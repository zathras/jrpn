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
/// The main controller for the application.  The controller receives
/// [Operation] instances from the view in response to button presses,
/// and manipulates the [Model].
///
/// The [Operations] are split out into a separate library, so that they
/// are prevented from accessing private parts of the controller.  Similarly,
/// the concrete [ControllerState] types are put in a separate Dart library.
/// Operations and states are fairly complex, reflecting the sophisticated
/// design of the original HP-16C.  Keeping them encapsulated from the
/// controller's internals helps make the code easier to follow.
///
/// See [ControllerState] for a detailed description of the controller's
/// state machine.  See [Operation] for a description
/// of the operation type hierarchy.
/// <br>
/// <br>
/// <img src="dartdoc/controller/main.svg" style="width: 100%;"/>
/// <br>
///
library controller;

import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import '../v/buttons.dart';
import '../v/main_screen.dart';

import '../m/model.dart';
import 'operations.dart';
import 'states.dart';

part 'tests.dart';

// See the library comments, above!  (Android Studio  hides them by default.)

///
/// The main controller for the application.  This abstract class is implemented
/// by a [RealController] for normal calculator, and by [RunningController],
/// which manages a running calculator program.
///
abstract class Controller {
  Model<Operation> get model;
  late ControllerState _state;
  @protected
  Operation? lastKey;

  Controller();

  KeyboardController get keyboard;
  ControllerState get state => _state;

  Operation get minusOp;
  Operation get multOp;

  set state(ControllerState s) {
    _state = s;
    s.onChangedTo();
  }

  /// Tell if stack lift is enabled.  This is considered part of the
  /// controller's state, but note that the status from a running program
  /// reflects back to when a program isn't running.  This is important
  /// for proper functioning of the R/S key, and SST.
  bool get _stackLiftEnabled;
  set _stackLiftEnabled(bool v);
  @protected
  void enableStackLift() => _stackLiftEnabled = true;

  void buttonWidgetDown(CalculatorButton b) =>
      buttonDown(model.shift.select(b));

  ///
  /// Handle an operation due to a press on the keyboard.
  ///
  @mustCallSuper
  void buttonDown(Operation key) {
    lastKey = key;
    if (model.shift != ShiftKey.none) {
      model.shift = ShiftKey.none;
      // key.pressed(this) might set the shift key again.
    }
    state.buttonDown(key);
  }

  ///
  /// Finish the operation started by [buttonDown].  This is meaningful
  /// for some keys, like SST, show-hex and clear-prefix.
  ///
  void buttonUp() {
    Operation? k = lastKey;
    if (k != null) {
      state.buttonUp(k);
    }
  }

  ///
  /// Get the arguments described by Arg, and then run it.
  ///
  void getArgsAndRun(Operation op, Arg arg, Resting fromState);

  /// Show an error on the LCD screen.
  void showCalculatorError(CalculatorError e, StackTrace? stack) {
    showMessage('  error ${getErrorNumber(e)}  ');
    model.program.programListener.onErrorShown(e, stack);
  }

  int getErrorNumber(CalculatorError err);

  /// Show a message on the LCD screen.
  void showMessage(String message) {
    model.display.current = message;
    model.display.update();
    state = MessageShowing(state);
  }

  /// Reset everything but the state of the state machine
  void reset() {
    _stackLiftEnabled = false;
  }

  void resetAll() {
    reset();
    state.abort();
    state = Resting(this);
    model.displayDisabled = false;
    model.display.displayX();
  }

  /// Perform a single step action by running one instruction, and then
  /// returning to an appropriate state (DigitEntry or Running, as
  /// determined by the executed instruction).
  void singleStep(DigitEntry? digitEntryStateFrom);

  /// Handle the pause operation.  Note that this enables stack lift --
  /// see p. 100
  @mustCallSuper
  void handlePSE() => _stackLiftEnabled = true;

  bool _branchingOperationCalcDisabled();

  bool pasteToX(String clipboard) {
    final v = model.tryParseValue(clipboard);
    if (v == null) {
      return false;
    }
    if (_stackLiftEnabled) {
      model.pushStack();
    }
    _stackLiftEnabled = true;
    model.x = v;
    model.display.displayX();
    state = Resting(this);
    return true;
  }

  SelfTests newSelfTests({bool inCalculator = true});

