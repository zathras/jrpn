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

import 'package:jrpn/v/main_screen.dart';
import 'package:jrpn15c/main15c.dart';
import 'package:jrpn15c/tests15c.dart';
import 'hyperbolic.dart';

Future<void> main() async {
  // Note that passing Jrpn into testWidgets actually tests very little, because
  // the deferred initialization doesn't happen.  I think it stalls on a plugin
  // waiting for the system, maybe related to receiving links.

  testWidgets('15C Buttons', (WidgetTester tester) async {
    final controller = Controller15(createModel15());
    final ScreenPositioner positioner = ScreenPositioner(12.7, 8);
    await tester.pumpWidget(Builder(builder: (BuildContext context) {
      final factory = LandscapeButtonFactory15(context, positioner, controller);
      final layout = ButtonLayout15(factory, 10, 0.1);

      TrigInputTests(controller, layout).run();

      return Container(); // placeholder
    }));
    // Avoid pending timers error:
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
  });

  test('Built-in self tests 15C', () async {
    await SelfTests15(inCalculator: false).runAll();
  });
}
