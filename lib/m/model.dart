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
/// The model for the calculator, centered around [Model].  It retains the
/// state of the calculator, most of which is saved persistently.  It
/// also functions as a helper to the controller, by providing states
/// using the state pattern for calculator modes, like the [DisplayMode]
/// and the [SignMode].  The overall structure looks like this:
///
/// <br>
/// <img src="dartdoc/model/model.svg" style="width: 100%;"/>
/// <br>
/// <br>
/// The [Model] has a [Memory], which is the 406 nybble storage that's
/// shared between [ProgramMemory] and [Registers].  Part of the model
/// is the [LcdContents], which holds the data that ultimately
/// gets displayed in the view's `LcdDisplay`.  The model is only loosely
/// coupled to the view, by making the display contents [Observable].
///
library model;

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:io' show Platform;

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'complex.dart';

part 'values.dart';
part 'display_mode.dart';
part 'args.dart';
part 'sign_mode.dart';
part 'memory.dart';

// See the library comments, above!  (Android Studio  hides them by default.)

///
/// A comparable data holder for the contents of what is displayed on the LCD
///
class LcdContents {
  final bool blank;
  final String mainText;
  final ShiftKey shift;
  final ShiftKey? extraShift;

  /// For self test
  final SignMode sign;
  final int bits;
  final bool cFlag; // 16C's carry flag
  final bool complexFlag; // 16C's complex flag, not in same place as cFlag
  final bool gFlag;
  final bool prgmFlag;
  final bool rightJustify;
  final bool windowEnabled;
  final bool euroComma;
  final bool hideComplement;
  final int? wordSize;
  final TrigMode trigMode;
  final bool userMode;

  Timer? _myTimer;

  LcdContents(
      {required this.mainText,
      required this.shift,
      required this.sign,
      required this.bits,
      required this.cFlag,
      required this.complexFlag,
      required this.gFlag,
      required this.prgmFlag,
      required this.rightJustify,
      required this.windowEnabled,
      required this.euroComma,
      required this.hideComplement,
      required this.wordSize,
      required this.trigMode,
      required this.userMode,
      this.extraShift})
      : blank = false;

  LcdContents.blank({Timer? timer})
      : blank = true,
        mainText = '',
        shift = ShiftKey.none,
        sign = SignMode.twosComplement,
        bits = 0,
        cFlag = false,
        complexFlag = false,
        gFlag = false,
        prgmFlag = false,
        rightJustify = false,
        windowEnabled = false,
        euroComma = false,
        hideComplement = false,
        wordSize = null,
        trigMode = TrigMode.deg,
        userMode = false,
        _myTimer = timer,
        extraShift = null;

  LcdContents.powerOn(String text, this.rightJustify)
      : mainText = rightJustify ? text : ' $text',
        blank = false,
        shift = ShiftKey.none,
        sign = SignMode.twosComplement,
        bits = 0,
        cFlag = false,
        complexFlag = false,
        gFlag = false,
        prgmFlag = false,
        windowEnabled = false,
        euroComma = false,
        hideComplement = false,
        wordSize = null,
        trigMode = TrigMode.deg,
        userMode = false,
        _myTimer = null,
        extraShift = null;

  bool equivalent(LcdContents other) =>
      blank == other.blank &&
      mainText == other.mainText &&
      shift == other.shift &&
      sign == other.sign &&
      bits == other.bits &&
      cFlag == other.cFlag &&
      gFlag == other.gFlag &&
      prgmFlag == other.prgmFlag &&
      rightJustify == other.rightJustify &&
      euroComma == other.euroComma &&
      hideComplement == other.hideComplement &&
      wordSize == other.wordSize &&
      windowEnabled == other.windowEnabled &&
      complexFlag == other.complexFlag &&
      trigMode == other.trigMode &&
      userMode == other.userMode &&
      extraShift == other.extraShift;

  @override
  String toString() => blank
      ? 'LcdContents(blank)'
      : 'LcdContents($mainText, ${shift.name}, C=$cFlag, G=$gFlag)';
}

///
/// An error that should result in "Error x" being displayed
/// on the LCD Display
///
class CalculatorError {
  final int num16;
  final int num15;

  CalculatorError(int num, {int? num15})
      : num16 = num,
        num15 = num15 ?? num;

  @override
  String toString() => 'CalculatorError($num16, $num15)';
}

enum OrientationSetting { auto, portrait, landscape }

///
/// User settings that control the calculator's appearance or behavior
///
class Settings {
  final Model _model;
  final Observable<bool> menuEnabled = Observable(true);
  bool _windowEnabled = true;
  bool _euroComma = false;
  bool _hideComplement = false;
  bool _showWordSize = false;
  final Observable<bool> showAccelerators = Observable(false);
  double? _msPerInstruction;
  bool _traceProgramToStdout = false;
  static const double _msPerInstructionDefault = 50;
  // My 15C does about 100 add instructions in ten seconds, which would be
  // 100ms per instruction.  Going about double that speed gives pleasing
  // results.
  OrientationSetting _orientation = OrientationSetting.auto;
  bool _systemOverlaysDisabled = false;

  Settings(this._model) {
    menuEnabled.addObserver((_) => _model.needsSave = true);
    showAccelerators.addObserver((_) => _model.needsSave = true);
  }