  ///
  /// The key used to GTO an absolute line number ("." on the 16C,
  /// CHS on the 15C).
  Operation get gotoLineNumberKey;

  /// The numeric base for arguments, like register numbers.
  int get argBase;

  NormalArgOperation get gsbOperation;
  NormalArgOperation get gtoOperation;

  bool delayForShow(int Function() updateDisplay);
}

///
/// A type that can be used by states to access the library-private
/// [RealController] `_stackLiftEnabled` flag.  This provides enhanced
/// encapsulation, by explicitly marking states that do this.
///
mixin StackLiftEnabledUser {
  Controller get controller;

  /// Tell if stack lift is enabled.  This is considered part of the
  /// controller's state, but note that the status from a running program
  /// reflects back to when a program isn't running.  This is important
  /// for proper functioning of the R/S key, and SST.  The value comes
  /// from the [RealController].
  @protected
  bool get stackLiftEnabled => controller._stackLiftEnabled;
  @protected
  set stackLiftEnabled(bool v) => controller._stackLiftEnabled = v;
}

///
/// A controller for normal calculator operation.  When a program is
/// running, the real controller continues to exist, for when the program
/// stops.
///
abstract class RealController extends Controller {
  @override
  // The linter is wrong here -- stackLiftEnabled's setter is called.
  // https://github.com/flutter/flutter/issues/80689
  // ignore: prefer_final_fields
  bool _stackLiftEnabled = true;

  ProgramRunner? get suspendedProgramRunner =>
      model.program.suspendedProgram as ProgramRunner?;

  @override
  final KeyboardController keyboard = KeyboardController();

  RealController(
      {required List<NumberEntry> numbers,
      required Map<Operation, ArgDone> shortcuts,
      required Operation lblOperation,
      required Operation rtn})
      : super() {
    model.memory.initializeSystem(
        OperationMap<Operation>(
            registerBase: model.registerNumberBase,
            keys: model.logicalKeys,
            numbers: numbers,
            special: nonProgrammableOperations,
            shortcuts: shortcuts),
        lblOperation,
        rtn);
    state = Resting(this);
    keyboard.controller = this;
  }

  List<Operation> get nonProgrammableOperations => Operations.special;

  bool doDeferred() => false;

  @override
  void buttonDown(Operation key) {
    super.buttonDown(key);
    model.debugLog?.addKey(key);
  }

  @override
  void getArgsAndRun(Operation op, Arg arg, Resting fromState) {
    state = op.makeInputState(arg, this, fromState);
  }

  @override
  void buttonUp() {
    try {
      if (doDeferred()) {
        model.display.displayX();
      }
    } on CalculatorError catch (e, s) {
      showCalculatorError(e, s);
      // ignore: avoid_catches_without_on_clauses
    } catch (e, s) {
      debugPrint('Unexpected exception $e\n\n$s');
      showCalculatorError(CalculatorError(9), s);
    }
    super.buttonUp();
  }

  @override
  void singleStep(DigitEntry? digitEntryStateFrom) {
    final RunningController rc;
    if (digitEntryStateFrom == null) {
      rc = RunningController(this, digitEntryState: false);
    } else {
      rc = RunningController(this, digitEntryState: true);
      rc.currentDigitEntryState!.takeOverFrom(digitEntryStateFrom);
    }
    state = SingleStepping(rc);
  }

  void _returnFromChild(ControllerState newState) {
    state = newState;
  }

  @override
  bool delayForShow(int Function() updateDisplay) {
    updateDisplay();
    return false;
  }

  @override
  bool _branchingOperationCalcDisabled() => true;

  ButtonLayout getButtonLayout(
      ButtonFactory factory, double totalHeight, double totalButtonHeight);

  Widget getBackPanel();

  LandscapeButtonFactory getLandscapeButtonFactory(
      BuildContext context, ScreenPositioner screen);

  PortraitButtonFactory getPortraitButtonFactory(
      BuildContext context, ScreenPositioner screen);

  ///
  /// Some menus change on the 15C (e.g. settings)
  ///
  bool get menus15C => false;
}

///
/// A controller for when a program is running.
///
class RunningController extends Controller {
  final RealController real;
  int? Function()? pause; // Pause to show user what's on display
  CalculatorError? pendingError;
  ArgDone _argValue = _dummy;

  static final _dummy = ArgDone((_) {});

