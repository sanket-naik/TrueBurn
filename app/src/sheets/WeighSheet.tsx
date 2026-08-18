import React, { useEffect, useState } from 'react';
import { Text, View } from 'react-native';
import { TREND_ALPHA } from '@core/weightTrend';
import { Body, Card, Num, Pill, PrimaryButton, Row, Sheet, Split } from '../components/ui';
import { useReport } from '../hooks/useReport';
import { logWeight } from '../store/actions';
import { useStore } from '../store/store';
import { useTheme } from '../theme/ThemeProvider';

/**
 * One number, and an honest preview of what it does.
 *
 * Raw weight swings a kilo or two on water alone, and reacting to that swing is the
 * behaviour the trend exists to prevent — so the sheet shows the trend the entry
 * produces, and puts the 0.01 precision on the *movement*, which is where the small
 * change actually lives (§4.1).
 */
export function WeighSheet({ open, onClose }: { open: boolean; onClose: () => void }) {
  const { c } = useTheme();
  const weighIns = useStore((s) => s.log.weighIns);
  const { trend } = useReport();

  const lastRaw = weighIns[weighIns.length - 1]?.kg ?? 75;
  const [v, setV] = useState(lastRaw);

  useEffect(() => {
    if (open) setV(Math.round(lastRaw * 10) / 10);
  }, [open, lastRaw]);

  const prev = trend[trend.length - 1]?.trend ?? v;
  // The same time-aware EMA the engine runs, so the preview is what actually lands.
  const nextTrend = trend.length ? prev + TREND_ALPHA * (v - prev) : v;
  const move = nextTrend - prev;
  const loggedToday = weighIns.some((w) => w.date === new Date().toISOString().slice(0, 10));

  const nudge = (d: number) => setV((x) => Math.round((x + d) * 10) / 10);

  return (
    <Sheet open={open} onClose={onClose}>
      <Text style={{ fontSize: 23, fontWeight: '600', color: c.ink }}>Log weight</Text>

      <Row gap={12}>
        <Pill label="−" onPress={() => nudge(-0.1)} />
        <View style={{ flex: 1, alignItems: 'center' }}>
          <Num size={30}>{v.toFixed(1)}</Num>
          <Body size={11.5} color={c.ink3}>kg</Body>
        </View>
        <Pill label="+" onPress={() => nudge(0.1)} />
      </Row>

      <Row gap={7}>
        {[-1, -0.5, 0.5, 1].map((d) => (
          <Pill key={d} flex mono label={`${d > 0 ? '+' : ''}${d}`} onPress={() => nudge(d)} />
        ))}
      </Row>

      <Card style={{ backgroundColor: c.sunken }}>
        <Split left={<Body>Trend after this</Body>} right={<Num size={17}>{nextTrend.toFixed(1)} kg</Num>} />
        <Split
          left={
            <Body size={12}>
              Moves the trend by{' '}
              <Num size={12}>{move >= 0 ? '+' : '−'}{Math.abs(move).toFixed(2)} kg</Num>
            </Body>
          }
          right={<Body size={12}>from <Num size={12}>{prev.toFixed(1)}</Num></Body>}
        />
      </Card>

      <Body size={12} color={c.ink3}>
        Day-to-day weight swings a kilo or two on water and food alone. Baseline records the number
        you enter but reads the trend, so a heavy morning does not mean a bad week.
      </Body>

      <Row gap={9}>
        <View style={{ flex: 1 }}>
          <Pill flex label="Cancel" onPress={onClose} />
        </View>
        <View style={{ flex: 1 }}>
          <PrimaryButton
            label={loggedToday ? 'Update' : 'Save'}
            onPress={() => {
              logWeight(v);
              onClose();
            }}
          />
        </View>
      </Row>
    </Sheet>
  );
}
