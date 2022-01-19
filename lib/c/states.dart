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
    // print('@@ state set to $v');
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
  /// Process an [Operation] that takes an [OperationArg], once the
  /// argument value is available.
  ///
  void onArgComplete(OperationArg arg, int argValue);

  void handleOnOff();
  void handleShift(ShiftKey k);
  void handleDecimalPoint();
  void handleClearPrefix();
  void handleBackspace();
  void handlePR();
  void handleShowStatus();
  void handleShowMem();
  void handleGotoDot(int value);
  void handleSST();
  void handleBST();
  void handleClearProgram();

  void gosubEntryDone(GosubArgInputState from, int label);

  @protected
  void Function(Model<Operation>)? getCalculation(Operation o) {
    const selector = _OperationSelector();
    Function(Model<Operation>)? floatOrInt =
        model.displayMode.select(selector, o);
    return o.calcDefinedFor(controller, floatOrInt);
  }
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
    if (key == Operations.gto && controller is RealController) {
      // This is a little tricky.  GTO has this quirk, where "GTO . nnn"
      // positions the current line.  It still enables stack lift,
      // which is what the normal key.pressed() does.
      key.pressed(this);
      changeState(WaitingForGotoDot(controller, this));
      return;
    }
    final OperationArg? arg = key.arg;
    if (arg != null) {
      const selector = _ArgOperationSelector();
      final void Function(Model, int)? f =
          model.displayMode.select(selector, arg);
      if (key.calcDefinedFor(controller, f) != null) {
        // If there's a calculation for our current mode
        controller.runWithArg(arg, this);
      } else {
        key.pressed(this);
      }
    } else {
      key.pressed(this);
      final f = getCalculation(key);
      if (f != null) {
        _calculate(f);
        key.possiblyAlterStackLift(controller);
      }
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
    model.negateX();
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
      model.display.current = model.x.floatPrefix;
      model.display.update();
      changeState(ShowState(this));
    } else if (model.settings.windowEnabled) {
      model.display.displayX(flash: false, disableWindow: true);
      changeState(ShowState(this, disableWindow: true));
    }
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
    model.display.current = '0ff?   ';
    model.display.update();
    stackLiftEnabled = true;
    changeState(OnOffKeyPressed(controller));
  }

  @override
  void handleShift(ShiftKey k) => model.shift = k;

  void _calculate(void Function(Model<Operation>) f) {
    try {
      f(model);
      model.display.displayX();
    } on CalculatorError catch (e) {
      controller.showCalculatorError(e);
      // ignore: avoid_catches_without_on_clauses
    } catch (e, s) {
      debugPrint('Unexpected exception $e\n\n$s');
      controller.showCalculatorError(CalculatorError(9));
    }
  }

  @override
  void onArgComplete(OperationArg arg, int argValue) {
    const selector = _ArgOperationSelector();
    void Function(Model, int)? f = model.displayMode.select(selector, arg);
    try {
      final p = arg.pressed;
      if (p != null) {
        p(this);
      }
      f!(model, argValue);
      model.display.displayX();
    } on CalculatorError catch (e) {
      controller.showCalculatorError(e);
      // ignore: avoid_catches_without_on_clauses
    } catch (e, s) {
      debugPrint('Unexpected exception $e\n\n$s');
      controller.showCalculatorError(CalculatorError(9));
    }
    arg.op.possiblyAlterStackLift(controller);
  }

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
  void gosubEntryDone(GosubArgInputState from, int label) =>
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
    try {
      program.gosub(operation.numericValue);
    } on CalculatorError catch (e) {
      controller.showCalculatorError(e);
      return;
    }
    program.displayCurrent();
    final arg = GosubOperationArg.both(26, calc: (_, __) {});
    arg.op = Operations.gsb;
    final s = GosubArgInputState(controller, arg, this);
    s.isDone = true;
    changeState(s);
    /* @@ was:
    final arg = GosubOperationArg.both(17,
        calc: (Model m, int label) => m.memory.program.gosub(label));
    arg.op = Operations.gsb;
    final inState = GosubArgInputState(controller, arg, this);
    changeState(inState);
    inState.buttonDown(operation);
     */
  }
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
    if (getCalculation(key) != null || key.arg != null) {
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
        model.negateX(); // In unsigned mode this does what the 16C does
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
  void onArgComplete(OperationArg arg, int argValue) => unreachable();

  @override
  void handleGotoDot(int value) => unreachable();

  @override
  void handleClearProgram() =>
      changeState(Resting(controller)).handleClearProgram();

  @override
  void gosubEntryDone(GosubArgInputState from, int label) =>
      changeState(Resting(controller)).gosubEntryDone(from, label);

  @override
  void handleLetterLabel(LetterLabel operation) =>
      changeState(Resting(controller)).handleLetterLabel(operation);
}

