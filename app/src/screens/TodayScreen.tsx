import React, { useState } from 'react';
import { Pressable, ScrollView, Text, View } from 'react-native';
import { waterTargetMl } from '@core/targets';
import { IntakeBar } from '../components/IntakeBar';
import { TrendChart } from '../components/TrendChart';
import { WaterWave } from '../components/WaterWave';
import {
  Body,
  Card,
  Chip,
  Label,
  Meter,
  Notice,
  Num,
  Pill,
  PrimaryButton,
  Row,
  SegButton,
  Split,
} from '../components/ui';
import { MEALS, type Meal } from '../domain/foods';
import { minutesNow, todayISO } from '../domain/time';
import { useReport } from '../hooks/useReport';
import { addWater, consumedKcal, copyYesterday, totalWaterMl } from '../store/actions';
import { useStore } from '../store/store';
import { useTheme } from '../theme/ThemeProvider';

const MEASURE_FROM = 12;
const MEASURE_FULL = 28;

type Range = 'month' | 'quarter' | 'year';
const RANGE_DAYS: Record<Range, number> = { month: 30, quarter: 90, year: 365 };

export function TodayScreen({
  onOpen,
}: {
  onOpen: (sheet: 'food' | 'weigh' | 'history' | 'settings') => void;
}) {
  const { c } = useTheme();
  const s = useStore((x) => x);
  const { report, trend, spanDays } = useReport();
  const [range, setRange] = useState<Range>('month');
  const [armed, setArmed] = useState<number | null>(null);

  const today = todayISO();
  const consumed = consumedKcal(s, today);
  const waterMl = totalWaterMl(s);
  const fromRoutines = waterMl - s.water.manualMl;
  const paused = false;

  const hasWeight = s.log.weighIns.length > 0;
  const target = report.energy.target.kcal;

  // ------------------------------------------------------------ first run
  if (!hasWeight) {
    const wTarget = 2500;
    return (
      <ScrollView contentContainerStyle={{ padding: 18, gap: 18, paddingBottom: 40 }}>
        <Row>
          <Text style={{ flex: 1, fontSize: 23, fontWeight: '600', color: c.ink }}>Today</Text>
          <Pill label="Settings" onPress={() => onOpen('settings')} />
        </Row>

        <Card style={{ gap: 14 }}>
          <View>
            <Label>Welcome</Label>
            <Text style={{ fontSize: 19, fontWeight: '600', color: c.ink, marginTop: 6, lineHeight: 24 }}>
              Weigh yourself. That is the whole of today.
            </Text>
          </View>
          {[
            ['Today', 'One weigh-in. Five seconds, and the app has what it needs to start.'],
            ['This week', 'Log roughly what you eat. Rough is fine — it only has to be consistent.'],
            ['Week three', 'Baseline stops estimating and tells you what you actually burn.'],
          ].map(([k, v]) => (
            <View key={k} style={{ gap: 2 }}>
              <Label style={{ color: c.accent }}>{k}</Label>
              <Body>{v}</Body>
            </View>
          ))}
          <PrimaryButton label="Log your first weight" onPress={() => onOpen('weigh')} />
          <Body size={12} color={c.ink3}>
            No account, nothing uploaded. You can add food and water any time — they do not need
            setting up first.
          </Body>
        </Card>

        <Card>
          <Row>
            <View style={{ flex: 1 }}>
              <Text style={{ fontSize: 14, fontWeight: '500', color: c.ink }}>Food</Text>
              <Body size={12} color={c.ink3}>Nothing logged yet</Body>
            </View>
            <Pill label="Add" tone="accent" onPress={() => onOpen('food')} />
          </Row>
        </Card>

        <Card flush>
          <WaterWave pct={Math.min(100, (waterMl / wTarget) * 100)} />
          <View style={{ padding: 16, gap: 12 }}>
            <Row gap={9}>
              <Num size={30}>{(waterMl / 1000).toFixed(2)} L</Num>
              <Body size={12.5}>no target until you weigh in</Body>
            </Row>
            <WaterButtons armed={armed} setArmed={setArmed} paused={paused} />
          </View>
        </Card>
      </ScrollView>
    );
  }

  // ------------------------------------------------------------ normal
  const mode = report.energy.tdee.mode;
  const chipLabel = mode === 'measured' ? 'Measured' : mode === 'blended' ? 'Part measured' : 'Estimated';
  const remaining = target === null ? null : target - consumed;
  const wTarget = report.water.targetMl ?? waterTargetMl(report.weight.trend ?? 70);

  const byMeal = MEALS.reduce(
    (acc, m) => {
      acc[m.k] = s.entries.filter((e) => e.date === today && e.meal === m.k).reduce((a, e) => a + e.kcal, 0);
      return acc;
    },
    {} as Record<Meal, number>,
  );

  const days = Math.min(RANGE_DAYS[range], trend.length);
  const first = trend[Math.max(0, trend.length - days)];
  const last = trend[trend.length - 1];
  const delta = first && last ? last.trend - first.trend : 0;
  const weeks = first && last ? Math.max(1, (last.day - first.day) / 7) : 1;

  return (
    <ScrollView contentContainerStyle={{ padding: 18, gap: 18, paddingBottom: 40 }}>
      <Row>
        <Text style={{ flex: 1, fontSize: 23, fontWeight: '600', color: c.ink }}>Today</Text>
        <Pill label="History" onPress={() => onOpen('history')} />
        <Pill label="Settings" onPress={() => onOpen('settings')} />
      </Row>

      <Card>
        <Row>
          <View style={{ flex: 1 }}>
            <Label>Left to eat</Label>
            <View style={{ marginTop: 6 }}>
              <Num size={44}>{remaining === null ? '—' : Math.abs(remaining)}</Num>
            </View>
          </View>
          <Chip label={chipLabel} tone={mode === 'formula' ? 'estimated' : 'measured'} />
        </Row>
        {target !== null && (
          <>
            <Meter pct={(consumed / target) * 100} over={consumed > target} />
            <Split
              left={<Body><Num>{consumed}</Num> eaten</Body>}
              right={<Body>target <Num>{target}</Num></Body>}
            />
          </>
        )}
        <Notice>
          Your expenditure is {Math.round(report.energy.tdee.kcal)} kcal,{' '}
          {mode === 'measured'
            ? `measured from your last ${MEASURE_FULL} days rather than estimated from your height and weight.`
            : mode === 'blended'
              ? `part measured from your ${spanDays} days of data, part still the starting estimate.`
              : `estimated from your height and weight. Baseline needs ${MEASURE_FROM} days of weigh-ins before it can start measuring.`}
        </Notice>
      </Card>

      {spanDays < MEASURE_FULL && (
        <Card>
          <Split
            left={<Label>Learning your body</Label>}
            right={<Num size={12}>{spanDays} of {MEASURE_FULL} days</Num>}
          />
          <Meter pct={(spanDays / MEASURE_FULL) * 100} markAt={(MEASURE_FROM / MEASURE_FULL) * 100} />
          {/* Keyed off the engine's own mode, not a threshold compare. At a 12-day span
              confidence is exactly zero — measurement becomes *possible*, not
              trustworthy — so a `spanDays >= 12` test here would claim measuring had
              started while the chip above still correctly read "Estimated". */}
          <Notice tone={mode === 'formula' ? 'plain' : 'accent'}>
            {mode === 'formula'
              ? `Your target still comes from a population formula, which is ±10–15% off for any given person. Baseline needs about ${MEASURE_FROM} days between weigh-ins before it can start measuring.`
              : `Measuring has started, but it is not confident yet — your target leans further on your own data each day until day ${MEASURE_FULL}.`}
          </Notice>
        </Card>
      )}

      <Card>
        <Row>
          <View style={{ flex: 1 }}>
            <Text style={{ fontSize: 14, fontWeight: '500', color: c.ink }}>Weight</Text>
            <Body size={12} color={c.ink3}>
              trend <Num size={12} color={c.ink2}>{report.weight.trend?.toFixed(1)} kg</Num>
            </Body>
          </View>
          <Pill label="Log" tone="accent" onPress={() => onOpen('weigh')} />
        </Row>
        <SegButton
          compact
          value={range}
          onChange={(v) => setRange(v as Range)}
          options={[
            { v: 'month', label: 'Month' },
            { v: 'quarter', label: 'Quarter' },
            { v: 'year', label: 'Year' },
          ]}
        />
        <TrendChart points={trend} days={RANGE_DAYS[range]} />
        <Row gap={9}>
          <Num size={22} color={delta < 0 ? c.accent : c.warn}>
            {delta < 0 ? '−' : '+'}
            {Math.abs(delta).toFixed(1)} kg
          </Num>
          <Body size={12}>
            over {days} days · {delta < 0 ? '−' : '+'}
            {Math.abs(delta / weeks).toFixed(2)} kg a week
          </Body>
        </Row>
      </Card>

      <Card>
        <Row>
          <View style={{ flex: 1 }}>
            <Text style={{ fontSize: 14, fontWeight: '500', color: c.ink }}>Food</Text>
            <Body size={12} color={c.ink3}>
              <Num size={12} color={c.ink2}>{consumed}</Num> kcal ·{' '}
              {s.entries.filter((e) => e.date === today).length} items
            </Body>
          </View>
          <Pill label="Add" tone="accent" onPress={() => onOpen('food')} />
        </Row>
        {target !== null && <IntakeBar byMeal={byMeal} total={consumed} target={target} />}
        {consumed === 0 && (
          <Pill label="Same as yesterday" onPress={() => copyYesterday(paused)} />
        )}
      </Card>

      <Card flush>
        <WaterWave pct={Math.min(100, (waterMl / wTarget) * 100)} />
        <View style={{ padding: 16, gap: 12 }}>
          <Row gap={9}>
            <Num size={30}>{(waterMl / 1000).toFixed(2)} L</Num>
            <Body size={12.5}>of {(wTarget / 1000).toFixed(2)} L</Body>
            {fromRoutines > 0 && (
              <Num size={12} color={c.accent}>{fromRoutines} ml from reminders</Num>
            )}
          </Row>
          <WaterButtons armed={armed} setArmed={setArmed} paused={paused} />
        </View>
      </Card>
    </ScrollView>
  );
}

/**
 * Two-tap add: the first arms, the second commits. A stray tap on a card scrolled past
 * several times a day should not silently rewrite the log.
 */
function WaterButtons({
  armed,
  setArmed,
  paused,
}: {
  armed: number | null;
  setArmed: (v: number | null) => void;
  paused: boolean;
}) {
  if (armed !== null) {
    return (
      <Row gap={7}>
        <Pill
          flex
          tone="accent"
          label={`Add ${armed >= 1000 ? `${armed / 1000} L` : `${armed} ml`}?`}
          onPress={() => {
            addWater(armed, paused);
            setArmed(null);
          }}
        />
        <Pill label="Cancel" onPress={() => setArmed(null)} />
      </Row>
    );
  }
  return (
    <Row gap={6}>
      {[100, 250, 500, 1000].map((v) => (
        <Pill
          key={v}
          flex
          mono
          label={`+${v >= 1000 ? `${v / 1000} L` : v}`}
          onPress={() => setArmed(v)}
        />
      ))}
    </Row>
  );
}

export { minutesNow };
