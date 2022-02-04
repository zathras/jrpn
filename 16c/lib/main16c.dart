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

import 'package:flutter/material.dart';

import 'package:jrpn/c/controller.dart';
import 'package:jrpn/c/operations.dart';
import 'package:jrpn/c/states.dart';
import 'package:jrpn/generic_main.dart';
import 'package:jrpn/m/model.dart';
import 'package:jrpn/v/buttons.dart';
import 'package:jrpn/v/main_screen.dart';

import 'back_panel16c.dart';
import 'tests16c.dart';

void main() async => genericMain(Jrpn(Controller16(Model16())));

class Model16 extends Model<Operation> {
  Model16() : super(DisplayMode.hex, 16, 6);

  @override
  List<List<MKey<Operation>?>> get logicalKeys => _logicalKeys;

  //
  // See Model.logicalKeys.  This table determines the operation opcodes.
  // Changing the order here would render old JSON files of the
  // calculator's state obsolete.
  static final List<List<MKey<Operation>?>> _logicalKeys = [
    [
      MKey(Operations16.letterA, Operations16.sl, Operations16.lj),
      MKey(Operations16.letterB, Operations16.sr, Operations16.asr),
      MKey(Operations16.letterC, Operations16.rl, Operations16.rlc),
      MKey(Operations16.letterD, Operations16.rr, Operations16.rrc),
      MKey(Operations16.letterE, Operations16.rln, Operations16.rlcn),
      MKey(Operations16.letterF, Operations16.rrn, Operations16.rrcn),
      MKey(Operations.n7, Operations16.maskl, Operations16.poundB),
      MKey(Operations.n8, Operations16.maskr, Operations.abs),
      MKey(Operations.n9, Operations16.rmd, Operations16.dblr),
      MKey(Operations.div, Operations16.xor, Operations16.dblDiv),
    ],
    [
      MKey(Operations.gsb, Operations.xSwapParenI, Operations.rtn),
      MKey(Operations.gto, Operations.xSwapI, Operations16.lbl),
      MKey(Operations16.hex, Operations16.showHex, Operations16.dsz),
      MKey(Operations16.dec, Operations16.showDec, Operations16.isz),
      MKey(Operations16.oct, Operations16.showOct, Operations.sqrtOp),
      MKey(Operations16.bin, Operations16.showBin, Operations.reciprocal),
      MKey(Operations.n4, Operations16.sb, Operations.sf),
      MKey(Operations.n5, Operations16.cb, Operations.cf),
      MKey(Operations.n6, Operations16.bQuestion, Operations.fQuestion),
      MKey(Operations.mult, Operations16.and, Operations16.dblx),
    ],
    [
      MKey(Operations.rs, Operations16.parenI, Operations.pr),
      MKey(Operations.sst, Operations16.I, Operations.bst),
      MKey(Operations.rDown, Operations.clearPrgm, Operations.rUp),
      MKey(Operations.xy, Operations.clearReg, Operations.pse),
      MKey(Operations.bsp, Operations.clearPrefix, Operations.clx),
      MKey(Operations.enter, Operations16.window, Operations.lstx),
      MKey(Operations.n1, Operations16.onesCompl, Operations.xLEy),
      MKey(Operations.n2, Operations16.twosCompl, Operations.xLT0),
      MKey(Operations.n3, Operations16.unsign, Operations.xGTy),
      MKey(Operations.minus, Operations16.not, Operations.xGT0),
    ],
    [
      MKey(Operations.onOff, Operations.onOff, Operations.onOff),
      MKey(Operations.fShift, Operations.fShift, Operations.fShift),
      MKey(Operations.gShift, Operations.gShift, Operations.gShift),
      MKey(Operations16.sto, Operations16.wSize, Operations16.windowRight),
      MKey(Operations16.rcl, Operations16.floatKey, Operations16.windowLeft),
      null,
      MKey(Operations.n0, Operations.mem, Operations.xNEy),
      MKey(Operations.dot, Operations.status, Operations.xNE0),
      MKey(Operations.chs, Operations.eex, Operations.xEQy),
      MKey(Operations.plus, Operations16.or, Operations.xEQ0),
    ]
  ];

  @override
  bool get displayLeadingZeros => getFlag(3);
  @override
  bool get cFlag => getFlag(4);
  @override
  set cFlag(bool v) => setFlag(4, v);
  @override
  bool get gFlag => getFlag(5);
  @override
  set gFlag(bool v) => setFlag(5, v);

  @override
  String get modelName => '16C';

  @override
  ProgramInstruction<Operation> newProgramInstruction(
          Operation operation, int argValue) =>
      ProgramInstruction16(operation, argValue);

  @override
  int get returnStackSize => 4;

  @override
  bool get floatOverflow => gFlag;
  @override
  set floatOverflow(bool v) => gFlag = v;

