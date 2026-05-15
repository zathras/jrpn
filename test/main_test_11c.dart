// ignore_for_file: avoid_print

// 11C smoke + layout suite. Boots the 11C target, exercises a few core
// operations end-to-end, asserts the keyboard matches the handbook,
// verifies the opcode snapshot, and runs the pre-existing `SelfTests11`
// battery.
//
// TODO: extend as 11C behavior diverges further. Add targeted tests when:
//   - matrix entry points are closed off outside the keyboard,
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

  test('11C statistics accumulate into R0..R5 (handbook p. 58 example)', () {
    final tc = TestCalculator(for11C: true);
    final m = tc.model;
    final regs = m.memory.registers;

    // Pre-seed R0..R7 with junk to prove (a) CLEAR Σ wipes R0..R5, and
    // (b) 11C doesn't touch the 15C-range registers R6/R7.
    final junk = Value.fromDouble(0xdeadbeef.toDouble());
    for (int i = 0; i <= 7; i++) {
      regs[i] = junk;
    }
    tc.enter(Operations.fShift);
    tc.enter(Operations11.clearSigma);
    for (int i = 0; i <= 5; i++) {
      expect(regs[i], Value.zero, reason: 'R$i after CLEAR Σ');
    }
    expect(regs[6], junk, reason: 'CLEAR Σ must not touch R6 on 11C');
    expect(regs[7], junk, reason: 'CLEAR Σ must not touch R7 on 11C');

    // (y, x) pairs from the HP-11C handbook coal/electricity example.
    final pairs = <(double, double)>[
      (1.761, 5.552),
      (1.775, 5.963),
      (1.792, 6.135),
      (1.884, 6.313),
      (1.943, 6.713),
    ];
    for (final (y, x) in pairs) {
      m.yF = y;
      m.xF = x;
      tc.enter(Operations11.sigmaPlus);
    }

    // After Σ+, X holds the running n.
    expect(m.x, Value.fromDouble(5));
    // Handbook expected values (FIX 4 in the manual).
    expect(regs[0], Value.fromDouble(5));            // n
    expect(regs[1], Value.fromDouble(30.676));       // Σx
    expect(regs[2], Value.fromDouble(188.938636));   // Σx²
    expect(regs[3], Value.fromDouble(9.155));        // Σy
    expect(regs[4], Value.fromDouble(16.787715));    // Σy²
    expect(regs[5], Value.fromDouble(56.292368));    // Σxy

    // 15C-style positions (R2..R7) must NOT be touched. We pre-seeded
    // R6/R7 with junk; they should still be junk. R2..R5 were already
    // cleared and re-used by 11C stats, so we can't assert on them here.
    expect(regs[6], junk, reason: 'R6 must not be used by 11C stats');
    expect(regs[7], junk, reason: 'R7 must not be used by 11C stats');
  });

  test('11C keyboard matches the expected layout', () {
    final tc = TestCalculator(for11C: true);
    final keys = tc.model.logicalKeys;
    // (row, col, primary, f-shift, g-shift). Row 3 col 5 is null
    // (lower half of ENTER).
    final expected = <List<Object>>[
      // Row 0
      [0, 0, Operations11.sqrtOp15, Operations11.letterLabelA, Operations11.xSquared],
      [0, 1, Operations11.eX15, Operations11.letterLabelB, Operations11.lnOp],
      [0, 2, Operations11.tenX15, Operations11.letterLabelC, Operations11.logOp],
      [0, 3, Operations11.yX15, Operations11.letterLabelD, Operations11.percent],
      [0, 4, Operations11.reciprocal15, Operations11.letterLabelE, Operations11.deltaPercent],
      [0, 5, Operations.chs, Operations11.piOp, Operations.abs],
      [0, 6, Operations.n7, Operations11.fix, Operations11.deg],
      [0, 7, Operations.n8, Operations11.sci, Operations11.rad],
      [0, 8, Operations.n9, Operations11.eng, Operations11.grd],
      [0, 9, Operations11.div, Operations.xLEy, Operations.xLT0],
      // Row 1
      [1, 0, Operations.sst, Operations11.lbl15, Operations.bst],
      [1, 1, Operations11.gto, Operations11.hyp, Operations11.hypInverse],
      [1, 2, Operations11.sin, Operations.xSwapParenI, Operations11.sinInverse],
      [1, 3, Operations11.cos, Operations11.parenI15, Operations11.cosInverse],
      [1, 4, Operations11.tan, Operations11.I15, Operations11.tanInverse],
      [1, 5, Operations.eex, Operations11.toR, Operations11.toP],
      [1, 6, Operations.n4, Operations11.xExchange, Operations11.sf],
      [1, 7, Operations.n5, Operations11.dse, Operations11.cf],
      [1, 8, Operations.n6, Operations11.isg, Operations11.fQuestion],
      [1, 9, Operations11.mult, Operations.xGTy, Operations.xGT0],
      // Row 2
      [2, 0, Operations.rs, Operations.pse, Operations.pr],
      [2, 1, Operations11.gsb, Operations11.clearSigma, Operations.rtn],
      [2, 2, Operations.rDown, Operations.clearPrgm, Operations.rUp],
      [2, 3, Operations.xy, Operations.clearReg, Operations11.rnd],
      [2, 4, Operations.bsp, Operations.clearPrefix, Operations.clx],
      [2, 5, Operations.enter, Operations11.ranNum, Operations11.lstx15],
      [2, 6, Operations.n1, Operations11.pYX, Operations11.cYX],
      [2, 7, Operations.n2, Operations11.toHMS, Operations11.toH],
      [2, 8, Operations.n3, Operations11.toRad, Operations11.toDeg],
      [2, 9, Operations11.minus, Operations.xNEy, Operations.xNE0],
      // Row 3
      [3, 0, Operations.onOff, Operations.onOff, Operations.onOff],
      [3, 1, Operations.fShift, Operations.fShift, Operations.fShift],
      [3, 2, Operations.gShift, Operations.gShift, Operations.gShift],
      [3, 3, Operations11.sto15, Operations11.fracOp, Operations11.intOp],
      [3, 4, Operations11.rcl15, Operations11.userOp, Operations.mem],
      // row 3 col 5 is null (under ENTER)
      [3, 6, Operations.n0, Operations11.xFactorial, Operations11.xBar],
      [3, 7, Operations.dot, Operations11.yHatR, Operations11.stdDeviation],
      [3, 8, Operations11.sigmaPlus, Operations11.linearRegression, Operations11.sigmaMinus],
      [3, 9, Operations11.plus, Operations.xEQy, Operations.xEQ0],
    ];
    for (final e in expected) {
      final row = e[0] as int;
      final col = e[1] as int;
      final k = keys[row][col];
      final pos = 'row $row col $col';
      expect(k, isNotNull, reason: '$pos missing');
      expect(k!.unshifted, same(e[2]), reason: '$pos primary');
      expect(k.fShifted, same(e[3]), reason: '$pos f-shift');
      expect(k.gShifted, same(e[4]), reason: '$pos g-shift');
    }
    expect(keys[3][5], isNull, reason: 'row 3 col 5 should be null (under ENTER)');
  });

  test('Built-in self tests 11C', () async {
    await SelfTests11(inCalculator: false).runAll();
  });

  test('11C opcode test', opcodeTest11C);
}
