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

import 'package:jrpn/c/operations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jrpn/c/controller.dart';
import 'package:jrpn/m/model.dart';

import 'package:jrpn/generic_main.dart';
import 'package:jrpn16c/main16c.dart';
import 'package:jrpn16c/tests16c.dart';
import 'programs.dart';



Future<void> main() async {
  testWidgets('Self tests', (WidgetTester tester) async {
    await tester.pumpWidget(Jrpn(Controller16(Model16())));
  });

  test('p79 program', p79Program);
  test('p93 checksum program', p93Checksum);
  test('stack lift', testStackLift);
  test('registers and word size', testRegistersAndWordSize);
  test('program with error', programWithError);
  test('last x', lastX);
  test('no scroll reset', noScrollReset);
  appendixA();
  test('Towers of Hanoi', towersOfHanoi);
  // Do this last, because it leaves a timer pending:
  test('Built-in self tests', () async {
    await SelfTests16(inCalculator: false).runAll();
  });
}

void enter(Controller c, Operation key) {
  c.buttonDown(key);
  c.buttonUp();
}

Future<void> noScrollReset() async {
  // p. 100
  final ops = [
    Operations.minus,
    Operations.plus,
    Operations.mult,
    Operations.div,
    Operations.rmd,
    Operations.dblx,
    Operations.dblDiv,
    Operations.dblr,
    Operations.xor,
    Operations.not,
    Operations.or,
    Operations.and,
    Operations.abs,
    Operations.sqrtOp,
    Operations.wSize,
    Operations.lj,
    Operations.asr,
    Operations.rl,
    Operations.rr,
    Operations.rlcn,
    Operations.rrcn,
    Operations.maskl,
    Operations.maskr,
    Operations.sb,
    Operations.cb,
    Operations.bQuestion,
    Operations.rlcn,
    Operations.rrn,
    Operations.poundB,
    Operations.chs
  ];
  final fops = [
    Operations.minus,
    Operations.plus,
    Operations.mult,
    Operations.div,
    Operations.reciprocal,
    Operations.abs,
    Operations.sqrtOp,
  ];
  final Value four = Value.fromInternal(BigInt.parse('4'));
  for (final Operation op in ops) {
    final m = Model16();
    final c = Controller16(m);

    enter(c, Operations.n3);
    enter(c, Operations.enter);
    enter(c, Operations.n2);
    enter(c, Operations.enter);
    enter(c, Operations.n1);
    enter(c, Operations.enter);
    enter(c, Operations.n4);
    expect(m.lastX, Value.zero);
    enter(c, op);
    expect(m.lastX, four, reason: 'lastx for ${op.name}');
  }
  for (final Operation op in fops) {
    final m = Model16();
    final c = Controller16(m);

    enter(c, Operations.floatKey);
    enter(c, Operations.n2);
    enter(c, Operations.n3);
    enter(c, Operations.enter);
    enter(c, Operations.n2);
    enter(c, Operations.enter);
    enter(c, Operations.n1);
    enter(c, Operations.enter);
    enter(c, Operations.n4);
    expect(m.lastX, Value.zero);
    enter(c, op);
    expect(m.lastX.asDouble, 4.0, reason: 'lastx for float mode ${op.name}');
  }
}

Future<void> lastX() async {
  // p. 100
  final ops = [
    Operations.minus,
    Operations.plus,
    Operations.mult,
    Operations.div,
    Operations.rmd,
    Operations.dblx,
    Operations.dblDiv,
    Operations.dblr,
    Operations.xor,
    Operations.not,
    Operations.or,
    Operations.and,
    Operations.abs,
    Operations.sqrtOp,
    Operations.wSize,
    Operations.lj,
    Operations.asr,
    Operations.rl,
    Operations.rr,
    Operations.rlcn,
    Operations.rrcn,
    Operations.maskl,
    Operations.maskr,
    Operations.sb,
    Operations.cb,
    Operations.bQuestion,
    Operations.rlcn,
    Operations.rrn,
    Operations.poundB,
    Operations.chs
  ];
  final fops = [
    Operations.minus,
    Operations.plus,
    Operations.mult,
    Operations.div,
    Operations.reciprocal,
    Operations.abs,
    Operations.sqrtOp,
  ];
  final Value four = Value.fromInternal(BigInt.parse('4'));
  for (final program in [false, true]) {
    for (final Operation op in ops) {
      final tc = TestCalculator();
      final c = tc.controller;
      final m = tc.model;
      if (program) {
        enter(c, Operations.pr);
      }
      enter(c, Operations.n3);
      enter(c, Operations.enter);
      enter(c, Operations.n2);
      enter(c, Operations.enter);
      enter(c, Operations.n1);
      enter(c, Operations.enter);
      enter(c, Operations.n4);
      expect(m.lastX, Value.zero);
      enter(c, op);
      if (program) {
        final out = StreamIterator<ProgramEvent>(tc.output.stream);
        enter(c, Operations.rtn); // An extra one in case of branching instr.
        enter(c, Operations.pr);
        enter(c, Operations.rs);
        expect(await out.moveNext(), true);
        expect(out.current, ProgramEvent.done);
      }
      expect(m.lastX, four, reason: 'lastx for ${op.name}');
    }
    for (final Operation op in fops) {
      final tc = TestCalculator();
      final m = tc.model;
      final c = tc.controller;
      if (program) {
        enter(c, Operations.pr);
      }

      enter(c, Operations.floatKey);
      enter(c, Operations.n2);
      enter(c, Operations.n3);
      enter(c, Operations.enter);
      enter(c, Operations.n2);
      enter(c, Operations.enter);
      enter(c, Operations.n1);
      enter(c, Operations.enter);
      enter(c, Operations.n4);
      if (!program) {
        expect(m.lastX, Value.zero);
      }
      if (program) {
        final out = StreamIterator<ProgramEvent>(tc.output.stream);
        enter(c, Operations.rtn); // An extra one in case of branching instr.
        enter(c, Operations.pr);
        enter(c, Operations.rs);
        expect(await out.moveNext(), true);
        expect(out.current, ProgramEvent.done);
      }
      enter(c, op);
      expect(m.lastX.asDouble, 4.0, reason: 'lastx for float mode ${op.name}');
    }
  }
}

