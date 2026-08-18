import React, { useEffect, useState } from 'react';
import { Pressable, Text, TextInput, View } from 'react-native';
import { waterTargetMl } from '@core/targets';
import { Body, Card, Label, Notice, Num, Pill, PrimaryButton, Row, SegButton, Sheet, Split } from '../components/ui';
import { TEMPLATES, type Routine, type RoutineType } from '../domain/routines';
import { DOW_INITIAL, DOW_SHORT, ampm, clock, mins } from '../domain/time';
import { deleteRoutine, newRoutine, upsertRoutine } from '../store/actions';
import { useReport } from '../hooks/useReport';
import { useTheme } from '../theme/ThemeProvider';

export function RoutineSheet({
  routine,
  isNew,
  onClose,
}: {
  routine: Routine | null;
  isNew: boolean;
  onClose: () => void;
}) {
  const { c, mono } = useTheme();
  const { report } = useReport();
  const [d, setD] = useState<Routine | null>(routine);

  useEffect(() => setD(routine), [routine]);
  if (!d) return null;

  const perDay = d.times.length;
  const perWeek = perDay * d.days.length;
  const dense = perDay > 6;

  const wTarget = report.water.targetMl ?? waterTargetMl(report.weight.trend ?? 70);
  const delivers = d.times.length * d.amountMl;

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
  } as const;

  const setTime = (i: number, value: string) =>
    setD((x) => (x ? { ...x, times: x.times.map((t, j) => (j === i ? value : t)) } : x));

  const addTime = () =>
    setD((x) => {
      if (!x) return x;
      const last = x.times[x.times.length - 1] ?? '09:00';
      return { ...x, times: [...x.times, clock(Math.min(1380, mins(last) + 120))].sort() };
    });

  return (
    <Sheet open onClose={onClose}>
      <Text style={{ fontSize: 23, fontWeight: '600', color: c.ink }}>
        {isNew ? 'New routine' : 'Edit routine'}
      </Text>

      <View style={{ gap: 8 }}>
        <Label>Type</Label>
        <SegButton
          value={d.type}
          onChange={(v) => {
            const t = v as RoutineType;
            // Create mode loads the template whole; edit mode changes only the type, so
            // an existing schedule is never silently overwritten.
            setD((x) => (x ? (isNew ? { ...newRoutine(t), id: x.id } : { ...x, type: t }) : x));
          }}
          options={(Object.keys(TEMPLATES) as RoutineType[]).map((k) => ({
            v: k,
            label: TEMPLATES[k].label,
          }))}
        />
        {isNew && (
          <Body size={12} color={c.ink3}>
            Picking a type fills in a ready-made schedule. Change anything below.
          </Body>
        )}
      </View>

      <View style={{ gap: 8 }}>
        <Label>Name</Label>
        <TextInput
          style={[input, { fontFamily: undefined }]}
          value={d.name}
          onChangeText={(v) => setD((x) => (x ? { ...x, name: v } : x))}
          placeholder={`${TEMPLATES[d.type].label} reminder`}
          placeholderTextColor={c.ink3}
        />
      </View>

      <View style={{ gap: 8 }}>
        <Label>Remind me at</Label>
        {d.times.map((t, i) => (
          <Row key={`${t}-${i}`} gap={8}>
            <TextInput
              style={[input, { flex: 1 }]}
              value={t}
              onChangeText={(v) => setTime(i, v)}
              placeholder="09:00"
              placeholderTextColor={c.ink3}
            />
            <Body size={12} color={c.ink3}>{/\d\d:\d\d/.test(t) ? ampm(t) : ''}</Body>
            {d.times.length > 1 && (
              <Pill
                label="×"
                onPress={() => setD((x) => (x ? { ...x, times: x.times.filter((_, j) => j !== i) } : x))}
              />
            )}
          </Row>
        ))}
        <Pill label="+ Add another time" tone="accent" onPress={addTime} />
      </View>

      <View style={{ gap: 8 }}>
        <Label>Days</Label>
        <Row gap={5}>
          {DOW_INITIAL.map((lab, i) => {
            const on = d.days.includes(i);
            return (
              <Pressable
                key={i}
                accessibilityLabel={DOW_SHORT[i]}
                onPress={() =>
                  setD((x) =>
                    x
                      ? {
                          ...x,
                          days: on
                            ? x.days.length > 1
                              ? x.days.filter((v) => v !== i)
                              : x.days
                            : [...x.days, i].sort(),
                        }
                      : x,
                  )
                }
                style={{
                  flex: 1,
                  borderWidth: 1,
                  borderColor: on ? c.accent : c.line,
                  backgroundColor: on ? c.accentSoft : 'transparent',
                  borderRadius: 9,
                  paddingVertical: 8,
                  alignItems: 'center',
                }}
              >
                <Text style={{ fontFamily: mono, fontSize: 11, color: on ? c.accent : c.ink3 }}>
                  {lab}
                </Text>
              </Pressable>
            );
          })}
        </Row>
      </View>

      {d.type === 'water' && (
        <View style={{ gap: 8 }}>
          <Label>Each reminder logs</Label>
          <Row gap={9}>
            <TextInput
              style={[input, { flex: 1 }]}
              value={String(d.amountMl)}
              keyboardType="number-pad"
              onChangeText={(v) => setD((x) => (x ? { ...x, amountMl: parseInt(v, 10) || 0 } : x))}
            />
            <Body size={13} color={c.ink3}>ml, added to Today</Body>
          </Row>
          {/* A schedule that quietly under-delivers is worse than no schedule, because
              the user believes hydration is handled and stops thinking about it. */}
          <Notice tone={delivers >= wTarget ? 'accent' : 'warn'}>
            {d.times.length} × {d.amountMl} ml is {(delivers / 1000).toFixed(2)} L a day
            {delivers >= wTarget
              ? ` — covers your ${(wTarget / 1000).toFixed(2)} L recommended intake.`
              : `, ${Math.round((delivers / wTarget) * 100)}% of your ${(wTarget / 1000).toFixed(2)} L recommended intake. You would still need ${((wTarget - delivers) / 1000).toFixed(2)} L by hand — add a time, or raise the amount.`}
          </Notice>
        </View>
      )}

      <View style={{ gap: 8 }}>
        <Label>Run for</Label>
        <Row gap={9}>
          <TextInput
            style={[input, { flex: 1 }]}
            value={String(d.totalDays)}
            keyboardType="number-pad"
            onChangeText={(v) =>
              setD((x) => (x ? { ...x, totalDays: Math.max(1, Math.min(365, parseInt(v, 10) || 1)) } : x))
            }
          />
          <Body size={13} color={c.ink3}>days, then it retires</Body>
        </Row>
      </View>

      <View style={{ gap: 8 }}>
        <Label>Notification text</Label>
        <TextInput
          style={[input, { fontFamily: undefined }]}
          value={d.message}
          onChangeText={(v) => setD((x) => (x ? { ...x, message: v } : x))}
          placeholder="Your own words"
          placeholderTextColor={c.ink3}
        />
      </View>

      <Card style={{ backgroundColor: c.sunken }}>
        <Label>Baseline · now</Label>
        <Text style={{ fontSize: 13.5, fontWeight: '600', color: c.ink }}>
          {d.name || `${TEMPLATES[d.type].label} reminder`}
        </Text>
        <Body>
          {d.message || 'Your own words appear here.'}
          {d.type === 'water' && d.amountMl ? ` Marking done logs ${d.amountMl} ml.` : ''}
        </Body>
      </Card>

      <Split
        left={
          <Body size={12.5} color={dense ? c.warn : c.ink2}>
            <Num size={12.5} color={dense ? c.warn : c.ink}>{perDay}</Num> a day,{' '}
            <Num size={12.5} color={dense ? c.warn : c.ink}>{perWeek}</Num> a week
            {dense ? ' — dense enough that people usually mute it.' : '.'}
          </Body>
        }
        right={null}
      />

      <Row gap={9}>
        <View style={{ flex: 1 }}>
          <Pill flex label="Cancel" onPress={onClose} />
        </View>
        <View style={{ flex: 1 }}>
          <PrimaryButton
            label={isNew ? 'Start routine' : 'Save changes'}
            onPress={() => {
              upsertRoutine({
                ...d,
                name: d.name.trim() || `${TEMPLATES[d.type].label} reminder`,
                message: d.message.trim() || 'Time for this.',
                done: d.done.filter((t) => d.times.includes(t)),
              });
              onClose();
            }}
          />
        </View>
      </Row>

      {!isNew && (
        <Pressable onPress={() => { deleteRoutine(d.id); onClose(); }}>
          <Text style={{ color: c.warn, fontSize: 13, fontWeight: '500', textAlign: 'center' }}>
            Delete this routine
          </Text>
        </Pressable>
      )}
    </Sheet>
  );
}
