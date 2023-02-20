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
