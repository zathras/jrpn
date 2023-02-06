// ignore_for_file: avoid_print

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

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:jrpn/c/controller.dart';
import 'package:jrpn/v/buttons.dart';
import 'package:vector_math/vector_math_64.dart' as dart_mat;
import 'package:flutter_test/flutter_test.dart';
import 'package:jrpn/c/operations.dart';
import 'package:jrpn/m/model.dart';

import 'package:jrpn/v/main_screen.dart';
import 'package:jrpn15c/main15c.dart';
import 'package:jrpn15c/matrix.dart';
import 'package:jrpn15c/model15c.dart';
import 'package:jrpn15c/tests15c.dart';
import 'hyperbolic.dart';
import 'programs.dart';
import 'package:jrpn15c/linear_algebra.dart' as linalg;

Future<void> main() async {
  runStaticInitialization15();

  // Note that passing Jrpn into testWidgets actually tests very little, because
  // the deferred initialization doesn't happen.  I think it stalls on a plugin
  // waiting for the system, maybe related to receiving links.  Anyway, we
  // don't do it here.

  bool done = false;
  testWidgets('15C Buttons', (WidgetTester tester) async {
    final controller = Controller15(createModel15());
    final ScreenPositioner positioner = ScreenPositioner(12.7, 8);
    await tester.pumpWidget(Builder(builder: (BuildContext context) {
      final factory = LandscapeButtonFactory15(context, positioner, controller);
      final layout = ButtonLayout15(factory, 10, 0.1);

      TrigInputTests(controller, layout).run();
      MiscTests(controller, layout).run();
      unawaited(() async {
        try {
          await MatrixTests(TestCalculator(for15C: true), layout).run();
        } finally {
          done = true;
        }
      }());

      return Container(); // placeholder
    }));
    await tester.pumpAndSettle(const Duration(milliseconds: 10000));
    expect(done, true);
  });

  test('Built-in self tests 15C', () async {
    await SelfTests15(inCalculator: false).runAll();
  });
}

class MiscTests {
  final Controller15 controller;
  final ButtonLayout15 layout;
  final Model15 model;

  MiscTests(this.controller, this.layout) : model = controller.model;

  void _userModeStackLift() {
    controller.buttonWidgetDown(layout.n1);
    controller.buttonWidgetDown(layout.enter);
    controller.buttonWidgetDown(layout.n2);
    controller.buttonWidgetDown(layout.fShift);
    controller.buttonWidgetDown(layout.rcl); // USER
    expect(model.userMode, true);
    controller.buttonWidgetDown(layout.n3);
    expect(model.x, Value.fromDouble(3));
    expect(model.y, Value.fromDouble(2));
    expect(model.z, Value.fromDouble(1));
    controller.buttonWidgetDown(layout.fShift);
    controller.buttonWidgetDown(layout.rcl); // USER
    expect(model.userMode, false);
    expect(model.x, Value.fromDouble(3));
    expect(model.y, Value.fromDouble(2));
    expect(model.z, Value.fromDouble(1));
  }

  void _toPolar(Value Function() getY) {
    controller.buttonDown(Operations15.deg);

    model.yF = 5;
    model.xF = 4;
    if (model.isComplexMode) {
      controller.buttonDown(Operations.xy);
      controller.buttonDown(Operations15.I15);
    }
    controller.buttonDown(Operations15.toP);
    expect(model.x, Value.fromDouble(6.403124237));
    expect(getY(), Value.fromDouble(51.34019175));
    controller.buttonDown(Operations15.toR);
    expect(model.x, Value.fromDouble(3.999999999));
    expect(getY(), Value.fromDouble(5));

    model.yF = 5;
    model.xF = -4;
    if (model.isComplexMode) {
      controller.buttonDown(Operations.xy);
      controller.buttonDown(Operations15.I15);
    }
    controller.buttonDown(Operations15.toP);
    expect(model.x, Value.fromDouble(6.403124237));
    expect(getY(), Value.fromDouble(128.6598083));
    controller.buttonDown(Operations15.toR);
    expect(model.x, Value.fromDouble(-4.000000004));
    expect(getY(), Value.fromDouble(4.999999996));

    model.yF = -5;
    model.xF = 4;
    if (model.isComplexMode) {
      controller.buttonDown(Operations.xy);
      controller.buttonDown(Operations15.I15);
    }
    controller.buttonDown(Operations15.toP);
    expect(model.x, Value.fromDouble(6.403124237));
    expect(getY(), Value.fromDouble(-51.34019175));
    controller.buttonDown(Operations15.toR);
    expect(model.x, Value.fromDouble(3.999999999));
    expect(getY(), Value.fromDouble(-5));

    model.yF = -5;
    model.xF = -4;
    if (model.isComplexMode) {
      controller.buttonDown(Operations.xy);
      controller.buttonDown(Operations15.I15);
    }
    controller.buttonDown(Operations15.toP);
    expect(model.x, Value.fromDouble(6.403124237));
    expect(getY(), Value.fromDouble(-128.6598083));
    controller.buttonDown(Operations15.toR);
    expect(model.x, Value.fromDouble(-4.000000004));
    expect(getY(), Value.fromDouble(-4.999999996));

    controller.buttonDown(Operations15.rad);
    model.yF = 5;
    model.xF = 4;
    if (model.isComplexMode) {
      controller.buttonDown(Operations.xy);
      controller.buttonDown(Operations15.I15);
    }
    controller.buttonDown(Operations15.toP);
    expect(model.x, Value.fromDouble(6.403124237));
    expect(getY(), Value.fromDouble(0.8960553846));
    controller.buttonDown(Operations15.toR);
    expect(model.x, Value.fromDouble(4));
    expect(getY(), Value.fromDouble(5));

    controller.buttonDown(Operations15.grd);
    model.yF = 5;
    model.xF = 4;
    if (model.isComplexMode) {
      controller.buttonDown(Operations.xy);
      controller.buttonDown(Operations15.I15);
    }
    controller.buttonDown(Operations15.toP);
    expect(model.x, Value.fromDouble(6.403124237));
    expect(getY(), Value.fromDouble(57.04465750));
    controller.buttonDown(Operations15.toR);
    expect(model.x, Value.fromDouble(3.999999999));
    expect(getY(), Value.fromDouble(5));

    controller.buttonDown(Operations15.deg);
  }

  void run() {
    model.isComplexMode = false;
    _userModeStackLift();
    _toPolar(() => model.y);
    model.isComplexMode = true;
    _toPolar(() => model.xImaginary);
    model.isComplexMode = false;
  }
}

class MatrixTests {
  final TestCalculator calculator;
  final Controller15 controller;
  final ButtonLayout15 layout;
  final Model15 model;
  final StreamIterator<ProgramEvent> out;

  MatrixTests(this.calculator, this.layout)
      : controller = calculator.controller as Controller15,
        model = calculator.controller.model as Model15,
        out = StreamIterator<ProgramEvent>(calculator.output.stream);

