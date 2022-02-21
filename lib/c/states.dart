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
  LimitedState(Controller con) : super(con);

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

  void gosubEntryDone(GosubArgInputState from, ArgDone label);

  @protected
  void Function(Model<Operation>)? getCalculation(ArgDone ad) =>
      ad.getCalculation(model, const _OperationSelector());

  ControllerState gosubDoneState();

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
  ActiveState(Controller con) : super(con);

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
  Resting(Controller con) : super(con);

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
    op.pressed(this);
    final f = op.calcDisabled(controller) ? null : getCalculation(arg);
    if (f != null) {
      try {
        op.beforeCalculate(this);
        f(model);
        model.display.displayX();
      } on CalculatorError catch (e) {
        controller.showCalculatorError(e);
        // ignore: avoid_catches_without_on_clauses
      } catch (e, s) {
        debugPrint('Unexpected exception $e\n\n$s');
        controller.showCalculatorError(CalculatorError(9));
      }
      op.possiblyAlterStackLift(controller);
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
  }

  @override
  void handleBackspace() {
    stackLiftEnabled = false;
    model.x = Value.zero;
    model.display.displayX();
  }

  @override
  void handleClearPrefix() {
    if (model.isFloatMode) {
      if (model.x.asMatrix == null) {
        model.display.current = model.x.floatPrefix;
        model.display.update();
        changeState(ShowState(this));
      }
    } else if (model.settings.windowEnabled) {
      model.display.displayX(flash: false, disableWindow: true);
      changeState(ShowState(this, disableWindow: true));
    }
  }

  @override
  void handleShowImaginary() {
    if (!model.isComplexMode) {
      throw CalculatorError(3);
    }
    final tmp = model.xC;
    model.x = model.xImaginary;
    model.display.displayX();
    model.xC = tmp;
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
    if (model.displayMode != mode) {
      model.display.window = 0;
      model.display.current = mode.format(model.x, model);
      model.display.update();
    }
    changeState(ShowState(this));
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
    } on CalculatorError catch (e) {
      controller.showCalculatorError(e);
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
    program.handleRunStopKepyress();
    if (program.currentLine == 0 && program.lines > 0) {
      program.currentLine = 1;
    }
    program.displayCurrent();
    changeState(Running(controller));
  }

  @override
  void handleClearProgram() {
    stackLiftEnabled = true;
    model.memory.program.currentLine = 0;
  }

  @override
  void gosubEntryDone(GosubArgInputState from, ArgDone label) =>
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
    } on CalculatorError catch (e) {
      controller.showCalculatorError(e);
      return;
    }
    program.displayCurrent();
    final s = GosubArgInputState(gsb, gsb.arg, controller, this);
    s.isDone = true;
    // Since we're telling the state it's done, it won't try to do the gosub.
    // It will just wait for button up, then switch to gosubDoneState, which
    // will run the program.
    changeState(s);
  }

  @override
  ControllerState gosubDoneState() => Running(controller);
}

