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

import 'package:flutter/foundation.dart';
import 'package:jrpn/c/operations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jrpn/c/controller.dart';
import 'package:jrpn/m/model.dart';
import 'package:jrpn15c/main.dart';
import 'package:jrpn16c/main.dart';

class ProgramEvent {
  final int? errorNumber;
  final String? name;

  ProgramEvent({this.errorNumber, this.name});

  static final done = ProgramEvent(name: 'done');

  /// runStop pressed.  Normally followed by stop.
  static final runStop = ProgramEvent(name: 'run/stop');
  static final pause = ProgramEvent(name: 'pause');
  static final stop = ProgramEvent(name: 'stop');

  @override
  String toString() {
    if (name != null) {
      return ('ProgramEvent("$name")');
    } else if (errorNumber != null) {
      return ('ProgramEvent($errorNumber)');
    }
    return super.toString();
  }
}

class TestCalculator implements ProgramListener {
  final Controller controller;
  Model get model => controller.model;
  // The program's output
  final output = StreamController<ProgramEvent>();
  Completer<void>? _resume;
  static const trace = false;

  TestCalculator({bool for15C = false})
      : controller =
            for15C ? Controller15(createModel15()) : Controller16(Model16()) {
    model.settings.msPerInstruction = 0;
    model.program.programListener = this;
  }

  void _trace(String msg) {
    // print(msg);
  }

  void loadState(final String fileName) {
    final state = File('./test/examples/$fileName').readAsStringSync();
    loadStateFromString(state);
  }

  void loadStateFromString(final String state) {
    model.decodeJson(json.decoder.convert(state) as Map<String, dynamic>,
        needsSave: false);
    model.settings.msPerInstruction = 0;
  }

  @override
  void onDone() {
    _trace("==> sending done");
    output.add(ProgramEvent.done);
  }

  @override
  void onError(CalculatorError err) {
    _trace("==> sending error $err");
    output.add(ProgramEvent(errorNumber: controller.getErrorNumber(err)));
  }

  @override
  void onPause() {
    _resume ??= Completer<void>();
    _trace("==> sending pause");
    output.add(ProgramEvent.pause);
  }

  @override
  void onRS() {
    _trace("==> sending runStop");
    output.add(ProgramEvent.runStop);
  }

  @override
  void onStop() {
    _trace("==> sending stop");
    output.add(ProgramEvent.stop);
  }

  @override
  Future<void> resumeFromPause() {
    _trace("==> resuming from pause");

    _resume ??= Completer<void>();
    return _resume!.future;
  }

  void resume() {
    _trace("==> resume");
    Completer c = _resume!;
    _resume = null;
    c.complete(null);
  }

  void enter(Operation key) {
    controller.buttonDown(key);
    controller.buttonUp();
  }

  @override
  void onErrorShown(CalculatorError err, StackTrace? stack) {
    debugPrint('Calculator error shown:  $err');
    // if (stack != null) {
    //   debugPrint(stack?.toString());
    // }
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
      p.enter(Operations16.gsb);
      p.enter(Operations16.letterB);
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
      p.enter(Operations16.gsb);
      p.enter(Operations16.letterA);
      expect(await out.moveNext(), true);
      expect(out.current, ProgramEvent.done);
      final String ieee = canonicalIeee[i] ?? ieeeFormat[i];
      expect(p.model.x.internal, BigInt.parse(ieee, radix: 16));
    });
  }
}

Future<void> programEntry() async {
  final tc = TestCalculator();
  final m = tc.model;
  tc.enter(Operations.pr);
  int line = 0;
  expect(m.display.current, '${(line++).toString().padLeft(3, '0')}-      ');
  tc.enter(Operations16.bin);
  expect(m.display.current, '${(line++).toString().padLeft(3, '0')}-    26');
  tc.enter(Operations.sqrtOp);
  expect(m.display.current, '${(line++).toString().padLeft(3, '0')}- 43 25');
  tc.enter(Operations.n1);
  expect(m.display.current, '${(line++).toString().padLeft(3, '0')}-     1');
  tc.enter(Operations16.gsb);
  tc.enter(Operations.n0);
  expect(m.display.current, '${(line++).toString().padLeft(3, '0')}- 21  0');
  tc.enter(Operations16.gsb);
  tc.enter(Operations.sst);
  expect(m.display.current, '${(line++).toString().padLeft(3, '0')}- 21 32');
  tc.enter(Operations16.gsb);
  tc.enter(Operations16.I);
  expect(m.display.current, '${(line++).toString().padLeft(3, '0')}- 21 32');
  tc.enter(Operations16.gto);
  tc.enter(Operations.dot);
  tc.enter(Operations.n0);
  tc.enter(Operations.n0);
  tc.enter(Operations.n2);
  line = 2;
  expect(m.display.current, '${(line++).toString().padLeft(3, '0')}- 43 25');
  tc.enter(Operations16.floatKey);
  tc.enter(Operations.n4);
  expect(m.display.current, '${(line++).toString().padLeft(3, '0')}-42,45, 4');
  tc.enter(Operations16.floatKey);
  tc.enter(Operations.dot);
  expect(m.display.current, '${(line++).toString().padLeft(3, '0')}-42,45,48');
}

Future<void> p79Program() async {
  final p = TestCalculator()..loadState('p79_example.jrpn');
  final out = StreamIterator<ProgramEvent>(p.output.stream);
  p.enter(Operations16.gsb);
  p.enter(Operations.n1);
  expect(await out.moveNext(), true);
  expect(out.current, ProgramEvent.done);
  expect(p.model.xI, BigInt.parse('1219326320'));
  expect(p.model.yI, BigInt.parse('731267636031035818'));
}

Future<void> p93Checksum() async {
  final p = TestCalculator()..loadState('p93_checksum.jrpn');
  final out = StreamIterator<ProgramEvent>(p.output.stream);
  p.enter(Operations16.gsb);
  p.enter(Operations16.letterD);
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
  p.enter(Operations16.gsb);
  p.enter(Operations16.letterA);
  for (final Move move in hanoi(0x7, 1, 3)) {
    expect(await out.moveNext(), true);
    expect(out.current, ProgramEvent.pause);
    expect(p.model.xI.toInt(), move.from);
    p.resume();
    expect(await out.moveNext(), true);
    expect(out.current, ProgramEvent.runStop);
    expect(await out.moveNext(), true);
    expect(out.current, ProgramEvent.stop);
    expect(p.model.xI.toInt(), move.to);
    p.enter(Operations.rs);
  }
  expect(await out.moveNext(), true);
  expect(out.current, ProgramEvent.done);
  // Note that for a depth of 1, we get a Pause followed by a R/S
  expect(p.model.xI.toInt(), 0);
}