  void _reset() {
    menuEnabled.value = true;
    _windowEnabled = true;
    _euroComma = false;
    _hideComplement = false;
    _showWordSize = false;
    showAccelerators.value = false;
    _msPerInstruction = null;
    _traceProgramToStdout = false;
    _orientation = OrientationSetting.auto;
    _setPlatformOrientation();
    _systemOverlaysDisabled = false;
    _setPlatformOverlays();
  }

  ///
  /// Should we show the word size annunciator on the display?
  ///
  bool get showWordSize => _showWordSize;
  set showWordSize(bool v) {
    _showWordSize = v;
    _model.needsSave = true;
  }

  ///
  /// Should the window functions be enabled?  If not, we just shrink the
  /// digits when a number is too big.
  ///
  bool get windowEnabled => _windowEnabled;
  set windowEnabled(bool v) {
    _windowEnabled = v;
    _model.needsSave = true;
  }

  ///
  /// Should we show numbers Euro-style, with commas instead of periods
  /// and vice-versa?
  ///
  bool get euroComma => _euroComma;
  set euroComma(bool v) {
    _euroComma = v;
    _model.needsSave = true;
  }

  ///
  /// Should we hide the complement annunciator?
  ///
  bool get hideComplement => _hideComplement;
  set hideComplement(bool v) {
    _hideComplement = v;
    _model.needsSave = true;
  }

  ///
  /// How long do we want an instruction to take when running a program?
  /// Note that number keys run about 5x faster than this.
  ///
  double get msPerInstruction => _msPerInstruction ?? _msPerInstructionDefault;
  set msPerInstruction(double? msPerInstruction) {
    if (msPerInstruction == _msPerInstructionDefault) {
      msPerInstruction = null;
    }
    _msPerInstruction = msPerInstruction;
    _model.needsSave = true;
  }

  ///
  /// When running a program, should a program trace be sent to stdout?  This
  /// can only be set by importing a JSON file, on the theory that people
  /// who can get at stdout are also comfortable hacking a JSON file, and
  /// trying to explain "stdout" in a settings menu is hard.
  ///
  bool get traceProgramToStdout => _traceProgramToStdout;

  ///
  /// Not really a setting, but we need it in the same places:  Is it possible
  /// to set the screen orientation on this device?  It is iff we're a native
  /// mobile app.
  ///
  bool get isMobilePlatform =>
      !kIsWeb && (Platform.isIOS || Platform.isAndroid || Platform.isFuchsia);

  bool get systemOverlaysDisabled => _systemOverlaysDisabled;

  set systemOverlaysDisabled(bool v) {
    if (!isMobilePlatform) {
      return;
    }
    _systemOverlaysDisabled = v;
    _setPlatformOverlays();
    _model.needsSave = true;
  }

  void _setPlatformOverlays() {
    if (systemOverlaysDisabled) {
      unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive));
    } else if (!kIsWeb && Platform.isIOS) {
      // Get rid of ugly black bar along bottom.  It doesn't seem to do
      // anything -- maybe to be functional it has to be configured
      // somehow?
      unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
          overlays: [SystemUiOverlay.top]));
    } else {
      unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    }
  }

  OrientationSetting get orientation => _orientation;

  set orientation(OrientationSetting v) {
    if (!isMobilePlatform) {
      return;
    }
    _orientation = v;
    _setPlatformOrientation();
    _model.needsSave = true;
  }

  void _setPlatformOrientation() {
    final List<DeviceOrientation> orientations;
    switch (orientation) {
      case OrientationSetting.auto:
        orientations = [];
        break;
      case OrientationSetting.portrait:
        orientations = [
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown
        ];
        break;
      case OrientationSetting.landscape:
        orientations = [
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight
        ];
        break;
    }
    unawaited(SystemChrome.setPreferredOrientations(orientations));
  }

  ///
  /// Convert to a data structure that can be serialized as JSON.
  ///
  Map<String, dynamic> toJson({bool comments = false}) {
    final r = <String, dynamic>{
      'menuEnabled': menuEnabled.value,
      'windowEnabled': _windowEnabled,
      'euroComma': _euroComma,
      'hideComplement': _hideComplement,
      'showWordSize': _showWordSize,
      'showAccelerators': showAccelerators.value,
      'systemOverlaysDisabled': systemOverlaysDisabled,
      'orientation': orientation.index
    };
    if (_msPerInstruction != null) {
      r['msPerInstruction'] = _msPerInstruction;
    }
    if (comments || _traceProgramToStdout) {
      r['traceProgramToStdout'] = _traceProgramToStdout;
    }
    return r;
  }

  ///
  /// Convert from a data structure that comes from JSON.  If there's an
  /// error in the middle, it might be partially read, but not in a way
  /// that causes bad behavior in the calculator.
  ///
  void decodeJson(Map<String, dynamic> json) {
    menuEnabled.value = json['menuEnabled'] as bool;
    _windowEnabled = json['windowEnabled'] as bool;
    _euroComma = json['euroComma'] as bool;
    _hideComplement = json['hideComplement'] as bool;
    _showWordSize = json['showWordSize'] as bool? ?? false;
    showAccelerators.value = json['showAccelerators'] == true; // could be null
    _msPerInstruction = (json['msPerInstruction'] as num?)?.toDouble();
    _traceProgramToStdout = (json['traceProgramToStdout'] as bool?) ?? false;
    _systemOverlaysDisabled =
        (json['systemOverlaysDisabled'] as bool?) ?? false;
    _setPlatformOverlays();
    int? ov = json['orientation'] as int?;
    if (ov == null || ov < 0 || ov > OrientationSetting.values.length) {
      _orientation = OrientationSetting.auto;
    } else {
      _orientation = OrientationSetting.values[ov];
    }
    _setPlatformOrientation();
    _traceProgramToStdout = (json['traceProgramToStdout'] as bool?) ?? false;
  }
}

