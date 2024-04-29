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
/// The states of the controller, reflecting the input mode of the calculator.
/// There are three main states:  [Resting] (the state it's usually in,
/// waiting for something to do), [DigitEntry] and [ProgramEntry].  There
/// are a large number of additional states, such as argument input,
/// or running a program.  The full hierarchy looks like this:
///
/// <br>
/// <br>
/// <img src="dartdoc/controller.states/hierarchy.svg" style="width: 100%;"/>
/// <br>
/// <br>
///
/// The state pattern is used to help manage the complexity of the calculator's
/// behavior in the various state.  Correctly managing stack lift is an
/// interesting challenge.  The three main states use functions attached to
/// [Operation]s to do their work.  The API presented to the [ProgramEntry]
/// state is a reduced one, presented by [LimitedState].  Note that this
/// introduces a contravariant relationship between states and operations,
/// which isn't completely captured by the Dart type relationships.  This
/// does result in a downcast in two places, but it's appropriately guarded.
/// Segmenting the API in this way makes the static type checker ensure that
/// we don't accidentally reference a method that should not be available
/// for the type of operation; this helped simplify development, and removes
/// a potential source of bugs.
///
library controller.states;

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../m/model.dart';
import 'operations.dart';

// See the library comments, above!  (Android Studio  hides them by default.)

///
/// Superclass for all states of a [Controller].  See the
/// `controller.states` library documentation for an overview, including
/// a diagram.
///
abstract class ControllerState {
  ControllerState(this.controller);

  final Controller controller;

  Model<Operation> get model => controller.model;

  @protected
  T changeState<T extends ControllerState>(T v) {
    controller.state = v;
    return v;
  }

  /// Called by the controller when this state is changed to
  void onChangedTo() {}

  void buttonDown(Operation key);

  void buttonUp(Operation key) {}

  /// Convenience method to call from an unreachable operation on a state
  @protected
  void unreachable() {
    assert(false);
  }

  void abort() {}
}

///
/// Supertype for the three states that process pressed functions
/// from [LimitedOperation]s (which includes all [NormalOperation]s).
/// This is the contravariant typing relationship mentioned in our
/// library overview.  cf. the controller.operations library's class
/// diagram, notably the dashed subtype line from [LimitedOperation]
/// to [NormalOperation].
///
abstract class LimitedState extends ControllerState {
  LimitedState(super.con);

  ///
  /// Process an [Operation] with the argument [ArgDone], once the
  /// argument value is available.
  ///
  void onArgComplete(Operation op, ArgDone arg);

  void handleOnOff();
  void handleShift(ShiftKey k);
  void handleDecimalPoint();
  void handleClearPrefix();
  void handleShowImaginary();
  void handleBackspace();
  void handlePR();
  void handleShowStatus();
  void handleShowMem();
  void handleGotoDot(int value);
  void handleSST();
  void handleBST();
  void handleClearProgram();

  void gosubEntryDone(RunProgramArgInputState from, ArgDone label);

  @protected
  void Function(Model<Operation>)? getCalculation(ArgDone ad) =>
      ad.getCalculation(model, const _OperationSelector());

  ControllerState gosubDoneState(ProgramRunner Function() runner);

  void terminateDigitEntry() {}
}

///
/// Supertype for the two states that process pressed and calculation
/// functions for [NormalOperation]s.  This is where stack lift
/// is exposed, because usually stack lift is enabled after performing
/// a calculation on the model.  It is performed when entering digits,
/// or recalling a value from a register or lastX.
///
abstract class ActiveState extends LimitedState with StackLiftEnabledUser {
  ActiveState(super.con);

  void handlePSE() => controller.handlePSE();

  void handleNumberKey(final int num);
  void handleLetterLabel(LetterLabel operation);
  void handleCHS();
  void handleEEX();
  void handleShow(IntegerDisplayMode mode);
  void handleRunStop();

  void liftStackIfEnabled() {
    if (stackLiftEnabled) {
      model.pushStack();
      stackLiftEnabled = false;
    }
  }
}

///
/// The initial state of the calculator, when it's waiting for input telling
/// it to do something.
///
class Resting extends ActiveState {
  Resting(super.con);

  @override
  void buttonDown(Operation key) {
    if (model.shift != ShiftKey.none) {
      model.shift = ShiftKey.none;
      // key.pressed(this) might set the shift key again.
    }
    if (key == controller.gtoOperation && controller is RealController) {
      // This is a little tricky.  GTO has this quirk, where "GTO . nnn"
      // positions the current line.  It still enables stack lift,
      // which is what the normal key.pressed() does.
      key.pressed(this);
      changeState(WaitingForGotoDot(controller, this));
      return;
    }
    final Arg arg = key.arg;
    if (arg is ArgDone) {
      // If it's a no-arg operation
      calculate(key, arg);
    } else {
      if (key.calcDisabled(controller)) {
        key.pressed(this);
      } else {
        // If our current mode doesn't disable calculations.  A branching
        // operation disables itself when we're not running a program.
        controller.getArgsAndRun(key, arg, this);
      }
    }
  }

  void calculate(Operation op, ArgDone arg) {
    try {
      op.pressed(this);
      final f = op.calcDisabled(controller) ? null : getCalculation(arg);
      if (f != null) {
        // Give the argument a chance to veto or defer the beforeCalculate
        // step.  This is needed for operations with a timeout, like the
        // 15C's STO to matrix.
        assert(!model.hasDeferToButtonUp);
        arg.handleOpBeforeCalculate(model, () => op.beforeCalculate(this));
        if (!model.hasDeferToButtonUp) {
          if (arg.liftStackIfEnabled(model)) {
            liftStackIfEnabled();
          }
          f(model);
          model.display.displayX();
          op.possiblyAlterStackLift(controller);
        }
      }
    } on CalculatorError catch (e, stack) {
      controller.showCalculatorError(e, stack);
      // ignore: avoid_catches_without_on_clauses
    } catch (e, s) {
      debugPrint('Unexpected exception $e\n\n$s');
      controller.showCalculatorError(CalculatorError(9), s);
    }
  }

