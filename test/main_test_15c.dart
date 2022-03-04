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

import 'package:flutter/material.dart';
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

  void _invertMatrix() {
    final Matrix mat2 = model.matrices[4];
    final Matrix mat = model.matrices[3];
    mat2.resize(model, 2, 2);
    mat2.setF(0, 0, 0.1);
    mat2.setF(0, 1, 0.1);
    mat2.setF(1, 0, 0.2);
    mat2.setF(1, 1, 0.4);
    AMatrix mat2c = CopyMatrix(mat2);
    linalg.invert(mat2);
    expect(mat2.getF(0, 0), 20);
    expect(mat2.getF(0, 1), -5);
    expect(mat2.getF(1, 0), -10);
    expect(mat2.getF(1, 1), 5);
    linalg.invert(mat2);
    expect(mat2, mat2c);

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
    linalg.invert(mat2);
    expect(mat2.getF(0, 0), 0);
    expect(mat2.getF(0, 1), 15);
    expect(mat2.getF(0, 2), -20);
    expect(mat2.getF(1, 0), 20);
    expect(mat2.getF(1, 1), -25);
    expect(mat2.getF(1, 2), 30);
    expect(mat2.getF(2, 0), -10);
    expect(mat2.getF(2, 1), 10);
    expect(mat2.getF(2, 2), -10);
    linalg.invert(mat2);
    expectMatrix(mat2, mat2c, 5e-10);

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
    controller.buttonWidgetDown(layout.rcl);
    controller.buttonWidgetDown(layout.chs); // Matrix
    controller.buttonWidgetDown(layout.reciprocal); // E
    controller.buttonWidgetDown(layout.reciprocal); // 1/x
    final result = model.matrices[2];
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
            linalg.invert(mat);
            expectMatrix(mat, mat2, 5e-6);
            linalg.invert(mat);
            expectMatrix(mat, o, 2e-8);
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
        linalg.invert(mat2);
        result.dot(mat, mat2);
        expectMatrix(result, identity, 5e-7);
      }
    }

    mat.resize(model, 0, 0);
    mat2.resize(model, 0, 0);

    /*
    expect(result.get(0,0), Value.fromDouble(499999999));
    expect(result.get(0,1), Value.fromDouble(1000000000));
    expect(result.get(0,2), Value.fromDouble(-500000000.1));
    expect(result.get(1,0), Value.fromDouble(999999999));
    expect(result.get(1,1), Value.fromDouble(-2000000000));
    expect(result.get(1,2), Value.fromDouble(1000000000));
    expect(result.get(2,0), Value.fromDouble(-500000000));
    expect(result.get(2,1), Value.fromDouble(1000000000));
    expect(result.get(2,2), Value.fromDouble(-500000000));
     */
  }

  void expectRounded(double epsilon, Value v, double expected) {
    if ((v.asDouble - expected).abs() > epsilon) {
      expect(false, '$v differs from $expected by more than $epsilon');
    }
  }

  Future<void> run() async {
    await _page139(asProgram: false);
    await _page139(asProgram: true);
    _page146();
    _stoMatrixAndChs();
    _invertMatrix();
  }

  void expectMatrix(AMatrix m, AMatrix expected, double epsilon) {
    expect(m.rows, expected.rows);
    expect(m.columns, expected.columns);
    m.visit((r, c) {
      if ((m.getF(r, c) - expected.getF(r, c)).abs() > epsilon) {
        print(
            'Matrix value $r, $c differs by more than tolerance.  Matrix:  $m');
        print('Expected: $expected');
        expect(false, true);
      }
    });
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
