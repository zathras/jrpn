// ignore_for_file: avoid_print

// 11C smoke suite. Boots the 11C target, exercises a few core operations
// end-to-end, verifies the opcode table hasn't drifted from the 15C
// reference, and runs the pre-existing `SelfTests11` battery.
//
// TODO: extend as 11C behavior diverges from 15C. In particular, add
// targeted tests whenever:
//   - the 11C keyboard layout is wired up (assert key-to-op mapping),
//   - matrix entry points are removed from the 11C UI,
//   - complex mode is disabled on 11C,
//   - the 11C stats register map is changed from the 15C mapping,
//   - 11C-specific memory limits / program-handbook behavior is locked in.
// Each of those is the right moment to add coverage against the *11C*
// spec rather than mirroring 15C.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:jrpn/c/operations.dart';
import 'package:jrpn/m/model.dart';
import 'package:jrpn/jrpn11/main.dart';
import 'package:jrpn/jrpn11/model11c.dart';
import 'package:jrpn/jrpn11/tests11c.dart';

import 'opcodes11c.dart';
import 'programs.dart';

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  runStaticInitialization11();

  test('11C identity', () {
    final tc = TestCalculator(for11C: true);
    final m = tc.model;
    expect(m.kind, CalculatorModelKind.jrpn11);
    expect(m.modelName, '11C');
    expect(m.hasIntegerModeSettings, false);
  });

  test('Persistent storage keys are stable across all model kinds', () {
    // These specific strings are a back-compat contract: changing them
    // would silently drop saved state on upgrade.
    expect(CalculatorModelKind.jrpn16.persistentStorageKey, 'init');
    expect(CalculatorModelKind.jrpn15.persistentStorageKey, 'init15C');
    expect(CalculatorModelKind.jrpn11.persistentStorageKey, 'init11C');
  });

  test('Model display names are stable across all model kinds', () {
    // Persisted in JSON state files; values are a back-compat contract.
    expect(CalculatorModelKind.jrpn16.displayName, '16C');
    expect(CalculatorModelKind.jrpn15.displayName, '15C');
    expect(CalculatorModelKind.jrpn11.displayName, '11C');
  });

  test('11C JSON omits 16C-only integer-mode settings', () {
    final tc = TestCalculator(for11C: true);
    final json = tc.model.toJson();
    final settings = json['settings'] as Map;
    expect(settings.containsKey('showWordSize'), false);
    expect(settings.containsKey('hideComplement'), false);
    expect(settings.containsKey('integerModeCommas'), false);
  });

  test('decodeJson rejects a foreign-model state file', () {
    final tc = TestCalculator(for11C: true);
    final json = tc.model.toJson();
    json['modelName'] = '15C';
    expect(
      () => tc.model.decodeJson(
        Map<String, dynamic>.from(json),
        needsSave: false,
      ),
      throwsArgumentError,
    );
  });

  test('11C boots and does basic stack arithmetic', () {
    final tc = TestCalculator(for11C: true);
    final m = tc.model;

    expect(m is Model11, true);
    expect(m.isComplexMode, false);

    tc.enter(Operations.n2);
    tc.enter(Operations.enter);
    tc.enter(Operations.n3);
    tc.enter(Operations11.plus);
    expect(m.x, Value.fromDouble(5));

    tc.enter(Operations.n4);
    tc.enter(Operations11.mult);
    expect(m.x, Value.fromDouble(20));

    tc.enter(Operations.chs);
    expect(m.x, Value.fromDouble(-20));
  });

  test('11C STO/RCL round-trip', () {
    final tc = TestCalculator(for11C: true);
    final m = tc.model;

    tc.enter(Operations.n4);
    tc.enter(Operations.n2);
    tc.enter(Operations11.sto15);
    tc.enter(Operations.n0);
    expect(m.memory.registers[0], Value.fromDouble(42));

    tc.enter(Operations.clx);
    expect(m.x, Value.zero);

    tc.enter(Operations11.rcl15);
    tc.enter(Operations.n0);
    expect(m.x, Value.fromDouble(42));
  });

  test('11C GSB runs a stored program', () async {
    final tc = TestCalculator(for11C: true);
    final m = tc.model;
    final out = StreamIterator<ProgramEvent>(tc.output.stream);

    // Program:  LBL A, 2, +, RTN
    tc.enter(Operations.pr);
    tc.enter(Operations11.lbl15);
    tc.enter(Operations11.letterLabelA);
    tc.enter(Operations.n2);
    tc.enter(Operations11.plus);
    tc.enter(Operations.rtn);
    tc.enter(Operations.pr);

    tc.enter(Operations.n4);
    tc.enter(Operations.n0);
    tc.enter(Operations11.gsb);
    tc.enter(Operations11.letterLabelA);
    expect(await out.moveNext(), true);
    expect(out.current, ProgramEvent.done);
    expect(m.x, Value.fromDouble(42));
  });

  test('Built-in self tests 11C', () async {
    await SelfTests11(inCalculator: false).runAll();
  });

  test('11C opcode test', opcodeTest11C);
}