  @override
  void handleNumberKey(final int num) {
    if (num >= model.displayMode.radix) {
      return;
    }
    _enterDigitEntryState().handleNumberKey(num);
  }

  @override
  void handleDecimalPoint() {
    if (model.displayMode.isFloatMode) {
      _enterDigitEntryState().handleDecimalPoint();
    }
  }

  @override
  void handleEEX() {
    if (model.displayMode.isFloatMode) {
      _enterDigitEntryState().handleEEX();
    }
  }

  DigitEntry _enterDigitEntryState() {
    final s = DigitEntry(controller);
    changeState(s);
    s.liftStackIfEnabled();
    stackLiftEnabled = true;
    return s;
  }

  @override
  void handleCHS() {
    if (!model.isFloatMode) {
      model.lastX = model.x;
    }
    model.chsX();
    model.display.displayX();
    stackLiftEnabled = true;
  }

  @override
  void handleBackspace() {
    stackLiftEnabled = false;
    if (model.errorBlink) {
      model.resetErrorBlink();
    } else {
      model.clx();
    }
    model.display.displayX();
  }

  @override
  void handleClearPrefix() {
    if (model.isFloatMode) {
      if (model.x.asMatrix == null) {
        model.display.current = model.x.floatPrefix;
        final blink = model.errorBlink ? BlinkMode.all : BlinkMode.none;
        model.display.update(blink: blink);
        changeState(ShowState(this));
      }
    } else if (model.settings.windowLongNumbers) {
      model.display.displayX(flash: false, disableWindow: true);
      changeState(ShowState(this, disableWindow: true));
    }
  }

  @override
  void handleShowImaginary() {
    if (!model.isComplexMode) {
      throw CalculatorError(3);
    }
    final tmpR = model.x;
    final tmpI = model.xImaginary;
    model.xPreserveCLX = tmpI;
    model.display.displayX();
    model.xPreserveCLX = tmpR;
    model.xImaginary = tmpI;
    changeState(ShowState(this));
  }

  @override
  void handleShowMem() {
    _handleShowMemImpl(model);
    changeState(ShowState(this));
  }

  @override
  void handleShowStatus() {
    _handleShowStatusImpl(model);
    changeState(ShowState(this));
  }

  @override
  void handleShow(IntegerDisplayMode mode) {
    if (model.isFloatMode) {
      return;
    }
    int lastWindow = 0;
    int show() {
      lastWindow = model.display.window;
      if (model.displayMode != mode) {
        model.display.window = 0;
      }
      model.display.currentShowingX = mode.format(model.x, model);
      model.display.update(neverReformat: true);
      return lastWindow;
    }

    if (!controller.delayForShow(show)) {
      changeState(ShowState(this, window: lastWindow));
    }
  }

  @override
  void handlePR() => changeState(ProgramEntry(controller));

  @override
  void handleOnOff() {
    model.onIsPressed.value = true;
    model.resetErrorBlink();
    model.display.current = '0ff?   ';
    model.display.update();
    stackLiftEnabled = true;
    changeState(OnOffKeyPressed(controller));
  }

  @override
  void handleShift(ShiftKey k) => model.shift = k;

  @override
  void onArgComplete(Operation op, ArgDone arg) => calculate(op, arg);

  @override
  void handleGotoDot(int value) {
    try {
      model.memory.program.currentLine = value;
      model.display.displayX();
    } on CalculatorError catch (e, s) {
      controller.showCalculatorError(e, s);
    }
  }

  @override
  void handleSST() => controller.singleStep(null);

  @override
  void handleBST() {
    model.memory.program.stepCurrentLine(-1);
    model.memory.program.displayCurrent();
    changeState(ShowState(this, delayed: false));
  }

  @override
  void handleRunStop() {
    final program = model.memory.program;
    assert(!program.isRunning);
    program.adjustStackForRunStopStarting();
    if (program.currentLine == 0 && program.lines > 0) {
      program.currentLine = 1;
      // On the 15C, if R/S is pressed just before the phantom RTN of an
      // integrate function that runs off the end of memory, it does *not*
      // handle it gracefully - it just wraps like this.
    }
    program.displayCurrent();
    final rc = controller as RealController;
    final spr = rc.suspendedProgramRunner;
    if (spr == null) {
      changeState(Running(rc, GosubProgramRunner()));
    } else {
      final running =
          spr.restart(RunningController(controller as RealController));
      changeState(Resumed(running, rc));
    }
  }

  @override
  void handleClearProgram() {
    stackLiftEnabled = true;
    final p = model.memory.program;
    p.currentLine = 0;
    p.suspendedProgram?.abort();
    p.suspendedProgram = null;
  }

  @override
  void gosubEntryDone(RunProgramArgInputState from, ArgDone label) =>
      from.handleGosubEntryDone(label);

  @override
  void handleLetterLabel(LetterLabel operation) {
    final program = model.memory.program;
    assert(controller is RealController);
    // The 15C's letter labels get translated to GSB <label> when entering
    // a program, so they cannot occur if we're running a program (i.e.
    // when controller is RunningController).  The return stack should only
    // be reset when we're not currently running a program, which is the only
    // case here.
    program.resetReturnStack();
    final gsb = controller.gsbOperation;
    try {
      program.gosub(operation.numericValue);
    } on CalculatorError catch (e, s) {
      controller.showCalculatorError(e, s);
      return;
    }
    program.displayCurrent();
    final s = RunProgramArgInputState(
        gsb, gsb.arg, controller, this, () => GosubProgramRunner());
    s.isDone = true;
    // Since we're telling the state it's done, it won't try to do the gosub.
    // It will just wait for button up, then switch to gosubDoneState, which
    // will run the program.
    changeState(s);
  }

  @override
  ControllerState gosubDoneState(ProgramRunner Function() runner) =>
      Running(controller as RealController, runner());
}

///
/// The state the calculator's in while entering digits.
///
class DigitEntry extends ActiveState {
  DigitEntry(super.con);

  String _entered = '';
  String _sign = '';
  int? _exponent;
  bool _negativeExponent = false; // -00 and 00 are different