  @override
  bool get errorBlink => false;

  @override
  int get registerNumberBase => 16;

  @override
  LcdContents selfTestContents() => LcdContents(
      hideComplement: false,
      windowEnabled: false,
      mainText: '-8,8,8,8,8,8,8,8,8,8,',
      cFlag: true,
      complexFlag: false,
      euroComma: false,
      rightJustify: false,
      bits: 64,
      sign: SignMode.unsigned,
      wordSize: 64,
      gFlag: true,
      prgmFlag: true,
      shift: ShiftKey.g,
      trigMode: TrigMode.deg,
      extraShift: ShiftKey.f);
}

class Operations16 extends Operations {

  static final letterA = NumberEntry('A', 10);
  static final letterB = NumberEntry('B', 11);
  static final letterC = NumberEntry('C', 12);
  static final letterD = NumberEntry('D', 13);
  static final letterE = NumberEntry('E', 14);
  static final letterF = NumberEntry('F', 15);


  static final NormalOperation hex = NormalOperation(
      calc: (Model m) => m.displayMode = DisplayMode.hex,
      stackLift: StackLift.neutral,
      name: 'HEX');

  static final NormalOperation dec = NormalOperation(
      calc: (Model m) => m.displayMode = DisplayMode.decimal,
      stackLift: StackLift.neutral,
      name: 'DEC');

  static final NormalOperation oct = NormalOperation(
      calc: (Model m) => m.displayMode = DisplayMode.oct,
      stackLift: StackLift.neutral,
      name: 'OCT');

  static final NormalOperation bin = NormalOperation(
      calc: (Model m) => m.displayMode = DisplayMode.bin,
      stackLift: StackLift.neutral,
      name: 'BIN');

  static final NormalArgOperation sto = NormalArgOperation(
      arg: OperationArg.both(
          desc: const ArgDescription16C(maxArg: 33),
          calc: (Model m, int arg) =>
              m.memory.registers.setValue(arg, sto.arg, m.x)),
      name: 'STO');

  static final NormalArgOperation rcl = NormalArgOperation(
      arg: OperationArg.both(
          desc: const ArgDescription16C(maxArg: 33),
          pressed: (ActiveState s) => s.liftStackIfEnabled(),
          calc: (Model m, int arg) =>
          m.x = m.memory.registers.getValue(arg, rcl.arg)),
      name: 'RCL');

  static final NormalOperation sl = NormalOperation.intOnly(
      intCalc: (Model m) {
        m.cFlag = m.x.internal & m.signMask != BigInt.zero;
        m.resultX = Value.fromInternal((m.x.internal << 1) & m.wordMask);
      },
      name: 'SL');

  static final NormalOperation sr = NormalOperation.intOnly(
      intCalc: (Model m) {
        m.cFlag = m.x.internal & BigInt.one != BigInt.zero;
        m.resultX = Value.fromInternal(m.x.internal >> 1);
      },
      name: 'SR');

  static final NormalOperation rl = NormalOperation.intOnly(
      intCalc: (Model m) => m.resultX = _rotateLeft(BigInt.one, m.x, m),
      name: 'RL');

  static final NormalOperation rr = NormalOperation.intOnly(
      intCalc: (Model m) => m.resultX = _rotateRight(BigInt.one, m.x, m),
      name: 'RR');

  static final NormalOperation rln = NormalOperation.intOnly(
      intCalc: (Model m) => m.popSetResultX = _rotateLeft(m.xI.abs(), m.y, m),
      name: 'RLn');

  static final NormalOperation rrn = NormalOperation.intOnly(
      intCalc: (Model m) => m.popSetResultX = _rotateRight(m.xI.abs(), m.y, m),
      name: 'RRn');

  static final NormalOperation maskl = NormalOperation.intOnly(
      intCalc: (Model m) => m.resultX = Value.fromInternal(
          m.wordMask ^ _maskr(m.wordSize - _numberOfBits(m.xI.abs(), m))),
      name: 'MASKL');

  static final NormalOperation maskr = NormalOperation.intOnly(
      intCalc: (Model m) =>
      m.resultX = Value.fromInternal(_maskr(_numberOfBits(m.xI.abs(), m))),
      name: 'MASKR');

  static final NormalOperation rmd = NormalOperation.intOnly(
      intCalc: (Model m) {
        try {
          BigInt xi = m.xI;
          BigInt yi = m.yI;
          m.popSetResultXI = yi.remainder(xi);
          // ignore: avoid_catches_without_on_clauses
        } catch (e) {
          throw CalculatorError(0);
        }
      },
      name: 'RMD');

  static final NormalOperation xor = NormalOperation.intOnly(
      intCalc: (Model m) =>
      m.popSetResultX = Value.fromInternal(m.x.internal ^ m.y.internal),
      name: 'XOR');

