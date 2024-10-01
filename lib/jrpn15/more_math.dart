/*
Copyright (c) 2023-2024 William Foote

This program is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation; either version 3 of the License, or (at your option) any later
version.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

You should have received a copy of the GNU General Public License along with
this program; if not, see https://www.gnu.org/licenses/ .

*/

library;

import 'dart:math';

import 'package:jrpn/m/model.dart';

///
/// Port of Java implementation of Lanczos approximation of the Gamma function,
/// from https://rosettacode.org/wiki/Gamma_function#Java.  It is offered
/// under CC BY-SA 4.0 - https://creativecommons.org/licenses/by-sa/4.0/
///
double laGamma(double x) {
  const p = [
    0.99999999999980993,
    676.5203681218851,
    -1259.1392167224028,
    771.32342877765313,
    -176.61502916214059,
    12.507343278686905,
    -0.13857109526572012,
    9.9843695780195716e-6,
    1.5056327351493116e-7
  ];
  int g = 7;
  if (x < 0.5) {
    return pi / (sin(pi * x) * laGamma(1 - x));
  }

  x -= 1;
  double a = p[0];
  double t = x + g + 0.5;
  for (int i = 1; i < p.length; i++) {
    a += p[i] / (x + i);
  }

  return sqrt(2 * pi) * pow(t, x + 0.5) * exp(-t) * a;
}

Value factorial(Value x) {
  final xf = DecimalFP22(x);
  final zero = DecimalFP22(Value.zero);
  if (xf >= DecimalFP22(Value.fromDouble(70))) {
    throw FloatOverflow(Value.fMaxValue);
  } else if (xf >= zero && x.fracOp() == Value.zero) {
    return factorialOfInt(xf).toValue();
  } else {
    return Value.fromDouble(laGamma(x.asDouble + 1));
  }
}

DecimalFP22 factorialOfInt(DecimalFP22 x) {
  final one = DecimalFP22.tenTo(0);
  var result = one;
  for (var i = one; i <= x; i = i + one) {
    result *= i;
  }
  return result;
}

Value permutations(Value nv, Value kv, {DecimalFP22? initial}) {
  if (nv.fracOp() != Value.zero || kv.fracOp() != Value.zero) {
    throw CalculatorError(0);
  }
  final one = DecimalFP22.tenTo(0);
  final zero = DecimalFP22(Value.zero);
  initial ??= one;
  final n = DecimalFP22(nv);
  final k = DecimalFP22(kv);
  if (n < zero || k < zero || k > n) {
    throw CalculatorError(0);
  } else if (k > DecimalFP22(Value.fromDouble(70))) {
    throw FloatOverflow(Value.fMaxValue);
  } else if (n - k <= one) {
    return factorialOfInt(n).toValue();
  }
  var result = initial;
  for (var i = (n - k) + one; i <= n; i = i + one) {
    result *= i;
  }
  return result.toValue();
}

Value binomialCoefficient(Value nv, Value kv) {
  if (nv.fracOp() != Value.zero || kv.fracOp() != Value.zero) {
    throw CalculatorError(0);
  }
  final n = DecimalFP22(nv);
  var k = DecimalFP22(kv);
  final zero = DecimalFP22(Value.zero);
  final one = DecimalFP22.tenTo(0);
  if (n < zero || k < zero || k > n) {
    throw CalculatorError(0);
  }
  DecimalFP22 tmp = n - k;
  if (tmp < k) {
    k = tmp; // k = min(k, n-k)
  }
  if (k > DecimalFP22(Value.fromDouble(200))) {
    // Enough to overflow the 15C
    throw FloatOverflow(Value.fMaxValue);
  } else if (k == one) {
    return n.toValue();
  } else if (n > DecimalFP22(Value.fromDouble(10000))) {
    if (k > DecimalFP22(Value.fromDouble(36))) {
      // Enough to overflow the 15C
      throw FloatOverflow(Value.fMaxValue);
    }
    return permutations(n.toValue(), k.toValue(),
        initial: one / factorialOfInt(k));
  }
  final int ki = k.asInt;
  final int ni = n.asInt;
  final c = List<DecimalFP22>.generate(ki + 1, (_) => zero, growable: false);
  c[0] = one;
  for (int i = 1; i <= ni; i++) {
    for (int j = min(i, ki); j > 0; j--) {
      c[j] += c[j - 1];
    }
  }
  return c[ki].toValue();
}

