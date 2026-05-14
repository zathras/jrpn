// ignore_for_file: avoid_print

// 11C opcode snapshot test.
//
// TODO: transitory. While 11C remains byte-identical to 15C, this reuses
// the 15C reference tables (`SEQ_2_CODE` / `expectedOpcodes`). As soon as
// the 11C op table is allowed to diverge from 15C (e.g. when the 11C
// keymap is wired up, or any 11C-specific op is added), fork local
// `expectedOpcodes11c` / `SEQ_2_CODE_11c` into this file and stop
// referencing `ref15`.

import 'package:flutter_test/flutter_test.dart';

import 'opcodes15c.dart' as ref15;
import 'programs.dart';

Future<void> opcodeTest11C() async {
  final c = TestCalculator(for11C: true);
  final instructions = c.model.memory.program.getAllInstructions();
  final tcl = ref15.tclDisplayToOpcode();
  final seen = <String>{};
  for (final instr in instructions) {
    String pd = instr.programDisplay.replaceFirst('-', '').trim();
    while (pd.contains('  ')) {
      pd = pd.replaceFirst('  ', ' ');
    }
    if (pd.contains(',')) {
      pd = pd.replaceAll(',', '_').replaceAll(' ', '');
    } else {
      pd = pd.replaceAll(' ', '_');
    }
    if (pd.startsWith('u_')) {
      pd = '${pd.substring(2)}_u';
    }
    expect(seen.add(pd), true, reason: '$pd previously seen');
    final tclOpcode = tcl.remove(pd);
    expect(tclOpcode == null, false);
    if (instr.opcode <= 0xff) {
      expect(
        tclOpcode!.length,
        2,
        reason:
            '$instr ($tclOpcode, '
            '0x${instr.opcode.toRadixString(16)}) should be two bytes',
      );
    } else {
      expect(
        tclOpcode!.length,
        4,
        reason:
            '$instr ($tclOpcode, '
            '0x${instr.opcode.toRadixString(16)}) should be one byte',
      );
    }
  }
  tcl.remove('44_42_36'); // Synonym for 44_36, sto-random
  final undead = tcl.keys.toList()..sort();
  for (final t in undead) {
    print('$t is undead');
  }
  expect(tcl.length, 0);

  expect(instructions.length, ref15.expectedOpcodes.length);
  for (int i = 0; i < ref15.expectedOpcodes.length; i++) {
    final instr = instructions[i];
    final e = ref15.expectedOpcodes[i];
    expect(instr.opcode, e[0]);
    expect(instr.programDisplay, e[1]);
    expect(instr.programListing, e[2]);
  }

  // Round-trip every instruction through program import/export.
  final mem = c.model.memory;
  for (final instr in instructions) {
    mem.reset();
    mem.program.insert(instr);
    final String exported = mem.program.listing[1];
    mem.reset();
    expect(mem.program.listing.length, 1);
    mem.program.importProgram(exported);
    expect(
      mem.program[1].opcode,
      instr.opcode,
      reason:
          '${mem.program[1].programListing}'
          ' != ${instr.programListing} ($exported)',
    );
  }
}
