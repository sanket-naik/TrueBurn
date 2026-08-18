/**
 * A very small external store. No dependency, `useSyncExternalStore` under the hood.
 *
 * Every mutation goes through `set`, which persists. That single choke point is what
 * keeps Today and Routines from disagreeing — they are two views of one object, never
 * two copies (REQUIREMENTS §7.4).
 */

import { useSyncExternalStore } from 'react';
import { todayISO } from '../domain/time';
import { initialState, type AppState } from './state';
import { load, save } from './persist';

type Listener = () => void;

let state: AppState = initialState(todayISO());
const listeners = new Set<Listener>();

const emit = () => listeners.forEach((l) => l());

export function getState(): AppState {
  return state;
}

export function set(fn: (s: AppState) => AppState): void {
  state = fn(state);
  emit();
  if (state.hydrated) void save(state);
}

export function subscribe(l: Listener): () => void {
  listeners.add(l);
  return () => listeners.delete(l);
}

export function useStore<T>(select: (s: AppState) => T): T {
  return useSyncExternalStore(
    subscribe,
    () => select(state),
    () => select(state),
  );
}

export async function hydrate(): Promise<void> {
  const restored = await load();
  state = restored
    ? { ...restored, hydrated: true }
    : { ...initialState(todayISO()), hydrated: true };
  emit();
}
