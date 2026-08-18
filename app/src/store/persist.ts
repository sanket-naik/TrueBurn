/**
 * Local-first persistence. No account, nothing uploaded (REQUIREMENTS §1).
 *
 * Writes are debounced because quick-add taps arrive in bursts, and a flush on every
 * keystroke of a food name would thrash the disk for no benefit.
 */

import AsyncStorage from '@react-native-async-storage/async-storage';
import type { AppState } from './state';

const KEY = 'baseline.state.v1';
const DEBOUNCE_MS = 400;

let timer: ReturnType<typeof setTimeout> | null = null;
let pending: AppState | null = null;

export async function load(): Promise<AppState | null> {
  try {
    const raw = await AsyncStorage.getItem(KEY);
    if (!raw) return null;
    const parsed = JSON.parse(raw) as AppState;
    // A stored shape from an older build should degrade to a fresh start rather than
    // crashing the app on a missing field.
    if (!parsed || typeof parsed !== 'object' || !parsed.profile) return null;
    return parsed;
  } catch {
    return null;
  }
}

export function save(s: AppState): void {
  pending = s;
  if (timer) return;
  timer = setTimeout(() => {
    timer = null;
    const snapshot = pending;
    pending = null;
    if (snapshot) {
      void AsyncStorage.setItem(KEY, JSON.stringify({ ...snapshot, hydrated: false })).catch(
        () => {},
      );
    }
  }, DEBOUNCE_MS);
}

export async function wipe(): Promise<void> {
  try {
    await AsyncStorage.removeItem(KEY);
  } catch {
    /* nothing to recover from — the caller resets state regardless */
  }
}
