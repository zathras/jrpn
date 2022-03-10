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

typedef OpInitFunction = void Function(ArgDone resolved,
    {required ProgramOperation? shift,
    required bool argDot,
    required ProgramOperation? arg,
    required bool userMode});

abstract class Arg {
  static late final List<ProgramOperation> kDigits;
  static late final ProgramOperation kI;
  static late final ProgramOperation kParenI;
  static late final ProgramOperation kDot;
  static late final ProgramOperation fShift;
  static late final ProgramOperation gShift;
  static late final Map<ProgramOperation, ProgramOperation> registerISynonyms;

  static bool assertStaticInitialized() {
    // Assert that these values are initialized, by using them in a logical
    // expression.  The expression itself is pretty meaningless.
    assert(kDigits[0] != kI &&
        kParenI != kDot &&
        fShift != gShift &&
        registerISynonyms[kI] == null);
    return true;
  }

  Arg? matches(ProgramOperation key, bool userMode);

  void init(int registerBase,
      {required OpInitFunction f,
      required ProgramOperation? shift,
      required bool argDot,
      required ProgramOperation? arg,
      required bool userMode});
}

class DigitArg extends Arg {
  final int max;
  final void Function(Model, int) calc;

  late final List<ArgDone> _next;
  late final KeyArg? _nextOnDot;

  DigitArg({required this.max, required this.calc});

  @override
  Arg? matches(ProgramOperation key, bool userMode) {
    for (int i = 0; i < _next.length; i++) {
      if (key == Arg.kDigits[i]) {
        return _next[i];
      }
    }
    if (key == Arg.kDot) {
      return _nextOnDot;
    } else {
      return null;
    }
  }

  @override
  void init(int registerBase,
      {required OpInitFunction f,
      required ProgramOperation? shift,
      required bool argDot,
      required ProgramOperation? arg,
      required bool userMode}) {
    if (arg != null) {
      // Move arg over to shift, e.g. for STO + 7
      assert(shift == null);
      shift = arg;
      arg = null;
    }
    _next = List.generate(min(max + 1, registerBase), (i) {
      final a = ArgDone((m) => calc(m, i)); // Function currying, baby
      a.init(registerBase,
          f: f,
          shift: shift,
          argDot: argDot,
          arg: Arg.kDigits[i],
          userMode: userMode);
      return a;
    }, growable: false);
    if (max < registerBase) {
      _nextOnDot = null;
    } else {
      assert(!argDot, 'max: $max');
      final ka = _nextOnDot = KeyArg(
          key: Arg.kDot,
          child: DigitArg(
              max: max - registerBase,
              calc: (m, i) => calc(m, i + registerBase)));
      // Skip over ka, straight to its child:
      ka.child.init(registerBase,
          f: f, shift: shift, argDot: true, arg: arg, userMode: userMode);
      // argName: '.', userMode: userMode));
    }
  }

  void visitChildren(void Function(int, ArgDone) f, [int offset = 0]) {
    int n = 0;
    for (final c in _next) {
      f(offset + n++, c);
    }
    final nd = _nextOnDot;
    if (nd != null) {
      final da = nd.child as DigitArg;
      da.visitChildren(f, n);
    }
  }
}

class KeyArg extends Arg {
  final ProgramOperation key;
  final Arg child;

  KeyArg({required this.key, required this.child});

  @override
  Arg? matches(ProgramOperation key, bool userMode) {
    if (key == this.key) {
      return child;
    }
    return null;
  }

  @override
  void init(int registerBase,
      {required OpInitFunction f,
      required ProgramOperation? shift,
      required bool argDot,
      required ProgramOperation? arg,
      required bool userMode}) {
    if (arg != null) {
      // Move arg over to shift, e.g. for STO + (i)
      assert(shift == null);
      shift = arg;
      arg = null;
    }
    assert(!argDot);
    child.init(registerBase,
        f: f, shift: shift, arg: key, argDot: argDot, userMode: userMode);
  }
}

class KeysArg extends Arg {
  final Iterable<ProgramOperation> keys;
  final Arg Function(int) generator;
  final Map<ProgramOperation, ProgramOperation> synonyms;
  late final List<Arg> _next;

  KeysArg(
      {required this.keys, required this.generator, this.synonyms = const {}});

  @override
  Arg? matches(ProgramOperation key, bool userMode) {
    key = synonyms[key] ?? key;
    int i = 0;
    for (final k in keys) {
      if (k == key) {
        return _next[i];
      }
      i++;
    }
    return null;
  }

