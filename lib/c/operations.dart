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
///
/// The calculator operations.  This is split into its own library so that
/// it's encapsulated from the controller internals.  Operations are split
/// into various types, viz:
///
/// <br>
/// <br>
/// <img src="dartdoc/controller.operations/hierarchy.svg"
///     style="width: 100%;"/>
/// <br>
/// <br>
///
/// Note the contravariant relationship between operation types and major
/// state typess.  This is discussed in more detail in the
/// `controller.states` library description.
///
library controller.operations;

import 'dart:math';

import '../m/model.dart';
import 'controller.dart';
import 'states.dart';

// See the library comments, above!  (Android Studio  hides them by default.)

///
/// The calculator operations.  This is split into its own library so that
/// it's encapsulated from the controller internals.  This class is just
/// a collecting place for the static final [Operation] constants,
/// and some lists of operations that are useful.
///
/// See the `controller.operations` library-level documentation for an overview
/// of the different [Operation] types.
///
class Operations {
  // Unshifted keys:

  static final a = NumberEntry('A', 10);
  static final b = NumberEntry('B', 11);
  static final c = NumberEntry('C', 12);
  static final d = NumberEntry('D', 13);
  static final e = NumberEntry('E', 14);
  static final f = NumberEntry('F', 15);
  static final n7 = NumberEntry('7', 7);
  static final n8 = NumberEntry('8', 8);
  static final n9 = NumberEntry('9', 9);

