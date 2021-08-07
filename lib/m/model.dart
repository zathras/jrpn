/*
MIT License

Copyright (c) 2021 William Foote

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
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
import 'dart:typed_data';
import 'dart:io' show Platform;

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart'
    show SystemChrome, DeviceOrientation, SystemUiOverlay;
import 'package:pedantic/pedantic.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'values.dart';
part 'display_mode.dart';
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
  final bool cFlag;
  final bool gFlag;
  final bool prgmFlag;
  final bool rightJustify;
  final bool windowEnabled;
  final bool euroComma;
  final bool hideComplement;
  final int? wordSize;

  Timer? _myTimer;

  LcdContents(
      {required this.mainText,
      required this.shift,
      required this.sign,
      required this.bits,
      required this.cFlag,
      required this.gFlag,
      required this.prgmFlag,
      required this.rightJustify,
      required this.windowEnabled,
      required this.euroComma,
      required this.hideComplement,
      required this.wordSize,
      this.extraShift})
      : blank = false;

  LcdContents.blank({Timer? timer})
      : blank = true,
        mainText = '',
        shift = ShiftKey.none,
        sign = SignMode.twosComplement,
        bits = 0,
        cFlag = false,
        gFlag = false,
        prgmFlag = false,
        rightJustify = false,
        windowEnabled = false,
        euroComma = false,
        hideComplement = false,
        wordSize = null,
        _myTimer = timer,
        extraShift = null;

  LcdContents.powerOn()
      : blank = false,
        mainText = '        0 h',
        shift = ShiftKey.none,
        sign = SignMode.twosComplement,
        bits = 0,
        cFlag = false,
        gFlag = false,
        prgmFlag = false,
        rightJustify = false,
        windowEnabled = false,
        euroComma = false,
        hideComplement = false,
        wordSize = null,
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
  final int num;

  CalculatorError(this.num);

  @override
  String toString() => 'CalculatorError($num)';
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
  OrientationSetting _orientation = OrientationSetting.auto;
  bool _systemOverlaysDisabled = false;

  Settings(this._model) {
    menuEnabled.addObserver((_) => _model._needsSave = true);
    showAccelerators.addObserver((_) => _model._needsSave = true);
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
    _model._needsSave = true;
  }

  ///
  /// Should the window functions be enabled?  If not, we just shrink the
  /// digits when a number is too big.
  ///
  bool get windowEnabled => _windowEnabled;
  set windowEnabled(bool v) {
    _windowEnabled = v;
    _model._needsSave = true;
  }

  ///
  /// Should we show numbers Euro-style, with commas instead of periods
  /// and vice-versa?
  ///
  bool get euroComma => _euroComma;
  set euroComma(bool v) {
    _euroComma = v;
    _model._needsSave = true;
  }

  ///
  /// Should we hide the complement annunciator?
  ///
  bool get hideComplement => _hideComplement;
  set hideComplement(bool v) {
    _hideComplement = v;
    _model._needsSave = true;
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
    _model._needsSave = true;
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
    _model._needsSave = true;
  }

  void _setPlatformOverlays() {
    if (systemOverlaysDisabled) {
      SystemChrome.setEnabledSystemUIOverlays([]);
    } else {
      SystemChrome.setEnabledSystemUIOverlays(SystemUiOverlay.values);
    }
  }

  OrientationSetting get orientation => _orientation;

  set orientation(OrientationSetting v) {
    if (!isMobilePlatform) {
      return;
    }
    _orientation = v;
    _setPlatformOrientation();
    _model._needsSave = true;
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
/// structure.
///
class Model<OT extends ProgramOperation> implements NumStatus {
  late final display = DisplayModel(this);
  late final settings = Settings(this);
  bool _needsSave = false;
  ShiftKey _shift = ShiftKey.none;
  int _wordSize = 16;
  BigInt _wordMask = BigInt.from(0xffff);
  BigInt _signMask = BigInt.from(0x8000);
  DisplayMode _displayMode = DisplayMode.hex;
  IntegerSignMode _integerSignMode = SignMode.twosComplement;

  /// Not used, but we retain any comments found in the JSON file
  /// so we can write them back out.
  dynamic _comments;

  bool isRunningProgram = false;
  @override
  BigInt get maxInt => _integerSignMode.maxValue(this);
  @override
  BigInt get minInt => _integerSignMode.minValue(this);
  @override
  bool get isFloatMode => displayMode.isFloatMode;
  DoubleWordStatus? _doubleWordStatus; // for double divide, multiply
  late final Memory<OT> memory = Memory<OT>(this);
  final Observable<bool> onIsPressed = Observable(false);
  bool prgmFlag = false;
  DebugLog? _debugLog;
  static const int _jsonVersion = 1;

  final List<Value> _stack = List<Value>.filled(4, Value.zero, growable: false);
  Value get x => _stack[0];

  /// Get x as a signed BigInt
  BigInt get xI => _integerSignMode.toBigInt(_stack[0], this);

  /// Get x as a Dart double
  double get xF => _stack[0].asDouble;

  set x(Value v) {
    _stack[0] = v;
    _needsSave = true;
    display.window = 0;
  }

  /// Set x from a signed BigInt
  set xI(BigInt v) => x = _integerSignMode.fromBigInt(v, this);

  /// Set x from a Dart double
  set xF(double v) => x = Value.fromDouble(v);

  /// Pop the stack and set X, setting lastX
  // ignore: avoid_setters_without_getters
  set popSetResultX(Value v) {
    _popStackSetLastX();
    x = v;
    _needsSave = true;
  }

  /// Pop the stack and set X from a signed BigInt, setting lastX
  // ignore: avoid_setters_without_getters
  set popSetResultXI(BigInt v) {
    popSetResultX = _integerSignMode.fromBigInt(v, this);
  }

  /// Pop the stack and set X from a Dart double, setting lastX
  // ignore: avoid_setters_without_getters
  set popSetResultXF(double v) => popSetResultX = Value.fromDouble(v);

  /// Set a result in X, which saves the old X value in lastX
  // ignore: avoid_setters_without_getters
  set resultX(Value v) {
    lastX = x;
    x = v;
    _needsSave = true;
  }

  // ignore: avoid_setters_without_getters
  set resultXI(BigInt v) => resultX = _integerSignMode.fromBigInt(v, this);
  // ignore: avoid_setters_without_getters
  set resultXF(double v) => resultX = Value.fromDouble(v);

  Value get y => _stack[1];
  BigInt get yI => _integerSignMode.toBigInt(_stack[1], this);
  double get yF => _stack[1].asDouble;
  set y(Value v) {
    _stack[1] = v;
    _needsSave = true;
  }

  set yI(BigInt v) => y = _integerSignMode.fromBigInt(v, this);
  set yF(double v) => y = Value.fromDouble(v);
  Value get z => _stack[2];
  void setYZT(Value v) {
    _stack[3] = _stack[2] = _stack[1] = v;
    _needsSave = true;
  }

  Value _lastX = Value.zero;
  Value get lastX => _lastX;
  set lastX(Value v) {
    _lastX = v;
    _needsSave = true;
  }

  Value getStackByIndex(int i) => _stack[i];

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
    _needsSave = true;
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
    _needsSave = true;
  }

  ProgramMemory<OT> get program => memory.program;

  SignMode get signMode => displayMode.signMode(_integerSignMode);
  set integerSignMode(IntegerSignMode v) {
    _integerSignMode = v;
    display.displayX();
    _needsSave = true;
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

  final List<bool> _flags = List<bool>.filled(6, false, growable: false);

  // ignore: avoid_positional_boolean_parameters
  void setFlag(int i, bool v) {
    if (i >= _flags.length) {
      throw CalculatorError(1);
    }
    _flags[i] = v;
    display.update();
    _needsSave = true;
  }

  bool getFlag(int i) {
    if (i >= _flags.length) {
      throw CalculatorError(1);
    }
    return _flags[i];
  }

  bool get displayLeadingZeros => _flags[3];
  @override
  bool get cFlag => _flags[4];
  @override
  set cFlag(bool v) => setFlag(4, v);
  @override
  bool get gFlag => _flags[5];
  @override
  set gFlag(bool v) => setFlag(5, v);

  void _popStackSetLastX() {
    lastX = _stack[0];
    popStack();
    _needsSave = true;
  }

  void popStack() {
    _stack[0] = _stack[1];
    _stack[1] = _stack[2];
    _stack[2] = _stack[3];
    display.window = 0;
    _needsSave = true;
  }

  void swapXY() {
    Value t = _stack[0];
    _stack[0] = _stack[1];
    _stack[1] = t;
    display.window = 0;
    _needsSave = true;
  }

  /// "lift" stack, after which one can write to x
  void pushStack() {
    _stack[3] = _stack[2];
    _stack[2] = _stack[1];
    _stack[1] = _stack[0];
    _needsSave = true;
  }

  /// the R<down arrow> key
  void rotateStackDown() {
    Value t = _stack[0];
    _stack[0] = _stack[1];
    _stack[1] = _stack[2];
    _stack[2] = _stack[3];
    _stack[3] = t;
    display.window = 0;
    _needsSave = true;
  }

  /// The R<up arrow> key
  void rotateStackUp() {
    Value t = _stack[3];
    _stack[3] = _stack[2];
    _stack[2] = _stack[1];
    _stack[1] = _stack[0];
    _stack[0] = t;
    display.window = 0;
    _needsSave = true;
  }

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
        gFlag: gFlag,
        prgmFlag: prgmFlag,
        rightJustify: displayMode.rightJustify,
        windowEnabled: disableWindow ? false : settings.windowEnabled,
        euroComma: settings.euroComma,
        wordSize: settings.showWordSize ? wordSize : null,
        hideComplement: settings.hideComplement);
  }

  ///
  /// Negate the value in x, according to the current sign mode.
  ///
  void negateX() {
    x = signMode.negate(x, this);
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
    _needsSave = true;
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
  Map<String, dynamic> toJson({bool comments = false}) {
    final r = <String, dynamic>{};
    if (comments) {
      r['comments'] = _comments;
    }
    r['version'] = _jsonVersion;
    r['settings'] = settings.toJson(comments: comments);
    r['displayMode'] = _displayMode.toJson();
    r['integerSignMode'] = _integerSignMode.toJson();
    r['wordSize'] = _wordSize;
    r['stack'] = _stack.map((v) => v.toJson()).toList();
    r['lastX'] = _lastX.toJson();
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
    _comments = json['comments'];
    settings.decodeJson(json['settings'] as Map<String, dynamic>);
    displayMode = DisplayMode.fromJson(json['displayMode']!);
    integerSignMode =
        IntegerSignMode.fromJson(json['integerSignMode'] as String);
    wordSize = json['wordSize'] as int;
    int i = 0;
    for (final v in json['stack'] as List<dynamic>) {
      _stack[i++] = Value.fromJson(v as String);
    }
    _lastX = Value.fromJson(json['lastX'] as String);
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
    _needsSave = needsSave;
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
    if (!_needsSave) {
      return;
    }
    _needsSave = false;
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
          ZLibDecoder().decodeBytes(base64Url.decoder.convert(qs)));
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
  String _current = '0 h';
  int _window = 0; // Number of digits scrolled off the right side
  bool _suspendWindow = false;
  final Observable<LcdContents> _lastShown = Observable(LcdContents.powerOn());
  bool get ignoreUpdates => model.isRunningProgram;

  DisplayModel(this.model);

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
      {bool flash = false, bool blink = false, bool disableWindow = false}) {
    if (ignoreUpdates) {
      return;
    }
    final LcdContents c = model._newLcdContents(disableWindow: disableWindow);
    if (flash) {
      final t = Timer(Duration(milliseconds: 40), () {
        show(c);
      });
      c._myTimer = t;
      show(LcdContents.blank().._myTimer = t);
    } else if (blink) {
      bool on = true;
      final blank = LcdContents.blank();
      final t = Timer.periodic(Duration(milliseconds: 400), (_) {
        on = !on;
        show(on ? c : blank);
      });
      c._myTimer = t;
      blank._myTimer = t;
      show(c);
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
    final newNumber = model.displayMode.format(model.x, model);
    if (delayed) {
      final initial = model._newLcdContents(disableWindow: disableWindow);
      currentWithWindow = newNumber;
      final delayed = model._newLcdContents(disableWindow: false);
      final t = Timer(Duration(milliseconds: 1400), () {
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
      _keys.add(key._opCode);
    }
  }
}