import 'package:jrpn/m/model.dart';

class Matrix {
  final String name;
  List<Value> _values = [];
  int _columns = 0;
  int get _rows => (_values.isEmpty) ? 0 : (_values.length ~/ _columns);

  Matrix(this.name);

  /// Number of registers this matrix occupies
  int get length => _values.length;

  void resize(int rows, int columns) {
    if (rows < 0 || columns < 0) {
      throw ArgumentError('rows $rows columns $columns');
    }
    final values = List<Value>.filled(rows * columns, Value.zero);
    for (int i = 0; i < values.length && i < _values.length; i++) {
      values[i] = _values[i];
    }
    _columns = (rows == 0) ? 0 : columns;
    _values = values;
  }

  Map<String, Object> toJson() =>
      {'columns': _columns, 'values': _values.map((v) => v.toJson()).toList()};

  void decodeJson(Map<String, dynamic> m) {
    _columns = m['columns'] as int;
    final v = m['values'] as List;
    _values = List.generate(v.length, (i) => Value.fromJson(v[i] as String),
        growable: false);
  }

  @override
  String toString() => 'Matrix($lcdString)';

  String get lcdString {
    final r = _rows.toString().padLeft(3);
    final c = _columns.toString().padLeft(3);
    return '$name    $r$c';
  }
}
