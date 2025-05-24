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

/// Immutable calculator value
///
/// Floats are stored in something close to what I think is the 16C's internal
/// format
///
/// This format is interesting.  It's big-endian BCD.  The mantissa is
/// sign-magnitude, with the sign in a nybble that is 0 for positive, and
/// 9 for negative.  The exponent is 10's complement BCD, with a magnitude
/// between 0 and 99 (inclusive).  So it looks like:
///
///      smmmmmmmmmmeee
///
/// s = mantissa sign (0/9)
/// m = mantissa magnitude
/// e = exponent (1 is 001, -1 is 0x999, -2 is 0x998, etc)
///
/// The most significant digit of the mantissa is always non-zero.  In other
/// words, 0.1e-99 underflows to zero.  The mantissa is NOT stored in
/// complement form.  So, a mantissa of -4.2 is 0x94200000000.
///
/// Note that I didn't refer to a ROM image to figure this out, or anything
/// like that.  I just asked what the behavior of the real calculator is
/// for a couple of data points.
/// cf. https://www.hpmuseum.org/forum/thread-16595-post-145554.html#pid145554
@immutable
class Value {
  /// The calculator's internal representation of a value, as an *unsigned*
  /// integer of (up to) 64 bits in normal operation (128 for the double
  /// integer operations).  It's a BigInt rather than an int because
  /// Javascript Is Evil (tm) - dart web currently has 32 bit ints for that
  /// reason.  Hopefully WASM will fix that eventually.  Anyway, using BigInt
  /// does let us handle the double integer operations easily.
  final BigInt internal;
  static final BigInt _maxNormalInternal = BigInt.parse(
    'ffffffffffffffff',
    radix: 16,
  );
  // The maximum value of internal, EXCEPT when we're doing the 16C double-int
  // operations

  Value.fromInternal(this.internal) {
    assert(internal >= BigInt.zero);
  }

  Value._fromMantissaAndRawExponent(BigInt mantissa, int exponent)
    : internal = (mantissa << 12) | BigInt.from(exponent) {
    assert(exponent >= 0, 'Exponent must be thousands complement');
    // Assert a valid float bit pattern by throwing CaclulatorError(6)
    // if malformed.
    // In production, asDouble can legitimately throw this error when a
    // register value is recalled in float mode.
    final double check = asDouble;

    // While we're here, we know we should never legitimately return this:
    assert(!check.isNaN);
  }

  BigInt get _upper52 => (internal >> 12) & _mask52;
  int get _lower12 => (internal & _mask12).toInt();

  @override
  int get hashCode => internal.hashCode;

  @override
  bool operator ==(Object other) =>
      (other is Value) ? (internal == other.internal) : false;

  /// Zero for both floats and ints
  static final Value zero = Value.fromInternal(BigInt.from(0));
  static final Value oneF = Value.fromDouble(1);
  static final Value fMaxValue = Value._fromMantissaAndRawExponent(
    BigInt.parse('09999999999', radix: 16),
    0x099,
  );
  static final Value fMinValue = Value._fromMantissaAndRawExponent(
    BigInt.parse('99999999999', radix: 16),
    0x099,
  );

  static final BigInt _mask12 = (BigInt.one << 12) - BigInt.one;
  static final BigInt _mask52 = (BigInt.one << 52) - BigInt.one;
  static final BigInt _maskF = BigInt.from(0xf);
  static final BigInt _mantissaSign = BigInt.parse('90000000000', radix: 16);
  static final BigInt _mantissaMagnitude = BigInt.parse(
    'ffffffffff',
    radix: 16,
  );
  static final BigInt _mantissaMsdMask = BigInt.parse('f000000000', radix: 16);

  static final BigInt _matrixMantissa = BigInt.parse('a111eeeeeee', radix: 16);
  // Not a valid float.  Also, matrices are painful, and vaguely French.

  static final BigInt _ten = BigInt.from(10);

