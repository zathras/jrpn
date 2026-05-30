/*
Copyright (c) 2021-2024 William Foote

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

library;

import 'dart:math' as dart;

import 'package:jrpn/m/model.dart';

class Model11<OT extends ProgramOperation> extends Model<OT> {
  final ProgramInstruction<OT> Function(OT, ArgDone) _newProgramInstructionF;
  final List<List<MKey<OT>?>> Function() _getLogicalKeys;

  @override
  bool get userMode => _userMode;
  void set userMode(bool v) {
    _userMode = v;
    needsSave = true;
  }

  bool _userMode = false;

  // Stub left in place: the deferred-on-button-up mechanism (used on 15C
  // for matrix and indirect-recall ops) has no users on 11C, but the
  // controller still polls it. Always null here.
  bool Function()? deferToButtonUp;

  Model11(this._getLogicalKeys, this._newProgramInstructionF)
    : super(DisplayMode.fix(4, false), 56, 10);

  // It's a little hacky, but we need to defer initialization of
  // logicalKeys until after the controller initializes
  // Operations.numberOfFlags.  This seems the
  // least bad option.
  @override
  late final List<List<MKey<OT>?>> logicalKeys = _getLogicalKeys();

  @override
  ProgramInstruction<OT> newProgramInstruction(OT operation, ArgDone arg) =>
      _newProgramInstructionF(operation, arg);

  final rand = RandomGenerator();

  @override
  void reset() {
    userMode = false;
    displayMode = DisplayMode.fix(4, false);
    super.reset();
    rand.reset();
    trigMode = TrigMode.deg;
    memory.program.suspendedProgram?.abort();
    memory.program.suspendedProgram = null;
    assert(memory.program.runner == null);
    memory.program.runner?.abort(); // Should be null, but be conservative
    memory.program.runner = null;
    memory.numRegisters = 20;
  }

  @override
  late final Memory11<OT> memory = Memory11<OT>(this, memoryNybbles: 29 * 14);
  // HP-11C pool: 20 convertible data registers + 9 register-equivalents
  // of permanent program memory (63 base program lines / 7 lines per
  // register-equivalent) = 29 register-equivalents × 14 nybbles each.
  // R_I is held outside this pool.

  @override
  bool get displayLeadingZeros => false;

  @override
  bool get cFlag => false;

  @override
  set cFlag(bool v) {
    assert(false);
  }

  @override
  bool get gFlag => false;

  @override
  set gFlag(bool v) {
    assert(false);
  }

  @override
  CalculatorModelKind get kind => CalculatorModelKind.jrpn11;

  @override
  int get returnStackSize => 7;

  @override
  bool get floatOverflow => getFlag(9);

  @override
  set floatOverflow(bool v) {
    if (v) {
      setFlag(9, v);
    }
  }

  // 11C is real-only: complex mode cannot be entered by any user action.
  // SF 8 still sets the underlying flag bit (so program logic that polls
  // flag 8 keeps working), but there is no side effect into complex mode.
  @override
  set isComplexMode(bool v) {}

  @override
  bool get errorBlink => floatOverflow;
  @override
  void resetErrorBlink() => setFlag(9, false);

  @override
  Map<String, Object> toJson() {
    final r = super.toJson();
    r['numRegisters'] = memory.numRegisters;
    r['lastRandom'] = rand.lastValue;
    r['userMode'] = userMode;
    return r;
  }

  @override
  void decodeJson(Map<String, dynamic> json, {required bool needsSave}) {
    super.decodeJson(json, needsSave: needsSave);
    memory.numRegisters = json['numRegisters'] as int;
    final Object? lastRandom = json['lastRandom'];
    if (lastRandom is double) {
      rand.setNoReseed(lastRandom);
    }
    final Object? um = json['userMode'];
    if (um is bool) {
      _userMode = um;
    }
  }

  @override
  int get registerNumberBase => 10;

  @override
  LcdContents selfTestContents() => LcdContents(
    hideComplement: false,
    longNumbers: LongNumbersSetting.window,
    mainText: '-8,8,8,8,8,8,8,8,8,8,',
    cFlag: false,
    complexFlag: true,
    euroComma: false,
    rightJustify: false,
    bits: 64,
    sign: SignMode.float,
    wordSize: null,
    gFlag: true,
    prgmFlag: true,
    shift: ShiftKey.g,
    trigMode: TrigMode.grad,
    userMode: true,
    extraShift: ShiftKey.f,
    lcdDigits: 11,
  );

}

///
/// Implementation of the RAN # key, and sto/rcl
///
/// Note that the generator isn't re-seeded with the last value every time
/// a number is requested.  That means that the sequence:
///    STO RAN #
///    RAN #
///    STO RAN #
///    RAN #
/// will yield a different result than:
///    STO RAN #
///    RAN #
///    RAN #
///  whereas the two will generate identical results on a real 15C.
///
/// Re-seeding each time would presumably generate worse results that
/// Dart's built-in function, and I'm a little concerned it might even
/// lead to pathological cases, like small cycles in certain cases.
///
class RandomGenerator {
  var _generator = dart.Random();
  double _lastValue = 0;

  RandomGenerator() {
    nextValue;
  }

  void setSeed(double seed) {
    seed = seed.abs();
    if (seed > 1) {
      final exp = log10(seed).floorToDouble() + 1;
      seed /= dart.pow(10.0, exp);
    }
    _lastValue = seed;
    int s = ((seed - 0.5) * dart.pow(2.0, 52.0)).round();
    _generator = dart.Random(s);
    // Stupid JavaScript ints are limited to +- 2^52. To be conservative, I
    // go for 2^51
  }

  ///
  /// Set from JSON on startup
  ///
  void setNoReseed(double val) => _lastValue = val;

  double get lastValue => _lastValue;

  double get nextValue => _lastValue = _generator.nextDouble();

  void reset() {
    _generator = dart.Random();
    nextValue;
  }
}

class MemoryPolicy11 extends MemoryPolicy {
  final Memory11 _memory;

  MemoryPolicy11(this._memory);

  @override
  void checkRegisterAccess(int i) {
    if (i < 0 || i >= _memory.numRegisters) {
      throw CalculatorError(3);
    }
  }

  @override
  String showMemory() {
    String dd = (_memory.numRegisters - 1).toString().padLeft(2);
    String uu = (_memory.availableRegisters).toString().padLeft(2);
    String pp = (_memory.program.programBytes ~/ 7).toString().padLeft(2);
    String b = (_memory.program.bytesToNextAllocation).toString();
    return '$dd $uu $pp-$b';
  }

  /// Throws CalculatorError(10) if the needed register memory isn't available
  void checkAvailable(int registers) {
    if (registers > _memory.availableRegisters) {
      throw CalculatorError(10);
    }
  }

  @override
  void checkExtendProgramMemory() {
    if (_memory.availableRegisters < 1) {
      // 11C auto-converts the next storage register to 7 more lines of
      // program memory. Order is descending JRPN index: R.9 first, then
      // R.8, … R.0, R9, … R0. Once all 20 convertible registers are
      // gone (only R_I remains), throw Error 4.
      if (_memory.numRegisters > 0) {
        _memory.numRegisters = _memory.numRegisters - 1;
      } else {
        throw CalculatorError(4);
      }
    }
  }

  @override
  void onProgramMemoryShrunk() {
    // Reverse direction of checkExtendProgramMemory: when deleting a
    // line frees a register-equivalent and we previously converted a
    // register away, hand one back. The newly-restored register's
    // storage may still hold leftover program bytes (deleteCurrent
    // only zeros the trailing bytes around the deletion point), so we
    // explicitly write Value.zero into it.
    while (_memory.availableRegisters > 0 &&
        _memory.numRegisters < Memory11.initialNumRegisters) {
      final newIndex = _memory.numRegisters;
      _memory.numRegisters = newIndex + 1;
      _memory.registers[newIndex] = Value.zero;
    }
  }

  @override
  int get maxProgramBytes {
    int regs = _memory.availableRegistersWithProgram(null);
    regs += _memory.program.programBytes ~/ 7;
    return regs * 7;
  }
}

/// HP-11C's memory. Registers and programs share a single 406-nybble
/// pool: 14 nybbles per register, 7 program bytes per register-equivalent.
/// The user trades data registers for program memory automatically
/// (Phase 7's auto-conversion); R_I is held outside this pool.
class Memory11<OT extends ProgramOperation> extends Memory<OT> {
  @override
  final Model11<OT> model;

  @override
  late final MemoryPolicy11 policy = MemoryPolicy11(this);

  ///
  /// Number of registers, not including rI
  ///
  int _numRegisters = initialNumRegisters;

  /// Initial / maximum number of convertible storage registers on the
  /// 11C (R0..R9 and R.0..R.9). R_I is held separately.
  static const int initialNumRegisters = 20;

  Memory11(this.model, {required super.memoryNybbles});

  @override
  void initializeSystem(OperationMap<OT> layout, OT lbl, OT rtn) => program =
      ProgramMemory11<OT>(this, layout, model.returnStackSize, lbl, rtn);

  int get numRegisters => _numRegisters;
  set numRegisters(int v) {
    policy.checkAvailable(v - _numRegisters);
    for (int i = v; i < _numRegisters; i++) {
      registers[i] = Value.zero;
    }
    _numRegisters = v;
    model.needsSave = true;
  }

  /// Number of uncommitted registers available in the pool.
  int get availableRegisters =>
      availableRegistersWithProgram(program.runner ?? program.suspendedProgram);

  @override
  String? checkMemorySize() {
    final a = availableRegisters;
    if (a < 0) {
      return 'New memory size too small.\n'
          'Available registers would be $a.';
    }
    return null;
  }

  int availableRegistersWithProgram(MProgramRunner? runner) {
    int result = totalNybbles ~/ 14;
    result -= numRegisters;
    result -= program.programBytes ~/ 7;
    result -= runner?.registersRequired ?? 0;
    return result;
  }
}

class ProgramMemory11<OT extends ProgramOperation> extends ProgramMemory<OT> {
  final List<int> _lblOpcodes;

  ProgramMemory11(
    super.memory,
    super.layout,
    super.returnStackSize,
    OT lbl,
    OT super.rtn,
  ) : _lblOpcodes = _makeLblOpcodes(lbl);

  static List<int> _makeLblOpcodes(ProgramOperation lbl) {
    /// Because LBL . n is two-byte, we have to chase down the opcodes
    /// assigned to the LBL instruction.
    final List<int?> table = List.filled(25, null);
    void visit(final Arg arg) {
      if (arg is KeyArg) {
        final ad = arg.child as ArgDone;
        final nv = arg.key.numericValue!;
        table[nv] = ad.opcode;
      } else if (arg is ArgAlternates) {
        for (final c in arg.children) {
          visit(c);
        }
      } else if (arg is DigitArg) {
        arg.visitChildren((nv, ad) => table[nv] = ad.opcode);
      } else {
        assert(false);
      }
    }

    visit(lbl.arg);
    return List.generate(table.length, (i) => table[i]!);
  }

  @override
  void goto(int label) {
    if (label < 0) {
      currentLine = -label;
    } else if (label >= _lblOpcodes.length) {
      throw CalculatorError(4);
    } else {
      gotoOpCode(_lblOpcodes[label]);
    }
  }
}

double log10(double val) => dart.log(val) * dart.log10e;
