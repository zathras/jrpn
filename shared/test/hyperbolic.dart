import 'package:flutter_test/flutter_test.dart';
import 'package:jrpn/m/complex.dart';
import 'package:jrpn/m/model.dart';

import 'package:jrpn/v/buttons.dart';
import 'package:jrpn15/main.dart';

///
/// Test the trig function, and test the input state machine for
/// the hyperbolic trig funcitons and DEG/RAD/GRD
///
class TrigInputTests {
  final Controller15 controller;
  final ButtonLayout15 layout;

  TrigInputTests(this.controller, this.layout);

  // Test trig functions with an argument of 12
  void _testTrigFunction(
      CalculatorButton units, CalculatorButton f, double expected,
      [double? inverse]) {
    controller.buttonWidgetDown(layout.gShift);
    controller.buttonWidgetDown(units);
    controller.buttonWidgetDown(layout.n1);
    controller.buttonWidgetDown(layout.n2);
    controller.buttonWidgetDown(f);
    expect(controller.model.x, Value.fromDouble(expected));
    controller.buttonWidgetDown(layout.gShift);
    controller.buttonWidgetDown(f);
    expect(controller.model.x, Value.fromDouble(inverse ?? 12));
  }

  // Test hyperbolic trig functions with an argument of 1.2
  void _testHyperbolicFunction(CalculatorButton f, double expected,
      [double? inverse]) {
    for (final units in [layout.n7, layout.n8, layout.n9]) {
      // Answer shouldn't change based on DEG, RAD or GRD mode
      for (final complex in [false, true]) {
        // Answer shouldn't change based on complex mode
        _setComplexMode(complex);
        controller.buttonWidgetDown(layout.gShift);
        controller.buttonWidgetDown(units); // DEG
        controller.buttonWidgetDown(layout.n1);
        controller.buttonWidgetDown(layout.dot);
        controller.buttonWidgetDown(layout.n2);
        controller.buttonWidgetDown(layout.fShift);
        controller.buttonWidgetDown(layout.gto); // HYP
        controller.buttonWidgetDown(f);
        expect(controller.model.x, Value.fromDouble(expected));
        if (complex) {
          expect(controller.model.xImaginary, Value.zero,
              reason: '${units.gText} $complex');
        }
        controller.buttonWidgetDown(layout.gShift);
        controller.buttonWidgetDown(layout.gto); // HYP-1
        controller.buttonWidgetDown(f);
        expect(controller.model.x, Value.fromDouble(inverse ?? 1.2),
            reason: '${units.gText} $complex');
        if (complex) {
          expect(controller.model.xImaginary, Value.zero);
        }
      }
    }
  }

  void _setComplexMode(bool mode) {
    controller.buttonWidgetDown(layout.gShift);
    if (mode) {
      controller.buttonWidgetDown(layout.n4);
    } else {
      controller.buttonWidgetDown(layout.n5);
    }
    controller.buttonWidgetDown(layout.n8);
  }

  void _testTrigFunctions() {
    _setComplexMode(false);
    _testTrigFunction(layout.n7, layout.sin, 0.2079116908); // n7 is DEG
    _testTrigFunction(
        layout.n8, layout.sin, -0.5365729180, -0.5663706144); // RAD
    _testTrigFunction(layout.n9, layout.sin, 0.1873813146); // GRD
    _testTrigFunction(
        layout.n7, layout.cos, 0.9781476007, 12.00000001); // n7 is DEG
    _testTrigFunction(layout.n8, layout.cos, 0.8438539587, 0.5663706144); // RAD
    _testTrigFunction(layout.n9, layout.cos, 0.9822872507, 12.00000001); // GRD
    _testTrigFunction(layout.n7, layout.tan, 0.2125565617); // n7 is DEG
    _testTrigFunction(
        layout.n8, layout.tan, -0.6358599287, -0.5663706144); // RAD
    _testTrigFunction(layout.n9, layout.tan, 0.1907602022); // GRD

    // Now go into complex mode, and make sure it stays in radians
    _setComplexMode(true);
    for (final units in [layout.n7, layout.n8, layout.n9]) {
      _testTrigFunction(units, layout.sin, -0.5365729180, -0.5663706144);
      _testTrigFunction(units, layout.cos, 0.8438539587, 0.5663706144);
      _testTrigFunction(units, layout.tan, -0.6358599287, -0.5663706144);
    }
    _setComplexMode(false);
    _testTrigFunction(layout.n7, layout.tan, 0.2125565617); // n7 is DEG
  }

