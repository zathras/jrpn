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
*/
part of 'model.dart';

///
/// Helper to select something based on whether the calculator's display
/// mode is one of the int modes, or float mode.  We
/// use a factory template to pull off dependency inversion between the
/// model (us) and the controller, for the sake of OO purity.
///
/// NB:  In Dart, this isn't as statically type-safe as one might imagine,
/// because Dart allows unsound covariant assignment, viz
/// https://github.com/dart-lang/sdk/issues/45731
/// That's mostly harmless here
///
abstract class DisplayModeSelector<R, A> {
  const DisplayModeSelector();
  R selectInteger(A arg);
  R selectFloat(A arg);
  R selectComplex(A arg);
}

///
/// Display mode and a bit more.  This selects between number base, float versus
/// integer, and complex versus normal.  The actual code is almost all
/// concerned with formatting and display, but this is also a convenient place
/// to select operations based on integer/float/complex mode.
///
abstract class DisplayMode {
  DisplayMode._protected();

  static final IntegerDisplayMode hex = _HexMode();
  static final IntegerDisplayMode oct = _OctalMode();
  static final IntegerDisplayMode bin = _BinaryMode();
  static final IntegerDisplayMode decimal = _DecimalMode();

  /// digits after the decimal point.  If digits is 10, always
  /// display in scientific notation.
  static DisplayMode float(int digits) => _FloatMode(digits);

  static final List<DisplayMode> _intValues = [hex, oct, bin, decimal];
  String get _jsonName;

  /// Put calculator in floating-point mode, displaying digits
  int get radix;
  int get commaDistance;

  Value? tryParse(String s, NumStatus m);

  ///
  /// Select something based on whether we're in an int mode or a float
  /// mode.
  ///
  R select<R, A>(DisplayModeSelector<R, A> selector, A arg);

  /// How this mode is shown on the LCD display
  String get displayName;

  ///
  /// Are digits right-justified in this mode?  If not, they'll be
  /// left-justified, like " 1.0       ".
  ///
  bool get rightJustify;

  String addCommas(String s) {
    String r = '';
    final int dp = s.indexOf('.');
    if (dp > -1) {
      r = s.substring(dp);
      s = s.substring(0, dp);
    }
    while (s.trim().length > commaDistance) {
      r = ',${s.substring(s.length - commaDistance)}$r';
      s = s.substring(0, s.length - commaDistance);
    }
    return s + r;
  }

  String toJson() => _jsonName;

  static DisplayMode fromJson(dynamic val) {
    for (final v in _intValues) {
      if (v._jsonName == val) {
        return v;
      }
    }
    if ((val as String).startsWith('f')) {
      return float(int.parse(val.substring(1)));
    }
    throw ArgumentError('Bad DisplayMode:  $val');
  }

  String format(Value v, Model m);

  bool get isFloatMode => false;

  ///
  /// Convert values in the model when switching between float and int,
  /// and vice-versa.  We're switching from this mode to next.  The 16C
  /// does interesting things with x and y here.
  ///
  void convertValuesTo(DisplayMode next, Model model);
  void _convertValuesFromInt(Model model) {}
  void _convertValuesFromFloat(Model model) {}

  ///
  /// Give the calculator's effective sign mode, considering the
  /// current display mode (which might be float), and the sign mode
  /// that was last set when the calculator was in integer mode (which
  /// might be now).
  ///
  SignMode signMode(IntegerSignMode integerSignMode);

  void setComplexMode(Model m, bool v);
}

abstract class IntegerDisplayMode extends DisplayMode {
  IntegerDisplayMode._protected() : super._protected();

  @override
  Value? tryParse(String s, NumStatus m) {
    s = s.replaceAll(',', '');
    BigInt? v = BigInt.tryParse(s, radix: radix);
    if (v == null) {
      return null;
    }
    return _toValue(v, m);
  }

  Value? _toValue(BigInt v, NumStatus m);

  @override
  R select<R, A>(DisplayModeSelector<R, A> selector, A arg) =>
      selector.selectInteger(arg);

  bool get _leadingZeroesOK => true;

  int get _bitsPerDigit;

  @override
  bool get rightJustify => true;

  @override
  SignMode signMode(IntegerSignMode integerSignMode) => integerSignMode;

