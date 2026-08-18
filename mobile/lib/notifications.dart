/// Reminders, with Done reachable from the lock screen.
///
/// That last part is the product bet, not a nicety: if marking something done requires
/// opening the app, people stop marking it done and the data breaks (§7.2). Skip is
/// registered alongside Done and is equally prominent — a reminder you can dismiss
/// honestly is one you keep.
///
/// The awkward bit is that a lock-screen tap runs in a **separate isolate** with no
/// access to the app's state. So the handler does the smallest durable thing it can:
/// append the completion to a queue in shared_preferences. The app drains that queue on
/// launch and on resume. Trying to parse, mutate and rewrite the whole state blob from
/// a background isolate would race the foreground and lose writes.
library;

import 'dart:io' show Platform;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'domain/clock.dart';
import 'domain/routine.dart';

const channelId = 'routines';
const actionDone = 'DONE';
const actionSnooze = 'SNOOZE';
const actionSkip = 'SKIP';

const _pendingKey = 'trueburn.pendingTicks.v1';

/// The iOS category that carries the action buttons. Android attaches actions to each
/// notification; iOS registers them once, up front, against a category identifier —
/// a notification with no matching registered category shows no buttons at all, and
/// fails silently rather than erroring.
const categoryId = 'ROUTINE';

/// v22 dropped the cross-platform facade in favour of the platform implementations, so
/// there is no single object to talk to — each platform is addressed directly.
final AndroidFlutterLocalNotificationsPlugin _android =
    AndroidFlutterLocalNotificationsPlugin();
final IOSFlutterLocalNotificationsPlugin _ios = IOSFlutterLocalNotificationsPlugin();

/// iOS refuses to hold more than **64** pending local notifications per app. Past that
/// it keeps the 64 soonest and drops the rest — no error, no callback, no log. A single
/// six-a-day water routine repeating weekly is already 42 requests, so two routines
/// would quietly lose their later reminders.
///
/// Two things keep this under control: every-day routines collapse to one daily-repeat
/// request instead of seven weekly ones (a 7x reduction, and exactly equivalent), and
/// what is left is scheduled soonest-first up to a ceiling that leaves headroom.
const _iosPendingLimit = 60;

/// `routineId|HH:MM` — enough for the app to apply the tick, small enough to be a
/// payload string.
String _payload(String routineId, String time) => '$routineId|$time';

Future<void> _queue(String payload) async {
  final prefs = await SharedPreferences.getInstance();
  // This isolate may hold a stale cache of what the app wrote.
  await prefs.reload();
  final q = prefs.getStringList(_pendingKey) ?? <String>[];
  if (!q.contains(payload)) {
    q.add(payload);
    await prefs.setStringList(_pendingKey, q);
  }
}

/// Runs in its own isolate — no store, no widgets, nothing but plugins.
@pragma('vm:entry-point')
void onBackgroundResponse(NotificationResponse r) {
  if (r.actionId != actionDone) return;
  final p = r.payload;
  if (p == null || !p.contains('|')) return;
  // Skip and snooze deliberately record nothing: a skipped reminder shows as missed,
  // which is information rather than failure.
  _queue(p);
}

void _onForegroundResponse(NotificationResponse r) {
  if (r.actionId != actionDone) return;
  final p = r.payload;
  if (p != null && p.contains('|')) _queue(p);
}

class Notifications {
  static bool _ready = false;

  static Future<void> init() async {
    if (_ready) return;

    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      // A wrong zone would fire reminders at the wrong hour, so fall back to UTC
      // rather than guessing at the user's offset.
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    if (Platform.isAndroid) {
      await _android.initialize(
        // Must be a white-on-transparent silhouette: Android discards the colour
        // and tints the alpha, so a launcher icon renders as a solid blob.
        settings: const AndroidInitializationSettings('@drawable/ic_notification'),
        onDidReceiveNotificationResponse: _onForegroundResponse,
        onDidReceiveBackgroundNotificationResponse: onBackgroundResponse,
      );

      await _android.createNotificationChannel(const AndroidNotificationChannel(
        channelId,
        'Routines',
        description: 'Reminders you created.',
        importance: Importance.defaultImportance,
      ));
      // The permission is *not* requested here — see `requestPermission` below.
    } else if (Platform.isIOS) {
      await _ios.initialize(
        settings: DarwinInitializationSettings(
          // Deferred, like Android's — asked for explicitly once the user has been told
          // what reminders are for.
          requestAlertPermission: false,
          requestBadgePermission: false,
          // Sound off to match Android: a reminder you asked for should not also be a
          // noise you did not.
          requestSoundPermission: false,
          defaultPresentSound: false,
          notificationCategories: <DarwinNotificationCategory>[
            DarwinNotificationCategory(
              categoryId,
              actions: <DarwinNotificationAction>[
                // `foreground` is deliberately absent: Done must not open the app, or
                // the product bet in this file's header is lost. Without it iOS runs
                // the action in the background isolate, which is what we want.
                DarwinNotificationAction.plain(actionDone, 'Done'),
                DarwinNotificationAction.plain(actionSnooze, 'In 30 min'),
                DarwinNotificationAction.plain(actionSkip, 'Skip'),
              ],
              options: const {DarwinNotificationCategoryOption.hiddenPreviewShowTitle},
            ),
          ],
        ),
        onDidReceiveNotificationResponse: _onForegroundResponse,
        onDidReceiveBackgroundNotificationResponse: onBackgroundResponse,
      );
    }
    _ready = true;
  }

