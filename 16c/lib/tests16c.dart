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

import 'dart:math';
import 'package:flutter/foundation.dart';

import 'package:jrpn/m/model.dart';
import 'package:jrpn/c/operations.dart';
import 'package:jrpn/c/controller.dart';

import 'main16c.dart';

class SelfTests16 extends SelfTests {
  SelfTests16({bool inCalculator = true}) : super(inCalculator: inCalculator);

  @override
  Model<Operation> newModel() {
    final r = Model16();
    Controller16(r);    // Initializes late final fields
    return r;
  }

  @override
  Controller newController() => Controller16(Model16());

  Future<void> testIntValues() async {
    await test('int sign modes', () async {
      Model m = newModel();
      m.wordSize = 8;
      m.displayMode = DisplayMode.decimal;
      for (int i = 0; i < 256; i++) {
        m.integerSignMode = SignMode.unsigned;
        m.xI = BigInt.from(i);
        m.integerSignMode = SignMode.twosComplement;
        if (i & 0x80 == 0) {
          await expect(m.xI, BigInt.from(i));
        } else {
          await expect(m.xI, BigInt.from(i - 0x100));
        }
        m.integerSignMode = SignMode.onesComplement;
        if (i & 0x80 == 0) {
          await expect(m.xI, BigInt.from(i));
        } else {
          await expect(m.xI, BigInt.from(i - 0xff));
        }
        m.integerSignMode = SignMode.unsigned;
        await expect(m.xI, BigInt.from(i));
        await expect(m.x.internal, BigInt.from(i));
      }
    });
  }

