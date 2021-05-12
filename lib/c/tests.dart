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
part of 'controller.dart';

///
/// Some built-in regression tests.  There aren't just an excuse to flash
/// "running" when a user triggers the 16C's self test fonction.  It's also
/// a way of easily running some of the tests involving integer and floating
/// point behavior in different browsers. This might be a bit of a pain point
/// for Dart, since the numeric types behave differently given JavaScript's
/// deficiencies in ths regard.
///
/// I note that I've seen Dart documentation that mention the 53 bit mantissa
/// of the underlying double that JavaScript uses, but it seems that Dart
/// clamps ints on (perhaps only some?) JavaScript runtime to 32 bits.  It
/// seems the prudent thing to do for interoperable code is to limit usage
/// of the int type to 32 bit ints, which is unfortunate.  In fairness, the
/// Dart language designers were in a bit of a bind, with no really good answers
/// for putting a normal type system on top of JavaScript's odd (and IMHO
/// terrible) choice as regards numeric types.
///
class SelfTests {
  final bool inCalculator;
  int testsRun = 0;
  int errorsSeen = 0;
  int _expectsSeen = 0;
  DateTime _lastPause = DateTime.now();
  static const _minSleep = Duration(milliseconds: 4); // min JS resolution

  SelfTests({this.inCalculator = true});

  Future<void> _expect(Object? val, Object? expected, {String? reason}) async {
    if (inCalculator) {
      if (_expectsSeen++ % 500 == 0) {
        DateTime now = DateTime.now();
        Duration sleep =
            (const Duration(milliseconds: 16)) - now.difference(_lastPause);
        _lastPause = now;
        if (sleep < _minSleep) {
          sleep = _minSleep; // Don't monopolize the CPU
        }
        await Future<void>.delayed(sleep);
        // JS resolution is only 4 ms
      }
    }
    if (val != expected) {
      print('');
      print('*** Error in self-test:  $val != $expected');
      if (reason != null) {
        print('  $reason');
        print('');
      }
      throw CalculatorError(9);
    }
  }

  Future<void> _test(String msg, Future<void> Function() tests) async {
    print('Running tests:  $msg');
    testsRun++;
    try {
      await tests();
      // ignore: avoid_catches_without_on_clauses
    } catch (e, s) {
      print('');
      print('*** Exception in test:  $e');
      print('');
      print(s);
      print('');
      errorsSeen++;
    }
  }

// Format a double to a couple more digits than we need, and a couple
// less than we have.
  String fd(double d) => d.toStringAsExponential(12);