  /// Ask for the notification permission — deliberately *not* at init.
  ///
  /// Requesting on the very first frame, before the app has said what reminders are or
  /// why they exist, is the reliable way to get denied: the user is answering a
  /// question they have no context for, and on both platforms a denial is close to
  /// permanent — the app cannot re-prompt, only send them to Settings.
  ///
  /// This runs once the tour has had its say instead. Nothing breaks if it is refused:
  /// scheduling still succeeds, the notifications simply do not display.
  static Future<void> requestPermission() async {
    if (!_ready) return;
    if (Platform.isAndroid) {
      // Android 13+ requires an explicit grant; without it nothing ever appears.
      await _android.requestNotificationsPermission();
    } else if (Platform.isIOS) {
      await _ios.requestPermissions(alert: true, badge: true);
    }
  }

  /// Completions banked by the lock screen while the app was not running.
  static Future<List<({String routineId, String time})>> drainPending() async {
    final prefs = await SharedPreferences.getInstance();
    // Critical: shared_preferences caches in-memory per isolate. The queue was written
    // by the notification isolate while this one was alive, so without an explicit
    // reload the main isolate reads its own stale snapshot and silently drops every
    // completion tapped from the lock screen.
    await prefs.reload();
    final q = prefs.getStringList(_pendingKey) ?? <String>[];
    if (q.isEmpty) return const [];
    await prefs.remove(_pendingKey);
    return q
        .map((p) => p.split('|'))
        .where((parts) => parts.length == 2)
        .map((parts) => (routineId: parts[0], time: parts[1]))
        .toList();
  }

  /// Stable per (routine, weekday, time) so a reschedule replaces rather than duplicates.
  static int _id(String routineId, int dow, String time) =>
      ('$routineId|$dow|$time').hashCode & 0x7FFFFFFF;

  /// Quiet hours normally wrap midnight (22:00 → 07:00), so the inside test flips.
  static bool _quiet(String time, String from, String to) {
    final t = minsOf(time);
    final f = minsOf(from);
    final q = minsOf(to);
    return f <= q ? (t >= f && t < q) : (t >= f || t < q);
  }

  /// How many reminders iOS could not be given room for. Zero on Android, and zero on
  /// iOS until someone builds a schedule denser than the OS will hold.
  static int droppedFromSchedule = 0;

