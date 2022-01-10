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
part of 'model.dart';

/// The calculator's 406 nybble internal memory that holds registers and
/// programs.
class Memory<OT extends ProgramOperation> {
  final ByteData _storage = ByteData(406);
  //  We hold one nybble (4 bits) in each byte of _storage.  The program
  // isn't stored here, but we do zero out that part of storage when
  // program lines are added, to simulate the behavior of shared storage.
  late final ProgramMemory<OT> program;
  late final registers = Registers(this);

  final Model _model;

  Memory(this._model);

  int get _programNybbles => program.programBytes * 2;

  /// Called by our controller, which necessarily happens after the Model
  /// exists.
  void initializeSystem(OperationMap<OT> layout) {
    program = ProgramMemory<OT>(this, _storage, layout._operationTable);

    // We rely on our Controller to give us an OperationMap with the
    // layout information that tells us the row/column positions of the various
    // operations.  Those positions are how the 16C displays program
    // instructions, and it's also how we externalize them in our JSON
    // state file.
    //
    // We don't need to retain the layout, but we do need to ensure that
    // one is created.  The OperationMap constructor has the side effect
    // of initializing late final fields that we depend on.  Admittedly, this
    // is a little tricky - making initialization happen while keeping modules
    // decoupled sometimes is.
  }

  void reset() {
    for (int i = 0; i < _storage.lengthInBytes; i++) {
      _storage.setUint8(i, 0);
    }
    program.reset(zeroMemory: false);
    registers.resetI();
  }

  Map<String, Object> toJson({bool comments = false}) {
    final st = StringBuffer();
    for (int i = 0; i < _storage.lengthInBytes; i++) {
      st.write(_storage.getUint8(i).toRadixString(16));
    }
    final r = <String, Object>{
      'storage': st.toString(),
      'program': program,
      'I': registers._indexValue.toJson()
    };
    if (comments) {
      r['commentProgramListing'] = program.listing;
    }
    return r;
  }

  void decodeJson(Map<String, dynamic> json) {
    final sto = json['storage'] as String;
    for (int i = 0; i < _storage.lengthInBytes; i++) {
      _storage.setUint8(i, int.parse(sto.substring(i, i + 1), radix: 16));
    }
    // Must come after storage.  cf. ProgramMemory.decodeJson().
    program.decodeJson(json['program'] as Map<String, dynamic>);
    registers._indexValue =
        Value.fromJson(json['I'] as String, maxInternal: Registers._maxI);
  }
}

/// A helper for the index register, which is always stored as a 68 bit
/// quantity, regardless of the calculator mode.
class _NumStatus68 implements NumStatus {
  final Model _model; // For the sign mode

  _NumStatus68(this._model);

  @override
  bool cFlag = false;

  @override
  bool gFlag = false;

  @override
  int get wordSize => 68;

  @override
  final BigInt wordMask = (BigInt.one << 68) - BigInt.one;

  @override
  final BigInt signMask = (BigInt.one << 67);

  @override
  BigInt get maxInt => _model._integerSignMode.maxValue(this);

  @override
  BigInt get minInt => _model._integerSignMode.minValue(this);

  @override
  bool get isFloatMode => _model.isFloatMode;

  @override
  IntegerSignMode get integerSignMode => _model.integerSignMode;

  Value signExtendFrom(Value other) {
    if (!_model.signMode.doesSignExtension) {
      return other;
    }
    BigInt internal = other.internal;
    if (BigInt.zero == internal & _model.signMask) {
      return other;
    }
    BigInt bitToSet = _model.signMask << 1;
    while (bitToSet <= signMask) {
      internal = internal | bitToSet;
      bitToSet <<= 1;
    }
    return Value.fromInternal(internal);
  }
}

///
/// A representation of the available memory as registers.  "Available memory"
/// is what's left over of the 406 nybble data store after the program's
/// storage is deducted.
///
class Registers {
  final Memory _memory;
  // A helper for dealing with 68 bit values, like I
  final _NumStatus68 helper68;

  /// Value of the index register, I, always stored in 68 bits.
  Value _indexValue = Value.zero;

  Registers(this._memory) : helper68 = _NumStatus68(_memory._model);

  static final BigInt _maxI = BigInt.parse('fffffffffffffffff', radix: 16);
  // 16^17-1, that is, 2^68-1

  /// Index of the index register
  static int indexRegister = 33;

