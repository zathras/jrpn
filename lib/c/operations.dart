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

  static final n7 = NumberEntry('7', 7);
  static final n8 = NumberEntry('8', 8);
  static final n9 = NumberEntry('9', 9);

  static final n4 = NumberEntry('4', 4);
  static final n5 = NumberEntry('5', 5);
  static final n6 = NumberEntry('6', 6);

  static final NormalOperation rs = NormalOperation(
      stackLift: StackLift.neutral,
      pressed: (ActiveState s) => s.handleRunStop(),
      calc: null,
      name: 'R/S');

  static final sst = NonProgrammableOperation(
      name: 'SST', pressed: (LimitedState s) => s.handleSST());

  static final NormalOperation rDown =
      NormalOperation(calc: (Model m) => m.rotateStackDown(), name: 'Rv');

  static final NormalOperation xy =
      NormalOperation(calc: (Model m) => m.swapXY(), name: 'X<=>Y');

  static final bsp = NonProgrammableOperation(
      endsDigitEntry: false,
      pressed: (LimitedState c) => c.handleBackspace(),
      name: 'BSP');

  static final NormalOperation enter = NormalOperation(
      calc: (Model m) => m.pushStack(),
      stackLift: StackLift.disable,
      name: 'ENTER');

  static final n1 = NumberEntry('1', 1);
  static final n2 = NumberEntry('2', 2);
  static final n3 = NumberEntry('3', 3);

  // On . changes decimal point
  // On on turns off
  // On x  runs self tests, displays -8,8,8,8,8,8,8,8,8,8,, lights all status
  //            Error 9 on failure
  // on -  clears everything, displays 'Pr Error'
  static final onOff = NonProgrammableOperation(
      pressed: (LimitedState s) => s.handleOnOff(), name: 'ON');

  static final fShift = ShiftOperation(
      pressed: (LimitedState c) => c.handleShift(ShiftKey.f), name: 'f');

  static final gShift = ShiftOperation(
      pressed: (LimitedState c) => c.handleShift(ShiftKey.g), name: 'g');

  static final n0 = NumberEntry('0', 0);

  static final LimitedOperation dot = LimitedOperation(
      endsDigitEntry: false,
      pressed: (LimitedState c) => c.handleDecimalPoint(),
      name: '.');

  static final NormalOperation chs = NormalOperation(
      endsDigitEntry: false,
      calc: null,
      pressed: (ActiveState c) => c.handleCHS(),
      name: 'CHS');

  static final NormalOperation xSwapParenI = NormalOperation(
      calc: (Model m) {
        Value tmp = m.x;
        m.resultX = m.memory.registers.indirectIndex;
        m.memory.registers.indirectIndex = tmp;
      },
      name: 'x<=>(i)');

  static final clearPrgm = NonProgrammableOperation(
      pressed: (LimitedState s) => s.handleClearProgram(), name: 'CLEAR PRGM');

  static final NormalOperation clearReg = NormalOperation(
      stackLift: StackLift.neutral,
      calc: (Model m) => m.memory.registers.clear(),
      name: 'CLEAR REG');

  static final clearPrefix = NonProgrammableOperation(
      pressed: (LimitedState cs) => cs.handleClearPrefix(),
      endsDigitEntry: false,
      name: 'CLEAR PREFIX');

  static final mem = NonProgrammableOperation(
      name: 'MEM', pressed: (LimitedState s) => s.handleShowMem());

  static final status = NonProgrammableOperation(
      pressed: (LimitedState cs) => cs.handleShowStatus(), name: 'STATUS');

  static final NormalOperation eex = NormalOperation(
      endsDigitEntry: false,
      pressed: (ActiveState c) => c.handleEEX(),
      calc: null,
      name: 'EEX');

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
        final x = m.xF;
        if (x < 0) {
          throw CalculatorError(0);
        }
        m.resultXF = sqrt(x);
      },
      complexCalc: (Model m) {
        m.resultXC = m.xC.sqrt();
      },
      intCalc: (Model m) => m.resultXI = _sqrtI(m.xI, m),
      name: 'sqrt(x)');

  static final pr = NonProgrammableOperation(
      pressed: (LimitedState s) => s.handlePR(), name: 'P/R');

  static final bst = NonProgrammableOperation(
      name: 'BST', pressed: (LimitedState s) => s.handleBST());

  static final NormalOperation rUp =
      NormalOperation(calc: (Model m) => m.rotateStackUp(), name: 'R^');

  static final NormalOperation pse = NormalOperation(
      name: 'PSE',
      pressed: (ActiveState s) => s.handlePSE(),
      stackLift: StackLift.neutral,
      calc: (Model m) => m.display.displayX());

  static final NormalOperation clx = NormalOperation(
      calc: (Model m) => m.clx(), stackLift: StackLift.disable, name: 'CLx');

  static final xLEy = NormalOperation(
      name: 'x<=y',
      calc: (Model m) => m.program.doNextIf(m.compare(m.x, m.y) <= 0));

  static final xLT0 = NormalOperation(
      name: 'x<0',
      calc: (Model m) => m.program.doNextIf(m.compare(m.x, Value.zero) < 0));

  static final xGTy = NormalOperation(
      name: 'x>y',
      calc: (Model m) => m.program.doNextIf(m.compare(m.x, m.y) > 0));

  static final xGT0 = NormalOperation(
      name: 'x>0',
      calc: (Model m) => m.program.doNextIf(m.compare(m.x, Value.zero) > 0));

  static final NormalOperation lstx = NormalOperation(
      pressed: (ActiveState s) => s.liftStackIfEnabled(),
      calc: (Model m) {
        m.x = m.lastX;
        m.display.displayX();
      },
      name: 'LSTx');

  static final xNEy = NormalOperation(
      name: 'x!=y',
      calc: (Model m) => m.program.doNextIf(m.compare(m.x, m.y) != 0));

  static final xNE0 = NormalOperation(
      name: 'x!=0', calc: (Model m) => m.program.doNextIf(!m.isZero(m.x)));

  static final xEQy = NormalOperation(
      name: 'x==y',
      calc: (Model m) => m.program.doNextIf(m.compare(m.x, m.y) == 0));

  static final xEQ0 = NormalOperation(
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
