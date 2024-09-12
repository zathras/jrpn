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
*/
part of 'model.dart';

abstract class SignMode {
  SignMode._p();

  static final IntegerSignMode onesComplement = _OnesComplement._p('1');
  static final IntegerSignMode twosComplement = _TwosComplement._p('2');
  static final IntegerSignMode unsigned = _Unsigned._p('u');
  static final SignMode float = _Float._p();

  String get annunciatorText;

  Value negate(Value v, Model m);

  bool get doesSignExtension;

  bool isZero(NumStatus m, Value value) => value == Value.zero;

  ///
  /// Increment a number by 1 or -1.  It's convenient to do this here, because
  /// the DSZ and ISZ instructions work in both float and integer mode.
  /// //
  Value increment(NumStatus m, Value valueI, int by);

  int compare(NumStatus m, Value x, Value y);

  ///
  /// Translate value to an int that could be a label, without any range
  /// checks to see if it's a valid label.  Always returns a non-negative int.
  ///
  int valueToLabel(Value v, Model m);
}

abstract class IntegerSignMode extends SignMode {
  final String _jsonName;
  IntegerSignMode._p(this._jsonName) : super._p();

  ///
  /// Text for the annunciator on the LCD display, if we're showing it.
  ///
  String get statusText;

  @override
  Value negate(Value v, Model m);

  /// Interpret v as an integer according to the sign mode and the model's
  /// word size, and return the result as a BigInt.
  BigInt toBigInt(Value v, NumStatus m);

  // convert a BigInto to a Value, setting the G flag of NumStatus on overflow.
  Value fromBigInt(BigInt v, NumStatus status, bool setOverflow);

  BigInt maxValue(NumStatus m);
  BigInt minValue(NumStatus m);

  void intAdd(Model m) => _intAdd(m.x.internal, m.y.internal, m);

  void _intAdd(BigInt xi, BigInt yi, Model m);

  void intSubtract(Model m) {
    final Value x = m.x;
    final BigInt xi = x.internal;
    final BigInt yi = m.y.internal;
    _intSubtract(xi, yi, m);
    m.lastX = x;
    m.cFlag = xi > yi;
    // The 16C sets carry whenever a binary subtraction results in a
    // borrow into the most significant bit, and clears it otherwise.
    // That's not the same as what you get by adding the negation.
  }

  void _intSubtract(BigInt xi, BigInt yi, Model m);

  static final List<IntegerSignMode> _values = [
    SignMode.onesComplement,
    SignMode.twosComplement,
    SignMode.unsigned
  ];
  String toJson() => _jsonName;

  static IntegerSignMode fromJson(String val) {
    for (final v in _values) {
      if (v._jsonName == val) {
        return v;
      }
    }
    throw ArgumentError('Bad DisplayMode:  $val');
  }

  @override
  int compare(NumStatus m, Value x, Value y) {
    final bx = toBigInt(x, m);
    final by = toBigInt(y, m);
    return bx.compareTo(by);
  }

  @override
  Value increment(NumStatus m, Value valueI, int by) =>
      fromBigInt(toBigInt(valueI, m) + BigInt.from(by), m, false);
  // ISZ/DSZ does not affect carry or out-of-range flags:  16C p. 90

  static final BigInt _tooBig = BigInt.from(1000);

  @override
  int valueToLabel(Value v, Model m) {
    final bigLabel = toBigInt(v, m).abs();
    if (bigLabel > _tooBig) {
      return 1000; // Avoid overflow
    } else {
      return bigLabel.toInt();
    }
  }

  bool get isUnsigned => false;
}

class _OnesComplement extends IntegerSignMode {
  _OnesComplement._p(super.j) : super._p();

  @override
  String get annunciatorText => "1's";

  @override
  BigInt maxValue(NumStatus m) => m.signMask - BigInt.one;

  @override
  BigInt minValue(NumStatus m) => BigInt.one - m.signMask;