///
/// A bit of interface segregation:  A reduced API of just the stuff
/// int operations need from the model.  This comes in handy for the
/// double operations, and for dealing with the I register.  I is always
/// 68 bits long, regardless of the calculator's current word size.
///
abstract class NumStatus {
  abstract bool cFlag;
  abstract bool gFlag;
  int get wordSize;
  BigInt get wordMask;
  BigInt get signMask;
  BigInt get maxInt;
  BigInt get minInt;
  bool get isFloatMode;
  IntegerSignMode get integerSignMode;
}

///
/// Our model, the main entry point to this module.  See the library-level
/// documentation for a description, and an explanation of the model's
/// structure.  Extended by Model15 and Model16.
///
abstract class Model<OT extends ProgramOperation> implements NumStatus {
  late final display = DisplayModel(this);
  late final settings = Settings(this);
  @protected
  bool needsSave = false;
  ShiftKey _shift = ShiftKey.none;
  int _wordSize;
  BigInt _wordMask;
  BigInt _signMask;
  TrigMode trigMode = TrigMode.deg;
  DisplayMode _displayMode;
  IntegerSignMode _integerSignMode = SignMode.twosComplement;
  bool displayDisabled = false;
  Model(this._displayMode, this._wordSize, int numFlags)
      : _flags = List<bool>.filled(numFlags, false, growable: false),
        _wordMask = (BigInt.one << _wordSize) - BigInt.one,
        _signMask = BigInt.one << (_wordSize - 1);

  /// The list of "logical" keys.  This has nothing to do with the UI;
  /// The order of the operations in this list determines the
  /// externalized form of the operations in the calculator's storage
  /// (the opcodes).  It also determines the displayed appearance of
  /// operations in program mode, whether the calculator is in portrait or
  /// landscape orientation.
  ///
  /// Changing the order here would render old JSON files of the
  /// calculator's state obsolete.
  List<List<MKey<OT>?>> get logicalKeys;

  ///
  /// The name of this model of the calculator (16C or 15C).
  ///
  String get modelName;

  int get returnStackSize;

  bool get userMode => false;

  ///
  /// Create an instance of the model-specific ProgramInstruction subtype
  ///
  ProgramInstruction<OT> newProgramInstruction(OT operation, ArgDone arg);

  /// Not used, but we retain any comments found in the JSON file
  /// so we can write them back out.
  Object? _comments;

  @override
  BigInt get maxInt => _integerSignMode.maxValue(this);
  @override
  BigInt get minInt => _integerSignMode.minValue(this);
  @override
  bool get isFloatMode => displayMode.isFloatMode;

  bool get isComplexMode => _imaginaryStack != null;
  set isComplexMode(bool v);

  DoubleWordStatus? _doubleWordStatus; // for double divide, multiply
  Memory<OT> get memory;
  final Observable<bool> onIsPressed = Observable(false);

  /// Are we entering a program?
  bool prgmFlag = false;
  DebugLog? _debugLog;
  static const int _jsonVersion = 1;

  final List<Value> _stack = List<Value>.filled(4, Value.zero, growable: false);
  List<Value>? _imaginaryStack;
  Complex _getComplex(int i) =>
      Complex(_stack[i].asDouble, _imaginaryStack![i].asDouble);
  void _setComplex(int i, Complex v) {
    _stack[i] = Value.fromDouble(v.real);
    _imaginaryStack![i] = Value.fromDouble(v.imaginary);
    needsSave = true;
  }

  Value get x => _stack[0];

  /// Get x as a signed BigInt
  BigInt get xI => _integerSignMode.toBigInt(_stack[0], this);

  /// Get x as a Dart double
  double get xF => _stack[0].asDouble;

  /// Get x as a complex value
  Complex get xC => _getComplex(0);

  /// Just the imaginary part of x
  Value get xImaginary => _imaginaryStack![0];

  set x(Value v) {
    if (identical(v, Value.fInfinity)) {
      floatOverflow = true;
      v = Value.fMaxValue;
    } else if (identical(v, Value.fNegativeInfinity)) {
      floatOverflow = true;
      v = Value.fMinValue;
    }
    _stack[0] = v;
    _imaginaryStack?[0] = Value.zero;
    needsSave = true;
    display.window = 0;
  }

  ///
  /// Sets the imaginary part of X.  This is *only* to be used after
  /// the real part is already set.
  ///
  set xImaginary(Value v) {
    if (identical(v, Value.fInfinity)) {
      floatOverflow = true;
      v = Value.fMaxValue;
    } else if (identical(v, Value.fNegativeInfinity)) {
      floatOverflow = true;
      v = Value.fMinValue;
    }
    _imaginaryStack![0] = v;
  }

  /// Set x from a signed BigInt
  set xI(BigInt v) => x = _integerSignMode.fromBigInt(v, this);

  /// Set x from a Dart double
  set xF(double v) => x = Value.fromDouble(v);

  /// Set x from a complex value
  set xC(Complex v) => _setComplex(0, v);

  /// Pop the stack and set X, setting lastX
  // ignore: avoid_setters_without_getters
  set popSetResultX(Value v) {
    _popStackSetLastX();
    x = v;
    needsSave = true;
  }

