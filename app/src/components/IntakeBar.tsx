/**
 * Intake grouped by meal, with the remaining budget as a labelled block.
 *
 * One segment per *entry* was tried first: a 16 kcal spoon of sugar became an invisible
 * sliver, and alternating accent tints coloured segments arbitrarily. Four meal blocks
 * are always legible and the opacity ramp — lighter earlier in the day — encodes
 * something true (§5.3).
 */

import React from 'react';
import { StyleSheet, Text, View } from 'react-native';
import { MEALS, type Meal } from '../domain/foods';
import { useTheme } from '../theme/ThemeProvider';
import { Num } from './ui';

export function IntakeBar({
  byMeal,
  total,
  target,
}: {
  byMeal: Record<Meal, number>;
  total: number;
  target: number;
}) {
  const { c } = useTheme();
  const over = total > target;
  const scale = Math.max(total, target, 1);
  const left = Math.max(0, target - total);

  return (
    <View style={{ gap: 8 }}>
      <View
        style={{
          height: 32,
          borderRadius: 9,
          backgroundColor: c.sunken,
          overflow: 'hidden',
          flexDirection: 'row',
        }}
      >
        {MEALS.map((m, i) => {
          const v = byMeal[m.k];
          if (!v) return null;
          const pct = (v / scale) * 100;
          return (
            <View
              key={m.k}
              style={{
                width: `${pct}%`,
                backgroundColor: c.accent,
                opacity: 0.58 + i * 0.14,
                justifyContent: 'center',
                paddingHorizontal: 8,
                borderRightWidth: StyleSheet.hairlineWidth * 2,
                borderRightColor: c.surface,
              }}
            >
              {pct > 21 && (
                <Text numberOfLines={1} style={{ color: c.onAccent, fontSize: 10.5, fontWeight: '600' }}>
                  {m.label}
                </Text>
              )}
            </View>
          );
        })}
        {left > 0 && (
          <View style={{ width: `${(left / scale) * 100}%`, justifyContent: 'center', paddingHorizontal: 8 }}>
            {(left / scale) * 100 > 16 && (
              <Text numberOfLines={1} style={{ color: c.ink3, fontSize: 10.5 }}>
                {left} left
              </Text>
            )}
          </View>
        )}
        {over && (
          <View
            style={{
              position: 'absolute',
              left: `${(target / scale) * 100}%`,
              top: 0,
              bottom: 0,
              width: 2,
              backgroundColor: c.ink,
              opacity: 0.65,
            }}
          />
        )}
      </View>

      <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 12 }}>
        {MEALS.filter((m) => byMeal[m.k]).map((m) => (
          <Text key={m.k} style={{ fontSize: 11, color: c.ink3 }}>
            {m.label} <Num size={11} color={c.ink2}>{byMeal[m.k]}</Num>
          </Text>
        ))}
        <Text style={{ fontSize: 11, color: over ? c.warn : c.ink3 }}>
          {over ? 'over by ' : ''}
          <Num size={11} color={over ? c.warn : c.ink2}>{over ? total - target : left}</Num>
          {over ? '' : ' left'}
        </Text>
      </View>
    </View>
  );
}