void convertHMStoH(Model m) {
  final n100 = Value.fromDouble(100);
  final n60 = DecimalFP12(Value.fromDouble(60));
  final Value hr = m.x;
  final Value min = hr.fracOp().decimalMultiply(n100);
  final Value sec = min.fracOp().decimalMultiply(n100);
  final hrFP = DecimalFP12(hr.intOp());
  final minFP = DecimalFP12(min.intOp());
  final secFP = DecimalFP12(sec);
  m.resultX =
      m.checkOverflow(() => (hrFP + (minFP + secFP / n60) / n60).toValue());
}

void convertHtoHMS(Model m) {
  Value round(Value v, int digits) => FixFloatFormatter(digits).round(v);

  final Value hr = m.x.intOp();
  final int hrDigits = (hr == Value.zero) ? 0 : (hr.exponent + 1);
  if (hrDigits >= 10) {
    m.resultX = m.x;
    return;
  }
  final sixty = DecimalFP12(Value.fromDouble(60));
  DecimalFP12 minFP =
      DecimalFP12(m.x.fracOp()) * DecimalFP12(Value.fromDouble(60));
  Value minV = minFP.toValue();
  int digitsLeft = 10 - hrDigits; // 1..10
  if (hrDigits == 0 && minV.intOp() == Value.zero) {
    final sec = round((minFP * sixty).toValue(), 7);
    final secFP = DecimalFP12(sec);
    if (secFP >= sixty) {
      m.resultX = Value.fromDouble(0.01);
    } else if (secFP <= sixty.negate()) {
      m.resultX = Value.fromDouble(-0.01);
    } else {
      m.resultX = secFP.toValue().timesTenTo(-4);
    }
    return;
  }
  // >= 1 minute
  if (digitsLeft != 10) {
    minV = round(minV.timesTenTo(-2), digitsLeft).timesTenTo(2);
  }
  minFP = DecimalFP12(minV.intOp());
  if (minFP.abs() >= sixty) {
    // I believe this branch is impossible, but just to be extra paranoid...
    final minSec = "0.5959999999".substring(0, 2 + digitsLeft);
    if (minFP > DecimalFP12(Value.zero)) {
      m.resultX = hr.decimalAdd(Value.fromDouble(double.parse(minSec)));
    } else {
      m.resultX = hr.decimalSubtract(Value.fromDouble(double.parse(minSec)));
    }
    return;
  }
  digitsLeft -= 2;
  final fiftyNine = DecimalFP12(Value.fromDouble(59));
  assert(minFP <= fiftyNine && minFP >= fiftyNine.negate());
  if (digitsLeft <= 0) {
    m.resultX = hr.decimalAdd(minV.intOp().timesTenTo(-2));
    return;
  }
  Value sec = (DecimalFP12(minV.fracOp()) * sixty).toValue();
  final n100 = DecimalFP12(Value.fromDouble(100));
  if (digitsLeft == 1) {
    final tensSec =
        DecimalFP12(round(sec.timesTenTo(-1), 0)); // tens of seconds
    if (tensSec.abs() >= DecimalFP12(Value.fromDouble(6))) {
      // I believe this branch is impossible, too.
      final n005 = DecimalFP12(Value.fromDouble(0.005));
      if (tensSec > DecimalFP12(Value.zero)) {
        m.resultX = (DecimalFP12(hr) + minFP / n100 + n005).toValue();
      } else {
        m.resultX = (DecimalFP12(hr) + minFP / n100 - n005).toValue();
      }
    } else {
      final n1000 = DecimalFP12(Value.fromDouble(1000));
      m.resultX = (DecimalFP12(hr) + minFP / n100 + tensSec / n1000).toValue();
    }
    return;
  }
  digitsLeft -= 2;
  assert(digitsLeft >= 0);
  final secFP = DecimalFP12(round(sec, digitsLeft));
  if (secFP.abs() >= sixty) {
    // I believe this branch is impossible, but I'm still paranoid.
    final secStr = "0.0059999999".substring(0, 4 + digitsLeft);
    final secStrFP = DecimalFP12(Value.fromDouble(double.parse(secStr)));
    if (secFP > DecimalFP12(Value.zero)) {
      m.resultX = (DecimalFP12(hr) + minFP / n100 + secStrFP).toValue();
    } else {
      m.resultX = (DecimalFP12(hr) + minFP / n100 - secStrFP).toValue();
    }
  } else {
    final n10000 = DecimalFP12(Value.fromDouble(10000));
    m.resultX = (DecimalFP12(hr) + minFP / n100 + secFP / n10000).toValue();
  }
}