  RunningController(this.real, {bool digitEntryState = false}) {
    if (digitEntryState) {
      state = DigitEntry(this);
    } else {
      state = Resting(this);
    }
  }

  @override
  Model<Operation> get model => real.model;

  void setArg(ArgDone argValue) {
    _argValue = argValue;
  }

  @override
  KeyboardController get keyboard => real.keyboard;

  @override
  bool get _stackLiftEnabled => real._stackLiftEnabled;

  @override
  set _stackLiftEnabled(bool v) => real._stackLiftEnabled = v;

  DigitEntry? get currentDigitEntryState {
    ControllerState s = state;
    if (s is DigitEntry) {
      return s;
    } else {
      return null;
    }
  }

  @override
  void getArgsAndRun(Operation op, Arg arg, Resting fromState) {
    assert(state == fromState);
    assert(_argValue != _dummy);
    fromState.calculate(op, _argValue);
    real.doDeferred();
    assert((_argValue = _dummy) == _dummy); // Reset _argValue if in debug mode
    // If not in debug mode, leaving _argValue pointing to a stray ArgDone
    // is harmless.
  }

  void returnToParent(ControllerState s) => real._returnFromChild(s);

  @override
  void handlePSE() {
    super.handlePSE();
    pause = () {
      model.display.displayX(flash: false);
      return null;
    };
  }

  @override
  bool delayForShow(int Function() updateDisplay) {
    pause = updateDisplay;
    return true;
  }

  @override
  void singleStep(DigitEntry? digitEntryStateFrom) {
    assert(false);
  }

  @override
  void buttonUp() {}

  @override
  bool _branchingOperationCalcDisabled() => false;

  @override
  void showCalculatorError(CalculatorError e, StackTrace? stack) =>
      pendingError = e;

  @override
  SelfTests newSelfTests({bool inCalculator = true}) =>
      real.newSelfTests(inCalculator: inCalculator);

  @override
  Operation get gotoLineNumberKey => real.gotoLineNumberKey;

  @override
  int get argBase => real.argBase;

  @override
  int getErrorNumber(CalculatorError err) => real.getErrorNumber(err);

  @override
  NormalArgOperation get gsbOperation => real.gsbOperation;

  @override
  NormalArgOperation get gtoOperation => real.gtoOperation;

  @override
  Operation get minusOp => real.minusOp;

  @override
  Operation get multOp => real.multOp;
}

///
/// An operation, triggered by a key on the calculator keyboard, or executed
/// as part of a program.
///
abstract class Operation extends ProgramOperation {
  @override
  final String name;

  Operation({required this.name});

  /// A description of this arguments operation, or ArgDone if there is none.
  /// For example, the STO operation has an argument to indicate which register
  /// to store to.
  @override
  Arg get arg;

  StackLift get _stackLift;

  @override
  String toString() => 'Operation($name)';

  ///
  /// What to do when the key is pressed.
  ///
  void pressed(LimitedState arg);

  /// Either enable or disable stack lift, if appropriate, after this
  /// operation's calculation is done.  This will not be called if this
  /// operation doesn't have a calculation (intCalc or floatCalc on itself,
  /// or on its argument).
  void possiblyAlterStackLift(Controller c) => _stackLift._possiblyAlter(c);

  ControllerState makeInputState(
          Arg arg, Controller c, LimitedState fromState) =>
      ArgInputState(this, arg, c, fromState);

  /// By default, operations, if present, work for all kinds of controllers,
  /// but cf. [BranchingOperation]
  bool calcDisabled(Controller controller) => false;

  void beforeCalculate(Resting resting) {}

  bool get endsDigitEntry;
}

abstract class NoArgOperation extends Operation implements ArgDone {
  NoArgOperation({required super.name});

  @override
  late final int opcode;
  @override
  late final String programDisplay;
  @override
  late final String programListing;

  @override
  Arg get arg => this;

  @override
  void init(int registerBase,
          {required OpInitFunction f,
          required ProgramOperation? shift,
          required bool argDot,
          required ProgramOperation? arg,
          required bool userMode}) =>
      f(this, shift: shift, argDot: argDot, arg: arg, userMode: userMode);

  @override
  Arg? matches(ProgramOperation key, bool userMode) => null;

  @override
  void handleOpBeforeCalculate(Model m, void Function() opBeforeCalculate) =>
      opBeforeCalculate();
}