  static final NormalOperation showHex = NormalOperation(
      calc: null,
      pressed: (ActiveState cs) => cs.handleShow(DisplayMode.hex),
      stackLift: StackLift.neutral,
      name: 'SHOW HEX');

  static final NormalOperation showDec = NormalOperation(
      calc: null,
      pressed: (ActiveState cs) => cs.handleShow(DisplayMode.decimal),
      stackLift: StackLift.neutral,
      name: 'SHOW DEC');

  static final NormalOperation showOct = NormalOperation(
      calc: null,
      pressed: (ActiveState cs) => cs.handleShow(DisplayMode.oct),
      stackLift: StackLift.neutral,
      name: 'SHOW OCT');

  static final NormalOperation showBin = NormalOperation(
      calc: null,
      pressed: (ActiveState cs) => cs.handleShow(DisplayMode.bin),
      stackLift: StackLift.neutral,
      name: 'SHOW BIN');

  static final NormalOperation sb = NormalOperation.intOnly(
      intCalc: (Model m) => m.popSetResultX = Value.fromInternal(
          m.y.internal | (BigInt.one << _bitNumber(m.xI.abs(), m))),
      name: 'SB');

  static final NormalOperation cb = NormalOperation.intOnly(
      intCalc: (Model m) => m.popSetResultX = Value.fromInternal(m.y.internal &
      ((BigInt.one << _bitNumber(m.xI.abs(), m)) ^ m.wordMask)),
      name: 'CB');

  static final NormalOperation bQuestion = NormalOperation(
      name: 'B?',
      calc: (Model m) {
        m.lastX = m.x;
        bool r = (m.y.internal & (BigInt.one << _bitNumber(m.xI.abs(), m))) !=
            BigInt.zero;
        if (m.isRunningProgram) {
          m.program.doNextIf(r);
        }
        m.popStack(); // Even when not running a program
      });

  static final NormalOperation and = NormalOperation.intOnly(
      intCalc: (Model m) =>
      m.popSetResultX = Value.fromInternal(m.x.internal & m.y.internal),
      name: 'AND');

  ///
  /// The HP 16's (i) operation, related to the index register
  ///
  static final NormalOperation parenI = NormalOperation(
      pressed: (ActiveState s) => s.liftStackIfEnabled(),
      calc: (Model m) {
        m.x = m.memory.registers.indirectIndex;
        m.display.displayX();
      },
      name: '(i)');

  ///
  /// The HP 16's I operation, related to the index register
  ///
  static final NormalOperation I = NormalOperation(
      pressed: (ActiveState s) => s.liftStackIfEnabled(),
      calc: (Model m) {
        m.x = m.memory.registers.index;
        m.display.displayX();
      },
      name: 'I');

  static final NormalArgOperation window = NormalArgOperation(
      arg: OperationArg.intOnly(
          desc: const ArgDescription16C(maxArg: 7),
          intCalc: (Model m, int arg) => m.display.window = arg * 8),
      stackLift: StackLift.neutral,
      name: 'WINDOW');

  static final NormalOperation onesCompl = NormalOperation.intOnly(
      intCalc: (Model m) => m.integerSignMode = SignMode.onesComplement,
      stackLift: StackLift.neutral,
      name: "1's");

  static final NormalOperation twosCompl = NormalOperation.intOnly(
      intCalc: (Model m) => m.integerSignMode = SignMode.twosComplement,
      stackLift: StackLift.neutral,
      name: "2's");

  static final NormalOperation unsign = NormalOperation.intOnly(
      intCalc: (Model m) => m.integerSignMode = SignMode.unsigned,
      stackLift: StackLift.neutral,
      name: 'UNSGN');

  static final NormalOperation not = NormalOperation.intOnly(
      intCalc: (Model m) =>
      m.resultX = Value.fromInternal(m.x.internal ^ m.wordMask),
      name: 'NOT');

  static final NormalOperation wSize = NormalOperation.intOnly(
      intCalc: (Model m) {
        m.lastX = m.x;
        m.wordSize = m.xI.toInt().abs();
        m.popStack();
      },
      name: 'WSIZE');

  /// The 16C's float key
  static final NormalArgOperation floatKey = NormalArgOperation(
      stackLift: StackLift.neutral, // But see also FloatKeyArg.onArgComplete()
      arg: FloatKeyArg(
          desc: const ArgDescription16C(maxArg: 10),
          calc: (Model m, int arg) {
            m.floatOverflow = false;
            m.displayMode = DisplayMode.float(arg);
          }),
      name: 'FLOAT');

  static final NormalOperation or = NormalOperation.intOnly(
      intCalc: (Model m) =>
      m.popSetResultX = Value.fromInternal(m.x.internal | m.y.internal),
      name: 'OR');

