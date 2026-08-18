/**
 * Weight over the selected range.
 *
 * Raw weigh-ins are scattered dots behind a confident trend line — the product's whole
 * thesis, drawn. Dots earn their place at a month, shrink at a quarter, and are dropped
 * at a year where 365 of them are texture rather than information. The line is scaled to
 * the trend so outliers cannot flatten it.
 */

import React, { useState } from 'react';
import { View } from 'react-native';
import Svg, { Circle, Line, Path } from 'react-native-svg';
import type { TrendPoint } from '@core/weightTrend';
import { useTheme } from '../theme/ThemeProvider';

export function TrendChart({
  points,
  days,
  height = 92,
}: {
  points: TrendPoint[];
  days: number;
  height?: number;
}) {
  const { c } = useTheme();
  const [w, setW] = useState(300);

  const slice = points.slice(Math.max(0, points.length - days));
  if (slice.length < 2) return <View style={{ height }} />;

  const pad = 7;
  const showDots = days <= 90;
  const dotR = days <= 30 ? 1.9 : 1.2;

  const values = slice.map((p) => p.trend).concat(showDots ? slice.map((p) => p.raw) : []);
  const lo = Math.min(...values) - 0.25;
  const hi = Math.max(...values) + 0.25;
  const span = Math.max(0.1, hi - lo);

  const X = (i: number) => pad + (i / (slice.length - 1)) * (w - pad * 2);
  const Y = (v: number) => pad + (1 - (v - lo) / span) * (height - pad * 2);

  const d = slice.map((p, i) => `${i ? 'L' : 'M'}${X(i).toFixed(1)} ${Y(p.trend).toFixed(1)}`).join(' ');
  const lastPoint = slice[slice.length - 1];
  if (!lastPoint) return <View style={{ height }} />;

  return (
    <View onLayout={(e) => setW(e.nativeEvent.layout.width)} style={{ height }}>
      <Svg width={w} height={height}>
        {[0.25, 0.5, 0.75].map((g) => (
          <Line
            key={g}
            x1={0}
            x2={w}
            y1={pad + g * (height - pad * 2)}
            y2={pad + g * (height - pad * 2)}
            stroke={c.line}
            strokeWidth={1}
          />
        ))}
        {showDots &&
          slice.map((p, i) => (
            <Circle key={p.date} cx={X(i)} cy={Y(p.raw)} r={dotR} fill={c.ink3} opacity={0.42} />
          ))}
        <Path d={d} stroke={c.accent} strokeWidth={2} fill="none" strokeLinejoin="round" strokeLinecap="round" />
        <Circle
          cx={X(slice.length - 1)}
          cy={Y(lastPoint.trend)}
          r={5.4}
          stroke={c.accent}
          strokeWidth={1.5}
          fill="none"
          opacity={0.3}
        />
        <Circle cx={X(slice.length - 1)} cy={Y(lastPoint.trend)} r={3} fill={c.accent} />
      </Svg>
    </View>
  );
}