///
/// Operations that do something when the key is pressed, even when the
/// calculator is in program entry state.  They're called "limited," because
/// the set of handleXXX() calls is limited to those supported by
/// [ProgramEntry].
///
/// It might seem counter-intuitive, but all Limited operations are
/// NormalOperations.  Normal operations are the operations whose
/// pressed functions execute on an [ActiveState], either [Resting] or
/// [DigitEntry].  Limited operations
/// have pressed callbacks that execute on a LimitedState, and ActiveState
/// is a subtype of LimitedState.  Therefore, NormalOperation is,
/// conceptually, a supertype of LimitedOperation - there's a contravariant
/// relationship between the operations and the types, because the
/// operations, in essence, take an operation as argument.
///
class LimitedOperation extends NoArgOperation implements NormalOperation {
  @override
  final bool endsDigitEntry;

  @override
  bool liftStackIfEnabled(Model m) => false;
  // Some limited operations may do this via a pressed callback

  @override
  final void Function(LimitedState) _pressed;

  LimitedOperation(
      {required void Function(LimitedState) pressed,
      required super.name,
      this.endsDigitEntry = true})
      : _pressed = pressed;

  @override
  void Function(Model m)? get floatCalc => null;
  @override
  void Function(Model m)? get intCalc => null;
  @override
  void Function(Model m)? get complexCalc => null;

  @override
  void pressed(LimitedState arg) => _pressed(arg);

  @override
  StackLift get _stackLift => StackLift.neutral;

  @override
  void Function(Model)? getCalculation<T extends ProgramOperation>(
          Model m, DisplayModeSelector<void Function(Model)?, T> selector) =>
      m.displayMode.select(selector, this); // See subclass(es)
}

///
/// One of the number keys, from 0 to f.
///
class NumberEntry extends NoArgOperation {
  @override
  final int numericValue;

  @override
  bool get endsDigitEntry => false;

  @override
  bool liftStackIfEnabled(Model m) => false;

  NumberEntry(String name, this.numericValue) : super(name: name);

  @override
  void pressed(LimitedState arg) =>
      (arg as ActiveState).handleNumberKey(numericValue);
  // See the downcast note in NormalOperation

  @override
  StackLift get _stackLift => StackLift.neutral;

  @override
  void Function(Model)? getCalculation<T extends ProgramOperation>(
          Model m, DisplayModeSelector<void Function(Model)?, T> selector) =>
      null;
}

///
/// One of the 15C's letter keys, from A to E.
///
class LetterLabel extends NumberEntry {
  LetterLabel(super.name, super.value);

  @override
  bool get endsDigitEntry => true;

  @override
  void pressed(LimitedState arg) =>
      (arg as ActiveState).handleLetterLabel(this);
  // See the downcast note in NormalOperation

  @override
  StackLift get _stackLift => StackLift.neutral;

  @override
  String? get programListingArgName => name;
}

///
///  A "normal" calculator operation that doesn't take any keyboard arguments.
///  Generally, they perform some kind of
///  calculation, or otherwise manipulate the model.
///
class NormalOperation extends NoArgOperation implements ArgDone {
  /// The calculation performed when the calculator is in floating-point mode.
  final void Function(Model m)? floatCalc;

  /// The calculation performed when the calculator is in integer mode.
  final void Function(Model m)? intCalc;

  /// The calculation performed when the calculator is in complex mode.
  final void Function(Model m)? complexCalc;

  final void Function(ActiveState)? _pressed;

  @override
  final StackLift _stackLift;

  @override
  final bool endsDigitEntry;

  @override
  final int maxOneByteOpcodes;

  NormalOperation(
      {void Function(ActiveState)? pressed,
      StackLift? stackLift,
      required void Function(Model m)? calc,
      required super.name,
      this.endsDigitEntry = true,
      this.maxOneByteOpcodes = 9999})
      : _pressed = pressed,
        _stackLift = stackLift ?? StackLift.enable,
        floatCalc = calc,
        intCalc = calc,
        complexCalc = calc;

  NormalOperation.intOnly(
      {void Function(ActiveState)? pressed,
      StackLift? stackLift,
      required void Function(Model) this.intCalc,
      required super.name,
      this.endsDigitEntry = true})
      : _pressed = pressed,
        _stackLift = stackLift ?? StackLift.enable,
        floatCalc = null,
        complexCalc = null,
        maxOneByteOpcodes = 9999;