  static final NormalOperation lj = NormalOperation.intOnly(
      intCalc: (Model m) {
        int shifts = 0;
        m.lastX = m.x;
        BigInt val = m.x.internal;
        if (val != BigInt.zero) {
          while (val & m.signMask == BigInt.zero) {
            shifts++;
            val <<= 1;
          }
        }
        m.pushStack();
        m.y = Value.fromInternal(val);
        m.xI = BigInt.from(shifts);
      },
      name: 'LJ');

  static final NormalOperation asr = NormalOperation.intOnly(
      intCalc: (Model m) {
        m.lastX = m.x;
        BigInt x = m.x.internal;
        BigInt newSignBit;
        if (m.integerSignMode == SignMode.unsigned) {
          newSignBit = BigInt.zero;
        } else {
          newSignBit = x & m.signMask;
        }
        m.cFlag = x & BigInt.one != BigInt.zero;
        m.resultX = Value.fromInternal((x >> 1) | newSignBit);
      },
      name: 'ASR');

  static final NormalOperation rlc = NormalOperation.intOnly(
      intCalc: (Model m) => m.resultX = _rotateLeftCarry(BigInt.one, m.x, m),
      name: 'RLC');

  static final NormalOperation rrc = NormalOperation.intOnly(
      intCalc: (Model m) =>
      m.resultX = _rotateLeftCarry(BigInt.from(m.wordSize), m.x, m),
      name: 'RRC');

  static final NormalOperation rlcn = NormalOperation.intOnly(
      intCalc: (Model m) => m.popSetResultX = _rotateLeftCarry(m.xI, m.y, m),
      name: 'RLCn');

  static final NormalOperation rrcn = NormalOperation.intOnly(
      intCalc: (Model m) => m.popSetResultX = _rotateRightCarry(m.xI, m.y, m),
      name: 'RRCn');

  static final NormalOperation poundB = NormalOperation.intOnly(
      intCalc: (Model m) {
        int count = 0;
        BigInt v = m.x.internal;
        while (v > BigInt.zero) {
          if ((v & BigInt.one) != BigInt.zero) {
            count++;
          }
          v = v >> 1;
        }
        m.resultX = Value.fromInternal(BigInt.from(count));
      },
      name: '#B');

  static final NormalOperation dblr =
  NormalOperation.intOnly(intCalc: _doubleIntRemainder, name: 'DBLR');

  static final NormalOperation dblDiv =
  NormalOperation.intOnly(intCalc: _doubleIntDivide, name: 'DBL/');

  static final NormalArgOperation lbl = NormalArgOperation(
      arg: OperationArg.both(
          desc: const ArgDescription16C(maxArg: 15), calc: (_, __) {}),
      name: 'LBL');

  static final BranchingOperation dsz = BranchingOperation(
      name: 'DSZ',
      calc: (Model m) {
        Value v = m.memory.registers.incrementI(-1);
        m.program.doNextIf(!m.isZero(v));
      });

  static final BranchingOperation isz = BranchingOperation(
      name: 'ISZ',
      calc: (Model m) {
        Value v = m.memory.registers.incrementI(1);
        m.program.doNextIf(!m.isZero(v));
      });

  static final NormalOperation dblx =
  NormalOperation.intOnly(intCalc: _doubleIntMultiply, name: 'DBLx');

  /// Shown as blue "<" on the keyboard - it shifts the number left,
  /// which means the window shifts right.
  static final NormalOperation windowRight = NormalOperation.intOnly(
      stackLift: StackLift.neutral,
      intCalc: (Model m) {
        if (m.display.window > 0) {
          m.display.window = m.display.window - 1;
        }
      },
      name: '<');

  static final NormalOperation windowLeft = NormalOperation.intOnly(
      stackLift: StackLift.neutral,
      intCalc: (Model m) {
        try {
          m.display.window = m.display.window + 1;
        } on CalculatorError catch (_) {}
      },
      name: '>');
}

class ProgramInstruction16 extends ProgramInstruction<Operation> {
  ProgramInstruction16(Operation op, int argValue) : super(op, argValue);

  @override
  String get programDisplay {
    if (op.maxArg > 0) {
      final String as;
      if (argValue < 16) {
        if (argValue == 10 && op.maxArg == 10) {
          as = '48';
          // Special case:  f-FLOAT is the only key that takes arguments
          // from 0 to 10, with 10 being input as ".".  It means "scientific
          // notation," so semantically it's not really "A", and the 16C
          // displays it is 48 (which is ".").  I guess the 16C's behavior
          // makes sense!
        } else {
          as = ' ${argValue.toRadixString(16)}';
        }
      } else if (argIsParenI) {
        as = '31';
      } else if (argIsI) {
        as = '32';
      } else {
        as = ' .${(argValue - 16).toRadixString(16)}';
      }
      return rightJustify('${op.programDisplay}$as', 6);
    } else {
      return rightJustify(op.programDisplay, 6);
    }
  }
}