  /// Pop the stack and set X from a signed BigInt, setting lastX
  // ignore: avoid_setters_without_getters
  set popSetResultXI(BigInt v) {
    popSetResultX = _integerSignMode.fromBigInt(v, this);
  }

  /// Pop the stack and set X from a Dart double, setting lastX
  // ignore: avoid_setters_without_getters
  set popSetResultXF(double v) => popSetResultX = Value.fromDouble(v);

  /// Pop the stack and set X from a Dart double, setting lastX
  // ignore: avoid_setters_without_getters
  set popSetResultXC(Complex v) {
    _popStackSetLastX();
    _setComplex(0, v);
    needsSave = true;
  }

  /// Set a result in X, which saves the old X value in lastX
  // ignore: avoid_setters_without_getters
  set resultX(Value v) {
    lastX = x;
    x = v;
    needsSave = true;
  }

  // ignore: avoid_setters_without_getters
  set resultXI(BigInt v) => resultX = _integerSignMode.fromBigInt(v, this);
  // ignore: avoid_setters_without_getters
  set resultXF(double v) => resultX = Value.fromDouble(v);
  // ignore: avoid_setters_without_getters
  set resultXC(Complex v) {
    lastX = x;
    _lastXImaginary = _imaginaryStack![0];
    xC = v;
    needsSave = true;
  }

  Value get y => _stack[1];
  BigInt get yI => _integerSignMode.toBigInt(_stack[1], this);
  double get yF => _stack[1].asDouble;
  Complex get yC => _getComplex(1);
  set y(Value v) {
    _stack[1] = v;
    _imaginaryStack?[1] = Value.zero;
    needsSave = true;
  }

  set yI(BigInt v) => y = _integerSignMode.fromBigInt(v, this);
  set yF(double v) => y = Value.fromDouble(v);
  set yC(Complex v) => _setComplex(1, v);

  Value get z => _stack[2];
  Complex get zC => _getComplex(2);

  set z(Value v) {
    _stack[2] = v;
    _imaginaryStack?[2] = Value.zero;
    needsSave = true;
  }

  set zF(double v) => z = Value.fromDouble(v);

  Value get t => _stack[3];
  set t(Value v) {
    _stack[3] = v;
    _imaginaryStack?[3] = Value.zero;
    needsSave = true;
  }

  void setYZT(Value v) {
    assert(!isComplexMode);
    // This is only used converting between int and float
    _stack[3] = _stack[2] = _stack[1] = v;
    needsSave = true;
  }

  void setXYZT(Value v) {
    _stack[3] = _stack[2] = _stack[1] = _stack[0] = v;
    final im = _imaginaryStack;
    if (im != null) {
      im[3] = im[2] = im[1] = im[0] = Value.zero;
    }
    needsSave = true;
  }

  Value _lastX = Value.zero;
  Value? _lastXImaginary;

  Value get lastX => _lastX;
  Complex get lastXC => Complex(_lastX.asDouble, _lastXImaginary!.asDouble);
  set lastX(Value v) {
    _lastX = v;
    if (isComplexMode) {
      _lastXImaginary = Value.zero;
    }
    needsSave = true;
  }

  set lastXC(Complex v) {
    _lastX = Value.fromDouble(v.real);
    _lastXImaginary = Value.fromDouble(v.imaginary);
    needsSave = true;
  }

  String formatValue(Value v) => displayMode.format(v, this);

  Value getStackByIndex(int i) => _stack[i];
  Complex getStackByIndexC(int i) => _getComplex(i);

  @override
  int get wordSize => _wordSize;
  @override
  BigInt get wordMask => _wordMask;
  @override
  BigInt get signMask => _signMask;

  ///
  /// Set the word size, and fix up the values on the stack for the new
  /// size.  A size of 0 is interpreted as 64, as per the 16C.
  ///
  set wordSize(int v) {
    _doubleWordStatus = null;
    if (v == 0) {
      v = 64;
    }
    if (v < 1 || v > 64) {
      throw CalculatorError(2);
    }
    if (v != _wordSize) {
      final BigInt newMask = (BigInt.one << v) - BigInt.one;
      lastX = lastX.changeBitSize(newMask);
      for (int i = 0; i < _stack.length; i++) {
        _stack[i] = _stack[i].changeBitSize(newMask);
      }
      _wordSize = v;
      _wordMask = newMask;
      _signMask = BigInt.one << (v - 1);
      display.window = 0;
    }
    display.displayX(); // If v unchanged, still want the blink.
    needsSave = true;
  }

  DisplayMode get displayMode => _displayMode;
  set displayMode(DisplayMode v) {
    _displayMode.convertValuesTo(v, this);
    _displayMode = v;
    if (v.isFloatMode) {
      wordSize = 56; // "Converts" values which is n/a for FloatValue
      // Setting numBits already displays X
    } else {
      display.displayX();
    }
    needsSave = true;
  }

  ProgramMemory<OT> get program => memory.program;

  SignMode get signMode => displayMode.signMode(_integerSignMode);
  set integerSignMode(IntegerSignMode v) {
    _integerSignMode = v;
    display.displayX();
    needsSave = true;
  }

  @override
  IntegerSignMode get integerSignMode => _integerSignMode;

  /// Determine if this value is 0 or, if applicable, -0.  Not for use with an
  /// index register value, since it can have a different representation
  /// for -0 -- cf. Memory.isZeroI()
  bool isZero(Value v) => signMode.isZero(this, v);

