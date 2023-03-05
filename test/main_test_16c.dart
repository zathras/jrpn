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
import 'package:jrpn16c/main.dart';
import 'package:jrpn16c/tests16c.dart';
import 'opcodes.dart';
import 'programs.dart';

Future<void> main() async {
  runStaticInitialization16();
  testWidgets('16C Buttons', (WidgetTester tester) async {
    await tester.pumpWidget(Jrpn(Controller16(Model16())));
  });
  test('programEntry', programEntry);
  test('p79 program', p79Program);
  test('p93 checksum program', p93Checksum);
  test('stack lift', testStackLift);
  test('registers and word size', testRegistersAndWordSize);
  test('program with error', programWithError);
  test('digit entry, R/S, SST', digitEntry);
  test('last x', lastX);
  test('no scroll reset', noScrollReset);
  test('JSON format / opcodes', opcodeTest16C);
  test('negative gosub', testNegativeGosub);
  test('float stack lift', testFloatStackLift);
  test('bug 21', testBug21);
  appendixA();
  test('Towers of Hanoi', towersOfHanoi);
  // Do this last, because it leaves a timer pending:
  test('Built-in self tests 16C', () async {
    await SelfTests16(inCalculator: false).runAll();
  });
}

void enter(Controller c, Operation key) {
  c.buttonDown(key);
  c.buttonUp();
}