///
/// The layout of the buttons (part of the view, but retrieved by the
/// controller as part of initialization).
///
class ButtonLayout16 extends ButtonLayout {
  final ButtonFactory factory;
  final double _totalButtonHeight;
  final double _buttonHeight;

  ButtonLayout16(this.factory, this._totalButtonHeight, this._buttonHeight);

  CalculatorButton get a => CalculatorButtonWithLJ(factory, 'A', 'SL',
      'L\u200AJ', Operations16.letterA, Operations16.sl, Operations16.lj, 'A');
  CalculatorButton get b => CalculatorButton(factory, 'B', 'SR', 'ASR',
      Operations16.letterB, Operations16.sr, Operations16.asr, 'B');
  CalculatorButton get c => CalculatorButton(factory, 'C', 'RL', 'RLC',
      Operations16.letterC, Operations16.rl, Operations16.rlc, 'C');
  CalculatorButton get d => CalculatorButton(factory, 'D', 'RR', 'RRC',
      Operations16.letterD, Operations16.rr, Operations16.rrc, 'D');
  CalculatorButton get e => CalculatorButton(factory, 'E', 'RLn', 'RLCn',
      Operations16.letterE, Operations16.rln, Operations16.rlcn, 'E');
  CalculatorButton get f => CalculatorButton(factory, 'F', 'RRn', 'RRCn',
      Operations16.letterF, Operations16.rrn, Operations16.rrcn, 'F');
  CalculatorButton get n7 => CalculatorButton(factory, '7', 'MASKL', '#B',
      Operations.n7, Operations16.maskl, Operations16.poundB, '7');
  CalculatorButton get n8 => CalculatorButton(factory, '8', 'MASKR', 'ABS',
      Operations.n8, Operations16.maskr, Operations.abs, '8');
  CalculatorButton get n9 => CalculatorButton(factory, '9', 'RMD', 'DBLR',
      Operations.n9, Operations16.rmd, Operations16.dblr, '9');
  CalculatorButton get div => CalculatorButton(factory, '\u00F7', 'XOR',
      'DBL\u00F7', Operations.div, Operations16.xor, Operations16.dblDiv, '/');

  CalculatorButton get gsb => CalculatorButton(factory, 'GSB', 'x\u2B0C(i)',
      'RTN', Operations.gsb, Operations.xSwapParenI, Operations.rtn, 'U');
  CalculatorButton get gto => CalculatorButton(factory, 'GTO', 'x\u2B0CI',
      'LBL', Operations.gto, Operations.xSwapI, Operations16.lbl, 'T');
  CalculatorButton get hex => CalculatorButton(factory, 'HEX', '', 'DSZ',
      Operations16.hex, Operations16.showHex, Operations16.dsz, 'I');
  CalculatorButton get dec => CalculatorButton(factory, 'DEC', '', 'ISZ',
      Operations16.dec, Operations16.showDec, Operations16.isz, 'Z');
  CalculatorButton get oct => CalculatorBlueSqrtButton(factory, 'OCT', '',
      '\u221Ax', Operations16.oct, Operations16.showOct, Operations.sqrtOp, 'K');
  CalculatorButton get bin => CalculatorButton(factory, 'BIN', '', '1/x',
      Operations16.bin, Operations16.showBin, Operations.reciprocal, 'L');
  CalculatorButton get n4 => CalculatorButton(factory, '4', 'SB', 'SF',
      Operations.n4, Operations16.sb, Operations.sf, '4');
  CalculatorButton get n5 => CalculatorButton(factory, '5', 'CB', 'CF',
      Operations.n5, Operations16.cb, Operations.cf, '5');
  CalculatorButton get n6 => CalculatorButton(factory, '6', 'B?', 'F?',
      Operations.n6, Operations16.bQuestion, Operations.fQuestion, '6');
  CalculatorButton get mult => CalculatorOnSpecialButton(
      factory,
      '\u00D7',
      'AND',
      'DBLx',
      Operations.mult,
      Operations16.and,
      Operations16.dblx,
      'X*',
      'TST',
      acceleratorLabel: '*\u00d7');
  CalculatorButton get rs => CalculatorButton(factory, 'R/S', '(i)', 'P/R',
      Operations.rs, Operations16.parenI, Operations.pr, '[');
  CalculatorButton get sst => CalculatorButton(factory, 'SST', 'I', 'BST',
      Operations.sst, Operations16.I, Operations.bst, ']');
  CalculatorButton get rdown => CalculatorButton(factory, 'R\u2193', 'PRGM',
      'R\u2191', Operations.rDown, Operations.clearPrgm, Operations.rUp, 'V');
  CalculatorButton get xy => CalculatorButton(factory, 'x\u2B0Cy', 'REG', 'PSE',
      Operations.xy, Operations.clearReg, Operations.pse, 'Y');
  CalculatorButton get bsp => CalculatorButton(
      factory,
      'BSP',
      'PREFIX',
      'CLx',
      Operations.bsp,
      Operations.clearPrefix,
      Operations.clx,
      '\u0008\u007f\uf728',
      acceleratorLabel: '\u2190');
  @override
  CalculatorButton get enter => CalculatorEnterButton(
      factory,
      'E\nN\nT\nE\nR',
      'WINDOW',
      'LSTx',
      Operations.enter,
      Operations16.window,
      Operations.lstx,
      '\n\r',
      extraHeight: factory.height * _totalButtonHeight / _buttonHeight,
      acceleratorLabel: ' \u23ce');
  CalculatorButton get n1 => CalculatorButton(factory, '1', '1\'s', 'x\u2264y',
      Operations.n1, Operations16.onesCompl, Operations.xLEy, '1');
  CalculatorButton get n2 => CalculatorButton(factory, '2', '2\'s', 'x<0',
      Operations.n2, Operations16.twosCompl, Operations.xLT0, '2');
  CalculatorButton get n3 => CalculatorButton(factory, '3', 'UNSGN', 'x>y',
      Operations.n3, Operations16.unsign, Operations.xGTy, '3');
  CalculatorButton get minus => CalculatorOnSpecialButton(
      factory,
      '\u2212',
      'NOT',
      'x>0',
      Operations.minus,
      Operations16.not,
      Operations.xGT0,
      '-',
      'CLR',
      acceleratorLabel: '\u2212');