  Future<void> _page139({required bool asProgram}) async {
    model.isComplexMode = true;
    model.userMode = false;
    if (asProgram) {
      controller.buttonWidgetDown(layout.gShift);
      controller.buttonWidgetDown(layout.rs); // P/R
      controller.buttonWidgetDown(layout.fShift);
      controller.buttonWidgetDown(layout.rdown); // CLEAR PRGM
      controller.buttonWidgetDown(layout.fShift);
      controller.buttonWidgetDown(layout.sst); // LBL
      controller.buttonWidgetDown(layout.sqrt); // A
    }
    controller.buttonWidgetDown(layout.fShift);
    controller.buttonWidgetDown(layout.n7); // FIX
    controller.buttonWidgetDown(layout.n4);
    controller.buttonWidgetDown(layout.gShift);
    controller.buttonWidgetDown(layout.n5); // CF
    controller.buttonWidgetDown(layout.n8);
    if (!asProgram) {
      expect(false, model.isComplexMode);
    }
    controller.buttonWidgetDown(layout.n2);
    controller.buttonWidgetDown(layout.enter);
    controller.buttonWidgetDown(layout.fShift);
    controller.buttonWidgetDown(layout.sin); // DIM
    controller.buttonWidgetDown(layout.sqrt); // A
    controller.buttonWidgetDown(layout.fShift);
    controller.buttonWidgetDown(layout.chs); // MATRIX
    controller.buttonWidgetDown(layout.n1); // A
    controller.buttonWidgetDown(layout.fShift);
    controller.buttonWidgetDown(layout.rcl); // USER

    controller.buttonWidgetDown(layout.n3);
    controller.buttonWidgetDown(layout.dot);
    controller.buttonWidgetDown(layout.n8);
    controller.buttonWidgetDown(layout.sto);
    controller.buttonWidgetDown(layout.sqrt); // A
    controller.buttonUp();
    if (!asProgram) {
      expect(model.display.current, ' 3.8000     ');
      expect(model.matrices[0].get(0, 0), Value.fromDouble(3.8));
    }

    controller.buttonWidgetDown(layout.n7);
    controller.buttonWidgetDown(layout.dot);
    controller.buttonWidgetDown(layout.n2);
    controller.buttonWidgetDown(layout.sto);
    controller.buttonWidgetDown(layout.sqrt); // A
    controller.buttonUp();
    if (!asProgram) {
      expect(model.matrices[0].get(0, 1), Value.fromDouble(7.2));
    }

    controller.buttonWidgetDown(layout.n1);
    controller.buttonWidgetDown(layout.dot);
    controller.buttonWidgetDown(layout.n3);
    controller.buttonWidgetDown(layout.sto);
    controller.buttonWidgetDown(layout.sqrt); // A
    controller.buttonUp();
    if (!asProgram) {
      expect(model.matrices[0].get(1, 0), Value.fromDouble(1.3));
    }

    controller.buttonWidgetDown(layout.dot);
    controller.buttonWidgetDown(layout.n9);
    controller.buttonWidgetDown(layout.chs);
    controller.buttonWidgetDown(layout.sto);
    controller.buttonWidgetDown(layout.sqrt); // A
    controller.buttonUp();
    if (asProgram) {
      controller.buttonWidgetDown(layout.gto);
      controller.buttonWidgetDown(layout.sqrt); // GTO A, should be skipped
    } else {
      expect(model.matrices[0].get(1, 1), Value.fromDouble(-0.9));
      expect(model.memory.registers[0], Value.fromDouble(1));
      expect(model.memory.registers[1], Value.fromDouble(1));
    }

    controller.buttonWidgetDown(layout.n2);
    controller.buttonWidgetDown(layout.enter);
    controller.buttonWidgetDown(layout.n1);
    controller.buttonWidgetDown(layout.fShift);
    controller.buttonWidgetDown(layout.sin); // DIM
    controller.buttonWidgetDown(layout.eX); // B

    controller.buttonWidgetDown(layout.n1);
    controller.buttonWidgetDown(layout.n6);
    controller.buttonWidgetDown(layout.dot);
    controller.buttonWidgetDown(layout.n5);
    controller.buttonWidgetDown(layout.sto);
    controller.buttonWidgetDown(layout.eX); // B
    controller.buttonUp();
    if (!asProgram) {
      expect(model.matrices[1].get(0, 0), Value.fromDouble(16.5));
    }

    controller.buttonWidgetDown(layout.n2);
    controller.buttonWidgetDown(layout.n2);
    controller.buttonWidgetDown(layout.dot);
    controller.buttonWidgetDown(layout.n1);
    controller.buttonWidgetDown(layout.chs);
    controller.buttonWidgetDown(layout.sto);
    controller.buttonWidgetDown(layout.eX); // B
    controller.buttonUp();
    if (asProgram) {
      controller.buttonWidgetDown(layout.gto);
      controller.buttonWidgetDown(layout.sqrt); // GTO A, should be skipped
    } else {
      expect(model.matrices[1].get(1, 0), Value.fromDouble(-22.1));
    }

    controller.buttonWidgetDown(layout.fShift);
    controller.buttonWidgetDown(layout.eex); // result
    controller.buttonWidgetDown(layout.tenX); // C

    controller.buttonWidgetDown(layout.rcl);
    controller.buttonWidgetDown(layout.chs); // matrix
    controller.buttonWidgetDown(layout.eX); // B
    if (!asProgram) {
      expect(model.x, Value.fromMatrix(1));
    }
    controller.buttonWidgetDown(layout.rcl);
    controller.buttonWidgetDown(layout.chs); // matrix
    controller.buttonWidgetDown(layout.sqrt); // A
    if (!asProgram) {
      expect(model.x, Value.fromMatrix(0));
    }
    controller.buttonWidgetDown(layout.div);
    if (asProgram) {
      controller.buttonWidgetDown(layout.gShift);
      controller.buttonWidgetDown(layout.gsb); // RTN
      controller.buttonWidgetDown(layout.fShift);
      controller.buttonWidgetDown(layout.sst); // LBL
      controller.buttonWidgetDown(layout.eX); // B
      controller.buttonWidgetDown(layout.rcl);
      controller.buttonWidgetDown(layout.tenX); // C
      controller.buttonWidgetDown(layout.gShift);
      controller.buttonWidgetDown(layout.rs); // P/R
      controller.buttonWidgetDown(layout.sqrt); // A (in user mode)
      controller.buttonUp();
      expect(await out.moveNext(), true);
      expect(out.current, ProgramEvent.done);
    }
    expect(model.x, Value.fromMatrix(2));

    if (asProgram) {
      controller.buttonWidgetDown(layout.eX); // B in user mode
      controller.buttonUp();
      expect(await out.moveNext(), true);
      expect(out.current, ProgramEvent.done);
    } else {
      controller.buttonWidgetDown(layout.rcl);
      controller.buttonWidgetDown(layout.tenX); // C
      controller.buttonUp();
    }
    expect(model.x, Value.fromDouble(-11.28873239));
    controller.buttonWidgetDown(layout.rcl);
    controller.buttonWidgetDown(layout.tenX); // C
    controller.buttonUp();
    expect(model.x, Value.fromDouble(8.249608762));

    controller.buttonWidgetDown(layout.fShift);
    controller.buttonWidgetDown(layout.rcl); // USER (off)
    controller.buttonWidgetDown(layout.fShift);
    controller.buttonWidgetDown(layout.chs); // matrix
    controller.buttonWidgetDown(layout.n0);
    for (int i = 0; i < 5; i++) {
      expect(model.matrices[i].length, 0);
    }
    expect(model.userMode, false);
  }

  ///
  /// Test STO-G-<matrix> and RCL-G-Matrix
  ///
  void _page146() {
    final Matrix mat = model.matrices[3];
    mat.resize(model, 3, 3);
    mat.set(2, 1, Value.zero);
    mat.set(1, 2, Value.fromDouble(99.99));
    model.yF = 42.42;
    model.pushStack();
    model.yF = 3.9; // Row 3
    model.xF = 2.01; // Column 2
    controller.buttonWidgetDown(layout.sto);
    controller.buttonWidgetDown(layout.gShift);
    controller.buttonWidgetDown(layout.yX); // D
    controller.buttonUp();
    expect(mat.get(2, 1), Value.fromDouble(42.42));
    expect(model.x, Value.fromDouble(42.42));
    model.xF = 6.66;
    model.pushStack();
    controller.buttonDown(Operations.n2); // Ro2
    controller.buttonDown(Operations.enter);
    controller.buttonDown(Operations.n3); // Column
    controller.buttonWidgetDown(layout.rcl);
    controller.buttonWidgetDown(layout.gShift);
    controller.buttonWidgetDown(layout.yX); // D
    controller.buttonUp();
    expect(model.x, Value.fromDouble(99.99));
    expect(model.y, Value.fromDouble(6.66));
    mat.resize(model, 0, 0);
  }

  ///
  /// Test STO-matrix
  ///
  void _stoMatrixAndChs() {
    final Matrix mat = model.matrices[3];
    mat.resize(model, 3, 3);
    for (int i = 0; i < 3; i++) {
      for (int j = 0; j < 3; j++) {
        mat.set(i, j, Value.fromDouble(10.0 * i + j));
      }
    }
    controller.buttonWidgetDown(layout.rcl);
    controller.buttonWidgetDown(layout.chs); // Matrix
    controller.buttonWidgetDown(layout.yX); // Matrix
    controller.buttonWidgetDown(layout.sto);
    controller.buttonWidgetDown(layout.fShift);
    controller.buttonWidgetDown(layout.chs); // Matrix
    controller.buttonWidgetDown(layout.fShift);
    controller.buttonWidgetDown(layout.reciprocal);
    model.xF = -42;
    controller.buttonWidgetDown(layout.sto);
    controller.buttonWidgetDown(layout.chs); // Matrix
    controller.buttonWidgetDown(layout.yX);

    final Matrix mat2 = model.matrices[4];
    mat.resize(model, 3, 3);
    for (int i = 0; i < 3; i++) {
      for (int j = 0; j < 3; j++) {
        expect(mat.get(i, j), Value.fromDouble(-42));
        expect(mat2.get(i, j), Value.fromDouble(10.0 * i + j));
      }
    }

    // Test chs on matrix E
    controller.buttonWidgetDown(layout.rcl);
    controller.buttonWidgetDown(layout.chs); // Matrix
    controller.buttonWidgetDown(layout.reciprocal); // Matrix
    controller.buttonWidgetDown(layout.chs); // Matrix
    for (int i = 0; i < 3; i++) {
      for (int j = 0; j < 3; j++) {
        expect(mat2.get(i, j), Value.fromDouble(-10.0 * i + -j));
      }
    }
  }