  Future<void> testFloatValues() async {
    await _test('Float Value constants', () async {
      await _expect(Value.zero, Value.fromDouble(0.0));
      await _expect(Value.fInfinity, Value.fromDouble(9.999999999e99));
      await _expect(Value.fNegativeInfinity, Value.fromDouble(-9.999999999e99));
    });
    await _test('Float Value internal representation', () async {
      Model m = Model();
      m.displayMode = DisplayMode.float(4);
      await _expect(m.tryParseValue('0')!.internal, BigInt.from(0));
      await _expect(
          m.tryParseValue('42')!.internal, BigInt.from(0x04200000000001));
      await _expect(m.tryParseValue('-42')!.internal,
          BigInt.parse('94200000000001', radix: 16));
      await _expect(
          m.tryParseValue('1e42')!.internal, BigInt.from(0x1000000000042));
      await _expect(
          m.tryParseValue('1e-42')!.internal, BigInt.from(0x1000000000958));
    });
    await _test('FloatValue from double to double', () async {
      await _expect(fd(Value.fromDouble(42.0).asDouble), fd(42.0));
      await _expect(fd(Value.fromDouble(-42.0).asDouble), fd(-42.0));
      await _expect(
          Value.fromDouble(-42).negateAsFloat(), Value.fromDouble(42));
      await _expect(fd(Value.fromDouble(12.3456e78).asDouble), fd(12.3456e78));
      await _expect(
          fd(Value.fromDouble(-12.3456e78).asDouble), fd(-12.3456e78));
      await _expect(
          fd(Value.fromDouble(12.3456e-78).asDouble), fd(12.3456e-78));
      await _expect(
          fd(Value.fromDouble(-12.3456e-78).asDouble), fd(-12.3456e-78));
      await _expect(
          fd(Value.fromDouble(9.999999999e-99).asDouble), fd(9.999999999e-99));
      await _expect(fd(Value.fromDouble(-9.999999999e-99).asDouble),
          fd(-9.999999999e-99));
    });
    await _test('Float rounding to zero', () async {
      await _expect(Value.fromDouble(1e-100), Value.zero);
      await _expect(Value.fromDouble(-1e-100), Value.zero);
      await _expect(fd(Value.fromDouble(1e-100).asDouble), fd(0.0));
      await _expect(fd(Value.fromDouble(-1e-100).asDouble), fd(0.0));
      await _expect(fd(Value.fromDouble(1e-101).asDouble), fd(0.0));
      await _expect(fd(Value.fromDouble(-1e-101).asDouble), fd(0.0));
    });
    await _test('Float rounding to infinity', () async {
      await _expect(Value.fromDouble(9.9999999996e99), Value.fInfinity);
      await _expect(
          Value.fromDouble(-9.9999999996e99), Value.fNegativeInfinity);
      await _expect(
          fd(Value.fromDouble(9.9999999996e99).asDouble), fd(9.999999999e99));
      await _expect(
          fd(Value.fromDouble(-9.9999999996e99).asDouble), fd(-9.999999999e99));
    });
  }

  Future<void> testIntValues() async {
    await _test('int sign modes', () async {
      Model m = Model();
      m.wordSize = 8;
      m.displayMode = DisplayMode.decimal;
      for (int i = 0; i < 256; i++) {
        m.integerSignMode = SignMode.unsigned;
        m.xI = BigInt.from(i);
        m.integerSignMode = SignMode.twosComplement;
        if (i & 0x80 == 0) {
          await _expect(m.xI, BigInt.from(i));
        } else {
          await _expect(m.xI, BigInt.from(i - 0x100));
        }
        m.integerSignMode = SignMode.onesComplement;
        if (i & 0x80 == 0) {
          await _expect(m.xI, BigInt.from(i));
        } else {
          await _expect(m.xI, BigInt.from(i - 0xff));
        }
        m.integerSignMode = SignMode.unsigned;
        await _expect(m.xI, BigInt.from(i));
        await _expect(m.x.internal, BigInt.from(i));
      }
    });
  }