  @override
  Value negate(Value v, Model m) {
    // 0 negates to -0, and -0 negates to 0.
    // Source:  https://github.com/zathras/jrpn/issues/85
    return Value.fromInternal(v.internal ^ m.wordMask);
  }

  @override
  BigInt toBigInt(Value v, NumStatus m) {
    BigInt internal = v.internal;
    if ((internal & m.signMask) == BigInt.zero) {
      return internal;
    } else {
      return internal - m.wordMask;
      // Works for -0
    }
  }

  @override
  Value fromBigInt(BigInt v, NumStatus m, bool setOverflow) {
    if (v >= BigInt.zero) {
      if (v <= maxValue(m)) {
        if (setOverflow) {
          m.gFlag = false;
        }
        return Value.fromInternal(v);
      } else {
        if (setOverflow) {
          m.gFlag = true;
        }
        return Value.fromInternal(v & m.wordMask);
      }
    } else {
      if (v >= minValue(m)) {
        if (setOverflow) {
          m.gFlag = false;
        }
        return Value.fromInternal(v + m.wordMask);
      } else {
        if (setOverflow) {
          m.gFlag = true;
        }
        return Value.fromInternal(
            (v + m.wordMask + (BigInt.one << (v.bitLength + 1))) & m.wordMask);
      }
    }
  }

  @override
  void _intAdd(BigInt xi, BigInt yi, Model m) {
    BigInt r = xi + yi;
    if (r <= m.wordMask) {
      m.cFlag = false;
    } else {
      m.cFlag = true;
      r = r + BigInt.one;
      r = r & m.wordMask;
    }
    if (r == m.wordMask) {
      // -0
      m.popSetResultX = Value.zero;
    } else {
      m.popSetResultX = Value.fromInternal(r);
    }
    m.gFlag = (xi & m.signMask == yi & m.signMask) &&
        (xi & m.signMask != r & m.signMask);
  }

  @override
  void _intSubtract(BigInt xi, BigInt yi, Model<ProgramOperation> m) =>
      _intAdd(xi ^ m._wordMask, yi, m);

  @override
  String get statusText => '1';

  @override
  bool get doesSignExtension => true;

  @override
  bool isZero(NumStatus m, Value value) =>
      value == Value.zero || value.internal == m.wordMask;
}

class _TwosComplement extends IntegerSignMode {
  _TwosComplement._p(super.j) : super._p();

  @override
  String get annunciatorText => '';

  @override
  BigInt maxValue(NumStatus m) => m.signMask - BigInt.one;
  @override
  BigInt minValue(NumStatus m) => -m.signMask;

  @override
  Value negate(Value v, Model m) {
    BigInt i = v.internal;
    if (-i == m.signMask) {
      // overflow
      m.gFlag = true;
    }
    return Value.fromInternal(((i ^ m.wordMask) + BigInt.one) & m.wordMask);
  }

  @override
  BigInt toBigInt(Value v, NumStatus m) {
    BigInt internal = v.internal;
    if ((internal & m.signMask) == BigInt.zero) {
      return internal;
    } else {
      return (internal - m.wordMask) - BigInt.one;
    }
  }

  @override
  Value fromBigInt(BigInt v, NumStatus m, bool setOverflow) {
    if (v >= BigInt.zero) {
      if (v <= maxValue(m)) {
        if (setOverflow) {
          m.gFlag = false;
        }
        return Value.fromInternal(v);
      } else {
        if (setOverflow) {
          m.gFlag = true;
        }
        return Value.fromInternal(v & m.wordMask);
      }
    } else {
      if (v >= minValue(m)) {
        if (setOverflow) {
          m.gFlag = false;
        }
        return Value.fromInternal(v + m.wordMask + BigInt.one);
      } else {
        if (setOverflow) {
          m.gFlag = true;
        }
        return Value.fromInternal(
            (v + m.wordMask + BigInt.one + (BigInt.one << (v.bitLength + 1))) &
                m.wordMask);
      }
    }
  }

