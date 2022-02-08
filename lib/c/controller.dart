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
import 'package:jrpn/v/buttons.dart';
import 'package:jrpn/v/main_screen.dart';

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
  final Model<Operation> model;
  late ControllerState _state;
  @protected
  Operation? lastKey;

  Controller(this.model);

  KeyboardController get keyboard;
  ControllerState get state => _state;

  Set<LimitedOperation> get nonProgrammableKeys;

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
  /// Run the operation `arg.op` when its argument is available.
  /// When running a program, that's now.
  ///
  void runWithArg(OperationArg arg, LimitedState fromState);

  /// Show an error on the LCD screen.
  void showCalculatorError(CalculatorError e) =>
      showMessage('  error ${e.num}  ');

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
    state = Resting(this);
    model.isRunningProgram = false;
  }

  /// Perform a single step action by running one instruction, and then
  /// returning to an appropriate state (DigitEntry or Running, as
  /// determined by the executed instruction).
  void singleStep(DigitEntry? digitEntryStateFrom);

  void _returnFromChild(ControllerState newState);

  /// Handle the pause operation.  Note that this enables stack lift --
  /// see p. 100
  @mustCallSuper
  void handlePSE() => _stackLiftEnabled = true;

  T? _branchingOperationCalc<T>(T? calc);

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

  /// Abbreviated key sequences for I used as an argument
  /// cf. 16C manual p. 68
  Set<Operation> get argIops;

  /// Abbreviated key sequences for (i) used as an argument
  /// cf. 16C manual p. 68
  Set<Operation> get argParenIops;

  /// The numeric base for arguments, like register numbers.
  int get argBase;
}

///
/// A type that can be used by states to access the library-private
/// [RealController] `_stackLiftEnabled` flag.  This provides enhanced
/// encapsulation, by explicitly marking states that do this.
///
abstract class StackLiftEnabledUser {
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

  @override
  final KeyboardController keyboard = KeyboardController();

  RealController(
      Model<Operation> model,
      List<NumberEntry> numbers,
      Map<NormalOperation, ProgramInstruction> shortcuts,
      Operation lblOperation)
      : super(model) {
    Operations.numberOfFlags = model.numberOfFlags;
    model.memory.initializeSystem(OperationMap<Operation>(
        keys: model.logicalKeys,
        numbers: numbers,
        special: Operations.special,
        shortcuts: shortcuts,
        lbl: lblOperation));
    state = Resting(this);
    keyboard.controller = this;
  }

  @override
  void buttonDown(Operation key) {
    super.buttonDown(key);
    model.debugLog?.addKey(key);
  }