  void takeOverFrom(final DigitEntry? other) {
    if (other != null) {
      _entered = other._entered;
      _sign = other._sign;
      _exponent = other._exponent;
      _negativeExponent = other._negativeExponent;
      _tryNewValue(_entered, _sign, _exponent, _negativeExponent);
    } else {
      changeState(Resting(controller));
    }
  }

  @override
  void buttonDown(Operation key) {
    if (key.endsDigitEntry) {
      model.x = model.x; // Clear CLX status
      changeState(Resting(controller)).buttonDown(key);
    } else {
      key.pressed(this);
    }
  }

  @override
  void handleNumberKey(final int num) {
    if (num >= model.displayMode.radix) {
      return;
    }
    final int? e = _exponent;
    if (e == null) {
      _tryNewValue(
          _entered + num.toRadixString(16), _sign, e, _negativeExponent);
    } else if (num < 10) {
      if (_negativeExponent) {
        _tryNewValue(_entered, _sign, -(((-e) * 10 + num) % 100), true);
      } else {
        _tryNewValue(_entered, _sign, (e * 10 + num) % 100, false);
      }
    }
  }

  static final _decimalDigits = RegExp('[0-9]');

  bool _tryNewValue(String ent, String sign, final int? ex, final bool negEx) {
    final int intDigits;
    if (model.isFloatMode) {
      intDigits = 0;
    } else {
      final ism = model.integerSignMode;
      final maxV = ism.fromBigInt(ism.maxValue(model), model, false);
      intDigits =
          model.displayMode.format(maxV, model).replaceAll(',', '').length - 2;
    }
    final Value? v;
    if (ex == null) {
      final Value? vv;
      if (!model.isFloatMode && sign == '-') {
        vv = null;
      } else {
        vv = model.tryParseValue(sign + ent);
      }
      if (vv != null) {
        v = vv;
        if (!model.isFloatMode) {
          while (ent.length > intDigits && ent.startsWith('0')) {
            ent = ent.substring(1);
          }
        }
      } else if (!model.isFloatMode) {
        // See page 36 - in integer modes, digit entry that overflows is
        // interesting.
        if (sign != "") {
          // CHS ends digit entry, so if we're here we've already had a
          // bit flow into the sign bit, so this is definitely overflow
          return false;
        }
        Value? big = model.displayMode
            .tryParse(sign + ent, model.memory.registers.helper68);
        if (big == null || (big.internal != (big.internal & model.wordMask))) {
          // Overflow.  See https://github.com/zathras/jrpn/issues/53.
          return false;
        } else {
          final originalEntLen = ent.length;
          v = Value.fromInternal(big.internal);
          ent = model.displayMode.format(v, model);
          ent = ent.substring(0, ent.length - 2); // Remove ' d' etc.
          if (ent.startsWith('-')) {
            ent = ent.substring(1);
            sign = '-';
          } else {
            sign = '';
          }
          if (ent.length < 10 && originalEntLen != ent.length) {
            // When there's overflow, that changes ent.  We might need to pad
            // zeros in the left.  See p. 36.
            final len = min(originalEntLen, intDigits);
            if (len > ent.length) {
              ent = ent.padLeft(len, '0');
            }
          }
        }
      } else {
        v = null;
      }
    } else {
      v = model.tryParseValue(sign + ent + (ex < 0 ? 'E$ex' : 'E+$ex'));
    }
    // It's important to try to parse '1e+3' and not '1e3' so that it
    // isn't interpreted as hex.
    if (v == null) {
      return false;
    }
    if (model.isFloatMode) {
      int max = ent.contains('.') ? 11 : 10;
      if (ent.length > max) {
        return false;
      }
    }
    model.xPreserveCLX = v;
    if (ex == null) {
      String d = ent;
      final dm = model.displayMode;
      if (model.displayLeadingZeros && dm != DisplayMode.decimal) {
        d = d.padLeft(intDigits, '0');
      }
      model.display.current = sign +
          dm.addCommas(
              d.replaceAll(',', ''), model.settings.integerModeCommas) +
          dm.displayName;
    } else {
      assert(model.displayMode.isFloatMode);
      assert(negEx || ex >= 0);
      final int noWidth = ent.contains('.') ? 1 : 0;
      int extra = 7 - (ent.length - noWidth);
      String show = ent;
      String pad;
      if (extra < 0) {
        if (model.settings.windowLongNumbers) {
          while (extra < 0) {
            if (!show.substring(show.length - 1).contains(_decimalDigits)) {
              return false; // Doesn't fit
            }
            show = show.substring(0, show.length - 1);
            extra++;
          }
        }
        pad = '';
      } else {
        pad = '       '.substring(0, extra);
      }
      final String exs;
      if (ex >= 10) {
        exs = 'E+$ex';
      } else if (ex > 0) {
        exs = 'E+0$ex';
      } else if (ex <= -10) {
        exs = 'E$ex';
      } else if (ex < 0) {
        exs = 'E-0${-ex}';
      } else if (negEx) {
        exs = 'E-00';
      } else {
        exs = 'E+00';
      }
      // Note that LcdDisplay dictates that 'e' is
      // part of a hex number, whereas E is for an exponent.
      model.display.current = sign +
          model.displayMode.addCommas(show, model.settings.integerModeCommas) +
          pad +
          exs;
    }
    _entered = ent;
    _sign = sign;
    _exponent = ex;
    _negativeExponent = negEx;
    model.display.update();
    return true;
  }

  @override
  void handleBackspace() {
    final int? ex = _exponent;
    if (ex != null) {
      int? newEx;
      bool newNeg;
      if (ex == 0) {
        if (_negativeExponent) {
          newNeg = false;
          newEx = 0;
        } else {
          newNeg = false;
          newEx = null;
        }
      } else {
        newEx = ex ~/ 10;
        newNeg = _negativeExponent;
      }
      _tryNewValue(_entered, _sign, newEx, newNeg);
    } else if (!model.isFloatMode && _sign == '-') {
      // See https://github.com/zathras/jrpn/issues/53...  We convert
      // to unsigned, then subtract the digit
      final displayMode = model.displayMode as IntegerDisplayMode;
      final String fmt = displayMode.formatUnsigned(model.x, model);
      _tryNewValue(fmt.substring(0, fmt.length - 3), '', ex, _negativeExponent);
    } else if (_entered.length > 1) {
      if (_sign == '-') {
        _tryNewValue(_entered, '', ex, _negativeExponent);
      } else {
        _tryNewValue(_entered.substring(0, _entered.length - 1), _sign, ex,
            _negativeExponent);
      }
    } else {
      changeState(Resting(controller)).handleBackspace();
    }
  }