  /// Index to address via (i)
  static int indirectIndex = 32; // It comes earlier on the keyboard

  Model get _model => _memory._model;

  int get _nybblesPerRegister => (_model.wordSize + 3) ~/ 4;

  int get length =>
      (_memory._storage.lengthInBytes - _memory._programNybbles) ~/
      _nybblesPerRegister;

  static final BigInt _oneKmask = BigInt.from(0x3ff);

  Value operator [](int i) {
    assert(i >= 0 && i <= indexRegister);
    final Value result;
    if (i == indexRegister) {
      result = Value.fromInternal(_indexValue.internal & _model.wordMask);
    } else {
      if (i == indirectIndex) {
        i = _IasIndex;
      }
      if (i < 0 || i >= length) {
        throw CalculatorError(3);
      }
      final int npr = _nybblesPerRegister;
      int addr = _memory._storage.lengthInBytes - 1 - (i + 1) * npr;
      // Address of most significant nybble - 1
      BigInt value = BigInt.zero;
      for (int i = 0; i < npr; i++) {
        value = (value << 4) | BigInt.from(_memory._storage.getUint8(++addr));
      }
      result = Value.fromInternal(value);
    }
    if (_model.isFloatMode) {
      result.asDouble; // Throw exception if not valid float
    }
    return result;
  }

  static final BigInt _low4 = BigInt.from(0xf);

  void operator []=(int i, Value v) {
    assert(i >= 0 && i <= indexRegister);
    if (i == indexRegister) {
      _indexValue = helper68.signExtendFrom(v);
      return;
    } else if (i == indirectIndex) {
      i = _IasIndex;
    }
    if (i < 0 || i >= length) {
      throw CalculatorError(3);
    }
    final int npr = _nybblesPerRegister;
    BigInt value = v.internal;
    int addr = _memory._storage.lengthInBytes - 1 - i * npr;
    // Address of least significant nybble
    for (int i = 0; i < npr; i++) {
      _memory._storage.setUint8(addr--, (value & _low4).toInt());
      value >>= 4;
    }
    _model._needsSave = true;
  }

  /// Calculate the value of the I register for use as an index.  If that
  /// value is too big to be an index, then any int that is too big will do,
  /// since we'll just end up generating a CalculatorError anyway.
  int get _IasIndex {
    if (_model.isFloatMode) {
      Value masked = Value.fromInternal(_indexValue.internal & _model.wordMask);
      double d = masked.asDouble.abs();
      if (d > 1000) {
        return 1000; // close enough to infinity
      } else {
        return d.floor();
      }
    } else {
      BigInt bi = _model._integerSignMode.toBigInt(_indexValue, helper68).abs();
      if (bi > _oneKmask) {
        return 1024; // close enough to infinity
      } else {
        return bi.toInt().abs();
      }
    }
  }

  void resetI() {
    _indexValue = Value.zero;
  }

  void clear() {
    resetI();
    final maxMem = _memory._storage.lengthInBytes;
    for (int addr = _memory._programNybbles; addr < maxMem; addr++) {
      _memory._storage.setUint8(addr, 0);
    }
  }

  bool isZeroI(Value v) => _model.signMode.isZero(helper68, v);

  /// Gives value after increment
  Value incrementI(int by) {
    return _indexValue = _model.signMode.increment(helper68, _indexValue, by);
  }
}

///
/// A representation of the calculator's 406 nybble data store as a list
/// of program instructions.  ProgramMemory takes over space from register
/// storage as needed.  We also keep the return stack for GSB instructions
/// here, and the current program line.
///
class ProgramMemory<OT extends ProgramOperation> {
  final Memory _memory;

  /// Indexed by opCode
  final List<OT> _operationTable;

  int _lines = 0;

  final List<int> _returnStack = List.filled(4, 0);
  int _returnStackPos = -1;

  /// Current line (editing and/or execution)
  int _currentLine = 0;

  /// This is a testing hook.  In normal operation, it's always null.
  ProgramListener programListener = ProgramListener();

  ProgramMemory(this._memory, this._registerStorage, this._operationTable);

  final ByteData _registerStorage;

  int get programBytes => ((_lines + 6) ~/ 7) * 7;

  /// Number of lines in the program
  int get lines => _lines;

  int get currentLine => _currentLine;

  int get bytesToNextAllocation =>
      (_registerStorage.lengthInBytes ~/ 2 - _lines) % 7;

