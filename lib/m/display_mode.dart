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
/// That's mostly harmless here.
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
  /// display in scientific notation, as per the 16C manual, page 56.
  static DisplayMode float(int fractionDigits) => (fractionDigits == 10)
      ? _FloatMode(const _Sci16FloatFormatter())
      : _FloatMode(_Fix16FloatFormatter(fractionDigits));
  static DisplayMode fix(int fractionDigits, bool complex) => complex
      ? _ComplexMode(FixFloatFormatter(fractionDigits))
      : _FloatMode(FixFloatFormatter(fractionDigits));
  static DisplayMode sci(int fractionDigits, bool complex) => complex
      ? _ComplexMode(SciFloatFormatter(fractionDigits))
      : _FloatMode(SciFloatFormatter(fractionDigits));
  static DisplayMode eng(int fractionDigits, bool complex) => complex
      ? _ComplexMode(_EngFloatFormatter(fractionDigits))
      : _FloatMode(_EngFloatFormatter(fractionDigits));

  static final List<DisplayMode> _intValues = [hex, oct, bin, decimal];
  String get _jsonName;

  /// Put calculator in floating-point mode, displaying fractionDigits
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

  static DisplayMode fromJson(dynamic val, bool isComplex) {
    for (final v in _intValues) {
      if (v._jsonName == val) {
        return v;
      }
    }
    if ((val as String).startsWith('f')) {
      return float(int.parse(val.substring(1)));
    } else if (val.startsWith('x')) {
      return fix(int.parse(val.substring(1)), isComplex);
    } else if (val.startsWith('s')) {
      return sci(int.parse(val.substring(1)), isComplex);
    } else if (val.startsWith('e')) {
      return eng(int.parse(val.substring(1)), isComplex);
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

  ///
  /// Gives the least significant digit when value is displayed, where the units
  /// digit is 0, and negative is to the right of the decimal.  For example,
  /// for FIX-3, gives -3 (10^-3 is 0.001), unless the value is such that
  /// scientific notation would be used.
  ///
  /// This is needed for the HP 15C's integrate function.
  ///
  int leastSignificantDigit(double value);
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

  @override
  int leastSignificantDigit(double value) => 1;
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
  final FloatFormatter _formatter;

  _FloatMode(this._formatter) : super._protected();

  @override
  void setComplexMode(Model m, bool v) {
    if (v) {
      m.displayMode = _ComplexMode(_formatter);
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

  /// Format a float according to a VERY strict format.  The result
  /// has to fit in an 11  digit display, with one digit reserved for
  /// the mantissa sign.  If in scientific mode, that leaves seven
  /// digits for the mantissa.
  ///
  /// LcdDisplay understands formatting, like commas and decimal points.
  /// These formatting characters don't take up space.  Also, the 'E"
  /// must be upper-case, but is rendered on the display as a space
  /// (or a '-' for a negative exponent) - we always provide a two-digit
  /// exponent with a sign, like "E+07'.
  @override
  String format(Value v, Model m) =>
      addCommas(_formatter.format(v, m.settings.windowEnabled));

  @override
  int get hashCode => Object.hash(_jsonName, _formatter);

  @override
  bool operator ==(Object? other) =>
      (other is _FloatMode) ? _jsonName == other._jsonName : false;

  @override
  String get _jsonName => _formatter._jsonName;

  @override
  int leastSignificantDigit(double value) =>
      _formatter.leastSignificantDigit(value);
}

class _ComplexMode extends _FloatMode {
  _ComplexMode(FloatFormatter formatter) : super(formatter);

  @override
  void setComplexMode(Model m, bool v) {
    if (!v) {
      m.displayMode = _FloatMode(_formatter);
    }
  }

  @override
  R select<R, A>(DisplayModeSelector<R, A> selector, A arg) =>
      selector.selectComplex(arg);
}

@immutable
abstract class FloatFormatter {
  const FloatFormatter();

  String get _jsonName;
  int get fractionDigits;

  static final int _ascii0 = '0'.codeUnitAt(0);

  ///
  /// Format the unsigned part of the mantissa to the given number of digits.
  /// Result will be either digits or digits+1 characters long.
  ///
  @protected
  String formatMantissaU(Value v, int digits) {
    assert(digits >= 0 && digits <= 10);
    final charCodes = List.filled(10, 0);
    int i = charCodes.length;
    if (digits < 10) {
      bool carry = v.mantissaDigit(digits) >= 5;
      while (carry && digits > 0) {
        final d = v.mantissaDigit(--digits) + 1;
        if (d == 10) {
          charCodes[--i] = _ascii0;
        } else {
          charCodes[--i] = _ascii0 + d;
          carry = false;
        }
      }
      if (carry) {
        charCodes[--i] = _ascii0 + 1;
      }
    }
    while (digits > 0) {
      charCodes[--i] = _ascii0 + v.mantissaDigit(--digits);
    }
    return (String.fromCharCodes(charCodes, i));
  }

  ///
  /// Format in scientific format, as modified by the
  /// (potentially overridden) constrainExponent function.
  ///
  @protected
  String formatScientific(Value v, int digits) {
    int exp = v.exponent;
    String m = formatMantissaU(v, digits);
    String minus = v.mantissaDigit(-1) == 9 ? '-' : '';
    if (m.length > digits) {
      exp++;
      if (exp == 100) {
        if (digits == 7) {
          return '${minus}9.999999E+99';
        } else {
          return formatScientific(v, 7);
        }
      }
      m = formatMantissaU(v, digits - 1);
    }
    int shownExp = constrainExponent(exp);
    final int dpOffset = exp - shownExp;
    if (digits < dpOffset + 1) {
      m = m + '00'.substring(0, dpOffset + 1 - digits);
      digits = dpOffset + 1;
    }

    final sp = '       '.substring(min(digits, 7));
    final eSign = shownExp >= 0 ? '+' : '-';
    shownExp = shownExp.abs();
    return '$minus${m.substring(0, 1 + dpOffset)}.${m.substring(dpOffset + 1)}'
        '${sp}E$eSign${shownExp ~/ 10}${shownExp % 10}';
  }

  @protected
  int constrainExponent(int exp) => exp;

  @protected
  String? formatFixed(Value v, int fractionDigits) {
    int exp = v.exponent;
    // First, try assuming no carry
    int mantissaDigits = min(10, exp + fractionDigits + 1);
    if (mantissaDigits < 0) {
      return null;
    }
    String mantissa = formatMantissaU(v, mantissaDigits);
    if (mantissa.length > mantissaDigits) {
      // If we got a carry,
      // it's like our exponent is one higher.
      exp++;
    } else if (mantissa.isEmpty) {
      return null;
    }
    fractionDigits = mantissa.length - exp - 1;
    if (fractionDigits < 0 || fractionDigits > 9) {
      return null;
    }
    int i = mantissa.length - fractionDigits;
    if (i < 0) {
      return null;
    } else if (i == 0) {
      mantissa = '0$mantissa';
      i = 1;
    }
    String minus = v.mantissaDigit(-1) == 9 ? '-' : '';
    final sp = '         '.substring(mantissa.length - 1);
    return '$minus${mantissa.substring(0, i)}.${mantissa.substring(i)}$sp';
  }

  String format(Value v, bool windowEnabled);

  ///
  /// See [DisplayMode.leastSignificantDigit]
  ///
  /// This assumes scientific notation, and is overriden for fixed-point.
  ///
  int leastSignificantDigit(double value) {
    if (value != 0) {
      return log(value.abs()).floor() - fractionDigits;
    } else {
      return -fractionDigits;
    }
  }
}

@immutable
class SciFloatFormatter extends FloatFormatter {
  @override
  final int fractionDigits;
  const SciFloatFormatter(this.fractionDigits);

  @override
  String get _jsonName => 's$fractionDigits';

  @override
  String format(Value v, bool windowEnabled) {
    return formatScientific(
        v, windowEnabled ? min(7, fractionDigits + 1) : fractionDigits + 1);
  }
}

@immutable
class FixFloatFormatter extends FloatFormatter {
  @override
  final int fractionDigits;
  const FixFloatFormatter(this.fractionDigits);

  @override
  String get _jsonName => 'x$fractionDigits';

  @override
  String format(Value v, bool windowEnabled) =>
      formatFixed(v, fractionDigits) ??
      formatScientific(
          v, windowEnabled ? min(7, fractionDigits + 1) : fractionDigits + 1);

  @override
  int leastSignificantDigit(double value) {
    if (value != 0) {
      final r = log(value.abs()).floor();
      if (r < -fractionDigits || r >= 10) {
        return r - fractionDigits; // Same as super.leastSignificantDigit()
      }
    }
    return -fractionDigits;
  }
}

///
/// The float format for the 16C, which is mostly like the 15C's fixed format,
/// except that it always goes to 7 digit scientific on overflow.
/// This does not handle Float-. mode (which is the 16C's
/// idiom for always being in 7 digit scientific notation).
///
@immutable
class _Fix16FloatFormatter extends FixFloatFormatter {
  const _Fix16FloatFormatter(int fractionDigits) : super(fractionDigits);

  @override
  String get _jsonName => 'f$fractionDigits';

  @override
  String format(Value v, windowEnabled) =>
      formatFixed(v, fractionDigits) ??
      formatScientific(v, windowEnabled ? 7 : max(7, fractionDigits + 1));
}

///
/// The scientific notation float format for the 16C, which is what you get
/// from "FLOAT-."  It's stored in JSON as 'f10' for backwards compatibility.
///
@immutable
class _Sci16FloatFormatter extends SciFloatFormatter {
  const _Sci16FloatFormatter() : super(9);

  @override
  String get _jsonName => 'f10';
}

@immutable
class _EngFloatFormatter extends SciFloatFormatter {
  const _EngFloatFormatter(int fractionDigits) : super(fractionDigits);

  @override
  String get _jsonName => 'e$fractionDigits';

  @override
  @protected
  int constrainExponent(int exp) => (((exp + 9999) ~/ 3) * 3) - 9999;
}