  /// Next occurrence of a time, any day.
  static tz.TZDateTime _nextDaily(String time) {
    final now = tz.TZDateTime.now(tz.local);
    var d = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, minsOf(time) ~/ 60, minsOf(time) % 60);
    if (!d.isAfter(now)) d = d.add(const Duration(days: 1));
    return d;
  }

  static tz.TZDateTime _nextInstance(int dow, String time) {
    final now = tz.TZDateTime.now(tz.local);
    var d = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, minsOf(time) ~/ 60, minsOf(time) % 60);
    // Dart weekday is 1=Mon..7=Sun; routine days are 0=Sun.
    while (d.weekday % 7 != dow || !d.isAfter(now)) {
      d = d.add(const Duration(days: 1));
    }
    return d;
  }

  /// Rebuild the whole schedule from state.
  ///
  /// The OS schedule is a *projection* of the routines, never a thing mutated in place,
  /// so it can always be reconstructed from scratch. Cheap enough to run on any change.
  static Future<void> syncAll(
    List<Routine> routines, {
    required String quietFrom,
    required String quietTo,
    required bool paused,
  }) async {
    if (!_ready) return;
    await cancelAll();
    if (paused) return;

    var slots = <_Slot>[];
    for (final r in routines) {
      if (!r.active) continue;
      // An every-day routine is one daily repeat, not seven weekly ones. Identical
      // behaviour, a seventh of the pending requests — which is what keeps iOS under
      // its cap for any realistic set of routines.
      final daily = r.days.length == 7;
      for (final dow in daily ? const [0] : r.days) {
        for (final time in r.times) {
          if (_quiet(time, quietFrom, quietTo)) continue;
          slots.add(_Slot(r, dow, time, daily));
        }
      }
    }

    if (Platform.isIOS && slots.length > _iosPendingLimit) {
      // Soonest first, so what survives is what fires next. Truncating is not silent
      // here even though iOS would have done it silently: the count is exposed through
      // `droppedFromSchedule` for the UI to surface.
      slots.sort((a, b) => a.when.compareTo(b.when));
      droppedFromSchedule = slots.length - _iosPendingLimit;
      slots = slots.take(_iosPendingLimit).toList();
    } else {
      droppedFromSchedule = 0;
    }

    for (final s in slots) {
      final body = s.routine.type == RoutineType.water && s.routine.amountMl > 0
          ? '${s.routine.message} Marking done logs ${s.routine.amountMl} ml.'
          : s.routine.message;
      final payload = _payload(s.routine.id, s.time);
      final match =
          s.daily ? DateTimeComponents.time : DateTimeComponents.dayOfWeekAndTime;

      if (Platform.isAndroid) {
        await _android.zonedSchedule(
          id: s.id,
          title: s.routine.name,
          body: body,
          scheduledDate: s.when,
          notificationDetails: const AndroidNotificationDetails(
              channelId,
              'Routines',
              importance: Importance.defaultImportance,
              priority: Priority.defaultPriority,
              playSound: false,
              actions: [
                // Done first, but Skip is a full sibling — not tucked away.
                AndroidNotificationAction(actionDone, 'Done',
                    showsUserInterface: false, cancelNotification: true),
                AndroidNotificationAction(actionSnooze, 'In 30 min',
                    showsUserInterface: false, cancelNotification: true),
                AndroidNotificationAction(actionSkip, 'Skip',
                    showsUserInterface: false, cancelNotification: true),
              ]),
          payload: payload,
          // Exact, deliberately. Inexact alarms carry a **one-hour** delivery window
          // on Android — verified in `dumpsys alarm` — which would let a 9 am
          // reminder arrive at 9:55 and quietly destroy the premise that the schedule
          // means anything. USE_EXACT_ALARM is the permission for exactly this case.
          scheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          matchDateTimeComponents: match,
        );
      } else if (Platform.isIOS) {
        await _ios.zonedSchedule(
          id: s.id,
          title: s.routine.name,
          body: body,
          scheduledDate: s.when,
          // No exact-alarm question on iOS: a UNCalendarNotificationTrigger fires on
          // the minute without a permission, which is the one place iOS is simpler.
          notificationDetails: const DarwinNotificationDetails(
            categoryIdentifier: categoryId,
            presentSound: false,
            threadIdentifier: channelId,
          ),
          payload: payload,
          matchDateTimeComponents: match,
        );
      }
    }
  }

  /// Fire one shortly, for checking the lock-screen actions without waiting for 9 am.
  static Future<void> fireTestIn(Duration d, Routine r, String time) async {
    if (!_ready) return;
    final at = tz.TZDateTime.now(tz.local).add(d);
    final body = '${r.message}  (test — tap Done, then reopen the app)';
    if (Platform.isAndroid) {
      await _android.zonedSchedule(
        id: 999001,
        title: r.name,
        body: body,
        scheduledDate: at,
        notificationDetails: const AndroidNotificationDetails(
          channelId,
          'Routines',
          importance: Importance.defaultImportance,
          playSound: false,
          actions: [
            AndroidNotificationAction(actionDone, 'Done',
                showsUserInterface: false, cancelNotification: true),
            AndroidNotificationAction(actionSkip, 'Skip',
                showsUserInterface: false, cancelNotification: true),
          ],
        ),
        payload: _payload(r.id, time),
        scheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } else if (Platform.isIOS) {
      await _ios.zonedSchedule(
        id: 999001,
        title: r.name,
        body: body,
        scheduledDate: at,
        notificationDetails: const DarwinNotificationDetails(
          categoryIdentifier: categoryId,
          presentSound: false,
        ),
        payload: _payload(r.id, time),
      );
    }
  }

  static Future<int> scheduledCount() async => Platform.isAndroid
      ? (await _android.pendingNotificationRequests()).length
      : (await _ios.pendingNotificationRequests()).length;

  static Future<void> cancelAll() =>
      Platform.isAndroid ? _android.cancelAll() : _ios.cancelAll();
}

/// One scheduled reminder, resolved to its next fire time so the iOS cap can be applied
/// soonest-first rather than in whatever order the routines happen to be stored.
class _Slot {
  final Routine routine;
  final int dow;
  final String time;
  final bool daily;
  final tz.TZDateTime when;

  _Slot(this.routine, this.dow, this.time, this.daily)
      : when = daily ? Notifications._nextDaily(time) : Notifications._nextInstance(dow, time);

  int get id => Notifications._id(routine.id, daily ? -1 : dow, time);
}
