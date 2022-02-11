import 'dart:math';
import 'dart:math' as dart;

import 'package:meta/meta.dart';
import 'model.dart' show CalculatorError;

///
/// A complex value
///
@immutable
class Complex {
  final double real;
  final double imaginary;

  const Complex(this.real, this.imaginary);

  Complex.polar(double r, double theta)
      : real = r * dart.cos(theta),
        imaginary = r * dart.sin(theta);

  static const zero = Complex(0, 0);

  @override
  String toString() => '$real+${imaginary}i';
  @override
  int get hashCode => Object.hash(real, imaginary);

  @override
  bool operator ==(Object? other) => (other is Complex)
      ? (real == other.real && imaginary == other.imaginary)
      : false;

  Complex operator -() => Complex(-real, -imaginary);

  Complex operator +(Complex other) =>
      Complex(real + other.real, imaginary + other.imaginary);

  Complex operator -(Complex other) =>
      Complex(real - other.real, imaginary - other.imaginary);

  double get r => dart.sqrt(real * real + imaginary * imaginary);

  double get theta => atan2(imaginary, real);

  Complex operator *(Complex other) => Complex(
      real * other.real - imaginary * other.imaginary,
      real * other.imaginary + imaginary * other.real);

  Complex operator /(Complex other) {
    final mag = other.real * other.real + other.imaginary * other.imaginary;
    return Complex((real * other.real + imaginary * other.imaginary) / mag,
        (imaginary * other.real - real * other.imaginary) / mag);
  }

  Complex sqrt() => Complex(dart.sqrt(r), 0) * (Complex(0, theta / 2)).exp();

  ///
  /// Compute e^this
  ///
  Complex exp() {
    double eXr = dart.exp(real);
    return Complex(eXr * dart.cos(imaginary), eXr * dart.sin(imaginary));
  }

  Complex ln() => Complex(dart.log(r), theta);

  ///
  /// Compute this^exp
  ///
  Complex pow(Complex exp) {
    // y^x = e^(x ln y)
    final x = exp;
    final y = this;
    final yR = y.r;
    if (yR == 0) {
      if (x == Complex.zero) {
        throw CalculatorError(0);
      }
      return Complex.zero;
    } else {
      final lnY = Complex(dart.log(yR), y.theta);
      final xLnY = x * lnY;
      final resultR = dart.exp(xLnY.real);
      return Complex(resultR * dart.cos(xLnY.imaginary),
          resultR * dart.sin(xLnY.imaginary));
    }
  }

  Complex sin() =>
      const Complex(0, -0.5) *
      ((const Complex(0, 1) * this).exp() -
          (const Complex(0, -1) * this).exp());

  Complex cos() =>
      const Complex(0.5, 0) *
      ((const Complex(0, 1) * this).exp() +
          (const Complex(0, -1) * this).exp());

  Complex tan() => sin() / cos();

  Complex sinh() => const Complex(0.5, 0) * (exp() - ((-this).exp()));

  Complex cosh() => const Complex(0.5, 0) * (exp() + ((-this).exp()));

  Complex tanh() => sinh() / cosh();

  Complex asin() =>
      const Complex(0, -1) *
      (const Complex(0, 1) * this + (const Complex(1, 0) - this * this).sqrt())
          .ln();

  Complex acos() =>
      const Complex(dart.pi / 2, 0) +
      const Complex(0, 1) *
          (const Complex(0, 1) * this +
                  (const Complex(1, 0) - this * this).sqrt())
              .ln();
  // This isn't what's given in the advanced functions book (page 61), but
  // it matches the calculator's behavior.

  Complex atan() => const Complex(0, 0.5) * ((const Complex(0, 1) + this) / (const Complex(0, 1) - this) ).ln();

  Complex asinh() => (this + (this * this + const Complex(1, 0)).sqrt()).ln();

  Complex acosh() =>
      const Complex(2, 0) *
      (((this + const Complex(1, 0)) / const Complex(2, 0)).sqrt() +
              (((this - const Complex(1, 0)) / const Complex(2, 0))).sqrt())
          .ln();

  Complex atanh() =>
      const Complex(0.5, 0) *
      ((const Complex(1, 0) + this).ln() - (const Complex(1, 0) - this).ln());
}

///
/// Just for the namespacing
///
class Real {
  static double sinh(double x) => (dart.exp(x) - dart.exp(-x)) / 2;
  static double cosh(double x) => (dart.exp(x) + dart.exp(-x)) / 2;
  static double tanh(double x) {
    final e2x = dart.exp(2 * x);
    return (e2x - 1) / (e2x + 1);
  }

  /// Inverse sinh
  static double asinh(double x) => dart.log(x + dart.sqrt(x * x + 1));
  static double acosh(double x) => dart.log(x + dart.sqrt(x * x - 1));
  static double atanh(double x) => 0.5 * dart.log((1 + x) / (1 - x));
}
