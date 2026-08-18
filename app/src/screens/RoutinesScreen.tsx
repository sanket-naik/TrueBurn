import React from 'react';
import { Pressable, ScrollView, Text, View } from 'react-native';
import { Timeline } from '../components/Timeline';
import { Body, Card, Label, Meter, Notice, Num, Pill, PrimaryButton, Row, Split } from '../components/ui';
import {
  TEMPLATES,
  dueOn,
  missedTimes,
  nextTime,
  whenText,
  type Routine,
  type RoutineType,
} from '../domain/routines';
import { ampm, minutesNow } from '../domain/time';
import { newRoutine, tickReminder, toggleRoutine, upsertRoutine } from '../store/actions';
import { useStore } from '../store/store';
import { useTheme } from '../theme/ThemeProvider';

export function RoutinesScreen({
  onEdit,
  onPauseAll,
  pausedUntil,
  onResume,
}: {
  onEdit: (r: Routine) => void;
  onPauseAll: () => void;
  pausedUntil: string | null;
  onResume: () => void;
}) {
  const { c } = useTheme();
  const routines = useStore((s) => s.routines);

  const now = new Date();
  const nowMin = minutesNow(now);
  const dow = now.getDay();
  const paused = pausedUntil !== null;

  const active = routines.filter((r) => r.active);
  const idle = routines.filter((r) => !r.active);
  const perDayTotal = active.reduce((a, r) => a + r.times.length, 0);

  const tally = (key: 'done' | 'doneYesterday', d: number) =>
    active.reduce(
      (acc, r) =>
        dueOn(r, d) ? { done: acc.done + r[key].length, due: acc.due + r.times.length } : acc,
      { done: 0, due: 0 },
    );
  const yest = tally('doneYesterday', (dow + 6) % 7);
  const todayT = tally('done', dow);
  const missed = active.reduce((a, r) => a + missedTimes(r, dow, nowMin, paused).length, 0);

  return (
    <ScrollView contentContainerStyle={{ padding: 18, gap: 18, paddingBottom: 40 }}>
      <Row>
        <Text style={{ flex: 1, fontSize: 23, fontWeight: '600', color: c.ink }}>Routines</Text>
        <Num size={11} color={c.ink3}>{perDayTotal}/DAY</Num>
      </Row>

      {paused && (
        <Notice tone="warn">
          Paused until {pausedUntil}.{'  '}
          <Text onPress={onResume} style={{ fontWeight: '700', textDecorationLine: 'underline' }}>
            Resume now
          </Text>
        </Notice>
      )}

      {active.length > 0 && (
        <Card>
          <Split
            left={<Label>Reminders</Label>}
            right={
              <Body size={11.5}>
                yest <Num size={11.5}>{yest.done}/{yest.due}</Num> · today{' '}
                <Num size={11.5}>{todayT.done}/{todayT.due}</Num>
              </Body>
            }
          />
          <Timeline routines={routines} nowMin={nowMin} todayDow={dow} paused={paused} />
          <Row gap={12}>
            <Legend color={c.accent} label="done" />
            <Legend color={c.warn} label="missed" hollow />
            <Legend color={c.ink3} label="ahead" faded />
            {missed > 0 && (
              <Num size={10.5} color={c.warn}>{missed} missed today</Num>
            )}
          </Row>
        </Card>
      )}

      <Row gap={9}>
        <View style={{ flex: 1 }}>
          <PrimaryButton label="New routine" onPress={() => onEdit(newRoutine('water'))} />
        </View>
        {!paused && (
          <View style={{ flex: 1 }}>
            <PrimaryButton label="Pause all" tone="ghost" onPress={onPauseAll} />
          </View>
        )}
      </Row>

      <View style={{ gap: 11 }}>
        <Label>Active · {active.length}</Label>
        {active.length ? (
          active.map((r) => (
            <RoutineCard
              key={r.id}
              r={r}
              nowMin={nowMin}
              dow={dow}
              paused={paused}
              onEdit={() => onEdit(r)}
            />
          ))
        ) : (
          <Starters />
        )}
      </View>

      {idle.length > 0 && (
        <View style={{ gap: 11 }}>
          <Label>Paused · {idle.length}</Label>
          {idle.map((r) => (
            <RoutineCard key={r.id} r={r} nowMin={nowMin} dow={dow} paused onEdit={() => onEdit(r)} />
          ))}
        </View>
      )}
    </ScrollView>
  );
}