  void _testHyperbolicFunctions() {
    _testHyperbolicFunction(layout.sin, 1.509461355);
    _testHyperbolicFunction(layout.cos, 1.810655567);
    _testHyperbolicFunction(layout.tan, 0.8336546070);
  }

  void expectC(Complex expected) {
    expect(controller.model.x, Value.fromDouble(expected.real));
    expect(controller.model.xImaginary, Value.fromDouble(expected.imaginary));
  }

  /// Test a trig function on 1.2+3.4i
  void _testComplexFunction(
      bool hyperbolic, CalculatorButton f, Complex expected,
      [Complex? inverse]) {
    for (final units in [layout.n7, layout.n8, layout.n9]) {
      // Answer shouldn't change based on DEG, RAD or GRD mode
      controller.buttonWidgetDown(layout.gShift);
      controller.buttonWidgetDown(units); // DEG
      controller.buttonWidgetDown(layout.n1);
      controller.buttonWidgetDown(layout.dot);
      controller.buttonWidgetDown(layout.n2);
      controller.buttonWidgetDown(layout.enter);
      controller.buttonWidgetDown(layout.n3);
      controller.buttonWidgetDown(layout.dot);
      controller.buttonWidgetDown(layout.n4);
      controller.buttonWidgetDown(layout.fShift);
      controller.buttonWidgetDown(layout.tan); // I
      if (hyperbolic) {
        controller.buttonWidgetDown(layout.fShift);
        controller.buttonWidgetDown(layout.gto); // HYP
      }
      controller.buttonWidgetDown(f);
      expectC(expected);
      controller.buttonWidgetDown(layout.gShift);
      if (hyperbolic) {
        controller.buttonWidgetDown(layout.gto); // HYP-1
      }
      controller.buttonWidgetDown(f);
      expectC(inverse ?? const Complex(1.2, 3.4));
    }
  }

  void _testInverse(CalculatorButton b, Complex arg, Complex norm, Complex hyp,
      {int digits = 8}) {
    final model = controller.model;
    model.xC = arg;
    controller.buttonDown(b.uKey);
    controller.buttonDown(b.gKey);
    Complex r = model.xC;
    expect(r.real.toStringAsExponential(digits),
        norm.real.toStringAsExponential(digits),
        reason: '${b.uKey} $norm expected, got $r');
    expect(r.imaginary.toStringAsExponential(digits),
        norm.imaginary.toStringAsExponential(digits),
        reason: '${b.uKey} $norm expected, got $r');
    model.xC = arg;
    controller.buttonWidgetDown(layout.fShift);
    controller.buttonWidgetDown(layout.gto);
    controller.buttonWidgetDown(b);
    controller.buttonWidgetDown(layout.gShift);
    controller.buttonWidgetDown(layout.gto);
    controller.buttonWidgetDown(b);
    r = model.xC;
    expect(r.real.toStringAsExponential(digits),
        hyp.real.toStringAsExponential(digits),
        reason: '${b.uKey} $hyp expected, got $r');
    expect(r.imaginary.toStringAsExponential(digits),
        hyp.imaginary.toStringAsExponential(digits),
        reason: '${b.uKey} $hyp expected, got $r');
  }

