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

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jrpn/c/operations.dart';
import 'package:jrpn/m/model.dart';

import 'package:jrpn/v/main_screen.dart';
import 'package:jrpn15c/main15c.dart';
import 'package:jrpn15c/model15c.dart';
import 'package:jrpn15c/tests15c.dart';
import 'hyperbolic.dart';

Future<void> main() async {
  runStaticInitialization15();

  // Note that passing Jrpn into testWidgets actually tests very little, because
  // the deferred initialization doesn't happen.  I think it stalls on a plugin
  // waiting for the system, maybe related to receiving links.  Anyway, we
  // don't do it here.

  testWidgets('15C Buttons', (WidgetTester tester) async {
    final controller = Controller15(createModel15());
    final ScreenPositioner positioner = ScreenPositioner(12.7, 8);
    await tester.pumpWidget(Builder(builder: (BuildContext context) {
      final factory = LandscapeButtonFactory15(context, positioner, controller);
      final layout = ButtonLayout15(factory, 10, 0.1);

      TrigInputTests(controller, layout).run();
      MiscTests(controller, layout).run();

      return Container(); // placeholder
    }));
    // Avoid pending timers error:
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
  });

  test('Built-in self tests 15C', () async {
    await SelfTests15(inCalculator: false).runAll();
  });
}

class MiscTests {
  final Controller15 controller;
  final ButtonLayout15 layout;
  final Model15 model;

  MiscTests(this.controller, this.layout) : model = controller.model as Model15;

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
