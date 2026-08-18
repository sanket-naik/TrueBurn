/**
 * Adherence timeline — one row per routine, each with a thin yesterday row beneath.
 *
 * Merging every routine onto two shared rows was tried first and failed twice: dots at
 * nearby times collided into blobs, and a missed marker was unattributable — you could
 * see something lapsed at 5 pm but not what. Within one routine the times are distinct
 * by definition, so per-routine rows cannot collide (§7.3).
 */

import React, { useState } from 'react';
import { View } from 'react-native';
import Svg, { Circle, Line, Text as SvgText } from 'react-native-svg';
import { TEMPLATES, dueOn, type Routine } from '../domain/routines';
import { hourLabel, mins } from '../domain/time';
import { useTheme } from '../theme/ThemeProvider';

const HOURS = [6, 10, 14, 18, 22];
const FROM = 6 * 60;
const TO = 22 * 60 + 30;

export function Timeline({
  routines,
  nowMin,
  todayDow,
  paused,
}: {
  routines: Routine[];
  nowMin: number;
  todayDow: number;
  paused: boolean;
}) {
  const { c, mono } = useTheme();
  const [w, setW] = useState(300);

  const active = routines.filter((r) => r.active);
  if (!active.length) return null;

  const L = 54;
  const R = 8;
  const TOP = 4;
  const ROW = 30;
  const AX = 14;
  const height = TOP + active.length * ROW + AX;
  const yestDow = (todayDow + 6) % 7;

  const X = (m: number) => L + ((m - FROM) / (TO - FROM)) * (w - L - R);

  return (
    <View onLayout={(e) => setW(e.nativeEvent.layout.width)} style={{ height }}>
      <Svg width={w} height={height}>
        {HOURS.map((hh) => (
          <React.Fragment key={hh}>
            <Line x1={X(hh * 60)} x2={X(hh * 60)} y1={TOP} y2={height - AX} stroke={c.line} strokeWidth={1} />
            <SvgText
              x={X(hh * 60)}
              y={height - 3}
              fill={c.ink3}
              fontSize={8}
              fontFamily={mono}
              textAnchor="middle"
            >
              {hourLabel(hh)}
            </SvgText>
          </React.Fragment>
        ))}

        {active.map((r, i) => {
          const yT = TOP + i * ROW + 11;
          const yY = yT + 11;
          return (
            <React.Fragment key={r.id}>
              <Line x1={L} x2={w - R} y1={yT} y2={yT} stroke={c.line} strokeWidth={1} />
              <Line x1={L} x2={w - R} y1={yY} y2={yY} stroke={c.line} strokeWidth={1} opacity={0.55} />
              <SvgText x={0} y={yT + 3} fill={c.ink2} fontSize={8} fontFamily={mono}>
                {TEMPLATES[r.type].label.toUpperCase()}
              </SvgText>
              <SvgText x={0} y={yY + 2.5} fill={c.ink3} fontSize={6.5} fontFamily={mono}>
                YEST
              </SvgText>

              {dueOn(r, todayDow) &&
                r.times.map((t) => {
                  const done = r.done.includes(t);
                  const lapsed = mins(t) < nowMin && !paused;
                  if (done) return <Circle key={`t${t}`} cx={X(mins(t))} cy={yT} r={4} fill={c.accent} />;
                  if (lapsed)
                    return (
                      <Circle
                        key={`t${t}`}
                        cx={X(mins(t))}
                        cy={yT}
                        r={3.4}
                        fill="none"
                        stroke={c.warn}
                        strokeWidth={1.7}
                      />
                    );
                  return <Circle key={`t${t}`} cx={X(mins(t))} cy={yT} r={3.4} fill={c.ink3} opacity={0.3} />;
                })}

              {dueOn(r, yestDow) &&
                r.times.map((t) =>
                  r.doneYesterday.includes(t) ? (
                    <Circle key={`y${t}`} cx={X(mins(t))} cy={yY} r={2.4} fill={c.accent} opacity={0.45} />
                  ) : (
                    <Circle
                      key={`y${t}`}
                      cx={X(mins(t))}
                      cy={yY}
                      r={2.2}
                      fill="none"
                      stroke={c.warn}
                      strokeWidth={1.3}
                      opacity={0.5}
                    />
                  ),
                )}
            </React.Fragment>
          );
        })}

        <Line
          x1={X(nowMin)}
          x2={X(nowMin)}
          y1={TOP}
          y2={height - AX}
          stroke={c.ink}
          strokeWidth={1}
          opacity={0.35}
          strokeDasharray="2 2"
        />
      </Svg>
    </View>
  );
}
