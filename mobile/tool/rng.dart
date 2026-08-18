/// Seeded RNG, bit-identical to the TypeScript original.
///
/// This has to match exactly or the ported simulation produces different numbers for
/// reasons that have nothing to do with the engine — and we would not be able to tell
/// a faithful port from a broken one.
///
/// JS `Math.imul` is a signed 32-bit multiply and `>>>` operates on ToUint32. Dart ints
/// are 64-bit, so every step is masked back to 32 bits; the low 32 bits of a wrapped
/// 64-bit product are the same as the low 32 bits of the JS result.
library;

import 'dart:math' as math;

int _u32(int x) => x & 0xFFFFFFFF;
int _imul(int a, int b) => _u32(_u32(a) * _u32(b));

double Function() mulberry32(int seed) {
  var a = _u32(seed);
  return () {
    a = _u32(a + 0x6d2b79f5);
    var t = a;
    t = _imul(t ^ (t >>> 15), t | 1);
    t = _u32(t ^ _u32(t + _imul(t ^ (t >>> 7), t | 61)));
    return _u32(t ^ (t >>> 14)) / 4294967296.0;
  };
}

/// Box–Muller.
double gaussian(double Function() rand) {
  var u = 0.0;
  var v = 0.0;
  while (u == 0) {
    u = rand();
  }
  while (v == 0) {
    v = rand();
  }
  return math.sqrt(-2 * math.log(u)) * math.cos(2 * math.pi * v);
}