  /// Check that a function followed by its inverse gives the correct
  /// behavior, as regards quadrants and reflection.
  void _testInverses() {
    final model = controller.model;
    model.isComplexMode = true;
    for (final b in [layout.sin, layout.cos, layout.tan]) {
      for (final re in [-0.1, -1.1, 0.1, 1.1]) {
        for (final im in [-1.1, -0.1, 0.1, 1.1]) {
          final arg = Complex(re, im);
          model.xC = arg;
          Complex r = arg;
          if (re < 0 && b.uKey == Operations15.cos) {
            r = -r;
          }
          _testInverse(b, arg, r, r, digits: 7);
        }
      }
    }

    _testInverse(layout.sin, const Complex(2.8, 2.7),
        const Complex(0.341592654, -2.7), const Complex(-2.8, 0.441592654));
    _testInverse(layout.sin, const Complex(2.8, -2.7),
        const Complex(0.341592654, 2.7), const Complex(-2.8, -0.441592654));
    _testInverse(layout.sin, const Complex(-2.8, 2.7),
        const Complex(-0.341592654, -2.7), const Complex(2.8, 0.441592654));
    _testInverse(layout.sin, const Complex(-2.8, -2.7),
        const Complex(-0.341592654, 2.7), const Complex(2.8, -0.441592654));

    _testInverse(layout.cos, const Complex(2.8, 2.7), const Complex(2.8, 2.7),
        const Complex(2.8, 2.7));
    _testInverse(layout.cos, const Complex(2.8, -2.7), const Complex(2.8, -2.7),
        const Complex(2.8, -2.7));
    _testInverse(layout.cos, const Complex(-2.8, 2.7), const Complex(2.8, -2.7),
        const Complex(2.8, -2.7));
    _testInverse(layout.cos, const Complex(-2.8, -2.7), const Complex(2.8, 2.7),
        const Complex(2.8, 2.7));

    _testInverse(layout.tan, const Complex(2.8, 2.7),
        const Complex(-0.341592654, 2.7), const Complex(2.8, -0.441592654),
        digits: 6);
    _testInverse(layout.tan, const Complex(2.8, -2.7),
        const Complex(-0.341592654, -2.7), const Complex(2.8, 0.441592654),
        digits: 6);
    _testInverse(layout.tan, const Complex(-2.8, 2.7),
        const Complex(0.341592654, 2.7), const Complex(-2.8, -0.441592654),
        digits: 6);
    _testInverse(layout.tan, const Complex(-2.8, -2.7),
        const Complex(0.341592654, -2.7), const Complex(-2.8, 0.441592654),
        digits: 6);
  }

  void _testComplexFunctions() {
    _testComplexFunction(
        false, layout.sin, const Complex(13.97940881, 5.422815472));
    _testComplexFunction(
        true,
        layout.sin,
        const Complex(-1.459344510, -0.4626969191),
        const Complex(-1.2, -0.2584073465));
    _testComplexFunction(
        false, layout.cos, const Complex(5.434908536, -13.94830361));
    _testComplexFunction(
        true,
        layout.cos,
        const Complex(-1.750538530, -0.3857294182),
        const Complex(1.2, -2.883185307));
    _testComplexFunction(
        false,
        layout.tan,
        const Complex(0.001507101876, 1.001642797),
        const Complex(1.200000002, 3.399999998));
    _testComplexFunction(
        true,
        layout.tan,
        const Complex(0.8505969575, 0.07688871007),
        const Complex(1.2, 0.2584073464));

    // An extra hyperbolic tangent function, for historical reasons.
    controller.model.xC = const Complex(0.22, 0.73);
    Operations15.tanh.complexCalc!(controller.model);
    expectC(const Complex(0.3758125280, 0.8220979109));
    Operations15.tanhInverse.complexCalc!(controller.model);
    expectC(const Complex(0.22, 0.73));

    _testInverses();
  }

  void run() {
    _testTrigFunctions();
    _testHyperbolicFunctions();
    _testComplexFunctions();
  }
}