  @override
  void handleCHS() {
    if (!model.isFloatMode) {
      model.lastX = model.x;
      changeState(Resting(controller));
    }
    final int? ex = _exponent;
    if (ex != null) {
      _tryNewValue(_entered, _sign, -ex, !_negativeExponent);
    } else if (_sign == '') {
      bool done = _tryNewValue(_entered, '-', ex, _negativeExponent);
      if (!done) {
        // Happens for hex, oct, bin, and unsigned dec
        model.chsX(); // In unsigned mode this does what the 16C does
        model.display.displayX(flash: false);
        _entered = '';
      }
    } else {
      _tryNewValue(_entered, '', ex, _negativeExponent);
      if (model.xI.isNegative) {
        assert(model.x.internal == model.signMask); // e.g. -32768 for 16 bit
        model.gFlag = true;
      }
    }
  }

  @override
  void handleDecimalPoint() {
    if (_exponent == null) {
      if (_entered == '') {
        _tryNewValue('0.', _sign, _exponent, _negativeExponent);
      } else {
        _tryNewValue('$_entered.', _sign, _exponent, _negativeExponent);
      }
    }
  }

  @override
  void handleEEX() {
    if (_exponent != null) {
      return;
    }
    assert(!_negativeExponent);
    if (model.settings.windowLongNumbers) {
      int pos = _entered.indexOf('.');
      if (pos == -1) {
        pos = _entered.length;
      }
      if (pos > 7) {
        // no room
        return;
      }
    }
    if (_entered == '') {
      _entered = '1';
    }
    _tryNewValue(_entered, _sign, 0, _negativeExponent);
  }

  @override
  void handleClearPrefix() {
    if (model.isFloatMode || model.settings.windowLongNumbers) {
      changeState(Resting(controller)).handleClearPrefix();
    }
  }

  @override
  void handleShowImaginary() =>
      changeState(Resting(controller)).handleShowImaginary();

  @override
  void handleShowStatus() =>
      changeState(Resting(controller)).handleShowStatus();

  @override
  void handleShowMem() => changeState(Resting(controller)).handleShowMem();

  @override
  void handleShow(IntegerDisplayMode mode) {
    if (!model.isFloatMode) {
      changeState(Resting(controller)).handleShow(mode);
    }
  }

  @override
  void handleSST() => controller.singleStep(this);

  @override
  void handleBST() {
    changeState(Resting(controller)).handleBST();
  }

  @override
  void handleOnOff() => changeState(Resting(controller)).handleOnOff();

  @override
  void handlePR() => changeState(Resting(controller)).handlePR();

  @override
  void handleRunStop() => changeState(Resting(controller)).handleRunStop();

  @override
  void handleShift(ShiftKey k) => model.shift = k;

  @override
  void onArgComplete(Operation op, ArgDone arg) => unreachable();

  @override
  void handleGotoDot(int value) => unreachable();

  @override
  void handleClearProgram() =>
      changeState(Resting(controller)).handleClearProgram();

  @override
  void gosubEntryDone(RunProgramArgInputState from, ArgDone label) =>
      changeState(Resting(controller)).gosubEntryDone(from, label);

  @override
  void handleLetterLabel(LetterLabel operation) =>
      changeState(Resting(controller)).handleLetterLabel(operation);

  @override
  ControllerState gosubDoneState(ProgramRunner Function() runner) =>
      throw StateError('unreachable');
}

///
/// Inputting an argument.  Generally, the calculator silently waits for
/// keypresses giving the argument value.  For example, when recalling
/// register 1c, the user presses "RCL . c"; the calculator is in this
/// state while waiting for the ". c" to be pressed.
///
class ArgInputState extends ControllerState {
  final Operation op;
  Arg _arg;
  final LimitedState lastState;

  ArgInputState(this.op, this._arg, Controller con, this.lastState)
      : super(con);

  // GTO and GSB take index registers, but not .

  @override
  void buttonDown(Operation key) {
    if (key == Arg.fShift || key == Arg.gShift) {
      lastState.buttonDown(key);
      return;
    }
    final Arg? next = _arg.matches(key, model.userMode);
    if (next == null) {
      changeState(lastState);
      lastState.buttonDown(key);
    } else if (next is ArgDone) {
      done(next);
    } else {
      _arg = next;
    }
  }

  void done(ArgDone arg) {
    changeState(lastState);
    lastState.onArgComplete(op, arg);
  }
}

///
/// Inputting the argument for GSB.  See [handleGosubEntryDone].
///
class RunProgramArgInputState extends ArgInputState {
  final ProgramRunner Function() runner;
  RunProgramArgInputState(
      super.op, super.arg, super.con, super.lastState, this.runner);

  bool isDone = false;

  @override
  void done(ArgDone arg) {
    lastState.gosubEntryDone(this, arg);
    isDone = true;
  }

  ///
  /// When GSB <label> is pressed (but before it is released), and when we're
  /// not entering a program, we pre-display the first instruction of the
  /// program.  So, Resting.gosubEntryDone calls this method to do that.
  ///
  void handleGosubEntryDone(ArgDone label) {
    // We know that we're coming from a keyboard-entered GSB, since arguments
    // are being input.
    assert(controller is RealController);
    final program = model.memory.program;
    program.resetReturnStack(); // Since we're starting new program
    try {
      label.getCalculation(model, const _OperationSelector())!(model);
    } on CalculatorError catch (e, s) {
      changeState(lastState);
      controller.showCalculatorError(e, s);
      return;
    }
    program.displayCurrent();
    // On button up, another goto(label) will happen, but that's harmless.
  }

  @override
  void buttonUp(Operation key) {
    if (isDone) {
      op.possiblyAlterStackLift(controller);
      changeState(lastState.gosubDoneState(runner)).buttonUp(key);
    } else {
      super.buttonUp(key); // NOP
    }
  }
}

