/** Shared primitives. Every number renders mono, every word sans. */

import React from 'react';
import {
  Modal,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  View,
  type StyleProp,
  type TextStyle,
  type ViewStyle,
} from 'react-native';
import { useTheme } from '../theme/ThemeProvider';
import { radius } from '../theme/tokens';

export function Card({
  children,
  style,
  flush,
}: {
  children: React.ReactNode;
  style?: StyleProp<ViewStyle>;
  flush?: boolean;
}) {
  const { c } = useTheme();
  return (
    <View
      style={[
        {
          backgroundColor: c.surface,
          borderColor: c.line,
          borderWidth: StyleSheet.hairlineWidth * 2,
          borderRadius: radius.card,
          padding: flush ? 0 : 16,
          gap: flush ? 0 : 12,
          overflow: 'hidden',
        },
        style,
      ]}
    >
      {children}
    </View>
  );
}

export function Label({ children, style }: { children: React.ReactNode; style?: StyleProp<TextStyle> }) {
  const { c, mono } = useTheme();
  return (
    <Text
      style={[
        { fontFamily: mono, fontSize: 10, letterSpacing: 1.3, color: c.ink3 },
        style,
      ]}
    >
      {String(children).toUpperCase()}
    </Text>
  );
}

export function Num({
  children,
  size = 13,
  color,
  weight = '500',
}: {
  children: React.ReactNode;
  size?: number;
  color?: string;
  weight?: TextStyle['fontWeight'];
}) {
  const { c, mono } = useTheme();
  return (
    <Text
      style={{
        fontFamily: mono,
        fontSize: size,
        color: color ?? c.ink,
        fontWeight: weight,
        fontVariant: ['tabular-nums'],
      }}
    >
      {children}
    </Text>
  );
}

export function Body({
  children,
  size = 13,
  color,
  style,
}: {
  children: React.ReactNode;
  size?: number;
  color?: string;
  style?: StyleProp<TextStyle>;
}) {
  const { c } = useTheme();
  return <Text style={[{ fontSize: size, color: color ?? c.ink2, lineHeight: size * 1.5 }, style]}>{children}</Text>;
}

export function Pill({
  label,
  onPress,
  tone = 'plain',
  flex,
  disabled,
  mono,
}: {
  label: string;
  onPress?: () => void;
  tone?: 'plain' | 'accent' | 'warn';
  flex?: boolean;
  disabled?: boolean;
  mono?: boolean;
}) {
  const t = useTheme();
  const border = tone === 'accent' ? t.c.accent : tone === 'warn' ? t.c.warn : t.c.line;
  const color = tone === 'accent' ? t.c.accent : tone === 'warn' ? t.c.warn : t.c.ink;
  return (
    <Pressable
      accessibilityRole="button"
      disabled={disabled}
      onPress={onPress}
      style={({ pressed }) => ({
        borderWidth: StyleSheet.hairlineWidth * 2,
        borderColor: border,
        borderRadius: radius.pill,
        paddingVertical: 8,
        paddingHorizontal: 13,
        flex: flex ? 1 : undefined,
        alignItems: 'center',
        opacity: disabled ? 0.45 : pressed ? 0.65 : 1,
        backgroundColor: pressed ? t.c.sunken : 'transparent',
      })}
    >
      <Text
        style={{
          color,
          fontSize: mono ? 12 : 13,
          fontWeight: '500',
          fontFamily: mono ? t.mono : undefined,
        }}
      >
        {label}
      </Text>
    </Pressable>
  );
}

export function PrimaryButton({
  label,
  onPress,
  disabled,
  tone = 'accent',
}: {
  label: string;
  onPress?: () => void;
  disabled?: boolean;
  tone?: 'accent' | 'ghost';
}) {
  const { c } = useTheme();
  const ghost = tone === 'ghost';
  return (
    <Pressable
      accessibilityRole="button"
      disabled={disabled}
      onPress={onPress}
      style={({ pressed }) => ({
        backgroundColor: ghost ? c.surface : c.accent,
        borderWidth: ghost ? StyleSheet.hairlineWidth * 2 : 0,
        borderColor: c.line,
        borderRadius: 12,
        paddingVertical: 13,
        alignItems: 'center',
        opacity: disabled ? 0.45 : pressed ? 0.85 : 1,
      })}
    >
      <Text style={{ color: ghost ? c.ink : c.onAccent, fontSize: 14.5, fontWeight: '600' }}>
        {label}
      </Text>
    </Pressable>
  );
}

