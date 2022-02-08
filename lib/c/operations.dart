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

import '../m/complex.dart';
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
  /// Initialized by model.  Harmlessley re-initialized when units tests
  /// are run.
  static late int numberOfFlags;

  // Unshifted keys:

  static final n7 = NumberEntry('7', 7);
  static final n8 = NumberEntry('8', 8);
  static final n9 = NumberEntry('9', 9);

  static final NormalOperation div = NormalOperation.differentFloatAndInt(
      floatCalc: (Model m) {
        try {
          m.floatOverflow = false;
          m.popSetResultXF = m.yF / m.xF;
          // ignore: avoid_catches_without_on_clauses
        } catch (e) {
          throw CalculatorError(0);
        }
      },
      complexCalc: (Model m) {
        m.popSetResultXC = m.xC / m.yC;
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
      arg: GosubOperationArg.both(
          desc: const ArgDescriptionGto16C(),
          // calc is only used when running a program - see
          // GosubArgInputState.
          calc: (Model m, int label) =>
              m.memory.program.gosub(label, const ArgDescriptionGto16C())),
      name: 'GSB');

  static final NormalArgOperation gto = NormalArgOperation(
      arg: OperationArg.both(
          desc: const ArgDescriptionGto16C(),
          calc: (Model m, int label) =>
              m.memory.program.goto(label, const ArgDescriptionGto16C())),
      name: 'GTO');

  static final n4 = NumberEntry('4', 4);
  static final n5 = NumberEntry('5', 5);
  static final n6 = NumberEntry('6', 6);

  static final NormalOperation mult = NormalOperation.differentFloatAndInt(
      floatCalc: (Model m) {
        m.floatOverflow = false;
        m.popSetResultXF = m.xF * m.yF;
      },
      complexCalc: (Model m) {
        m.popSetResultXC = m.xC * m.yC;
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
        m.floatOverflow = false;
        m.popSetResultXF = m.yF - m.xF;
      },
      complexCalc: (Model m) {
        m.popSetResultXC = m.xC - m.yC;
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

  static final n0 = NumberEntry('0', 0);

  static final LimitedOperation dot = LimitedOperation(
      pressed: (LimitedState c) => c.handleDecimalPoint(), name: '.');

  static final NormalOperation chs = NormalOperation(
      calc: null, pressed: (ActiveState c) => c.handleCHS(), name: 'CHS');

  static final NormalOperation plus = NormalOperation.differentFloatAndInt(
      floatCalc: (Model m) {
        m.floatOverflow = false;
        m.popSetResultXF = m.yF + m.xF;
      },
      complexCalc: (Model m) {
        m.popSetResultXC = m.xC + m.yC;
      },
      intCalc: (Model m) => m.integerSignMode.intAdd(m),
      name: '+');

  static final NormalOperation xSwapParenI = NormalOperation(
      calc: (Model m) {
        Value tmp = m.x;
        m.resultX = m.memory.registers.indirectIndex;
        m.memory.registers.indirectIndex = tmp;
      },
      name: 'x<=>(i)');

  static final NormalOperation xSwapI = NormalOperation(
      calc: (Model m) {
        Value tmp = m.x;
        m.resultX = m.memory.registers.index;
        m.memory.registers.index = tmp;
      },
      name: 'x<=>I');

  static final LimitedOperation clearPrgm = LimitedOperation(
      pressed: (LimitedState s) => s.handleClearProgram(), name: 'CLEAR PRGM');

  static final NormalOperation clearReg = NormalOperation(
      stackLift: StackLift.neutral,
      calc: (Model m) => m.memory.registers.clear(),
      name: 'CLEAR REG');

  static final LimitedOperation clearPrefix = LimitedOperation(
      pressed: (LimitedState cs) => cs.handleClearPrefix(),
      name: 'CLEAR PREFIX');

  static final LimitedOperation mem = LimitedOperation(
      name: 'MEM', pressed: (LimitedState s) => s.handleShowMem());

  static final LimitedOperation status = LimitedOperation(
      pressed: (LimitedState cs) => cs.handleShowStatus(), name: 'STATUS');

  static final NormalOperation eex = NormalOperation(
      pressed: (ActiveState c) => c.handleEEX(), calc: null, name: 'EEX');

  static final NormalOperation abs = NormalOperation.differentFloatAndInt(
      floatCalc: (Model m) {
        m.resultXF = m.xF.abs();
      },
      complexCalc: (Model m) {
        m.resultXF = m.xC.r; // Sets complex part to zero
      },
      intCalc: (Model m) => m.resultXI = m.xI.abs(),
      name: 'ABS');

  static final NormalOperation rtn = NormalOperation(
      calc: (Model m) => m.memory.program.popReturnStack(), name: 'RTN');

  static final NormalOperation sqrtOp = NormalOperation.differentFloatAndInt(
      floatCalc: (Model m) {
        try {
          m.resultXF = sqrt(m.xF);
          // ignore: avoid_catches_without_on_clauses
        } catch (e) {
          throw CalculatorError(0);
        }
      },
      complexCalc: (Model m) {
        m.resultXC = m.xC.sqrt();
      },
      intCalc: (Model m) => m.resultXI = _sqrtI(m.xI, m),
      name: 'sqrt(x)');

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
      complexCalc: (Model m) {
        final x = m.xC;
        if (x == Complex.zero) {
          throw CalculatorError(0);
        } else {
          m.resultXC = const Complex(1, 0) / x;
        }
      },
      name: '1/x');

  static final _flagArgDesc = ArgDescription16C(maxArg: numberOfFlags - 1);

  static final NormalArgOperation sf = NormalArgOperation(
      arg: OperationArg.both(
          desc: _flagArgDesc,
          calc: (Model m, int arg) {
            m.setFlag(arg, true);
          }),
      name: 'SF');

  static final NormalArgOperation cf = NormalArgOperation(
      arg: OperationArg.both(
          desc: _flagArgDesc,
          calc: (Model m, int arg) => m.setFlag(arg, false)),
      name: 'CF');

  static final BranchingArgOperation fQuestion = BranchingArgOperation(
      arg: OperationArg.both(
          desc: _flagArgDesc,
          calc: (Model m, int arg) => m.program.doNextIf(m.getFlag(arg))),
      name: 'F?');

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

  // ================================
  // Useful collections of operations
  // ================================

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
