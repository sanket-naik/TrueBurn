import type { LogBook, Profile } from '@core/types';
import type { Food, Meal } from '../domain/foods';
import type { Routine } from '../domain/routines';
import type { ThemeChoice } from '../theme/ThemeProvider';

/** A logged food item. `source` lets a routine-created water entry be reversed exactly. */
export interface Entry {
  id: string;
  date: string;
  name: string;
  unit: string;
  qty: number;
  kcal: number;
  meal: Meal;
}

export interface WaterLog {
  date: string;
  /** Millilitres logged by hand and not yet attributed to a reminder. */
  manualMl: number;
}

export interface Settings {
  theme: ThemeChoice;
  weighAt: string;
  quietFrom: string;
  quietTo: string;
  notificationsGranted: boolean;
}

export interface AppState {
  /** Set once the user has answered enough for a formula estimate. */
  profileSet: boolean;
  profile: Profile;
  /** Weigh-ins live in the core's LogBook shape so the engine consumes them directly. */
  log: LogBook;
  entries: Entry[];
  water: WaterLog;
  routines: Routine[];
  recents: string[];
  customFoods: Food[];
  settings: Settings;
  /** Bumped on load so the UI can wait for persistence rather than flashing empty. */
  hydrated: boolean;
}

export const DEFAULT_PROFILE: Profile = {
  heightCm: 175,
  birthYear: 1994,
  formulaVariant: 'mifflin-male',
  activityLevel: 'light',
  goal: { kind: 'lose', kgPerWeek: 0.5 },
};

export const initialState = (today: string): AppState => ({
  profileSet: false,
  profile: DEFAULT_PROFILE,
  log: { weighIns: [], food: [], water: [] },
  entries: [],
  water: { date: today, manualMl: 0 },
  routines: [],
  recents: [],
  customFoods: [],
  settings: {
    theme: 'auto',
    weighAt: '07:30',
    quietFrom: '22:00',
    quietTo: '07:00',
    notificationsGranted: false,
  },
  hydrated: false,
});