  Future<void> testIntOperations() async {
    await _test("2's complement int operations", () async {
      Model m = Model();
      m.wordSize = 16;
      m.displayMode = DisplayMode.decimal;
      m.integerSignMode = SignMode.twosComplement;

      // -1 + 1 = 0, set carry
      m.cFlag = false;
      m.yI = BigInt.from(-1);
      m.xI = BigInt.from(1);
      Operations.plus.intCalc!(m);
      await _expect(m.xI, BigInt.zero);
      await _expect(m.cFlag, true);

      // 0 + 1 = 1, clear carry
      m.cFlag = true;
      m.yI = BigInt.from(0);
      m.xI = BigInt.from(1);
      Operations.plus.intCalc!(m);
      await _expect(m.xI, BigInt.one);
      await _expect(m.cFlag, false);

      // 32767 * 2 = 32766, set overflow
      m.gFlag = false;
      m.yI = BigInt.from(32767);
      m.xI = BigInt.from(2);
      Operations.mult.intCalc!(m);
      await _expect(m.xI, BigInt.from(32766));
      await _expect(m.gFlag, true);

      // 1440 / -12 = -120, clear carry
      m.cFlag = true;
      m.yI = BigInt.from(1440);
      m.xI = BigInt.from(-12);
      Operations.div.intCalc!(m);
      await _expect(m.xI, BigInt.from(-120));
      await _expect(m.cFlag, false);
    });

    await _test("1's complement int operations", () async {
      Model m = Model();
      m.wordSize = 16;
      m.integerSignMode = SignMode.onesComplement;
      m.wordSize = 4;

      // -1 + -1 = -2, set carry
      m.cFlag = true;
      m.yI = BigInt.from(-1);
      m.xI = BigInt.from(-1);
      Operations.plus.intCalc!(m);
      await _expect(m.xI, BigInt.from(-2));
      await _expect(m.cFlag, true);

      // 3 - 4 = -1, set borrow (that is, cFlag)
      m.cFlag = false;
      m.yI = BigInt.from(3);
      m.xI = BigInt.from(4);
      Operations.minus.intCalc!(m);
      await _expect(m.xI, BigInt.from(-1));
      await _expect(m.cFlag, true);

      // -3 + 3 = 0, no carry
      m.cFlag = true;
      m.yI = BigInt.from(-3);
      m.xI = BigInt.from(3);
      Operations.plus.intCalc!(m);
      await _expect(m.xI, BigInt.from(0));
      await _expect(m.cFlag, false);

      // 6 - 5 = 1, no borrow
      m.cFlag = true;
      m.yI = BigInt.from(6);
      m.xI = BigInt.from(5);
      Operations.minus.intCalc!(m);
      await _expect(m.xI, BigInt.from(1));
      await _expect(m.cFlag, false);
    });

    await _test("subtraction carry, 1's and 2's complement", () async {
      Model m = Model();
      m.wordSize = 4;
      for (final c in [SignMode.onesComplement, SignMode.twosComplement]) {
        m.integerSignMode = c;

        // -6 - -4 = -2, carry set
        m.cFlag = false;
        m.yI = BigInt.from(-6);
        m.xI = BigInt.from(-4);
        Operations.minus.intCalc!(m);
        await _expect(m.xI, BigInt.from(-2));
        await _expect(m.cFlag, true);

        // 6 - 1 = 5, carry cleared
        m.cFlag = true;
        m.yI = BigInt.from(6);
        m.xI = BigInt.from(1);
        Operations.minus.intCalc!(m);
        await _expect(m.xI, BigInt.from(5));
        await _expect(m.cFlag, false);
      }
    });
    await _test("2's complement range", () async {
      Model m = Model();
      m.wordSize = 4;

      // 7 + 6 = -3, G set, C cleared
      m.cFlag = true;
      m.gFlag = false;
      m.yI = BigInt.from(7);
      m.xI = BigInt.from(6);
      Operations.plus.intCalc!(m);
      await _expect(m.xI, BigInt.from(-3));
      await _expect(m.cFlag, false);
      await _expect(m.gFlag, true);
    });

    await _test('int rmd', () async {
      Model m = Model();
      m.yI = BigInt.from(0x66);
      m.xI = BigInt.from(7);
      Operations.div.intCalc!(m);
      await _expect(m.xI, BigInt.from(0xe));
      m.pushStack();
      m.xI = BigInt.from(2);
      Operations.div.intCalc!(m);
      await _expect(m.xI, BigInt.from(0x7));
      m.pushStack();
      m.xI = BigInt.from(4);
      Operations.rmd.intCalc!(m);
      await _expect(m.xI, BigInt.from(0x3));
    });
    await _test('logical operations', () async {
      // Not
      Model m = Model();
      await _expect(m.wordSize, 16); // default
      m.displayMode = DisplayMode.bin;
      m.x = m.tryParseValue('11111111')!;
      Operations.not.intCalc!(m);
      await _expect(m.x, m.tryParseValue('1111111100000000'));

      // and
      m.y = m.tryParseValue('10101')!;
      m.x = m.tryParseValue('10011')!;
      Operations.and.intCalc!(m);
      await _expect(m.x, m.tryParseValue('10001'));

      // or
      m.y = m.tryParseValue('10101')!;
      m.x = m.tryParseValue('10011')!;
      Operations.or.intCalc!(m);
      await _expect(m.x, m.tryParseValue('10111'));

      // xor
      m.y = m.tryParseValue('1010101')!;
      m.x = m.tryParseValue('1011101')!;
      Operations.xor.intCalc!(m);
      await _expect(m.x, m.tryParseValue('1000'));

      // sl (shift left)
      m.wordSize = 8;
      m.x = m.tryParseValue('10011100')!;
      Operations.sl.intCalc!(m);
      await _expect(m.x, m.tryParseValue('00111000'));
      await _expect(m.cFlag, true);
      Operations.sl.intCalc!(m);
      await _expect(m.x, m.tryParseValue('01110000'));
      await _expect(m.cFlag, false);

      // sr (shift right)
      Operations.sr.intCalc!(m);
      await _expect(m.x, m.tryParseValue('00111000'));
      await _expect(m.cFlag, false);
      Operations.sr.intCalc!(m);
      await _expect(m.cFlag, false);
      Operations.sr.intCalc!(m);
      await _expect(m.cFlag, false);
      Operations.sr.intCalc!(m);
      await _expect(m.cFlag, false);
      Operations.sr.intCalc!(m);
      await _expect(m.x, m.tryParseValue('00000011'));
      await _expect(m.cFlag, true);

      // lj (left justify)
      m.xI = BigInt.from(0);
      Operations.lj.intCalc!(m);
      await _expect(m.x, m.tryParseValue('0'));
      await _expect(m.y, m.tryParseValue('0'));
      m.x = m.tryParseValue('1111')!;
      Operations.lj.intCalc!(m);
      await _expect(m.x, m.tryParseValue('100'));
      await _expect(m.y, m.tryParseValue('11110000'));

      // asr
      m.integerSignMode = SignMode.unsigned;
      m.x = m.tryParseValue('10011100')!;
      Operations.asr.intCalc!(m);
      await _expect(m.x, m.tryParseValue('01001110'));
      m.integerSignMode = SignMode.twosComplement;
      m.x = m.tryParseValue('10011100')!;
      Operations.asr.intCalc!(m);
      await _expect(m.x, m.tryParseValue('11001110'));

      // rl
      m.x = m.tryParseValue('10011100')!;
      m.cFlag = false;
      Operations.rl.intCalc!(m);
      await _expect(m.cFlag, true);
      await _expect(m.x, m.tryParseValue('00111001'));
      Operations.rl.intCalc!(m);
      await _expect(m.cFlag, false);
      await _expect(m.x, m.tryParseValue('01110010'));

      // rr
      Operations.rr.intCalc!(m);
      await _expect(m.cFlag, false);
      await _expect(m.x, m.tryParseValue('00111001'));
      Operations.rr.intCalc!(m);
      await _expect(m.cFlag, true);
      await _expect(m.x, m.tryParseValue('10011100'));
      Operations.rr.intCalc!(m);
      await _expect(m.cFlag, false);
      await _expect(m.x, m.tryParseValue('01001110'));

      // rlc
      m.x = m.tryParseValue('10011100')!;
      m.cFlag = false;
      Operations.rlc.intCalc!(m);
      await _expect(m.cFlag, true);
      await _expect(m.x, m.tryParseValue('00111000'));
      Operations.rlc.intCalc!(m);
      await _expect(m.cFlag, false);
      await _expect(m.x, m.tryParseValue('01110001'));

      // rrc
      Operations.rrc.intCalc!(m);
      await _expect(m.x, m.tryParseValue('00111000'));
      m.cFlag = true;
      Operations.rrc.intCalc!(m);
      await _expect(m.x, m.tryParseValue('10011100'));
      await _expect(m.cFlag, false);
      Operations.rrc.intCalc!(m);
      await _expect(m.x, m.tryParseValue('01001110'));
      await _expect(m.cFlag, false);

      // rln
      m.x = m.tryParseValue('10011100')!;
      m.pushStack();
      m.xI = BigInt.one;
      m.cFlag = false;
      Operations.rln.intCalc!(m);
      await _expect(m.cFlag, true);
      await _expect(m.x, m.tryParseValue('00111001'));

      m.x = m.tryParseValue('10011100')!;
      m.pushStack();
      m.xI = BigInt.two;
      m.cFlag = true;
      Operations.rln.intCalc!(m);
      await _expect(m.cFlag, false);
      await _expect(m.x, m.tryParseValue('01110010'));

      // rrn
      m.x = m.tryParseValue('01110010')!;
      m.pushStack();
      m.xI = BigInt.one;
      Operations.rrn.intCalc!(m);
      await _expect(m.cFlag, false);
      await _expect(m.x, m.tryParseValue('00111001'));

      m.x = m.tryParseValue('01110010')!;
      m.pushStack();
      m.xI = BigInt.two;
      Operations.rrn.intCalc!(m);
      await _expect(m.cFlag, true);
      await _expect(m.x, m.tryParseValue('10011100'));

      m.x = m.tryParseValue('01110010')!;
      m.pushStack();
      m.xI = BigInt.from(3);
      Operations.rrn.intCalc!(m);
      await _expect(m.cFlag, false);
      await _expect(m.x, m.tryParseValue('01001110'));

      // rlcn
      m.x = m.tryParseValue('10011100')!;
      m.cFlag = false;
      m.pushStack();
      m.xI = BigInt.one;
      Operations.rlcn.intCalc!(m);
      await _expect(m.cFlag, true);
      await _expect(m.x, m.tryParseValue('00111000'));

      m.x = m.tryParseValue('10011100')!;
      m.cFlag = false;
      m.pushStack();
      m.xI = BigInt.two;
      Operations.rlcn.intCalc!(m);
      await _expect(m.cFlag, false);
      await _expect(m.x, m.tryParseValue('01110001'));

      // rrcn
      m.x = m.tryParseValue('01110001')!;
      m.cFlag = false;
      m.pushStack();
      m.xI = BigInt.one;
      Operations.rrcn.intCalc!(m);
      await _expect(m.x, m.tryParseValue('00111000'));
      await _expect(m.cFlag, true);

      m.x = m.tryParseValue('01110001')!;
      m.cFlag = false;
      m.pushStack();
      m.xI = BigInt.two;
      Operations.rrcn.intCalc!(m);
      await _expect(m.x, m.tryParseValue('10011100'));
      await _expect(m.cFlag, false);

      m.x = m.tryParseValue('01110001')!;
      m.cFlag = false;
      m.pushStack();
      m.xI = BigInt.from(3);
      Operations.rrcn.intCalc!(m);
      await _expect(m.x, m.tryParseValue('01001110'));
      await _expect(m.cFlag, false);

      // cb
      m.y = m.tryParseValue('11111111')!;
      m.x = m.tryParseValue('00000011')!;
      Operations.cb.intCalc!(m);
      await _expect(m.x, m.tryParseValue('11110111'));

      // sb
      m.y = m.tryParseValue('01110000')!;
      m.x = m.tryParseValue('00000000')!;
      Operations.sb.intCalc!(m);
      await _expect(m.x, m.tryParseValue('01110001'));

      m.pushStack();
      m.xI = BigInt.from(7);
      Operations.sb.intCalc!(m);
      await _expect(m.x, m.tryParseValue('11110001'));

      // maskr
      m.xI = BigInt.from(4);
      Operations.maskr.intCalc!(m);
      await _expect(m.x, m.tryParseValue('00001111'));
      m.xI = BigInt.from(0);
      Operations.maskr.intCalc!(m);
      await _expect(m.x, m.tryParseValue('00000000'));
      m.xI = BigInt.from(8);
      Operations.maskr.intCalc!(m);
      await _expect(m.x, m.tryParseValue('11111111'));

      // maskl
      m.xI = BigInt.from(3);
      Operations.maskl.intCalc!(m);
      await _expect(m.x, m.tryParseValue('11100000'));
      m.xI = BigInt.from(0);
      Operations.maskl.intCalc!(m);
      await _expect(m.x, m.tryParseValue('00000000'));
      m.xI = BigInt.from(7);
      Operations.maskl.intCalc!(m);
      await _expect(m.x, m.tryParseValue('11111110'));
      m.xI = BigInt.from(8);
      Operations.maskl.intCalc!(m);
      await _expect(m.x, m.tryParseValue('11111111'));

      // #b
      m.x = m.tryParseValue('01011101')!;
      Operations.poundB.intCalc!(m);
      await _expect(m.xI, BigInt.from(5));
      m.x = m.tryParseValue('00000000')!;
      Operations.poundB.intCalc!(m);
      await _expect(m.xI, BigInt.from(0));
      m.x = m.tryParseValue('11111111')!;
      Operations.poundB.intCalc!(m);
      await _expect(m.xI, BigInt.from(8));
    });
    await _test('double operations', () async {
      Model m = Model();
      m.wordSize = 5;
      await _expect(m.signMode, SignMode.twosComplement); // default
      m.displayMode = DisplayMode.bin;

      // double multiply:  7*6 = 42
      m.y = m.tryParseValue('00111')!;
      m.x = m.tryParseValue('00110')!;
      Operations.dblx.intCalc!(m);
      await _expect(m.x, m.tryParseValue('00001'));
      await _expect(m.y, m.tryParseValue('01010'));

      // double divide:  -88 / 11
      m.x = m.tryParseValue('01000')!; // Z
      m.pushStack();
      m.x = m.tryParseValue('11101')!; // Y, YZ is -88
      m.pushStack();
      m.x = m.tryParseValue('01011')!; // X, 11
      Operations.dblDiv.intCalc!(m);
      await _expect(m.x, m.tryParseValue('11000'));

      // double remainder: -87 remainder 11 = -10
      m.x = m.tryParseValue('01001')!; // Z
      m.pushStack();
      m.x = m.tryParseValue('11101')!; // Y, YZ is -87
      m.pushStack();
      m.x = m.tryParseValue('01011')!; // X, 11
      Operations.dblr.intCalc!(m);
      await _expect(m.xI, BigInt.from(-10));

      // double multiply:  Unsigned f723eb313f123827 * a20175becabcde06
      //          is 9c6623a4aff98347_8e11697b49c322ea
      m.wordSize = 64;
      m.integerSignMode = SignMode.unsigned;
      m.gFlag = true;
      m.xI = BigInt.parse('f723eb313f123827', radix: 16);
      m.yI = BigInt.parse('a20175becabcde06', radix: 16);
      Operations.dblx.intCalc!(m);
      await _expect(m.xI, BigInt.parse('9c6623a4aff98347', radix: 16));
      await _expect(m.yI, BigInt.parse('8e11697b49c322ea', radix: 16));
      await _expect(m.gFlag, false);

      // double divide with above numbers
      m.pushStack();
      m.xI = BigInt.parse('a20175becabcde06', radix: 16);
      Operations.dblDiv.intCalc!(m);
      await _expect(m.xI, BigInt.parse('f723eb313f123827', radix: 16));

      // double remainder with big numbers
      m.xI = BigInt.parse('8e11697b49c322ec', radix: 16);
      m.pushStack();
      m.xI = BigInt.parse('9c6623a4aff98347', radix: 16);
      m.pushStack();
      m.xI = BigInt.parse('f723eb313f123827', radix: 16);
      Operations.dblr.intCalc!(m);
      await _expect(m.xI, BigInt.from(2));
    });
    await _test('Unsigned add and subtract', _testUnsigned);
  }