  @override
  String format(Value v, Model m) {
    String s = v.internal.toRadixString(radix);
    if (_leadingZeroesOK && m.displayLeadingZeros) {
      final int digits = (m.wordSize + _bitsPerDigit - 1) ~/ _bitsPerDigit;
      final int n = digits - s.length;
      // 64 zeroes (63 would actually do):
      s = '0000000000000000000000000000000000000000000000000000000000000000'
              .substring(0, n) +
          s;
    }
    return addCommas(s) + displayName;
  }

  @override
  void convertValuesTo(DisplayMode next, Model model) =>
      next._convertValuesFromInt(model);

  @override
  void _convertValuesFromFloat(Model model) {
    model.setYZT(Value.zero);
    model.lastX = Value.zero;
    final double x = model.x.asDouble;
    if (x == 0.0) {
      model.x = Value.zero;
    } else {
      final minM = BigInt.one << 31;
      final maxM = (BigInt.one << 32) - BigInt.one;
      double log2 = log(x.abs()) / log(2.0);
      int exp = log2.floor() - 31;
      BigInt m = BigInt.from((x / pow(2.0, exp)).round()); // round
      if (m.abs() > maxM) {
        exp++;
        m = BigInt.from((x / pow(2.0, exp)).round());
      }
      assert(m.abs() >= minM && m.abs() <= maxM,
          '$minM <= ${m.abs()} <= $maxM for $x (exponent $exp)');

      model.yI = m;
      model.xI = BigInt.from(exp);
    }
  }

  @override
  void setComplexMode(Model m, bool v) {
    assert(false);
  }
}

abstract class _Pow2IntegerMode extends IntegerDisplayMode {
  _Pow2IntegerMode() : super._protected();

  @override

  /// When a hex, octal or binary number is entered, the sign bit is
  /// given in the bit pattern, not as a minus sign.  We can't go through
  /// a signed BigInt; that's more complicated, and it loses the distinction
  /// between 0 and -0 in 1's complement mode.
  Value? _toValue(BigInt v, NumStatus m) {
    if (v < BigInt.zero || v > m.wordMask) {
      return null;
    } else {
      return Value.fromInternal(v);
    }
  }
}

class _HexMode extends _Pow2IntegerMode {
  @override
  int get radix => 16;

  @override
  String get displayName => ' h';

  @override
  int get commaDistance => 4;

  @override
  int get _bitsPerDigit => 4;

  @override
  String get _jsonName => 'h';
}

class _OctalMode extends _Pow2IntegerMode {
  @override
  int get radix => 8;

  @override
  String get displayName => ' o';

  @override
  int get commaDistance => 4;

  @override
  int get _bitsPerDigit => 3;

  @override
  String get _jsonName => 'o';
}

class _BinaryMode extends _Pow2IntegerMode {
  @override
  int get radix => 2;

  @override
  String get displayName => ' b';

  @override
  int get commaDistance => 4;

  @override
  int get _bitsPerDigit => 1;

  @override
  String get _jsonName => 'b';
}

class _DecimalMode extends IntegerDisplayMode {
  _DecimalMode() : super._protected();

  @override
  int get radix => 10;

  @override
  String get displayName => ' d';

  @override
  int get commaDistance => 3;

  @override
  bool get _leadingZeroesOK => false;

  @override
  int get _bitsPerDigit {
    assert(false); // Not used, and not particularly meaningful
    return 4;
  }

  @override
  Value? _toValue(BigInt v, NumStatus m) {
    final IntegerSignMode sm = m.integerSignMode;
    if (v < sm.minValue(m) || v > sm.maxValue(m)) {
      return null;
    }
    return sm.fromBigInt(v, m);
  }

  @override
  String format(Value v, Model m) {
    if (m.signMode == SignMode.unsigned) {
      return super.format(v, m);
    }
    final BigInt num = v.internal;
    if (BigInt.zero.compareTo(m.signMask & num) == 0) {
      // non-negative
      return super.format(v, m);
    }
    return '-${super.format(m.signMode.negate(v, m), m)}';
  }

  @override
  String get _jsonName => 'd';
}

class _FloatMode extends DisplayMode {
  final int digits;

  _FloatMode(this.digits) : super._protected();

  @override
  void setComplexMode(Model m, bool v) {
    if (v) {
      m.displayMode = _ComplexMode(digits);
    }
  }

  @override
  int get radix => 10;

  @override
  int get commaDistance => 3;

  @override
  Value? tryParse(String s, NumStatus m) {
    double? d = double.tryParse(s);
    if (d == null) {
      return null;
    }
    return Value.fromDouble(d);
  }

  @override
  R select<R, A>(DisplayModeSelector<R, A> selector, A arg) =>
      selector.selectFloat(arg);

