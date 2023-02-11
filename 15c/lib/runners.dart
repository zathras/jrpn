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

///
/// A non-trivial program runner involves a computation that isn't
/// just calling a subroutine.  It's trickier to implement, because
/// the computation can be suspended (if the user interrupts by pressing
/// a button, or via the R/S or SST keys).  This requires another asynchronous
/// task.
abstract class NontrivialProgramRunner extends ProgramRunner {
  bool _done = false;
  bool _abort = false;
  Completer<void>? _toCompute;
  Completer<void> _fromCompute = Completer();

  ///
  /// Called by the Running state whenever the calculator is willing to
  /// do some of our computation (i.e. when the program isn't in an interrupted
  /// state, via R/S et al
  ///
  @override
  Future<bool> run() async {
    final originalFromCompute = _fromCompute;
    if (_toCompute == null) {
      unawaited(_compute());
      assert(_toCompute != null || (_done && _fromCompute.isCompleted));
    }
    await originalFromCompute.future;
    while (!_done) {
      final lastFromCompute = _fromCompute;
      final success = await runProgramLoop();
      // @@ TODO
      if (success) {
        // subroutine finished
        assert(!_toCompute!.isCompleted);
        _toCompute!.complete();
      } else {
        return false;
      }
      await lastFromCompute.future;
    }

    return true;
  }

  Future<void> _compute() async {
    try {
      await compute();
    } on _Aborted {
      print("@@ Aborted.  Remove this println.");
    } finally {
      _done = true;
      _fromCompute.complete();
    }
  }

  @override
  void abort() {
    super.abort();
    _abort = true;
    final toCompute = _toCompute;
    if (toCompute != null && !toCompute.isCompleted) {
      toCompute.complete();
    }
  }

  Future<void> callCalculatorRoutine() async {
    if (_abort) {
      throw _Aborted();
    }
    initSubroutine();
    final lastFromCompute = _fromCompute;
    assert(!lastFromCompute.isCompleted);
    _toCompute = Completer();
    _fromCompute = Completer();
    lastFromCompute.complete();
    await (_toCompute!.future);
    return;
  }

  Future<void> compute();
}

class _Aborted {}

class SolveProgramRunner extends NontrivialProgramRunner {
  SolveProgramRunner() {}
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
  Future<void> compute() async {
    print("@@ calling calculator routine");
    await callCalculatorRoutine();
    print("@@ called calculator routine");
  }
}

class IntegrateProgramRunner extends NontrivialProgramRunner {
  @override
  void checkStartRunning() {
    // TODO: implement startRunning
    throw UnimplementedError();
  }

  @override
  Future<void> compute() async {
    // TODO
    throw UnimplementedError();
  }
}