function Legend({ color, label, hollow, faded }: { color: string; label: string; hollow?: boolean; faded?: boolean }) {
  const { c } = useTheme();
  return (
    <Row gap={5}>
      <View
        style={{
          width: 8,
          height: 8,
          borderRadius: 4,
          backgroundColor: hollow ? 'transparent' : color,
          borderWidth: hollow ? 1.5 : 0,
          borderColor: color,
          opacity: faded ? 0.3 : 1,
        }}
      />
      <Text style={{ fontSize: 10.5, color: c.ink3 }}>{label}</Text>
    </Row>
  );
}

function RoutineCard({
  r,
  nowMin,
  dow,
  paused,
  onEdit,
}: {
  r: Routine;
  nowMin: number;
  dow: number;
  paused: boolean;
  onEdit: () => void;
}) {
  const { c } = useTheme();
  const miss = missedTimes(r, dow, nowMin, paused);
  const due = dueOn(r, dow);
  const next = nextTime(r, nowMin);
  const pct = (r.elapsed / Math.max(1, r.totalDays)) * 100;

  return (
    <Card style={miss.length ? { borderColor: c.warn } : undefined}>
      <Pressable onPress={onEdit} accessibilityRole="button">
        <Row>
          <View style={{ flex: 1 }}>
            <Text style={{ fontSize: 14.5, fontWeight: '600', color: c.ink }}>{r.name}</Text>
            <Num size={11.5} color={c.ink2}>{whenText(r)}</Num>
          </View>
          <Text style={{ color: c.ink3, fontSize: 18 }}>›</Text>
        </Row>
      </Pressable>

      {due ? (
        <Row gap={10}>
          <Row gap={4}>
            {r.times.map((t) => {
              const done = r.done.includes(t);
              const lapsed = !done && Number(t.slice(0, 2)) * 60 + Number(t.slice(3, 5)) < nowMin && !paused;
              return (
                <View
                  key={t}
                  style={{
                    width: 8,
                    height: 8,
                    borderRadius: 4,
                    backgroundColor: done ? c.accent : lapsed ? 'transparent' : c.ink3,
                    borderWidth: lapsed ? 1.5 : 0,
                    borderColor: c.warn,
                    opacity: !done && !lapsed ? 0.28 : 1,
                  }}
                />
              );
            })}
          </Row>
          <Body size={12} color={miss.length ? c.warn : c.ink2}>
            <Num size={12} color={miss.length ? c.warn : c.ink}>{r.done.length}</Num> of {r.times.length} done today
          </Body>
        </Row>
      ) : (
        <Body size={12} color={c.ink3}>Not due today</Body>
      )}

      <Row gap={10}>
        <View style={{ flex: 1 }}>
          <Meter pct={pct} thin />
        </View>
        <Num size={10.5} color={c.ink3}>Day {r.elapsed} of {r.totalDays}</Num>
      </Row>

      <Row gap={7}>
        {r.active && !paused && due && next ? (
          <View style={{ flex: 1 }}>
            <Pill
              flex
              tone={miss.length ? 'warn' : 'accent'}
              label={miss[0] ? `Missed ${ampm(miss[0])} — tick` : `Tick ${ampm(next)}`}
              onPress={() => tickReminder(r.id, next, paused)}
            />
          </View>
        ) : (
          <View style={{ flex: 1 }} />
        )}
        <Pill label={r.active ? 'Pause' : 'Resume'} onPress={() => toggleRoutine(r.id)} />
      </Row>
    </Card>
  );
}

/** First run: the two reminders that pay for themselves, with the reason each earns it. */
function Starters() {
  const { c } = useTheme();
  const add = (t: RoutineType) => upsertRoutine(newRoutine(t));
  return (
    <View style={{ gap: 12, padding: 16, borderWidth: 1, borderStyle: 'dashed', borderColor: c.line, borderRadius: 14 }}>
      <Body>
        No routines yet. These two pay for themselves — a water reminder logs the water for you,
        and a meal reminder keeps your log complete enough for Baseline to measure anything.
      </Body>
      <Row gap={9}>
        <View style={{ flex: 1 }}>
          <Pill flex tone="accent" label="Water reminders" onPress={() => add('water')} />
        </View>
        <View style={{ flex: 1 }}>
          <Pill flex tone="accent" label="Meal reminders" onPress={() => add('food')} />
        </View>
      </Row>
    </View>
  );
}

export { TEMPLATES };