  Future<void> testIntOperations() async {
    await test("2's complement int operations", () async {
      Model m = newModel();
      m.wordSize = 16;
      m.displayMode = DisplayMode.decimal;
      m.integerSignMode = SignMode.twosComplement;

      // -1 + 1 = 0, set carry
      m.cFlag = false;
      m.yI = BigInt.from(-1);
      m.xI = BigInt.from(1);
      Operations.plus.intCalc!(m);
      await expect(m.xI, BigInt.zero);
      await expect(m.cFlag, true);

      // 0 + 1 = 1, clear carry
      m.cFlag = true;
      m.yI = BigInt.from(0);
      m.xI = BigInt.from(1);
      Operations.plus.intCalc!(m);
      await expect(m.xI, BigInt.one);
      await expect(m.cFlag, false);

      // 32767 * 2 = 32766, set overflow
      m.gFlag = false;
      m.yI = BigInt.from(32767);
      m.xI = BigInt.from(2);
      Operations.mult.intCalc!(m);
      await expect(m.xI, BigInt.from(32766));
      await expect(m.gFlag, true);

      // 1440 / -12 = -120, clear carry
      m.cFlag = true;
      m.yI = BigInt.from(1440);
      m.xI = BigInt.from(-12);
      Operations.div.intCalc!(m);
      await expect(m.xI, BigInt.from(-120));
      await expect(m.cFlag, false);
    });

    await test("1's complement int operations", () async {
      Model m = newModel();
      m.wordSize = 16;
      m.integerSignMode = SignMode.onesComplement;
      m.wordSize = 4;

      // -1 + -1 = -2, set carry
      m.cFlag = true;
      m.yI = BigInt.from(-1);
      m.xI = BigInt.from(-1);
      Operations.plus.intCalc!(m);
      await expect(m.xI, BigInt.from(-2));
      await expect(m.cFlag, true);

      // 3 - 4 = -1, set borrow (that is, cFlag)
      m.cFlag = false;
      m.yI = BigInt.from(3);
      m.xI = BigInt.from(4);
      Operations.minus.intCalc!(m);
      await expect(m.xI, BigInt.from(-1));
      await expect(m.cFlag, true);

      // -3 + 3 = 0, no carry
      m.cFlag = true;
      m.yI = BigInt.from(-3);
      m.xI = BigInt.from(3);
      Operations.plus.intCalc!(m);
      await expect(m.xI, BigInt.from(0));
      await expect(m.cFlag, false);

      // 6 - 5 = 1, no borrow
      m.cFlag = true;
      m.yI = BigInt.from(6);
      m.xI = BigInt.from(5);
      Operations.minus.intCalc!(m);
      await expect(m.xI, BigInt.from(1));
      await expect(m.cFlag, false);
    });

    await test("subtraction carry, 1's and 2's complement", () async {
      Model m = newModel();
      m.wordSize = 4;
      for (final c in [SignMode.onesComplement, SignMode.twosComplement]) {
        m.integerSignMode = c;

        // -6 - -4 = -2, carry set
        m.cFlag = false;
        m.yI = BigInt.from(-6);
        m.xI = BigInt.from(-4);
        Operations.minus.intCalc!(m);
        await expect(m.xI, BigInt.from(-2));
        await expect(m.cFlag, true);

        // 6 - 1 = 5, carry cleared
        m.cFlag = true;
        m.yI = BigInt.from(6);
        m.xI = BigInt.from(1);
        Operations.minus.intCalc!(m);
        await expect(m.xI, BigInt.from(5));
        await expect(m.cFlag, false);
      }
    });
    await test("2's complement range", () async {
      Model m = newModel();
      m.wordSize = 4;

      // 7 + 6 = -3, G set, C cleared
      m.cFlag = true;
      m.gFlag = false;
      m.yI = BigInt.from(7);
      m.xI = BigInt.from(6);
      Operations.plus.intCalc!(m);
      await expect(m.xI, BigInt.from(-3));
      await expect(m.cFlag, false);
      await expect(m.gFlag, true);
    });

    await test('int rmd', () async {
      Model m = newModel();
      m.yI = BigInt.from(0x66);
      m.xI = BigInt.from(7);
      Operations.div.intCalc!(m);
      await expect(m.xI, BigInt.from(0xe));
      m.pushStack();
      m.xI = BigInt.from(2);
      Operations.div.intCalc!(m);
      await expect(m.xI, BigInt.from(0x7));
      m.pushStack();
      m.xI = BigInt.from(4);
      Operations16.rmd.intCalc!(m);
      await expect(m.xI, BigInt.from(0x3));
    });
    await test('logical operations', () async {
      // Not
      Model m = newModel();
      await expect(m.wordSize, 16); // default
      m.displayMode = DisplayMode.bin;
      m.x = m.tryParseValue('11111111')!;
      Operations16.not.intCalc!(m);
      await expect(m.x, m.tryParseValue('1111111100000000'));

      // and
      m.y = m.tryParseValue('10101')!;
      m.x = m.tryParseValue('10011')!;
      Operations16.and.intCalc!(m);
      await expect(m.x, m.tryParseValue('10001'));

      // or
      m.y = m.tryParseValue('10101')!;
      m.x = m.tryParseValue('10011')!;
      Operations16.or.intCalc!(m);
      await expect(m.x, m.tryParseValue('10111'));

      // xor
      m.y = m.tryParseValue('1010101')!;
      m.x = m.tryParseValue('1011101')!;
      Operations16.xor.intCalc!(m);
      await expect(m.x, m.tryParseValue('1000'));

      // sl (shift left)
      m.wordSize = 8;
      m.x = m.tryParseValue('10011100')!;
      Operations16.sl.intCalc!(m);
      await expect(m.x, m.tryParseValue('00111000'));
      await expect(m.cFlag, true);
      Operations16.sl.intCalc!(m);
      await expect(m.x, m.tryParseValue('01110000'));
      await expect(m.cFlag, false);

      // sr (shift right)
      Operations16.sr.intCalc!(m);
      await expect(m.x, m.tryParseValue('00111000'));
      await expect(m.cFlag, false);
      Operations16.sr.intCalc!(m);
      await expect(m.cFlag, false);
      Operations16.sr.intCalc!(m);
      await expect(m.cFlag, false);
      Operations16.sr.intCalc!(m);
      await expect(m.cFlag, false);
      Operations16.sr.intCalc!(m);
      await expect(m.x, m.tryParseValue('00000011'));
      await expect(m.cFlag, true);

      // lj (left justify)
      m.xI = BigInt.from(0);
      Operations16.lj.intCalc!(m);
      await expect(m.x, m.tryParseValue('0'));
      await expect(m.y, m.tryParseValue('0'));
      m.x = m.tryParseValue('1111')!;
      Operations16.lj.intCalc!(m);
      await expect(m.x, m.tryParseValue('100'));
      await expect(m.y, m.tryParseValue('11110000'));

      // asr
      m.integerSignMode = SignMode.unsigned;
      m.x = m.tryParseValue('10011100')!;
      Operations16.asr.intCalc!(m);
      await expect(m.x, m.tryParseValue('01001110'));
      m.integerSignMode = SignMode.twosComplement;
      m.x = m.tryParseValue('10011100')!;
      Operations16.asr.intCalc!(m);
      await expect(m.x, m.tryParseValue('11001110'));

      // rl
      m.x = m.tryParseValue('10011100')!;
      m.cFlag = false;
      Operations16.rl.intCalc!(m);
      await expect(m.cFlag, true);
      await expect(m.x, m.tryParseValue('00111001'));
      Operations16.rl.intCalc!(m);
      await expect(m.cFlag, false);
      await expect(m.x, m.tryParseValue('01110010'));

      // rr
      Operations16.rr.intCalc!(m);
      await expect(m.cFlag, false);
      await expect(m.x, m.tryParseValue('00111001'));
      Operations16.rr.intCalc!(m);
      await expect(m.cFlag, true);
      await expect(m.x, m.tryParseValue('10011100'));
      Operations16.rr.intCalc!(m);
      await expect(m.cFlag, false);
      await expect(m.x, m.tryParseValue('01001110'));

      // rlc
      m.x = m.tryParseValue('10011100')!;
      m.cFlag = false;
      Operations16.rlc.intCalc!(m);
      await expect(m.cFlag, true);
      await expect(m.x, m.tryParseValue('00111000'));
      Operations16.rlc.intCalc!(m);
      await expect(m.cFlag, false);
      await expect(m.x, m.tryParseValue('01110001'));

      // rrc
      Operations16.rrc.intCalc!(m);
      await expect(m.x, m.tryParseValue('00111000'));
      m.cFlag = true;
      Operations16.rrc.intCalc!(m);
      await expect(m.x, m.tryParseValue('10011100'));
      await expect(m.cFlag, false);
      Operations16.rrc.intCalc!(m);
      await expect(m.x, m.tryParseValue('01001110'));
      await expect(m.cFlag, false);

      // rln
      m.x = m.tryParseValue('10011100')!;
      m.pushStack();
      m.xI = BigInt.one;
      m.cFlag = false;
      Operations16.rln.intCalc!(m);
      await expect(m.cFlag, true);
      await expect(m.x, m.tryParseValue('00111001'));

      m.x = m.tryParseValue('10011100')!;
      m.pushStack();
      m.xI = BigInt.two;
      m.cFlag = true;
      Operations16.rln.intCalc!(m);
      await expect(m.cFlag, false);
      await expect(m.x, m.tryParseValue('01110010'));

      // rrn
      m.x = m.tryParseValue('01110010')!;
      m.pushStack();
      m.xI = BigInt.one;
      Operations16.rrn.intCalc!(m);
      await expect(m.cFlag, false);
      await expect(m.x, m.tryParseValue('00111001'));

      m.x = m.tryParseValue('01110010')!;
      m.pushStack();
      m.xI = BigInt.two;
      Operations16.rrn.intCalc!(m);
      await expect(m.cFlag, true);
      await expect(m.x, m.tryParseValue('10011100'));

      m.x = m.tryParseValue('01110010')!;
      m.pushStack();
      m.xI = BigInt.from(3);
      Operations16.rrn.intCalc!(m);
      await expect(m.cFlag, false);
      await expect(m.x, m.tryParseValue('01001110'));

      // rlcn
      m.x = m.tryParseValue('10011100')!;
      m.cFlag = false;
      m.pushStack();
      m.xI = BigInt.one;
      Operations16.rlcn.intCalc!(m);
      await expect(m.cFlag, true);
      await expect(m.x, m.tryParseValue('00111000'));

      m.x = m.tryParseValue('10011100')!;
      m.cFlag = false;
      m.pushStack();
      m.xI = BigInt.two;
      Operations16.rlcn.intCalc!(m);
      await expect(m.cFlag, false);
      await expect(m.x, m.tryParseValue('01110001'));

      // rrcn
      m.x = m.tryParseValue('01110001')!;
      m.cFlag = false;
      m.pushStack();
      m.xI = BigInt.one;
      Operations16.rrcn.intCalc!(m);
      await expect(m.x, m.tryParseValue('00111000'));
      await expect(m.cFlag, true);

      m.x = m.tryParseValue('01110001')!;
      m.cFlag = false;
      m.pushStack();
      m.xI = BigInt.two;
      Operations16.rrcn.intCalc!(m);
      await expect(m.x, m.tryParseValue('10011100'));
      await expect(m.cFlag, false);

      m.x = m.tryParseValue('01110001')!;
      m.cFlag = false;
      m.pushStack();
      m.xI = BigInt.from(3);
      Operations16.rrcn.intCalc!(m);
      await expect(m.x, m.tryParseValue('01001110'));
      await expect(m.cFlag, false);

      // cb
      m.y = m.tryParseValue('11111111')!;
      m.x = m.tryParseValue('00000011')!;
      Operations16.cb.intCalc!(m);
      await expect(m.x, m.tryParseValue('11110111'));

      // sb
      m.y = m.tryParseValue('01110000')!;
      m.x = m.tryParseValue('00000000')!;
      Operations16.sb.intCalc!(m);
      await expect(m.x, m.tryParseValue('01110001'));

      m.pushStack();
      m.xI = BigInt.from(7);
      Operations16.sb.intCalc!(m);
      await expect(m.x, m.tryParseValue('11110001'));

      // maskr
      m.xI = BigInt.from(4);
      Operations16.maskr.intCalc!(m);
      await expect(m.x, m.tryParseValue('00001111'));
      m.xI = BigInt.from(0);
      Operations16.maskr.intCalc!(m);
      await expect(m.x, m.tryParseValue('00000000'));
      m.xI = BigInt.from(8);
      Operations16.maskr.intCalc!(m);
      await expect(m.x, m.tryParseValue('11111111'));

      // maskl
      m.xI = BigInt.from(3);
      Operations16.maskl.intCalc!(m);
      await expect(m.x, m.tryParseValue('11100000'));
      m.xI = BigInt.from(0);
      Operations16.maskl.intCalc!(m);
      await expect(m.x, m.tryParseValue('00000000'));
      m.xI = BigInt.from(7);
      Operations16.maskl.intCalc!(m);
      await expect(m.x, m.tryParseValue('11111110'));
      m.xI = BigInt.from(8);
      Operations16.maskl.intCalc!(m);
      await expect(m.x, m.tryParseValue('11111111'));

      // #b
      m.x = m.tryParseValue('01011101')!;
      Operations16.poundB.intCalc!(m);
      await expect(m.xI, BigInt.from(5));
      m.x = m.tryParseValue('00000000')!;
      Operations16.poundB.intCalc!(m);
      await expect(m.xI, BigInt.from(0));
      m.x = m.tryParseValue('11111111')!;
      Operations16.poundB.intCalc!(m);
      await expect(m.xI, BigInt.from(8));
    });
    await test('double operations', () async {
      Model m = newModel();
      m.wordSize = 5;
      await expect(m.signMode, SignMode.twosComplement); // default
      m.displayMode = DisplayMode.bin;

      // double multiply:  7*6 = 42
      m.y = m.tryParseValue('00111')!;
      m.x = m.tryParseValue('00110')!;
      Operations16.dblx.intCalc!(m);
      await expect(m.x, m.tryParseValue('00001'));
      await expect(m.y, m.tryParseValue('01010'));

      // double divide:  -88 / 11
      m.x = m.tryParseValue('01000')!; // Z
      m.pushStack();
      m.x = m.tryParseValue('11101')!; // Y, YZ is -88
      m.pushStack();
      m.x = m.tryParseValue('01011')!; // X, 11
      Operations16.dblDiv.intCalc!(m);
      await expect(m.x, m.tryParseValue('11000'));

      // double remainder: -87 remainder 11 = -10
      m.x = m.tryParseValue('01001')!; // Z
      m.pushStack();
      m.x = m.tryParseValue('11101')!; // Y, YZ is -87
      m.pushStack();
      m.x = m.tryParseValue('01011')!; // X, 11
      Operations16.dblr.intCalc!(m);
      await expect(m.xI, BigInt.from(-10));

      // double multiply:  Unsigned f723eb313f123827 * a20175becabcde06
      //          is 9c6623a4aff98347_8e11697b49c322ea
      m.wordSize = 64;
      m.integerSignMode = SignMode.unsigned;
      m.gFlag = true;
      m.xI = BigInt.parse('f723eb313f123827', radix: 16);
      m.yI = BigInt.parse('a20175becabcde06', radix: 16);
      Operations16.dblx.intCalc!(m);
      await expect(m.xI, BigInt.parse('9c6623a4aff98347', radix: 16));
      await expect(m.yI, BigInt.parse('8e11697b49c322ea', radix: 16));
      await expect(m.gFlag, false);

      // double divide with above numbers
      m.pushStack();
      m.xI = BigInt.parse('a20175becabcde06', radix: 16);
      Operations16.dblDiv.intCalc!(m);
      await expect(m.xI, BigInt.parse('f723eb313f123827', radix: 16));

      // double remainder with big numbers
      m.xI = BigInt.parse('8e11697b49c322ec', radix: 16);
      m.pushStack();
      m.xI = BigInt.parse('9c6623a4aff98347', radix: 16);
      m.pushStack();
      m.xI = BigInt.parse('f723eb313f123827', radix: 16);
      Operations16.dblr.intCalc!(m);
      await expect(m.xI, BigInt.from(2));
    });
    await test('Unsigned add and subtract', _testUnsigned);
  }