  void _invertMatrix(bool useInvert) {
    void invert(Matrix m) {
      if (useInvert) {
        linalg.invert(m);
      } else {
        final identity = CopyMatrix(m)..identity();
        final result = CopyMatrix(m);
        linalg.solve(m, identity, result);
        m.isLU = false;
        result.visit((r, c) => m.set(r, c, result.get(r, c)));
      }
    }

    final Matrix mat2 = model.matrices[4];
    final Matrix mat = model.matrices[3];
    mat2.resize(model, 2, 2);
    mat2.setF(0, 0, 0.1);
    mat2.setF(0, 1, 0.1);
    mat2.setF(1, 0, 0.2);
    mat2.setF(1, 1, 0.4);
    AMatrix mat2c = CopyMatrix(mat2);
    invert(mat2);
    expect(mat2.getF(0, 0), 20);
    expect(mat2.getF(0, 1), -5);
    expect(mat2.getF(1, 0), -10);
    expect(mat2.getF(1, 1), 5);
    invert(mat2);
    expect(mat2.equivalent(mat2c), true);

    mat2.resize(model, 3, 3);
    mat2.setF(0, 0, 0.1);
    mat2.setF(0, 1, 0.1);
    mat2.setF(0, 2, 0.1);
    mat2.setF(1, 0, 0.2);
    mat2.setF(1, 1, 0.4);
    mat2.setF(1, 2, 0.8);
    mat2.setF(2, 0, 0.1);
    mat2.setF(2, 1, 0.3);
    mat2.setF(2, 2, 0.6);
    mat2c = CopyMatrix(mat2);
    invert(mat2);
    expect(mat2.getF(0, 0), 0);
    expect(mat2.getF(0, 1), 15);
    expect(mat2.getF(0, 2), -20);
    expect(mat2.getF(1, 0), 20);
    expect(mat2.getF(1, 1), -25);
    expect(mat2.getF(1, 2), 30);
    expect(mat2.getF(2, 0), -10);
    expect(mat2.getF(2, 1), 10);
    expect(mat2.getF(2, 2), -10);
    invert(mat2);
    expectMatrix(mat2, mat2c, useInvert ? 5e-10 : 2e-9);

    // Test 1/x on matrix E
    mat2.setF(0, 0, 0.1);
    mat2.setF(0, 1, 0.1);
    mat2.setF(0, 2, 0.1);
    mat2.setF(1, 0, 0.2);
    mat2.setF(1, 1, 0.4);
    mat2.setF(1, 2, 0.8);
    mat2.setF(2, 0, 0.1);
    mat2.setF(2, 1, 0.5);
    mat2.setF(2, 2, 0.9);
    final result = model.matrices[model.resultMatrix = 2];
    controller.buttonWidgetDown(layout.rcl);
    controller.buttonWidgetDown(layout.chs); // Matrix
    controller.buttonWidgetDown(layout.reciprocal); // E
    controller.buttonWidgetDown(layout.reciprocal); // 1/x
    {
      const epsilon = 1.1e-8;
      expectRounded(epsilon, result.get(0, 0), 5);
      expectRounded(epsilon, result.get(0, 1), 5);
      expectRounded(epsilon, result.get(0, 2), -5);
      expectRounded(epsilon, result.get(1, 0), 12.5);
      expectRounded(epsilon, result.get(1, 1), -10);
      expectRounded(epsilon, result.get(1, 2), 7.5);
      expectRounded(epsilon, result.get(2, 0), -7.5);
      expectRounded(epsilon, result.get(2, 1), 5);
      expectRounded(epsilon, result.get(2, 2), -2.5);
    }

    final orig = [
      [0.01, 0.02, 0.03, 0.04, 0.05],
      [0.01, 0.03, 0.05, 0.07, 0.09],
      [0.01, 0.06, 0.1, 0.15, 0.25],
      [0.1, 0.2, 0.5, 0.7, 0.8],
      [0.3, 0.6, 0.7, 0.8, 0.9],
    ];
    final inverted = [
      [450.0, -200.0, 0.0, 0.0, -5.0],
      [-12.5, 200.0, -25.0, -12.5, -1.25],
      [-612.5, -300.0, 75.0, 27.5, 18.75],
      [362.5, 300.0, -75.0, -17.5, -13.75],
      [12.5, -100.0, 25.0, 2.5, 1.25],
    ];
    for (final m in model.matrices) {
      m.resize(model, 0, 0);
    }
    model.memory.numRegisters = 2;
    mat.resize(model, 5, 5);
    mat2.resize(model, 5, 5);
    mat.isLU = false;
    mat2.isLU = false;
    // do all 5! (120) permutations
    for (int a = 0; a < 5; a++) {
      final remain = [0, 1, 2, 3, 4];
      final map = <int>[];
      final lastX = <int>[];
      void take(int x) {
        lastX.add(x);
        map.add(remain[x]);
        remain.removeAt(x);
      }

      void give() {
        final lx = lastX.removeLast();
        final lv = map.removeLast();
        remain.insert(lx, lv);
      }

      take(a);
      for (int b = 0; b < 4; b++) {
        take(b);
        for (int c = 0; c < 3; c++) {
          take(c);
          for (int d = 0; d < 2; d++) {
            take(d);
            take(0);
            for (int r = 0; r < 5; r++) {
              for (int c = 0; c < 5; c++) {
                mat.setF(r, map[c], orig[r][c]);
                mat2.setF(map[r], c, inverted[r][c]);
              }
            }
            final o = CopyMatrix(mat);
            invert(mat);
            expectMatrix(mat, mat2, 5e-6);
            invert(mat);
            expectMatrix(mat, o, useInvert ? 2e-8 : 5e-8);
            give();
            give();
          }
          give();
        }
        give();
      }
    }

    ///
    /// Make a bunch of pseudo-random matrices, find their inverses, multiply
    /// 'em, and make sure the result is close to the identity matrix.
    ///
    final random = [
      0.11554357410230745,
      0.1752190781091121,
      0.2554799105149069,
      0.7882517396398285,
      0.9553619742044123,
      0.31669130654119626,
      0.6512789895641755,
      0.956850550664375,
      0.5149877831225405,
      0.9069305781274585,
      0.6148645579026758,
      0.2954207054723502,
      0.9252281346955582,
      1.0374866365398772,
      0.30523103927522177,
      0.9498085834094088,
      0.596642195724848,
      0.7278426526965753,
      1.0453753342972407,
      0.7553738159786345,
      0.15637221523026837,
      0.8670820197735291,
      0.3938634878728674,
      0.4382736054911537,
      0.1717232227697613,
      1.062594511041458,
      0.43563026638450497,
      0.8034066490281968,
      0.2142472399579687,
      0.5918618563998227,
      0.9345396921345667,
      0.8449774408819636,
      0.783358655118447,
      1.0281576723791797,
      0.6229052671179554,
      1.028115675075235,
      0.9757683761758337,
      0.2646857903574741,
      0.7999931334094097,
      0.969812107245347,
      0.42444150839051675,
      0.8935187276167458,
      0.5256281891538678,
      0.905695547664674,
      0.2450874099913132,
      0.5912254403400581,
      0.7810969255400474,
      0.8788464339354397,
      0.6620639665847116,
      1.0943110970818815,
      0.48470482292355066,
      0.6615836506436301,
      1.0458772534696898,
      0.5047192340830525,
      0.4685312103667608,
      0.9802805674851287,
      0.21305505735550592,
      0.37026185427005986,
      0.10162243410658447,
      0.7848549364642744,
      0.28347485762438895,
      0.1818113208618173,
      1.0280231209098611,
      0.6961553994372459,
      0.9903127956749369,
      0.7456275776442648,
      0.6278249317681296,
      0.5293719965367599,
      0.3448840987921128,
      0.3181939701519737,
      0.12990316554686723,
      0.7981990455439859,
      0.7227555038509729,
      0.925907636507783,
      0.843093213283728,
      0.7396488347741407,
      0.9487692238747365,
      0.39142942330231,
      0.6152346182123536,
      0.7380712954605932,
      0.9166836954506805,
      0.7484829378036751,
      0.19031076562245933,
      0.5856881358721754,
      0.21339616026637045,
      0.5615065546729514,
      0.5880700604803681,
      0.3135305338351917,
      1.0329419877061843,
      0.726816109416792,
      0.9315827556414396,
      0.37734079984471613,
      0.3732704741421152,
      0.2996321641769589,
      0.5189723759038541,
      0.13142897558336689,
      0.34724822080474493,
      0.2751082165630431,
      0.11038090886648369,
      0.7374852462277609,
      0.6666619454401502,
    ];
    for (int sz = 1; sz <= 5; sz++) {
      mat.resize(model, sz, sz);
      mat2.resize(model, sz, sz);
      final identity = CopyMatrix(mat)..identity();
      final result = CopyMatrix(mat);

      for (int startPos = 0; startPos < random.length; startPos++) {
        int pos = startPos;
        mat.visit((r, c) {
          mat2.setF(r, c, random[pos]);
          mat.setF(r, c, random[pos++]);
          pos = pos % random.length;
        });
        //
        // While we're here, test the determinant
        //
        if (sz == 2) {
          final dm = dart_mat.Matrix2.zero();
          mat2.visit((r, c) => dm.setEntry(r, c, mat.getF(r, c)));
          expectRounded(2e-9, Value.fromDouble(linalg.determinant(mat2)),
              dm.determinant());
        } else if (sz == 3) {
          final dm = dart_mat.Matrix3.zero();
          mat2.visit((r, c) => dm.setEntry(r, c, mat.getF(r, c)));
          expectRounded(2e-9, Value.fromDouble(linalg.determinant(mat2)),
              dm.determinant());
        } else if (sz == 4) {
          final dm = dart_mat.Matrix4.zero();
          mat2.visit((r, c) => dm.setEntry(r, c, mat.getF(r, c)));
          expectRounded(2e-9, Value.fromDouble(linalg.determinant(mat2)),
              dm.determinant());
        }
        invert(mat2);
        result.dot(mat, mat2);
        expectMatrix(result, identity, useInvert ? 5e-7 : 2e-6);
      }
    }

    mat.resize(model, 0, 0);
    mat2.resize(model, 0, 0);
  }

