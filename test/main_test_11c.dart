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

  test('11C decodeJson stays real-only even with imaginaryStack in JSON', () {
    // Base Model.decodeJson gates `imaginaryStack` / `lastXImaginary`
    // restoration on `supportsComplex`, which is false for 11C.
    final tc = TestCalculator(for11C: true);
    final m = tc.model;
    final json = m.toJson();
    final flags = List<bool>.from(json['flags'] as List);
    flags[8] = true;
    json['flags'] = flags;
    json['imaginaryStack'] = List.filled(4, Value.zero.toJson());
    json['lastXImaginary'] = Value.zero.toJson();
    m.decodeJson(Map<String, dynamic>.from(json), needsSave: false);
    expect(m.isComplexMode, false);
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

  test('11C storage register arithmetic exercises (handbook p. 40)', () {
    final tc = TestCalculator(for11C: true);
    final m = tc.model;

    tc.enter(Operations.n1);
    tc.enter(Operations.n8);
    tc.enter(Operations11.sto15);
    tc.enter(Operations.n0);
    expect(m.memory.registers[0], Value.fromDouble(18));

    tc.enter(Operations.n3);
    tc.enter(Operations11.sto15);
    tc.enter(Operations11.div);
    tc.enter(Operations.n0);
    expect(m.memory.registers[0], Value.fromDouble(6));

    tc.enter(Operations.n4);
    tc.enter(Operations11.sto15);
    tc.enter(Operations11.mult);
    tc.enter(Operations.n0);
    expect(m.memory.registers[0], Value.fromDouble(24));

    tc.enter(Operations11.rcl15);
    tc.enter(Operations.n0);
    tc.enter(Operations11.sto15);
    tc.enter(Operations11.plus);
    tc.enter(Operations.n0);
    expect(m.memory.registers[0], Value.fromDouble(48));

    tc.enter(Operations.n4);
    tc.enter(Operations.n0);
    tc.enter(Operations11.sto15);
    tc.enter(Operations11.minus);
    tc.enter(Operations.n0);
    expect(m.memory.registers[0], Value.fromDouble(8));
  });

  test('11C RCL has no arithmetic argument (only STO does)', () {
    // The 11C only supports STO arithmetic, no RCL arithmetic
    // RCL's argument structure should expose register reads
    // and RAN# / Sigma+ keys, but no +/-/*/div keys.
    final arg = Operations11.rcl15.arg as ArgAlternates;
    final keys = arg.children.whereType<KeyArg>().map((c) => c.key).toSet();
    expect(keys.contains(Operations11.plus), isFalse);
    expect(keys.contains(Operations11.minus), isFalse);
    expect(keys.contains(Operations11.mult), isFalse);
    expect(keys.contains(Operations11.div), isFalse);
  });

  test('11C SF/CF/F? only target flags 0 and 1 (p. 116)', () async {
    // "The two flags in your HP-11C are numbered 0 and 1."
    final tc = TestCalculator(for11C: true);
    final m = tc.model;
    final out = StreamIterator<ProgramEvent>(tc.output.stream);

    expect(m.getFlag(0), false);
    expect(m.getFlag(1), false);

    tc.enter(Operations11.sf);
    tc.enter(Operations.n0);
    expect(m.getFlag(0), true);

    tc.enter(Operations11.sf);
    tc.enter(Operations.n1);
    expect(m.getFlag(1), true);

    tc.enter(Operations11.cf);
    tc.enter(Operations.n0);
    expect(m.getFlag(0), false);
    expect(m.getFlag(1), true);

    // Verify F? branches a running program based on flag state.
    // Program:  LBL A, F? 1, GTO 0, 0, RTN, LBL 0, 4, 2, RTN
    tc.enter(Operations.pr);
    tc.enter(Operations11.lbl15);
    tc.enter(Operations11.letterLabelA);
    tc.enter(Operations11.fQuestion);
    tc.enter(Operations.n1);
    tc.enter(Operations11.gto);
    tc.enter(Operations.n0);
    tc.enter(Operations.n0);
    tc.enter(Operations.rtn);
    tc.enter(Operations11.lbl15);
    tc.enter(Operations.n0);
    tc.enter(Operations.n4);
    tc.enter(Operations.n2);
    tc.enter(Operations.rtn);
    tc.enter(Operations.pr);

    tc.enter(Operations11.gsb);
    tc.enter(Operations11.letterLabelA);
    expect(await out.moveNext(), true);
    expect(out.current, ProgramEvent.done);
    expect(m.x, Value.fromDouble(42));
  });

  test('11C SF/CF/F? arg structure has no I path and only digits 0-1', () {
    // Only "SF/CF/F? followed by the digit key (0 or 1)".
    // There is no indirect (I) addressing for flags on the 11C.
    for (final op in [Operations11.sf, Operations11.cf, Operations11.fQuestion]) {
      final arg = op.arg as ArgAlternates;
      final keys = arg.children.whereType<KeyArg>().map((c) => c.key).toSet();
      expect(keys.contains(Arg.kI), isFalse,
          reason: '${op.name} must not accept I as argument on 11C');
      expect(keys.contains(Arg.kParenI), isFalse,
          reason: '${op.name} must not accept (i) as argument on 11C');
    }
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

  test('Pythagorean Theorem program (handbook p. 99)', () async {
    final tc = TestCalculator(for11C: true);
    final m = tc.model;
    final out = StreamIterator<ProgramEvent>(tc.output.stream);

    // LBL E, x², x↔y, x², +, √x, RTN
    tc.enter(Operations.pr);
    tc.enter(Operations11.lbl15);
    tc.enter(Operations11.letterLabelE);
    tc.enter(Operations11.xSquared);
    tc.enter(Operations.xy);
    tc.enter(Operations11.xSquared);
    tc.enter(Operations11.plus);
    tc.enter(Operations11.sqrtOp15);
    tc.enter(Operations.rtn);
    tc.enter(Operations.pr);

    // 22 ENTER 9 GSB E → hypotenuse 23.7697 at FIX 4.
    tc.enter(Operations.n2);
    tc.enter(Operations.n2);
    tc.enter(Operations.enter);
    tc.enter(Operations.n9);
    tc.enter(Operations11.gsb);
    tc.enter(Operations11.letterLabelE);
    expect(await out.moveNext(), true);
    expect(out.current, ProgramEvent.done);
    expect(m.formatValue(m.x).trim(), '23.7697');
  });

  test('Area of Circle program (handbook p. 87)', () async {
    final tc = TestCalculator(for11C: true);
    final m = tc.model;
    final out = StreamIterator<ProgramEvent>(tc.output.stream);

    // LBL A, x², π, ×, RTN
    tc.enter(Operations.pr);
    tc.enter(Operations11.lbl15);
    tc.enter(Operations11.letterLabelA);
    tc.enter(Operations11.xSquared);
    tc.enter(Operations11.piOp);
    tc.enter(Operations11.mult);
    tc.enter(Operations.rtn);
    tc.enter(Operations.pr);

    // Three handbook input/output pairs at FIX 4.
    for (final (radius, expected) in [
      (7.5, '176.7146'),
      (9.0, '254.4690'),
      (15.3, '735.4154'),
    ]) {
      m.xF = radius;
      tc.enter(Operations11.gsb);
      tc.enter(Operations11.letterLabelA);
      expect(await out.moveNext(), true);
      expect(out.current, ProgramEvent.done);
      expect(m.formatValue(m.x).trim(), expected, reason: 'r=$radius');
    }
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

  test('11C initial memory state: 20 registers + 63 free program lines', () {
    final tc = TestCalculator(for11C: true);
    final m = tc.model;
    expect((m.memory as Memory11).numRegisters, 20);
    expect(m.memory.program.lines, 0);
    // 29 reg-equiv total pool − 20 registers − 0 program = 9 reg-equiv = 63 lines.
    expect((m.memory as Memory11).availableRegisters, 9);
  });

  test('11C auto-converts a storage register on the 64th program line', () {
    final tc = TestCalculator(for11C: true);
    final m = tc.model;
    tc.enter(Operations.pr); // enter program mode
    // 63 single-byte digit instructions fit in the base program memory.
    for (int i = 0; i < 63; i++) {
      tc.enter(Operations.n0);
    }
    expect(m.memory.program.lines, 63);
    expect((m.memory as Memory11).numRegisters, 20, reason: 'no conversion yet');
    // The 64th instruction triggers conversion of R.9.
    tc.enter(Operations.n0);
    expect(m.memory.program.lines, 64);
    expect((m.memory as Memory11).numRegisters, 19);
    // The 71st instruction triggers conversion of R.8.
    for (int i = 64; i < 71; i++) {
      tc.enter(Operations.n0);
    }
    expect(m.memory.program.lines, 71);
    expect((m.memory as Memory11).numRegisters, 18);
  });

  test('11C fills to 203 lines; the 204th throws Error 4', () {
    final tc = TestCalculator(for11C: true);
    final m = tc.model;
    tc.enter(Operations.pr);
    for (int i = 0; i < 203; i++) {
      tc.enter(Operations.n0);
    }
    expect(m.memory.program.lines, 203);
    expect((m.memory as Memory11).numRegisters, 0, reason: 'only R_I remains');
    expect(
      () => tc.enter(Operations.n0),
      throwsA(isA<CalculatorError>().having((e) => e.num15, 'num15', 4)),
    );
  });

  test('STO/RCL on a converted register throws Error 3', () {
    final tc = TestCalculator(for11C: true);
    final m = tc.model;
    tc.enter(Operations.pr);
    for (int i = 0; i < 64; i++) {
      tc.enter(Operations.n0);
    }
    expect((m.memory as Memory11).numRegisters, 19);
    // R.9 (index 19) is now backing program memory, not user data.
    expect(
      () => m.memory.registers[19],
      throwsA(isA<CalculatorError>().having((e) => e.num15, 'num15', 3)),
    );
    expect(
      () => m.memory.registers[19] = Value.fromDouble(42),
      throwsA(isA<CalculatorError>().having((e) => e.num15, 'num15', 3)),
    );
  });

  test('11C auto-restores a register on program deletion', () {
    final tc = TestCalculator(for11C: true);
    final m = tc.model;
    tc.enter(Operations.pr);
    for (int i = 0; i < 64; i++) {
      tc.enter(Operations.n0);
    }
    expect((m.memory as Memory11).numRegisters, 19);
    // Delete one line: 64 → 63, R.9 should come back.
    tc.enter(Operations.bsp);
    expect(m.memory.program.lines, 63);
    expect((m.memory as Memory11).numRegisters, 20);
    // Restored register reads as zero, not as leftover program data.
    expect(m.memory.registers[19], Value.zero);
  });

  test('11C CLEAR PRGM restores all converted registers', () {
    final tc = TestCalculator(for11C: true);
    final m = tc.model;
    tc.enter(Operations.pr);
    for (int i = 0; i < 100; i++) {
      tc.enter(Operations.n0);
    }
    expect((m.memory as Memory11).numRegisters, lessThan(20));
    // f CLEAR PRGM resets to 20 registers, 63 free lines.
    tc.enter(Operations.fShift);
    tc.enter(Operations.clearPrgm);
    expect(m.memory.program.lines, 0);
    expect((m.memory as Memory11).numRegisters, 20);
    // All convertible registers read as zero.
    for (int i = 0; i < 20; i++) {
      expect(m.memory.registers[i], Value.zero, reason: 'R$i');
    }
  });

  test('11C ISG operates on R_I only (handbook pp. 132-134)', () async {
    final tc = TestCalculator(for11C: true);
    final m = tc.model;
    final out = StreamIterator<ProgramEvent>(tc.output.stream);

    // Manual p. 132: control word 2.05002 in R_I = (counter=2, test=050,
    // increment=02). After one ISG, R_I = 4.05002 (counter advances by 2).
    m.memory.registers.index = Value.fromDouble(2.05002);
    tc.enter(Operations.fShift);
    tc.enter(Operations11.isg);
    expect(m.memory.registers.index, Value.fromDouble(4.05002));

    // Manual p. 133: when the loop runs past test value 050, the next
    // program line is skipped. Build a program that ISGs and then GTOs
    // back; on the skipping iteration GTO is bypassed and we hit RTN.
    //   LBL A: ISG, GTO A, RTN
    m.memory.registers.index = Value.fromDouble(48.05002);
    tc.enter(Operations.pr);
    tc.enter(Operations11.lbl15);
    tc.enter(Operations11.letterLabelA);
    tc.enter(Operations.fShift);
    tc.enter(Operations11.isg);
    tc.enter(Operations11.gto);
    tc.enter(Operations11.letterLabelA);
    tc.enter(Operations.rtn);
    tc.enter(Operations.pr);

    tc.enter(Operations11.gsb);
    tc.enter(Operations11.letterLabelA);
    expect(await out.moveNext(), true);
    expect(out.current, ProgramEvent.done);
    // After 50 → 52 (incremented past 50), ISG skipped the GTO and RTN ran.
    expect(m.memory.registers.index, Value.fromDouble(52.05002));
  });

  test('11C DSE operates on R_I only', () async {
    final tc = TestCalculator(for11C: true);
    final m = tc.model;

    // Manual p. 130 iteration table: 6.00002 decrements by 2 each pass
    // (yy=02), passing through 4.00002 → 2.00002 → 0.00002 → -2.00002.
    m.memory.registers.index = Value.fromDouble(6.00002);
    tc.enter(Operations.fShift);
    tc.enter(Operations11.dse);
    expect(m.memory.registers.index, Value.fromDouble(4.00002));

    tc.enter(Operations.fShift);
    tc.enter(Operations11.dse);
    expect(m.memory.registers.index, Value.fromDouble(2.00002));
  });

  test('11C DSE / ISG default to step 1 when R_I has no decimal portion '
      '(handbook p. 129: "unspecified yy defaults to 01")', () async {
    final tc = TestCalculator(for11C: true);
    final m = tc.model;
    final out = StreamIterator<ProgramEvent>(tc.output.stream);

    // Plain integer R_I: yy=00 → step 1, xxx=000 → test value 0.
    m.memory.registers.index = Value.fromDouble(3);
    tc.enter(Operations.fShift);
    tc.enter(Operations11.dse);
    expect(m.memory.registers.index, Value.fromDouble(2));

    // ISG on R_I = 0 with step-default-1: 0 → 1, skip since 1 > 0.
    m.memory.registers.index = Value.zero;
    tc.enter(Operations.fShift);
    tc.enter(Operations11.isg);
    expect(m.memory.registers.index, Value.fromDouble(1));

    // Program: integer R_I = 3 should loop exactly three times via DSE
    // (3 → 2, 2 → 1, 1 → 0 + skip), then RTN.
    //   LBL A: ISG R_I dummy (no, use stats reg as counter), GSB B (counts), DSE, GTO A, RTN
    //   LBL B: 1, +, RTN
    // Simpler: count iterations into R0 directly.
    //   LBL A: 1, STO + 0, DSE, GTO A, RTN
    m.memory.registers.index = Value.fromDouble(3);
    m.memory.registers[0] = Value.zero;
    tc.enter(Operations.pr);
    tc.enter(Operations11.lbl15);
    tc.enter(Operations11.letterLabelA);
    tc.enter(Operations.n1);
    tc.enter(Operations11.sto15);
    tc.enter(Operations11.plus);
    tc.enter(Operations.n0);
    tc.enter(Operations.fShift);
    tc.enter(Operations11.dse);
    tc.enter(Operations11.gto);
    tc.enter(Operations11.letterLabelA);
    tc.enter(Operations.rtn);
    tc.enter(Operations.pr);

    tc.enter(Operations11.gsb);
    tc.enter(Operations11.letterLabelA);
    expect(await out.moveNext(), true);
    expect(out.current, ProgramEvent.done);
    expect(m.memory.registers[0], Value.fromDouble(3),
        reason: 'DSE loop should execute body exactly 3 times on R_I=3');
    expect(m.memory.registers.index, Value.zero,
        reason: 'final DSE call landed on 0 and skipped the GTO');
  });

  test('Built-in self tests 11C', () async {
    await SelfTests11(inCalculator: false).runAll();
  });

  test('11C opcode test', opcodeTest11C);
}