  set currentLine(int v) {
    if (v < 0 || v > lines) {
      throw CalculatorError(4);
    }
    _currentLine = v;
  }

  /// Insert a new instruction, and increment currentLine to refer to it.
  void insert(final ProgramInstruction<OT> instruction) {
    if (lines >= _registerStorage.lengthInBytes ~/ 2) {
      throw CalculatorError(4);
    }
    assert(_currentLine >= 0 && _currentLine <= _lines);
    assert(instruction.argValue >= 0 &&
        instruction.argValue <= instruction.op.maxArg);
    int addr = _currentLine * 2; // stored as nybbles
    for (int a = _lines * 2 - 1; a >= addr; a--) {
      _registerStorage.setUint8(a + 2, _registerStorage.getUint8(a));
    }
    final int opCode = instruction.op._opCode + instruction.argValue;
    assert(opCode >= 0 && opCode <= 0xff);
    _registerStorage.setUint8(addr++, opCode >> 4);
    _registerStorage.setUint8(addr++, opCode & 0xf);
    _lines++;
    _currentLine++; // Where we just inserted the instruction

    _memory._model._needsSave = true;
  }

  void deleteCurrent() {
    assert(_lines > 0 && _currentLine > 0);
    _lines--;
    _currentLine--;
    int addr = _currentLine * 2; // The nybble after the new current instruction
    while (addr < _lines * 2) {
      _registerStorage.setUint8(addr, _registerStorage.getUint8(addr + 2));
      addr++;
    }
    _registerStorage.setUint8(addr++, 0);
    _registerStorage.setUint8(addr, 0);

    _memory._model._needsSave = true;
  }

  /// line counts from 1
  ProgramInstruction<OT> operator [](final int line) {
    final int opCode = opcodeAt(line);
    final OT op = _operationTable[opCode];
    // throws an exception on an illegal opCode, which is what we want.
    final int arg = opCode - op._opCode;
    return ProgramInstruction<OT>(op, arg);
    // We're not storing the instructions as nybbles and creating instructions
    // as-needed to save memory.  It's the easiest way of implementing it,
    // given that we want to store the program in a form that is faithful
    // to the original 16C.  The extra time we spend converting back and
    // forth is, of course, irrelevant.
  }

  int opcodeAt(final int line) {
    assert(line > 0 && line <= _lines);
    final int a = (line - 1) * 2;
    return (_registerStorage.getUint8(a) << 4) +
        _registerStorage.getUint8(a + 1);
  }

  ProgramInstruction<OT> getCurrent() => this[currentLine];

  void reset({bool zeroMemory = true}) {
    if (zeroMemory) {
      for (int i = 0; i < _lines * 2; i++) {
        _registerStorage.setUint8(i, 0);
      }
    }
    _lines = 0;
    _currentLine = 0;
    resetReturnStack();
  }

  Map<String, dynamic> toJson() => <String, Object>{
        'lines': _lines,
        'currentLine': _currentLine,
        'returnStack': _returnStack,
        'returnStackPos': _returnStackPos
      };

  /// Must be called after the register storage has been read in, so any
  /// stray data will be propely zeroed out.
  void decodeJson(Map<String, dynamic> json) {
    int n = (json['lines'] as num).toInt();
    if (n < 0 || n > _registerStorage.lengthInBytes ~/ 2) {
      throw ArgumentError('$n:  Illegal number of lines');
    }
    _lines = n;
    // Check for illegal instructions
    try {
      for (_currentLine = 1; _currentLine <= _lines; _currentLine++) {
        getCurrent();
      }
      _currentLine = 0;
    } catch (e) {
      _lines = 0;
      _currentLine = 0;
      rethrow;
    }
    n = (json['currentLine'] as num).toInt();
    if (n < 0 || n > _lines) {
      throw ArgumentError('$n:  Illegal line number');
    }
    _currentLine = n;

    final returnStack = (json['returnStack'] as List<dynamic>?);
    if (returnStack != null && returnStack.length == _returnStack.length) {
      for (int i = 0; i < returnStack.length; i++) {
        _returnStack[i] = returnStack[i] as int;
      }
    }
    final returnStackPos = (json['returnStackPos'] as num?);
    if (returnStackPos != null) {
      _returnStackPos = returnStackPos.toInt();
    }
  }