  void expectRounded(double epsilon, Value v, double expected) {
    if ((v.asDouble - expected).abs() > epsilon) {
      expect(false, '$v differs from $expected by more than $epsilon');
    }
  }

  void _singularMatrix() {
    // Advanced functions page 98:  Singular matrix example.  Our LU
    // perturbation to avoid zero pivots is unlikely to be identical to what
    // the real 15C does, but it was chosen to work for this known example.
    final mat = model.matrices[0];
    mat.resize(model, 2, 2);
    mat.setF(0, 0, 3);
    mat.setF(0, 1, 3);
    mat.setF(1, 0, 1);
    mat.setF(1, 1, 1);
    final mat2 = model.matrices[1];
    mat2.resize(model, 2, 1);
    mat2.setF(0, 0, 1);
    mat2.setF(1, 0, 1);
    final result = model.matrices[model.resultMatrix = 2];
    controller.buttonDown(Operations15.rcl15);
    controller.buttonDown(Operations15.matrix);
    controller.buttonDown(Operations15.letterLabelB);
    controller.buttonUp();
    controller.buttonDown(Operations15.rcl15);
    controller.buttonDown(Operations15.matrix);
    controller.buttonDown(Operations15.letterLabelA);
    controller.buttonUp();
    controller.buttonDown(Operations15.div);
    expect(mat.isLU, true);
    expect(mat.get(0, 0), Value.fromDouble(3));
    expect(mat.get(0, 1), Value.fromDouble(3));
    expect(mat.get(1, 0), Value.fromDouble(1.0 / 3.0));
    expect(mat.get(1, 1), Value.fromDouble(1e-10));
    expect(result.get(0, 0), Value.fromDouble(-6666666667));
    expect(result.get(1, 0), Value.fromDouble(6666666667));
    model.matrices[0].resize(model, 0, 0);
    model.matrices[1].resize(model, 0, 0);
    model.matrices[2].resize(model, 0, 0);
  }

  void _transpose() {
    final mat = model.matrices[1];
    for (int rows = 1; rows <= 50; rows++) {
      for (int cols = 1; cols <= 50 ~/ rows; cols++) {
        mat.resize(model, rows, cols);
        mat.visit((r, c) => mat.setF(r, c, 100.0 * r + c));
        final orig = CopyMatrix(mat);
        controller.buttonDown(Operations15.rcl15);
        controller.buttonDown(Operations15.matrix);
        controller.buttonDown(Operations15.letterLabelB);
        controller.buttonDown(Operations15.matrix);
        controller.buttonDown(Operations.n4);
        expect(mat.rows, orig.columns);
        expect(mat.columns, orig.rows);
        mat.visit((r, c) {
          expect(mat.get(r, c), orig.get(c, r));
        });
      }
    }
    mat.resize(model, 0, 0);
  }

  void _complexMatrix() {
    final numRegisters = model.memory.numRegisters;
    model.memory.numRegisters = 2;
    final mat = model.matrices[1];
    for (int rows = 1; rows <= 50; rows++) {
      for (int cols = 2; cols <= 50 ~/ rows; cols += 2) {
        mat.resize(model, rows, cols);
        mat.visit((r, c) => mat.setF(r, c, 100.0 * r + c));
        final orig = CopyMatrix(mat);
        controller.buttonDown(Operations15.rcl15);
        controller.buttonDown(Operations15.matrix);
        controller.buttonDown(Operations15.letterLabelB);
        controller.buttonDown(Operations15.pYX);
        expect(mat.rows, orig.rows * 2);
        expect(mat.columns, orig.columns ~/ 2);
        mat.visit((r, c) {
          expect(mat.get(r, c),
              orig.get(r % orig.rows, c * 2 + (r >= orig.rows ? 1 : 0)));
        });
        controller.buttonDown(Operations15.cYX);
        expectMatrix(mat, orig);
      }
    }
    for (int rows = 1; rows <= 12; rows++) {
      for (int cols = 1; cols <= 12 ~/ rows; cols++) {
        mat.resize(model, rows * 2, cols);
        for (int r = 0; r < rows; r++) {
          for (int c = 0; c < cols; c++) {
            mat.setF(r, c, 1 + r + 100.0 * c);
            mat.setF(r + rows, c, 1001 + r + 100.0 * c);
          }
        }
        final copy = CopyMatrix(mat);
        mat.convertToZTilde(model);
        for (int r = 0; r < rows; r++) {
          for (int c = 0; c < cols; c++) {
            expect(mat.get(r, c), copy.get(r, c));
            expect(mat.get(r + rows, c + cols), copy.get(r, c));
            expect(mat.get(r + rows, c), copy.get(r + rows, c));
            expect(mat.get(r, c + cols), copy.get(r + rows, c).negateAsFloat());
            mat.set(r, c + cols, Value.zero);
            mat.set(r + rows, c + cols, Value.zero);
          }
        }
        mat.convertFromZTilde(model);
        expectMatrix(mat, copy);
      }
    }
    mat.resize(model, 0, 0);
    model.memory.numRegisters = numRegisters;
  }

  void _misc() {
    final mat = model.matrices[model.resultMatrix = 1];
    mat.resize(model, 5, 5);
    final vals = [
      <double>[1, 3, 29, 4.7, 16.8],
      <double>[27, -3, 5, 24, 3.14],
      <double>[99, 86, 8, 42, 6.66],
      <double>[23, 6.022, 51, 52, 88],
      <double>[210, -37, 5, 16, 7]
    ];

    mat.visit((r, c) => mat.setF(r, c, vals[r][c]));
    controller.buttonDown(Operations15.rcl15);
    controller.buttonDown(Operations15.matrix);
    controller.buttonDown(Operations15.letterLabelB);
    controller.buttonDown(Operations15.matrix);
    controller.buttonDown(Operations.n7); // Row norm
    expect(model.x, Value.fromDouble(275));

    controller.buttonDown(Operations15.rcl15);
    controller.buttonDown(Operations15.matrix);
    controller.buttonDown(Operations15.letterLabelB);
    controller.buttonDown(Operations15.matrix);
    controller.buttonDown(Operations.n8); // Frobenius norm
    expect(model.x, Value.fromDouble(284.5818154));

    mat.transpose();

    controller.buttonDown(Operations15.rcl15);
    controller.buttonDown(Operations15.matrix);
    controller.buttonDown(Operations15.letterLabelB);
    controller.buttonDown(Operations15.matrix);
    controller.buttonDown(Operations.n7); // Row norm
    expect(model.x, Value.fromDouble(360));

    controller.buttonDown(Operations15.rcl15);
    controller.buttonDown(Operations15.matrix);
    controller.buttonDown(Operations15.letterLabelB);
    controller.buttonDown(Operations15.matrix);
    controller.buttonDown(Operations.n8); // Frobenius norm
    expect(model.x, Value.fromDouble(284.5818154));

    mat.resize(model, 0, 0);
  }

