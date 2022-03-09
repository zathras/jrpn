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
    assert(a.columns == b.rows && rows == a.rows && columns == b.columns);
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

  ///
  /// Computes this = this - a dot b.
  /// r, a and b must already be properly dimensioned.
  ///
  void residual(AMatrix a, AMatrix b) {
    assert(a.columns == b.rows && rows == a.rows && columns == b.columns);
    for (int i = 0; i < rows; i++) {
      for (int j = 0; j < columns; j++) {
        double v = getF(i, j);
        for (int k = 0; k < a.columns; k++) {
          v -= a.getF(i, k) * b.getF(k, j);
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

  bool equivalent(AMatrix other) {
    if (other.rows != rows && other.columns != columns) {
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

  List<int> cloneRowSwaps() {
    assert(isLU);
    final rs = _rowSwaps!;
    return List.generate(rs.length, (i) => rs[i]);
  }

  ///
  /// calculate this = this dot P.
  /// This is not to be confused with P dot this!
  ///
  void dotByP() {
    // This is equivalent to doing the inverse of swapping the columns according
    // to _rowSwaps
    final swaps = cloneRowSwaps();
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
    if (other == this) {
      return;
    }
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

  void transpose() {
    isLU = false;
    _columns = rows;
    if (length <= 2) {
      return;
    }
    final last = length - 1;
    _internalMove(1, last, (i) => i * columns % last);
  }

  void _internalMove(int i, final int last, int Function(int) nextF) {
    final moved = List<bool>.filled(length, false);
    int i = 1;
    assert(!moved[i]);
    while (i < last) {
      final cycleBegin = i;
      Value t = _values[i];
      do {
        final next = nextF(i);
        final tt = t;
        t = _values[next];
        _values[next] = tt;
        moved[i] = true;
        i = next;
      } while (i != cycleBegin);
      while (i < last && moved[i]) {
        i++;
      }
    }
  }

  ///
  /// The P(x,y) function:  Convert a complex matrix from "complex-like" form
  /// to partitioned form
  ///
  void convertToZP() {
    isLU = false;
    if (columns % 2 == 1) {
      throw CalculatorError(11);
    }
    int _newHome(final int i) {
      final r = i ~/ columns; // old row
      final c = i % columns;
      final rn = (c % 2 == 0) ? r : r + rows; // new row
      final cn = c ~/ 2;
      // @@ TODO rm print('($r,$c) ($rn, $cn)  $rows $columns');
      return rn * (columns ~/ 2) + cn;
    }

    _internalMove(1, length - 1, _newHome);
    _columns ~/= 2;
  }

  ///
  /// The C(x,y) function:  Convert a complex matrix from partitioned to
  /// "complex-like" form
  ///
  void convertToZC() {
    isLU = false;
    if (rows % 2 == 1) {
      throw CalculatorError(11);
    }
    final newRows = rows ~/ 2;
    final newColumns = columns * 2;
    int _newHome(final int i) {
      final r = i ~/ columns;
      final c = i % columns;
      final rn = r % newRows;
      final cn = c * 2 + (r >= newRows ? 1 : 0);
      return rn * newColumns + cn;
    }

    _internalMove(1, length - 1, _newHome);
    _columns *= 2;
  }

  ///
  /// Convert from ZP form to ZTilde, that is,
  ///
  ///     from:   X      to     X    -Y
  ///             Y             Y     X
  ///
  void convertToZTilde(Model15 m) {
    final rows = this.rows;
    if (rows % 2 != 0) {
      throw CalculatorError(11);
    }
    final oldColumns = this.columns;
    final columns = oldColumns * 2;
    resize(m, rows, columns);
    isLU = false;
    // Copy Y:
    for (int r = rows ~/ 2; r < rows; r++) {
      for (int c = 0; c < oldColumns; c++) {
        final y = _values[r * oldColumns + c];
        set(r, c, y);
      }
    }
    // Copy X into both locations:
    for (int r = rows ~/ 2 - 1; r >= 0; r--) {
      for (int c = oldColumns - 1; c >= 0; c--) {
        final x = _values[r * oldColumns + c];
        set(r, c, x);
        set(r + rows ~/ 2, c + columns ~/ 2, x);
      }
    }
    // And finally, copy Y to -Y:
    for (int r = rows ~/ 2; r < rows; r++) {
      for (int c = 0; c < oldColumns; c++) {
        final y = get(r, c);
        set(r - rows ~/ 2, c + oldColumns, y.negateAsFloat());
      }
    }
  }

  ///
  /// Convert from ZTilde to ZP
  ///
  ///    from:   X    -YC    to    X
  ///            Y     XC          Y
  ///
  /// where XC and YC are ignored and discarded.
  ///
  void convertFromZTilde(Model15 m) {
    final rows = this.rows;
    final columns = this.columns;
    if (rows % 2 != 0 || columns % 2 != 0) {
      throw CalculatorError(11);
    }
    final newColumns = columns ~/ 2;
    isLU = false;

    // Copy X:
    for (int r = 0; r < rows ~/ 2; r++) {
      for (int c = 0; c < newColumns; c++) {
        final x = get(r, c);
        _values[r * newColumns + c] = x;
      }
    }
    // Copy Y:
    for (int r = rows ~/ 2; r < rows; r++) {
      for (int c = 0; c < newColumns; c++) {
        final y = get(r, c);
        _values[r * newColumns + c] = y;
      }
    }

    resize(m, rows, newColumns);
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

///
/// A transpose view of a matrix.
///
class TransposeMatrix extends AMatrix {
  final AMatrix _m;

  TransposeMatrix(this._m);

  @override
  int get rows => _m.columns;

  @override
  int get columns => _m.rows;

  @override
  Value get(int row, int col) => _m.get(col, row);

  @override
  void set(int row, int col, Value v) => _m.set(col, row, v);
}
