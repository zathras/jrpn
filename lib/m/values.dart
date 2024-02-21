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
/// 9 for negative.  The exponent is 1000's complement BCD, with a magnitude
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
  static final BigInt _maxNormalInternal =
      BigInt.parse('ffffffffffffffff', radix: 16);
  // The maximum value of internal, EXCEPT when we're doing the double-int
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
      BigInt.parse('09999999999', radix: 16), 0x099);
  static final Value fMinValue = Value._fromMantissaAndRawExponent(
      BigInt.parse('99999999999', radix: 16), 0x099);
  static final Value fInfinity =
      Value.fromInternal(BigInt.parse('0100000000009a', radix: 16));
  static final Value fNegativeInfinity =
      Value.fromInternal(BigInt.parse('9100000000009a', radix: 16));

  static final BigInt _mask12 = (BigInt.one << 12) - BigInt.one;
  static final BigInt _mask52 = (BigInt.one << 52) - BigInt.one;
  static final BigInt _maskF = BigInt.from(0xf);
  static final BigInt _mantissaSign = BigInt.parse('90000000000', radix: 16);
  static final BigInt _mantissaMagnitude =
      BigInt.parse('ffffffffff', radix: 16);

  static final BigInt _matrixMantissa = BigInt.parse('a111eeeeeee', radix: 16);
  // Not a valid float.  Also, matrices are painful, and vaguely French.

  static Value fromDouble(double num) {
    if (num == double.infinity) {
      return fInfinity;
    } else if (num == double.negativeInfinity) {
      return fNegativeInfinity;
    } else if (num.isNaN) {
      return fInfinity;
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
        return fInfinity;
      } else {
        return fNegativeInfinity;
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

  bool get isInfinite => this == fInfinity || this == fNegativeInfinity;

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

  /// Interpret this value as a floating point, and convert to a double.
  /// There is no corresponding asInt method, because the int interpretation
  /// depends on the bit size and the sign mode - cf. IntegerSignMode.toBigInt()
  double get asDouble {
    if (this == fInfinity) {
      return double.infinity;
    } else if (this == fNegativeInfinity) {
      return double.negativeInfinity;
    }
    final BigInt upper52 = _upper52;
    String mantissa = (upper52 & _mantissaMagnitude).toRadixString(16);
    final int sign = (upper52 >> 40).toInt();
    double m = 0;
    try {
      m = double.parse(mantissa);
    } catch (e) {
      throw CalculatorError(6, num15: 1);
    }
    if (sign != 0) {
      if (sign == 0x9) {
        m = -m;
      } else {
        throw CalculatorError(6, num15: 1);
      }
    }
    final e = exponent;
    if (m == 0 && e != 0) {
      throw CalculatorError(6, num15: 1); // Issue 68
    }
    return m * pow(10.0, (e - 9).toDouble());
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
          '0'.codeUnitAt(0) + ((upper52 >> 36 - (d * 4)) & _maskF).toInt());
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
      // Impossible, now that checking is stricter, but left in for robustness.
      throw CalculatorError(6, num15: 1);
    }
  }

  Value negateAsFloat() {
    if (this == zero) {
      return this;
    } else {
      return Value._fromMantissaAndRawExponent(
          _mantissaSign ^ _upper52, _lower12);
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
    if (isInfinite) {
      return zero;
    }
    final int e = exponent;
    if (e > 9) {
      return zero;
    } else if (e < 0) {
      return this;
    }
    final BigInt u = _upper52;
    final BigInt mag = (u << ((e + 1) * 4)) & _mantissaMagnitude;
    if (mag == BigInt.zero) {
      return Value.zero;
    } else if ((u & _mantissaSign) == BigInt.zero) {
      return Value._fromMantissaAndRawExponent(mag, 0x999); // 0x999 is -1
    } else {
      return Value._fromMantissaAndRawExponent(mag | _mantissaSign, 0x999);
    }
  }

  Value intOp() {
    if (asMatrix != null) {
      throw CalculatorError(1);
    }
    if (isInfinite) {
      return this;
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
        return fInfinity;
      } else {
        return fNegativeInfinity;
      }
    } else if (e <= -100) {
      return zero;
    } else {
      return Value._fromMantissaAndRawExponent(_upper52, _intToRawExponent(e));
    }
  }

  Value decimalAdd(Value other) {
    final us = _InternalFP(this);
    us.add(_InternalFP(other));
    return us.toValue();
  }

  Value decimalSubtract(Value other) {
    final us = _InternalFP(this);
    us.subtract(_InternalFP(other));
    return us.toValue();
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

  ComplexValue decimalAdd(ComplexValue other) => ComplexValue(
      real.decimalAdd(other.real), imaginary.decimalAdd(other.imaginary));

  ComplexValue decimalSubtract(ComplexValue other) => ComplexValue(
      real.decimalSubtract(other.real),
      imaginary.decimalSubtract(other.imaginary));
}