  ShiftKey get shift => _shift;
  set shift(ShiftKey v) {
    _shift = v;
    display.update();
  }

  final List<bool> _flags;

  // ignore: avoid_positional_boolean_parameters
  void setFlag(int i, bool v) {
    if (i >= _flags.length) {
      throw CalculatorError(1);
    }
    _flags[i] = v;
    display.update();
    needsSave = true;
  }

  bool getFlag(int i) {
    if (i >= _flags.length) {
      throw CalculatorError(1);
    }
    return _flags[i];
  }

  bool get displayLeadingZeros;

  void _popStackSetLastX() {
    lastX = _stack[0];
    _lastXImaginary = _imaginaryStack?[0];
    popStack();
    needsSave = true;
  }

  void popStack() {
    void f(final List<Value>? st) {
      if (st != null) {
        st[0] = st[1];
        st[1] = st[2];
        st[2] = st[3];
      }
    }

    f(_stack);
    f(_imaginaryStack);
    display.window = 0;
    needsSave = true;
  }

  void swapXY() {
    void f(final List<Value>? st) {
      if (st != null) {
        Value t = st[0];
        st[0] = st[1];
        st[1] = t;
      }
    }

    f(_stack);
    f(_imaginaryStack);
    display.window = 0;
    needsSave = true;
  }

  /// "lift" stack, after which one can write to x
  void pushStack() {
    void f(final List<Value>? st) {
      if (st != null) {
        st[3] = st[2];
        st[2] = st[1];
        st[1] = st[0];
      }
    }

    f(_stack);
    f(_imaginaryStack);
    needsSave = true;
  }

  /// the R<down arrow> key
  void rotateStackDown() {
    void f(final List<Value>? st) {
      if (st != null) {
        Value t = st[0];
        st[0] = st[1];
        st[1] = st[2];
        st[2] = st[3];
        st[3] = t;
      }
    }

    f(_stack);
    f(_imaginaryStack);
    display.window = 0;
    needsSave = true;
  }

  /// The R<up arrow> key
  void rotateStackUp() {
    void f(final List<Value>? st) {
      if (st != null) {
        Value t = st[3];
        st[3] = st[2];
        st[2] = st[1];
        st[1] = st[0];
        st[0] = t;
      }
    }

    f(_stack);
    f(_imaginaryStack);
    display.window = 0;
    needsSave = true;
  }

  /// The float overflow flag, which is stored as gFlag on the 16C.  On the 15C,
  /// it causes errorFlash to be true.
  set floatOverflow(bool v);
  bool get floatOverflow;

  bool get errorBlink;
  void resetErrorBlink() {}

  /// Are register numbers base 10 (15C), or base 16 (16C)?
  int get registerNumberBase;

  ///
  /// Try to parse `s` consistent with the current display mode, giving a
  /// Value on success.
  ///
  Value? tryParseValue(String s) => displayMode.tryParse(s, this);

  LcdContents _newLcdContents({bool disableWindow = false}) {
    return LcdContents(
        mainText:
            disableWindow ? display.currentWithoutWindow : display.current,
        shift: shift,
        sign: signMode,
        bits: wordSize,
        cFlag: cFlag,
        complexFlag: isComplexMode,
        trigMode: trigMode,
        userMode: userMode,
        gFlag: gFlag,
        prgmFlag: prgmFlag,
        rightJustify: displayMode.rightJustify,
        windowEnabled: disableWindow ? false : settings.windowEnabled,
        euroComma: settings.euroComma,
        wordSize: settings.showWordSize ? wordSize : null,
        hideComplement: settings.hideComplement);
  }

  LcdContents _newLcdContentsJustDigits() {
    return LcdContents(
        mainText: display.current,
        shift: ShiftKey.none,
        sign: SignMode.twosComplement,
        bits: 0,
        cFlag: false,
        complexFlag: false,
        gFlag: false,
        prgmFlag: false,
        rightJustify: false,
        windowEnabled: false,
        euroComma: false,
        hideComplement: false,
        wordSize: null,
        trigMode: TrigMode.deg,
        userMode: false,
        extraShift: null);
  }

  ///
  /// Negate the value in x like the CHS key does.  The behavior varies
  /// according to the current sign mode.  In complex mode, it leaves the
  /// imaginary part alone.
  ///
  void chsX() {
    _stack[0] = signMode.negate(x, this);
    needsSave = true;
    display.window = 0;
  }

  ///
  /// Compare two values according to the current sign mode
  ///
  int compare(Value x, Value y) => signMode.compare(this, x, y);

  ///
  /// Reset the calculator to its default state.
  ///
  void reset() {
    settings._reset();
    displayMode = DisplayMode.hex;
    integerSignMode = SignMode.twosComplement;
    wordSize = 16;
    for (int i = 0; i < _stack.length; i++) {
      _stack[i] = Value.zero;
    }
    _lastX = Value.zero;
    for (int i = 0; i < _flags.length; i++) {
      _flags[i] = false;
    }
    memory.reset();
    display.window = 0;
    prgmFlag = false;
    needsSave = true;
  }

  ///
  /// Gives a helper object for implementation of the double-integer multiply,
  /// remainder and divide operations.
  ///
  DoubleWordStatus get doubleWordStatus {
    _doubleWordStatus ??= DoubleWordStatus(this);
    return _doubleWordStatus!;
  }