  Future<void> testFloatConvert() async {
    await _test('Convert from int to float', () async {
      final Model model = Model();
      model.wordSize = 32;
      model.yI = BigInt.from(0x25e47);
      model.xI = BigInt.zero;
      model.displayMode = DisplayMode.float(2);
      await _expect(model.xF, 155207.0);

      model.displayMode = DisplayMode.hex;
      model.integerSignMode = SignMode.unsigned;
      model.yI = BigInt.one;
      model.xI = BigInt.zero;
      model.displayMode = DisplayMode.float(4);
      model.displayMode = DisplayMode.hex;
      await _expect(model.xI, BigInt.parse('ffffffffffffe1', radix: 16));
      await _expect(model.yI, BigInt.parse('80000000', radix: 16));
    });
    await _test('int DisplayMode mode convert from float', () async {
      await _testConvertFromFloat(0, BigInt.zero, 0);
      await _testConvertFromFloat(
          512, BigInt.one << 31, -22); // 512 = 2<<31 * 2^-22
      await _testConvertFromFloat(
          513, BigInt.one << 31 | BigInt.one << 22, -22); // 512 = 2<<31 * 2^-22

      await _testConvertFromFloat(5e-62, BigInt.parse('2760698539'), -235);
      await _testConvertFromFloat(5e-52, BigInt.parse('3213876089'), -202);
      await _testConvertFromFloat(1.284e-17, BigInt.parse('3973787526'), -88);
    });
    await _test(
        'DisplayMode from float to int and back at power of two boundaries',
        () async {
      /// go from a little over 1e-99 to a little under 9.999999999e99,
      /// concentrating on the areas around powers of two.  This is meant to
      /// tease out any rounding errors, especially around the log()
      /// calculations in _IntegerMode.convertValuesFromFloat
      Model model = Model();
      model.displayMode = DisplayMode.float(9);
      await _testFloatConvertAndBack(model, 0.0);
      await _testFloatConvertAndBack(model, 1);
      await _testFloatConvertAndBack(model, 123);
      await _testFloatConvertAndBack(model, 5.678e99);
      await _testFloatConvertAndBack(model, 5.678e-99);
      for (int exp = -328; exp <= 332; exp++) {
        final double base = pow(2.0, exp).toDouble();
        for (double delta = -pow(10.0, -8.0).toDouble();
            delta <= pow(10.0, -8);
            delta += pow(10.0, -10) * 3) {
          await _testFloatConvertAndBack(model, base + delta * base);
        }
      }
    });

    await _test('DisplayMode from float to int and back with random values',
        () async {
      Model model = Model();
      model.displayMode = DisplayMode.float(9);
      await _testFloatConvertAndBack(model, 1.0625892214194362e+58);
      final Random r = Random();
      const limit = kIsWeb ? 100 : 2000;
      for (int i = 0; i < limit; i++) {
        if (i > 0 && i % 2000 == 0) {
          final percent = (i * 100 / limit).toStringAsFixed(0);
          print('Random float count $i of limit - $percent%');
        }
        final double m = 22 * r.nextDouble() - 11;
        final int e = r.nextInt(250) - 125; // Generate some out of range
        final double dv = m * pow(10.0, e);
        await _testFloatConvertAndBack(model, dv);
      }
    });
  }

