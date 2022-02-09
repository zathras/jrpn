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

import 'package:jrpn/m/model.dart';

import 'matrix.dart';

class Model15<OT extends ProgramOperation> extends Model<OT> {
  final List<Matrix> matrices = [
    Matrix('A'),
    Matrix('B'),
    Matrix('C'),
    Matrix('D'),
    Matrix('E')
  ];

  final ProgramInstruction<OT> Function(OT, int) _newProgramInstructionF;
  final List<List<MKey<OT>?>> Function() _getLogicalKeys;

  Model15(this._getLogicalKeys, this._newProgramInstructionF)
      : super(DisplayMode.fix(4, false), 56, 10);

  // It's a little hacky, but we need to defer initialization of
  // logicalKeys until after the controller initializes
  // Operations.numberOfFlags.  This seems the
  // least bad option.
  @override
  late final List<List<MKey<OT>?>> logicalKeys = _getLogicalKeys();

  @override
  ProgramInstruction<OT> newProgramInstruction(OT operation, int argValue) =>
      _newProgramInstructionF(operation, argValue);

  @override
  reset() {
    super.reset();
    displayMode = DisplayMode.fix(4, false);
  }

  @override
  late final Memory15<OT> memory = Memory15<OT>(this, memoryNybbles: 66 * 14);
  // cf. 16C manual, page 214.  The index register doesn't count against
  // our storage, so that's space for 66 total registers, of 14 nybbles each.

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
  String get modelName => '15C';

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

  @override
  void setFlag(int i, bool v) {
    if (i == 8) {
      isComplexMode = v;
    } else {
      super.setFlag(i, v);
    }
  }

  @override
  set isComplexMode(bool v) {
    if (v && !isComplexMode) {
      memory.policy.checkAvailable(5);
      // Might throw CalculatorError
    }
    super.setFlag(8, v);
    if (v != isComplexMode) {
      setupComplex(
          v ? List<Value>.filled(4, Value.zero, growable: false) : null);
    }
  }

  @override
  bool get errorBlink => floatOverflow;
  @override
  void resetErrorBlink() => setFlag(9, false);

  @override
  String formatValue(Value v) {
    final int? mx = v.asMatrix;
    if (mx == null) {
      return super.formatValue(v);
    } else {
      return matrices[mx].toString();
    }
  }
  @override
  void decodeJson(Map<String, dynamic> json, {required bool needsSave}) {
    super.decodeJson(json, needsSave: needsSave);
    isComplexMode = getFlag(8);
  }

  @override
  int get registerNumberBase => 10;

  @override
  LcdContents selfTestContents() => LcdContents(
      hideComplement: false,
      windowEnabled: false,
      mainText: '-8,8,8,8,8,8,8,8,8,8,',
      cFlag: false,
      complexFlag: true,
      euroComma: false,
      rightJustify: false,
      bits: 64,
      sign: SignMode.unsigned,
      wordSize: 64,
      gFlag: true,
      prgmFlag: true,
      shift: ShiftKey.g,
      trigMode: TrigMode.grad,
      extraShift: ShiftKey.f);
}

class MemoryPolicy15 extends MemoryPolicy {
  final Memory15 _memory;

  MemoryPolicy15(this._memory);

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
      throw CalculatorError(4);
    }
  }
}

/// HP 15C's memory.  Like in the HP 16C, registers and programs are
/// stored by the nybble.  However, matrices, the imaginary stack, and
/// storage for solve/integrate just deduct from the memory otherwise
/// available, but don't actually use it.
///
/// On the 16C it made more sense to store the registers by the nybble,
/// since register size changes with the word size, rounded up to the nearest
/// nybble.  The 16C's memory contents aren't changed when the word size
/// changes, and while the mapping of the memory interpretation isn't specified,
/// the fact that a temporary change in word size doesn't lose information in
/// the registers is.
///
/// On the 15C, there's nothing like this behavior; registers are always
/// 14 nybbles.  We keep the user registers in the common storage, since
/// we inherit that from our superclass, but the other uses of the
/// register pool storage use regular dart structures for their underlying
/// storage.
class Memory15<OT extends ProgramOperation> extends Memory<OT> {

  @override
  final Model15<OT> model;

  @override
  late final MemoryPolicy15 policy = MemoryPolicy15(this);

  int _numRegisters = 20;

  Memory15(this.model, {required int memoryNybbles})
      : super(memoryNybbles: memoryNybbles);

  int get numRegisters => _numRegisters;
  set numRegisters(int v) {
    policy.checkAvailable(v - _numRegisters);
    _numRegisters = v;
  }

  /// @@ TODO
  /// Number of uncommitted registers available in the pool.
  int get availableRegisters {
    int result = totalNybbles ~/ 14;
    assert(totalNybbles % 14 == 0);
    result -= numRegisters;
    result -= program.programBytes ~/ 7;
    assert(totalNybbles % 7 == 0);
    if (model.isComplexMode) {
      result -= 5;
    }
    for (final m in model.matrices) {
      result -= m.length;
    }
    return result;
  }
}

class ProgramInstruction15<OT extends ProgramOperation>
    extends ProgramInstruction<OT> {
  ProgramInstruction15(OT op, int argValue) : super(op, argValue);

  @override
  String get programDisplay {
    if (op.maxArg == 0) {
      return rightJustify(op.programDisplay, 6);
    }
    final String as;
    if (argIsParenI) {
      as = '24';
    } else if (argIsI) {
      as = '25';
    } else {
      final av = argValue - op.arg!.desc.r0ArgumentValue;
      assert(av >= 0 && av < 25);
      if (av < 10) {
        as = ' ${av.toRadixString(10)}';
      } else if (av < 20) {
        as = ' .${(av - 10).toRadixString(10)}';
      } else {
        // A..F
        as = '1${av - 19}';
      }
    }
    return rightJustify('${op.programDisplay}$as', 6);
  }

  @override
  String get programListing {
    final String as;
    if (op.maxArg > 0) {
      if (argIsParenI) {
        as = ' (i)';
      } else if (argIsI) {
        as = ' I';
      } else {
        final av = argValue - op.arg!.desc.r0ArgumentValue;
        assert(av >= 0 && av < 25);
        if (av < 20) {
          as = ' ${argValue.toRadixString(10)}';
        } else {
          final cc = 'A'.codeUnitAt(0) + av - 20;
          as = ' ${String.fromCharCode(cc)}';
        }
      }
    } else {
      as = '';
    }
    return '${op.name}$as';
  }
}
