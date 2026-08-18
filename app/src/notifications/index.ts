/**
 * Reminders, with Done reachable from the lock screen.
 *
 * That last part is the product bet, not a nicety: if marking something done requires
 * opening the app, people stop marking it done and the data breaks (REQUIREMENTS §7.2).
 * Skip is registered alongside Done and is equally prominent — a reminder you can
 * dismiss honestly is one you keep.
 */

import * as Notifications from 'expo-notifications';
import { Platform } from 'react-native';
import { mins } from '../domain/time';
import type { Routine } from '../domain/routines';

export const CATEGORY = 'baseline.routine';
export const ACTION_DONE = 'DONE';
export const ACTION_SNOOZE = 'SNOOZE';
export const ACTION_SKIP = 'SKIP';

Notifications.setNotificationHandler({
  // `shouldShowAlert` is the older field and `shouldShowBanner`/`shouldShowList` the
  // newer split; both are set so this behaves the same across SDK versions.
  handleNotification: async () => ({
    shouldShowAlert: true,
    shouldShowBanner: true,
    shouldShowList: true,
    shouldPlaySound: false,
    shouldSetBadge: false,
  }),
});

export async function configure(): Promise<boolean> {
  const existing = await Notifications.getPermissionsAsync();
  let status = existing.status;
  if (status !== 'granted') {
    const asked = await Notifications.requestPermissionsAsync();
    status = asked.status;
  }
  if (status !== 'granted') return false;

  await Notifications.setNotificationCategoryAsync(CATEGORY, [
    { identifier: ACTION_DONE, buttonTitle: 'Done', options: { opensAppToForeground: false } },
    { identifier: ACTION_SNOOZE, buttonTitle: 'In 30 min', options: { opensAppToForeground: false } },
    { identifier: ACTION_SKIP, buttonTitle: 'Skip', options: { opensAppToForeground: false } },
  ]);

  if (Platform.OS === 'android') {
    await Notifications.setNotificationChannelAsync('routines', {
      name: 'Routines',
      importance: Notifications.AndroidImportance.DEFAULT,
      sound: null,
      vibrationPattern: [0, 120],
      enableVibrate: true,
    });
  }
  return true;
}

/** Deterministic per reminder, so rescheduling replaces rather than duplicates. */
const slotId = (routineId: string, dow: number, time: string) => `${routineId}|${dow}|${time}`;

function withinQuietHours(time: string, from: string, to: string): boolean {
  const t = mins(time);
  const f = mins(from);
  const q = mins(to);
  // Quiet hours normally wrap midnight (22:00 → 07:00), so the inside test flips.
  return f <= q ? t >= f && t < q : t >= f || t < q;
}

export async function scheduleRoutine(
  r: Routine,
  quiet: { from: string; to: string },
): Promise<void> {
  await cancelRoutine(r.id);
  if (!r.active) return;

  for (const dow of r.days) {
    for (const time of r.times) {
      if (withinQuietHours(time, quiet.from, quiet.to)) continue;
      const body =
        r.type === 'water' && r.amountMl
          ? `${r.message} Marking done logs ${r.amountMl} ml.`
          : r.message;
      await Notifications.scheduleNotificationAsync({
        identifier: slotId(r.id, dow, time),
        content: {
          title: r.name,
          body,
          categoryIdentifier: CATEGORY,
          data: { routineId: r.id, time, type: r.type },
        },
        trigger: {
          type: Notifications.SchedulableTriggerInputTypes.WEEKLY,
          // expo weekday is 1 = Sunday.
          weekday: dow + 1,
          hour: Math.floor(mins(time) / 60),
          minute: mins(time) % 60,
        },
      });
    }
  }
}

export async function cancelRoutine(routineId: string): Promise<void> {
  const all = await Notifications.getAllScheduledNotificationsAsync();
  await Promise.all(
    all
      .filter((n) => n.identifier.startsWith(`${routineId}|`))
      .map((n) => Notifications.cancelScheduledNotificationAsync(n.identifier)),
  );
}

export async function cancelAll(): Promise<void> {
  await Notifications.cancelAllScheduledNotificationsAsync();
}

/** Re-schedule everything. Cheap enough to run whenever routines or quiet hours change. */
export async function syncAll(
  routines: Routine[],
  quiet: { from: string; to: string },
): Promise<void> {
  await cancelAll();
  for (const r of routines) await scheduleRoutine(r, quiet);
}

export async function snooze(r: { name: string; message: string }, minutes = 30): Promise<void> {
  await Notifications.scheduleNotificationAsync({
    content: { title: r.name, body: r.message, categoryIdentifier: CATEGORY },
    trigger: {
      type: Notifications.SchedulableTriggerInputTypes.TIME_INTERVAL,
      seconds: minutes * 60,
    },
  });
}

export { Notifications };