///
/// Inputting an argument.  Generally, the calculator silently waits for
/// keypresses giving the argument value.  For example, when recalling
/// register 1c, the user presses "RCL . c"; the calculator is in this
/// state while waiting for the ". c" to be pressed.
///
class ArgInputState extends ControllerState {
  final OperationArg arg;
  final LimitedState lastState;
  bool _decimalPressed = false;

  ArgInputState(Controller con, this.arg, this.lastState) : super(con);

  bool get decimalAllowed => arg.maxArg > 17;
  // GTO and GSB take index registers, but not .

  @override
  void buttonDown(Operation key) {
    if (Operations.argIops.contains(key)) {
      _gotNumber(Registers.indexRegister);
    } else if (Operations.argParenIops.contains(key)) {
      _gotNumber(Registers.indirectIndex);
    } else if (key == Operations.dot) {
      if (_decimalPressed || !decimalAllowed) {
        changeState(lastState);
        lastState.handleDecimalPoint();
      } else {
        _decimalPressed = true;
      }
    } else {
      int? argV = key.numericValue;
      if (argV != null) {
        _gotNumber(argV);
      } else {
        changeState(lastState); // bail
        lastState.buttonDown(key);
      }
    }
  }

  void _gotNumber(int argV) {
    if (_decimalPressed) {
      argV += 16;
    } else if (!decimalAllowed &&
        (argV == Registers.indirectIndex || argV == Registers.indexRegister)) {
      // GTO and GSB for I and (i)
      argV -= 16;
    }
    if (argV > arg.maxArg) {
      changeState(lastState);
      // But we eat the number key.  At least, that's how my 15C works
      // on g-CF-9
    } else {
      done(argV);
    }
  }

  void done(int argValue) {
    changeState(lastState);
    if (argValue <= arg.maxArg) {
      arg.onArgComplete(lastState, argValue);
    }
  }
}

///
/// Inputting the argument for the FLOAT key.  This is a little different
/// than a normal [ArgInputState] in that the "." key, by itself, means
/// "go to scientific display," which we model as ten digits after the
/// decimal point (which doesn't fit on the LCD display).
///
class FloatKeyArgInputState extends ControllerState {
  final OperationArg arg;
  final LimitedState lastState;

  FloatKeyArgInputState(Controller con, this.arg, this.lastState) : super(con);

  @override
  void buttonDown(Operation key) {
    if (key == Operations.dot) {
      _done(10);
    } else {
      int? argV = key.numericValue;
      if (argV != null && argV <= 9) {
        _done(argV);
      } else {
        changeState(lastState); // bail
        lastState.buttonDown(key);
      }
    }
  }

  void _done(int argValue) {
    changeState(lastState);
    arg.onArgComplete(lastState, argValue);
  }
}

///
/// Inputting the argument for GSB.  See [handleGosubEntryDone].
///
class GosubArgInputState extends ArgInputState {
  GosubArgInputState(Controller con, OperationArg arg, LimitedState lastState)
      : super(con, arg, lastState);

  bool isDone = false;

  @override
  void done(int argValue) => lastState.gosubEntryDone(this, argValue);

  ///
  /// When GSB <label> is pressed (but before it is released), and when we're
  /// not entering a program, we pre-display the first instruction of the
  /// program.  So, Resting.gosubEntryDone calls this method to do that.
  ///
  void handleGosubEntryDone(int label) {
    // We know that we're coming from a keyboard-entered GSB, since arguments
    // are being input.
    if (label <= arg.maxArg) {
      final p = arg.pressed;
      if (p != null) {
        p(lastState as ActiveState);
      }
      assert(controller is RealController);
      final program = model.memory.program;
      program.resetReturnStack(); // Since we're starting new program
      try {
        program.gosub(label);
      } on CalculatorError catch (e) {
        changeState(lastState);
        controller.showCalculatorError(e);
        return;
      }
      program.displayCurrent();
      isDone = true;
      // On button up, another goto(label) will happen, but that's harmless.
    } else {
      super.done(label);
    }
  }