  static Value fromDouble(double num) {
    if (num == double.infinity) {
      throw FloatOverflow(fMaxValue);
    } else if (num == double.negativeInfinity) {
      throw FloatOverflow(fMinValue);
    } else if (num.isNaN) {
      throw FloatOverflow(fMaxValue);
    }

    // Slow but simple
    final String s = num.toStringAsExponential(9);
    BigInt mantissa = BigInt.zero;
    // Huh!  It looks like ints are limited to 32 bits under JS, at least
    // as regards left-shift as of April 2021.
    int i = 0;
    while (true) {
      final int c = s.codeUnitAt(i);
      if (c == '-'.codeUnitAt(0)) {
        assert(mantissa == BigInt.zero, "$c in '$s' at $i");
        mantissa = BigInt.from(9);
      } else if (c == '.'.codeUnitAt(0)) {
        // do nothing
      } else if (c == 'e'.codeUnitAt(0)) {
        i++;
        break;
      } else {
        final int d = c - '0'.codeUnitAt(0);
        assert(d >= 0 && d < 10, '$d in "$s" at $i');
        mantissa = (mantissa << 4) | BigInt.from(d);
      }
      i++;
    }
    assert(i >= 12 && i <= 13, '$i $s');
    bool negativeExponent = false;
    int exponent = 0;
    while (i < s.length) {
      final int c = s.codeUnitAt(i);
      if (c == '-'.codeUnitAt(0)) {
        assert(exponent == 0);
        negativeExponent = true;
      } else if (c == '+'.codeUnitAt(0)) {
        assert(exponent == 0 && !negativeExponent);
        // do nothing
      } else {
        final int d = c - '0'.codeUnitAt(0);
        assert(d >= 0 && d < 10, 'for character ${s.substring(i, i + 1)}');
        exponent = (exponent << 4) | d;
      }
      i++;
    }
    if (exponent >= 0x100) {
      if (negativeExponent) {
        return zero;
      } else if (mantissa & _mantissaSign == BigInt.zero) {
        // positive mantissa
        throw FloatOverflow(fMaxValue);
      } else {
        throw FloatOverflow(fMinValue);
      }
    } else if (negativeExponent) {
      // 1000's complement in BCD
      exponent = (0x99a - exponent);
      if (exponent & 0xf == 0xa) {
        exponent += 6;
      }
    }
    if (mantissa == _mantissaSign) {
      // -0.0, which the real calculator doesn't distinguish from 0.0
      mantissa = BigInt.zero;
    }
    return Value._fromMantissaAndRawExponent(mantissa, exponent);
  }

  Value.fromMatrix(int matrixNumber)
    : internal = (_matrixMantissa << 12) | BigInt.from(matrixNumber) {
    assert(matrixNumber >= 0 && matrixNumber < 5);
  }

  /// Determine if this value is zero.  In 1's complement mode,
  /// -0 isZero, too.
  bool isZero(Model m) => m.isZero(this);

  ///
  /// If this is a matrix descriptor, give the matrix number, where A is 0.
  ///
  int? get asMatrix {
    if ((internal >> 12) == _matrixMantissa) {
      return exponent;
    } else {
      return null;
    }
  }

  ///
  /// Interpret this value as a floating point, and convert to a double.
  /// There is no corresponding asInt method, because on the 16C the int
  /// interpretation depends on the bit size and the sign mode -
  /// cf. IntegerSignMode.toBigInt(), and [floatIntPart]
  ///
  double get asDouble {
    final BigInt upper52 = _upper52;
    String mantissa = (upper52 & _mantissaMagnitude).toRadixString(16);
    final asciiZero = '0'.codeUnitAt(0);
    int getDigit(int d) {
      int r = mantissa.codeUnitAt(d) - asciiZero;
      if (r < 0 || r > 9) {
        throw CalculatorError(6, num15: 1);
      }
      return r;
    }

    final int e = exponent;
    if (mantissa == '0') {
      if (e != 0) {
        throw CalculatorError(6, num15: 1); // Issue 68
      }
      return 0.0;
    } else if (mantissa.length != 10) {
      throw CalculatorError(6, num15: 1);
    }
    final int sign = (upper52 >> 40).toInt();
    int intPart = 0;
    int fracPart = 0;
    // int part:
    int d = 0;
    for (; d < min(e + 1, 10); d++) {
      intPart *= 10;
      intPart += getDigit(d);
    }
    final int fracDigits = 10 - d;
    for (; d < 10; d++) {
      fracPart *= 10;
      fracPart += getDigit(d);
    }
    // ignore: prefer_interpolation_to_compose_strings
    final sr =
        '$intPart.' +
        '$fracPart'.padLeft(fracDigits, '0') +
        'e${e + fracDigits - 9}';
    var result = double.parse(sr);
    /*
    Parsing a string is marginally more accurate than this:
    double result = intPart * pow(10.0, e + fracDigits - 9).toDouble() +
        fracPart * pow(10.0, e - 9).toDouble();
     */
    if (sign != 0) {
      if (sign == 0x9) {
        result = -result;
      } else {
        throw CalculatorError(6, num15: 1);
      }
    }
    return result;
  }

