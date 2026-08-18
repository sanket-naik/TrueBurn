import React, { useMemo, useState } from 'react';
import { Pressable, Text, TextInput, View } from 'react-native';
import { Body, Card, Label, Num, Pill, PrimaryButton, Row, Sheet, Split } from '../components/ui';
import { browseGroups, mealFor, mealLabel, search, type Food } from '../domain/foods';
import { minutesNow } from '../domain/time';
import { addCustomFood, addEntry } from '../store/actions';
import { useStore } from '../store/store';
import { useTheme } from '../theme/ThemeProvider';

export function FoodSheet({
  open,
  onClose,
  consumed,
  target,
  paused,
}: {
  open: boolean;
  onClose: () => void;
  consumed: number;
  target: number | null;
  paused: boolean;
}) {
  const { c, mono } = useTheme();
  const recents = useStore((s) => s.recents);
  const custom = useStore((s) => s.customFoods);

  const [q, setQ] = useState('');
  const [pick, setPick] = useState<Food | null>(null);
  const [qty, setQty] = useState(1);
  const [customOpen, setCustomOpen] = useState(false);
  const [cName, setCName] = useState('');
  const [cKcal, setCKcal] = useState('');

  const groups = useMemo(() => browseGroups(recents, custom), [recents, custom]);
  const results = useMemo(() => (q.trim() ? search(q, recents, custom) : []), [q, recents, custom]);

  const reset = () => {
    setQ('');
    setPick(null);
    setQty(1);
    setCustomOpen(false);
    setCName('');
    setCKcal('');
  };
  const close = () => {
    reset();
    onClose();
  };

  const input = {
    fontSize: 14,
    color: c.ink,
    backgroundColor: c.sunken,
    borderWidth: 1,
    borderColor: c.line,
    borderRadius: 10,
    paddingHorizontal: 12,
    paddingVertical: 10,
  } as const;

  // ---- add your own -------------------------------------------------------
  if (open && customOpen) {
    const kc = parseInt(cKcal, 10) || 0;
    return (
      <Sheet open={open} onClose={close}>
        <Text style={{ fontSize: 23, fontWeight: '600', color: c.ink }}>Add your own</Text>
        <View style={{ gap: 8 }}>
          <Label>What is it</Label>
          <TextInput style={input} value={cName} onChangeText={setCName} placeholder="Amma's sambar" placeholderTextColor={c.ink3} />
        </View>
        <View style={{ gap: 8 }}>
          <Label>Calories in one serving</Label>
          <TextInput
            style={[input, { fontFamily: mono }]}
            value={cKcal}
            onChangeText={setCKcal}
            keyboardType="number-pad"
            placeholder="160"
            placeholderTextColor={c.ink3}
          />
        </View>
        <Body size={12} color={c.ink3}>
          Saved for reuse, so next time it is one tap. A rough number you use every time beats an
          exact number you re-guess — re-guessing biases the expenditure measurement.
        </Body>
        <Row gap={9}>
          <View style={{ flex: 1 }}>
            <Pill flex label="Back" onPress={() => setCustomOpen(false)} />
          </View>
          <View style={{ flex: 1 }}>
            <PrimaryButton
              label="Save and add"
              disabled={!cName.trim() || !kc}
              onPress={() => {
                addCustomFood(cName, kc, paused);
                close();
              }}
            />
          </View>
        </Row>
      </Sheet>
    );
  }

  // ---- quantity + projection ---------------------------------------------
  if (open && pick) {
    const kcal = Math.round(pick.k * qty);
    const after = consumed + kcal;
    return (
      <Sheet open={open} onClose={close}>
        <Row>
          <Text style={{ flex: 1, fontSize: 23, fontWeight: '600', color: c.ink }}>{pick.n}</Text>
          <Num size={11} color={c.ink3}>{mealLabel(mealFor(minutesNow())).toUpperCase()}</Num>
        </Row>

        <Row gap={12}>
          <Pill label="−" onPress={() => setQty((v) => Math.max(0.5, v <= 2 ? v - 0.5 : v - 1))} />
          <View style={{ flex: 1, alignItems: 'center' }}>
            <Num size={20}>{qty % 1 ? qty.toFixed(1) : qty}</Num>
            <Body size={11.5} color={c.ink3}>× {pick.u}</Body>
          </View>
          <Pill label="+" onPress={() => setQty((v) => Math.min(20, v < 2 ? v + 0.5 : v + 1))} />
        </Row>

        {/* Show where this lands before committing, so the decision is informed rather
            than something you check afterwards and regret. */}
        <Card style={{ backgroundColor: c.sunken }}>
          <Split left={<Body>Adding</Body>} right={<Num size={17}>{kcal} kcal</Num>} />
          {target !== null && (
            <Split
              left={<Body size={12}>Takes you to <Num size={12}>{after}</Num> of <Num size={12}>{target}</Num></Body>}
              right={
                <Body size={12} color={after > target ? c.warn : c.ink2}>
                  {after > target ? `over by ${after - target}` : `${target - after} left`}
                </Body>
              }
            />
          )}
        </Card>

        <Row gap={9}>
          <View style={{ flex: 1 }}>
            <Pill flex label="Back" onPress={() => setPick(null)} />
          </View>
          <View style={{ flex: 1 }}>
            <PrimaryButton
              label={`Add ${kcal} kcal`}
              onPress={() => {
                addEntry(pick, qty, paused);
                close();
              }}
            />
          </View>
        </Row>
      </Sheet>
    );
  }

  // ---- browse / search ----------------------------------------------------
  const Item = ({ f }: { f: Food }) => (
    <Pressable
      onPress={() => {
        setPick(f);
        setQty(1);
      }}
      style={({ pressed }) => ({
        flexDirection: 'row',
        alignItems: 'center',
        gap: 10,
        paddingVertical: 9,
        paddingHorizontal: 10,
        borderRadius: 10,
        backgroundColor: pressed ? c.sunken : 'transparent',
      })}
    >
      <View style={{ flex: 1 }}>
        <Text style={{ fontSize: 13.5, color: c.ink }}>{f.n}</Text>
        <Text style={{ fontSize: 11.5, color: c.ink3 }}>{f.u}</Text>
      </View>
      <Num size={12.5} color={c.ink2}>{f.k}</Num>
    </Pressable>
  );

  return (
    <Sheet open={open} onClose={close}>
      <Text style={{ fontSize: 23, fontWeight: '600', color: c.ink }}>Add food</Text>
      <TextInput
        style={input}
        value={q}
        onChangeText={setQ}
        placeholder="Search dal, roti, coffee…"
        placeholderTextColor={c.ink3}
      />

      {q.trim() ? (
        <View>
          <Label>{results.length} match{results.length === 1 ? '' : 'es'}, lightest first</Label>
          {results.map((f) => <Item key={f.n} f={f} />)}
          {!results.length && <Body>Nothing matches. Add it as your own below.</Body>}
        </View>
      ) : (
        groups.map((g) => (
          <View key={g.label}>
            <Label>{g.label}</Label>
            {g.items.map((f) => <Item key={f.n} f={f} />)}
          </View>
        ))
      )}

      <Pill label="+ Add your own food" onPress={() => { setCName(q); setCustomOpen(true); }} />
    </Sheet>
  );
}
