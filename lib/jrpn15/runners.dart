/*
Copyright (c) 2023-2024 William Foote

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

library jrpn15.runners;

import 'dart:async';
import 'dart:math';
import 'dart:math' as math show pow;
import 'dart:typed_data';

import 'package:jrpn/c/states.dart';
import 'package:jrpn/m/model.dart';
import 'package:meta/meta.dart';

import 'model15c.dart';

abstract class NontrivialProgramRunner extends ProgramRunner {
  static const int _subroutineNotStarted = 0xdeadc0de;
  int _subroutineStart = _subroutineNotStarted;

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
    } else if (!result) {
      fail();
    }
  }

  void fail();

  ///
  /// Run the solve/integrate algorithm.
  ///
  Future<bool> runCalculation();

  Future<double> runSubroutine(double arg) =>
      runSubroutineErrorsOK(arg, const {});

  ///
  /// If the subroutine we call generates a CalculatorError with an
  /// acceptable error code, we throw the exception.
  ///
  Future<double> runSubroutineErrorsOK(
      double arg, Set<int> acceptableErrors) async {
    if (_subroutineStart == _subroutineNotStarted) {
      _subroutineStart = model.program.currentLine;
    } else {
      model.program.currentLine = _subroutineStart;
      pushPseudoReturn(model);
      assert(returnStackStartPos == model.program.returnStackPos);
    }
    model.setXYZT(Value.fromDouble(arg));
    await caller.runProgramLoop(acceptableErrors: acceptableErrors);
    assert(returnStackStartPos == model.program.returnStackPos + 1);
    if (model.getFlag(9)) {
      model.setFlag(9, false);
      if (model.xF > 0) {
        return double.infinity;
      } else {
        return double.negativeInfinity;
      }
    } else {
      return model.xF;
    }
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
  fail() {
    throw CalculatorError(8);
  }

  @override
  Future<double> runSubroutine(double arg) async {
    const okErrors = {0, 1};
    try {
      final r = await super.runSubroutineErrorsOK(arg, okErrors);
      return r;
    } on CalculatorError catch (e) {
      if (!okErrors.contains(e.num15)) {
        rethrow;
      }
      while (returnStackStartPos < model.program.returnStackPos + 1) {
        model.program.popReturnStack();
      }
      return double.infinity;
    }
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
        x1 += pow(10, log10(x0).floorToDouble()) * 1e-6;
      }
    }

    double resultX0 = await runSubroutine(x0);
    double resultX1 = await runSubroutine(x1);
    if (resultX0.isInfinite || resultX1.isInfinite) {
      if (resultX0.isInfinite) {
        model.zF = resultX0;
      } else {
        model.zF = resultX1;
      }
      model.yF = x0;
      model.xF = x1;
      return false;
    }
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
        x2 = x1 - 100 * (x0 - x1);
      }

      // Optimization 2 (see TCL source)
      if (resultX0 * resultX1 < 0 && (x2 < min(x0, x1) || x2 > max(x0, x1))) {
        x2 = (x0 + x1) / 2;
      }
      double resultX2 = await runSubroutine(x2);
      while (resultX2.isInfinite && ii < cntmax) {
        // Oops!  Try a less agressive estimate, by backing off the slope.
        // "4" is a guess.  FWIW, this made
        // "HP-15C_4.4.00_Programs/Users/Eddie Shore/Reactance chart solver.15c"
        // work with the given example, and trying something when we get
        // infinity from the function we call won't hurt.
        slope /= 4;
        x2 = x1 - resultX1 * slope;
        resultX2 = await runSubroutine(x2);
        cntmax++;
      }
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
  double _lastEstimate = 0;

  @override
  int get registersRequired => max(23, (parent?.registersRequired ?? 0));

  @override
  bool get runImplicitRtnOnSST => true;
  // This is needed for the behavior of executing the RTN for integrate,
  // which lets a user SST through the function as described on page
  // 257, third paragraph.

  static const int maxIterations = 10;
  // Complexity is... uh... O(a lot)
  // In testing, typical functions converge in 3 or 4 iterations.
  // With the default 50ms/program instruction, and a trivial function
  // that generates a random number, it takes over an hour to get here.
  // 10 is conservatively high, and a nice, round number
  // that's low enough so the thing will terminate before the universe
  // expires.

  ///
  /// For integration, "failure" just returns.  It takes a loooong time
  /// to get to where it gives up -- see `maxIterations`.
  ///
  @override
  fail() {
    throw 'unreachable';
  }

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

  // pow(num, num) returning num is annoying
  static double fpow(double a, double b) => math.pow(a, b).toDouble();

  @override
  Future<double> runSubroutineErrorsOK(
      double arg, Set<int> acceptableErrors) async {
    model.lastX = Value.fromDouble(_lastEstimate);
    // See page 257 of User's Guide, third paragraph.
    return super.runSubroutineErrorsOK(arg, acceptableErrors);
  }

  @override
  Future<bool> runCalculation() async {
    final Value originalY = model.y;
    final Value originalX = model.x;
    double a = model.yF; // lower bound
    double b = model.xF; // upper bound
    final double signResult;
    if (a == b) {
      model.z = originalX;
      model.t = originalY;
      model.x = model.y = Value.zero;
      return Future.value(true);
    } else if (a > b) {
      signResult = -1;
      final tmp = b;
      b = a;
      a = tmp;
    } else {
      signResult = 1;
    }
    final double span = b - a;

    const okErrors = {0, 1};
    try {
      _lastEstimate = 0;
      return await qromb(
          okErrors, span, a, b, signResult, originalX, originalY);
    } on CalculatorError catch (e) {
      if (!okErrors.contains(e.num15)) {
        rethrow;
      }
      while (returnStackStartPos < model.program.returnStackPos + 1) {
        model.program.popReturnStack();
      }
    }
    _lastEstimate = 0;
    return qromo(span, a, b, signResult, originalX, originalY);
  }

  Future<bool> qromb(Set<int> okErrors, double span, double a, double b,
      double signResult, Value originalX, Value originalY) async {
    final DisplayMode precision = model.displayMode;
    // Try qromb.  See https://github.com/zathras/jrpn/issues/36
    var ro = Float64List(maxIterations);
    var ru = Float64List(maxIterations);
    final fOfA = await runSubroutineErrorsOK(a, okErrors);
    final fOfB = await runSubroutineErrorsOK(b, okErrors);
    double h = span;
    ro[0] = (fOfA + fOfB) * h / 2;
    // Now that we made it here, errors are no longer allowed.
    int i;
    for (i = 1; i < maxIterations; i++) {
      int k = 1 << i; // /k = 2^i, i is at most 12
      int s = 1;
      double sum = 0;
      h /= 2;
      for (int j = 1; j < k; j += 2) {
        final f = await runSubroutine(a + j * h);
        sum += f;
      }
      ru[0] = h * sum + ro[0] / 2;
      for (int j = 1; j <= i; j++) {
        s *= 4;
        ru[j] = (s * ru[j - 1] - ro[j - 1]) / (s - 1);
      }
      final rt = ro;
      ro = ru;
      ru = rt;
      final estimate = ro[i] * signResult;
      final double digit = precision.leastSignificantDigitNoFloor(estimate);
      final double eps = fpow(10.0, digit);
      if (i > 2 && (ru[i - 1] - estimate).abs() <= eps) {
        i++;
        break;
      }
      _lastEstimate = estimate;
    }
    final err = (ru[i - 2] - ro[i - 1]).abs();
    model.z = originalX;
    model.t = originalY;
    model.yF = err;
    model.xF = ro[i - 1] * signResult;
    return true;
  }

  Future<bool> qromo(double span, double a, double b, double signResult,
      Value originalX, Value originalY) async {
    final DisplayMode precision = model.displayMode;
    // The number of digits being displayed determines how precisely we
    // estimate the integral.

    // This is a port of qromo(), copied from
    // https://www.hpmuseum.org/forum/thread-16523.html
    // The post includes the text "You may freely use any of the code
    // here and please ask questions or PM me if something is not clear."
    /*
      double qromo(double (*f)(double), double a, double b, int n, double eps) {
        double R1[n], R2[n];
        double *Ro = &R1[0], *Ru = &R2[0];
        double h = b-a;
        int i, j;
        unsigned long long k = 1;
        Ro[0] = f((a+b)/2)*h;
        for (i = 1; i < n; ++i) {
          unsigned long long s = 1;
          double sum = 0;
          double *Rt;
          k *= 3;
          h /= 3;
          for (j = 1; j < k; j += 3)
            sum += f(a+(j-1)*h+h/2) + f(a+(j+1)*h+h/2);
          Ru[0] = h*sum + Ro[0]/3;
          for (j = 1; j <= i; ++j) {
            s *= 9;
            Ru[j] = (s*Ru[j-1] - Ro[j-1])/(s-1);
          }
          if (i > 1 && fabs(Ro[i-1]-Ru[i]) <= eps*fabs(Ru[i])+eps)
            return Ru[i];
          Rt = Ro;
          Ro = Ru;
          Ru = Rt;
        }
        return Ro[n-1]; // no convergence, return best result,
                        // error is fabs((Ru[n-2]-Ro[n-1])/Ro[n-1])
      }
     */
    var ro = Float64List(maxIterations);
    var ru = Float64List(maxIterations);
    double h = span;
    int k = 1;
    ro[0] = await runSubroutine((a + b) / 2) * h;
    _lastEstimate = ro[0] * signResult;
    int i;
    for (i = 1; i < maxIterations; i++) {
      int s = 1;
      double sum = 0;
      k *= 3;
      h /= 3;
      for (int j = 1; j < k; j += 3) {
        double f1 = await runSubroutine(a + (j - 1) * h + h / 2);
        double f2 = await runSubroutine(a + (j + 1) * h + h / 2);
        sum += f1 + f2;
      }
      ru[0] = h * sum + ro[0] / 3;
      for (int j = 1; j <= i; ++j) {
        s *= 9;
        ru[j] = (s * ru[j - 1] - ro[j - 1]) / (s - 1);
      }
      final rt = ro;
      ro = ru;
      ru = rt;
      final estimate = ro[i] * signResult;
      final double digit = precision.leastSignificantDigitNoFloor(estimate);
      final double eps = fpow(10.0, digit);
      if (i > 1 && (ru[i - 1] - estimate).abs() <= eps) {
        break;
      }
      _lastEstimate = estimate;
    }
    final ok = i < maxIterations;
    if (!ok) {
      i--;
    }
    final err = ((ru[i - 1] - ro[i]) / ro[i]).abs();
    model.z = originalX;
    model.t = originalY;
    model.yF = err;
    model.xF = ro[i] * signResult;
    return true; // The 15C never gives CalculatorError on failure to converge
  }
}
