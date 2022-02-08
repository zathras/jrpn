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

class Model15<OT extends ProgramOperation> extends Model<OT> {

  final ProgramInstruction<OT> Function(OT, int) _newProgramInstructionF;
  final List<List<MKey<OT>?>> Function() _getLogicalKeys;

  Model15(this._getLogicalKeys,
      this._newProgramInstructionF)
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
  late final Memory<OT> memory = Memory<OT>(this, memoryNybbles: 469);

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
    super.setFlag(8, v);
    super.isComplexMode = v;
  }

  @override
  bool get errorBlink => floatOverflow;
  @override
  void resetErrorBlink() => setFlag(9, false);

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