  ///
  /// Convert to a data structure that can be serialized as JSON.
  ///
  Map<String, Object> toJson({bool comments = false}) {
    final r = <String, Object>{};
    if (comments && _comments != null) {
      r['comments'] = _comments!;
    }
    r['version'] = _jsonVersion;
    r['modelName'] = modelName;
    r['settings'] = settings.toJson(comments: comments);
    final tm = trigMode.toJson();
    if (tm != null) {
      r['trigMode'] = tm;
    }
    r['displayMode'] = _displayMode.toJson();
    r['integerSignMode'] = _integerSignMode.toJson();
    r['wordSize'] = _wordSize;
    r['stack'] = _stack.map((v) => v.toJson()).toList();
    r['lastX'] = _lastX.toJson();
    if (isComplexMode) {
      r['imaginaryStack'] = _imaginaryStack!.map((v) => v.toJson()).toList();
      r['lastXImaginary'] = _lastXImaginary!.toJson();
    }
    r['flags'] = _flags;
    r['memory'] = memory.toJson(comments: comments);
    final debugLog = _debugLog;
    if (debugLog != null && comments) {
      r['debugLog'] = debugLog.toJson(comments: comments);
      r['endDisplay'] = display.current;
    }
    return r;
  }

  ///
  /// Convert from a data structure that comes from JSON.  If there's an
  /// error in the middle, it might be partially read, but not in a way
  /// that causes bad behavior in the calculator.
  ///
  void decodeJson(Map<String, dynamic> json, {required bool needsSave}) {
    if (_jsonVersion != json['version']) {
      throw ArgumentError("Version ${json['version']} unrecognized");
    }
    final String jModelName = (json['modelName'] as String?) ?? '16C';
    // 16C came first, and older 16C versions don't save the model name.
    if (modelName != jModelName) {
      throw ArgumentError(
          'Wrong calculator model.  This is a $modelName, not a $jModelName.');
    }

    _comments = json['comments'];
    settings.decodeJson(json['settings'] as Map<String, dynamic>);
    trigMode = TrigMode.fromJson(json['trigMode']);
    integerSignMode =
        IntegerSignMode.fromJson(json['integerSignMode'] as String);
    final List<dynamic>? ims = json['imaginaryStack'] as List<dynamic>?;
    displayMode = DisplayMode.fromJson(json['displayMode']!, ims != null);
    // displayMode must be set before stack, since setting
    // display mode alters stack
    wordSize = json['wordSize'] as int;
    int i = 0;
    for (final v in json['stack'] as List<dynamic>) {
      _stack[i++] = Value.fromJson(v as String);
    }
    _lastX = Value.fromJson(json['lastX'] as String);
    if (ims == null) {
      _imaginaryStack = null;
    } else {
      _imaginaryStack = List<Value>.filled(4, Value.zero, growable: false);
      i = 0;
      for (final v in ims) {
        _imaginaryStack![i] = Value.fromJson(v as String);
      }
    }
    final imx = json['lastXImaginary'] as String?;
    if (imx == null) {
      _lastXImaginary = null;
    } else {
      _lastXImaginary = Value.fromJson(imx);
    }
    i = 0;
    for (final v in json['flags'] as List<dynamic>) {
      _flags[i++] = v as bool;
    }
    memory.decodeJson(json['memory'] as Map<String, dynamic>);
    Object? debugLog = json['debugLog'];
    if (debugLog == null) {
      _debugLog = null;
    } else {
      _debugLog = DebugLog.fromJson(debugLog as Map<String, dynamic>, this);
    }
    display.window = 0;
    this.needsSave = needsSave;
  }

  Future<void> readFromPersistentStorage() async {
    final storage = await SharedPreferences.getInstance();
    String? js = storage.getString('init');
    if (js != null) {
      try {
        decodeJson(json.decode(js) as Map<String, dynamic>, needsSave: false);
      } finally {
        display.displayX(flash: false);
      }
    }
  }

  Future<void> resetFromPersistentStorage() {
    reset();
    return readFromPersistentStorage();
  }

  Future<void> writeToPersistentStorage() async {
    // We could query needsSave here, but this is called infrequently.
    // A full audit to make sure needsSave is always updated would be needed
    // to restore the query here.
    needsSave = false;
    final storage = await SharedPreferences.getInstance();
    String js = json.encode(toJson());
    await storage.setString('init', js);
  }

  ///
  /// Starts or stops capturing debug log information.  A debug log captures
  /// the calculator state, and subsequent keystrokes.  It's meant to be a
  /// tool to facilitate bug reports.
  ///
  set captureDebugLog(bool v) {
    if (v) {
      _debugLog ??= (DebugLog(this)..initModelState());
    } else {
      _debugLog = null;
    }
  }

  bool get captureDebugLog => _debugLog != null;
  DebugLog? get debugLog => _debugLog;

  bool initializeFromJsonOrUri(String linkOrJson) {
    final String js;
    if (linkOrJson.startsWith('http://') || linkOrJson.startsWith('https://')) {
      final q = Uri.tryParse(linkOrJson)?.queryParameters;
      if (q == null || q.isEmpty) {
        return false;
      }
      final String? qs = q['state'];
      if (qs == null) {
        throw ArgumentError('No state query parameter in $linkOrJson');
      }
      js = String.fromCharCodes(
          const ZLibDecoder().decodeBytes(base64Url.decoder.convert(qs)));
    } else {
      js = linkOrJson;
    }
    try {
      decodeJson(json.decode(js) as Map<String, dynamic>, needsSave: true);
    } finally {
      display.displayX(flash: false);
    }
    return true;
  }

