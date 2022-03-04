/*
Copyright (c) 2022 William Foote

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

import 'package:jrpn/m/model.dart';
import 'package:meta/meta.dart';

import 'model15c.dart';

///
/// Abstract matrix.  This is narrower than the Matrix interface.
///
abstract class AMatrix {
  int get rows;
  int get columns;
  void set(int row, int col, Value v);
  Value get(int row, int col);

  void setF(int row, int col, double d) => set(row, col, Value.fromDouble(d));
  double getF(int row, int col) => get(row, col).asDouble;

  ///
  /// Computes this = a dot b.  r, a and b must already be properly dimensioned.
  ///
  void dot(AMatrix a, AMatrix b) {
    if (a.columns != b.rows || rows != a.rows || columns != b.columns) {
      throw CalculatorError(11);
    }
    for (int i = 0; i < rows; i++) {
      for (int j = 0; j < columns; j++) {
        double v = 0;
        for (int k = 0; k < a.columns; k++) {
          v += a.getF(i, k) * b.getF(k, j);
        }
        setF(i, j, v);
      }
    }
  }

  @protected
  String get toStringDim => '($rows, $columns)';

  void visit(void Function(int r, int c) f) {
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < columns; c++) {
        f(r, c);
      }
    }
  }

  String formatValueWith(String Function(Value) fmt) {
    final sb = StringBuffer();
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < columns; c++) {
        if (c == 0) {
          sb.write('    ');
        }
        sb.write(fmt(get(r, c)).trim().padLeft(11));
        if (c != columns - 1) {
          sb.write(',   ');
        }
      }
      sb.writeln();
    }
    return sb.toString();
  }

  @override
  String toString() {
    final sb = StringBuffer('Matrix');
    sb.write(toStringDim);
    if (columns != 0 && rows != 0) {
      sb.writeln(':');
    }
    sb.write(formatValueWith((v) => (const FixFloatFormatter(4)).format(v)));
    return sb.toString();
  }

  @override
  bool operator ==(Object other) {
    if (other is! AMatrix) {
      return false;
    } else if (other.rows != rows && other.columns != columns) {
      return false;
    } else {
      for (int i = 0; i < rows; i++) {
        for (int j = 0; j < columns; j++) {
          if (get(i, j) != other.get(i, j)) {
            return false;
          }
        }
      }
      return true;
    }
  }

  @override
  int get hashCode {
    final values = Iterable.generate(
        rows * columns, (i) => get(i ~/ columns, i % columns));
    return Object.hash(rows, columns, Object.hashAll(values));
  }
}

///
/// A matrix stored in the 15C's registers, with values held in the 15C's
/// internal format, with ten decimal digits of mantissa.
///
class Matrix extends AMatrix {
  final String name;
  List<Value> _values = [];

  /// List of rows swapped in the LU decomposition
  List<int>? _rowSwaps;
  int _columns = 0;
  @override
  int get rows => (_values.isEmpty) ? 0 : (_values.length ~/ _columns);

  Matrix(this.name);

  /// Number of registers this matrix occupies
  int get length => _values.length;

  @override
  int get columns => _columns;

  bool get isLU => _rowSwaps != null;
  set isLU(bool v) {
    if (v == isLU) {
      return;
    }
    final swaps = _rowSwaps;
    if (swaps == null) {
      if (rows != columns) {
        throw CalculatorError(11);
      }
      _rowSwaps = List.generate(rows, (i) => i, growable: false);
    } else {
      _rowSwaps = null;
      for (int r = 0; r < rows; r++) {
        final sr = swaps[r];
        if (sr != r) {
          assert(sr > r);
          for (int c = 0; c < columns; c++) {
            final t = get(r, c);
            set(r, c, get(sr, c));
            set(sr, c, t);
          }
          swaps[r] = r;
          bool ok = false;
          for (int i = r + 1; i < swaps.length; i++) {
            if (swaps[i] == r) {
              swaps[i] = sr;
              ok = true;
              break;
            }
          }
          assert(ok);
        }
      }
      assert(() {
        for (int r = 0; r < rows; r++) {
          assert(r == swaps[r]);
        }
        return true;
      }());
    }
    assert(isLU == v);
  }

  ///
  /// calculate this = this dot P.
  /// This is not to be confused with P dot this!
  ///
  void dotByP() {
    // This is equivalent to doing the inverse of swapping the columns according
    // to _rowSwaps
    assert(isLU);
    final rs = _rowSwaps!;
    final swaps = List.generate(rs.length, (i) => rs[i]);
    for (int c = 0; c < columns;) {
      final sc = swaps[c];
      if (sc == c) {
        c++;
      } else {
        for (int r = 0; r < rows; r++) {
          final t = get(r, c);
          set(r, c, get(r, sc));
          set(r, sc, t);
        }
        swaps[c] = swaps[sc];
        swaps[sc] = sc;
      }
    }
    assert(() {
      for (int c = 0; c < columns; c++) {
        assert(c == swaps[c]);
      }
      return true;
    }());
  }

  void resize(Model15 m, int rows, int columns) {
    if (rows < 0 || columns < 0) {
      throw ArgumentError('rows $rows columns $columns');
    } else if (rows == this.rows && columns == this.columns) {
      return;
    }
    int totalMatrix = rows * columns - 2 * length;
    for (final mat in m.matrices) {
      totalMatrix += mat.length;
    }
    if (totalMatrix > 64) {
      // bottom of page 148
      throw CalculatorError(10);
    }
    m.memory.policy.checkAvailable(rows * columns - length);
    isLU = false;
    final values = List<Value>.filled(rows * columns, Value.zero);
    for (int i = 0; i < values.length && i < _values.length; i++) {
      values[i] = _values[i];
    }
    _columns = (rows == 0) ? 0 : columns;
    _values = values;
  }

  void copyFrom(Model15 m, Matrix other) {
    resize(m, other.rows, other.columns);
    for (int i = 0; i < length; i++) {
      _values[i] = other._values[i];
    }
    final ors = other._rowSwaps;
    if (ors == null) {
      _rowSwaps = null;
    } else {
      _rowSwaps = List.generate(ors.length, (i) => ors[i], growable: false);
    }
  }

  void checkIndices(int row, int col) {
    if (row < 0 || col < 0 || row >= rows || col >= columns) {
      throw CalculatorError(3);
    }
  }

  @override
  void set(int row, int col, Value v) {
    checkIndices(row, col);
    final swaps = _rowSwaps;
    if (swaps != null) {
      row = swaps[row];
    }
    _values[row * columns + col] = v;
  }

  @override
  Value get(int row, int col) {
    checkIndices(row, col);
    final swaps = _rowSwaps;
    if (swaps != null) {
      row = swaps[row];
    }
    return _values[row * columns + col];
  }

  ///
  /// Swap rows in a matrix holding an LU decomposition.
  ///
  void swapRowsLU(int r1, int r2) {
    assert(isLU);
    checkIndices(r1, r2); // It's square, so this works
    final swaps = _rowSwaps!;
    final t = swaps[r1];
    swaps[r1] = swaps[r2];
    swaps[r2] = t;
  }

  ///
  /// Get the permutation matrix P value at the given row, column.  Since it's
  /// a permuted identity matrix, the value is 0 or 1, so we give it as a bool.
  /// A P matrix only exists for an LU-decomposed matrix.
  ///
  bool getP(int r, int c) {
    assert(isLU);
    checkIndices(r, c);
    final swaps = _rowSwaps!;
    return swaps[r] == c;
  }

  Map<String, Object?> toJson() => {
        'columns': _columns,
        'values': _values.map((v) => v.toJson()).toList(),
        'rowSwaps': _rowSwaps
      };

  void decodeJson(Map<String, dynamic> m) {
    final rsRaw = m['rowSwaps'] as List?;
    if (rsRaw == null) {
      _rowSwaps = null;
    } else {
      _rowSwaps =
          List.generate(rsRaw.length, (i) => rsRaw[i] as int, growable: false);
    }
    _columns = m['columns'] as int;
    final v = m['values'] as List;
    _values = List.generate(v.length, (i) => Value.fromJson(v[i] as String),
        growable: false);
  }

  @override
  String get toStringDim => '($lcdString)';

  String get lcdString {
    final r = rows.toString().padLeft(3);
    final c = _columns.toString().padLeft(3);
    final luString = isLU ? '--' : '  ';
    return '$name$luString  $r$c';
  }

  void chsElements() {
    for (int i = 0; i < _values.length; i++) {
      _values[i] = _values[i].negateAsFloat();
    }
  }
}

///
/// A copy of a matrix.  This isn't used by the 15C simulator, but it comes
/// in handy for experiments and testing.
///
class CopyMatrix extends AMatrix {
  @override
  final int rows;
  @override
  final int columns;
  final List<Value> _values;

  CopyMatrix(AMatrix src)
      : rows = src.rows,
        columns = src.columns,
        _values = List.generate(src.rows * src.columns,
            (i) => src.get(i ~/ src.columns, i % src.columns),
            growable: false);

  @override
  void set(int row, int col, Value v) => _values[row * columns + col] = v;
  @override
  Value get(int row, int col) => _values[row * columns + col];

  /// Make this the identity matrix
  void identity() {
    visit((r, c) {
      if (r == c) {
        setF(r, c, 1);
      } else {
        setF(r, c, 0);
      }
    });
  }
}

///
/// A view of a 15C matrix giving the permutation matrix (P).  Only valid if
/// the underlying matrix is in LU form.
///
class PermutationMatrix extends AMatrix {
  final Matrix _m;

  PermutationMatrix(this._m);

  @override
  int get rows => _m.rows;

  @override
  int get columns => _m.columns;

  @override
  Value get(int row, int col) => _m.getP(row, col) ? Value.oneF : Value.zero;

  @override
  void set(int row, int col, Value v) {
    throw Error();
  }
}

abstract class UpperOrLowerTriangular extends AMatrix {
  final Matrix _m;

  UpperOrLowerTriangular(this._m);

  @protected
  Value? getFixed(int r, int c);

  @override
  int get rows => _m.rows;

  @override
  int get columns => _m.columns;

  @override
  Value get(int row, int col) => getFixed(row, col) ?? _m.get(row, col);

  @override
  void set(int row, int col, Value v) {
    final f = getFixed(row, col);
    if (f == null) {
      _m.set(row, col, v);
    } else if (v != f) {
      print('Attempt to set fixed part of triangle to $v ($f expected)');
    }
  }
}

class UpperTriangular extends UpperOrLowerTriangular {
  UpperTriangular(Matrix m) : super(m);

  @override
  getFixed(int r, int c) {
    if (c < r) {
      return Value.zero;
    } else {
      return null;
    }
  }
}

class LowerTriangular extends UpperOrLowerTriangular {
  LowerTriangular(Matrix m) : super(m);

  @override
  getFixed(int r, int c) {
    if (c > r) {
      return Value.zero;
    } else if (c == r) {
      return Value.oneF;
    } else {
      return null;
    }
  }
}
