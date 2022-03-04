/*
Copyright (c) 2021,2022 William Foote

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

Some code in this file was developed, in part, by consulting code
in the la4j package by Vladimir Kostyukov and Contributors,
https://github.com/vkostyukov/la4j/, which is offered
under the Apache license, and by consulting code in the HP-15C Simulator
by Torsten Manz, https://hp-15c.homepage.t-online.de/content_web.htm, which
is offered under the GPL.
*/

library linalg;

import 'dart:math';

import 'package:jrpn/m/model.dart';

import 'matrix.dart';

///
/// Do an LU decomposition with row permutations.  This is hoped to be
/// compatible with the 15C's LU decomposition using the Doolittle method,
/// as mentioned in the HP 15C Advanced Functions book, page 83.  It's a
/// port of la4j's RawLUCompositor.decompose() (in Java), cross-checked against
/// Thomas Manz's ::matrix::dgetrf (TCL), which appears to trace back to
/// LAPACK (Fortran).
///
void decomposeLU(Matrix m) {
  assert(!m.isLU);
  m.isLU = true;
  for (int j = 0; j < m.columns; j++) {
    for (int i = 0; i < m.rows; i++) {
      int kMax = min(i, j);
      double s = 0;
      for (int k = 0; k < kMax; k++) {
        s += m.getF(i, k) * m.getF(k, j);
      }
      m.setF(i, j, m.getF(i, j) - s);
    }

    int pivot = j;

    for (int i = j + 1; i < m.rows; i++) {
      if (m.getF(i, j).abs() > m.getF(pivot, j).abs()) {
        pivot = i;
      }
    }
    if (pivot != j) {
      m.swapRowsLU(pivot, j);
    }
    if (j < m.rows) {
      final double vj = m.getF(j, j);
      if (vj.abs() > 0) {
        for (int i = j + 1; i < m.rows; i++) {
          m.setF(i, j, m.getF(i, j) / vj);
        }
      }
    }
  }
}

///
/// Solve the system of linear equations AX = B.  This is a port of
/// la4j's ForwardBackSubstitutionSolver.solve.
///
void solve(Matrix a, Matrix b, Matrix x) {
  if (!a.isLU) {
    decomposeLU(a);
  }
  final int n = b.rows;
  if (x.rows != n || x.columns != 1 || b.columns != 1 || a.rows != n) {
    throw CalculatorError(11);
  }

  // Check for a singular matrix
  for (int i = 0; i < n; i++) {
    if (a.get(i, i) == Value.zero) {
      for (int j = 0; j < n; j++) {
        x.set(j, 0, Value.fMaxValue);
      }
      throw MatrixOverflow();
    }
  }

  for (int i = 0; i < n; i++) {
    for (int j = 0; j < n; j++) {
      if (a.getP(i, j)) {
        x.set(i, 0, b.get(j, 0));
        break;
      }
    }
  }

  for (int j = 0; j < n; j++) {
    for (int i = j + 1; i < n; i++) {
      x.setF(i, 0, x.getF(i, 0) - x.getF(j, 0) * a.getF(i, j));
    }
  }

  for (int j = n - 1; j >= 0; j--) {
    x.setF(j, 0, x.getF(j, 0) / a.getF(j, j));
    for (int i = 0; i < j; i++) {
      x.setF(i, 0, x.getF(i, 0) - x.getF(j, 0) * a.getF(i, j));
    }
  }
}

///
/// Invert m in place.
///
void invert(final Matrix m) {
  if (!m.isLU) {
    decomposeLU(m);
  }

  /// Now use A^-1 = U^-1 * l^-1 * P, as per HP 15C Advanced Functions p. 83
  // @@ TODO:  Perturb matrix to avoid divide by zero

  // Calculate U^-1.  Adapted from dtri2.f in LAPACK from www.netlib.org.
  for (int j = 0; j < m.rows; j++) {
    final ajj = -1 / m.getF(j, j);
    m.setF(j, j, -ajj);
    // Compute elements 0..j-1 of the jth column
    // DTRMV call:
    for (int jj = 0; jj < j; jj++) {
      final temp = m.getF(jj, j);
      for (int i = 0; i < jj; i++) {
        m.setF(i, j, m.getF(i, j) + temp * m.getF(i, jj));
      }
      m.setF(jj, j, m.getF(jj, j) * m.getF(jj, jj));
    }
    // DSCAL call:
    for (int i = 0; i < j; i++) {
      m.setF(i, j, m.getF(i, j) * ajj);
    }
  }

  // Calculate L^-1, adapted from dtri2.f.
  for (int j = m.rows - 2; j >= 0; j--) {
    const ajj = -1;
    // DTRMV call:
    for (int jj = m.rows - 2 - j; jj >= 0; jj--) {
      final temp = m.getF(j + jj + 1, j);
      for (int i = m.rows - 2 - j; i > jj; i--) {
        m.setF(j + 1 + i, j,
            m.getF(j + 1 + i, j) + temp * m.getF(j + i + 1, j + jj + 1));
      }
    }
    // DSCAL call:
    for (int i = j + 1; i < m.rows; i++) {
      m.setF(i, j, m.getF(i, j) * ajj);
    }
  }

  // Calculate m = U^-1 dot L^-1 in-place:
  for (int r = 0; r < m.rows; r++) {
    for (int c = 0; c < m.columns; c++) {
      double v = 0;
      for (int k = max(r, c); k < m.columns; k++) {
        assert(r <= k); // Otherwise U is zero
        assert(c <= k); // Otherwise L is zero;
        final uv = m.getF(r, k);
        final lv = (k == c) ? 1 : m.getF(k, c);
        v += uv * lv;
      }
      m.setF(r, c, v);
    }
  }
  m.dotByP();
  m.isLU = false;
}

class MatrixOverflow {}