  ///
  /// For a Value holding a float, give the int part, for a line number, and
  /// index, or a label in a program.  For suifficiently large integers, just
  /// give something with a big magnitude
  ///
  int floatIntPart() {
    if (asMatrix != null) {
      throw CalculatorError(1);
    }
    int e = exponent;
    int result = 0;
    int d = 0;
    if (e > 14) {
      result = 99999999999999;
    } else {
      while (e >= 0) {
        result *= 10;
        if (d < 10) {
          result += mantissaDigit(d++);
        }
        e--;
      }
    }
    if (isNegative) {
      return -result;
    } else {
      return result;
    }
  }

  ///
  /// Give the mantissa, essentially.  Used for f-CLEAR PREFIX, which shows
  /// the mantissa to the user.
  ///
  String get floatPrefix {
    final sb = StringBuffer();
    final BigInt upper52 = _upper52;
    for (int d = 0; d < 10; d++) {
      sb.writeCharCode(
        '0'.codeUnitAt(0) + ((upper52 >> 36 - (d * 4)) & _maskF).toInt(),
      );
    }
    return sb.toString();
  }

  ///
  /// Get the exponent part of this value interpreted as a float.
  /// Not valid for infinity or -infinity.
  ///
  int get exponent {
    int checkDigit(int d) {
      if (d > 9) {
        throw CalculatorError(6, num15: 1);
      }
      return d;
    }

    int lower12 = _lower12;
    int r = 10 * checkDigit((lower12 >> 4) & 0xf) + checkDigit(lower12 & 0xf);
    if (lower12 & 0xf00 == 0x900) {
      r = -(100 - r);
    } else if ((lower12 & 0x0f00) != 0x000) {
      throw CalculatorError(6, num15: 1);
    }
    if (r > -100 && r < 100) {
      return r;
    } else {
      throw CalculatorError(6, num15: 1);
    }
  }

  BigInt get _mantissa {
    BigInt result = BigInt.from(mantissaDigit(0));
    for (int i = 1; i <= 9; i++) {
      result *= _ten;
      result += BigInt.from(mantissaDigit(i));
    }
    return result;
  }

  Value negateAsFloat() {
    if (this == zero) {
      return this;
    } else {
      return Value._fromMantissaAndRawExponent(
        _mantissaSign ^ _upper52,
        _lower12,
      );
    }
  }

  Value abs() {
    if (isNegative) {
      return negateAsFloat();
    } else {
      return this;
    }
  }

  Value changeBitSize(BigInt bitMask) => Value.fromInternal(internal & bitMask);
  // The 16C doesn't do sign extension when the bit size increases.

  @override
  String toString() {
    String more;
    try {
      more = ', $asDouble';
    } catch (ignored) {
      final m = asMatrix;
      if (m == null) {
        more = '';
      } else {
        more = ', Matrix ${['A', 'B', 'C', 'D', 'E'][m]}';
      }
    }
    return 'Value(0x${internal.toRadixString(16).padLeft(16, '0')}$more)';
  }

  static Value fromJson(String v, {BigInt? maxInternal}) {
    maxInternal ??= _maxNormalInternal;
    final i = BigInt.parse(v, radix: 16);
    if (i < BigInt.zero || i > maxInternal) {
      throw ArgumentError('$i out of range 0..$maxInternal');
    }
    return Value.fromInternal(i);
  }

  String toJson() => internal.toRadixString(16);