  @protected
  void setupComplex(List<Value>? imaginaryStack) {
    final nowComplex = imaginaryStack != null;
    assert(isComplexMode != nowComplex);
    displayMode.setComplexMode(this, nowComplex);
    _imaginaryStack = imaginaryStack;
    if (nowComplex) {
      _lastXImaginary = Value.zero;
    } else {
      _lastXImaginary = null;
    }
  }

  LcdContents selfTestContents();
}

///
/// An object for helping with the "double" integer functions, double multiply,
/// double divide and double remainder
///
class DoubleWordStatus implements NumStatus {
  final Model _model;

  @override
  bool cFlag;

  @override
  bool gFlag;

  @override
  final int wordSize;

  @override
  final BigInt wordMask;

  @override
  final BigInt signMask;

  @override
  IntegerSignMode get integerSignMode => _model.integerSignMode;

  DoubleWordStatus(final Model model)
      : _model = model,
        cFlag = false,
        gFlag = false,
        wordSize = model.wordSize * 2,
        wordMask = (BigInt.one << (model.wordSize * 2)) - BigInt.one,
        signMask = BigInt.one << (model.wordSize * 2 - 1);

  @override
  BigInt get maxInt => _model._integerSignMode.maxValue(this);

  @override
  BigInt get minInt => _model._integerSignMode.minValue(this);

  @override
  bool get isFloatMode => _model.isFloatMode;
}

///
/// Superclass for things that can be selected based on whether the f or
/// g key, or neither, has been pressed.  See ShiftKey.select.  It's a
/// little like the Visitor pattern - a tyepsafe way of avoiding a switch
/// statement on the shift key.
///
mixin ShiftKeySelected<T> {
  T get uKey;
  T get fKey;
  T get gKey;
}

///
/// The state of which shift key was last pressed, if any.
///
class ShiftKey {
  static final ShiftKey none =
      ShiftKey._p('', <T>(ShiftKeySelected<T> v) => v.uKey);
  static final ShiftKey f =
      ShiftKey._p('f', <T>(ShiftKeySelected<T> v) => v.fKey);
  static final ShiftKey g =
      ShiftKey._p('g', <T>(ShiftKeySelected<T> v) => v.gKey, offset: true);

  final String name;

  ///
  /// Select the appropriate member from a selectable [ShiftKeySelected]
  /// based on the [Model]'s shift status.
  ///
  final T Function<T>(ShiftKeySelected<T> selectable) select;

  final bool offset; // in the LCD display

  ShiftKey._p(this.name, this.select, {this.offset = false});
}

///
/// A pretty bog-standard observable.  Odd that Dart doesn't have one in
/// the core library.
///
/// Oh - `ValueSetter<T>` and friends, maybe?  Whatever.
///
class Observable<T> {
  T _value;
  final List<void Function(T)> _observers = List.empty(growable: true);

  Observable(this._value);

  T get value => _value;

  set value(T v) {
    _value = v;
    _notifyAll();
  }

  void addObserver(void Function(T) o) {
    _observers.add(o);
    o(value);
  }

  void removeObserver(void Function(T) o) {
    bool ok = _observers.remove(o);
    assert(ok);
  }

  void _notifyAll() {
    for (final f in _observers) {
      f(value);
    }
  }
}

///
/// A logical model of what's being displayed on the LCD display.
/// Handles flashing and blinking, and delayed display (like when
/// clear-prefix is released).
///
class DisplayModel {
  final Model model;
  String _current;
  int _window = 0; // Number of digits scrolled off the right side
  bool _suspendWindow = false;
  final Observable<LcdContents> _lastShown;
  bool get ignoreUpdates => model.displayDisabled;

  DisplayModel(Model model)
      : this._p(model, model.displayMode.format(model.x, model));

  DisplayModel._p(this.model, String initial)
      : _current = initial,
        _lastShown =
            Observable(LcdContents.powerOn(initial, !model.isFloatMode));

  set current(String v) {
    _current = v;
    _suspendWindow = true;
  }

  set currentWithWindow(String v) {
    _current = v;
    _suspendWindow = false;
  }

  String get currentWithoutWindow => model.isFloatMode ? current : _current;

  String get current {
    if (model.isFloatMode) {
      if (_current.startsWith('-')) {
        return _current;
      } else {
        return ' $_current';
      }
    } else if (model.settings.windowEnabled) {
      final int maxWindow = ((_numDigits - 1) ~/ 8) * 8;
      if (_window > maxWindow) {
        _window = maxWindow;
        // If, for example, the base changed out from under us, like in
        // https://github.com/zathras/jrpn/issues/12
      }
      final int window = (_suspendWindow) ? 0 : _window;
      final int count = _numDigits;
      if (count <= 8) {
        return _current;
      }
      String radix = _current.substring(_current.length - 1);
      String r = _current.substring(0, _current.length - 2);

      final bool negative = r.startsWith('-');
      if (negative) {
        r = r.substring(1);
      }
      final List<int> digitPos = _allDigits
          .allMatches(r)
          .fold(List<int>.empty(growable: true), (List<int> l, RegExpMatch m) {
        l.add(m.start);
        return l;
      });
      assert(digitPos[0] == 0);
      final int end = 1 + digitPos[digitPos.length - 1 - window];
      final int start = digitPos[max(0, digitPos.length - 8 - window)];

      r = r.substring(start, end);
      final dot = (model.settings.euroComma ? ',' : '.');
      if (window < maxWindow) {
        // Dot before radix letter
        radix = dot + radix;
      }
      if (window > 0) {
        // Dot after radix letter
        radix = radix + dot;
      }
      if (negative && window >= maxWindow) {
        return '-$r $radix';
      } else {
        return '$r $radix';
      }
    } else {
      return _current;
    }
  }

