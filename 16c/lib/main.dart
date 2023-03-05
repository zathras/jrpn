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
import 'package:jrpn/v/isw.dart';

import 'back_panel16c.dart';
import 'tests16c.dart';

void main(List<String> args) async {
  if (!await InternalStateWindow.takeControl(args)) {
    runStaticInitialization16();
    genericMain(Jrpn(Controller16(Model16())));
  }
}

void runStaticInitialization16() {
  // None of these operations has an argument, so there is no circular
  // initialization here.
  Arg.kI = Operations16.I;
  Arg.kParenI = Operations16.parenI;
  Arg.kDigits = Controller16.numbers;
  Arg.kDot = Operations.dot;
  Arg.fShift = Operations.fShift;
  Arg.gShift = Operations.gShift;
  Arg.gsbLabelSynonyms = Arg.registerISynonyms = {
    Operations.sst: Operations16.I,
    Operations.rs: Operations16.parenI
  };
  assert(Arg.assertStaticInitialized());
}

class Model16 extends Model<Operation> {
  Model16() : super(DisplayMode.hex, 16, 6);

  @override
  late final Memory<Operation> memory = Memory16(this, memoryNybbles: 406);

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
      MKey(Operations16.div, Operations16.xor, Operations16.dblDiv),
    ],
    [
      MKey(Operations16.gsb, Operations.xSwapParenI, Operations.rtn),
      MKey(Operations16.gto, Operations16.xSwapI, Operations16.lbl),
      MKey(Operations16.hex, Operations16.showHex, Operations16.dsz),
      MKey(Operations16.dec, Operations16.showDec, Operations16.isz),
      MKey(Operations16.oct, Operations16.showOct, Operations.sqrtOp),
      MKey(Operations16.bin, Operations16.showBin, Operations16.reciprocal),
      MKey(Operations.n4, Operations16.sb, Operations16.sf),
      MKey(Operations.n5, Operations16.cb, Operations16.cf),
      MKey(Operations.n6, Operations16.bQuestion, Operations16.fQuestion),
      MKey(Operations16.mult, Operations16.and, Operations16.dblx),
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
      MKey(Operations16.minus, Operations16.not, Operations.xGT0),
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
      MKey(Operations16.plus, Operations16.or, Operations.xEQ0),
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
          Operation operation, ArgDone arg) =>
      ProgramInstruction16(operation, arg);

  @override
  void reset() {
    displayMode = DisplayMode.hex;
    integerSignMode = SignMode.twosComplement;
    wordSize = 16;
    super.reset();
  }

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
      userMode: false,
      extraShift: ShiftKey.f);

  @override
  set isComplexMode(bool v) {}
  // Nope!
}

class MemoryPolicy16 extends MemoryPolicy {
  final Memory _memory;

  MemoryPolicy16(this._memory);

  @override
  void checkRegisterAccess(int i) {
    if (i < 0 || i >= _numRegisters) {
      throw CalculatorError(3);
    }
  }

  int get _numRegisters =>
      (_memory.totalNybbles - _memory.programNybbles) ~/
      _memory.registers.nybblesPerRegister;

  @override
  String showMemory() {
    int b = _memory.program.bytesToNextAllocation;
    String r = _numRegisters.toString().padLeft(3, '0');
    return 'p-$b r-$r ';
  }

  @override
  void checkExtendProgramMemory() {
    if (_memory.programNybbles + 14 > _memory.totalNybbles) {
      throw CalculatorError(4);
    }
  }

  @override
  int get maxProgramBytes => (_memory.totalNybbles ~/ 14) * 14;
}

class Memory16 extends Memory<Operation> {
  @override
  final Model<Operation> model;

  @override
  late final policy = MemoryPolicy16(this);

  Memory16(this.model, {required int memoryNybbles})
      : super(memoryNybbles: memoryNybbles);

  @override
  void initializeSystem(
      OperationMap<Operation> layout, Operation lbl, Operation rtn) {
    final int opcode =
        (lbl.arg.matches(Operations.n0, false) as ArgDone).opcode;
    program = ProgramMemory16(this, layout, model.returnStackSize, opcode, rtn);
  }
}

class ProgramMemory16 extends ProgramMemory<Operation> {
  final int _lblOpcode;