  ///
  /// Give one digit of the mantissa, where 0 is the MSD, and 9 is the LSD.
  /// -1 gives the sign digit (9 is negative, 0 is positive).
  ///
  int mantissaDigit(int digit) {
    assert(digit >= -1 && digit <= 9);
    final r = ((internal >> 4 * (12 - digit)) & _maskF).toInt();
    assert(r <= 9 && r >= 0);
    return r;
  }

  bool get isPositive => mantissaDigit(-1) == 0;

  Value fracOp() {
    if (asMatrix != null) {
      throw CalculatorError(1);
    }
    final int e = exponent;
    if (e > 9) {
      return zero;
    } else if (e < 0) {
      return this;
    }
    final BigInt u = _upper52;
    BigInt mag = (u << ((e + 1) * 4)) & _mantissaMagnitude;
    if (mag == BigInt.zero) {
      return Value.zero;
    } else {
      // Need to normalize mag so MSD is non-zero
      int exp = 0x999; // -1
      while (mag & _mantissaMsdMask == BigInt.zero) {
        exp--;
        mag = mag << 4;
      }
      if ((u & _mantissaSign) == BigInt.zero) {
        return Value._fromMantissaAndRawExponent(mag, exp); // 0x999 is -1
      } else {
        return Value._fromMantissaAndRawExponent(mag | _mantissaSign, exp);
      }
    }
  }

  Value intOp() {
    if (asMatrix != null) {
      throw CalculatorError(1);
    }
    final e = exponent;
    if (e < 0) {
      return zero;
    } else if (e > 9) {
      return this;
    }
    final BigInt u = _upper52;
    final mask = 'fffffffffff'.substring(9 - e).padRight(11, '0');
    // mask includes sign
    final BigInt m = BigInt.parse(mask, radix: 16);
    return Value._fromMantissaAndRawExponent(u & m, e);
  }

  bool get isNegative => mantissaDigit(-1) == 9;

  int _intToRawExponent(int e) {
    bool negative = e < 0;
    e = e.abs();
    assert(e <= 99);
    int rawE = ((e ~/ 10) * 0x10) | (e % 10);
    if (negative) {
      rawE = 0x99a - rawE;
      if (rawE & 0xf == 0xa) {
        rawE += 6;
      }
    }
    return rawE;
  }

  Value timesTenTo(int power) {
    assert(asMatrix == null);
    if (this == zero) {
      return this;
    }
    final e = exponent + power;
    if (e >= 100) {
      if (mantissaDigit(-1) == 0) {
        throw FloatOverflow(Value.fMaxValue);
      } else {
        throw FloatOverflow(Value.fMinValue);
      }
    } else if (e <= -100) {
      return zero;
    } else {
      return Value._fromMantissaAndRawExponent(_upper52, _intToRawExponent(e));
    }
  }

  Value decimalAdd(Value other) {
    return (DecimalFP12(this) + DecimalFP12(other)).toValue();
  }

  /// Return this - other
  Value decimalSubtract(Value other) {
    return (DecimalFP12(this) - DecimalFP12(other)).toValue();
  }

  Value decimalMultiply(Value other) {
    return (DecimalFP12(this) * DecimalFP12(other)).toValue();
  }

  Value decimalDivideBy(Value other) {
    return (DecimalFP12(this) / DecimalFP12(other)).toValue();
  }
}

///
/// A complex Value.  This is just a wrapper, used for addition and subtraction.
///
@immutable
class ComplexValue {
  final Value real;
  final Value imaginary;

  const ComplexValue(this.real, this.imaginary);

  ComplexValue decimalAdd(
    ComplexValue other,
    Value Function(Value Function()) check,
  ) => ComplexValue(
    check(() => real.decimalAdd(other.real)),
    check(() => imaginary.decimalAdd(other.imaginary)),
  );

  ComplexValue decimalSubtract(
    ComplexValue other,
    Value Function(Value Function()) check,
  ) => ComplexValue(
    check(() => real.decimalSubtract(other.real)),
    check(() => imaginary.decimalSubtract(other.imaginary)),
  );