  @override
  void _intAdd(BigInt xi, BigInt yi, Model m) {
    BigInt r = xi + yi;
    if (r <= m.wordMask) {
      m.cFlag = false;
      m.popSetResultX = Value.fromInternal(r);
    } else {
      m.cFlag = true;
      m.popSetResultX = Value.fromInternal(r & m.wordMask);
    }
    m.gFlag = (xi & m.signMask == yi & m.signMask) &&
        (xi & m.signMask != r & m.signMask);
  }

  @override
  void _intSubtract(BigInt xi, BigInt yi, Model<ProgramOperation> m) =>
      _intAdd(((xi ^ m.wordMask) + BigInt.one) & m.wordMask, yi, m);

  @override
  String get statusText => '2';

  @override
  bool get doesSignExtension => true;
}

class _Unsigned extends IntegerSignMode {
  _Unsigned._p(super.j) : super._p();

  @override
  String get annunciatorText => 'U';

  @override
  BigInt maxValue(NumStatus m) => m.wordMask;
  @override
  BigInt minValue(NumStatus m) => BigInt.zero;

  @override
  Value negate(Value v, Model m) {
    // Set overflow and return the two's complement negation, as per page
    // 30 of the users guide.  See issue #121.
    m.gFlag = true;
    BigInt i = v.internal;
    return Value.fromInternal(((i ^ m.wordMask) + BigInt.one) & m.wordMask);
  }

  @override
  BigInt toBigInt(Value v, NumStatus m) {
    return v.internal;
  }

  @override
  Value fromBigInt(BigInt v, NumStatus m, bool setOverflow) {
    if (v < BigInt.zero) {
      if (setOverflow) {
        m.gFlag = true;
      }
      final bits = max(m.wordSize, v.bitLength + 1);
      return Value.fromInternal((v + (BigInt.one << bits)) & m.wordMask);
    } else if (v > maxValue(m)) {
      if (setOverflow) {
        m.gFlag = true;
      }
      return Value.fromInternal(v & m.wordMask);
    } else {
      if (setOverflow) {
        m.gFlag = false;
      }
      return Value.fromInternal(v);
    }
  }

  @override
  void _intAdd(BigInt xi, BigInt yi, Model m) {
    BigInt r = xi + yi;
    if (r <= m.wordMask) {
      m.cFlag = false;
      m.gFlag = false;
      m.popSetResultX = Value.fromInternal(r);
    } else {
      m.cFlag = true;
      m.gFlag = true;
      m.popSetResultX = Value.fromInternal(r & m.wordMask);
    }
  }

  @override
  void _intSubtract(BigInt xi, BigInt yi, Model<ProgramOperation> m) {
    BigInt r = yi - xi;
    if (r < BigInt.zero) {
      r += m._signMask << 1;
      m.gFlag = true;
    }
    assert(r <= m.wordMask);
    m.popSetResultX = Value.fromInternal(r);
  }

  @override
  String get statusText => '0';

  @override
  bool get doesSignExtension => false;

  @override
  bool get isUnsigned => true;
}

class _Float extends SignMode {
  _Float._p() : super._p();

  @override
  String get annunciatorText => ''; // Float mode is already visually obvious

  @override
  Value negate(Value v, Model m) => v.negateAsFloat();

  @override
  bool get doesSignExtension => false;

  @override
  Value increment(NumStatus m, Value v, int by) =>
      Value.fromDouble(v.asDouble + by);

  @override
  int compare(NumStatus m, Value x, Value y) {
    final fx = x.asDouble;
    final fy = y.asDouble;
    return fx.compareTo(fy);
  }

  @override
  int valueToLabel(Value v, Model<ProgramOperation> m) {
    int? mat = v.asMatrix;
    if (mat != null) {
      return mat + 20;
    }
    final bigLabel = v.asDouble.abs();
    if (bigLabel > 1000) {
      return 1000; // avoid overflow
    } else {
      return bigLabel.floor();
    }
  }
}