Future<void> programWithError() async {
  final tc = TestCalculator();
  final m = tc.model;
  final c = tc.controller;
  var out = StreamIterator<ProgramEvent>(tc.output.stream);

  enter(c, Operations.pr);
  enter(c, Operations.lbl);
  enter(c, Operations.letterA);
  enter(c, Operations.floatKey);
  enter(c, Operations.n2);
  enter(c, Operations.n0);
  enter(c, Operations.reciprocal);
  enter(c, Operations.pr);
  enter(c, Operations.gsb);
  enter(c, Operations.letterA);
  await out.moveNext();
  expect(out.current.errorNumber, 0);
  expect(m.display.current, '   error 0  ');

  enter(c, Operations.clearPrefix); // Clear error display
  enter(c, Operations.pr); // Program mode
  enter(c, Operations.clearPrgm);
  enter(c, Operations.lbl);
  enter(c, Operations.letterA);
  enter(c, Operations.n1);
  enter(c, Operations.plus);
  enter(c, Operations.gsb);
  enter(c, Operations.letterA);
  enter(c, Operations.pr);
  enter(c, Operations.n0);
  enter(c, Operations.enter);
  enter(c, Operations.enter);
  enter(c, Operations.enter);
  enter(c, Operations.gsb);
  enter(c, Operations.letterA);
  expect(await out.moveNext(), true);
  expect(out.current.errorNumber, 5);
  expect(m.display.current, '   error 5  ');
  enter(c, Operations.letterA);
  expect(m.display.current.trim(), '5.00');
}

Future<void> testRegistersAndWordSize() async {
  // p. 67:
  final m = Model16();
  final c = Controller16(m);

  enter(c, Operations.hex);
  enter(c, Operations.n1);
  enter(c, Operations.n0);
  enter(c, Operations.wSize);
  enter(c, Operations.clearReg);
  enter(c, Operations.n1);
  enter(c, Operations.n2);
  enter(c, Operations.n3);
  enter(c, Operations.n4);
  enter(c, Operations.sto);
  enter(c, Operations.n0);
  enter(c, Operations.n5);
  enter(c, Operations.n6);
  enter(c, Operations.n7);
  enter(c, Operations.n8);
  enter(c, Operations.sto);
  enter(c, Operations.n1);
  enter(c, Operations.n2);
  enter(c, Operations.n0);
  enter(c, Operations.wSize);
  enter(c, Operations.rcl);
  enter(c, Operations.n0);
  expect(m.xI, BigInt.parse('56781234', radix: 16));
  enter(c, Operations.rcl);
  enter(c, Operations.n1);
  expect(m.xI, BigInt.parse('0', radix: 16));
  enter(c, Operations.n1);
  enter(c, Operations.n0);
  enter(c, Operations.wSize);
  enter(c, Operations.rcl);
  enter(c, Operations.n0);
  expect(m.xI, BigInt.parse('1234', radix: 16));
  enter(c, Operations.rcl);
  enter(c, Operations.n1);
  expect(m.xI, BigInt.parse('5678', radix: 16));

  // p. 70:
  enter(c, Operations.n0);
  enter(c, Operations.enter);
  enter(c, Operations.enter);
  enter(c, Operations.enter);
  enter(c, Operations.dec);
  enter(c, Operations.n0);
  enter(c, Operations.wSize);
  enter(c, Operations.n3);
  enter(c, Operations.n2);
  enter(c, Operations.n6);
  enter(c, Operations.sto);
  enter(c, Operations.I);
  enter(c, Operations.n4);
  enter(c, Operations.wSize);
  enter(c, Operations.n3);
  enter(c, Operations.sto);
  enter(c, Operations.parenI);
  enter(c, Operations.bsp);
  enter(c, Operations.rcl);
  enter(c, Operations.parenI);
  expect(m.xI, BigInt.parse('3'));
  expect(m.yI, BigInt.parse('6')); // 326 & 15
  expect(m.z, Value.zero); // 326 & 15
}

Future<void> testStackLift() async {
  for (final program in [false, true]) {
    final tc = TestCalculator();
    final m = tc.model;
    final c = tc.controller;

    // p. 67:
    m.displayMode = DisplayMode.float(2);
    if (program) {
      enter(c, Operations.pr);
    }
    enter(c, Operations.n4);
    enter(c, Operations.n2);
    enter(c, Operations.floatKey);
    enter(c, Operations.n0);
    enter(c, Operations.eex);
    enter(c, Operations.n8);
    enter(c, Operations.sto);
    enter(c, Operations.n0);
    if (program) {
      enter(c, Operations.clx);
    } else {
      enter(c, Operations.bsp);
    }
    enter(c, Operations.rcl);
    enter(c, Operations.n0);
    enter(c, Operations.n2);
    enter(c, Operations.mult);
    if (program) {
      final out = StreamIterator<ProgramEvent>(tc.output.stream);
      enter(c, Operations.pr);
      enter(c, Operations.rs);
      expect(await out.moveNext(), true);
      expect(out.current, ProgramEvent.done);
    }
    expect(m.xF, 200000000.0);
    expect(m.yF, 42.0);
    expect(m.z, Value.zero);
  }
}