  CalculatorButton get onOff => CalculatorOnButton(factory, 'ON', '', '',
      Operations.onOff, Operations.onOff, Operations.onOff, 'O', 'OFF');
  CalculatorButton get fShift => CalculatorFButton(factory, 'f', '', '',
      Operations.fShift, Operations.fShift, Operations.fShift, 'M\u0006',
      acceleratorLabel: 'M');
  CalculatorButton get gShift => CalculatorGButton(factory, 'g', '', '',
      Operations.gShift, Operations.gShift, Operations.gShift, 'G\u0007',
      acceleratorLabel: 'G');
  CalculatorButton get sto => CalculatorButton(factory, 'STO', 'WSIZE', '<',
      Operations16.sto, Operations16.wSize, Operations16.windowRight, 'S<');
  CalculatorButton get rcl => CalculatorButton(factory, 'RCL', 'FLOAT', '>',
      Operations16.rcl, Operations16.floatKey, Operations16.windowLeft, 'R>');
  CalculatorButton get n0 => CalculatorButton(factory, '0', 'MEM', 'x\u2260y',
      Operations.n0, Operations.mem, Operations.xNEy, '0');
  CalculatorButton get dot => CalculatorOnSpecialButton(
      factory,
      '\u2219',
      'STATUS',
      'x\u22600',
      Operations.dot,
      Operations.status,
      Operations.xNE0,
      '.',
      '\u2219/\u201a',
      acceleratorLabel: '\u2219');
  CalculatorButton get chs => CalculatorButton(factory, 'CHS', 'EEX', 'x=y',
      Operations.chs, Operations.eex, Operations.xEQy, 'H');
  CalculatorButton get plus => CalculatorButton(factory, '+', 'OR', 'x=0',
      Operations.plus, Operations16.or, Operations.xEQ0, '+=');

  @override
  List<List<CalculatorButton?>> get landscapeLayout => [
        [a, b, c, d, e, f, n7, n8, n9, div],
        [gsb, gto, hex, dec, oct, bin, n4, n5, n6, mult],
        [rs, sst, rdown, xy, bsp, null, n1, n2, n3, minus],
        [onOff, fShift, gShift, sto, rcl, null, n0, dot, chs, plus]
      ];

  @override
  List<List<CalculatorButton?>> get portraitLayout => [
        [onOff, rdown, xy, bsp, fShift, gShift],
        [gsb, gto, hex, dec, oct, bin],
        [a, b, c, d, e, f],
        [rs, sst, n7, n8, n9, div],
        [sto, rcl, n4, n5, n6, mult],
        [null, null, n1, n2, n3, minus],
        [null, null, n0, dot, chs, plus],
      ];
}

class LandscapeButtonFactory16 extends LandscapeButtonFactory {
  LandscapeButtonFactory16(
      BuildContext context, ScreenPositioner screen, RealController controller)
      : super(context, screen, controller);