  NormalOperation.floatOnly(
      {void Function(ActiveState)? pressed,
      StackLift? stackLift,
      required void Function(Model) this.floatCalc,
      void Function(Model)? complexCalc,
      required super.name,
      this.endsDigitEntry = true,
      this.maxOneByteOpcodes = 9999})
      : _pressed = pressed,
        _stackLift = stackLift ?? StackLift.enable,
        intCalc = null,
        complexCalc = complexCalc ?? floatCalc;

  NormalOperation.differentFloatAndInt(
      {void Function(ActiveState)? pressed,
      StackLift? stackLift,
      required void Function(Model) this.intCalc,
      required void Function(Model) this.floatCalc,
      void Function(Model)? complexCalc,
      required super.name,
      this.endsDigitEntry = true,
      this.maxOneByteOpcodes = 9999})
      : _pressed = pressed,
        _stackLift = stackLift ?? StackLift.enable,
        complexCalc = complexCalc ?? floatCalc;

  @override
  bool liftStackIfEnabled(Model m) => false;
  // Some operations do this via a pressed callback

  @override
  void pressed(LimitedState arg) {
    final p = _pressed;
    if (p != null) {
      p(arg as ActiveState);
    }
    // Note the downcast.  LimitedState implementations need to ensure that
    // this method is only called on LimitedOperation instances.  As long as
    // that invariant holds, this bit of covariance increases static checking,
    // because it ensures that LimtedState pressed functions don't call any of
    // the methods declared lower in the hierarchy (like handleCHS or, notably,
    // the methods related to stack lift).  This simplifies reasoning about the
    // state machine, and avoids a bunch of null handleXXX methods in states
    // that don't use them, but it does come at the prices of a little less
    // static type safety.
    //
    // See ArgInputState._buttonDown and ProgramEntry._buttonDown to see how
    // they robustly guarantee that the covariant relationship isn't violated.
  }

  @override
  void Function(Model)? getCalculation<T extends ProgramOperation>(
          Model m, DisplayModeSelector<void Function(Model)?, T> selector) =>
      m.displayMode.select(selector, this);
}

///
/// A [NormalOperation] that might lift this stack, if enabled
///
class StackLiftingNormalOperation extends NormalOperation {
  final bool Function(Model) needsStackLiftIfEnabled;

  StackLiftingNormalOperation.floatOnly(
      {required super.floatCalc,
      super.complexCalc,
      required this.needsStackLiftIfEnabled,
      required super.name,
      super.maxOneByteOpcodes})
      : super.floatOnly();

  @override
  bool liftStackIfEnabled(Model m) => needsStackLiftIfEnabled(m);
}

///
/// A [NormalOperation] that doubles as a letter (A-F) on the 15C, as the
/// argument to LBL, GTO or GSB.  The letters on the 16C are unshifted, so
/// this doesn't come up there.
///
class NormalOperationOrLetter extends NormalOperation {
  @override
  final int numericValue;

  @override
  final String programListingArgName;

  NormalOperationOrLetter.floatOnly(
      {super.pressed,
      super.stackLift,
      required super.floatCalc,
      super.complexCalc,
      required super.name,
      required LetterLabel letter})
      : numericValue = letter.numericValue,
        programListingArgName = letter.name,
        super.floatOnly();

  NormalOperationOrLetter(NormalOperation op, LetterLabel letter)
      : numericValue = letter.numericValue,
        programListingArgName = letter.name,
        super.floatOnly(
            pressed: op._pressed,
            stackLift: op._stackLift,
            floatCalc: op.floatCalc!,
            complexCalc: op.complexCalc,
            name: op.name);
}

///
/// A [NormalOperation] that is shifted (by fShift or gShift), and that
/// is used as an argument.
///
class NormalOperationShiftedArg extends NormalOperation {
  @override
  final ProgramOperation argShift;

  @override
  final String programListingArgName;

  NormalOperationShiftedArg.floatOnly(
      {super.pressed,
      super.stackLift,
      required super.floatCalc,
      super.complexCalc,
      required super.name,
      required this.argShift,
      required this.programListingArgName})
      : super.floatOnly();
}

///
/// An [Operation] that takes an argument.  For example, the RCL and STO
/// operations take an argument, giving the register to store to or recall from.
///
class NormalArgOperation extends Operation {
  @override
  final Arg arg;