  Future<void> _testConvertFromFloat(
      double num, BigInt mantissa, int exponent) async {
    final Model model = Model();
    model.displayMode = DisplayMode.float(5);
    model.x = Value.fromDouble(num);
    model.displayMode = DisplayMode.hex;
    await _expect(model.xI, BigInt.from(exponent));
    await _expect(model.yI, mantissa);
    if (num > 0) {
      await _testConvertFromFloat(-num, -mantissa, exponent);
    }
  }

  Future<void> _testUnsigned() async {
    final ys = [5, 7, 0xfe, 0xff, 5, 7, 0xfe, 0xff];
    final xs = [7, 5, 0xff, 0xfe, 7, 5, 0xff, 0xfe];
    final result = [12, 12, 0xfd, 0xfd, 0xfe, 2, 0xff, 1];
    final gcFlags = [false, false, true, true, true, false, true, false];
    final model = Model<Operation>();
    model.integerSignMode = SignMode.unsigned;
    model.wordSize = 8;
    final c = Controller(model);
    for (int i = 0; i < ys.length; i++) {
      for (bool initial in [false, true]) {
        model.gFlag = initial;
        model.cFlag = initial;
        model.yI = BigInt.from(ys[i]);
        model.xI = BigInt.from(xs[i]);
        if (i < 4) {
          c.buttonDown(Operations.plus);
        } else {
          c.buttonDown(Operations.minus);
        }
        c.buttonUp();
        await _expect(model.xI.toInt(), result[i]);
        await _expect(model.gFlag, gcFlags[i]);
        await _expect(model.cFlag, gcFlags[i]);
      }
    }
  }