  @override
  double addUpperGoldLabels(List<Widget> result, Rect pos,
      {required double th,
      required double tw,
      required double bh,
      required double bw}) {
    double y = pos.top;
    result.add(screen.box(
        Rect.fromLTRB(pos.left + 2 * tw - 0.05, y + th - 0.14,
            pos.left + 5 * tw + bw + 0.05, y + th + 0.11),
        CustomPaint(
            painter:
                UpperLabel('SHOW', fTextStyle, height * (0.14 + 0.11) / bh))));
    result.add(screen.box(
        Rect.fromLTRB(pos.left + 2 * tw - 0.05, y + 2 * th - 0.155,
            pos.left + 4 * tw + bw + 0.05, y + 2 * th + 0.065),
        CustomPaint(
            painter: UpperLabel('CLEAR', fTextSmallLabelStyle,
                height * (0.065 + 0.155) / bh))));
    result.add(screen.box(
        Rect.fromLTRB(pos.left + 6 * tw - 0.05, y + 2 * th - 0.155,
            pos.left + 8 * tw + bw + 0.05, y + 2 * th + 0.065),
        CustomPaint(
            painter: UpperLabel('SET COMPL', fTextSmallLabelStyle,
                height * (0.065 + 0.155) / bh))));
    return 0;
  }
}

class PortraitButtonFactory16 extends PortraitButtonFactory {
  PortraitButtonFactory16(
      BuildContext context, ScreenPositioner screen, RealController controller)
      : super(context, screen, controller);

  @override
  double addUpperGoldLabels(List<Widget> result, Rect pos,
      {required double th,
      required double tw,
      required double bh,
      required double bw}) {
    double y = pos.top;
    result.add(screen.box(
        Rect.fromLTWH(pos.left + tw - 0.05, y + 0.07, 2 * tw + bw + 0.10, 0.22),
        CustomPaint(
            painter: UpperLabel('CLEAR', fTextSmallLabelStyle,
                height * (0.065 + 0.155) / bh))));
    result.add(screen.box(
        Rect.fromLTWH(
            pos.left + 2 * tw - 0.05, y + th + 0.18, 3 * tw + bw + 0.10, 0.25),
        CustomPaint(
            painter:
                UpperLabel('SHOW', fTextStyle, height * (0.14 + 0.11) / bh))));
    result.add(screen.box(
        Rect.fromLTWH(pos.left + 2 * tw - 0.05, y + 5 * th + 0.08,
            2 * tw + bw + 0.1, 0.22),
        CustomPaint(
            painter: UpperLabel('SET COMPL', fTextSmallLabelStyle,
                height * (0.065 + 0.155) / bh))));
    return 0.28;
  }
}

class Controller16 extends RealController {
  Controller16(Model<Operation> model) : super(model, _numbers, _shortcuts, Operations16.lbl);

  /// Map from operation that is a short cut to what it's a shortcut for, with
  /// the key as an argument
  static final Map<NormalOperation, ProgramInstruction> _shortcuts = {
    Operations16.I: ProgramInstruction16(Operations16.rcl, Operations16.rcl.arg.desc.indexRegisterNumber),
    Operations16.parenI:
        ProgramInstruction16(Operations16.rcl, Operations16.rcl.arg.desc.indirectIndexNumber)
  };

  /// The numbers.  This must be in order.
  static final List<NumberEntry> _numbers = [
    Operations.n0,
    Operations.n1,
    Operations.n2,
    Operations.n3,
    Operations.n4,
    Operations.n5,
    Operations.n6,
    Operations.n7,
    Operations.n8,
    Operations.n9,
    Operations16.letterA,
    Operations16.letterB,
    Operations16.letterC,
    Operations16.letterD,
    Operations16.letterE,
    Operations16.letterF
  ];

  @override
  Operation get gotoLineNumberKey => Operations.dot;

  @override
  SelfTests newSelfTests({bool inCalculator = true}) =>
      SelfTests16(inCalculator: inCalculator);

  @override
  ButtonLayout getButtonLayout(ButtonFactory factory, double totalHeight,
          double totalButtonHeight) =>
      ButtonLayout16(factory, totalHeight, totalButtonHeight);

  @override
  BackPanel15 getBackPanel() => const BackPanel15();

  @override
  LandscapeButtonFactory getLandscapeButtonFactory(
          BuildContext context, ScreenPositioner screen) =>
      LandscapeButtonFactory16(context, screen, this);

  @override
  PortraitButtonFactory getPortraitButtonFactory(
          BuildContext context, ScreenPositioner screen) =>
      PortraitButtonFactory16(context, screen, this);

  /// Abbreviated key sequences for I used as an argument
  /// cf. 16C manual p. 68
  @override
  Set<Operation> get argIops => _argIops;
  static final Set<Operation> _argIops = {Operations.sst, Operations16.I};

  /// Abbreviated key sequences for (i) used as an argument
  /// cf. 16C manual p. 68
  @override
  Set<Operation> get argParenIops => _argParenIops;
  static final Set<Operation> _argParenIops = {Operations.rs, Operations16.parenI};
}