///
/// The state the calculator's in while entering digits.
///
class DigitEntry extends ActiveState {
  DigitEntry(Controller con) : super(con);

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
    } else {
      changeState(Resting(controller));
    }
  }

  @override
  void buttonDown(Operation key) {
    if (key.endsDigitEntry) {
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
    final Value? v;
    if (ex == null) {
      final vv = model.tryParseValue(sign + ent);
      if (vv != null) {
        v = vv;
      } else if (!model.isFloatMode) {
        // See page 36 - in integer modes, digit entry that overflows is
        // interesting.
        Value? big = model.displayMode
            .tryParse(sign + ent, model.memory.registers.helper68);
        if (big == null) {
          v = null;
        } else {
          v = Value.fromInternal(big.internal & model.wordMask);
          ent = model.displayMode.format(v, model);
          ent = ent.substring(0, ent.length - 2); // Remove ' d' etc.
          if (ent.startsWith('-')) {
            ent = ent.substring(1);
            sign = '-';
          } else {
            sign = '';
          }
          if (ent.length < 10 && v.internal != big.internal) {
            ent = '0' + ent;
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
    if (model.isFloatMode && model.settings.windowEnabled) {
      int max = ent.contains('.') ? 11 : 10;
      if (ent.length > max) {
        return false;
      }
    }
    model.x = v;
    if (ex == null) {
      model.display.current = sign +
          model.displayMode.addCommas(ent.replaceAll(',', '')) +
          model.displayMode.displayName;
    } else {
      assert(model.displayMode.isFloatMode);
      assert(negEx || ex >= 0);
      final int noWidth = ent.contains('.') ? 1 : 0;
      int extra = 7 - (ent.length - noWidth);
      String show = ent;
      String pad;
      if (extra < 0) {
        if (model.settings.windowEnabled) {
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
      model.display.current =
          sign + model.displayMode.addCommas(show) + pad + exs;
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
        _tryNewValue('0$_entered.', _sign, _exponent, _negativeExponent);
      } else {
        _tryNewValue('$_entered.', _sign, _exponent, _negativeExponent);
      }
    }
  }

  @override
  void handleEEX() {
    if (_exponent == null) {
      assert(!_negativeExponent);
      if (_entered == '') {
        _entered = '1';
      }
      _tryNewValue(_entered, _sign, 0, _negativeExponent);
    }
  }

  @override
  void handleClearPrefix() {
    if (model.isFloatMode || model.settings.windowEnabled) {
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
  void gosubEntryDone(GosubArgInputState from, ArgDone label) =>
      changeState(Resting(controller)).gosubEntryDone(from, label);

  @override
  void handleLetterLabel(LetterLabel operation) =>
      changeState(Resting(controller)).handleLetterLabel(operation);

  @override
  ControllerState gosubDoneState() => throw StateError('unreachable');
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
class GosubArgInputState extends ArgInputState {
  GosubArgInputState(
      Operation op, Arg arg, Controller con, LimitedState lastState)
      : super(op, arg, con, lastState);

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
    } on CalculatorError catch (e) {
      changeState(lastState);
      controller.showCalculatorError(e);
      return;
    }
    program.displayCurrent();
    // On button up, another goto(label) will happen, but that's harmless.
    // @@ TODO:  Check that it's a goto, not a gosub, and explain this better.
  }

  @override
  void buttonUp(Operation key) {
    if (isDone) {
      op.possiblyAlterStackLift(controller);
      changeState(lastState.gosubDoneState()).buttonUp(key);
    } else {
      super.buttonUp(key);
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

  ProgramEntry(Controller con) : super(con);

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
    } on CalculatorError catch (e) {
      controller.showCalculatorError(e);
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
  void gosubEntryDone(GosubArgInputState from, ArgDone label) {
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
    model.memory.program.currentLine = 0;
    model.memory.program.displayCurrent();
  }

  @override
  void handleOnOff() {
    model.prgmFlag = false;
    changeState(Resting(controller)).handleOnOff();
  }

  @override
  ControllerState gosubDoneState() => this;
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

  WaitingForGotoDotLines(Controller con, this.last) : super(con);

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

  ShowState(this._last,
      {this.disableWindow = false,
      this.delayed = true,
      this.fromProgramEntry = false})
      : super(_last.controller);

  @override
  void buttonUp(Operation key) {
    if (fromProgramEntry) {
      model.memory.program.displayCurrent(delayed: delayed);
    } else {
      model.display.displayX(delayed: delayed, disableWindow: disableWindow);
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
  DoNothing(Controller con) : super(con);

  @override
  void buttonDown(Operation key) {}
}

///
/// State for after the ON key is pressed, while we're waiting to see if they
/// pick a special function, or maybe press the ON key again to turn the
/// calculator off.
///
class OnOffKeyPressed extends DoNothing {
  OnOffKeyPressed(Controller con) : super(con);

  @override
  void buttonDown(Operation key) {
    model.onIsPressed.value = false;
    if (key == Operations.onOff) {
      changeState(DoNothing(controller));
      Future<void> res = () async {
        try {
          await model.writeToPersistentStorage();
        } finally {
          if (!kIsWeb && (Platform.isLinux || Platform.isWindows)) {
            // Current version on Linux dumps core on pop.
            // Current version on Windows keeps window there.
            exit(0);
          } else if (!kIsWeb) {
            await SystemNavigator.pop();
            // That kills us on some platforms, but it doesn't make sense on
            // web.  It's a NOP on iOS, because apps terminating themselves
            // is against the Apple human interface guidelines (which don't
            // make a bit of sense if you're turning a calculator off, but
            // whatever.)  So, on platforms were we can't go away, we blank
            // the LCD display and wait for the ON button to be pressed.
          }
          model.display.show(LcdContents.blank());
          changeState(CalculatorOff(controller));
        }
      }();
      unawaited(res);
    } else if (key == Operations.dot) {
      model.settings.euroComma = !model.settings.euroComma;
      model.display.displayX();
      changeState(Resting(controller));
    } else if (key == Operations.minus) {
      controller.reset();
      model.reset();
      final r = changeState(Resting(controller));
      model.display.current = 'pr error ';
      model.display.update();
      changeState(MessageShowing(r));
    } else if (key == Operations.mult) {
      changeState(DoNothing(controller));
      Future<void> runTests() async {
        try {
          model.display.current = 'RuNNING  ';
          model.display.update(blink: true);
          await controller.newSelfTests(inCalculator: true).runAll();
          changeState(Resting(controller));
          model.display.show(model.selfTestContents());
          changeState(MessageShowing(Resting(controller)));
        } on CalculatorError catch (e) {
          changeState(Resting(controller));
          controller.showCalculatorError(e);
          // ignore: avoid_catches_without_on_clauses
        } catch (e, s) {
          debugPrint('Unexpected exception $e\n\n$s');
          changeState(Resting(controller));
          controller.showCalculatorError(CalculatorError(9));
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
  final RunningController _fake;
  Running(Controller c)
      : _fake = RunningController(c),
        super(c);

  bool _stop = false;
  ProgramMemory<Operation> get program => model.memory.program;

  @override
  void buttonDown(Operation key) {
    _stop = true;
  }

  @override
  void buttonUp(Operation key) {
    if (!_stop) {
      model.isRunningProgram = true;
      unawaited(_run());
    }
  }

  /// We delay the showing of the blinking running a little bit, so that
  /// we don't get a very short flash of "running" when msPerInstruction
  /// is set to 0.
  Timer _showRunning() => Timer(const Duration(milliseconds: 20), () {
        assert(model.isRunningProgram);
        model.isRunningProgram = false;
        model.display.current = 'RuNNING  ';
        model.display.update(blink: true);
        model.isRunningProgram = true;
      });

  Future<void> _run() async {
    final settings = controller.model.settings;
    final ProgramListener listener = model.memory.program.programListener;
    double pendingDelay = settings.msPerInstruction;
    if (program.currentLine == program.lines) {
      program.currentLine = min(1, program.lines);
    }
    CalculatorError? pendingError;
    assert(model.isRunningProgram); // Because buttonUp() set it
    Timer showRunningTimer = _showRunning();
    try {
      do {
        await (Future<void>.delayed(
            Duration(milliseconds: (pendingDelay ~/ 4) * 4)));
        // Javascript clock granularity is 4ms
        pendingDelay = pendingDelay % 4;
        final ProgramInstruction<Operation> instr;
        final int line = program.currentLine;
        if (line == 0) {
          instr = model.newProgramInstruction(
              Operations.rtn, Operations.rtn.arg as ArgDone);
        } else {
          instr = program[line];
          program.incrementCurrentLine();
        }
        if (instr.op == Operations.rs) {
          // R/S
          // If we let it execute, it would recursively create another state!
          listener.onRS();
          break;
        }
        _fake.setArg(instr.arg);
        _fake.buttonDown(instr.op);
        // This bounces back to RunningController.runWithArg() if there's an
        // argument.
        _fake.buttonUp();
        if (settings.traceProgramToStdout) {
          final out = StringBuffer();
          out.write('  ');
          out.write(line.toString().padLeft(3, '0'));
          out.write(' ');
          out.write(instr.programListing.padRight(14));
          out.write('xyzt:');
          if (!model.isFloatMode) {
            out.write('0x');
          }
          for (int i = 0; i < 4; i++) {
            out.write('  ');
            if (model.isComplexMode) {
              final v = model.getStackByIndexC(i);
              out.write(v);
            } else if (model.isFloatMode) {
              final Value v = model.getStackByIndex(i);
              out.write(v);
            } else {
              final Value v = model.getStackByIndex(i);
              out.write(v.internal.toRadixString(16));
            }
          }
          debugPrint(out.toString());
        }
        pendingDelay = settings.msPerInstruction /
            ((instr.op.numericValue == null) ? 1 : 5);
        // While we're not simulating real instruction time, the number keys
        // are a lot faster than most other operations on a real calculator,
        // and they might be pretty common.  At a guess, we say 5x faster.
        pendingError = _fake.pendingError;
        if (_fake.pause && pendingError == null) {
          _fake.pause = false;
          listener.onPause();
          showRunningTimer.cancel();
          model.isRunningProgram = false;
          model.display.displayX(flash: false);
          await listener.resumeFromPause();
          model.isRunningProgram = true;
          showRunningTimer = _showRunning();
        }
        if (program.returnStackUnderflow) {
          listener.onDone();
          break;
        }
        if (pendingError != null) {
          listener.onError(pendingError);
          break;
        }
        if (_stop) {
          listener.onStop();
          break;
        }
      } while (!_stop);
    } finally {
      // For  bit of robustness in case there's a bug, we put the restoration
      // to a normal state in a finally.
      showRunningTimer.cancel();
      model.isRunningProgram = false;
      model.display.current = ' ';
      changeState(Resting(controller));
      if (pendingError != null) {
        controller.showCalculatorError(pendingError);
      } else {
        model.display.update(); // Blank with no delay
        model.display.displayX();
      }
    }
  }
}

///
/// State while single-stepping through a program.  Like [Running], this state
/// creates a [RunningController] that has its own [ControllerState].
///
class SingleStepping extends ControllerState with StackLiftEnabledUser {
  final RunningController _fake;
  // We are a state of _fake.real, so we will get the buttonUp notification
  // from the real controller.

  SingleStepping(RunningController rc)
      : _fake = rc,
        super(rc);

  ProgramMemory<Operation> get program => model.memory.program;

  @override
  void onChangedTo() {
    if (program.currentLine == 0 && program.lines > 0) {
      program.currentLine = 1;
      stackLiftEnabled = true;
      changeState(Resting(_fake));
    }
    program.displayCurrent();
    model.isRunningProgram = true;
  }

  @override
  void buttonDown(Operation key) => unreachable();

  @override
  void buttonUp(Operation key) {
    try {
      if (program.lines > 0) {
        ProgramInstruction<Operation> instr = program[program.currentLine];
        program.currentLine = (program.currentLine + 1) % (program.lines + 1);
        // That's what my 15C does
        if (instr.op == Operations.rs) {
          stackLiftEnabled = true;
        } else {
          _fake.setArg(instr.arg);
          _fake.buttonDown(instr.op);
          _fake.buttonUp();
        }
      }
    } finally {
      model.isRunningProgram = false;
      CalculatorError? pendingError = _fake.pendingError;
      if (pendingError != null) {
        _fake.real.showCalculatorError(pendingError);
        _fake.returnToParent(Resting(_fake.real));
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
        }
        model.display.displayX(flash: false);
      }
    }
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
  CalculatorOff(Controller con) : super(con);

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