  ComplexValue decimalMultiply(
    ComplexValue other,
    Value Function(Value Function()) check,
  ) {
    final usReal = DecimalFP22(real);
    final usImaginary = DecimalFP22(imaginary);
    final themReal = DecimalFP22(other.real);
    final themImaginary = DecimalFP22(other.imaginary);
    return ComplexValue(
      check(
        () => ((usReal * themReal) - (usImaginary * themImaginary)).toValue(),
      ),
      check(
        () => ((usReal * themImaginary) + (usImaginary * themReal)).toValue(),
      ),
    );
  }

  ComplexValue decimalDivideBy(
    ComplexValue other,
    Value Function(Value Function()) check,
  ) {
    final usReal = DecimalFP22(real);
    final usImaginary = DecimalFP22(imaginary);
    final themReal = DecimalFP22(other.real);
    final themImaginary = DecimalFP22(other.imaginary);
    final mag = themReal * themReal + themImaginary * themImaginary;
    final rePart = (usReal * themReal + usImaginary * themImaginary) / mag;
    final imPart = (usImaginary * themReal - usReal * themImaginary) / mag;
    return ComplexValue(
      check(() => rePart.toValue()),
      check(() => imPart.toValue()),
    );
  }

  @override
  String toString() => 'ComplexValue($real, $imaginary';

  @override
  bool operator ==(Object other) {
    if (other is ComplexValue) {
      return real == other.real && imaginary == other.imaginary;
    } else {
      return false;
    }
  }

  @override
  int get hashCode => Object.hash(real, imaginary);
}

//
// A decimal floating point value with a mantissa size that's fixed by
// the subclass.  Operations truncated (they don't round); it is expected that
// a result is rounded when it is converted to a Value.  Overflow and underflow
// detection aren't done, but the exponent is a full dart int; it is up to the
// caller to ensure that DecimalFP isn't used in such a way that this could
// over/underflow.  Zero is represented as a mantissan and exponent of zero.
// Otherwise, the mantissa is always normalzed to have a constant number of
// digits.
//
abstract class DecimalFP {
  final bool isNegative;
  final int exponent;
  final BigInt mantissa;

  DecimalFP.fromValue(Value v, this.mantissa)
    : isNegative = v.isNegative,
      exponent = v.exponent {
    _assertValid();
  }

  DecimalFP.raw(this.isNegative, this.exponent, this.mantissa) {
    _assertValid();
  }

  @protected
  void _assertValid() {
    assert(
      (mantissa == BigInt.zero && exponent == 0) ||
          (mantissa >= _tenPow(mantissaDigits - 1) &&
              mantissa < _tenPow(mantissaDigits)),
      '$mantissa',
    );
    assert(!isNegative || mantissa != BigInt.zero);
  }

  @protected
  DecimalFP newInstance(bool isNegative, int exponent, BigInt mantissa);

  @protected
  int get mantissaDigits;

  static final _tenPowCache = List<BigInt?>.generate(
    50,
    (_) => null,
    growable: false,
  );

  static BigInt _tenPow(int digits) =>
      _tenPowCache[digits] ??= _tenPowRaw(digits);

  static BigInt _tenPowRaw(int digits) =>
      BigInt.parse('1'.padRight(digits + 1, '0'));

  ///
  /// Convert to a Value.  Calling this method changes the internal
  /// representation (to a normalized form).
  ///
  Value toValue() {
    int mm;
    if (mantissaDigits > 11) {
      mm = (mantissa ~/ _tenPow(mantissaDigits - 11)).toInt();
    } else if (mantissaDigits == 11) {
      mm = mantissa.toInt();
    } else {
      mm = (mantissa * _tenPow(11 - mantissaDigits)).toInt();
    }
    if (mm == 0) {
      return Value.zero;
    }
    assert(mm >= 10000000000 && mm < 100000000000); // 1e11, 1e12
    int exp = exponent;
    if (mm + 5 >= 100000000000) {
      // 1e11
      mm ~/= 10;
      exp++;
    }
    mm = (mm + 5) ~/ 10;
    // Rounds away from zero.  Cf. issue #70
    assert(mm < 10000000000 && mm >= 1000000000); // 1e10, 1e9

    // Check underflow and overflow
    if (exp > 99) {
      if (isNegative) {
        throw FloatOverflow(Value.fMinValue);
      } else {
        throw FloatOverflow(Value.fMaxValue);
      }
    } else if (exp < -99) {
      return Value.zero;
    }

    // Convert to the HP's internal format.
    // Going through hex is pretty horrible, but so is doing a bunch of
    // left-shifts using immutable BigInt instances.
    final internal = StringBuffer();
    if (isNegative) {
      internal.write('9');
    }
    final ms = '$mm';
    assert(ms.length == 10);
    internal.write(ms);
    if (exp < 0) {
      exp += 1000;
    }
    assert(exp >= 0 && exp <= 999, exp);
    internal.write(exp.toString().padLeft(3, '0'));
    return Value.fromInternal(BigInt.parse(internal.toString(), radix: 16));
  }

