/*
Copyright (c) 2023 William Foote

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

import 'dart:async';
import 'dart:math';

import 'package:jrpn/c/states.dart';
import 'package:jrpn/m/model.dart';
import 'package:meta/meta.dart';

import 'model15c.dart';

abstract class NontrivialProgramRunner extends ProgramRunner {
  static const int _subroutineNotStarted = 0xdeadc0de;
  int _subroutineStart = _subroutineNotStarted;

  int get failureNumber;

  @override
  Future<void> run() async {
    final program = model.program;
    bool result = await runCalculation();
    if (_subroutineStart == _subroutineNotStarted) {
      // Degenerate case:  We didn't once execute the subroutine.  Maybe
      // something like integrating from 0 to 0?
      //
      // Running the subroutine would have ended in RTN, which would have
      // popped the stack.
      program.popReturnStack();
    }
    // And, pop off the real return address
    program.popReturnStack();
    if (!program.returnStackUnderflow) {
      // If integrate/solve came inside a program
      program.doNextIf(result);
    } else {
      throw CalculatorError(failureNumber);
    }
  }

  ///
  /// Run the solve/integrate algorithm.
  ///
  Future<bool> runCalculation();

  Future<double> runSubroutine(double arg) async {
    if (_subroutineStart == _subroutineNotStarted) {
      _subroutineStart = model.program.currentLine;
    } else {
      model.program.currentLine = _subroutineStart;
      pushPseudoReturn(model);
      assert(returnStackStartPos == model.program.returnStackPos);
    }
    model.setXYZT(Value.fromDouble(arg));
    await caller.runProgramLoop();
    print("@@ f($arg) gives ${model.xF}");
    return model.xF;
  }

  @override
  @mustCallSuper
  void checkStartRunning() {
    final p = caller.model.memory as Memory15;
    if (p.availableRegistersWithProgram(this) < 0) {
      throw CalculatorError(10);
    }
  }
}

class SolveProgramRunner extends NontrivialProgramRunner {
  @override
  int get registersRequired => max(5, (parent?.registersRequired ?? 0));

  @override
  int get failureNumber => 8;

  @override
  void checkStartRunning() {
    ProgramRunner? curr = parent;
    while (curr != null) {
      if (curr is SolveProgramRunner) {
        throw CalculatorError(7);
      }
      curr = curr.parent;
    }
    super.checkStartRunning();
  }

  @override
  Future<bool> runCalculation() async {
    // Algorithm translated from doc/HP-15C.tcl, secant, at line 5987
    double x0 = model.yF;
    double x1 = model.xF;
    const ebs = 1e-14;
    int cntmax = 25;
    int ii = 2;
    bool chs = false;
    bool rc;

    // From page 192 of the owner's handbook
    if (x0 == x1) {
      if (x0 == 0) {
        x1 = 1e-7;
      } else {
        // "One count in the seventh significant digit"
        x1 += pow(10, log(x0).floorToDouble()) * 1e-6;
      }
    }

    double resultX0 = await runSubroutine(x0);
    double resultX1 = await runSubroutine(x1);
    for (;;) {
      double slope;
      if (resultX1 - resultX0 != 0) {
        slope = (x1 - x0) / (resultX1 - resultX0);
        slope = slope.abs() > 10 ? slope * 2 : slope;
      } else if (resultX0 < 0) {
        slope = -0.5001;
      } else {
        slope = 0.5001;
      }
      double x2 = x1 - resultX1 * slope;

      // Optimization 1 (see TCL source)
      if ((x2 - x1).abs() > 100 * (x0 - x1).abs()) {
        x2 = (x0 + x1) / 2;
      }

      // Optimization 2 (see TCL source)
      if (resultX0 * resultX1 < 0 && (x2 < min(x0, x1) || x2 > max(x0, x1))) {
        x2 = (x0 + x1) / 2;
      }
      double resultX2 = await runSubroutine(x2);
      x0 = x1;
      resultX0 = resultX1;
      x1 = x2;
      resultX1 = resultX2;
      if (resultX0 * resultX1 < 0) {
        chs = true;
      }
      ii++;

      // Root found or abort?
      if (resultX2.abs() < ebs ||
          (resultX0 * resultX1 < 0 && (x0.abs() - x1.abs()).abs() < ebs)) {
        rc = true;
        break;
      } else if (ii > cntmax) {
        rc = chs;
        break;
      }
    }
    model.zF = resultX1;
    model.yF = x0;
    model.xF = x1;
    return rc;
  }
}

class IntegrateProgramRunner extends NontrivialProgramRunner {
  @override
  int get registersRequired => max(23, (parent?.registersRequired ?? 0));

  @override
  int get failureNumber => throw 'unreachable';

  @override
  void checkStartRunning() {
    ProgramRunner? curr = parent;
    while (curr != null) {
      if (curr is IntegrateProgramRunner) {
        throw CalculatorError(7);
      }
      curr = curr.parent;
    }
    super.checkStartRunning();
  }

  @override
  Future<bool> runCalculation() async {
    throw "@@ TODO";
  }
}