  static final NormalOperation div = NormalOperation.differentFloatAndInt(
      floatCalc: (Model m) {
        try {
          m.popSetResultXF = m.yF / m.xF;
          m.displayMode.setFloatOverflow(m);
          // ignore: avoid_catches_without_on_clauses
        } catch (e) {
          throw CalculatorError(0);
        }
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

  static final NormalArgOperation gsb = NormalArgOperation(
      arg: GosubOperationArg.both(17, // 0-f, I, (i)
          // calc is only used when running a program - see
          // GosubArgInputState.
          calc: (Model m, int label) => m.memory.program.gosub(label)),
      name: 'GSB');

  static final NormalArgOperation gto = NormalArgOperation(
      arg: OperationArg.both(17,
          calc: (Model m, int label) => m.memory.program.goto(label)),
      name: 'GTO');

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

  static final n4 = NumberEntry('4', 4);
  static final n5 = NumberEntry('5', 5);
  static final n6 = NumberEntry('6', 6);

  static final NormalOperation mult = NormalOperation.differentFloatAndInt(
      floatCalc: (Model m) {
        m.popSetResultXF = m.xF * m.yF;
        m.displayMode.setFloatOverflow(m);
      },
      intCalc: (Model m) => _storeMultDiv(m.xI * m.yI, m),
      name: '*');

  static final NormalOperation rs = NormalOperation(
      stackLift: StackLift.neutral,
      pressed: (ActiveState s) => s.handleRunStop(),
      calc: null,
      name: 'R/S');

  static final LimitedOperation sst =
      LimitedOperation(name: 'SST', pressed: (LimitedState s) => s.handleSST());

  static final NormalOperation rDown =
      NormalOperation(calc: (Model m) => m.rotateStackDown(), name: 'Rv');

  static final NormalOperation xy =
      NormalOperation(calc: (Model m) => m.swapXY(), name: 'X<=>Y');

  static final LimitedOperation bsp = LimitedOperation(
      pressed: (LimitedState c) => c.handleBackspace(), name: 'BSP');

  static final NormalOperation enter = NormalOperation(
      calc: (Model m) => m.pushStack(),
      stackLift: StackLift.disable,
      name: 'ENTER');

  static final n1 = NumberEntry('1', 1);
  static final n2 = NumberEntry('2', 2);
  static final n3 = NumberEntry('3', 3);

  static final NormalOperation minus = NormalOperation.differentFloatAndInt(
      floatCalc: (Model m) {
        m.popSetResultXF = m.yF - m.xF;
        m.displayMode.setFloatOverflow(m);
      },
      intCalc: (Model m) => m.integerSignMode.intSubtract(m),
      name: '-');

  // On . changes decimal point
  // On on turns off
  // On x  runs self tests, displays -8,8,8,8,8,8,8,8,8,8,, lights all status
  //            Error 9 on failure
  // on -  clears everything, displays 'Pr Error'
  static final LimitedOperation onOff = LimitedOperation(
      pressed: (LimitedState s) => s.handleOnOff(), name: 'ON');

  static final LimitedOperation fShift = LimitedOperation(
      pressed: (LimitedState c) => c.handleShift(ShiftKey.f), name: 'f');

  static final LimitedOperation gShift = LimitedOperation(
      pressed: (LimitedState c) => c.handleShift(ShiftKey.g), name: 'g');

  static final NormalArgOperation sto = NormalArgOperation(
      arg: OperationArg.both(33, // 0-f, .0-.f. I, (i)
          calc: (Model m, int arg) => m.memory.registers[arg] = m.x),
      name: 'STO');

  static final NormalArgOperation rcl = NormalArgOperation(
      arg: OperationArg.both(33,
          pressed: (ActiveState s) => s.liftStackIfEnabled(),
          calc: (Model m, int arg) => m.x = m.memory.registers[arg]),
      name: 'RCL');

  static final n0 = NumberEntry('0', 0);

  static final LimitedOperation dot = LimitedOperation(
      pressed: (LimitedState c) => c.handleDecimalPoint(), name: '.');

  static final NormalOperation chs = NormalOperation(
      calc: null, pressed: (ActiveState c) => c.handleCHS(), name: 'CHS');

  static final NormalOperation plus = NormalOperation.differentFloatAndInt(
      floatCalc: (Model m) {
        m.popSetResultXF = m.yF + m.xF;
        m.displayMode.setFloatOverflow(m);
      },
      intCalc: (Model m) => m.integerSignMode.intAdd(m),
      name: '+');

  // f (gold) shifted:

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

  static final NormalOperation xSwapParenI = NormalOperation(
      calc: (Model m) {
        Value tmp = m.x;
        m.resultX = m.memory.registers[Registers.indirectIndex];
        m.memory.registers[Registers.indirectIndex] = tmp;
      },
      name: 'x<=>(i)');

  static final NormalOperation xSwapI = NormalOperation(
      calc: (Model m) {
        Value tmp = m.x;
        m.resultX = m.memory.registers[Registers.indexRegister];
        m.memory.registers[Registers.indexRegister] = tmp;
      },
      name: 'x<=>I');

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

  static final NormalOperation parenI = NormalOperation(
      pressed: (ActiveState s) => s.liftStackIfEnabled(),
      calc: (Model m) {
        m.x = m.memory.registers[Registers.indirectIndex];
        m.display.displayX();
      },
      name: '(i)');

  static final NormalOperation I = NormalOperation(
      pressed: (ActiveState s) => s.liftStackIfEnabled(),
      calc: (Model m) {
        m.x = m.memory.registers[Registers.indexRegister];
        m.display.displayX();
      },
      name: 'I');

  static final LimitedOperation clearPrgm = LimitedOperation(
      pressed: (LimitedState s) => s.handleClearProgram(), name: 'CLEAR PRGM');

  static final NormalOperation clearReg = NormalOperation(
      stackLift: StackLift.neutral,
      calc: (Model m) => m.memory.registers.clear(),
      name: 'CLEAR REG');

  static final LimitedOperation clearPrefix = LimitedOperation(
      pressed: (LimitedState cs) => cs.handleClearPrefix(),
      name: 'CLEAR PREFIX');

  static final NormalArgOperation window = NormalArgOperation(
      arg: OperationArg.intOnly(7,
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

  static final NormalArgOperation floatKey = NormalArgOperation(
      stackLift: StackLift.neutral, // But see also FloatKeyArg.onArgComplete()
      arg: FloatKeyArg(10, calc: (Model m, int arg) {
        m.displayMode = DisplayMode.float(arg);
        m.displayMode.setFloatOverflow(m);
      }),
      name: 'FLOAT');

  static final LimitedOperation mem = LimitedOperation(
      name: 'MEM', pressed: (LimitedState s) => s.handleShowMem());

  static final LimitedOperation status = LimitedOperation(
      pressed: (LimitedState cs) => cs.handleShowStatus(), name: 'STATUS');

  static final NormalOperation eex = NormalOperation(
      pressed: (ActiveState c) => c.handleEEX(), calc: null, name: 'EEX');

  static final NormalOperation or = NormalOperation.intOnly(
      intCalc: (Model m) =>
          m.popSetResultX = Value.fromInternal(m.x.internal | m.y.internal),
      name: 'OR');

  // g (blue) shifted:

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

  static final NormalOperation abs = NormalOperation.differentFloatAndInt(
      floatCalc: (Model m) {
        m.resultXF = m.xF.abs();
      },
      intCalc: (Model m) => m.resultXI = m.xI.abs(),
      name: 'ABS');

  static final NormalOperation dblr =
      NormalOperation.intOnly(intCalc: _doubleIntRemainder, name: 'DBLR');

  static final NormalOperation dblDiv =
      NormalOperation.intOnly(intCalc: _doubleIntDivide, name: 'DBL/');

  static final NormalOperation rtn = NormalOperation(
      calc: (Model m) => m.memory.program.popReturnStack(), name: 'RTN');

  static final NormalArgOperation lbl = NormalArgOperation(
      arg: OperationArg.both(15, calc: (_, __) {}), name: 'LBL');

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

  static final NormalOperation sqrtOp = NormalOperation.differentFloatAndInt(
      floatCalc: (Model m) {
        try {
          m.resultXF = sqrt(m.xF);
          // ignore: avoid_catches_without_on_clauses
        } catch (e) {
          throw CalculatorError(0);
        }
      },
      intCalc: (Model m) => m.resultXI = _sqrtI(m.xI, m),
      name: 'sqrt(x)');

  static final NormalOperation reciprocal = NormalOperation.floatOnly(
      floatCalc: (Model m) {
        double x = m.xF;
        if (x == 0.0) {
          throw CalculatorError(0);
        } else {
          m.resultXF = 1.0 / m.xF;
          m.displayMode.setFloatOverflow(m);
        }
      },
      name: '1/x');

  static final NormalArgOperation sf = NormalArgOperation(
      arg: OperationArg.both(5,
          calc: (Model m, int arg) => m.setFlag(arg, true)),
      name: 'SF');

  static final NormalArgOperation cf = NormalArgOperation(
      arg: OperationArg.both(5,
          calc: (Model m, int arg) => m.setFlag(arg, false)),
      name: 'CF');

  static final BranchingArgOperation fQuestion = BranchingArgOperation(
      arg: OperationArg.both(5,
          calc: (Model m, int arg) => m.program.doNextIf(m.getFlag(arg))),
      name: 'F?');

  static final NormalOperation dblx =
      NormalOperation.intOnly(intCalc: _doubleIntMultiply, name: 'DBLx');

  static final LimitedOperation pr =
      LimitedOperation(pressed: (LimitedState s) => s.handlePR(), name: 'P/R');

  static final LimitedOperation bst =
      LimitedOperation(name: 'BST', pressed: (LimitedState s) => s.handleBST());

  static final NormalOperation rUp =
      NormalOperation(calc: (Model m) => m.rotateStackUp(), name: 'R^');

  static final NormalOperation pse = NormalOperation(
      name: 'PSE',
      pressed: (ActiveState s) => s.handlePSE(),
      stackLift: StackLift.neutral,
      calc: (Model m) => m.display.displayX());

  static final NormalOperation clx = NormalOperation(
      calc: (Model m) => m.x = Value.zero,
      stackLift: StackLift.disable,
      name: 'CLx');

  static final BranchingOperation xLEy = BranchingOperation(
      name: 'x<=y',
      calc: (Model m) => m.program.doNextIf(m.compare(m.x, m.y) <= 0));

  static final BranchingOperation xLT0 = BranchingOperation(
      name: 'x<0',
      calc: (Model m) => m.program.doNextIf(m.compare(m.x, Value.zero) < 0));

  static final BranchingOperation xGTy = BranchingOperation(
      name: 'x>y',
      calc: (Model m) => m.program.doNextIf(m.compare(m.x, m.y) > 0));

  static final BranchingOperation xGT0 = BranchingOperation(
      name: 'x>0',
      calc: (Model m) => m.program.doNextIf(m.compare(m.x, Value.zero) > 0));

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

  static final NormalOperation lstx = NormalOperation(
      pressed: (ActiveState s) => s.liftStackIfEnabled(),
      calc: (Model m) {
        m.x = m.lastX;
        m.display.displayX();
      },
      name: 'LSTx');

  static final BranchingOperation xNEy = BranchingOperation(
      name: 'x!=y',
      calc: (Model m) => m.program.doNextIf(m.compare(m.x, m.y) != 0));

  static final BranchingOperation xNE0 = BranchingOperation(
      name: 'x!=0', calc: (Model m) => m.program.doNextIf(!m.isZero(m.x)));

  static final BranchingOperation xEQy = BranchingOperation(
      name: 'x==y',
      calc: (Model m) => m.program.doNextIf(m.compare(m.x, m.y) == 0));

  static final BranchingOperation xEQ0 = BranchingOperation(
      name: 'x==0', calc: (Model m) => m.program.doNextIf(m.isZero(m.x)));

  /// Abbreviated key sequences for I used as an argument - cf. manual p. 68
  static final Set<Operation> argIops = {Operations.sst, Operations.I};

  /// Abbreviated key sequences for (i) used as an argument - cf. manual p. 68
  static final Set<Operation> argParenIops = {Operations.rs, Operations.parenI};

  /// The list of "logical" keys.  This has nothing to do with the UI;
  /// The order of the operations in this list determines the
  /// externalized form of the operations in the calculator's storage
  /// (the opcodes).  It also determines the displayed appearance of
  /// operation in program mode, whether the calculator is in portrait or
  /// landscape orientation.
  ///
  /// Changing the order here would render old JSON files of the
  /// calculator's state obsolete.
  static final List<List<Key<Operation>?>> keys = [
    [
      Key(Operations.a, Operations.sl, Operations.lj),
      Key(Operations.b, Operations.sr, Operations.asr),
      Key(Operations.c, Operations.rl, Operations.rlc),
      Key(Operations.d, Operations.rr, Operations.rrc),
      Key(Operations.e, Operations.rln, Operations.rlcn),
      Key(Operations.f, Operations.rrn, Operations.rrcn),
      Key(Operations.n7, Operations.maskl, Operations.poundB),
      Key(Operations.n8, Operations.maskr, Operations.abs),
      Key(Operations.n9, Operations.rmd, Operations.dblr),
      Key(Operations.div, Operations.xor, Operations.dblDiv),
    ],
    [
      Key(Operations.gsb, Operations.xSwapParenI, Operations.rtn),
      Key(Operations.gto, Operations.xSwapI, Operations.lbl),
      Key(Operations.hex, Operations.showHex, Operations.dsz),
      Key(Operations.dec, Operations.showDec, Operations.isz),
      Key(Operations.oct, Operations.showOct, Operations.sqrtOp),
      Key(Operations.bin, Operations.showBin, Operations.reciprocal),
      Key(Operations.n4, Operations.sb, Operations.sf),
      Key(Operations.n5, Operations.cb, Operations.cf),
      Key(Operations.n6, Operations.bQuestion, Operations.fQuestion),
      Key(Operations.mult, Operations.and, Operations.dblx),
    ],
    [
      Key(Operations.rs, Operations.parenI, Operations.pr),
      Key(Operations.sst, Operations.I, Operations.bst),
      Key(Operations.rDown, Operations.clearPrgm, Operations.rUp),
      Key(Operations.xy, Operations.clearReg, Operations.pse),
      Key(Operations.bsp, Operations.clearPrefix, Operations.clx),
      Key(Operations.enter, Operations.window, Operations.lstx),
      Key(Operations.n1, Operations.onesCompl, Operations.xLEy),
      Key(Operations.n2, Operations.twosCompl, Operations.xLT0),
      Key(Operations.n3, Operations.unsign, Operations.xGTy),
      Key(Operations.minus, Operations.not, Operations.xGT0),
    ],
    [
      Key(Operations.onOff, Operations.onOff, Operations.onOff),
      Key(Operations.fShift, Operations.fShift, Operations.fShift),
      Key(Operations.gShift, Operations.gShift, Operations.gShift),
      Key(Operations.sto, Operations.wSize, Operations.windowRight),
      Key(Operations.rcl, Operations.floatKey, Operations.windowLeft),
      null,
      Key(Operations.n0, Operations.mem, Operations.xNEy),
      Key(Operations.dot, Operations.status, Operations.xNE0),
      Key(Operations.chs, Operations.eex, Operations.xEQy),
      Key(Operations.plus, Operations.or, Operations.xEQ0),
    ]
  ];

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
    Operations.a,
    Operations.b,
    Operations.c,
    Operations.d,
    Operations.e,
    Operations.f
  ];

  /// Operations that can't be stored in memory
  static final List<Operation> special = [
    Operations.fShift,
    Operations.gShift,
    Operations.onOff,
    Operations.pr,
    Operations.bsp,
    Operations.clearPrgm,
    Operations.clearPrefix,
    Operations.sst,
    Operations.bst,
    Operations.mem,
    Operations.status
  ];

  /// Map from operation that is a short cut to what it's a shortcut for, with
  /// the key as an argument
  static final Map<NormalOperation, ProgramInstruction> shortcuts = {
    Operations.I: ProgramInstruction(Operations.rcl, Registers.indexRegister),
    Operations.parenI:
        ProgramInstruction(Operations.rcl, Registers.indirectIndex)
  };
}

// Taken from https://en.wikipedia.org/wiki/Methods_of_computing_square_roots
// under "Binary numeral system"
BigInt _sqrtI(BigInt num, NumStatus status) {
  if (num < BigInt.zero) {
    throw CalculatorError(0);
  }
  BigInt res = BigInt.zero;
  BigInt bit = BigInt.one << 64; // The second-to-top bit is set

  // bit starts at the highest power of four <= the argument
  while (bit > num) {
    bit >>= 2;
  }

  while (bit != BigInt.zero) {
    if (num >= res + bit) {
      num -= res + bit;
      res = (res >> 1) + bit;
    } else {
      res >>= 1;
    }
    bit >>= 2;
  }
  status.cFlag = num > BigInt.zero;
  return res;
}

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