  void _testScalar(NormalOperation op, double Function(double x, double y) f) {
    final values = [
      [1.1, -2.2, 3.3],
      [4.4, 5.5, 6.6]
    ];
    final scalarValues = [327.1, -56.0, 1.99, 42.24];
    final Matrix mat = model.matrices[0];
    final Matrix result = model.matrices[model.resultMatrix = 1];
    mat.resize(model, 2, 3);
    for (final s in scalarValues) {
      mat.visit((r, c) {
        model.yF = values[r][c];
        model.xF = s;
        controller.buttonDown(op);
        expect(Value.fromDouble(f(s, values[r][c])), model.x);
        mat.setF(r, c, values[r][c]);
      });
    }
    for (final s in scalarValues) {
      model.xF = s;
      model.y = Value.fromMatrix(0);
      controller.buttonDown(op);
      expect(model.x, Value.fromMatrix(1));
      expect(2, result.rows);
      expect(3, result.columns);
      result.visit((r, c) {
        expect(Value.fromDouble(f(s, values[r][c])), result.get(r, c));
      });
    }
    for (final s in scalarValues) {
      model.x = Value.fromMatrix(0);
      model.yF = s;
      controller.buttonDown(op);
      expect(model.x, Value.fromMatrix(1));
      expect(2, result.rows);
      expect(3, result.columns);
      result.visit((r, c) {
        expect(Value.fromDouble(f(values[r][c], s)), result.get(r, c));
      });
    }
  }

  void _play(List<CalculatorButton> script) {
    for (final b in script) {
      controller.buttonWidgetDown(b);
      controller.buttonUp();
    }
  }