  List<String> get listing {
    final r = List<String>.empty(growable: true);
    for (int i = 1; i <= lines; i++) {
      String line = i.toString().padLeft(3, '0');
      String opc = opcodeAt(i).toRadixString(16).padLeft(2, '0');
      final ProgramInstruction<OT> pi = this[i];
      String semiHuman = this[i].programDisplay.padLeft(9);
      String human = pi.programListing;
      r.add('$line --$semiHuman    0x$opc  $human');
    }
    return r;
  }

  void stepCurrentLine(int sign) {
    int line = currentLine + sign;
    if (line < 0) {
      currentLine = lines;
    } else if (line > lines) {
      currentLine = 0;
    } else {
      currentLine = line;
    }
  }

  void displayCurrent({bool flash = false, bool delayed = false}) {
    final display = _memory._model.display;
    final String newText;
    if (currentLine == 0) {
      newText = '000-      ';
    } else {
      String ls = currentLine.toRadixString(10).padLeft(3, '0');
      String disp = getCurrent().programDisplay;
      newText = '$ls-$disp';
    }
    if (delayed) {
      final initial = _memory._model._newLcdContents();
      display.current = newText;
      final delayed = _memory._model._newLcdContents();
      final t = Timer(Duration(milliseconds: 1400), () {
        display.show(delayed);
      });
      delayed._myTimer = t;
      initial._myTimer = t;
      display.show(initial);
    } else {
      display.current = newText;
      display.update(flash: flash);
    }
  }

  void popReturnStack() {
    if (_returnStackPos > 0) {
      currentLine = _returnStack[--_returnStackPos];
    } else {
      _returnStackPos = -1;
      currentLine = 0;
    }
  }

  void gosub(int label) {
    if (_returnStackPos >= _returnStack.length) {
      throw CalculatorError(5);
    }
    final returnTo = currentLine;
    goto(label);
    if (returnStackUnderflow) {
      // Keyboard entry of GSB to start program
      _returnStackPos++;
    } else {
      _returnStack[_returnStackPos++] = returnTo;
    }
  }

  static final BigInt _fifteen = BigInt.from(15);

  void goto(int label) {
    if (label > 15) {
      // I or (i)
      Value v = _memory.registers[label + 16];
      if (_memory._model.isFloatMode) {
        double fv = v.asDouble;
        if (fv < 0 || fv >= 16) {
          throw CalculatorError(4);
        }
        label = fv.floor();
        if (label > 16 || label < 0) {
          // This should be impossible, but I'm not 100% certain of double
          // semantic, e.g. on JavaScript.
          throw CalculatorError(4);
        }
      } else {
        BigInt iv = v.internal;
        if (iv < BigInt.zero || iv > _fifteen) {
          throw CalculatorError(4);
        }
        label = iv.toInt();
      }
    }
    int wanted = OperationMap._instance!.lbl._opCode + label;
    // We might be at the label, so we start at 0.  Also, remember that
    // line 0 has the phantom return instruction, so we have to
    // iterate over lines+1 "lines".
    if (lines != 0) {
      for (int i = 0; i <= lines; i++) {
        int line = (currentLine + i) % lines;
        if (line == 0) {
          line = lines;
        }
        if (opcodeAt(line) == wanted) {
          currentLine = line;
          return;
        }
      }
    }
    throw CalculatorError(4);
  }

  void resetReturnStack() {
    _returnStackPos = -1;
    assert(returnStackUnderflow);
  }

  bool get returnStackUnderflow => _returnStackPos < 0;

  /// A RunStop keypress can resume a program, in which case the return stack
  /// shoould be left undisturbed.  It can also start a "new" program run,
  /// so we need to be sure the return stack isn't in underflow
  void handleRunStopKepyress() {
    if (returnStackUnderflow) {
      _returnStackPos = 0;
    }
  }

  /// Increment the current line, up to a max of lines, wrapping to 0.
  /// To be clear, there are lines+1 possible values.
  ///
  /// Note that the branching instructions can cause the program to increment
  /// past the phantom RTN instruction at the end of memory, wrapping back
  /// to line 1.  This is intentional, and mirrors the behavior I observed
  /// on my 15C.
  void incrementCurrentLine() => currentLine = (currentLine + 1) % (lines + 1);

  void doNextIf(bool condition) {
    if (!condition) {
      incrementCurrentLine();
    }
  }
}

///
/// The model's view of an operation.
///
abstract class ProgramOperation {
  late final String _programDisplay;
  late final int _opCode;