  Future<void> _testFloatConvertAndBack(final Model m, final double dv) async {
    final Value fv = Value.fromDouble(dv);
    assert(m.displayMode.isFloatMode);
    m.x = fv;
    m.displayMode = DisplayMode.hex;
    m.displayMode = DisplayMode.float(0);
    final double r = m.xF;
    if (dv == 0.0) {
      await _expect(r, dv);
    } else if (fv == Value.fInfinity) {
      await _expect(dv > 9.99999999e99, true, reason: '$dv gives infinity');
    } else if (fv == Value.fNegativeInfinity) {
      await _expect(dv < -9.99999999e99, true,
          reason: '$dv gives negativeInfinity');
    } else if (m.x == Value.zero) {
      await _expect(dv > -1e-98 && dv < 1e-98, true,
          reason: '$dv gives negativeInfinity');
    } else {
      await _expect(((r - dv) / dv).abs() < 0.000000001, true,
          reason: '$dv gives $r');
      // The 32 bits of the mantissa give us a smidge over 9 digits of accuracy
    }
    if (dv > 0) {
      await _testFloatConvertAndBack(m, -dv);
    }
  }

  Future<void> testJson() async {
    final Model<Operation> m = Model<Operation>();
    Controller(m); // initializes m
    final String s = json.encoder.convert(m.toJson());
    m.decodeJson(json.decoder.convert(s) as Map<String, dynamic>,
        needsSave: false);
    await _expect(
        json.encoder.convert(m.toJson()), s); // It's not much of a test :-)
  }

