/**
 * The water fill.
 *
 * The level *is* the reading, so the motion carries information rather than decorating.
 * Two offset sine layers, and the level eases toward its new value so adding water reads
 * as filling rather than snapping. No text sits on top: over a variable fill no single
 * ink colour stays legible, so the readout lives on solid surface below (§5.5).
 */

import React, { useEffect, useState } from 'react';
import { View, useWindowDimensions } from 'react-native';
import Animated, {
  Easing,
  useAnimatedProps,
  useSharedValue,
  withRepeat,
  withTiming,
  useReducedMotion,
} from 'react-native-reanimated';
import Svg, { Path, Rect } from 'react-native-svg';
import { useTheme } from '../theme/ThemeProvider';

const AnimatedPath = Animated.createAnimatedComponent(Path);

function buildPath(w: number, h: number, levelPct: number, phase: number, amp: number, freq: number) {
  'worklet';
  const level = h - (levelPct / 100) * h;
  let d = `M0 ${h}`;
  const step = 6;
  for (let x = 0; x <= w; x += step) {
    const y = level + Math.sin((x / Math.max(1, w)) * Math.PI * freq + phase) * amp * (levelPct > 2 ? 1 : 0);
    d += ` L${x.toFixed(1)} ${y.toFixed(1)}`;
  }
  return `${d} L${w} ${h} Z`;
}

export function WaterWave({ pct, height = 76 }: { pct: number; height?: number }) {
  const { c } = useTheme();
  const win = useWindowDimensions();
  const [w, setW] = useState(win.width - 36);
  const reduced = useReducedMotion();

  const phase = useSharedValue(0);
  const level = useSharedValue(pct);

  useEffect(() => {
    level.value = reduced ? pct : withTiming(pct, { duration: 700, easing: Easing.out(Easing.cubic) });
  }, [pct, reduced, level]);

  useEffect(() => {
    if (reduced) return;
    phase.value = withRepeat(
      withTiming(Math.PI * 2, { duration: 4200, easing: Easing.linear }),
      -1,
      false,
    );
  }, [reduced, phase]);

  const backProps = useAnimatedProps(() => ({
    d: buildPath(w, height, level.value, phase.value, 10, 2.2),
  }));
  const frontProps = useAnimatedProps(() => ({
    d: buildPath(w, height, level.value, phase.value + Math.PI / 2, 14, 2.2),
  }));

  return (
    <View
      style={{ height, backgroundColor: c.sunken }}
      onLayout={(e) => setW(e.nativeEvent.layout.width)}
    >
      <Svg width={w} height={height}>
        <Rect x={0} y={0} width={w} height={height} fill={c.sunken} />
        <AnimatedPath animatedProps={backProps} fill={c.accent} opacity={0.55} />
        <AnimatedPath animatedProps={frontProps} fill={c.accent} opacity={0.32} />
      </Svg>
    </View>
  );
}