  @override
  void buttonUp(Operation key) {
    if (isDone) {
      arg.op.possiblyAlterStackLift(controller);
      changeState(Running(controller)).buttonUp(key);
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

  static final Set<LimitedOperation> _ourPressed = {
    Operations.fShift,
    Operations.gShift,
    Operations.pr,
    Operations.bsp,
    Operations.clearPrgm,
    Operations.clearPrefix,
    Operations.sst,
    Operations.bst,
    Operations.mem,
    Operations.status,
    Operations.onOff
  };

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
    final OperationArg? arg = key.arg;
    if (key == Operations.gto) {
      changeState(WaitingForGotoDot(controller, this));
    } else if (arg != null) {
      // which includes gsb and lbl
      controller.runWithArg(arg, this);
    } else if (_ourPressed.contains(key)) {
      assert(key is LimitedOperation);
      // It has to be, because it's in _ourKeys.  The static typing
      // system doesn't guarantee that for us, because we're using the
      // non-parameterized version of the generic Operation to achieve the
      // needed covariance.
      key.pressed(this);
    } else {
      _addOperation(key, 0);
    }
  }

  @override
  void buttonUp(Operation key) {
    _autorepeat?.cancel();
    _autorepeat = null;
  }

  @override
  void onArgComplete(OperationArg arg, int argValue) {
    assert(arg.floatCalc != null || arg.intCalc != null);
    _addOperation(arg.op, argValue);
  }

  void _addOperation(Operation op, int argValue) {
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
  void handleDecimalPoint() {
    // This can happen if we come from ArgInputState.
    _addOperation(Operations.dot, 0);
  }

  @override
  void gosubEntryDone(GosubArgInputState from, int label) {
    _addOperation(Operations.gsb, label);
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
}

///
/// State after the GTO key is pressed, when we don't know if the user
/// will press "." (meaning navigate to a specific line number), or a
/// label.  In the spirit of Beckett, we do hope one arrives before
/// too long.
///
class WaitingForGotoDot extends ControllerState {
  final LimitedState last;

  WaitingForGotoDot(Controller con, this.last) : super(con) {
    assert(con is RealController); // We're not running a program
  }

  @override
  void buttonDown(Operation key) {
    if (key == Operations.dot) {
      changeState(WaitingForGotoDotLines(controller, last));
    } else {
      changeState(ArgInputState(controller, Operations.gto.arg, last))
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
          final d = LcdContents(
              hideComplement: false,
              windowEnabled: false,
              mainText: '-8,8,8,8,8,8,8,8,8,8,',
              cFlag: true,
              euroComma: false,
              rightJustify: false,
              bits: 64,
              sign: SignMode.unsigned,
              wordSize: 64,
              gFlag: true,
              prgmFlag: true,
              shift: ShiftKey.g,
              extraShift: ShiftKey.f);
          model.display.show(d);
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
  // My 15C does about 100 add instructions in ten seconds, which would be
  // 100ms per instruction.  Going about double that speed gives pleasing
  // results.

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
          instr = model.newProgramInstruction(Operations.rtn, 0);
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
        final OperationArg? arg = instr.op.arg;
        if (arg != null) {
          _fake.argValue = instr.argValue;
        } else {
          _fake.argValue = null;
        }
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
            final Value v = model.getStackByIndex(i);
            if (model.isFloatMode) {
              try {
                out.write(v.asDouble.toString());
              } on CalculatorError catch (_) {
                out.write('0x');
                out.write(v.internal.toRadixString(16));
              }
            } else {
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
        final OperationArg? arg = instr.op.arg;
        if (arg != null) {
          _fake.argValue = instr.argValue;
        } else {
          _fake.argValue = null;
        }
        if (instr.op == Operations.rs) {
          stackLiftEnabled = true;
        } else {
          _fake.buttonDown(instr.op);
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
          // We came from DigitEntryState in our parent.  If and we're
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
  int b = model.memory.program.bytesToNextAllocation;
  String r = model.memory.registers.length.toString().padLeft(3, '0');
  model.display.current = 'p-$b r-$r ';
  model.display.update();
}

class _ArgOperationSelector
    extends DisplayModeSelector<void Function(Model, int)?, OperationArg> {
  const _ArgOperationSelector();

  @override
  void Function(Model, int)? selectInteger(OperationArg arg) => arg.intCalc;
  @override
  void Function(Model, int)? selectFloat(OperationArg arg) => arg.floatCalc;
}

class _OperationSelector
    extends DisplayModeSelector<void Function(Model)?, Operation> {
  const _OperationSelector();

  @override
  void Function(Model)? selectInteger(Operation arg) => arg.intCalc;
  @override
  void Function(Model)? selectFloat(Operation arg) => arg.floatCalc;
}
