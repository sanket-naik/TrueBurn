import React from 'react';
import { Pressable, Text, TextInput, View } from 'react-native';
import { intakeTarget } from '@core/targets';
import type { ActivityLevel, FormulaVariant } from '@core/types';
import { Body, Label, Notice, Num, Pill, PrimaryButton, Row, SegButton, Sheet } from '../components/ui';
import { ampm } from '../domain/time';
import { useReport } from '../hooks/useReport';
import { patchProfile, patchSettings } from '../store/actions';
import { useStore } from '../store/store';
import { useTheme, type ThemeChoice } from '../theme/ThemeProvider';

const RATES = [0.25, 0.5, 0.75, 1.0];
const ACTIVITY: { v: ActivityLevel; label: string }[] = [
  { v: 'sedentary', label: 'Sedentary' },
  { v: 'light', label: 'Light' },
  { v: 'moderate', label: 'Moderate' },
  { v: 'active', label: 'Active' },
];

export function SettingsSheet({ open, onClose }: { open: boolean; onClose: () => void }) {
  const { c, mono } = useTheme();
  const s = useStore((x) => x);
  const { report } = useReport();

  const kg = report.weight.trend ?? 75;
  const age = new Date().getFullYear() - s.profile.birthYear;
  const t = intakeTarget(s.profile, report.energy.tdee.kcal, kg, age);

  const input = {
    fontSize: 14,
    color: c.ink,
    backgroundColor: c.sunken,
    borderWidth: 1,
    borderColor: c.line,
    borderRadius: 10,
    paddingHorizontal: 12,
    paddingVertical: 10,
    fontFamily: mono,
    flex: 1,
  } as const;

  return (
    <Sheet open={open} onClose={onClose}>
      <Text style={{ fontSize: 23, fontWeight: '600', color: c.ink }}>Settings</Text>

      {/* Appearance first: it is the setting people reach for most. */}
      <View style={{ gap: 8 }}>
        <Label>Appearance</Label>
        <SegButton
          value={s.settings.theme}
          onChange={(v) => patchSettings({ theme: v as ThemeChoice })}
          options={[
            { v: 'light', label: 'Light' },
            { v: 'dark', label: 'Dark' },
            { v: 'auto', label: 'Auto' },
          ]}
        />
        <Body size={12} color={c.ink3}>
          Auto follows whatever your phone is set to, and changes with it through the day.
        </Body>
      </View>

      <View style={{ gap: 8 }}>
        <Label>Goal</Label>
        <SegButton
          value={s.profile.goal.kind}
          onChange={(v) =>
            patchProfile({
              goal:
                v === 'maintain'
                  ? { kind: 'maintain' }
                  : { kind: v as 'lose' | 'gain', kgPerWeek: 0.5 },
            })
          }
          options={[
            { v: 'lose', label: 'Lose' },
            { v: 'maintain', label: 'Maintain' },
            { v: 'gain', label: 'Gain' },
          ]}
        />
        {s.profile.goal.kind !== 'maintain' && (
          <SegButton
            value={String(s.profile.goal.kgPerWeek)}
            onChange={(v) =>
              patchProfile({
                goal: { kind: s.profile.goal.kind as 'lose' | 'gain', kgPerWeek: parseFloat(v) },
              })
            }
            options={RATES.map((r) => ({ v: String(r), label: `${r} kg` }))}
          />
        )}
        <Notice tone="accent">
          Your daily target is {t.kcal ?? '—'} kcal — measured expenditure{' '}
          {Math.round(report.energy.tdee.kcal)} minus the deficit for this goal.
        </Notice>
        {t.warnings.map((w) => (
          <Notice key={w} tone="warn">{w}</Notice>
        ))}
      </View>

      <View style={{ gap: 8 }}>
        <Label>About you</Label>
        <Row gap={9}>
          <TextInput
            style={input}
            keyboardType="number-pad"
            value={String(s.profile.heightCm)}
            onChangeText={(v) => patchProfile({ heightCm: parseInt(v, 10) || 175 })}
          />
          <Body size={13} color={c.ink3}>cm tall</Body>
        </Row>
        <Row gap={9}>
          <TextInput
            style={input}
            keyboardType="number-pad"
            value={String(s.profile.birthYear)}
            onChangeText={(v) => patchProfile({ birthYear: parseInt(v, 10) || 1994 })}
          />
          <Body size={13} color={c.ink3}>year of birth</Body>
        </Row>
      </View>

      <View style={{ gap: 8 }}>
        <Label>Starting estimate</Label>
        <SegButton
          value={s.profile.formulaVariant}
          onChange={(v) => patchProfile({ formulaVariant: v as FormulaVariant })}
          options={[
            { v: 'mifflin-male', label: 'Formula A' },
            { v: 'mifflin-female', label: 'Formula B' },
          ]}
        />
        <SegButton
          value={s.profile.activityLevel}
          onChange={(v) => patchProfile({ activityLevel: v as ActivityLevel })}
          options={ACTIVITY.map((a) => ({ v: a.v, label: a.label }))}
        />
        <Body size={12} color={c.ink3}>
          These only shape the first three weeks. Once Baseline has enough weigh-ins it measures
          your expenditure directly and stops using them. Pick the basal formula that fits you
          rather than having one inferred.
        </Body>
      </View>

      <View style={{ gap: 8 }}>
        <Label>Reminders</Label>
        <Row gap={9}>
          <TextInput
            style={input}
            value={s.settings.quietFrom}
            onChangeText={(v) => patchSettings({ quietFrom: v })}
          />
          <TextInput
            style={input}
            value={s.settings.quietTo}
            onChangeText={(v) => patchSettings({ quietTo: v })}
          />
        </Row>
        <Body size={12} color={c.ink3}>
          Nothing fires between {ampm(s.settings.quietFrom)} and {ampm(s.settings.quietTo)}.
        </Body>
      </View>

      <View style={{ gap: 8 }}>
        <Label>Your data</Label>
        <Body size={12} color={c.ink3}>
          Everything stays on this phone. There is no account and nothing is uploaded.
        </Body>
      </View>

      <PrimaryButton label="Done" onPress={onClose} />
    </Sheet>
  );
}