export function Chip({ label, tone }: { label: string; tone: 'measured' | 'estimated' }) {
  const { c } = useTheme();
  const fg = tone === 'measured' ? c.accent : c.warn;
  const bg = tone === 'measured' ? c.accentSoft : c.warnSoft;
  return (
    <View
      style={{
        flexDirection: 'row',
        alignItems: 'center',
        gap: 6,
        backgroundColor: bg,
        borderRadius: radius.pill,
        paddingVertical: 4,
        paddingHorizontal: 9,
      }}
    >
      <View style={{ width: 5, height: 5, borderRadius: 3, backgroundColor: fg }} />
      <Text style={{ color: fg, fontSize: 11, fontWeight: '500' }}>{label}</Text>
    </View>
  );
}

export function Meter({
  pct,
  over,
  thin,
  markAt,
}: {
  pct: number;
  over?: boolean;
  thin?: boolean;
  markAt?: number;
}) {
  const { c } = useTheme();
  const h = thin ? 4 : 5;
  return (
    <View style={{ height: h, borderRadius: 3, backgroundColor: c.sunken, overflow: 'visible' }}>
      <View
        style={{
          height: h,
          borderRadius: 3,
          width: `${Math.max(0, Math.min(100, pct))}%`,
          backgroundColor: over ? c.warn : c.accent,
        }}
      />
      {markAt !== undefined && (
        <View
          style={{
            position: 'absolute',
            left: `${markAt}%`,
            top: -2,
            bottom: -2,
            width: 2,
            borderRadius: 1,
            backgroundColor: c.ink,
            opacity: 0.45,
          }}
        />
      )}
    </View>
  );
}

export function Notice({
  children,
  tone = 'plain',
}: {
  children: React.ReactNode;
  tone?: 'plain' | 'warn' | 'accent';
}) {
  const { c } = useTheme();
  const bg = tone === 'warn' ? c.warnSoft : tone === 'accent' ? c.accentSoft : c.sunken;
  const fg = tone === 'warn' ? c.warn : tone === 'accent' ? c.accent : c.ink2;
  return (
    <View style={{ backgroundColor: bg, borderRadius: 10, padding: 12 }}>
      <Text style={{ color: fg, fontSize: 12.5, lineHeight: 18.5 }}>{children}</Text>
    </View>
  );
}

export function Row({ children, gap = 12 }: { children: React.ReactNode; gap?: number }) {
  return <View style={{ flexDirection: 'row', alignItems: 'center', gap }}>{children}</View>;
}

export function Split({ left, right }: { left: React.ReactNode; right: React.ReactNode }) {
  return (
    <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'baseline', gap: 10 }}>
      {left}
      {right}
    </View>
  );
}

/** Bottom sheet. Plain Modal — no gesture library needed for a scrim + slide-up. */
export function Sheet({
  open,
  onClose,
  children,
}: {
  open: boolean;
  onClose: () => void;
  children: React.ReactNode;
}) {
  const { c } = useTheme();
  return (
    <Modal visible={open} transparent animationType="slide" onRequestClose={onClose}>
      <Pressable style={{ flex: 1, backgroundColor: c.scrim }} onPress={onClose} />
      <View
        style={{
          backgroundColor: c.surface,
          borderTopLeftRadius: radius.sheet,
          borderTopRightRadius: radius.sheet,
          borderTopWidth: StyleSheet.hairlineWidth * 2,
          borderColor: c.line,
          maxHeight: '88%',
        }}
      >
        <View
          style={{
            width: 34,
            height: 4,
            borderRadius: 2,
            backgroundColor: c.line,
            alignSelf: 'center',
            marginTop: 8,
          }}
        />
        <ScrollView
          contentContainerStyle={{ padding: 18, paddingBottom: 32, gap: 15 }}
          keyboardShouldPersistTaps="handled"
        >
          {children}
        </ScrollView>
      </View>
    </Modal>
  );
}

export function SegButton({
  options,
  value,
  onChange,
  compact,
}: {
  options: { v: string; label: string }[];
  value: string;
  onChange: (v: string) => void;
  compact?: boolean;
}) {
  const { c } = useTheme();
  return (
    <View style={{ flexDirection: 'row', gap: compact ? 5 : 6 }}>
      {options.map((o) => {
        const on = o.v === value;
        return (
          <Pressable
            key={o.v}
            accessibilityRole="button"
            accessibilityState={{ selected: on }}
            onPress={() => onChange(o.v)}
            style={{
              flex: 1,
              borderWidth: StyleSheet.hairlineWidth * 2,
              borderColor: on ? c.accent : c.line,
              backgroundColor: on ? c.accentSoft : 'transparent',
              borderRadius: compact ? 8 : radius.control,
              paddingVertical: compact ? 6 : 9,
              alignItems: 'center',
            }}
          >
            <Text
              style={{
                color: on ? c.accent : c.ink2,
                fontSize: compact ? 12 : 13,
                fontWeight: '500',
              }}
            >
              {o.label}
            </Text>
          </Pressable>
        );
      })}
    </View>
  );
}