  set window(int v) {
    if (v == _window) {
      return;
    }
    if (v != 0 && model.isFloatMode) {
      assert(false);
      return;
    }
    final int max = ((_numDigits - 1) ~/ 8) * 8;
    if (v < 0 || v > max) {
      throw CalculatorError(1);
    }
    _window = v;
    update();
  }

  int get window => _window;

  final RegExp _allDigits = RegExp('[a-f0-9]');

  int get _numDigits =>
      _allDigits.allMatches(_current.substring(0, _current.length - 1)).length;
  // Don't count the trailing 'b' for binary

  void addListener(void Function(LcdContents) f) => _lastShown.addObserver(f);

  void removeListener(void Function(LcdContents) f) =>
      _lastShown.removeObserver(f);

  void show(LcdContents newContents) {
    if (_lastShown.value._myTimer != newContents._myTimer) {
      if (ignoreUpdates) {
        return;
      }
      _lastShown.value._myTimer?.cancel();
    }
    _lastShown.value = newContents;
  }

  void update(
      {bool flash = false,
      BlinkMode blink = BlinkMode.none,
      bool disableWindow = false}) {
    if (ignoreUpdates) {
      return;
    }
    final LcdContents c = (blink == BlinkMode.justDigits)
        ? model._newLcdContentsJustDigits()
        : model._newLcdContents(disableWindow: disableWindow);
    if (blink.blinking || model.errorBlink) {
      bool on = true;
      final blank = LcdContents.blank();
      final Duration d;
      if (blink.blinking) {
        d = const Duration(milliseconds: 400);
      } else {
        d = const Duration(milliseconds: 200);
      }

      final t = Timer.periodic(d, (_) {
        on = !on;
        show(on ? c : blank);
      });
      c._myTimer = t;
      blank._myTimer = t;
      show(c);
    } else if (flash) {
      final t = Timer(const Duration(milliseconds: 40), () {
        show(c);
      });
      c._myTimer = t;
      show(LcdContents.blank().._myTimer = t);
    } else {
      c._myTimer = null;
      show(c);
    }
  }

  /// Display the value of X.
  /// disableWindow applies to the first display of X.  If there's a delayed
  /// value, it reverts to disableWindow being false.
  void displayX(
      {bool flash = true, bool delayed = false, bool disableWindow = false}) {
    final String newNumber = model.formatValue(model.x);
    if (delayed) {
      final initial = model._newLcdContents(disableWindow: disableWindow);
      currentWithWindow = newNumber;
      final delayed = model._newLcdContents(disableWindow: false);
      final t = Timer(const Duration(milliseconds: 1400), () {
        show(delayed);
      });
      delayed._myTimer = t;
      initial._myTimer = t;
      show(initial);
    } else {
      currentWithWindow = newNumber;
      update(flash: flash, disableWindow: disableWindow);
    }
  }
}

enum BlinkMode {
  none(false),
  all(true),
  justDigits(true); // Like "RuNNING"

  final bool blinking;
  const BlinkMode(this.blinking);
}

class TrigMode {
  final double scaleFactor;
  final String? label;

  const TrigMode._p(this.scaleFactor, this.label);

  static const deg = TrigMode._p(pi / 180, null);
  static const rad = TrigMode._p(1, 'RAD');
  static const grad = TrigMode._p(pi / 200, 'GRAD');

  String? toJson() => label;

  static TrigMode fromJson(Object? json) {
    for (final m in const {deg, rad, grad}) {
      if (json == m.label) {
        return m;
      }
    }
    assert(false);
    return deg;
  }
}

///
/// A memento of a calculator state, plus the keystrokes after the state
/// was captured.  It's meant to be a
/// tool to facilitate bug reports.
///
class DebugLog {
  late final Map<String, dynamic> _initialState;
  final List<int> _keys;
  // Horribly space-inefficient, but we don't expect more than a handful
  // of captured keystrokes.
  final Model _model;

  DebugLog(this._model) : _keys = List.empty(growable: true);

  DebugLog._p(this._initialState, this._keys, this._model);

  static DebugLog fromJson(Map<String, dynamic> json, Model model) {
    final initialState = json['initialState'] as Map<String, dynamic>;
    final keysD = json['keys'] as List<dynamic>;
    final keys = List.castFrom<dynamic, int>(keysD);
    return DebugLog._p(initialState, keys, model);
  }

  Map<String, Object> toJson({required bool comments}) {
    return <String, Object>{
      'initialState': _initialState,
      'keys': _keys,
    };
  }

  void initModelState() {
    assert(_model._debugLog == null);
    _initialState = _model.toJson(comments: false);
  }

  void addKey(ProgramOperation key) {
    if (_keys.length >= 1000) {
      // ridiculously big
      // So we reset it, so as to not fill up memory
      _model._debugLog = null;
      final replacement = DebugLog(_model)..initModelState();
      _model._debugLog = replacement;
      replacement.addKey(key);
    } else {
      _keys.add(key.debugLogId);
    }
  }
}