  @override
  void runWithArg(OperationArg arg, LimitedState fromState) {
    state = arg.makeInputState(this, fromState);
    // print('@@ state set to $state');
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

  @override
  void _returnFromChild(ControllerState newState) {
    // print('@@ Back to parent in state $newState');
    state = newState;
  }

  @override
  T? _branchingOperationCalc<T>(T? calc) => null;

  @override
  Set<LimitedOperation> get nonProgrammableKeys => nonProgrammableKeysStatic;

  static final Set<LimitedOperation> nonProgrammableKeysStatic = {
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

  ButtonLayout getButtonLayout(
      ButtonFactory factory, double totalHeight, double totalButtonHeight);

  Widget getBackPanel();

  LandscapeButtonFactory getLandscapeButtonFactory(
      BuildContext context, ScreenPositioner screen);

  PortraitButtonFactory getPortraitButtonFactory(
      BuildContext context, ScreenPositioner screen);
}

///
/// A controller for when a program is running.
///
class RunningController extends Controller {
  final Controller real;
  int? argValue;
  bool pause = false;
  CalculatorError? pendingError;

  RunningController(this.real, {bool digitEntryState = false})
      : super(real.model) {
    if (digitEntryState) {
      state = DigitEntry(this);
    } else {
      state = Resting(this);
    }
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
  void runWithArg(OperationArg arg, LimitedState fromState) {
    assert(state == fromState);
    int? v = argValue;
    assert(v != null);
    if (v != null && v <= arg.desc.maxArg) {
      arg.onArgComplete(fromState, v);
    }
  }

  void returnToParent(ControllerState s) => real._returnFromChild(s);

  @override
  void handlePSE() {
    super.handlePSE();
    pause = true;
  }

  @override
  void singleStep(DigitEntry? digitEntryStateFrom) {
    assert(false);
  }

  @override
  void buttonUp() {}

  @override
  void _returnFromChild(ControllerState newState) {
    assert(false);
  }

  @override
  T? _branchingOperationCalc<T>(T? calc) => calc;

  @override
  void showCalculatorError(CalculatorError e) => pendingError = e;

  @override
  SelfTests newSelfTests({bool inCalculator = true}) =>
      real.newSelfTests(inCalculator: inCalculator);

  @override
  Operation get gotoLineNumberKey => real.gotoLineNumberKey;

  @override
  Set<Operation> get argIops => real.argIops;

  @override
  Set<Operation> get argParenIops => real.argParenIops;

  @override
  int get argBase => real.argBase;

  @override
  Set<LimitedOperation> get nonProgrammableKeys => real.nonProgrammableKeys;
}

///
/// An operation, triggered by a key on the calculator keyboard, or executed
/// as part of a program.
///
abstract class Operation extends ProgramOperation {
  @override
  final String name;

  Operation({required this.name});

  /// A description of an argument, if there is one.  For example, the STO
  /// operation has an argument to indicate which register to store to.
  @override
  OperationArg? get arg;

  /// The calculation performed when the calculator is in floating-point mode.
  void Function(Model m)? get floatCalc;

  /// The calculation performed when the calculator is in integer mode.
  void Function(Model m)? get intCalc;

  /// The calculation performed when the calculator is in complex mode.
  void Function(Model m)? get complexCalc;

  StackLift get _stackLift;

  @override
  int get maxArg => arg?.desc.maxArg ?? 0;

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

  /// By default, operations, if present, work for all kinds of controllers,
  /// but cf. [BranchingOperation]
  T? calcDefinedFor<T>(Controller controller, T? calc) => calc;
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
class LimitedOperation extends Operation implements NormalOperation {
  @override
  final void Function(LimitedState) _pressed;

  LimitedOperation(
      {required void Function(LimitedState) pressed, required String name})
      : _pressed = pressed,
        super(name: name);

  @override
  OperationArg? get arg => null;
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
}

///
/// One of the number keys, from 0 to f.
///
class NumberEntry extends Operation {
  @override
  final int numericValue;

  NumberEntry(String name, this.numericValue) : super(name: name);

  @override
  OperationArg? get arg => null;
  @override
  void Function(Model m)? get floatCalc => null;
  @override
  void Function(Model m)? get intCalc => null;
  @override
  void Function(Model m)? get complexCalc => null;

  @override
  void pressed(LimitedState arg) =>
      (arg as ActiveState).handleNumberKey(numericValue);
  // See the downcast note in NormalOperation

  @override
  StackLift get _stackLift => StackLift.neutral;
}

///
/// One of the 15C's letter keys, from A to E.
///
class LetterLabel extends NumberEntry {
  LetterLabel(String name, int value) : super(name, value);

  @override
  void pressed(LimitedState arg) =>
      (arg as ActiveState).handleLetterLabel(this);
  // See the downcast note in NormalOperation

  @override
  StackLift get _stackLift => StackLift.neutral;
}

///
///  A "normal" calculator operation.  Generally, they perform some kind of
///  calculation, or otherwise manipulate the model.
///
class NormalOperation extends Operation {
  @override
  final void Function(Model m)? floatCalc;

  @override
  final void Function(Model m)? intCalc;

  @override
  final void Function(Model m)? complexCalc;

  final void Function(ActiveState)? _pressed;

  @override
  final StackLift _stackLift;

  NormalOperation(
      {void Function(ActiveState)? pressed,
      StackLift? stackLift,
      required void Function(Model m)? calc,
      required String name})
      : _pressed = pressed,
        _stackLift = stackLift ?? StackLift.enable,
        floatCalc = calc,
        intCalc = calc,
        complexCalc = calc,
        super(name: name);

  NormalOperation.intOnly(
      {void Function(ActiveState)? pressed,
      StackLift? stackLift,
      required void Function(Model) this.intCalc,
      required String name})
      : _pressed = pressed,
        _stackLift = stackLift ?? StackLift.enable,
        floatCalc = null,
        complexCalc = null,
        super(name: name);

  NormalOperation.floatOnly(
      {void Function(ActiveState)? pressed,
      StackLift? stackLift,
      required void Function(Model) this.floatCalc,
      void Function(Model)? complexCalc,
      required String name})
      : _pressed = pressed,
        _stackLift = stackLift ?? StackLift.enable,
        intCalc = null,
        complexCalc = complexCalc ?? floatCalc,
        super(name: name);

  NormalOperation.differentFloatAndInt(
      {void Function(ActiveState)? pressed,
      StackLift? stackLift,
      required void Function(Model) this.intCalc,
      required void Function(Model) this.floatCalc,
      void Function(Model)? complexCalc,
      required String name})
      : _pressed = pressed,
        _stackLift = stackLift ?? StackLift.enable,
        complexCalc = complexCalc ?? floatCalc,
        super(name: name);

  @override
  OperationArg? get arg => null;

  @override
  void pressed(LimitedState arg) {
    final p = _pressed;
    if (p != null) {
      p(arg as ActiveState);
    }
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

///
/// A [NormalOperation] that doubles as a letter (A-F) on the 15C, as the
/// argument to LBL, GTO or GSB.  The letters on the 16C are unshifted, so
/// this doesn't come up there.
///
class NormalOperationOrLetter extends NormalOperation {
  @override
  final int numericValue;

  NormalOperationOrLetter.floatOnly(
      {void Function(ActiveState)? pressed,
      StackLift? stackLift,
      required void Function(Model) floatCalc,
      void Function(Model)? complexCalc,
      required String name,
      required LetterLabel letter})
      : numericValue = letter.numericValue,
        super.floatOnly(
            pressed: pressed,
            stackLift: stackLift,
            floatCalc: floatCalc,
            complexCalc: complexCalc,
            name: name);

  NormalOperationOrLetter(NormalOperation op, LetterLabel letter)
      : numericValue = letter.numericValue,
        super.floatOnly(
            pressed: op._pressed,
            stackLift: op._stackLift,
            floatCalc: op.floatCalc!,
            complexCalc: op.complexCalc,
            name: op.name);
}

///
/// A [NormalOperation] that takes an argument.  For example, the RCL and STO
/// operations take an argument, giving the register to store to or recall from.
///
class NormalArgOperation extends Operation {
  @override
  final OperationArg arg;

  @override
  final int numExtendedOpCodes;

  @override
  final StackLift _stackLift;

  NormalArgOperation(
      {StackLift? stackLift,
      required this.arg,
      required String name,
      this.numExtendedOpCodes = 0})
      : _stackLift = stackLift ?? StackLift.enable,
        super(name: name) {
    arg.op = this;
  }

  @override
  void Function(Model m)? get floatCalc => null;
  @override
  void Function(Model m)? get intCalc => null;
  @override
  void Function(Model m)? get complexCalc => null;

  ///
  /// Do nothing -- we don't know our argument yet.
  ///
  @override
  void pressed(LimitedState arg) {}
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
  BranchingOperation({required String name, required void Function(Model) calc})
      : super(name: name, calc: calc);

  BranchingOperation.differentFloatAndInt(
      {required String name,
      required void Function(Model) floatCalc,
      required void Function(Model) intCalc})
      : super.differentFloatAndInt(
            name: name, floatCalc: floatCalc, intCalc: intCalc);

  /// Branching operations only perform a calculation when we are running
  /// a program.
  @override
  T? calcDefinedFor<T>(Controller controller, T? calc) =>
      controller._branchingOperationCalc(calc);
}

///
/// A [BranchingOperation] that takes an argument, namely B? (bit test)
///
class BranchingArgOperation extends NormalArgOperation {
  BranchingArgOperation({required OperationArg arg, required String name})
      : super(arg: arg, name: name);

  /// Branching operations only perform a calculation when we are running
  /// a program.
  @override
  T? calcDefinedFor<T>(Controller controller, T? calc) =>
      controller._branchingOperationCalc(calc);
}

///
/// A description of the argument for a [NormalArgOperation] or a
/// [BranchingArgOperation].  This includes the calculation that is to be
/// performed when the argument value is available.
///
class OperationArg extends ProgramOperationArg {
  final void Function(Model, int)? floatCalc;
  final void Function(Model, int)? intCalc;
  final void Function(Model, int)? complexCalc;
  final void Function(ActiveState)? pressed;
  late final NormalArgOperation op;
  @override
  final ArgDescription desc;

  OperationArg(
      {required this.floatCalc,
      required this.intCalc,
      Function(Model, int)? complexCalc,
      this.pressed,
      required this.desc})
      : complexCalc = complexCalc ?? floatCalc;

  OperationArg.both(
      {required void Function(Model, int) calc,
      this.pressed,
      required this.desc})
      : floatCalc = calc,
        intCalc = calc,
        complexCalc = calc;

  OperationArg.intOnly(
      {required this.intCalc, this.pressed, required this.desc})
      : floatCalc = null,
        complexCalc = null;

  void onArgComplete(LimitedState state, int argValue) =>
      state.onArgComplete(this, argValue);

  ControllerState makeInputState(Controller c, LimitedState fromState) =>
      ArgInputState(c, this, fromState);
}

///
/// The description of an argument for GSB, which requires a special state
/// for inputting the argument to preview the instruction that's about to
/// be executed.
///
class GosubOperationArg extends OperationArg {
  GosubOperationArg.both(
      {required void Function(Model, int) calc, required ArgDescription desc})
      : super.both(calc: calc, desc: desc);

  @override
  ControllerState makeInputState(Controller c, LimitedState fromState) =>
      GosubArgInputState(c, this, fromState);
}

///
/// The argument for the float mode key.  It's special
/// because stack lift is enabled when going from int mode to float mode,
/// but it's stack neutral if staying in float mode.
///
class FloatKeyArg extends OperationArg {
  FloatKeyArg(
      {required ArgDescription desc, required void Function(Model, int) calc})
      : super(floatCalc: calc, intCalc: calc, desc: desc);

  @override
  void onArgComplete(LimitedState state, int argValue) {
    if (!state.model.isFloatMode) {
      state.controller._stackLiftEnabled = true;
      // See page 100:  Stack lift is enabled when we go from int mode to
      // float mode, but not when we stay in float mode.  So: CLX,
      // FLOAT 2, 7 will not lift stack.
    }
    state.onArgComplete(this, argValue);
  }

  @override
  ControllerState makeInputState(Controller c, LimitedState fromState) =>
      FloatKeyArgInputState(c, this, fromState);
}

class KeyboardController {
  late final RealController controller;
  PhysicalKeyboardKey? _physicalKeyThatIsDown;
  final button = <String, CalculatorButtonState>{};
  CalculatorButtonState? _buttonThatIsDown;
  // For < and > accelerators, which imply a g-shift:
  CalculatorButtonState? _extraShiftThatIsDown;
  DateTime lastKeyDown = DateTime.now();

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

  KeyEventResult onKey(RawKeyEvent e) {
    if (e is! RawKeyDownEvent) {
      if (e is RawKeyUpEvent && e.physicalKey == _physicalKeyThatIsDown) {
        releasePressedButton();
        _physicalKeyThatIsDown = null;
      }
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
      if (e.isControlPressed && (sch == 'f' || sch == 'F')) {
        // Yes, JavaScript really does suck.  In case you were wondering.
        ch = Characters('\u0006');
      } else if (e.isControlPressed && (sch == 'g' || sch == 'G')) {
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