  ProgramMemory16(Memory16 memory, OperationMap<Operation> layout,
      int returnStackSize, this._lblOpcode, Operation rtn)
      : super(memory, layout, returnStackSize, rtn);

  @override
  void goto(int label) {
    label = label.abs();
    if (label >= 16) {
      throw CalculatorError(4);
    } else {
      gotoOpCode(_lblOpcode + label);
    }
  }
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
      arg: RegisterWriteArg(maxDigit: 31, f: (m) => m.x), name: 'STO');

  static final NormalArgOperation rcl = NormalArgOperationWithBeforeCalc(
      beforeCalculate: (Resting s) {
        s.liftStackIfEnabled();
        return StackLift.neutral;
      },
      arg: RegisterReadArg(
          maxDigit: 31,
          f: (m, v) {
            if (m.isFloatMode) {
              v.asDouble; // Throw exception if not
            }
            m.x = v;
          }),
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
      endsDigitEntry: false, // Not in float moad
      name: 'SHOW HEX');

  static final NormalOperation showDec = NormalOperation(
      calc: null,
      pressed: (ActiveState cs) => cs.handleShow(DisplayMode.decimal),
      stackLift: StackLift.neutral,
      endsDigitEntry: false, // Not in float mode
      name: 'SHOW DEC');

  static final NormalOperation showOct = NormalOperation(
      calc: null,
      pressed: (ActiveState cs) => cs.handleShow(DisplayMode.oct),
      stackLift: StackLift.neutral,
      endsDigitEntry: false, // Not in float mode
      name: 'SHOW OCT');

  static final NormalOperation showBin = NormalOperation(
      calc: null,
      pressed: (ActiveState cs) => cs.handleShow(DisplayMode.bin),
      stackLift: StackLift.neutral,
      endsDigitEntry: false, // Not in float mode
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
        if (m.displayDisabled) {
          m.program.doNextIf(r);
        }
        m.popStack(); // Even when not running a program
      });

  static final NormalOperation reciprocal = NormalOperation.floatOnly(
      floatCalc: (Model m) {
        double x = m.xF;
        if (x == 0.0) {
          throw CalculatorError(0);
        } else {
          m.floatOverflow = false;
          m.resultXF = 1.0 / x;
        }
      },
      name: '1/x');

  static final NormalOperation plus = NormalOperation.differentFloatAndInt(
      floatCalc: (Model m) {
        m.floatOverflow = false;
        m.popSetResultXF = m.yF + m.xF;
      },
      intCalc: (Model m) => m.integerSignMode.intAdd(m),
      name: '+');

  static final NormalOperation minus = NormalOperation.differentFloatAndInt(
      floatCalc: (Model m) {
        m.floatOverflow = false;
        m.popSetResultXF = m.yF - m.xF;
      },
      intCalc: (Model m) => m.integerSignMode.intSubtract(m),
      name: '-');

  static final NormalOperation mult = NormalOperation.differentFloatAndInt(
      floatCalc: (Model m) {
        m.floatOverflow = false;
        m.popSetResultXF = m.yF * m.xF;
      },
      intCalc: (Model m) => _storeMultDiv(m.yI * m.xI, m),
      name: '*');

  static final NormalOperation div = NormalOperation.differentFloatAndInt(
      floatCalc: (Model m) {
        final x = m.xF;
        if (x == 0) {
          throw CalculatorError(0);
        }
        m.floatOverflow = false;
        m.popSetResultXF = m.yF / x;
      },
      intCalc: (Model m) {
        try {
          final BigInt yi = m.yI;
          final BigInt xi = m.xI;
          _storeMultDiv(yi ~/ xi, m);
          // On one emulator I tried, -32768 / -1 resulted in Error 0
          // in 2-16 mode.  But 0 with overflow set is the right answer,
          // and that's what this gives, so I kept it.
          m.cFlag = yi.remainder(xi) != BigInt.zero;
          // ignore: avoid_catches_without_on_clauses
        } catch (e) {
          throw CalculatorError(0);
        }
      },
      name: '/');

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
        final v = m.memory.registers.index;
        if (m.isFloatMode) {
          v.asDouble; // Throw CalculatorError if not
        }
        m.x = v;
        m.display.displayX();
      },
      name: 'I');

  static final NormalOperation xSwapI = NormalOperation(
      calc: (Model m) {
        Value tmp = m.memory.registers.index;
        if (m.isFloatMode) {
          tmp.asDouble; // Throw CalculatorError if not
        }
        m.memory.registers.index = m.x;
        m.resultX = tmp;
      },
      name: 'x<=>I');

  static final NormalArgOperation window = NormalArgOperation(
      arg: DigitArg(
          max: 7,
          calc: (m, i) {
            if (!m.isFloatMode) {
              m.display.window = i * 8;
            }
          }),
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
  static void _setFloat(Model m, int digits) {
    m.floatOverflow = false;
    m.displayMode = DisplayMode.float(digits);
  }

  static final NormalArgOperation floatKey = NormalArgOperationWithBeforeCalc(
      stackLift: StackLift.neutral, // But see also FloatKeyArg.onArgComplete()
      beforeCalculate: (state) {
        if (!state.model.isFloatMode) {
          return StackLift.enable;
          // See page 100:  Stack lift is enabled when we go from int mode to
          // float mode, but not when we stay in float mode.  So: CLX,
          // FLOAT 2, 7 will not lift stack.
        } else {
          return StackLift.neutral;
        }
      },
      arg: ArgAlternates(children: [
        DigitArg(max: 9, calc: (m, i) => _setFloat(m, i)),
        KeyArg(key: Operations.dot, child: ArgDone((m) => _setFloat(m, 10))),
      ]),
      name: 'FLOAT');

  static final NormalArgOperation sf = NormalArgOperation(
      arg: DigitArg(max: 5, calc: (model, arg) => model.setFlag(arg, true)),
      name: 'SF');

  static final NormalArgOperation cf = NormalArgOperation(
      arg: DigitArg(max: 5, calc: (model, arg) => model.setFlag(arg, false)),
      name: 'CF');

  static final NormalArgOperation gsb = RunProgramOperation(
      runner: () => GosubProgramRunner(),
      arg: LabelArg(
          maxDigit: 15,
          indirect: true,
          f: (m, final int? label) {
            // indirect: set true, because GSB (i) was implemented in the first
            // released versions of JRPN.  I'm pretty sure this isn't implemented
            // in the real 16C.  For stricter simulation, we could disallow it
            // and make the corresponding opcode illegal.
            if (label == null) {
              // Like, I is a float outside int range
              throw CalculatorError(4);
            }
            m.memory.program.gosub(label);
          }),
      name: 'GSB');

  static final NormalArgOperation gto = NormalArgOperation(
      arg: LabelArg(
          maxDigit: 15,
          indirect: true,
          f: (m, final int? label) {
            // indirect: set true, because GTO (i) was implemented in the first
            // released versions of JRPN.  I'm pretty sure this isn't implemented
            // in the real 16C.  For stricter simulation, we could disallow it
            // and make the corresponding opcode illegal.
            if (label == null) {
              throw CalculatorError(4);
            }
            m.memory.program.goto(label);
          }),
      name: 'GTO');

  static final BranchingArgOperation fQuestion = BranchingArgOperation(
      arg: DigitArg(
          max: 5,
          calc: (model, arg) => model.program.doNextIf(model.getFlag(arg))),
      name: 'F?');

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

  static final NormalArgOperation lbl =
      NormalArgOperation(arg: DigitArg(max: 15, calc: (_, __) {}), name: 'LBL');

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
  ProgramInstruction16(Operation op, ArgDone arg) : super(op, arg);
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
  CalculatorButton get div => CalculatorButton(
      factory,
      '\u00F7',
      'XOR',
      'DBL\u00F7',
      Operations16.div,
      Operations16.xor,
      Operations16.dblDiv,
      '/');

  CalculatorButton get gsb => CalculatorButton(factory, 'GSB', 'x\u2B0C(i)',
      'RTN', Operations16.gsb, Operations.xSwapParenI, Operations.rtn, 'U');
  CalculatorButton get gto => CalculatorButton(factory, 'GTO', 'x\u2B0CI',
      'LBL', Operations16.gto, Operations16.xSwapI, Operations16.lbl, 'T');
  CalculatorButton get hex => CalculatorButton(factory, 'HEX', '', 'DSZ',
      Operations16.hex, Operations16.showHex, Operations16.dsz, 'I');
  CalculatorButton get dec => CalculatorButton(factory, 'DEC', '', 'ISZ',
      Operations16.dec, Operations16.showDec, Operations16.isz, 'Z');
  CalculatorButton get oct => CalculatorBlueSqrtButton(
      factory,
      'OCT',
      '',
      '\u221Ax',
      Operations16.oct,
      Operations16.showOct,
      Operations.sqrtOp,
      'K');
  CalculatorButton get bin => CalculatorButton(factory, 'BIN', '', '1/x',
      Operations16.bin, Operations16.showBin, Operations16.reciprocal, 'L');
  CalculatorButton get n4 => CalculatorButton(factory, '4', 'SB', 'SF',
      Operations.n4, Operations16.sb, Operations16.sf, '4');
  CalculatorButton get n5 => CalculatorButton(factory, '5', 'CB', 'CF',
      Operations.n5, Operations16.cb, Operations16.cf, '5');
  CalculatorButton get n6 => CalculatorButton(factory, '6', 'B?', 'F?',
      Operations.n6, Operations16.bQuestion, Operations16.fQuestion, '6');
  CalculatorButton get mult => CalculatorOnSpecialButton(
      factory,
      '\u00D7',
      'AND',
      'DBLx',
      Operations16.mult,
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
      Operations16.minus,
      Operations16.not,
      Operations.xGT0,
      '-',
      'CLR',
      acceleratorLabel: '\u2212');

  CalculatorButton get onOff => CalculatorOnButton(factory, 'ON', '', '',
      Operations.onOff, Operations.onOff, Operations.onOff, 'O', 'OFF');
  CalculatorButton get fShift => CalculatorFButton(factory, 'f', '', '',
      Operations.fShift, Operations.fShift, Operations.fShift, 'M\u0006',
      extraAcceleratorName: '^F', acceleratorLabel: 'M');
  CalculatorButton get gShift => CalculatorGButton(factory, 'g', '', '',
      Operations.gShift, Operations.gShift, Operations.gShift, 'G\u0007',
      extraAcceleratorName: '^G', acceleratorLabel: 'G');
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
      Operations16.plus, Operations16.or, Operations.xEQ0, '+=');

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
  @override
  final Model16 model;

  Controller16(this.model)
      : super(
            numbers: numbers,
            shortcuts: _shortcuts,
            lblOperation: Operations16.lbl,
            rtn: Operations.rtn);

  /// Map from operation that is a shortcut to what it's a shortcut for, with
  /// the key as an argument.  We want the identical instance of ArgDone, so
  /// we climb down the tree.  It's admittedly a bit of a hack.
  static final Map<Operation, ArgDone> _shortcuts = {
    Operations16.I: _makeShortcut(Operations16.rcl.arg, Operations16.I)!,
    Operations16.parenI:
        _makeShortcut(Operations16.rcl.arg, Operations16.parenI)!,
  };

  static ArgDone? _makeShortcut(Arg arg, Operation wanted) {
    if (arg is ArgAlternates) {
      for (final a in arg.children) {
        final r = _makeShortcut(a, wanted);
        if (r != null) {
          return r;
        }
      }
    } else if (arg is KeyArg) {
      if (arg.key == wanted) {
        return arg.child as ArgDone;
      }
    }
    return null;
  }

  /// The numbers.  This must be in order.
  static final List<NumberEntry> numbers = [
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

  @override
  int get argBase => 16;

  @override
  int getErrorNumber(CalculatorError err) => err.num16;

  @override
  NormalArgOperation get gsbOperation => Operations16.gsb;

  @override
  NormalArgOperation get gtoOperation => Operations16.gto;

  @override
  Operation get minusOp => Operations16.minus;

  @override
  Operation get multOp => Operations16.mult;
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

// Store the result of a multiplication or division, setting the
// G flag appropriately
void _storeMultDiv(BigInt r, Model m) {
  final max = m.maxInt;
  if (r > m.maxInt) {
    m.popSetResultXI = r & max;
    m.gFlag = true;
  } else {
    final min = m.minInt;
    if (r < min) {
      m.popSetResultXI = -((-r) & max); // Valid for 1's complement, too!
      m.gFlag = true;
    } else {
      m.popSetResultXI = r;
      m.gFlag = false;
    }
  }
}
