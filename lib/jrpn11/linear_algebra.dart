/*
Copyright (c) 2021-2024 William Foote

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

library;

import 'dart:math';

import 'package:jrpn/m/model.dart';

import 'matrix.dart';

///
/// Do an LU decomposition with row permutations, and with perturbations, if
/// needed, to avoid a singular matrix.  This is hoped to be
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
      var s = DecimalFP22.zero;
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
      final vj = m.getF(j, j);
      if (vj.abs() > DecimalFP22.zero) {
        for (int i = j + 1; i < m.rows; i++) {
          m.setF(i, j, m.getF(i, j) / vj);
        }
      }
    }
  }

  // Avoid a singular matrix by perturbing the pivots, if needed, so they fall
  // within the 15C's precision.  See Advanced Functions, 98-99.  Note that page
  // 98 say "Then, theoretically, a matrix is singular if at least one of the
  // diagonal elements of U, the pivots, is zero; otherwise it is nonsingular."
  //
  // Based on https://en.wikipedia.org/wiki/Machine_epsilon, a reasonable value
  // for machine epsilon is 5e-12 (b^(-p-1)/2, b = base = 10, p =
  // precision = 10).
  // https://link.springer.com/content/pdf/10.1007/3-540-48311-X_153
  // suggests that the pivot value does not vary with the magnitude
  // of other values of the matrix (!).  I experimented with the singular
  // matrices [[3 3] [1 1]] and [3e20 3e20] [1 1]], and both showed a minimum
  // pivot value of 1e-10, so I'll go with that.
  const minPivot = 1e-10;
  for (int i = 0; i < m.rows; i++) {
    final v = m.get(i, i).asDouble;
    if (v.abs() < minPivot) {
      if (v < 0) {
        m.set(i, i, Value.fromDouble(-minPivot));
      } else {
        m.set(i, i, Value.fromDouble(minPivot));
      }
    }
  }
}

///
/// Solve the system of linear equations AX = B.  This is a port of
/// la4j's ForwardBackSubstitutionSolver.solve.
///
void solve(Matrix a, AMatrix b, AMatrix result) {
  CopyMatrix x = CopyMatrix(result);
  final int n = b.rows;
  if (x.rows != n || x.columns != b.columns || a.rows != n) {
    throw CalculatorError(11);
  }
  try {
    if (!a.isLU) {
      decomposeLU(a);
    }

    for (int rCol = 0; rCol < x.columns; rCol++) {
      for (int i = 0; i < n; i++) {
        for (int j = 0; j < n; j++) {
          if (a.getP(i, j)) {
            x.set(i, rCol, b.get(j, rCol));
            break;
          }
        }
      }

      for (int j = 0; j < n; j++) {
        for (int i = j + 1; i < n; i++) {
          x.setF(i, rCol, x.getF(i, rCol) - x.getF(j, rCol) * a.getF(i, j));
        }
      }

      for (int j = n - 1; j >= 0; j--) {
        x.setF(j, rCol, x.getF(j, rCol) / a.getF(j, j));
        for (int i = 0; i < j; i++) {
          x.setF(i, rCol, x.getF(i, rCol) - x.getF(j, rCol) * a.getF(i, j));
        }
      }
    }
  } finally {
    x.visit((r, c) {
      result.set(r, c, x.get(r, c));
    });
  }
}

///
/// Invert m in place.
///
void invert(final Matrix m) {
  if (!m.isLU) {
    decomposeLU(m);
  }
  // Clone the matrix to a native float matrix, for better internal precision.
  // This seems to give results closer to the real 15C than the version that
  // did the internal math using Value's precision, in a quick test.  I suspect
  // that the 15C may be using a more clever algorithm, but brute force works,
  // too!
  final dm = List<List<DecimalFP22>>.generate(
    m.rows,
    (row) => List<DecimalFP22>.generate(m.columns, (col) => m.getF(row, col)),
  );

  try {
    /// Now use A^-1 = U^-1 * l^-1 * P, as per HP 15C Advanced Functions p. 83

    // Calculate U^-1.  Adapted from dtri2.f in LAPACK from www.netlib.org.
    for (int j = 0; j < m.rows; j++) {
      final ajj = DecimalFP22.negativeOne / dm[j][j];
      dm[j][j] = ajj.negate();
      // Compute elements 0..j-1 of the jth column
      // DTRMV call:
      for (int jj = 0; jj < j; jj++) {
        final temp = dm[jj][j];
        for (int i = 0; i < jj; i++) {
          dm[i][j] = dm[i][j] + temp * dm[i][jj];
        }
        dm[jj][j] = dm[jj][j] * dm[jj][jj];
      }
      // DSCAL call:
      for (int i = 0; i < j; i++) {
        dm[i][j] = dm[i][j] * ajj;
      }
    }

    // Calculate L^-1, adapted from dtri2.f.
    for (int j = m.rows - 2; j >= 0; j--) {
      final ajj = DecimalFP22.negativeOne;
      // DTRMV call:
      for (int jj = m.rows - 2 - j; jj >= 0; jj--) {
        final temp = dm[j + jj + 1][j];
        for (int i = m.rows - 2 - j; i > jj; i--) {
          dm[j + 1 + i][j] =
              dm[j + 1 + i][j] + temp * dm[j + i + 1][j + jj + 1];
        }
      }
      // DSCAL call:
      for (int i = j + 1; i < m.rows; i++) {
        dm[i][j] = dm[i][j] * ajj;
      }
    }

    // Calculate m = U^-1 dot L^-1 in-place:
    for (int r = 0; r < m.rows; r++) {
      for (int c = 0; c < m.columns; c++) {
        DecimalFP22 v = DecimalFP22.zero;
        for (int k = max(r, c); k < m.columns; k++) {
          assert(r <= k); // Otherwise U is zero
          assert(c <= k); // Otherwise L is zero;
          final uv = dm[r][k];
          final DecimalFP22 lv = (k == c) ? DecimalFP22.one : dm[k][c];
          v += uv * lv;
        }
        dm[r][c] = v;
      }
    }
  } finally {
    // Now copy back into m...
    m.visit((r, c) => m.setF(r, c, dm[r][c]));
    m.dotByP();
    m.isLU = false;
  }
}

DecimalFP22 determinant(Matrix mat) {
  if (!mat.isLU) {
    decomposeLU(mat);
  }
  var result = DecimalFP22.one;
  final rs = mat.cloneRowSwaps();
  // Figure out how many row swaps r there were
  for (int c = 0; c < rs.length;) {
    final sc = rs[c];
    if (sc == c) {
      c++;
    } else {
      rs[c] = rs[sc];
      rs[sc] = sc;
      result = result.negate();
    }
  }
  // result is now -1^(number of row swaps)
  for (int i = 0; i < mat.columns; i++) {
    result *= mat.getF(i, i);
  }
  return result;
}

DecimalFP22 rowNorm(AMatrix mat) {
  var result = DecimalFP22.zero;
  for (int r = 0; r < mat.rows; r++) {
    var sum = DecimalFP22.zero;
    for (int c = 0; c < mat.columns; c++) {
      sum += mat.getF(r, c).abs();
    }
    if (sum > result) {
      result = sum;
    }
  }
  return result;
}

double frobeniusNorm(AMatrix mat) {
  double result = 0;
  for (int r = 0; r < mat.rows; r++) {
    for (int c = 0; c < mat.columns; c++) {
      final v = mat.get(r, c).asDouble;
      result += v * v;
    }
  }
  return sqrt(result);
}