///
/// State while a message is showing, like "Error 2."
///
class MessageShowing extends ControllerState {
  final ControllerState last;

  MessageShowing(this.last) : super(last.controller);

  @override
  void buttonDown(Operation key) {
    controller.model.display.displayX(flash: false);
    changeState(last);
  }
}

///
/// State while entering a program.
///
class ProgramEntry extends LimitedState {
  Timer? _autorepeat;
  bool _alreadyDisplayed = false;

  ProgramEntry(super.con);

  ProgramMemory get program => model.memory.program;

  @override
  void onChangedTo() {
    model.prgmFlag = true;
    if (!_alreadyDisplayed) {
      program.displayCurrent();
    }
  }

  @override
  void buttonDown(Operation key) {
    if (key == controller.gtoOperation) {
      changeState(WaitingForGotoDot(controller, this));
    } else if (key is NonProgrammableOperation) {
      key.pressed(this);
    } else {
      final arg = key.arg;
      if (arg is ArgDone) {
        _addOperation(key, arg);
      } else {
        // This includes gsb and lbl
        controller.state = key.makeInputState(key.arg, controller, this);
      }
    }
  }

  @override
  void buttonUp(Operation key) {
    _autorepeat?.cancel();
    _autorepeat = null;
  }

  @override
  void onArgComplete(Operation op, ArgDone arg) {
    _addOperation(op, arg);
  }

  void _addOperation(Operation op, ArgDone argValue) {
    model.memory.program.insert(model.newProgramInstruction(op, argValue));
    // throws CalculatorError if memory full
    program.displayCurrent();
  }

  @override
  void handleBackspace() {
    if (program.currentLine > 0) {
      program.deleteCurrent();
    }
    program.displayCurrent();
  }

  @override
  void handleGotoDot(int value) {
    try {
      program.currentLine = value;
      program.displayCurrent();
    } on CalculatorError catch (e, s) {
      controller.showCalculatorError(e, s);
    }
  }

  @override
  void handleSST() => _handleRepeatingStep(1);

  @override
  void handleBST() => _handleRepeatingStep(-1);

  void _handleRepeatingStep(final int delta) {
    assert(_autorepeat == null);
    int ticks = 0;
    void task(Timer _) {
      if (ticks == 0 || ticks > 3) {
        program.stepCurrentLine(delta);
        program.displayCurrent();
      }
      ticks++;
    }

    Timer t = Timer.periodic(const Duration(milliseconds: 350), task);
    task(t);
    _autorepeat = t;
  }

  @override
  void handleClearPrefix() {
    // Do nothing more; this just clears the f shift status.
  }

  @override
  void handleShowImaginary() {
    // Do nothing more; this just clears the f shift status.
  }

  @override
  void handleDecimalPoint() {
    // This can happen if we come from ArgInputState.
    _addOperation(Operations.dot, Operations.dot.arg as ArgDone);
  }

  @override
  void gosubEntryDone(RunProgramArgInputState from, ArgDone label) {
    _addOperation(controller.gsbOperation, label);
  }

  @override
  void handlePR() {
    changeState(Resting(controller));
    model.prgmFlag = false;
    model.display.displayX();
  }

  @override
  void handleShift(ShiftKey k) => model.shift = k;

  @override
  void handleShowStatus() {
    _handleShowStatusImpl(model);
    _alreadyDisplayed = true;
    changeState(ShowState(this, fromProgramEntry: true));
  }

  @override
  void handleShowMem() {
    _handleShowMemImpl(model);
    _alreadyDisplayed = true;
    changeState(ShowState(this, fromProgramEntry: true));
  }

  @override
  void handleClearProgram() {
    program.reset();
    program.displayCurrent();
  }

  @override
  void handleOnOff() {
    model.prgmFlag = false;
    changeState(Resting(controller)).handleOnOff();
  }

  @override
  ControllerState gosubDoneState(ProgramRunner Function() runner) => this;
}

///
/// State after the GTO key is pressed, when we don't know if the user
/// will press "." (meaning navigate to a specific line number), or a
/// label.  In the spirit of Beckett, we do hope one arrives before
/// too long.
///
/// On the 15C, CHS is used instead of dot.
///
class WaitingForGotoDot extends ControllerState {
  final LimitedState last;

  WaitingForGotoDot(Controller con, this.last) : super(con) {
    assert(con is RealController); // We're not running a program
  }

  @override
  void buttonDown(Operation key) {
    if (key == controller.gotoLineNumberKey) {
      changeState(WaitingForGotoDotLines(controller, last));
    } else {
      changeState(ArgInputState(controller.gtoOperation,
              controller.gtoOperation.arg, controller, last))
          .buttonDown(key);
      // Not controller.runWithArg().  We need to invoke buttonDown, which can't
      // be done with a RunningController.  In the RunningController case, we
      // never go into the WaitingForGotoDot state -- see assert in
      // constructor.
    }
  }
}

///
/// After "GTO ." is pressed, we're in this state collecting the
/// three-digit line number.
///
class WaitingForGotoDotLines extends ControllerState {
  final LimitedState last;
  int _value = 0;
  int _digits = 0;

  WaitingForGotoDotLines(super.con, this.last);

  @override
  void buttonDown(Operation key) {
    int? digit = key.numericValue;
    if (digit == null || digit > 9) {
      changeState(last); // But eat the digit
      return;
    }
    _value *= 10;
    _value += digit;
    _digits++;
    if (_digits >= 3) {
      changeState(last).handleGotoDot(_value);
    }
  }
}

///
/// State while we're temporarily showing something, while a button is still
/// pressed.  For example "f show Hex" lands us in this state.
///
class ShowState extends ControllerState {
  final ControllerState _last;
  final bool disableWindow;
  final bool delayed;
  final bool fromProgramEntry;
  final int? window;

  ShowState(this._last,
      {this.disableWindow = false,
      this.delayed = true,
      this.fromProgramEntry = false,
      this.window})
      : super(_last.controller);