  @override
  void init(int registerBase,
      {required OpInitFunction f,
      required ProgramOperation? shift,
      required bool argDot,
      required ProgramOperation? arg,
      required bool userMode}) {
    if (arg != null) {
      // Move arg over to shift, e.g. for STO MATRIX A
      assert(shift == null);
      shift = arg;
      arg = null;
    }
    assert(!argDot);
    final nextKey = keys.iterator;
    _next = List.generate(keys.length, (i) {
      nextKey.moveNext();
      final Arg a = generator(i);
      a.init(registerBase,
          f: f,
          shift: shift,
          argDot: argDot,
          arg: nextKey.current,
          userMode: userMode);
      return a;
    });
  }
}

class ArgAlternates extends Arg {
  final Map<ProgramOperation, ProgramOperation> synonyms;
  final Iterable<Arg> children;

  ArgAlternates({this.synonyms = const {}, required this.children});

  @override
  Arg? matches(ProgramOperation key, bool userMode) {
    key = synonyms[key] ?? key;
    for (final a in children) {
      final r = a.matches(key, userMode);
      if (r != null) {
        return r;
      }
    }
    return null;
  }

  @override
  void init(int registerBase,
      {required OpInitFunction f,
      required ProgramOperation? shift,
      required bool argDot,
      required ProgramOperation? arg,
      required bool userMode}) {
    for (final a in children) {
      a.init(registerBase,
          f: f, shift: shift, argDot: argDot, arg: arg, userMode: userMode);
    }
  }
}

class RegisterWriteArg extends ArgAlternates {
  final Value Function(Model m) f;

  RegisterWriteArg(
      {required int maxDigit, required this.f, bool noParenI = false})
      : super(synonyms: Arg.registerISynonyms, children: [
          DigitArg(max: maxDigit, calc: (m, i) => m.memory.registers[i] = f(m)),
          ...(noParenI
              ? const []
              : [
                  KeyArg(
                      key: Arg.kParenI,
                      child: ArgDone(
                          (m) => m.memory.registers.indirectIndex = f(m))),
                ]),
          KeyArg(
              key: Arg.kI,
              child: ArgDone((m) => m.memory.registers.index = f(m))),
        ]);
}

class RegisterReadArg extends ArgAlternates {
  final void Function(Model m, Value v) f;

  RegisterReadArg(
      {required int maxDigit, required this.f, bool noParenI = false})
      : super(synonyms: Arg.registerISynonyms, children: [
          DigitArg(max: maxDigit, calc: (m, i) => f(m, m.memory.registers[i])),
          ...(noParenI
              ? const []
              : [
                  KeyArg(
                      key: Arg.kParenI,
                      child: ArgDone(
                          (m) => f(m, m.memory.registers.indirectIndex))),
                ]),
          KeyArg(
              key: Arg.kI,
              child: ArgDone((m) => f(m, m.memory.registers.index))),
        ]);
}

class LabelArg extends ArgAlternates {
  static int? _translate(Model m, Value v) => m.signMode.valueToLabel(v, m);

  LabelArg(
      {required int maxDigit,
      List<ProgramOperation> letters = const [],
      required void Function(Model m, int? v) f,
      bool indirect = false,
      bool iFirst = false})
      : super(
            synonyms: Arg.registerISynonyms,
            children: _makeChildren(maxDigit, indirect, iFirst, letters, f));

  static List<Arg> _makeChildren(int maxDigit, bool indirect, bool iFirst,
      List<ProgramOperation> letters, void Function(Model, int? v) f) {
    final List<Arg> iList = List.empty(growable: true);
    if (indirect) {
      iList.add(KeyArg(
          key: Arg.kParenI,
          child: ArgDone(
              (m) => f(m, _translate(m, m.memory.registers.indirectIndex)))));
    }
    iList.add(KeyArg(
        key: Arg.kI,
        child: ArgDone((m) => f(m, _translate(m, m.memory.registers.index)))));
    // Note that (i) comes before I on the 16C keyboard, so I originally
    // did the opcodes in that order.  On the 15C, I has to come first, so it's
    // a one-byte opcode; on the 16C, I initially did it in the other order.

    return [
      ...(iFirst ? iList : const []),
      ...letters.map((ProgramOperation letter) => KeyArg(
          key: letter, child: ArgDone((m) => f(m, letter.numericValue!)))),
      DigitArg(max: maxDigit, calc: (m, i) => f(m, i)),
      ...(iFirst ? const [] : iList)
    ];
  }
}

class ArgDone extends Arg {
  late final int opcode;
  late final String programDisplay;
  late final String programListing;

  final void Function(Model) _calculate;

  ArgDone(this._calculate);

  void Function(Model)? getCalculation<T extends ProgramOperation>(
          Model m, DisplayModeSelector<void Function(Model)?, T> selector) =>
      _calculate;

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

  ///
  /// Execute the beforeCalculate function of the operation.  Normally it
  /// just executes, but some 15C operations can be deferred; this method
  /// can be overridden to do that.
  ///
  void handleOpBeforeCalculate(Model m, void Function() opBeforeCalculate) =>
      opBeforeCalculate();
}
