import React, { useCallback, useEffect, useMemo, useState } from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { SafeAreaProvider, SafeAreaView } from 'react-native-safe-area-context';
import { StatusBar } from 'expo-status-bar';

import { Pill, Sheet } from './src/components/ui';
import { clock, minutesNow, todayISO } from './src/domain/time';
import type { Routine } from './src/domain/routines';
import { FoodSheet } from './src/sheets/FoodSheet';
import { RoutineSheet } from './src/sheets/RoutineSheet';
import { SettingsSheet } from './src/sheets/SettingsSheet';
import { WeighSheet } from './src/sheets/WeighSheet';
import { RoutinesScreen } from './src/screens/RoutinesScreen';
import { TodayScreen } from './src/screens/TodayScreen';
import { consumedKcal, rolloverDay, tickReminder } from './src/store/actions';
import { hydrate, useStore } from './src/store/store';
import { useReport } from './src/hooks/useReport';
import { ThemeProvider, useTheme } from './src/theme/ThemeProvider';
import {
  ACTION_DONE,
  ACTION_SKIP,
  ACTION_SNOOZE,
  Notifications,
  configure,
  syncAll,
} from './src/notifications';

type Tab = 'today' | 'routines';
type SheetKind = 'food' | 'weigh' | 'history' | 'settings' | 'pause' | null;

const PAUSE_OPTIONS = [
  { m: 60, label: '1 hour' },
  { m: 240, label: '4 hours' },
  { m: -2, label: 'Rest of today' },
  { m: -1, label: 'Until tomorrow' },
];

function Shell() {
  const { c } = useTheme();
  const s = useStore((x) => x);
  const { report } = useReport();

  const [tab, setTab] = useState<Tab>('today');
  const [sheet, setSheet] = useState<SheetKind>(null);
  const [editing, setEditing] = useState<{ r: Routine; isNew: boolean } | null>(null);
  const [pausedUntil, setPausedUntil] = useState<number | null>(null);

  const paused = pausedUntil !== null;
  const pausedLabel = pausedUntil === -1 ? 'tomorrow morning' : pausedUntil !== null ? clock(pausedUntil) : null;

  // Roll yesterday's ticks over whenever the app comes back to a new calendar day.
  useEffect(() => {
    rolloverDay();
    const id = setInterval(rolloverDay, 60_000);
    return () => clearInterval(id);
  }, []);

  // Reminders are rescheduled from state, never mutated in place — the schedule on the
  // OS is a projection of the routines, so it can always be rebuilt from scratch.
  useEffect(() => {
    if (!s.hydrated) return;
    void syncAll(paused ? [] : s.routines, {
      from: s.settings.quietFrom,
      to: s.settings.quietTo,
    });
  }, [s.hydrated, s.routines, s.settings.quietFrom, s.settings.quietTo, paused]);

  // Done from the lock screen, without opening the app. If marking something done needs
  // a launch, people stop marking it done and the data breaks.
  useEffect(() => {
    const sub = Notifications.addNotificationResponseReceivedListener((res) => {
      const data = res.notification.request.content.data as { routineId?: string; time?: string };
      if (!data?.routineId || !data?.time) return;
      if (res.actionIdentifier === ACTION_DONE) tickReminder(data.routineId, data.time, false);
      // SKIP and SNOOZE deliberately record nothing: a skipped reminder shows as missed,
      // which is information rather than failure.
      void ACTION_SKIP;
      void ACTION_SNOOZE;
    });
    return () => sub.remove();
  }, []);

  const openSheet = useCallback((k: Exclude<SheetKind, null>) => setSheet(k), []);
  const consumed = useMemo(() => consumedKcal(s, todayISO()), [s]);

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: c.ground }} edges={['top', 'left', 'right']}>
      <StatusBar style="auto" />

      <View style={{ flex: 1 }}>
        {tab === 'today' ? (
          <TodayScreen onOpen={openSheet} />
        ) : (
          <RoutinesScreen
            pausedUntil={pausedLabel}
            onResume={() => setPausedUntil(null)}
            onPauseAll={() => setSheet('pause')}
            onEdit={(r) => setEditing({ r, isNew: !s.routines.some((x) => x.id === r.id) })}
          />
        )}
      </View>

      <View
        style={{
          flexDirection: 'row',
          borderTopWidth: StyleSheet.hairlineWidth * 2,
          borderTopColor: c.line,
          backgroundColor: c.surface,
          paddingTop: 7,
          paddingBottom: 18,
          paddingHorizontal: 12,
        }}
      >
        {(['today', 'routines'] as Tab[]).map((t) => (
          <Pressable
            key={t}
            accessibilityRole="tab"
            accessibilityState={{ selected: tab === t }}
            onPress={() => setTab(t)}
            style={{ flex: 1, alignItems: 'center', paddingVertical: 7 }}
          >
            <Text style={{ color: tab === t ? c.accent : c.ink3, fontSize: 12, fontWeight: '600' }}>
              {t === 'today' ? 'Today' : 'Routines'}
            </Text>
          </Pressable>
        ))}
      </View>

      <FoodSheet
        open={sheet === 'food'}
        onClose={() => setSheet(null)}
        consumed={consumed}
        target={report.energy.target.kcal}
        paused={paused}
      />
      <WeighSheet open={sheet === 'weigh'} onClose={() => setSheet(null)} />
      <SettingsSheet open={sheet === 'settings'} onClose={() => setSheet(null)} />

      <Sheet open={sheet === 'pause'} onClose={() => setSheet(null)}>
        <Text style={{ fontSize: 23, fontWeight: '600', color: c.ink }}>Pause everything</Text>
        <Text style={{ fontSize: 13, color: c.ink2, lineHeight: 20 }}>
          Nothing fires until then. Day counts keep running, so a pause costs no progress.
        </Text>
        {PAUSE_OPTIONS.map((o) => (
          <Pill
            key={o.label}
            label={`${o.label} · until ${
              o.m === -1 ? 'tomorrow morning' : o.m === -2 ? 'midnight' : clock(minutesNow() + o.m)
            }`}
            onPress={() => {
              setPausedUntil(o.m === -1 ? -1 : o.m === -2 ? 1440 : minutesNow() + o.m);
              setSheet(null);
            }}
          />
        ))}
      </Sheet>

      {editing && (
        <RoutineSheet
          routine={editing.r}
          isNew={editing.isNew}
          onClose={() => setEditing(null)}
        />
      )}
    </SafeAreaView>
  );
}

export default function App() {
  const [ready, setReady] = useState(false);
  const theme = useStore((s) => s.settings.theme);

  useEffect(() => {
    void (async () => {
      await hydrate();
      await configure();
      setReady(true);
    })();
  }, []);

  return (
    <SafeAreaProvider>
      <ThemeProvider choice={theme}>{ready ? <Shell /> : <View style={{ flex: 1 }} />}</ThemeProvider>
    </SafeAreaProvider>
  );
}
