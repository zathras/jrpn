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

import 'package:jrpn/c/states.dart';
import 'package:jrpn/m/model.dart';
import 'package:meta/meta.dart';

import 'model15c.dart';

abstract class NontrivialProgramRunner extends ProgramRunner {
  static const int _subroutineNotStarted = 0xdeadc0de;
  int _subroutineStart = _subroutineNotStarted;

  Future<void> run() async {
    final program = model.program;
    await runCalculation();
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
  }

  ///
  /// Run the subroutine/solve.  Returns true if completed, false
  /// if interrupted.  If interrupted, the computation will be left suspened,
  /// and can be re-run, or aborted.
  ///
  Future<void> runCalculation();

  Future<void> runProgramLoop() {
    if (_subroutineStart == _subroutineNotStarted) {
      _subroutineStart = model.program.currentLine;
    } else {
      model.program.currentLine = _subroutineStart;
      pushPseudoReturn(model);
      assert(returnStackStartPos == model.program.returnStackPos);
    }
    return caller.runProgramLoop();
  }
}

class SolveProgramRunner extends NontrivialProgramRunner {
  @override
  void checkStartRunning() {
    ProgramRunner? curr = parent;
    while (curr != null) {
      if (curr is SolveProgramRunner) {
        throw CalculatorError(7);
      }
      curr = curr.parent;
    }
  }

  @override
  Future<void> runCalculation() async {
    print("@@ calling calculator routine");
    await runProgramLoop();
    print("@@ called calculator routine");
    model.xF = 42.0;
  }
}

class IntegrateProgramRunner extends NontrivialProgramRunner {
  @override
  void checkStartRunning() {
    throw "@@ TODO";
  }

  @override
  Future<void> runCalculation() async {
    throw "@@ TODO";
  }
}