Future<void> noScrollReset() async {
  // p. 100
  final ops = <Operation>[
    Operations16.minus,
    Operations16.plus,
    Operations16.mult,
    Operations16.div,
    Operations16.rmd,
    Operations16.dblx,
    Operations16.dblDiv,
    Operations16.dblr,
    Operations16.xor,
    Operations16.not,
    Operations16.or,
    Operations16.and,
    Operations.abs,
    Operations.sqrtOp,
    Operations16.wSize,
    Operations16.lj,
    Operations16.asr,
    Operations16.rl,
    Operations16.rr,
    Operations16.rlcn,
    Operations16.rrcn,
    Operations16.maskl,
    Operations16.maskr,
    Operations16.sb,
    Operations16.cb,
    Operations16.bQuestion,
    Operations16.rlcn,
    Operations16.rrn,
    Operations16.poundB,
    Operations.chs
  ];
  final fops = [
    Operations16.minus,
    Operations16.plus,
    Operations16.mult,
    Operations16.div,
    Operations16.reciprocal,
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

    enter(c, Operations16.floatKey);
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
  final ops = <Operation>[
    Operations16.minus,
    Operations16.plus,
    Operations16.mult,
    Operations16.div,
    Operations16.rmd,
    Operations16.dblx,
    Operations16.dblDiv,
    Operations16.dblr,
    Operations16.xor,
    Operations16.not,
    Operations16.or,
    Operations16.and,
    Operations.abs,
    Operations.sqrtOp,
    Operations16.wSize,
    Operations16.lj,
    Operations16.asr,
    Operations16.rl,
    Operations16.rr,
    Operations16.rlcn,
    Operations16.rrcn,
    Operations16.maskl,
    Operations16.maskr,
    Operations16.sb,
    Operations16.cb,
    Operations16.bQuestion,
    Operations16.rlcn,
    Operations16.rrn,
    Operations16.poundB,
    Operations.chs
  ];
  final fops = [
    Operations16.minus,
    Operations16.plus,
    Operations16.mult,
    Operations16.div,
    Operations16.reciprocal,
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
        enter(c, Operations.clearPrgm); // Set line 0
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

      enter(c, Operations16.floatKey);
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
        enter(c, Operations.sst); // Move to line 0
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

Future<void> digitEntry() async {
  final tc = TestCalculator();
  final m = tc.model;
  final c = tc.controller;
  final out = StreamIterator<ProgramEvent>(tc.output.stream);

  enter(c, Operations.pr);
  enter(c, Operations.n1);
  enter(c, Operations.n2);
  enter(c, Operations.rs);
  enter(c, Operations.n4);
  enter(c, Operations.n5);
  enter(c, Operations.sst);
  enter(c, Operations.pr);
  enter(c, Operations.rs);
  await out.moveNext();
  expect(out.current, ProgramEvent.runStop);
  await out.moveNext();
  expect(out.current, ProgramEvent.stop);
  expect(m.xI, BigInt.from(0x12));
  enter(c, Operations.n3);
  expect(m.xI, BigInt.from(0x3));
  enter(c, Operations.sst);
  await out.moveNext();
  expect(out.current, ProgramEvent.stop);
  expect(m.xI, BigInt.from(0x34));
  enter(c, Operations.sst);
  await out.moveNext();
  expect(out.current, ProgramEvent.stop);
  expect(m.xI, BigInt.from(0x345));
  enter(c, Operations.n6);
  expect(m.xI, BigInt.from(0x3456));
  enter(c, Operations.sst);
  await out.moveNext();
  expect(out.current, ProgramEvent.stop);
  enter(c, Operations.n9);
  expect(m.xI, BigInt.from(0x19));
}

Future<void> programWithError() async {
  final tc = TestCalculator();
  final m = tc.model;
  final c = tc.controller;
  final out = StreamIterator<ProgramEvent>(tc.output.stream);

  enter(c, Operations.pr);
  enter(c, Operations16.lbl);
  enter(c, Operations16.letterA);
  enter(c, Operations16.floatKey);
  enter(c, Operations.n2);
  enter(c, Operations.n0);
  enter(c, Operations16.reciprocal);
  enter(c, Operations.pr);
  enter(c, Operations16.gsb);
  enter(c, Operations16.letterA);
  await out.moveNext();
  expect(out.current.errorNumber, 0);
  expect(m.display.current, '   error 0  ');

  enter(c, Operations.clearPrefix); // Clear error display
  enter(c, Operations.pr); // Program mode
  enter(c, Operations.clearPrgm);
  enter(c, Operations16.lbl);
  enter(c, Operations16.letterA);
  enter(c, Operations.n1);
  enter(c, Operations16.plus);
  enter(c, Operations16.gsb);
  enter(c, Operations16.letterA);
  enter(c, Operations.pr);
  enter(c, Operations.n0);
  enter(c, Operations.enter);
  enter(c, Operations.enter);
  enter(c, Operations.enter);
  enter(c, Operations16.gsb);
  enter(c, Operations16.letterA);
  expect(await out.moveNext(), true);
  expect(out.current.errorNumber, 5, reason: '${out.current} unexpected');
  expect(m.display.current, '   error 5  ');
  enter(c, Operations16.letterA);
  expect(m.display.current.trim(), '5.00');
}

Future<void> testRegistersAndWordSize() async {
  // p. 67:
  final m = Model16();
  final c = Controller16(m);

  enter(c, Operations16.hex);
  enter(c, Operations.n1);
  enter(c, Operations.n0);
  enter(c, Operations16.wSize);
  enter(c, Operations.clearReg);
  enter(c, Operations.n1);
  enter(c, Operations.n2);
  enter(c, Operations.n3);
  enter(c, Operations.n4);
  enter(c, Operations16.sto);
  enter(c, Operations.n0);
  enter(c, Operations.n5);
  enter(c, Operations.n6);
  enter(c, Operations.n7);
  enter(c, Operations.n8);
  enter(c, Operations16.sto);
  enter(c, Operations.n1);
  enter(c, Operations.n2);
  enter(c, Operations.n0);
  enter(c, Operations16.wSize);
  enter(c, Operations16.rcl);
  enter(c, Operations.n0);
  expect(m.xI, BigInt.parse('56781234', radix: 16));
  enter(c, Operations16.rcl);
  enter(c, Operations.n1);
  expect(m.xI, BigInt.parse('0', radix: 16));
  enter(c, Operations.n1);
  enter(c, Operations.n0);
  enter(c, Operations16.wSize);
  enter(c, Operations16.rcl);
  enter(c, Operations.n0);
  expect(m.xI, BigInt.parse('1234', radix: 16));
  enter(c, Operations16.rcl);
  enter(c, Operations.n1);
  expect(m.xI, BigInt.parse('5678', radix: 16));

  // p. 70:
  enter(c, Operations.n0);
  enter(c, Operations.enter);
  enter(c, Operations.enter);
  enter(c, Operations.enter);
  enter(c, Operations16.dec);
  enter(c, Operations.n0);
  enter(c, Operations16.wSize);
  enter(c, Operations.n3);
  enter(c, Operations.n2);
  enter(c, Operations.n6);
  enter(c, Operations16.sto);
  enter(c, Operations16.I);
  enter(c, Operations.n4);
  enter(c, Operations16.wSize);
  enter(c, Operations.n3);
  enter(c, Operations16.sto);
  enter(c, Operations16.parenI);
  enter(c, Operations.bsp);
  enter(c, Operations16.rcl);
  enter(c, Operations16.parenI);
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
    enter(c, Operations16.floatKey);
    enter(c, Operations.n0);
    enter(c, Operations.eex);
    enter(c, Operations.n8);
    enter(c, Operations16.sto);
    enter(c, Operations.n0);
    if (program) {
      enter(c, Operations.clx);
    } else {
      enter(c, Operations.bsp);
    }
    enter(c, Operations16.rcl);
    enter(c, Operations.n0);
    enter(c, Operations.n2);
    enter(c, Operations16.mult);
    if (program) {
      final out = StreamIterator<ProgramEvent>(tc.output.stream);
      enter(c, Operations.sst);
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

Future<void> testNegativeGosub() async {
  final tc = TestCalculator();
  final c = tc.controller;
  final m = tc.model;
  final out = StreamIterator<ProgramEvent>(tc.output.stream);
  enter(c, Operations.pr);
  enter(c, Operations16.lbl);
  enter(c, Operations16.letterB);
  enter(c, Operations.n4);
  enter(c, Operations.n2);
  enter(c, Operations.rtn);
  enter(c, Operations.pr);
  enter(c, Operations16.twosCompl);
  m.xI = BigInt.from(-0xc);
  enter(c, Operations16.sto);
  enter(c, Operations16.I);
  enter(c, Operations16.gsb);
  enter(c, Operations16.I);
  expect(m.display.current.trim(), 'error 4');
  enter(c, Operations.enter);
  m.xI = BigInt.from(-0xb);
  enter(c, Operations.enter);
  enter(c, Operations16.sto);
  enter(c, Operations16.I);
  enter(c, Operations16.gsb);
  enter(c, Operations16.I);
  await out.moveNext();
  expect(out.current, ProgramEvent.done);
  expect(m.xI, BigInt.from(0x42));
}

Future<void> testFloatStackLift() async {
  final tc = TestCalculator();
  final c = tc.controller;
  final m = tc.model;
  enter(c, Operations16.floatKey);
  enter(c, Operations.n2);
  enter(c, Operations.n1);
  enter(c, Operations.enter);
  enter(c, Operations.n2);
  enter(c, Operations.enter);
  expect(m.x, Value.fromDouble(2));
  expect(m.y, Value.fromDouble(2));
  expect(m.z, Value.fromDouble(1));
  enter(c, Operations16.floatKey);
  enter(c, Operations.n4);
  enter(c, Operations.n3); // Stack lift not enabled
  expect(m.x, Value.fromDouble(3));
  expect(m.y, Value.fromDouble(2));
  expect(m.z, Value.fromDouble(1));

  enter(c, Operations16.hex);
  enter(c, Operations.enter);
  enter(c, Operations.n2);
  enter(c, Operations.enter);
  enter(c, Operations16.floatKey);
  enter(c, Operations.n4);
  expect(m.x, Value.fromDouble(8));
  expect(m.y, Value.fromDouble(0));
  expect(m.z, Value.fromDouble(0));
  enter(c, Operations.n7); // Stack lift enabled
  expect(m.x, Value.fromDouble(7));
  expect(m.y, Value.fromDouble(8));
  expect(m.z, Value.fromDouble(0));
}

Future<void> testBug21() async {
  for (final program in [false, true]) {
    final tc = TestCalculator();
    final c = tc.controller;
    final m = tc.model;
    if (program) {
      enter(c, Operations.pr);
      enter(c, Operations16.lbl);
      enter(c, Operations16.letterA);
    }
    enter(c, Operations.n1);
    enter(c, Operations.enter);
    enter(c, Operations.enter);
    enter(c, Operations.enter);
    enter(c, Operations16.plus);
    enter(c, Operations16.showBin);
    enter(c, Operations16.plus);
    if (program) {
      enter(c, Operations.rtn);
      enter(c, Operations.pr);
      final out = StreamIterator<ProgramEvent>(tc.output.stream);
      enter(c, Operations16.gsb);
      enter(c, Operations16.letterA);
      expect(await out.moveNext(), true);
      expect(out.current.pauseValue != null, true);
      tc.resume();
      expect(await out.moveNext(), true);
      expect(out.current, ProgramEvent.done);
    }
    expect(m.xI, BigInt.from(3));
  }
}