  /// the main example that works through ch12, starting on page 144.
  Future<void> _ch12() async {
    final l = layout;
    final mA = model.matrices[0];
    final mB = model.matrices[1];
    final mC = model.matrices[2];
    final mD = model.matrices[3];
    model.userMode = false;
    model.resultMatrix = 0;
    _play([l.fShift, l.chs, l.n0]); // F matrix 0
    _play([l.fShift, l.chs, l.n1]); // F matrix 1
    _play([l.fShift, l.rcl]); // F user
    _play([l.n2, l.enter, l.n3, l.fShift, l.sin, l.sqrt]); // 2, 3 f DIM A
    for (final n in [l.n1, l.n2, l.n3, l.n4, l.n5, l.n6]) {
      _play([n, l.sto, l.sqrt]); // n f STO A
    }
    expectMatrixVals(mA, [
      [1, 2, 3],
      [4, 5, 6]
    ]);
    _play([l.n2, l.sto, l.n0, l.n3, l.sto, l.n1, l.n9, l.sto, l.sqrt]);
    expectMatrixVals(mA, [
      [1, 2, 3],
      [4, 5, 9]
    ]);
    _play([l.n2, l.enter, l.n1, l.rcl, l.gShift, l.sqrt]);
    expect(model.x, Value.fromDouble(4));
    _play([l.rcl, l.chs, l.sqrt, l.sto, l.chs, l.eX, l.rcl, l.chs, l.eX]);
    _play([l.fShift, l.chs, l.n4]);
    expect(model.x, Value.fromMatrix(1));
    expectMatrixVals(mB, [
      [1, 4],
      [2, 5],
      [3, 9]
    ]);

    // p. 152:
    _play([l.fShift, l.eex, l.eX, l.rcl, l.chs, l.sqrt]); // result B, RCL mat A
    _play([l.n2, l.mult]);
    expect(model.x, Value.fromMatrix(1));
    _play([l.n1, l.minus]);
    expect(model.x, Value.fromMatrix(1));
    expectMatrixVals(mB, [
      [1, 3, 5],
      [7, 9, 17]
    ]);
    _play([l.fShift, l.eex, l.tenX, l.rcl, l.chs, l.eX]); // result C, RCL mat B
    _play([l.rcl, l.fShift, l.chs, l.sqrt, l.plus]); // Matrix add
    expect(model.x, Value.fromMatrix(2));
    expectMatrixVals(mC, [
      [2, 5, 8],
      [11, 14, 26]
    ]);
    _play([l.rcl, l.chs, l.eX]); // RCL mat B
    _play([l.rcl, l.fShift, l.chs, l.sqrt, l.minus]); // matrix subtract
    expect(model.x, Value.fromMatrix(2));
    expectMatrixVals(mC, [
      [0, 1, 2],
      [3, 4, 8]
    ]);

    _play([l.n0, l.enter, l.fShift, l.sin, l.tenX]); // dim(C) = 0,0
    expect(mC.length, 0);
    // Calculate transpose(A) * B using transpose, *
    _play([l.rcl, l.chs, l.sqrt, l.fShift, l.chs, l.n4]); // RCL A, transpose
    expect(model.x, Value.fromMatrix(0));
    _play([l.rcl, l.chs, l.eX, l.fShift, l.eex, l.tenX]); // RCL B, result C
    _play([l.mult]);
    expect(model.x, Value.fromMatrix(2));
    const aTstarB = [
      [29, 39, 73],
      [37, 51, 95],
      [66, 90, 168]
    ];
    expectMatrixVals(mC, aTstarB);
    _play([l.rcl, l.chs, l.sqrt, l.fShift, l.chs, l.n4]); // RCL A, transpose

    _play([l.n0, l.enter, l.fShift, l.sin, l.tenX]); // dim(C) = 0,0
    expect(mC.length, 0);
    // Calculate transpose(A) * B using matrix 5
    _play([l.rcl, l.chs, l.sqrt]); // RCL A
    expect(model.x, Value.fromMatrix(0));
    _play([l.rcl, l.chs, l.eX, l.fShift, l.eex, l.tenX]); // RCL B, result C
    _play([l.fShift, l.chs, l.n5]);
    expect(model.x, Value.fromMatrix(2));
    expectMatrixVals(mC, aTstarB);

    // p. 157:
    _play([l.n2, l.enter, l.fShift, l.sin, l.sqrt, l.fShift, l.chs, l.n1]);
    _play([l.n1, l.sto, l.sqrt, l.sto, l.sqrt]);
    _play([l.dot, l.n2, l.n4, l.sto, l.sqrt]);
    _play([l.dot, l.n8, l.n6, l.sto, l.sqrt]);
    _play([l.n2, l.enter, l.n3, l.fShift, l.sin, l.eX]);
    _play([l.n2, l.n7, l.n4, l.sto, l.eX]);
    _play([l.n2, l.n3, l.n3, l.sto, l.eX]);
    _play([l.n3, l.n3, l.n1, l.sto, l.eX]);
    _play([l.n1, l.n2, l.n0, l.dot, l.n3, l.n2, l.sto, l.eX]);
    _play([l.n1, l.n1, l.n2, l.dot, l.n9, l.n6, l.sto, l.eX]);
    _play([l.n1, l.n5, l.n1, l.dot, l.n3, l.n6, l.sto, l.eX]);
    _play([l.fShift, l.eex, l.yX]);
    _play([l.rcl, l.chs, l.eX, l.rcl, l.chs, l.sqrt]);
    _play([l.div]);
    _play([l.rcl, l.yX]);
    expect(model.x, Value.fromDouble(186));
    _play([l.rcl, l.yX]);
    expect(model.x, Value.fromDouble(141));
    _play([l.rcl, l.yX]);
    expect(model.x, Value.fromDouble(215));
    _play([l.rcl, l.yX]);
    expect(model.x, Value.fromDouble(88));
    _play([l.rcl, l.yX]);
    expect(model.x, Value.fromDouble(92));
    _play([l.rcl, l.yX]);
    expect(model.x, Value.fromDouble(116));

    // Residual, from advanced functions page 101
    mA.resize(model, 3, 3);
    final residO = [
      [33, 16, 72],
      [-24, -10, -57],
      [-8, -4, -17]
    ];
    mA.visit((r, c) => mA.setF(r, c, residO[r][c].toDouble()));
    mB.resize(model, 3, 3);
    mB.identity();
    _play([l.rcl, l.chs, l.sqrt, l.sto, l.chs, l.yX]); // RCL m A, STO m D
    expect(model.x, Value.fromMatrix(0));
    _play([l.rcl, l.chs, l.eX, l.rcl, l.chs, l.yX]); // RCL m b, RCL m D
    expect(model.z, Value.fromMatrix(0));
    expect(model.y, Value.fromMatrix(1));
    expect(model.x, Value.fromMatrix(3));
    _play([l.fShift, l.eex, l.tenX]);
    expect(model.z, Value.fromMatrix(0));
    expect(model.y, Value.fromMatrix(1));
    expect(model.x, Value.fromMatrix(3));
    _play([l.div]); // result C, divide
    // print(mC.formatValueWith((v) => v.asDouble.toStringAsFixed(9)));
    expect(model.y, Value.fromMatrix(0));
    expect(model.x, Value.fromMatrix(2));
    expectMatrixVals(
        mC,
        [
          [-9.666666881, -2.666666726, -32.00000071],
          [8.000000167, 2.500000046, 25.50000055],
          [2.666666728, 0.6666666836, 9.000000203]
        ],
        0.000000015);
    _play([l.fShift, l.eex, l.eX]); // result B
    _play([l.fShift, l.chs, l.n6]); // Matrix 6 (residual)
    _play([l.rcl, l.chs, l.yX, l.div]); // RCL mat D, divide
    _play([l.rcl, l.chs, l.tenX, l.plus]); // RCL mat C, plus
    expectMatrixVals(mB, [
      [-9.666666667, -2.666666667, -32],
      [8, 2.5, 25.5],
      [2.666666667, 0.6666666667, 9]
    ]);

    // Complex matrices, page 163:
    _play([l.fShift, l.chs, l.n0, l.n2, l.enter, l.n4]);
    _play([l.fShift, l.sin, l.sqrt, l.fShift, l.chs, l.n1]);
    _play([l.n4, l.sto, l.sqrt]);
    _play([l.n3, l.sto, l.sqrt]);
    _play([l.n7, l.sto, l.sqrt]);
    _play([l.n2, l.chs, l.sto, l.sqrt]);
    _play([l.n1, l.sto, l.sqrt]);
    _play([l.n5, l.sto, l.sqrt]);
    _play([l.n3, l.sto, l.sqrt]);
    _play([l.n8, l.sto, l.sqrt]);
    _play([l.rcl, l.chs, l.sqrt]);
    _play([l.fShift, l.plus]); // Py,x
    expectMatrixVals(mA, [
      [4, 7],
      [1, 3],
      [3, -2],
      [5, 8]
    ]);
    _play([l.gShift, l.plus]); // Cy,x
    expectMatrixVals(mA, [
      [4, 3, 7, -2],
      [1, 5, 3, 8]
    ]);
    _play([l.fShift, l.plus]); // Py,x
    expectMatrixVals(mA, [
      [4, 7],
      [1, 3],
      [3, -2],
      [5, 8]
    ]);

    // Page 165:
    _play([l.rcl, l.chs, l.sqrt, l.fShift, l.chs, l.n2]); // RCL A, -> Ztilde
    _play([l.fShift, l.eex, l.eX, l.fShift, l.reciprocal]);
    expect(model.x, Value.fromMatrix(1));
    _play([l.fShift, l.chs, l.n3]);
    expectMatrixVals(
        mB,
        [
          [-0.02541436465, 0.2419889503],
          [-0.01215469613, -0.1016574586],
          [-0.2828729282, -0.002209944705],
          [0.1690607735, -0.1314917127]
        ],
        1.5e-10);

    // page 167:
    _play([l.rcl, l.chs, l.sqrt, l.rcl, l.chs, l.eX]);
    _play([l.fShift, l.eex, l.tenX, l.mult]);
    expectMatrixVals(
        mC,
        [
          [1, -2.85e-10],
          [4e-11, 1],
          [1e-11, 3.8e-10],
          [1e-11, -1.05e-10]
        ],
        1.5e-9);

    // page 170:
    _play([l.fShift, l.chs, l.n0, l.fShift, l.chs, l.n1]);
    _play([l.n4, l.enter, l.n2, l.fShift, l.sin, l.sqrt]);
    _play([l.n1, l.n0, l.sto, l.sqrt]);
    _play([l.n0, l.sto, l.sqrt, l.sto, l.sqrt, l.sto, l.sqrt]);
    _play([l.n2, l.n0, l.n0, l.sto, l.sqrt]);
    _play([l.chs, l.sto, l.sqrt, l.sto, l.sqrt]);
    _play([l.n1, l.n7, l.n0, l.sto, l.sqrt]);
    _play([l.n4, l.enter, l.n1, l.fShift, l.sin, l.eX]);
    _play([l.n0, l.sto, l.chs, l.eX]);
    _play([l.n5, l.enter, l.n1, l.enter, l.sto, l.gShift, l.eX]);
    expect(model.memory.registers[0], Value.fromDouble(1));
    expect(model.memory.registers[1], Value.fromDouble(1));
    _play([l.rcl, l.chs, l.eX, l.rcl, l.chs, l.sqrt]);
    expect(model.y, Value.fromMatrix(1));
    expect(model.x, Value.fromMatrix(0));
    _play([l.fShift, l.chs, l.n2, l.fShift, l.eex, l.tenX, l.div]);
    expect(model.x, Value.fromMatrix(2));
    _play([l.gShift, l.plus]);
    expectMatrixVals(
        mC,
        [
          [0.03715608128, 0.1311391104],
          [0.04371303680, 0.1542813064]
        ],
        1.5e-10);

    void testMatrixAccess(List<CalculatorButton> op, double val, double r,
        [double? xr]) {
      void forMatrix(CalculatorButton matButton, Matrix mat) {
        model.userMode = false;
        mat.resize(model, 2, 3);
        model.memory.registers[0] = Value.fromDouble(2);
        model.memory.registers[1] = Value.fromDouble(3);
        mat.setF(1, 2, val);
        _play(op);
        controller.buttonWidgetDown(matButton);
        controller.buttonUp();
        expect(mat.get(1, 2), Value.fromDouble(r));
        if (xr != null) {
          expect(model.x, Value.fromDouble(xr));
        }
        mat.resize(model, 0, 0);
      }

      final x = model.x;
      forMatrix(l.tenX, mC); // C
      model.x = x;
      model.memory.registers.index = Value.fromMatrix(1);
      forMatrix(l.cos, mB); // (i)
    }

    model.xF = 1.2;
    testMatrixAccess([l.sto, l.plus], 40.8, 42);
    testMatrixAccess([l.sto, l.minus], 43.2, 42);
    testMatrixAccess([l.sto, l.mult], 100, 120);
    testMatrixAccess([l.sto, l.div], 120, 100);
    testMatrixAccess([l.fShift, l.n4], 100, 1.2); // swap
    testMatrixAccess([l.fShift, l.n4], -3.00104, 100); // swap
    expect(model.x, Value.fromDouble(-3.00104));
    testMatrixAccess([l.fShift, l.n6], -7.00402, -5.00402); // isg
    testMatrixAccess([l.fShift, l.n5], 1.00204, -3.00204); // dse
    model.xF = 1.2;
    testMatrixAccess([l.rcl, l.plus], 40.8, 40.8, 42);
    model.xF = 1.2;
    testMatrixAccess([l.rcl, l.minus], 43.2, 43.2, -42);
    model.xF = 1.2;
    testMatrixAccess([l.rcl, l.mult], 42, 42, 50.4);
    model.xF = -50.4;
    testMatrixAccess([l.rcl, l.div], -1.2, -1.2, 42);

    // Conditional tests on matrix descriptors, p. 174
    _play([l.gShift, l.rs, l.fShift, l.rdown, l.fShift, l.sst, l.sqrt]);
    // Program mode, clear program, label A
    _play([l.rcl, l.chs, l.reciprocal, l.gShift, l.mult]); // E = 0
    _play([l.n2, l.n1, l.sto, l.n0]); // (skip 2)1 sto 0
    _play([l.rcl, l.chs, l.reciprocal, l.gShift, l.minus, l.n0]); // E != 0
    _play([l.n4, l.n2, l.sto, l.plus, l.n0]); // (4)2 sto + 0
    _play([l.rcl, l.chs, l.reciprocal, l.enter, l.gShift, l.minus, l.n5]);
    // E = E
    _play([l.n5, l.n5, l.sto, l.plus, l.n0]); // (5)5 sto + 0
    _play([l.rcl, l.chs, l.reciprocal, l.rcl, l.chs, l.yX]);
    _play([l.gShift, l.minus, l.n5]); // E = D
    _play([l.n2, l.n1, l.sto, l.n1]); // (skip 2)1 sto 1
    _play([l.rcl, l.chs, l.reciprocal, l.n0, l.gShift, l.minus, l.n6]);
    // E != 0
    _play([l.n4, l.n2, l.sto, l.plus, l.n1]); // (4)2 sto + 1
    _play([l.rcl, l.n0, l.rcl, l.n1]);
    _play([l.gShift, l.rs]); // P/R
    _play([l.gsb, l.sqrt]); // GSB A
    expect(await out.moveNext(), true);
    expect(out.current, ProgramEvent.done);
    expect(model.yF, 98);
    expect(model.xF, 43);

    // Matrix stack operations, p. 174-175
    model.userMode = true;
    _play([l.fShift, l.chs, l.n0]); // F matrix 0
    // Dim A and B to 2x2, and store 1 2 3 4 in A, 5 6 7 8 in B
    _play([l.n2, l.enter, l.fShift, l.sin, l.sqrt, l.fShift, l.sin, l.eX]);
    _play([l.fShift, l.chs, l.n1]);
    _play([l.n1, l.sto, l.sqrt]);
    _play([l.n2, l.sto, l.sqrt]);
    _play([l.n3, l.sto, l.sqrt]);
    _play([l.n4, l.sto, l.sqrt]);
    _play([l.n5, l.sto, l.eX]);
    _play([l.n6, l.sto, l.eX]);
    _play([l.n7, l.sto, l.eX]);
    _play([l.n8, l.sto, l.eX]);
    _play([l.fShift, l.eex, l.tenX]); // Result C
    _play([l.n6, l.enter, l.n5, l.enter, l.n4, l.enter]);
    _play([l.rcl, l.chs, l.sqrt]); // rcl matrix a
    _play([l.fShift, l.reciprocal]);
    expect(model.x, Value.fromMatrix(2));
    expect(model.y, Value.fromDouble(4));
    expect(model.z, Value.fromDouble(5));
    expect(model.getStackByIndex(3), Value.fromDouble(6));
    expect(model.lastX, Value.fromMatrix(0));

    _play([l.n6, l.enter, l.n5, l.enter, l.n4, l.enter]);
    _play([l.rcl, l.chs, l.eX, l.rcl, l.chs, l.sqrt]); // rcl matrix a, b
    _play([l.mult]);
    expect(model.x, Value.fromMatrix(2));
    expect(model.y, Value.fromDouble(4));
    expect(model.z, Value.fromDouble(5));
    expect(model.getStackByIndex(3), Value.fromDouble(5));
    expect(model.lastX, Value.fromMatrix(0));

    // p. 176
    model.lastX = Value.fromDouble(1234);
    _play([l.n4, l.enter, l.n4, l.n2, l.enter, l.n1, l.enter, l.n2]);
    _play([l.sto, l.gShift, l.sqrt]);
    expect(model.x, Value.fromDouble(42));
    expect(model.y, Value.fromDouble(4));
    expect(model.z, Value.fromDouble(4));
    expect(model.getStackByIndex(3), Value.fromDouble(4));
    expect(model.lastX, Value.fromDouble(1234));

    _play([l.n5, l.enter, l.n4, l.enter, l.n1, l.enter, l.n2]);
    _play([l.rcl, l.gShift, l.sqrt]);
    expect(model.x, Value.fromDouble(42));
    expect(model.y, Value.fromDouble(4));
    expect(model.z, Value.fromDouble(5));
    expect(model.getStackByIndex(3), Value.fromDouble(5));
    expect(model.lastX, Value.fromDouble(1234));

    // p. 177
    model.userMode = true;
    _play([l.fShift, l.chs, l.n1]); // Matrix 1
    _play([l.rcl, l.chs, l.yX, l.sto, l.tan]); // Store "D" to I
    _play([l.n2, l.enter, l.fShift, l.sin, l.tan]); // dim D to 2x2
    // That tested f-DIM-I
    for (final n in [l.n3, l.n5, l.n7, l.n2]) {
      _play([n, l.sto, l.yX]); // sto D
    }
    model.userMode = false;
    _play([l.gShift, l.rs, l.fShift, l.rdown, l.fShift, l.sst, l.sqrt]);
    // Program mode, clear program, label A
    _play([l.fShift, l.chs, l.n1]); // Matrix 1
    _play([l.fShift, l.sst, l.n4]); // label 4
    _play([l.rcl, l.yX, l.gShift, l.sqrt]); // rcl D, x^2
    _play([l.fShift, l.rcl]); // toggle user mode
    _play([l.sto, l.yX]); // sto D
    _play([l.fShift, l.rcl]); // toggle user mode
    _play([l.gto, l.n4]);
    _play([l.gShift, l.rs]); // P/R
    expectMatrixVals(mD, [
      [3, 5],
      [7, 2]
    ]);
    _play([l.gsb, l.sqrt]); // GSB A
    expect(await out.moveNext(), true);
    expect(out.current, ProgramEvent.done);
    expectMatrixVals(mD, [
      [3 * 3, 5 * 5],
      [7 * 7, 2 * 2]
    ]);
    // Check that row-norm and Frobenius norm act as conditional branch
    for (final asProgram in [true, false]) {
      for (final test in [l.n7, l.n8]) {
        for (final mat in [true, false]) {
          if (asProgram) {
            _play([l.gShift, l.rs, l.fShift, l.rdown, l.fShift, l.sst, l.sqrt]);
          } else {
            model.program.currentLine = 3; // A known value
          }
          if (mat) {
            _play([l.rcl, l.chs, l.yX]); // rcl matrix D
          } else {
            _play([l.n7]);
          }
          _play([l.fShift, l.chs, test]); // f matrix test
          _play([l.n4, l.n2, l.enter]);
          if (asProgram) {
            _play([l.gShift, l.rs]); // P/R
            _play([l.gsb, l.sqrt]); // GSB A
            expect(await out.moveNext(), true);
            expect(out.current, ProgramEvent.done);
            if (mat) {
              expect(model.xF, 42); // skip
            } else {
              expect(model.xF, 2); // skip
            }
          } else {
            expect(model.xF, 42); // no skip
            expect(model.program.currentLine, 3);
          }
        }
      }
    }

    setMatrix(model, mD, [
      [1, 2.7, -3],
      [5, 24, 0.33]
    ]);
    _play([l.rcl, l.chs, l.yX]);
    expect(model.x, Value.fromMatrix(3));
    _play([l.chs]); // rcl mat D, chs
    expect(model.x, Value.fromMatrix(3));
    expectMatrixVals(mD, [
      [-1, -2.7, 3],
      [-5, -24, -0.33]
    ]);

    setMatrix(model, mD, [
      [1, 2.7, -3],
      [5, 24, 0.33],
      [-31, 3.14, -6.22]
    ]);
    _play([l.rcl, l.chs, l.yX, l.fShift, l.chs, l.n7]); // mat 7 on D
    expect(model.xF, 40.36);
    _play([l.rcl, l.chs, l.yX, l.fShift, l.chs, l.n8]); // mat 8 on D
    expect(model.xF, 40.34782398);
    _play([l.rcl, l.chs, l.yX, l.fShift, l.chs, l.n9]); // mat 9 on D
    expect(model.xF, -2373.067200);

    // p. 178, misc. matrix addressing:
    setMatrix(model, mD, [
      [1, 2.7, -3],
      [5, 24, 0.33],
      [-31, 3.14, -6.22]
    ]);
    setMatrix(model, mC, [
      [19, 20.7, -73],
      [19, 27, 2.33],
      [-310, 0.314, -6.22222],
      [22.1, 22.2, 22.3]
    ]);
    _play([l.rcl, l.chs, l.tenX, l.sto, l.tan]); // I := mC
    _play([l.n2, l.sto, l.n0, l.n3, l.sto, l.n1]); // r = 2, c = 3
    _play([l.n0, l.enter, l.enter, l.enter]);
    _play([l.rcl, l.cos]); // rcl (i), that is, C
    expect(model.xF, 2.33);
    _play([l.rcl, l.tenX]); // rcl C
    expect(model.xF, 2.33);
    _play([l.rcl, l.yX]); // rcl D
    expect(model.xF, 0.33);
    _play([l.n0, l.enter, l.enter, l.enter]);
    _play([l.n7, l.enter, l.n3, l.enter, l.n1]); // z = 7, y/r = 3, x/c = 1
    _play([l.rcl, l.gShift, l.cos]); // rcl g (i), that is, C
    expect(model.xF, -310);
    expect(model.yF, 7);
    _play([l.n0, l.enter, l.enter, l.enter]);
    _play([l.n7, l.enter, l.n3, l.enter, l.n1]); // z = 7, y/r = 3, x/c = 1
    _play([l.rcl, l.gShift, l.tenX]); // rcl g C
    expect(model.xF, -310);
    expect(model.yF, 7);
    _play([l.n0, l.enter, l.enter, l.enter]);
    _play([l.n7, l.enter, l.n3, l.enter, l.n1]); // z = 7, y/r = 3, x/c = 1
    _play([l.rcl, l.gShift, l.yX]); // rcl g D
    expect(model.xF, -31);
    expect(model.yF, 7);

    _play([l.n0, l.enter, l.enter, l.enter]);
    _play([l.rcl, l.sin, l.yX]); // rcl dim D
    expect(model.xF, 3);
    expect(model.yF, 3);
    _play([l.n0, l.enter, l.enter, l.enter]);
    _play([l.rcl, l.sin, l.tan]); // rcl dim I, that is, C
    expect(model.xF, 3);
    expect(model.yF, 4);

    _play([l.rcl, l.chs, l.eX, l.sto, l.eex]); // rcl mat B, sto result
    _play([l.n0, l.enter, l.enter, l.enter]);
    _play([l.rcl, l.eex]); // rcl result
    expect(model.x, Value.fromMatrix(1));
    _play([l.fShift, l.eex, l.yX]); // f result D
    _play([l.rcl, l.eex]); // rcl result
    expect(model.x, Value.fromMatrix(3));

    model.userMode = false;
    setMatrix(model, mD, [
      [1.1, 2.2]
    ]);
    _play([l.rcl, l.chs, l.yX, l.sto, l.tan]); // I := D
    _play([l.fShift, l.chs, l.n1]); // F matrix 1
    _play([l.n3, l.sto, l.yX]);
    expectMatrixVals(mD, [
      [3, 2.2]
    ]);
    _play([l.fShift, l.rcl]); // toggle user mode
    _play([l.n4, l.sto, l.cos]);
    _play([l.n5, l.sto, l.yX, l.n6, l.sto, l.cos]);
    expectMatrixVals(mD, [
      [6, 5]
    ]);
    _play([l.fShift, l.rcl]); // toggle user (to off)
    setMatrix(model, mD, [
      [1.1, 2.2],
      [3.1, 4.2],
      [5.1, 6.2]
    ]);
    _play([l.n1, l.enter, l.n3, l.enter, l.n2, l.sto, l.gShift, l.yX]);
    expectMatrixVals(mD, [
      [1.1, 2.2],
      [3.1, 4.2],
      [5.1, 1]
    ]);
    _play([l.n2, l.chs, l.enter, l.n2, l.enter, l.n1, l.sto, l.gShift, l.cos]);
    expectMatrixVals(mD, [
      [1.1, 2.2],
      [-2, 4.2],
      [5.1, 1]
    ]);

    _play([l.rcl, l.chs, l.yX, l.sto, l.chs, l.sqrt]); // A := D
    expectMatrixVals(mA, [
      [1.1, 2.2],
      [-2, 4.2],
      [5.1, 1]
    ]);
    _play([l.n9, l.chs, l.sto, l.chs, l.sqrt]); // A := 9
    expectMatrixVals(mA, [
      [-9, -9],
      [-9, -9],
      [-9, -9]
    ]);

    // @@ TODO:  Up through end of p. 178
    final testOpAndResults = [
      [
        l.plus,
        [
          [8.2, 10.4],
          [9.2, 13.4]
        ],
        [
          [-36.8, -35.7],
          [-34.8, -33.7]
        ]
      ],
      [
        l.minus,
        [
          [-6, -6],
          [-3, -5]
        ],
        [
          [39, 40.1],
          [41, 42.1]
        ],
        [
          [-39, -40.1],
          [-41, -42.1]
        ]
      ],
      [
        l.mult,
        [
          [21.23, 29.26],
          [47.63, 64.06]
        ],
        [
          [-41.69, -83.38],
          [-117.49, -159.18]
        ]
      ],
      [
        l.div,
        [
          [-1, -0.9281045754],
          [1, 1.071895425]
        ],
        [
          [-0.02902374670, -0.05804749340],
          [-0.08179419525, -0.1108179420]
        ],
        [
          [72.35454545, -37.9],
          [-53.40454545, 18.95]
        ]
      ]
    ];
    // Test +, -, *, and / on matrices and scalars
    _play([l.fShift, l.eex, l.tenX]); // f result C
    for (final tor in testOpAndResults) {
      for (var i = 0; i < 3; i++) {
        setMatrix(model, mA, [
          [1.1, 2.2],
          [3.1, 4.2],
        ]);
        _play([l.rcl, l.chs, l.sqrt]); // rcl matrix A
        if (i == 0) {
          setMatrix(model, mB, [
            [7.1, 8.2],
            [6.1, 9.2],
          ]);
          _play([l.rcl, l.chs, l.eX]); // rcl matrix B
          _play([tor[0] as CalculatorButton]);
          expectMatrixVals(mC, tor[1] as List<List<num>>);
        } else {
          _play([l.n3, l.n7, l.dot, l.n9, l.chs]); // -37.9
          if (i == 2) {
            _play([l.xy]);
          }
          _play([tor[0] as CalculatorButton]);
          if (tor.length == 3) {
            // Same result x<-->y or no
            expectMatrixVals(mC, tor[2] as List<List<num>>);
          } else {
            expectMatrixVals(mC, tor[i + 1] as List<List<num>>);
          }
        }
      }
    }

    model.userMode = false;
    _play([l.fShift, l.chs, l.n0]); // F matrix 0
  }