  @override
  void buttonUp(Operation key) {
    if (fromProgramEntry) {
      model.memory.program.displayCurrent(delayed: delayed);
    } else {
      model.display.displayX(
          delayed: delayed, disableWindow: disableWindow, setWindow: window);
    }
    changeState(_last);
  }

  @override
  void buttonDown(Operation key) {}
}

///
/// State where we ignore keypresses, because the calculator is off or
/// running self-tests.
///
class DoNothing extends ControllerState {
  DoNothing(super.con);

  @override
  void buttonDown(Operation key) {}
}

///
/// State for after the ON key is pressed, while we're waiting to see if they
/// pick a special function, or maybe press the ON key again to turn the
/// calculator off.
///
class OnOffKeyPressed extends DoNothing {
  OnOffKeyPressed(super.con);

  @override
  void buttonDown(Operation key) {
    model.onIsPressed.value = false;
    if (key == Operations.onOff) {
      changeState(DoNothing(controller));
      Future<void> res = () async {
        try {
          await model.writeToPersistentStorage(unconditional: true);
        } finally {
          if (!kIsWeb && (Platform.isLinux || Platform.isWindows)) {
            // Current version on Linux dumps core on pop.
            // Current version on Windows keeps window there.
            exit(0);
          } else {
            await SystemNavigator.pop();
            // That kills us on some platforms, but it doesn't make sense on
            // web.  It's a NOP on iOS, because apps terminating themselves
            // is against the Apple human interface guidelines (which doesn't
            // make a bit of sense if you're turning a calculator off, but
            // whatever.)  So, on platforms were we can't go away, we blank
            // the LCD display and wait for the ON button to be pressed.
            model.display
                .show(LcdContents.blank(lcdDigits: model.display.lcdDigits));
            changeState(CalculatorOff(controller));
          }
        }
      }();
      unawaited(res);
    } else if (key == Operations.dot) {
      model.settings.euroComma = !model.settings.euroComma;
      model.display.displayX();
      changeState(Resting(controller));
    } else if (key == controller.minusOp) {
      controller.reset();
      model.reset();
      final r = changeState(Resting(controller));
      model.display.current = 'pr error ';
      model.display.update();
      changeState(MessageShowing(r));
    } else if (key == controller.multOp) {
      changeState(DoNothing(controller));
      Future<void> runTests() async {
        try {
          DateTime start = DateTime.now();
          model.display.current = '  RuNNING';
          model.display.update(blink: BlinkMode.justDigits);
          await controller.newSelfTests(inCalculator: true).runAll();
          DateTime now = DateTime.now();
          Duration sleep =
              (const Duration(milliseconds: 2500)) - now.difference(start);
          if (!sleep.isNegative) {
            await Future<void>.delayed(sleep);
          }
          changeState(Resting(controller));
          model.display.show(model.selfTestContents());
          changeState(MessageShowing(Resting(controller)));
        } on CalculatorError catch (e, s) {
          changeState(Resting(controller));
          controller.showCalculatorError(e, s);
          // ignore: avoid_catches_without_on_clauses
        } catch (e, s) {
          debugPrint('Unexpected exception $e\n\n$s');
          changeState(Resting(controller));
          controller.showCalculatorError(CalculatorError(9), s);
        }
      }

      unawaited(runTests());
    } else {
      model.display.displayX();
      changeState(Resting(controller));
    }
  }
}

///
/// State while we're running a program.  While we're in this state, our
/// [Controller] stays in [Running], but we create a [RunningController]
/// that has its own [ControllerState].
///
class Running extends ControllerState {
  RunningController _fake;
  ProgramRunner _runner;
  ProgramRunner? _pushedRunner;
  bool _stopNext;
  void Function(CalculatorError?)? _singleStepOnDone;
  double pendingDelay = 0;
  late Timer showRunningTimer;
  DateTime _lastDelay = DateTime.now();

  Running(RealController c, this._runner)
      : _fake = RunningController(c),
        _stopNext = false,
        super(c) {
    final p = c.model.program;
    assert(p.returnStackPos <= 0);
    p.suspendedProgram?.abort();
    p.suspendedProgram = null;
  }

  Running.singleStep(this._fake, this._runner, this._singleStepOnDone)
      : _stopNext = true,
        super(_fake.real) {
    assert(_fake.real.suspendedProgramRunner == null);
    _stopNext = true;
  }

  @override
  void buttonDown(Operation key) {
    _stopNext = true;
  }

  @override
  void buttonUp(Operation key) {
    if (!_stopNext) {
      model.displayDisabled = true;
      unawaited(_run());
    }
  }

  void runSingleStep() {
    assert(_stopNext);
    model.displayDisabled = true;
    unawaited(_run());
  }

  /// We delay the showing of the blinking running a little bit, so that
  /// we don't get a very short flash of "running" when msPerInstruction
  /// is set to 0.
  Timer _showRunning() => Timer(const Duration(milliseconds: 20), () {
        assert(model.displayDisabled);
        model.displayDisabled = false;
        model.display.current = '  RuNNING';
        model.display.update(blink: BlinkMode.justDigits);
        model.displayDisabled = true;
      });

  Future<void> _run() async {
    final program = model.memory.program;
    _onStart();
    if (program.currentLine > program.lines) {
      program.currentLine = min(1, program.lines);
    }
    bool aborted = false;
    try {
      await _runner._run(this, true);
    } on CalculatorError catch (e) {
      _fake.pendingError = e;
      program.programListener.onError(e);
    } on _Aborted {
      aborted = true;
      // We're unawaited, so we swallow exception.
    } finally {
      // For  bit of robustness in case there's a bug, we put the restoration
      // to a normal state in a finally.
      if (!aborted) {
        if (_fake.pendingError == null) {
          program.programListener.onDone();
        }
        _onDone();
      }
    }
  }

  void _onStart() {
    assert(model.displayDisabled); // Because buttonUp() set it
    showRunningTimer = _showRunning();
    model.program.runner = _runner;
    pendingDelay = model.settings.msPerInstruction;
  }