  @override
  String get displayName => '';

  @override
  bool get rightJustify => false;

  @override
  SignMode signMode(IntegerSignMode integerSignMode) => SignMode.float;

  /// Format a float according to a VERY strict format.  The result
  /// has to fit in an 11  digit display, with one digit reserved for
  /// the mantissa sign.  If in scientific mode, that leaves seven
  /// digits for the mantissa.
  ///
  /// LcdDisplay understands formatting, like commas and decimal points.
  /// These formatting characters don't take up space.  Also, the 'E"
  /// must be upper-case, but is rendered on the display as a space
  /// (or a '-' for a negative exponent) - we always provided a two-digit
  /// exponent with a sign, like "E+07'.
  @override
  String format(Value v, Model m) => _format(v, m);

  String _format(Value v, Model m) {
    assert(m.signMode == SignMode.float);
    final double n = v.asDouble;
    String s;
    int nonspaceChars = 0;
    if (n == double.infinity) {
      s = '9.999999E+99';
      nonspaceChars++; // The E
    } else if (n == double.negativeInfinity) {
      s = '-9.999999E+99';
      nonspaceChars++; // The E
    } else {
      if (digits == 10) {
        s = n.toStringAsExponential(7);
      } else {
        s = n.abs().toStringAsFixed(digits);
        if (digits == 0) {
          s = '$s.';
        }
        if (s.length > 11) {
          int d = digits + 11 - s.length;
          if (d < 0) {
            s = n.abs().toStringAsExponential(7);
          } else {
            s = n.abs().toStringAsFixed(d);
            if (d == 0) {
              s = '$s.';
            }
          }
        }
        if (n < 0.0) {
          s = '-$s';
        }
        if (v != Value.zero && s == 0.0.toStringAsFixed(digits)) {
          s = n.toStringAsExponential();
        }
      }
      if (s.contains('e')) {
        // Round to 7 decimal digits of mantissa.  So, for example,
        // 9.999999999e30 becomes 1.000000e31
        final exs = n.toStringAsExponential(6);
        int i = exs.indexOf('e');
        s = '${exs.substring(0, i)}E'; // cf. Digit.digits['E']
        nonspaceChars++; // The E
        i++;
        final String sign = exs.substring(i, i + 1);
        assert(sign == '-' || sign == '+', 'exponent sign not found in $exs');
        i++;
        s = s + sign;
        if (i == exs.length - 1) {
          s = '${s}0';
        }
        s = s + exs.substring(i);
      }
      if (s == '1.000000E+100') {
        // really 9.999999999e+99 or thereabouts
        s = '9.999999E+99';
      } else if (s == '-1.000000E+100') {
        s = '-9.999999E+99';
      }
    }
    if (s.contains('.')) {
      nonspaceChars++;
    }
    if (s.startsWith('-')) {
      nonspaceChars++;
      // It doesn't really take up space since a digit is reserved
    }
    try {
      s = s + '            '.substring(s.length + 2 - nonspaceChars);
      // ignore: avoid_catches_without_on_clauses
    } catch (e) {
      assert(false, 'float right-justify failure $e'); // Yes, I'm a coward
    }
    return addCommas(s);
  }

  @override
  bool get isFloatMode => true;

  @override
  void convertValuesTo(DisplayMode next, Model m) =>
      next._convertValuesFromFloat(m);

  @override
  void _convertValuesFromInt(Model m) {
    if (m.y == Value.zero) {
      m.x = Value.zero;
    } else {
      final double x = m.xI.toDouble();
      final double y = m.yI.toDouble();
      final Value r = Value.fromDouble(y * pow(2.0, x));
      m.x = r;
      if (r == Value.fInfinity || r == Value.fNegativeInfinity) {
        m.floatOverflow = true;
      }
    }
    m.setYZT(Value.zero);
    m.lastX = Value.zero;
  }

  @override
  int get hashCode => _jsonName.hashCode & digits.hashCode;

  @override
  bool operator ==(Object? other) =>
      (other is _FloatMode) ? (digits == other.digits) : false;

  @override
  String get _jsonName => 'f$digits';
}

class _ComplexMode extends _FloatMode {
  _ComplexMode(int digits) : super(digits);

  @override
  void setComplexMode(Model m, bool v) {
    if (v) {
      m.displayMode = _FloatMode(digits);
    }
  }

  @override
  R select<R, A>(DisplayModeSelector<R, A> selector, A arg) =>
      selector.selectComplex(arg);
}
