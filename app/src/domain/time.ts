/** Clock helpers. Times are stored 24h `HH:MM`; am/pm is only ever a display concern. */

export const mins = (t: string): number =>
  parseInt(t.slice(0, 2), 10) * 60 + parseInt(t.slice(3, 5), 10);

export const clock = (m: number): string => {
  const v = ((m % 1440) + 1440) % 1440;
  return `${String(Math.floor(v / 60)).padStart(2, '0')}:${String(v % 60).padStart(2, '0')}`;
};

/** "9 am", "6:30 pm" — zero minutes dropped, because the clutter buys nothing. */
export const ampm = (t: string): string => {
  const m = mins(t);
  const hh = Math.floor(m / 60);
  const mm = m % 60;
  const h12 = hh % 12 || 12;
  return `${h12}${mm ? `:${String(mm).padStart(2, '0')}` : ''} ${hh < 12 ? 'am' : 'pm'}`;
};

export const hourLabel = (hh: number): string => `${hh % 12 || 12}${hh < 12 ? 'a' : 'p'}`;

export const todayISO = (d = new Date()): string =>
  `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;

export const minutesNow = (d = new Date()): number => d.getHours() * 60 + d.getMinutes();

export const DOW_SHORT = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'] as const;
export const DOW_INITIAL = ['S', 'M', 'T', 'W', 'T', 'F', 'S'] as const;
