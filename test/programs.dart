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
import 'dart:io';

import 'package:jrpn/c/operations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jrpn/c/controller.dart';
import 'package:jrpn/m/model.dart';

class ProgramEvent {
  final int? errorNumber;

  ProgramEvent({this.errorNumber});

  static final done = ProgramEvent();
  static final runStop = ProgramEvent();
  static final pause = ProgramEvent();
  static final stop = ProgramEvent();
}

class TestCalculator implements ProgramListener {
  final controller = Controller(Model<Operation>());
  Model get model => controller.model;
  // The program's output
  final output = StreamController<ProgramEvent>();
  Completer<void>? _resume;

  TestCalculator() {
    model.settings.msPerInstruction = 0;
    model.program.programListener = this;
  }

  void loadState(final String fileName) {
    final state = File('./test/examples/$fileName').readAsStringSync();
    model.decodeJson(json.decoder.convert(state) as Map<String, dynamic>,
        needsSave: false);
    model.settings.msPerInstruction = 0;
  }

  @override
  void onDone() => output.add(ProgramEvent.done);

  @override
  void onError(CalculatorError err) =>
      output.add(ProgramEvent(errorNumber: err.num));

  @override
  void onPause() {
    _resume ??= Completer<void>();
    output.add(ProgramEvent.pause);
  }

  @override
  void onRS() => output.add(ProgramEvent.runStop);

  @override
  void onStop() => output.add(ProgramEvent.stop);

  @override
  Future<void> resumeFromPause() {
    _resume ??= Completer<void>();
    return _resume!.future;
  }

  void resume() {
    Completer c = _resume!;
    _resume = null;
    c.complete(null);
  }

  void enter(Operation key) {
    controller.buttonDown(key);
    controller.buttonUp();
  }
}

void appendixA() {
  String fd(double d) => d.toStringAsExponential(6);

  final List<String> ieeeFormat = [
    '80000000', // -0
    '7f800000',
    '00800000',
    '3f800001',
    '7f800000',
    '1',
    '40490fdb'
  ];
  final Map<int, String> canonicalIeee = {0: '0'};
  final List<double> floatFormat = [
    0.0,
    1.0e100,
    1.175494351e-38,
    1.000000119,
    8e72,
    1.401298464e-45,
    3.141592654
  ];
  assert(ieeeFormat.length == floatFormat.length);
  for (int i = 0; i < ieeeFormat.length; i++) {
    test('Convert to ${floatFormat[i]}', () async {
      final x = Value.fromInternal(BigInt.parse(ieeeFormat[i], radix: 16));
      // Note that this uses x==0, which is the last opcode assigned (244).
      // This, and the other programs are a pretty thorough test of the
      // stability of the opcode assignments.
      final p = TestCalculator()..loadState('appendix_d_ieee_float.jrpn');
      final out = StreamIterator<ProgramEvent>(p.output.stream);
      p.model.displayMode = DisplayMode.hex;
      p.model.wordSize = 32;
      p.model.x = x;
      p.enter(Operations.gsb);
      p.enter(Operations.b);
      expect(await out.moveNext(), true);
      expect(out.current, ProgramEvent.done);
      if (floatFormat[i] >= 8e72) {
        // ieee infinity
        expect(fd(p.model.xF), fd(1.0e100));
      } else {
        expect(fd(p.model.xF), fd(floatFormat[i]));
      }
    });
    test('Convert from ${floatFormat[i]}', () async {
      final p = TestCalculator()..loadState('appendix_d_ieee_float.jrpn');
      final out = StreamIterator<ProgramEvent>(p.output.stream);
      p.model.x = Value.fromDouble(floatFormat[i]);
      p.enter(Operations.gsb);
      p.enter(Operations.a);
      expect(await out.moveNext(), true);
      expect(out.current, ProgramEvent.done);
      final String ieee = canonicalIeee[i] ?? ieeeFormat[i];
      expect(p.model.x.internal, BigInt.parse(ieee, radix: 16));
    });
  }
}

Future<void> p79Program() async {
  final p = TestCalculator()..loadState('p79_example.jrpn');
  final out = StreamIterator<ProgramEvent>(p.output.stream);
  p.enter(Operations.gsb);
  p.enter(Operations.n1);
  expect(await out.moveNext(), true);
  expect(out.current, ProgramEvent.done);
  expect(p.model.xI, BigInt.parse('1219326320'));
  expect(p.model.yI, BigInt.parse('731267636031035818'));
}

Future<void> p93Checksum() async {
  final p = TestCalculator()..loadState('p93_checksum.jrpn');
  final out = StreamIterator<ProgramEvent>(p.output.stream);
  p.enter(Operations.gsb);
  p.enter(Operations.d);
  expect(await out.moveNext(), true);
  expect(out.current, ProgramEvent.done);
  expect(p.model.xI, BigInt.parse('6'));
  expect(p.model.yI, BigInt.parse('1'));
}

/// Support for Towers of Hanoi test
class Move {
  final int from;
  final int to;

  Move(this.from, this.to);

  @override
  String toString() => 'from $from to $to';
}

/// Support for Towers of Hanoi test
Iterable<Move> hanoi(int discs, int from, int to) sync* {
  int other = 6 - from - to;
  if (discs == 1) {
    yield Move(from, to);
  } else {
    yield* hanoi(discs - 1, from, other);
    yield Move(from, to);
    yield* hanoi(discs - 1, other, to);
  }
}

Future<void> towersOfHanoi() async {
  final p = TestCalculator()..loadState('towers_of_hanoi.jrpn');
  final out = StreamIterator<ProgramEvent>(p.output.stream);
  p.enter(Operations.n7);
  p.enter(Operations.gsb);
  p.enter(Operations.a);
  for (final Move move in hanoi(0x7, 1, 3)) {
    expect(await out.moveNext(), true);
    expect(out.current, ProgramEvent.pause);
    expect(p.model.xI.toInt(), move.from);
    p.resume();
    expect(await out.moveNext(), true);
    expect(out.current, ProgramEvent.runStop);
    expect(p.model.xI.toInt(), move.to);
    p.enter(Operations.rs);
  }
  expect(await out.moveNext(), true);
  expect(out.current, ProgramEvent.done);
  // Note that for a depth of 1, we get a Pause followed by a R/S
  expect(p.model.xI.toInt(), 0);
}