  @protected
  DecimalFP addOrSubtract(DecimalFP other, bool add) {
    assert(mantissaDigits == other.mantissaDigits);
    BigInt us = mantissa;
    BigInt them = other.mantissa;
    if (them == BigInt.zero) {
      return this;
    }
    if (us == BigInt.zero) {
      if (add) {
        return other;
      } else {
        return newInstance(!other.isNegative, other.exponent, them);
      }
    }
    if (isNegative != other.isNegative) {
      add = !add;
    }
    int deltaExp = exponent - other.exponent;
    int exp = exponent;
    if (add) {
      if (deltaExp > 0) {
        if (deltaExp > mantissaDigits) {
          them = BigInt.zero;
        } else {
          them ~/= _tenPow(deltaExp);
        }
      } else if (deltaExp < 0) {
        exp = other.exponent;
        if (-deltaExp > mantissaDigits) {
          us = BigInt.zero;
        } else {
          us ~/= _tenPow(-deltaExp);
        }
      }
      us += them;
      if (us >= _tenPow(mantissaDigits)) {
        us ~/= _tenPow(1);
        exp++;
      }
      return newInstance(isNegative, exp, us);
    } else {
      // subtract
      bool changeSign;
      if (deltaExp > 0) {
        // Form complement:
        if (deltaExp > mantissaDigits) {
          them = _tenPow(mantissaDigits) - BigInt.one;
        } else {
          them = _tenPow(mantissaDigits) - them; // Complement
          final shiftIn = _tenPow(mantissaDigits - 1) * BigInt.from(9);
          for (int i = 0; i < deltaExp; i++) {
            them = (them ~/ _tenPow(1)) + shiftIn;
          }
        }
        changeSign = false;
      } else if (deltaExp < 0) {
        deltaExp = -deltaExp;
        // Form complement:
        if (deltaExp > mantissaDigits) {
          us = _tenPow(mantissaDigits) - BigInt.one;
        } else {
          us = _tenPow(mantissaDigits) - us; // Complement
          final shiftIn = _tenPow(mantissaDigits - 1) * BigInt.from(9);
          for (int i = 0; i < deltaExp; i++) {
            us = (us ~/ _tenPow(1)) + shiftIn;
          }
        }
        exp = other.exponent;
        changeSign = true;
      } else if (us > them) {
        them = _tenPow(mantissaDigits) - them;
        changeSign = false;
      } else if (us < them) {
        us = _tenPow(mantissaDigits) - us;
        changeSign = true;
      } else {
        return newInstance(false, 0, BigInt.zero);
      }
      us = us + them - _tenPow(mantissaDigits);
      assert(us > BigInt.zero, '$us');
      while (us < _tenPow(mantissaDigits - 1)) {
        us *= _tenPow(1);
        exp--;
      }
      return newInstance(isNegative ^ changeSign, exp, us);
    }
  }

  @protected
  DecimalFP multiply(DecimalFP other) {
    if (mantissa == BigInt.zero) {
      return this;
    }
    if (other.mantissa == BigInt.zero) {
      return other;
    }
    int resultExp = exponent + other.exponent;
    BigInt mm = mantissa * other.mantissa;
    BigInt resultM;
    // Do a truncating normalize.  Rounding happens when we convert to
    // a Value.
    if (mm < _tenPow(mantissaDigits * 2 - 1)) {
      resultM = mm ~/ _tenPow(mantissaDigits - 1);
    } else {
      resultExp++;
      resultM = mm ~/ _tenPow(mantissaDigits);
    }
    bool resultNegative = isNegative ^ other.isNegative;
    return newInstance(resultNegative, resultExp, resultM);
  }