  /// 0 if this operation doesn't take an argument
  int get maxArg;
  String get name;

  static const _invalidOpCodeStart = -1;
  // Invalid op codes are negative, but still distinct.  That allows them to
  // be used in the capture of a debug key log.

  String get programDisplay => _programDisplay;

  /// Give the numeric value of a number key.
  /// cf. tests.dart, SelfTests.testNumbers().
  int? get numericValue => (_opCode >= 0 && _opCode < 16) ? _opCode : null;

  @override
  String toString() => 'ProgramOperation(_programDisplay)';
}

///
/// The model's view of a key on the keyboard.  The model needs to know where
/// [ProgramOperation]s are on the portrait layout of the keyboard, because
/// they are displayed on the LCD display as row-column numbers.
///
class Key<OT extends ProgramOperation> {
  final OT unshifted;
  final OT fShifted;
  final OT gShifted;

  Key(this.unshifted, this.fShifted, this.gShifted);
}

///
/// An instruction in a program, consisting of a [ProgramOperation] and,
/// sometimes, an argument value.
///
class ProgramInstruction<OT extends ProgramOperation> {
  OT op;

  /// 0 if no argument
  int argValue;

  ProgramInstruction(this.op, this.argValue);

  final _noWidth = RegExp('[,.]');

  String _rightJustify(String s, int len) {
    int nw = _noWidth.allMatches(s).length;
    return s.padLeft(6 + nw);
  }

  /// How this is displayed in the LCD
  String get programDisplay {
    if (op.maxArg > 0) {
      final String as;
      if (argValue < 16) {
        if (argValue == 10 && op.maxArg == 10) {
          as = '48';
          // Special case:  f-FLOAT is the only key that takes arguments
          // from 0 to 10, with 10 being input as ".".  It means "scientific
          // notation," so semantically it's not really "A", and the 16C
          // displays it is 48 (which is ".").  I guess the 16C's behavior
          // makes sense!
        } else {
          as = ' ${argValue.toRadixString(16)}';
        }
      } else if (argIsParenI) {
        as = '31';
      } else if (argIsI) {
        as = '32';
      } else {
        as = ' .${(argValue - 16).toRadixString(16)}';
      }
      return _rightJustify('${op.programDisplay}$as', 6);
    } else {
      return _rightJustify(op.programDisplay, 6);
    }
  }

  /// How this is displayed in a program listing
  String get programListing {
    final String as;
    if (op.maxArg > 0) {
      if (argIsParenI) {
        as = ' (i)';
      } else if (argIsI) {
        as = ' I';
      } else if (argValue == 10 && op.maxArg == 10) {
        as = ' .';
        // See above, under programDisplay.  "f FLOAT ." is better than
        // "f FLOAT a," under similar reasoning.
      } else {
        as = ' ${argValue.toRadixString(16)}';
      }
    } else {
      as = '';
    }
    return '${op.name}$as';
  }

  bool get _hasI => op.maxArg > 10;

  /// (i)
  bool get argIsParenI =>
      _hasI && op.maxArg - argValue == 33 - Registers.indirectIndex;

  /// I
  bool get argIsI =>
      _hasI && op.maxArg - argValue == 33 - Registers.indexRegister;

  @override
  String toString() => 'ProgramInstruction($programListing)';
}

///
/// A representation of all of the operations.  This is used by the model
/// to assign op codes and labels to [ProgramOperation]s.
///
class OperationMap<OT extends ProgramOperation> {
  final List<List<Key<OT>?>> keys;
  final List<OT> numbers;
  final List<OT> special;
  final Map<OT, ProgramInstruction> shortcuts;

  /// Maps from opCode to ProgramOperation.  Each operation occurs in the
  /// table 1+maxArg times.
  late final List<OT> _operationTable;
  // (i) means "RCL (i)", and I means "RCL I".
  int _nextOpCode = 0;

  final List<OT> inNumericOrder = List.empty(growable: true);

  final OT lbl; // The label instruction, for GTO and GSB implementation

  OperationMap._internal(
      this.keys, this.numbers, this.special, this.shortcuts, this.lbl);

  static OperationMap? _instance;

