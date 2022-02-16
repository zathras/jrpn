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

abstract class Arg {
  static late final List<ProgramOperation> kDigits;
  static late final ProgramOperation kI;
  static late final ProgramOperation kParenI;
  static late final ProgramOperation kDot;
  static late final Map<ProgramOperation, ProgramOperation> registerISynonyms;

  Arg? matches(ProgramOperation key, bool userMode);

  void assignOpcodes(Model m, void Function(ArgDone resolved) f);
}

class DigitArg extends Arg {
  final int max;
  final void Function(Model, int) calc;

  late final List<Arg> _next;
  late final Arg? _nextOnDot;

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
  void assignOpcodes(Model m, void Function(ArgDone resolved) f) {
    final int base = m.registerNumberBase;
    _next = List.generate(min(max + 1, base), (i) {
      final a = ArgDone((m) => calc(m, i)); // Function currying, baby
      a.assignOpcodes(m, f);
      return a;
    }, growable: false);
    if (max < base) {
      _nextOnDot = null;
    } else {
      _nextOnDot = KeyArg(
          key: Arg.kDot,
          child: DigitArg(max: max - base, calc: (m, i) => calc(m, i + base)));
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
  void assignOpcodes(Model m, void Function(ArgDone resolved) f) =>
      child.assignOpcodes(m, f);
}

class KeysArg extends Arg {
  final Iterable<ProgramOperation> keys;
  final Arg Function(int) generator;
  late final List<Arg> _next;

  KeysArg({required this.keys, required this.generator});

  @override
  Arg? matches(ProgramOperation key, bool userMode) {
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
  void assignOpcodes(Model m, void Function(ArgDone resolved) f) {
    _next = List.generate(keys.length, (i) {
      final a = generator(i);
      a.assignOpcodes(m, f);
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
    for (final a in children) {
      final r = a.matches(key, userMode);
      if (r != null) {
        return r;
      }
    }
    return null;
  }

  @override
  void assignOpcodes(Model m, void Function(ArgDone resolved) f) {
    for (final a in children) {
      a.assignOpcodes(m, f);
    }
  }
}

class RegisterWriteArg extends ArgAlternates {
  final Value Function(Model m) f;

  RegisterWriteArg({required int numDigits, required this.f})
      : super(synonyms: Arg.registerISynonyms, children: [
          DigitArg(
              max: numDigits, calc: (m, i) => m.memory.registers[i] = f(m)),
          KeyArg(
              key: Arg.kI,
              child: ArgDone((m) => m.memory.registers.index = f(m))),
          KeyArg(
              key: Arg.kParenI,
              child: ArgDone((m) => m.memory.registers.indirectIndex = f(m)))
        ]);
}

class RegisterReadArg extends ArgAlternates {
  final void Function(Model m, Value v) f;

  RegisterReadArg({required int numDigits, required this.f})
      : super(synonyms: Arg.registerISynonyms, children: [
          DigitArg(max: numDigits, calc: (m, i) => f(m, m.memory.registers[i])),
          KeyArg(
              key: Arg.kI,
              child: ArgDone((m) => f(m, m.memory.registers.index))),
          KeyArg(
              key: Arg.kParenI,
              child: ArgDone((m) => f(m, m.memory.registers.indirectIndex)))
        ]);
}

class LabelArg extends ArgAlternates {
  final void Function(Model m, int? v) f;

  static int? _translate(Model m, Value v) => m.signMode.valueToLabel(v, m);

  LabelArg({required int numDigits, required this.f, bool indirect = false})
      : super(synonyms: Arg.registerISynonyms, children: [
          DigitArg(max: numDigits, calc: (m, i) => f(m, i)),
          KeyArg(
              key: Arg.kI,
              child: ArgDone(
                  (m) => f(m, _translate(m, m.memory.registers.index)))),
          KeyArg(
              key: Arg.kParenI,
              child: ArgDone(
                  (m) => f(m, _translate(m, m.memory.registers.indirectIndex))))
        ]);
}

class RegisterOpArg extends ArgAlternates {
  final double Function(double, double) f;

  RegisterOpArg({required int numDigits, required this.f})
      : super(synonyms: Arg.registerISynonyms, children: [
          DigitArg(
              max: numDigits,
              calc: (m, i) => m.memory.registers[i] =
                  Value.fromDouble(f(m.memory.registers[i].asDouble, m.xF))),
          KeyArg(
              key: Arg.kI,
              child: ArgDone((m) => m.memory.registers.index = Value.fromDouble(
                  f(m.memory.registers.index.asDouble, m.xF)))),
          KeyArg(
              key: Arg.kParenI,
              child: ArgDone((m) => m.memory.registers.indirectIndex =
                  Value.fromDouble(
                      f(m.memory.registers.indirectIndex.asDouble, m.xF))))
        ]);
}

class UserArg extends Arg {
  final bool userMode;
  final Arg child;

  UserArg({required this.userMode, required this.child});

  @override
  Arg? matches(ProgramOperation key, bool userMode) {
    if (this.userMode == userMode) {
      return child.matches(key, userMode);
    } else {
      return null;
    }
  }

  @override
  void assignOpcodes(Model m, void Function(ArgDone resolved) f) =>
      child.assignOpcodes(m, f);
}

class ArgDone extends Arg {
  late final String programDisplay; // @@ TODO

  late final String programListing; // @@ TODO

  final void Function(Model) calculate;

  ArgDone(this.calculate);

  @override
  void assignOpcodes(Model m, void Function(ArgDone resolved) f) => f(this);

  @override
  Arg? matches(ProgramOperation key, bool userMode) => null;
}