  Future<void> testNumbers() async {
    Controller(Model()); // initializes late final values.
    // Only really needed if no prior test has done this.
    await _expect(Operations.n0.numericValue, 0x0);
    await _expect(Operations.n1.numericValue, 0x1);
    await _expect(Operations.n2.numericValue, 0x2);
    await _expect(Operations.n3.numericValue, 0x3);
    await _expect(Operations.n4.numericValue, 0x4);
    await _expect(Operations.n5.numericValue, 0x5);
    await _expect(Operations.n6.numericValue, 0x6);
    await _expect(Operations.n7.numericValue, 0x7);
    await _expect(Operations.n8.numericValue, 0x8);
    await _expect(Operations.n9.numericValue, 0x9);
    await _expect(Operations.a.numericValue, 0xa);
    await _expect(Operations.b.numericValue, 0xb);
    await _expect(Operations.c.numericValue, 0xc);
    await _expect(Operations.d.numericValue, 0xd);
    await _expect(Operations.e.numericValue, 0xe);
    await _expect(Operations.f.numericValue, 0xf);
  }

  Future<void> runAll() async {
    await testJson();
    await testFloatConvert();
    await testFloatValues();
    await testIntValues();
    await testIntOperations();
    await testNumbers();
    print('');
    print('***  $testsRun self tests run.  $errorsSeen errors seen');
    print('');
    if (errorsSeen > 0) {
      throw CalculatorError(9);
    }
  }
}