  Future<void> testFloatConvert() async {
    await test('Convert from int to float', () async {
      final Model model = newModel();
      model.wordSize = 32;
      model.yI = BigInt.from(0x25e47);
      model.xI = BigInt.zero;
      model.displayMode = DisplayMode.float(2);
      await expect(model.xF, 155207.0);

      model.displayMode = DisplayMode.hex;
      model.integerSignMode = SignMode.unsigned;
      model.yI = BigInt.one;
      model.xI = BigInt.zero;
      model.displayMode = DisplayMode.float(4);
      model.displayMode = DisplayMode.hex;
      await expect(model.xI, BigInt.parse('ffffffffffffe1', radix: 16));
      await expect(model.yI, BigInt.parse('80000000', radix: 16));
    });
    await test('int DisplayMode mode convert from float', () async {
      await _testConvertFromFloat(0, BigInt.zero, 0);
      await _testConvertFromFloat(
          512, BigInt.one << 31, -22); // 512 = 2<<31 * 2^-22
      await _testConvertFromFloat(
          513, BigInt.one << 31 | BigInt.one << 22, -22); // 512 = 2<<31 * 2^-22

      await _testConvertFromFloat(5e-62, BigInt.parse('2760698539'), -235);
      await _testConvertFromFloat(5e-52, BigInt.parse('3213876089'), -202);
      await _testConvertFromFloat(1.284e-17, BigInt.parse('3973787526'), -88);
    });
    await test(
        'DisplayMode from float to int and back at power of two boundaries',
        () async {
      /// go from a little over 1e-99 to a little under 9.999999999e99,
      /// concentrating on the areas around powers of two.  This is meant to
      /// tease out any rounding errors, especially around the log()
      /// calculations in _IntegerMode.convertValuesFromFloat
      Model model = newModel();
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

    await test('DisplayMode from float to int and back with random values',
        () async {
      Model model = newModel();
      model.displayMode = DisplayMode.float(9);
      await _testFloatConvertAndBack(model, 1.0625892214194362e+58);
      final Random r = Random();
      const limit = kIsWeb ? 100 : 2000;
      for (int i = 0; i < limit; i++) {
        if (i > 0 && i % 2000 == 0) {
          final percent = (i * 100 / limit).toStringAsFixed(0);
          debugPrint('Random float count $i of limit - $percent%');
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
    final Model model = newModel();
    model.displayMode = DisplayMode.float(5);
    model.x = Value.fromDouble(num);
    model.displayMode = DisplayMode.hex;
    await expect(model.xI, BigInt.from(exponent));
    await expect(model.yI, mantissa);
    if (num > 0) {
      await _testConvertFromFloat(-num, -mantissa, exponent);
    }
  }

  Future<void> _testUnsigned() async {
    final ys = [5, 7, 0xfe, 0xff, 5, 7, 0xfe, 0xff];
    final xs = [7, 5, 0xff, 0xfe, 7, 5, 0xff, 0xfe];
    final result = [12, 12, 0xfd, 0xfd, 0xfe, 2, 0xff, 1];
    final gcFlags = [false, false, true, true, true, false, true, false];
    final c = newController();
    final model = c.model;
    model.integerSignMode = SignMode.unsigned;
    model.wordSize = 8;
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
        await expect(model.xI.toInt(), result[i]);
        await expect(model.gFlag, gcFlags[i]);
        await expect(model.cFlag, gcFlags[i]);
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
      await expect(r, dv);
    } else if (fv == Value.fInfinity) {
      await expect(dv > 9.99999999e99, true, reason: '$dv gives infinity');
    } else if (fv == Value.fNegativeInfinity) {
      await expect(dv < -9.99999999e99, true,
          reason: '$dv gives negativeInfinity');
    } else if (m.x == Value.zero) {
      await expect(dv > -1e-98 && dv < 1e-98, true,
          reason: '$dv gives negativeInfinity');
    } else {
      await expect(((r - dv) / dv).abs() < 0.000000001, true,
          reason: '$dv gives $r');
      // The 32 bits of the mantissa give us a smidge over 9 digits of accuracy
    }
    if (dv > 0) {
      await _testFloatConvertAndBack(m, -dv);
    }
  }

  @override
  Future<void> testNumbers() async {
    await super.testNumbers();
    await expect(Operations16.letterA.numericValue, 0xa);
    await expect(Operations16.letterB.numericValue, 0xb);
    await expect(Operations16.letterC.numericValue, 0xc);
    await expect(Operations16.letterD.numericValue, 0xd);
    await expect(Operations16.letterE.numericValue, 0xe);
    await expect(Operations16.letterF.numericValue, 0xf);
  }

  @override
  Future<void> runAll() async {
    await testFloatConvert();
    await testIntValues();
    await testIntOperations();
    return super.runAll();
  }
}