///
/// An mutable, internal representation of a decimal floating point value,
/// with 12 digits of mantissa.
///
class _InternalFP {
  final _bytes = Uint8List(14);

  _InternalFP(Value v) {
    assert(!v.isInfinite);
    isNegative = v.isNegative;
    for (int i = 0; i < 10; i++) {
      setMantissa(i + 1, v.mantissaDigit(i));
    }
    // lsd and msd retain default value of zero
    exponent = v.exponent;
  }

  @override
  String toString() {
    final sb = StringBuffer('_InternalFP ');
    if (isNegative) {
      sb.write('-');
    } else {
      sb.write('+');
    }
    final zero = '0'.codeUnitAt(0);
    sb.writeCharCode(zero + getMantissa(0));
    sb.writeCharCode(zero + getMantissa(1));
    sb.write('.');
    for (int i = 2; i < 12; i++) {
      sb.writeCharCode(zero + getMantissa(i));
    }
    sb.write('e');
    sb.write(exponent.toString());
    return sb.toString();
  }

  ///
  /// Convert to a Value.  Calling this method changes the internal
  /// representation (to a normalized form).
  ///
  Value toValue() {
    // First, normalize the mantissa, ensuring msd is 0
    normalizeMantissa();
    // Next, round away from zero.  Cf. issue #78
    int d = 11;
    bool carry = getMantissa(d--) >= 5;
    setMantissa(11, 0);
    while (carry && d >= 0) {
      final v = getMantissa(d) + 1;
      if (v > 9) {
        setMantissa(d, 0);
      } else {
        carry = false;
        setMantissa(d, v);
      }
      d--;
    }
    assert(!carry);
    // Rounding might have de-normalized the mantissa
    normalizeMantissa();
    assert(getMantissa(0) == 0);
    // Check for a zero mantissa
    for (d = 1;; d++) {
      if (getMantissa(d) != 0) {
        break;
      } else if (d == 11) {
        return Value.zero;
      }
    }
    // Now normalize so that mantissa[1] is non-zero
    if (d > 1) {
      final int delta = d - 1;
      // Left shift so that msd is in mantissa[1]
      exponent -= delta;
      for (d = 1; d < 12; d++) {
        setMantissa(d, getMantissa(d + delta));
      }
    }

    // At this point, mantissa should be mostly normalized, viz:
    assert(getMantissa(0) == 0 && getMantissa(1) > 0);
    // The lsd might be non-zero; rounding when we convert to a value
    // will handle that.

    // Check underflow and overflow
    if (exponent > 99) {
      if (isNegative) {
        return Value.fNegativeInfinity;
      } else {
        return Value.fInfinity;
      }
    } else if (exponent < -99) {
      return Value.zero;
    }

    // Convert to the HP's internal format.
    // Going through hex is pretty horrible, but so is doing a bunch of
    // left-shifts using immutable BigInt instances.
    final internal = StringBuffer();
    final asciiZero = '0'.codeUnitAt(0);
    if (isNegative) {
      internal.writeCharCode(asciiZero + 9);
    }
    for (d = 1; d <= 10; d++) {
      internal.writeCharCode(asciiZero + getMantissa(d));
    }
    int e = exponent;
    if (e < 0) {
      e += 1000;
    }
    assert(e >= 0 && e <= 999, e);
    for (int divisor = 100; divisor > 0; divisor ~/= 10) {
      int digit = e ~/ divisor;
      assert(digit >= 0 && digit <= 9);
      internal.writeCharCode(asciiZero + digit);
      e -= digit * divisor;
    }
    assert(e == 0);
    return Value.fromInternal(BigInt.parse(internal.toString(), radix: 16));
  }