class LinearRegression {
  final DecimalFP22 num; // Number of samples
  final DecimalFP22 m; // Taken from p. 208
  final DecimalFP22 n;
  final DecimalFP22 p;
  final DecimalFP22 sumY;
  final DecimalFP22 sumX;

  LinearRegression._internal(
      this.num, this.m, this.n, this.p, this.sumY, this.sumX);

  factory LinearRegression(Registers regs) {
    regs[7]; // Throw exception if invalid
    final numV = regs[2];
    if (numV == Value.zero || numV == Value.oneF) {
      throw CalculatorError(0);
    }
    final num = DecimalFP22(regs[2]);
    final sumX = DecimalFP22(regs[3]);
    final m = num * DecimalFP22(regs[4]) - sumX * sumX;
    final sumY = DecimalFP22(regs[5]);
    final n = num * DecimalFP22(regs[6]) - sumY * sumY;
    final zero = DecimalFP22(Value.zero);
    if (m == zero || n == zero) {
      throw CalculatorError(0);
    }
    final p = num * DecimalFP22(regs[7]) - sumX * sumY;
    return LinearRegression._internal(num, m, n, p, sumY, sumX);
  }

  DecimalFP22 get slope => p / m;

  DecimalFP22 get yIntercept => (m * sumY - p * sumX) / (num * m);

  DecimalFP22 yHat(DecimalFP22 x) =>
      (m * sumY + p * (num * x - sumX)) / (num * m);

  DecimalFP22 get r =>
      p / DecimalFP22(Value.fromDouble(sqrt(m.asDouble * n.asDouble)));
}

///
/// Special case of sin() for HP15, so that sin(180) gives exactly 0, etc.
///
/// rightAngleInt is 90 for degrees, 100 for grad, and null for radians.
///
double? sin15(double angle, int? rightAngleInt) {
  if (rightAngleInt != null) {
    double? a = _normalizeAngle(angle, rightAngleInt);
    if (a == 0 || a == rightAngleInt * 2) {
      return 0;
    }
  }
  return null;
}

///
/// Special case of cos() for HP15, so that cos(90) gives exactly 0, etc.
///
/// rightAngleInt is 90 for degrees, 100 for grad, and null for radians.
///
double? cos15(double angle, int? rightAngleInt) {
  if (rightAngleInt != null) {
    double? a = _normalizeAngle(angle, rightAngleInt);
    if (a == rightAngleInt || a == rightAngleInt * 3) {
      return 0;
    }
  }
  return null;
}

///
/// Special case of tan() for HP15, so that tan(90) gives infinity,
/// etc.
///
/// rightAngleInt is 90 for degrees, 100 for grad, and null for radians.
///
double? tan15(double angle, int? rightAngleInt) {
  if (rightAngleInt != null) {
    double? a = _normalizeAngle(angle, rightAngleInt);
    if (a == rightAngleInt || a == 3 * rightAngleInt) {
      return double.infinity;
    } else if (a == 0 || a == rightAngleInt * 2) {
      return 0;
    }
  }
  return null;
}

//
// Return null if angle isn't worth considering, or a number between
// 0 (inclusive) and 4*rightAngleInt (exclusive) if it is.
//
double? _normalizeAngle(double angle, int rightAngleInt) {
  if (angle > 9999999999.0 || angle < -9999999999.0) {
    // If the angle's units aren't exactly represented, don't bother.  This
    // prevents us having round-off problems with the remainder call, below.
    return null;
  }
  angle = angle.remainder(rightAngleInt * 4);
  if (angle >= 0) {
    return angle;
  } else {
    return 4 * rightAngleInt + angle;
  }
}
