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

///
/// A matrix stored in the 15C's registers, with values held in the 15C's
/// internal format, with ten decimal digits of mantissa.
///
class Matrix {
  final String name;
  List<Value> _values = [];

  /// List of rows swapped in the LU decomposition
  List<int>? _rowSwaps;
  int _columns = 0;
  int get _rows => (_values.isEmpty) ? 0 : (_values.length ~/ _columns);

  Matrix(this.name);

  /// Number of registers this matrix occupies
  int get length => _values.length;

  int get rows => _rows;
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
      _rowSwaps = null; // Do early so get/set work on "raw" matrix.
      for (int r = 0; r < rows; r++) {
        final sr = swaps[r];
        if (sr != r) {
          assert(sr > r);
          for (int c = 0; c < columns; c++) {
            final t = get(r, c);
            set(r, c, get(sr, c));
            set(sr, c, t);
          }
          // Don't swap back when we get up to sr!
          swaps[sr] = sr;
        }
      }
    }
    assert(isLU == v);
  }

  void resize(int rows, int columns) {
    if (rows < 0 || columns < 0) {
      throw ArgumentError('rows $rows columns $columns');
    }
    isLU = false;
    final values = List<Value>.filled(rows * columns, Value.zero);
    for (int i = 0; i < values.length && i < _values.length; i++) {
      values[i] = _values[i];
    }
    _columns = (rows == 0) ? 0 : columns;
    _values = values;
  }

  void checkIndices(int row, int col) {
    if (row < 0 || col < 0 || row >= rows || col >= columns) {
      throw CalculatorError(3);
    }
  }

  void set(int row, int col, Value v) {
    checkIndices(row, col);
    final swaps = _rowSwaps;
    if (swaps != null) {
      row = swaps[row];
    }
    _values[row * columns + col] = v;
  }

  void setF(int row, int col, double d) => set(row, col, Value.fromDouble(d));

  Value get(int row, int col) {
    checkIndices(row, col);
    final swaps = _rowSwaps;
    if (swaps != null) {
      row = swaps[row];
    }
    return _values[row * columns + col];
  }

  double getF(int row, int col) => get(row, col).asDouble;

  ///
  /// Swap rows in a matrix holding an LU decomposition.
  ///
  void swapRowsLU(int r1, int r2) {
    print("@@@@ Swap $r1 $r2");
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
  String toString() {
    final sb = StringBuffer('Matrix(');
    sb.write(lcdString);
    sb.writeln('):');
    if (columns == 0 || rows == 0) {
      sb.writeln('    empty');
    }
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < columns; c++) {
        if (c == 0) {
          sb.write('    ');
        }
        const fmt = FixFloatFormatter(4);
        sb.write(fmt.format(get(r, c)).padLeft(12));
      }
      sb.writeln();
    }
    return sb.toString();
  }

  String get lcdString {
    final r = _rows.toString().padLeft(3);
    final c = _columns.toString().padLeft(3);
    final luString = isLU ? '--' : '  ';
    return '$name$luString  $r$c';
  }
}