  void normalizeMantissa() {
    if (getMantissa(0) > 0) {
      // Do a truncating shift right
      exponent++;
      for (int d = 11; d >= 0; d--) {
        setMantissa(d, getMantissa(d - 1));
      }
    }
  }

  bool get isNegative => _bytes[0] != 0;
  set isNegative(bool v) => _bytes[0] = v ? 1 : 0;

  // 0 is most significant digit.  Out of range digits return zero.
  int getMantissa(int d) {
    if (d >= 0 && d < 12) {
      return _bytes[d + 1];
    } else {
      return 0;
    }
  }

  void setMantissa(int d, int v) {
    assert(d >= 0 && d < 12, '$d');
    _bytes[d + 1] = v;
  }

  ///
  /// The exponent of this value.  Because the MSD is maintained at zero for
  /// a normalized value, our value is:
  /// MM.MMMMMMMMMM * 10^exponent
  ///
  int get exponent => _bytes[13] - 128;
  set exponent(int v) {
    assert(v > -128 && v < 128);
    _bytes[13] = v + 128;
  }

  void negate() => isNegative = !isNegative;

  ///
  /// Add other to ourself.  Possibly changes other.
  ///
  void add(_InternalFP other) {
    assert(getMantissa(0) == 0 && other.getMantissa(0) == 0);
    if (isNegative != other.isNegative) {
      other.negate();
      return subtract(other);
    }
    final exponentDelta = exponent - other.exponent;
    if (exponentDelta > 0) {
      other.shiftRight(exponentDelta, 0);
    } else if (exponentDelta < 0) {
      shiftRight(-exponentDelta, 0);
    }
    int carry = 0;
    for (int d = 11; d >= 0; d--) {
      final v = getMantissa(d) + other.getMantissa(d) + carry;
      setMantissa(d, v % 10);
      carry = v ~/ 10;
    }
    assert(carry == 0);
  }

  ///
  /// Subtract other from ourself.  Possibly changes other.
  ///
  void subtract(_InternalFP other) {
    assert(getMantissa(0) == 0 && other.getMantissa(0) == 0);
    if (isNegative != other.isNegative) {
      other.negate();
      return add(other);
    }
    shiftLeft(1);
    other.shiftLeft(1);
    final exponentDelta = exponent - other.exponent;
    if (exponentDelta > 0) {
      other.complementMantissa();
      other.shiftRight(exponentDelta, 9);
    } else {
      negate();
      complementMantissa();
      shiftRight(-exponentDelta, 9);
    }
    int carry = 0;
    for (int d = 11; d >= 0; d--) {
      final v = getMantissa(d) + other.getMantissa(d) + carry;
      setMantissa(d, v % 10);
      carry = v ~/ 10;
    }
    // If this has changed signs
    if (carry == 0) {
      negate();
      complementMantissa();
    }
  }

  // Form the 10s complement of the mantissa.
  void complementMantissa() {
    int borrow = 0;
    for (int d = 11; d >= 0; d--) {
      final v = 10 - borrow - getMantissa(d);
      if (v == 10) {
        borrow = 0;
        setMantissa(d, 0);
      } else {
        borrow = 1;
        setMantissa(d, v);
      }
    }
    assert(borrow == 1);
  }

  void shiftRight(int delta, int shiftIn) {
    assert(delta >= 0);
    exponent += delta;
    for (int d = 11; d >= delta; d--) {
      setMantissa(d, getMantissa(d - delta));
    }
    for (int d = min(11, delta - 1); d >= 0; d--) {
      setMantissa(d, shiftIn);
    }
  }

  void shiftLeft(int delta) {
    assert(delta >= 0);
    assert(!Iterable<int>.generate(delta).any((i) => getMantissa(i) > 0));
    exponent -= delta;
    for (int d = 0; d <= 11; d++) {
      setMantissa(d, getMantissa(d + delta));
    }
  }
}