  @protected
  DecimalFP divideBy(DecimalFP other) {
    if (other.mantissa == BigInt.zero) {
      throw CalculatorError(0);
    } else if (mantissa == BigInt.zero) {
      return this;
    }
    BigInt dm = (mantissa * _tenPow(mantissaDigits + 1)) ~/ other.mantissa;
    int resultExp = exponent - other.exponent;
    BigInt resultM;
    // Do a truncating normalize.  Rounding happens when we convert to
    // a Value.
    if (dm < _tenPow(mantissaDigits + 1)) {
      resultM = dm ~/ _tenPow(1);
      resultExp--;
    } else {
      resultM = dm ~/ _tenPow(2);
    }
    bool resultNegative = isNegative ^ other.isNegative;
    return newInstance(resultNegative, resultExp, resultM);
  }

  DecimalFP abs() => isNegative ? newInstance(false, exponent, mantissa) : this;

  @protected
  int compareTo(DecimalFP other) {
    assert(mantissaDigits == other.mantissaDigits);
    if (isNegative != other.isNegative) {
      return isNegative ? -1 : 1;
    }
    if (mantissa == BigInt.zero) {
      if (other.mantissa == BigInt.zero) {
        return 0;
      } else {
        return other.isNegative ? 1 : -1;
      }
    } else if (other.mantissa == BigInt.zero) {
      return isNegative ? -1 : 1;
    }
    final int r;
    if (exponent != other.exponent) {
      r = exponent - other.exponent;
    } else {
      r = mantissa.compareTo(other.mantissa);
    }
    return isNegative ? -r : r;
  }

  @override
  bool operator ==(Object other) {
    if (other is! DecimalFP || mantissaDigits != other.mantissaDigits) {
      return false;
    } else {
      return compareTo(other) == 0;
    }
  }

  @override
  int get hashCode => Object.hash(isNegative, exponent, mantissa);

  @override
  String toString() {
    final sb = StringBuffer('DecimalFP$mantissaDigits(');
    if (isNegative) {
      sb.write('-');
    } else {
      sb.write('+');
    }
    final ms = '$mantissa'.padLeft(mantissaDigits, '0');
    sb.write(ms.substring(0, 1));
    sb.write('.');
    for (int i = 1; i < mantissaDigits; i++) {
      sb.write(ms.substring(i, i + 1));
    }
    sb.write('e');
    if (exponent < 0) {
      sb.write('-');
    } else {
      sb.write('+');
    }
    sb.write(exponent.abs().toString().padLeft(3, '0'));
    sb.write(')');
    return sb.toString();
  }

  // For testing, and feeding into things like sqrt:
  double get asDouble {
    final v = mantissa.toDouble() * pow(10.0, exponent - mantissaDigits + 1);
    return isNegative ? -v : v;
  }

  /// For integers that can't possibly overflow
  int get asInt {
    final BigInt v = mantissa ~/ _tenPow(mantissaDigits - 1 - exponent);
    return isNegative ? -v.toInt() : v.toInt();
  }

  /// Give the integer part of this value
  DecimalFP intOp() {
    if (mantissa == BigInt.zero) {
      return this;
    }
    int extraDigits = mantissaDigits - exponent - 1;
    if (extraDigits <= 0) {
      return this;
    }
    if (extraDigits >= mantissaDigits) {
      return newInstance(false, 0, BigInt.zero);
    }
    final newMantissa = mantissa - mantissa.remainder(_tenPowRaw(extraDigits));
    if (newMantissa == BigInt.zero) {
      return newInstance(false, 0, BigInt.zero);
    }
    return newInstance(isNegative, exponent, newMantissa);
  }
}

class DecimalFP12 extends DecimalFP {
  DecimalFP12(Value v) : super.fromValue(v, v._mantissa * DecimalFP._tenPow(2));

  DecimalFP12.raw(super.isNegative, super.exponent, super.mantissa)
    : super.raw();

