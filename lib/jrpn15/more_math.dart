/*
Copyright (c) 2023 William Foote

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

library jrpn15.more_math;

import 'dart:math';
import 'dart:typed_data';

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

double factorial(double x) {
  if (x >= 70) {
    return double.infinity;
  } else if (x >= 0 && x == x.floorToDouble()) {
    final lim = x.floor();
    double result = 1;
    for (int i = 1; i <= lim; i++) {
      result *= i;
    }
    return result;
  } else {
    return laGamma(x + 1);
  }
}

double permutations(double n, double k, {double initial = 1}) {
  if (n < 0 ||
      k < 0 ||
      k > n ||
      n != n.floorToDouble() ||
      k != k.floorToDouble()) {
    throw CalculatorError(0);
  } else if (k > 70) {
    return double.infinity;
  } else if (n - k <= 1) {
    return factorial(n);
  }
  double result = initial;
  for (int i = (n - k).floor() + 1; i <= n.floor(); i++) {
    result *= i;
  }
  return result;
}

double binomialCoefficient(double nr, double kr) {
  int n = nr.floor();
  int k = kr.floor();
  if (n != nr || k != kr || n < 0 || k < 0 || k > n) {
    throw CalculatorError(0);
  }
  k = min(k, n - k);
  if (k > 200) {
    // Enough to overflow the 15C
    return double.infinity;
  } else if (k == 1) {
    return nr;
  } else if (n > 10000) {
    if (k > 36) {
      // Enough to overflow the 15C
      return double.infinity;
    }
    final kd = k.toDouble();
    return permutations(nr, kd, initial: 1.0 / factorial(kd));
  }

  final c = Float64List(k + 1);
  c[0] = 1;
  for (int i = 1; i <= n; i++) {
    for (int j = min(i, k); j > 0; j--) {
      c[j] += c[j - 1];
      if (c[j] == double.infinity) {
        return c[j];
      }
    }
  }
  return c[k];
}

void convertHMStoH(Model m) {
  final Value hr = m.x;
  final Value min = Value.fromDouble(hr.fracOp().asDouble * 100);
  final double sec = min.fracOp().asDouble * 100;
  m.resultX = Value.fromDouble(
      hr.intOp().asDouble + (min.intOp().asDouble + sec / 60) / 60);
}

void convertHtoHMS(Model m) {
  Value round(Value v, int digits) => FixFloatFormatter(digits).round(v);

  final Value hr = m.x.intOp();
  final int hrDigits = (hr == Value.zero) ? 0 : (hr.exponent + 1);
  if (hrDigits >= 10) {
    m.resultX = m.x;
    return;
  }
  Value min = Value.fromDouble(m.x.fracOp().asDouble * 60);
  int digitsLeft = 10 - hrDigits; // 1..10
  if (hrDigits == 0 && min.intOp() == Value.zero) {
    final sec = round(Value.fromDouble(min.asDouble * 60), 7);
    final secD = sec.asDouble;
    if (secD >= 60.0) {
      m.resultX = Value.fromDouble(0.01);
    } else if (secD <= -60.0) {
      m.resultX = Value.fromDouble(-0.01);
    } else {
      m.resultX = Value.fromDouble(secD).timesTenTo(-4);
    }
    return;
  }
  // >= 1 minute
  if (digitsLeft != 10) {
    min = round(min.timesTenTo(-2), digitsLeft).timesTenTo(2);
  }
  final minD = min.intOp().asDouble;
  if (minD.abs() >= 60.0) {
    // I believe this branch is impossible, but just to be extra paranoid...
    final minSec = "0.5959999999".substring(0, 2 + digitsLeft);
    if (minD > 0) {
      m.resultX = Value.fromDouble(hr.asDouble + double.parse(minSec));
    } else {
      m.resultX = Value.fromDouble(hr.asDouble - double.parse(minSec));
    }
    return;
  }
  digitsLeft -= 2;
  assert(minD <= 59 && minD >= -59);
  if (digitsLeft <= 0) {
    m.resultX = Value.fromDouble(hr.asDouble + min.timesTenTo(-2).asDouble);
    return;
  }
  Value sec = Value.fromDouble(min.fracOp().asDouble * 60);
  if (digitsLeft == 1) {
    final tensSec = round(sec.timesTenTo(-1), 0).asDouble; // tens of seconds
    if (tensSec.abs() >= 6) {
      // I believe this branch is impossible, too.
      if (tensSec > 0) {
        m.resultX = Value.fromDouble(hr.asDouble + minD / 100 + 0.005);
      } else {
        m.resultX = Value.fromDouble(hr.asDouble + minD / 100 - 0.005);
      }
    } else {
      m.resultX = Value.fromDouble(hr.asDouble + minD / 100 + tensSec / 1000);
    }
    return;
  }
  digitsLeft -= 2;
  assert(digitsLeft >= 0);
  final secD = round(sec, digitsLeft).asDouble;
  if (secD.abs() >= 60) {
    // I believe this branch is impossible, but I'm still paranoid.
    final secStr = "0.0059999999".substring(0, 4 + digitsLeft);
    if (secD > 0) {
      m.resultX =
          Value.fromDouble(hr.asDouble + minD / 100 + double.parse(secStr));
    } else {
      m.resultX =
          Value.fromDouble(hr.asDouble + minD / 100 - double.parse(secStr));
    }
  } else {
    m.resultX = Value.fromDouble(hr.asDouble + minD / 100 + secD / 10000);
  }
}

class LinearRegression {
  final double num; // Number of samples
  final double m; // Taken from p. 208
  final double n;
  final double p;
  final double sumY;
  final double sumX;

  LinearRegression._internal(
      this.num, this.m, this.n, this.p, this.sumY, this.sumX);

  factory LinearRegression(Registers regs) {
    regs[7]; // Throw exception if invalid
    final num = regs[2].asDouble;
    if (num == 0 || num == 1) {
      throw CalculatorError(0);
    }
    final sumX = regs[3].asDouble;
    final m = num * regs[4].asDouble - sumX * sumX;
    final sumY = regs[5].asDouble;
    final n = num * regs[6].asDouble - sumY * sumY;
    if (m == 0 || n == 0) {
      throw CalculatorError(0);
    }
    final p = num * regs[7].asDouble - sumX * sumY;
    return LinearRegression._internal(num, m, n, p, sumY, sumX);
  }

  double get slope => p / m;

  double get yIntercept => (m * sumY - p * sumX) / (num * m);

  double yHat(double x) => (m * sumY + p * (num * x - sumX)) / (num * m);

  double get r => p / sqrt(m * n);
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