  @override
  final int maxOneByteOpcodes;

  @override
  final StackLift _stackLift;

  NormalArgOperation(
      {StackLift? stackLift,
      required this.arg,
      required super.name,
      this.maxOneByteOpcodes = 9999})
      : _stackLift = stackLift ?? StackLift.enable;

  ///
  /// Do nothing -- we don't know our argument yet.
  ///
  @override
  void pressed(LimitedState arg) {}

  @override
  bool get endsDigitEntry => true;
}

class RunProgramOperation extends NormalArgOperation {
  final ProgramRunner Function() runner;

  ///
  /// NOTE:  arg's function is only run when this operation is executed
  ///        as part of a program.  When it's entered from the keyboard,
  ///        the arg input state causes the operation to happen.
  RunProgramOperation(
      {required super.arg,
      required this.runner,
      required super.name,
      super.maxOneByteOpcodes});

  @override
  ControllerState makeInputState(
          Arg arg, Controller c, LimitedState fromState) =>
      RunProgramArgInputState(this, arg, c, fromState, runner);
}

class NormalArgOperationWithBeforeCalc extends NormalArgOperation {
  final StackLift Function(Resting state) _beforeCalculate;

  NormalArgOperationWithBeforeCalc(
      {StackLift? stackLift,
      required super.arg,
      required StackLift Function(Resting) beforeCalculate,
      required super.name,
      super.maxOneByteOpcodes})
      : _beforeCalculate = beforeCalculate,
        super(stackLift: stackLift ?? StackLift.enable);

  @override
  void beforeCalculate(Resting resting) {
    final StackLift lift = _beforeCalculate(resting);
    lift._possiblyAlter(resting.controller);
  }
}

class NonProgrammableOperation extends LimitedOperation implements ArgDone {
  final void Function(Model m)? calc;

  @override
  void Function(Model m)? get floatCalc => calc;
  @override
  void Function(Model m)? get complexCalc => calc;
  NonProgrammableOperation(
      {required super.name,
      required super.pressed,
      this.calc,
      super.endsDigitEntry = false});
}

class ShiftOperation extends NonProgrammableOperation {
  ShiftOperation({required super.name, required super.pressed});

  @override
  bool get isShift => true;
}

///
/// A declarative description of an [Operation]'s effect on stack lift, when
/// its calculation has been performed.  This covers the most common effects
/// that operations can have on stack lift.  See Page 99, "Operations Affecting
/// Stack Lift" in Appendix B of the 16C's manual.
///
class StackLift {
  final void Function(Controller) _possiblyAlter;

  StackLift._p(this._possiblyAlter);

  static StackLift enable =
      StackLift._p((Controller c) => c._stackLiftEnabled = true);
  static StackLift disable =
      StackLift._p((Controller c) => c._stackLiftEnabled = false);
  static StackLift neutral = StackLift._p((_) {});
}

///
/// A program branching operation.  These operations only function when running
/// a program.  They represent a condition.  If that condition is true, the next
/// instruction executes normally; otherwise, it is skipped.
///
class BranchingOperation extends NormalOperation {
  BranchingOperation(
      {required super.name, required void Function(Model) super.calc});

  /// Branching operations only perform a calculation when we are running
  /// a program.
  @override
  bool calcDisabled(Controller controller) =>
      controller._branchingOperationCalcDisabled();
}

///
/// A [BranchingOperation] that takes an argument, namely B? (bit test)
///
class BranchingArgOperation extends NormalArgOperation {
  BranchingArgOperation(
      {required super.arg, required super.name, super.maxOneByteOpcodes});

  /// Branching operations only perform a calculation when we are running
  /// a program.
  @override
  bool calcDisabled(Controller controller) =>
      controller._branchingOperationCalcDisabled();
}

class KeyboardController {
  late final RealController controller;
  PhysicalKeyboardKey? _physicalKeyThatIsDown;
  final button = <String, CalculatorButtonState>{};
  CalculatorButtonState? _buttonThatIsDown;
  // For < and > accelerators, which imply a g-shift:
  CalculatorButtonState? _extraShiftThatIsDown;
  DateTime lastKeyDown = DateTime.now();
  bool controlPressed = false;