  Future<void> runWithComplex(bool complex) async {
    model.isComplexMode = complex;
    await _ch12();
    // print("listing:  ${JsonEncoder.withIndent('  ').convert(model.memory.toJson(comments: true))}");
    _page146();
    _stoMatrixAndChs();
    _invertMatrix(true);
    _invertMatrix(false);
    _singularMatrix();
    _transpose();
    _complexMatrix();
    _misc();
    // Operations15.div is tested at the end of the ch. 12 tests.
    // scalar div matrix doesn't behave like _testScalar is built to handle.
    _testScalar(Operations15.mult, (x, y) => y * x);
    _testScalar(Operations15.plus, (x, y) => y + x);
    _testScalar(Operations15.minus, (x, y) => y - x);
    model.isComplexMode = false;
  }

  Future<void> run() async {
    await _page139(asProgram: false);
    await _page139(asProgram: true);
    await runWithComplex(false);
    await runWithComplex(true);
  }

  void expectMatrix(AMatrix m, AMatrix expected, [double epsilon = 0]) {
    expect(m.rows, expected.rows);
    expect(m.columns, expected.columns);
    m.visit((r, c) {
      bool bad = false;
      if (epsilon == 0) {
        if (m.get(r, c) != expected.get(r, c)) {
          bad = true;
        }
      } else if ((m.getF(r, c) - expected.getF(r, c)).abs() > epsilon) {
        print('Value differs by ${(m.getF(r, c) - expected.getF(r, c)).abs()}');
        print('    This is more than tolerance of $epsilon');
        print('Expected: $expected');
        bad = true;
      }
      if (bad) {
        print('Matrix value ($r,$c) bad.  Matrix:  $m');
        print('Expected:  $expected');
        expect(bad, false);
      }
    });
  }