  factory OperationMap(
      {required List<List<Key<OT>?>> keys,
      required List<OT> numbers,
      required List<OT> special,
      required Map<OT, ProgramInstruction> shortcuts,
      required OT lbl}) {
    final instance = _instance;
    if (instance == null) {
      final i = _instance =
          OperationMap<OT>._internal(keys, numbers, special, shortcuts, lbl);
      i._initializeProgramDisplay();
      i._initializeOperationTable();
      return i;
    } else {
      assert(instance.keys == keys);
      assert(instance.numbers == numbers);
      assert(instance.special == special);
      assert(instance.lbl == lbl);
      return instance as OperationMap<OT>;
    }
  }

  void _assignOpCode(OT o) {
    o._opCode = _nextOpCode;
    _nextOpCode += 1 + o.maxArg;
    inNumericOrder.add(o);
  }

  void _initializeOperationTable() {
    _operationTable = List.empty(growable: true);
    for (final OT o in inNumericOrder) {
      assert(o.maxArg >= 0);
      for (int i = 0; i <= o.maxArg; i++) {
        _operationTable.add(o);
      }
    }
    assert(_operationTable.length == _nextOpCode);
  }

  void _initializeProgramDisplay() {
    assert(inNumericOrder.isEmpty);
    final visited = <OT>{};
    for (int i = 0; i < special.length; i++) {
      final o = special[i];
      final ok = visited.add(o);
      assert(ok);
      o._programDisplay = '';
      o._opCode = ProgramOperation._invalidOpCodeStart - i;
    }
    for (final k in shortcuts.keys) {
      assert(!visited.contains(k));
      visited.add(k);
      // We will visit k, at the end, when the thing to which it's a
      // shortcut has been initialized.
    }
    for (int i = 0; i < numbers.length; i++) {
      final o = numbers[i];
      final ok = visited.add(o);
      assert(ok);
      o._programDisplay = ' ${i.toRadixString(16)}';
      _assignOpCode(o);
    }
    for (int row = 0; row < keys.length; row++) {
      final keyRow = keys[row];
      for (int col = 0; col < keyRow.length; col++) {
        final Key<OT>? key = keyRow[col];
        if (key == null) {
          continue;
        }
        final String rcText;
        if (visited.contains(key.unshifted)) {
          if (key.unshifted._programDisplay != '') {
            // A number key
            assert(key.unshifted.maxArg == 0);
            rcText = '${key.unshifted._programDisplay}';
          } else {
            rcText = '${row + 1}${(col + 1) % 10}';
          }
        } else {
          rcText = '${row + 1}${(col + 1) % 10}';
          visited.add(key.unshifted);
          if (key.unshifted.maxArg == 0) {
            key.unshifted._programDisplay = rcText;
          } else {
            key.unshifted._programDisplay = '$rcText ';
          }
          _assignOpCode(key.unshifted);
        }
        if (!visited.contains(key.fShifted)) {
          visited.add(key.fShifted);
          if (key.fShifted.maxArg == 0) {
            key.fShifted._programDisplay = '42 $rcText';
          } else {
            key.fShifted._programDisplay = '42,$rcText,';
          }
          _assignOpCode(key.fShifted);
        }
        if (!visited.contains(key.gShifted)) {
          visited.add(key.gShifted);
          if (key.gShifted.maxArg == 0) {
            key.gShifted._programDisplay = '43 $rcText';
          } else {
            key.gShifted._programDisplay = '43,$rcText,';
          }
          _assignOpCode(key.gShifted);
        }
      }
    }
    shortcuts.forEach((k, v) {
      assert(v.argValue >= 0 && v.argValue <= v.op.maxArg);
      k._opCode = v.op._opCode + v.argValue;
      k._programDisplay = v.op._programDisplay;
    });
    assert(_nextOpCode <= 256);
  }
}

///
///  A listener that receives callbacks when a program delivers results
///  to the user.  This is used for testing.
///
class ProgramListener {
  /// Called when the program finishes normally, via a RTN instruction.
  void onDone() {}

  /// Called when an R/S instruction stops the program (usually in the
  /// middle, to deliver intermediate results).
  void onRS() {}

  /// Called when a PSE instruction momentarily pauses the program to
  /// display results.
  void onPause() {}

  /// Called when the program has a CalculatorError
  void onError(CalculatorError err) {}

  /// Called when the program is stopped due to a keypress
  void onStop() {}

  /// A future that completes when we should resume from a pause instruction,
  /// after [onPause()] is called.
  Future<void> resumeFromPause() => Future.delayed(Duration(seconds: 1));
}