  void _onDone() {
    final program = model.memory.program;
    showRunningTimer.cancel();
    model.displayDisabled = false;
    model.display.current = ' ';
    program.runner = null;
    final onDone = _singleStepOnDone;
    final CalculatorError? err = _fake.pendingError;
    _fake.pendingError = null;
    if (onDone == null) {
      changeState(Resting(controller));
      if (err != null) {
        _fake.real.showCalculatorError(err, null);
      } else {
        model.display.update(); // Blank with no delay
        model.display.displayX();
      }
    } else {
      _singleStepOnDone = null;
      onDone(err);
    }
  }

  Future<void> runProgramLoop(
      {Set<int> acceptableErrors = const <int>{}}) async {
    final ProgramListener listener = model.memory.program.programListener;
    final settings = controller.model.settings;
    final program = model.memory.program;
    for (;;) {
      if (!_stopNext) {
        final now = DateTime.now();
        if (now.difference(_lastDelay).inMilliseconds >= 100) {
          // Delay at least 5 ms every 100ms, so the calculator doesn't become
          // non-responsive if the user cranks the speed up all the way.
          pendingDelay = max(5, pendingDelay);
        }
        if (pendingDelay >= 5) {
          // Only delay if 5ms has accrued.  This, combined with the logic
          // above, ensures we really do throttle the CPU at 95%.  The
          // observed actual delay times, at least on MacOS, have a slop of
          // one or two ms anyway, so we're not losing anything important
          // by enforcing slightly more granular sleep in certain edge cases
          // (e.g. msPerInstruction of 1 or .1).
          _lastDelay = now;
          final delay = Duration(microseconds: (pendingDelay * 1000).round());
          await (Future<void>.delayed(delay));
          final actual =
              (DateTime.now().difference(_lastDelay)).inMicroseconds / 1000;
          pendingDelay -= actual;
        }
      }
      final int line = program.currentLine;
      final ProgramInstruction<Operation> instr = program[line];
      if (instr.op == Operations.rs) {
        // If we let it execute, it would recursively create another state!
        listener.onRS();
        _stopNext = true;
        program.incrementCurrentLine();
      } else {
        int oldLine = program.currentLine;
        program.incrementCurrentLine();
        _fake.setArg(instr.arg);
        _fake.buttonDown(instr.op);
        // This bounces back to RunningController.runWithArg() if there's an
        // argument.
        _fake.buttonUp();
        if (_fake.pendingError != null) {
          program.currentLine = oldLine;
        }
      }
      model.addProgramTraceToSnapshot(
          () => '   ${line.toString().padLeft(3, '0')}'
              ' ${instr.programListing.padRight(14)}');
      if (settings.traceProgramToStdout) {
        final out = StringBuffer();
        // ignore: dead_code
        if (false) {
          // Simplified version, useful for comparisons
          out.write(line.toString());
          out.write(' ');
          out.write(model.xF.toStringAsExponential(9));
          out.write(' ');
          out.write(model.yF.toStringAsExponential(9));
        } else {
          out.write('  ');
          out.write(line.toString().padLeft(3, '0'));
          out.write(' ');
          out.write(instr.programListing.padRight(14));
          out.write('xyzt:');
          for (int i = 0; i < 4; i++) {
            out.write('  ');
            final Value v = model.getStackByIndex(i);
            final int? vm = v.asMatrix;
            if (vm != null) {
              out.write(String.fromCharCodes([('A'.codeUnitAt(0) + vm)]));
            } else if (model.isComplexMode) {
              out.write(model.getStackByIndexC(i));
            } else if (model.isFloatMode) {
              out.write(v.asDouble);
            } else {
              out.write('0x');
              out.write(v.internal.toRadixString(16));
            }
          }
        }
        // ignore: avoid_print
        print(out.toString());
        // Too busy: print(program.debugReturnStack());
        if (_fake.pendingError != null) {
          // ignore: avoid_print
          print("*********** ${_fake.pendingError}");
        }
      }
      pendingDelay +=
          settings.msPerInstruction / ((instr.op.numericValue == null) ? 1 : 5);
      // While we're not simulating real instruction time, the number keys
      // are a lot faster than most other operations on a real calculator,
      // and they might be pretty common.  At a guess, we say 5x faster.
      final err = _fake.pendingError;
      if (_fake.pause != null && err == null && !_stopNext) {
        // PSE instruction, show-BIN, etc.
        final updateDisplay = _fake.pause!;
        _fake.pause = null;
        listener.onPause();
        showRunningTimer.cancel();
        model.displayDisabled = false;
        int? window = updateDisplay();
        await listener.resumeFromPause();
        if (window != null) {
          model.display.window = window;
        }
        model.displayDisabled = true;
        showRunningTimer = _showRunning();
      }
      if (program.returnStackPos < _runner.returnStackStartPos) {
        // If we've popped off our return value
        assert(program.returnStackPos == -1 ||
            program.currentLine == MProgramRunner.pseudoReturnAddress);
        assert(_pushedRunner == null);
        break;
      } else if (err != null) {
        assert(_pushedRunner == null);
        if (acceptableErrors.contains(err.num15)) {
          _fake.pendingError = null;
          throw err;
        }
        listener.onError(err);
        _onDone();
        _stopNext = false;
        await _runner.suspend();
        _onStart();
      } else if (_stopNext) {
        _stopNext = false;
        listener.onStop();
        _onDone();
        await _runner.suspend();
        _onStart();
      }
      if (_pushedRunner != null) {
        final parent = _runner;
        _runner = _pushedRunner!;
        _pushedRunner = null;
        _runner.pushPseudoReturn(model);
        _runner.returnStackStartPos = program.returnStackPos;
        await _runner._run(this, false);
        _runner = parent;
      }
    }
  }

  void restarting(void Function(CalculatorError?)? singleStepOnDone) {
    _singleStepOnDone = singleStepOnDone;
    model.program.suspendedProgram = null;
    model.displayDisabled = true;
    _stopNext = singleStepOnDone != null;
  }

  @override
  void abort() {
    super.abort();
    _stopNext = true;
    _fake.real.suspendedProgramRunner?.abort();
    model.program.suspendedProgram?.abort();
    model.program.suspendedProgram = null;
    model.program.runner?.abort();
    model.program.runner = null;
  }
}

