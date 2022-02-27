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
import 'package:jrpn15c/model15c.dart';
import 'package:jrpn15c/tests15c.dart';
import 'hyperbolic.dart';
import 'programs.dart';

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
      printListing(model);
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

  Future<void> run() async {
    await _page139(asProgram: false);
    await _page139(asProgram: true);
  }
}

void printListing(Model model) {
  final j = model.toJson(comments: true);
  final pl = (j['memory'] as Map)['commentProgramListing'] as List;
  print('');
  for (final line in pl) {
    print(line);
  }
  print('');
}