  static final _ignored = <PhysicalKeyboardKey>{
    PhysicalKeyboardKey.shiftLeft,
    PhysicalKeyboardKey.shiftRight,
    PhysicalKeyboardKey.controlLeft,
    PhysicalKeyboardKey.controlRight,
    PhysicalKeyboardKey.capsLock,
    PhysicalKeyboardKey.altLeft,
    PhysicalKeyboardKey.altRight,
    PhysicalKeyboardKey.metaLeft,
    PhysicalKeyboardKey.metaRight
  };

  KeyEventResult onKey(KeyEvent e) {
    final isControl = e.logicalKey == LogicalKeyboardKey.controlLeft ||
        e.logicalKey == LogicalKeyboardKey.controlRight ||
        e.logicalKey == LogicalKeyboardKey.control;
    if (e is! KeyDownEvent) {
      if (e is KeyUpEvent) {
        if (isControl) {
          controlPressed = false;
        } else {
          if (e.physicalKey == _physicalKeyThatIsDown) {
            releasePressedButton();
          }
          _physicalKeyThatIsDown = null;
        }
      }
      return KeyEventResult.ignored;
    }
    if (isControl) {
      controlPressed = true;
      return KeyEventResult.ignored;
    }
    final now = DateTime.now();
    if (e.physicalKey == _physicalKeyThatIsDown &&
        now.difference(lastKeyDown).inMilliseconds < 2000) {
      // Effectively, disable autorepeat.
      lastKeyDown = now;
      return KeyEventResult.handled;
    }
    final Characters ch;
    if (e.physicalKey == PhysicalKeyboardKey.enter ||
        e.physicalKey == PhysicalKeyboardKey.numpadEnter) {
      // Bizarrely, on the web we get 'E' as the character in this case!
      // https://github.com/flutter/flutter/issues/82065
      ch = Characters('\n');
    } else if (e.physicalKey == PhysicalKeyboardKey.delete ||
        e.physicalKey == PhysicalKeyboardKey.backspace) {
      ch = Characters('\u0008');
    } else if (_ignored.contains(e.physicalKey)) {
      // Other keys give weird results on the web, alas.  Like, control
      // gives "C".  I didn't file a bug, but I may post a flaming screed
      // to alt.javascript.die.die.die
      return KeyEventResult.ignored;
    } else {
      String? sch = e.character;
      if (sch == null) {
        return KeyEventResult.ignored;
      }
      if (controlPressed && (sch == 'f' || sch == 'F')) {
        // Yes, JavaScript really does suck.  In case you were wondering.
        // This happens on Chrome (Still!  As of February 2024!).
        // On the HP 16C, we *really* want ^F to me the gold F key, since
        // plain F is taken for the hex digit.  For consistency, we allow
        // ^G for the G shift key.
        ch = Characters('\u0006');
      } else if (controlPressed && (sch == 'g' || sch == 'G')) {
        ch = Characters('\u0007');
      } else {
        ch = Characters(sch).toUpperCase();
      }
      if (ch.isEmpty) {
        return KeyEventResult.ignored;
      }
    }
    final CalculatorButtonState? b = button[ch.first];
    if (b != null) {
      releasePressedButton(); // Just in case, probably does nothing
      if (e.character == '<' || e.character == '>') {
        final gShift = button['G'];
        assert(gShift != null);
        if (gShift != null) {
          // Shut up analyzer
          gShift.keyPressed();
          _extraShiftThatIsDown = gShift;
        }
      }
      b.keyPressed();
      _buttonThatIsDown = b;
      _physicalKeyThatIsDown = e.physicalKey;
      lastKeyDown = now;
      return KeyEventResult.handled;
    } else if (e.character == '?') {
      controller.model.settings.showAccelerators.value =
          !controller.model.settings.showAccelerators.value;
      _physicalKeyThatIsDown = e.physicalKey;
      lastKeyDown = now;
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void releasePressedButton() {
    _extraShiftThatIsDown?.keyReleased();
    _extraShiftThatIsDown = null;
    _buttonThatIsDown?.keyReleased();
    _buttonThatIsDown = null;
  }

  void register(CalculatorButtonState s, String accelerator) {
    for (final ch in Characters(accelerator)) {
      button[ch] = s;
    }
  }

  void deregister(CalculatorButtonState s, String accelerator) {
    for (final ch in Characters(accelerator)) {
      if (button[ch] == s) {
        // New mapping might have registered first
        button.remove(ch);
      }
    }
  }
}
