import 'dart:math';
import 'dart:math' as dart;

import 'package:meta/meta.dart';

///
/// A complex value
///
@immutable
class Complex {
  final double real;
  final double imaginary;

  const Complex(this.real, this.imaginary);

  Complex.polar(double r, double theta)
      : real = r * cos(theta),
        imaginary = r * sin(theta);

  static const zero = Complex(0, 0);

  @override
  String toString()  =>  '$real+${imaginary}i';
  @override
  int get hashCode => Object.hash(real, imaginary);

  @override
  bool operator ==(Object? other) => (other is Complex)
      ? (real == other.real && imaginary == other.imaginary)
      : false;

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

  Complex sqrt() {
    final z = r;
    return Complex(
        dart.sqrt((real + z) / 2), imaginary.sign * dart.sqrt((z - real) / 2));
  }
}