void _doubleIntMultiply(Model m) {
  BigInt r = m.xI * m.yI; // Signed BigInt, up to 128 bits
  Value big = m.integerSignMode.fromBigInt(r, m.doubleWordStatus);
  m.lastX = m.x;
  m.x = Value.fromInternal(big.internal >> m.wordSize);
  m.y = Value.fromInternal(big.internal & m.wordMask);
  m.gFlag = false; // It can't overflow
  m.cFlag = false;
}

void _doubleIntDivide(Model m) {
  final Value last = m.x;
  final BigInt big = (m.y.internal << m.wordSize) | m.z.internal;
  final BigInt dividend =
  m.integerSignMode.toBigInt(Value.fromInternal(big), m.doubleWordStatus);
  final BigInt divisor = m.xI;
  final BigInt result = dividend ~/ divisor;
  if (result < m.minInt || result > m.maxInt) {
    throw CalculatorError(0);
  }
  m.popStack();
  m.popSetResultXI = result;
  m.lastX = last;
  m.cFlag = dividend.remainder(divisor) != BigInt.zero;
  m.gFlag = false;
}

final BigInt _maxU64 = (BigInt.one << 64) - BigInt.one;

void _doubleIntRemainder(Model m) {
  final Value last = m.x;
  final BigInt big = (m.y.internal << m.wordSize) | m.z.internal;
  final BigInt dividend =
  m.integerSignMode.toBigInt(Value.fromInternal(big), m.doubleWordStatus);
  final BigInt divisor = m.xI;
  final BigInt quotient = dividend ~/ divisor;
  if (quotient.abs() > _maxU64) {
    // Page 54 of the manual says "if it exceeds 64 bits."  I assume they're
    // doing that part unsigned, since it's internal.
    throw CalculatorError(0);
  }
  m.popStack();
  m.popSetResultXI = dividend.remainder(divisor);
  m.lastX = last;
  m.gFlag = false;
  m.cFlag = false;
}

Value _rotateLeft(BigInt nBI, Value arg, Model m) {
  final int n = _rotateCount(nBI, m.wordSize);
  if (n == 0) {
    return arg; // NOP.  n = wordSize isn't NOP, it changes carry.
  }
  BigInt r = _rotateLeftBI(arg.internal, n, m.wordSize);
  m.cFlag = (r & BigInt.one) != BigInt.zero;
  return Value.fromInternal(r);
}

Value _rotateRight(BigInt nBI, Value arg, Model m) {
  final int n = _rotateCount(nBI, m.wordSize);
  if (n == 0) {
    return arg; // NOP.  n = wordSize isn't NOP, it changes carry.
  }
  BigInt r = _rotateLeftBI(arg.internal, m.wordSize - n, m.wordSize);
  m.cFlag = (r & m.signMask) != BigInt.zero;
  return Value.fromInternal(r);
}

Value _rotateLeftCarry(BigInt n, Value arg, Model m) =>
    _rotateLeftCarryI(_rotateCount(n, m.wordSize), arg, m);

Value _rotateRightCarry(BigInt n, Value arg, Model m) =>
    _rotateLeftCarryI(m.wordSize + 1 - _rotateCount(n, m.wordSize), arg, m);

Value _rotateLeftCarryI(final int n, Value argV, Model m) {
  m.lastX = m.x;
  if (n == 0) {
    return argV; // NOP
  }
  final carryMask = BigInt.one << m.wordSize;
  // I'm using the fact that BigInt goes up to 65 bits here.
  final BigInt arg = m.cFlag ? (argV.internal | carryMask) : argV.internal;
  final r = _rotateLeftBI(arg, n, m.wordSize + 1);
  if (r & carryMask == BigInt.zero) {
    m.cFlag = false;
    return Value.fromInternal(r);
  } else {
    m.cFlag = true;
    return Value.fromInternal(r & m.wordMask);
  }
}

int _rotateCount(BigInt v, int wordSize) {
  v = v.abs();
  if (v > BigInt.from(wordSize)) {
    throw CalculatorError(2);
  }
  return v.toInt();
}

BigInt _rotateLeftBI(BigInt arg, int n, int wordSize) {
  assert(n > 0 && n <= wordSize);
  final bottomMask = ((BigInt.one << (wordSize - n)) - BigInt.one);
  // That would be really efficient in C.  One can hope the Dart runtime
  // does a reasonable job of optimizing it, and besides, it doesn't matter.
  return (arg >> (wordSize - n)) | ((arg & bottomMask) << n);
}

int _bitNumber(BigInt n, NumStatus m) {
  final int r = n.toInt(); // clamps to maxint
  if (r >= m.wordSize) {
    throw CalculatorError(2);
  }
  return r;
}

int _numberOfBits(BigInt n, NumStatus m) {
  final int r = n.toInt(); // clamps to maxint
  if (r > m.wordSize) {
    throw CalculatorError(2);
  }
  return r;
}

BigInt _maskr(int n) => (BigInt.one << n) - BigInt.one;