  @override
  int get mantissaDigits => 12;

  @override
  @protected
  DecimalFP12 newInstance(bool isNegative, int exponent, BigInt mantissa) =>
      DecimalFP12.raw(isNegative, exponent, mantissa);

  DecimalFP12 negate() => DecimalFP12.raw(!isNegative, exponent, mantissa);

  static DecimalFP12 tenTo(int pow, {bool negative = false}) =>
      DecimalFP12.raw(negative, pow, DecimalFP._tenPow(11));

  DecimalFP12 operator +(DecimalFP12 other) =>
      addOrSubtract(other, true) as DecimalFP12;

  DecimalFP12 operator -(DecimalFP12 other) =>
      addOrSubtract(other, false) as DecimalFP12;

  DecimalFP12 operator *(DecimalFP12 other) => multiply(other) as DecimalFP12;

  DecimalFP12 operator /(DecimalFP12 other) => divideBy(other) as DecimalFP12;

  @override
  DecimalFP12 abs() => super.abs() as DecimalFP12;

  @override
  DecimalFP12 intOp() => super.intOp() as DecimalFP12;

  bool operator >(DecimalFP12 other) => compareTo(other) > 0;
  bool operator >=(DecimalFP12 other) => compareTo(other) >= 0;
  bool operator <(DecimalFP12 other) => compareTo(other) < 0;
  bool operator <=(DecimalFP12 other) => compareTo(other) <= 0;
}

class DecimalFP22 extends DecimalFP {
  DecimalFP22(Value v)
    : super.fromValue(v, v._mantissa * DecimalFP._tenPow(12));

  DecimalFP22.raw(super.isNegative, super.exponent, super.mantissa)
    : super.raw();

  static DecimalFP22 zero = DecimalFP22.raw(false, 0, BigInt.zero);

  static DecimalFP22 one = tenTo(0);

  static DecimalFP22 negativeOne = tenTo(0, negative: true);

  @override
  int get mantissaDigits => 22;

  @override
  @protected
  DecimalFP22 newInstance(bool isNegative, int exponent, BigInt mantissa) =>
      DecimalFP22.raw(isNegative, exponent, mantissa);

  DecimalFP22 negate() => DecimalFP22.raw(!isNegative, exponent, mantissa);

  static DecimalFP22 tenTo(int pow, {bool negative = false}) =>
      DecimalFP22.raw(negative, pow, DecimalFP._tenPow(21));

  DecimalFP22 operator +(DecimalFP22 other) =>
      addOrSubtract(other, true) as DecimalFP22;

  DecimalFP22 operator -(DecimalFP22 other) =>
      addOrSubtract(other, false) as DecimalFP22;

  DecimalFP22 operator *(DecimalFP22 other) => multiply(other) as DecimalFP22;

  DecimalFP22 operator /(DecimalFP22 other) => divideBy(other) as DecimalFP22;

  @override
  DecimalFP22 abs() => super.abs() as DecimalFP22;

  @override
  DecimalFP22 intOp() => super.intOp() as DecimalFP22;

  bool operator >(DecimalFP22 other) => compareTo(other) > 0;
  bool operator >=(DecimalFP22 other) => compareTo(other) >= 0;
  bool operator <(DecimalFP22 other) => compareTo(other) < 0;
  bool operator <=(DecimalFP22 other) => compareTo(other) <= 0;
}

///
/// Only used for testing.  Compiler should strip this out of executable
/// in deployment.
///
class DecimalFP6 extends DecimalFP {
  DecimalFP6(Value v) : super.fromValue(v, v._mantissa ~/ DecimalFP._tenPow(4));

  DecimalFP6.raw(super.isNegative, super.exponent, super.mantissa)
    : super.raw();

  @override
  int get mantissaDigits => 6;

  @override
  @protected
  DecimalFP6 newInstance(bool isNegative, int exponent, BigInt mantissa) =>
      DecimalFP6.raw(isNegative, exponent, mantissa);
}

///
/// An exception when a floating point operation overflows.  Notably, this is
/// used in the matrix operations.
///
class FloatOverflow {
  final Value infinity; // Either the max or min value

  FloatOverflow(this.infinity);
}