abstract class ProgramRunner extends MProgramRunner {
  ProgramRunner? _parent;
  ProgramRunner? get parent => _parent;
  late Running _caller;
  Running get caller => _caller;
  Model get model => _caller.model;
  int returnStackStartPos = 0; // Correct for top-level runner
  Completer<void>? _suspended;

  bool get runImplicitRtnOnSST => false;

  Future<void> _run(Running caller, bool starting) {
    _caller = caller;
    if (starting) {
      checkStartRunning();
    }
    return run();
  }

  Future<void> run();

  ///
  /// Called from the calculation part of an operation to cause
  /// a program to start running with the next instruction.
  ///
  @override
  void startRunningProgram(ProgramRunner newRunner) {
    newRunner._parent = this;
    newRunner._caller = _caller;
    newRunner.checkStartRunning();
    _caller._pushedRunner = newRunner;
  }

  ///
  /// Called in order to see if it's OK to start
  /// running.  Throws CalculatorError if not.
  ///
  void checkStartRunning();

  @override
  @mustCallSuper
  void abort() {
    _suspended?.completeError(_Aborted());
  }

  Future<void> suspend() async {
    assert(_suspended == null);
    final s = _suspended = Completer();
    _caller.model.program.suspendedProgram = this;
    await s.future;
    assert(_suspended == null);
    assert(_caller._fake.real.suspendedProgramRunner == null);
  }

  void resume() {
    final s = _suspended!;
    _suspended = null;
    assert(!s.isCompleted);
    s.complete();
  }

  Running restart(RunningController newFake,
      {void Function(CalculatorError?)? singleStepOnDone}) {
    _caller._fake = newFake;
    _caller.restarting(singleStepOnDone);
    resume();
    return _caller;
  }
}

class _Aborted {}

class GosubProgramRunner extends ProgramRunner {
  GosubProgramRunner();

  @override
  int get registersRequired => 0;

  @override
  Future<void> run() => _caller.runProgramLoop();

  @override
  void checkStartRunning() {}
  // Nothing special needs to happen when a GSB happens within a program; we
  // just keep using the existing runner.
}

///
/// State while single-stepping through a program.  Like [Running], this state
/// creates a [RunningController] that has its own [ControllerState].
///
class SingleStepping extends ControllerState with StackLiftEnabledUser {
  final RunningController _fake;
  // We are a state of _fake.real, so we will get the buttonUp notification
  // from the real controller.
  bool _running = false;

  SingleStepping(RunningController super.rc) : _fake = rc;

  ProgramMemory<Operation> get program => model.memory.program;

  @override
  void onChangedTo() {
    if (program.currentLine == 0 && program.lines > 0) {
      final spr = _fake.real.suspendedProgramRunner;
      if (spr?.runImplicitRtnOnSST != true) {
        program.currentLine = 1;
        stackLiftEnabled = true;
        changeState(Resting(_fake));
      }
    }
    program.displayCurrent();
    model.displayDisabled = true;
  }

  @override
  void buttonDown(Operation key) {}

  @override
  void buttonUp(Operation key) {
    if (_running) {
      return;
    }
    if (program.lines == 0) {
      model.displayDisabled = false;
      _onDone(null);
    } else {
      _running = true;
      final spr = _fake.real.suspendedProgramRunner;
      ProgramInstruction<Operation> instr = program[program.currentLine];
      if (instr.op == Operations.rs) {
        stackLiftEnabled = true;
      }
      if (spr == null) {
        assert(!program.isRunning);
        program.adjustStackForRunStopStarting();
        final s = Running.singleStep(_fake, GosubProgramRunner(), _onDone);
        s.runSingleStep();
      } else {
        spr.restart(_fake, singleStepOnDone: _onDone);
      }
    }
  }

  void _onDone(CalculatorError? error) {
    if (error != null) {
      _fake.returnToParent(Resting(_fake.real));
      _fake.real.showCalculatorError(error, null);
    } else {
      final DigitEntry? old = _fake.currentDigitEntryState;
      if (old != null) {
        final replacement = DigitEntry(_fake.real);
        replacement.takeOverFrom(old);
        // We came from DigitEntryState in our parent.  If we're
        // still in DigitEntryState in the program, stay in digit entry
        // state, with whatever changes have been made.
        _fake.returnToParent(replacement);
      } else {
        _fake.returnToParent(Resting(_fake.real));
        model.display.displayX(flash: false);
      }
    }
  }
}

///
/// State when we resume program execution with the R/S key
///
class Resumed extends ControllerState {
  final Running running;
  Resumed(this.running, Controller controller) : super(controller);

  @override
  void buttonDown(Operation key) {
    running.buttonDown(key); // Halts it.
  }
}

///
/// State when the calculator is off.  On desktop and mobile, the calculator
/// screen is dismissed, but that's awkward on the web, especially if the
/// calculator is embedded in a page.  So, in the web case, we turn off the
/// LCD display, and wait in this state to see if the user presses ON at
/// some point.
///
class CalculatorOff extends ControllerState {
  CalculatorOff(super.con);

  @override
  void buttonDown(Operation key) {
    if (key == Operations.onOff) {
      model.display.displayX();
      changeState(Resting(controller));
    }
  }
}

void _handleShowStatusImpl(Model model) {
  final String sm = model.integerSignMode.statusText;
  final String w =
      (model.wordSize < 10) ? '0${model.wordSize}' : '${model.wordSize}';
  final f = StringBuffer();
  for (int i = 3; i >= 0; i--) {
    f.write(model.getFlag(i) ? '1' : '0');
  }
  model.display.current = '$sm-$w-$f ';
  model.display.update();
}

void _handleShowMemImpl(Model model) {
  model.display.current = model.memory.policy.showMemory();
  model.display.update();
}

class _OperationSelector
    extends DisplayModeSelector<void Function(Model)?, NormalOperation> {
  const _OperationSelector();

  @override
  void Function(Model)? selectInteger(NormalOperation arg) => arg.intCalc;
  @override
  void Function(Model)? selectFloat(NormalOperation arg) => arg.floatCalc;
  @override
  void Function(Model)? selectComplex(NormalOperation arg) => arg.complexCalc;
}