  void expectMatrixVals(AMatrix m, List<List<num>> expected,
      [final double epsilon = 0]) {
    expect(m.rows, expected.length);
    for (int r = 0; r < expected.length; r++) {
      final row = expected[r];
      expect(m.columns, row.length);
      for (int c = 0; c < row.length; c++) {
        bool bad = false;
        if (epsilon == 0) {
          if (m.get(r, c) != Value.fromDouble(row[c].toDouble())) {
            print('${m.get(r, c)} != ${Value.fromDouble(row[c].toDouble())}');
            bad = true;
          }
        } else if ((m.getF(r, c) - row[c]).abs() > epsilon) {
          print('Value differs by ${(m.getF(r, c) - row[c]).abs()}');
          print('    This is more than tolerance of $epsilon');
          // print(m.getF(r, c).toStringAsFixed(10));
          // print(row[c].toStringAsFixed(10));
          bad = true;
        }
        if (bad) {
          print('Matrix value ($r,$c) bad.  Matrix:  $m');
          print('Expected:  $expected');
          expect(bad, false);
        }
      }
    }
  }

  void setMatrix(Model15 model, Matrix m, List<List<num>> val) {
    if (val.length == 0) {
      m.resize(model, 0, 0);
    } else {
      m.resize(model, val.length, val[0].length);
    }
    m.visit((r, c) => m.setF(r, c, val[r][c].toDouble()));
  }
}

void printListing(Model model) {
  final j = model.toJson(comments: true);
  final pl = (j['memory'] as Map)['commentProgramListing'] as List;
  debugPrint('');
  for (final line in pl) {
    debugPrint(line.toString());
  }
  debugPrint('');
}

String formatDouble(double v, int digits) {
  String r = v.toStringAsFixed(digits);
  if (r.startsWith('-')) {
    double d = double.parse(r);
    if (d == 0) {
      r = 0.toStringAsFixed(digits);
    }
  }
  return r;
}
