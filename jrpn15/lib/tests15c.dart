/*
Copyright (c) 2021-2023 William Foote

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

library jrpn15.tests;

import 'package:jrpn/m/complex.dart';
import 'package:jrpn/m/model.dart';
import 'package:jrpn/c/controller.dart';

import 'main.dart';
import 'model15c.dart';

class SelfTests15 extends SelfTests {
  SelfTests15({bool inCalculator = true}) : super(inCalculator: inCalculator);

  @override
  Model15<Operation> newModel() {
    final m = createModel15();
    Controller15(m); // Initializes late final fields in model
    return m;
  }

  @override
  Controller newController() => Controller15(createModel15());

  @override
  int get pauseEvery => 4;

  Future<void> _testOneArgComplex(
      Model15 m, NormalOperation op, Complex arg, Complex result,
      [NormalOperation? inverse]) async {
    m.xC = arg;
    op.complexCalc!(m);
    await expect(m.x, Value.fromDouble(result.real));
    await expect(m.xImaginary, Value.fromDouble(result.imaginary));
    if (inverse != null) {
      return _testOneArgComplex(m, inverse, result, arg);
    }
  }

  Future<void> _testTwoArgComplex(Model15 m, NormalOperation op, Complex x,
      Complex y, Complex result) async {
    m.xC = x;
    m.yC = y;
    op.complexCalc!(m);
    await expect(m.x, Value.fromDouble(result.real));
    await expect(m.xImaginary, Value.fromDouble(result.imaginary));
  }

  Future<void> _testOneArgFloat(
      Model15 m, NormalOperation op, double arg, double result,
      [NormalOperation? inverse]) async {
    m.xF = arg;
    op.floatCalc!(m);
    await expect(m.x, Value.fromDouble(result));
    m.isComplexMode = true;
    m.xC = Complex(arg, 0);
    op.complexCalc!(m);
    await expect(m.x, Value.fromDouble(result));
    await expect(m.xImaginary, Value.zero);
    m.isComplexMode = false;
    if (inverse != null) {
      return _testOneArgFloat(m, inverse, result, arg);
    }
  }

  Future<void> _testTwoArgFloat(
      Model15 m, NormalOperation op, double x, double y, double? result,
      {int? err}) async {
    assert(result != null || err != null);
    m.xF = x;
    m.yF = y;
    try {
      op.floatCalc!(m);
    } on CalculatorError catch (e) {
      await expect(e.num15, err);
      return;
    }
    await expect(m.x, Value.fromDouble(result!));
    m.isComplexMode = true;
    m.xC = Complex(x, 0);
    m.yC = Complex(y, 0);
    op.complexCalc!(m);
    await expect(m.x, Value.fromDouble(result));
    await expect(m.xImaginary, Value.zero);
    m.isComplexMode = false;
  }

  Future<void> testFloatFunctions() async {
    await test('15c float mode functions', () async {
      final m = newModel();
      await _testOneArgFloat(
          m, Operations15.lnOp, 2.37, 0.8628899551, Operations15.eX15);
      await _testOneArgFloat(m, Operations15.sqrtOp15, 7.37, 2.714774392);
      await _testOneArgFloat(
          m, Operations15.xSquared, 2.714774392, 7.369999999);
      // On the real 15C, the xSquared result is that, too.
      await _testOneArgFloat(
          m, Operations15.xSquared, 4, 16, Operations15.sqrtOp15);
      await _testOneArgFloat(
          m, Operations15.tenX15, 3.7, 5011.872336, Operations15.logOp);
      await _testTwoArgFloat(m, Operations15.yX15, 1.234, 5.678, 8.524660835);
      await _testOneArgFloat(
          m, Operations15.reciprocal15, 0.01, 100, Operations15.reciprocal15);
      await _testTwoArgFloat(
          m, Operations15.deltaPercent, 5.678, 1.234, 360.1296596);

      await _testOneArgFloat(m, Operations15.fracOp, 2.37, 0.37);
      await _testOneArgFloat(m, Operations15.fracOp, -2.37, -0.37);
      await _testOneArgFloat(m, Operations15.fracOp, 2.37e54, 0);
      await _testOneArgFloat(m, Operations15.fracOp, -2.37e54, 0);
      await _testOneArgFloat(m, Operations15.fracOp, 2.37e-54, 2.37e-54);
      await _testOneArgFloat(m, Operations15.fracOp, -2.37e-54, -2.37e-54);

      await _testOneArgFloat(m, Operations15.intOp, 2.37, 2);
      await _testOneArgFloat(m, Operations15.intOp, -2.37, -2);
      await _testOneArgFloat(m, Operations15.intOp, 2.37e54, 2.37e54);
      await _testOneArgFloat(m, Operations15.intOp, -2.37e54, -2.37e54);
      await _testOneArgFloat(m, Operations15.intOp, -2.37e-54, 0);
      await _testOneArgFloat(m, Operations15.intOp, 2.37e-54, 0);

      for (final sign in [1.0, -1.0]) {
        await _testOneArgFloat(m, Operations15.toH, sign * 1.2345,
            sign * 1.395833333, Operations15.toHMS);
        await _testOneArgFloat(
            m, Operations15.toH, sign * 1.6789, sign * 2.141388889);
        await _testOneArgFloat(
            m, Operations15.toHMS, sign * 2.141388889, sign * 2.0829);
        await _testOneArgFloat(
            m, Operations15.toHMS, sign * 2.141388889, sign * 2.0829);
        await _testOneArgFloat(m, Operations15.toH, sign * 1.595999999,
            sign * 1.999999997, Operations15.toHMS);
        // The following three are verified on a physical 15C.  59.999996
        // is rounded to 59.99999, and not 60.00000, even though 6 >= 5.
        // In general, it never rounds up to 60 (or up to 6, where only the
        // tens digit is available).
        await _testOneArgFloat(
            m, Operations15.toHMS, sign * 1.999999999, sign * 1.595999999);
        await _testOneArgFloat(
            m, Operations15.toHMS, sign * 99999999.99, sign * 99999999.59);
        await _testOneArgFloat(
            m, Operations15.toHMS, sign * 999999999.9, sign * 999999999.5);
        await _testOneArgFloat(
            m, Operations15.toHMS, sign * 999999.9999, sign * 999999.5959);
        await _testOneArgFloat(
            m, Operations15.toHMS, sign * 9999999.999, sign * 9999999.595);
        await _testOneArgFloat(
            m, Operations15.toHMS, sign * 99999.99999, sign * 99999.59599);
        await _testOneArgFloat(
            m, Operations15.toHMS, sign * 1.666666667e-2, sign * 0.01);
        await _testOneArgFloat(
            m, Operations15.toHMS, sign * 1.666666666e-2, sign * 0.01);
        await _testOneArgFloat(m, Operations15.toHMS, sign * 1.666666665e-2,
            sign * 0.005999999990); // 15C gives 0:00:59.99999990
        await _testOneArgFloat(m, Operations15.toHMS, sign * 1.666666664e-2,
            sign * 0.005999999990);
        await _testOneArgFloat(
            m, Operations15.toHMS, sign * 123456789.9, sign * 123456789.5);
        await _testOneArgFloat(
            m, Operations15.toHMS, sign * 1234567891, sign * 1234567891);
        await _testOneArgFloat(
            m, Operations15.toHMS, sign * 0.9999999999, sign * 0.5959999999);

        await _testOneArgFloat(m, Operations15.toRad, sign * 100,
            sign * 1.745329252, Operations15.toDeg);
        await _testOneArgFloat(
            m, Operations15.toDeg, sign * 42.1, sign * 2412.152318);
        await _testOneArgFloat(m, Operations15.toRad, sign * 2412.152318,
            sign * 42.10000001, Operations15.toDeg); // Matches 15C
      }
    });
  }

  Future<void> testComplexFunctions() async {
    await test('15c complex mode functions', () async {
      final m = newModel();
      m.isComplexMode = true;

      await _testOneArgComplex(m, Operations15.lnOp,
          const Complex(1.234, 5.678), const Complex(1.759674471, 1.356794138));
      await _testOneArgComplex(
          m,
          Operations15.eX15,
          const Complex(1.759674471, 1.356794138),
          const Complex(1.234000001, 5.678));
      await _testOneArgComplex(
          m,
          Operations15.lnOp,
          const Complex(1.234, -5.678),
          const Complex(1.759674471, -1.356794138));
      await _testOneArgComplex(
          m,
          Operations15.eX15,
          const Complex(1.759674471, -1.356794138),
          const Complex(1.234000001, -5.678));
      await _testOneArgComplex(
          m,
          Operations15.lnOp,
          const Complex(-1.234, 5.678),
          const Complex(1.759674471, 1.784798515));
      await _testOneArgComplex(
          m,
          Operations15.eX15,
          const Complex(1.759674471, 1.784798515),
          const Complex(-1.233999998, 5.678000001));
      await _testOneArgComplex(
          m,
          Operations15.lnOp,
          const Complex(-1.234, -5.678),
          const Complex(1.759674471, -1.784798515));
      await _testOneArgComplex(
          m,
          Operations15.eX15,
          const Complex(1.759674471, -1.784798515),
          const Complex(-1.233999998, -5.678000001));

      await _testOneArgComplex(m, Operations15.sqrtOp15,
          const Complex(1.234, 5.678), const Complex(1.876771907, 1.512703802));
      await _testOneArgComplex(
          m,
          Operations15.xSquared,
          const Complex(1.876771907, 1.512703802),
          const Complex(1.233999998, 5.677999998));
      await _testOneArgComplex(
          m,
          Operations15.sqrtOp15,
          const Complex(1.234, -5.678),
          const Complex(1.876771907, -1.512703802));
      await _testOneArgComplex(
          m,
          Operations15.xSquared,
          const Complex(1.876771907, -1.512703802),
          const Complex(1.233999998, -5.677999998));
      await _testOneArgComplex(
          m,
          Operations15.sqrtOp15,
          const Complex(-1.234, 5.678),
          const Complex(1.512703802, 1.876771907));
      await _testOneArgComplex(
          m,
          Operations15.xSquared,
          const Complex(1.512703802, 1.876771907),
          const Complex(-1.233999998, 5.677999998));
      await _testOneArgComplex(
          m,
          Operations15.sqrtOp15,
          const Complex(-1.234, -5.678),
          const Complex(1.512703802, -1.876771907));
      await _testOneArgComplex(
          m,
          Operations15.xSquared,
          const Complex(1.512703802, -1.876771907),
          const Complex(-1.233999998, -5.677999998));

      await _testOneArgComplex(
          m,
          Operations15.tenX15,
          const Complex(-1.234, -5.678),
          const Complex(0.05098501197, -0.02836565620));
      // Note:  The above produces Complex(0.05098501197, -0.02836565619)
      //        on a real 15C.  Our answer is more accurate:  The answer is
      //        (5.09850119703065e-2, -2.83656561954365e-2) to 15 radix
      //        digits.  See misc/test_float/TestFloat.java.
      await _testOneArgComplex(
          m,
          Operations15.logOp,
          const Complex(0.05098501197, -0.02836565620),
          const Complex(-1.234, -0.2204945847));

      await _testTwoArgComplex(
          m,
          Operations15.yX15,
          const Complex(5.6, 7.8),
          const Complex(1.2, 3.4),
          const Complex(-0.03277613870, -0.08229096286));

      await _testOneArgComplex(
          m,
          Operations15.reciprocal15,
          const Complex(0.15, 0.25),
          const Complex(1.764705882, -2.941176471),
          Operations15.reciprocal15);

      m.isComplexMode = false;
      m.xF = 12.34;
      Operations15.reImSwap.floatCalc!(m);
      await expect(m.xF, 0);
      await expect(m.xImaginary.asDouble, 12.34);
      await expect(m.xC, const Complex(0, 12.34));
      m.xC = Complex(56.78, m.xImaginary.asDouble);
      Operations15.reImSwap.complexCalc!(m);
      await expect(m.xF, 12.34);
      await expect(m.xImaginary.asDouble, 56.78);
      await expect(m.xC, const Complex(12.34, 56.78));

      await expect(m.isComplexMode, true);
    });
  }

  Future<void> testStatisticsFunctions() async {
    await test('15c statistics functions', () async {
      final m = newModel();
      await _testOneArgFloat(m, Operations15.xFactorial, 0, 1);
      await _testOneArgFloat(m, Operations15.xFactorial, 1, 1);
      await _testOneArgFloat(m, Operations15.xFactorial, 9, 362880);
      await _testOneArgFloat(m, Operations15.xFactorial, 0.5, 0.8862269255);
      await _testOneArgFloat(m, Operations15.xFactorial, -0.7, 2.991568988);
      await _testOneArgFloat(
          m, Operations15.xFactorial, -31.2, -1.016536828e-32);
      await _testOneArgFloat(m, Operations15.xFactorial, 57.3, 1.367681189e77);
      await expect(m.getFlag(9), false);
      await _testOneArgFloat(m, Operations15.xFactorial, 70, 9.999999999e+99);
      await expect(m.getFlag(9), true);
      m.setFlag(9, false);
      await _testOneArgFloat(m, Operations15.xFactorial, 70.1, 9.999999999e+99);
      await expect(m.getFlag(9), true);
      m.setFlag(9, false);

      await _testTwoArgFloat(m, Operations15.pYX, 1, 0, null, err: 0);
      await _testTwoArgFloat(m, Operations15.pYX, 0, 1, 1);
      await _testTwoArgFloat(m, Operations15.pYX, 0, 1.1, null, err: 0);
      await _testTwoArgFloat(m, Operations15.pYX, 0, 5, 1);
      await _testTwoArgFloat(m, Operations15.pYX, 1, 5, 5);
      await _testTwoArgFloat(m, Operations15.pYX, 2, 5, 20);
      await _testTwoArgFloat(m, Operations15.pYX, 3, 5, 60);
      await _testTwoArgFloat(m, Operations15.pYX, 4, 5, 120);
      await _testTwoArgFloat(m, Operations15.pYX, 5, 5, 120);
      await expect(m.getFlag(9), false);
      await _testTwoArgFloat(m, Operations15.pYX, 341, 357, 9.999999999e+99);
      await expect(m.getFlag(9), true);
      m.setFlag(9, false);
      await _testTwoArgFloat(m, Operations15.pYX, 7, 101, 8.668605053e13);
      await _testTwoArgFloat(m, Operations15.pYX, 15, 111, 1.777747078e30);
      await _testTwoArgFloat(m, Operations15.pYX, 21, 213, 2.840246967e48);
      await expect(m.getFlag(9), false);

      await _testTwoArgFloat(m, Operations15.cYX, 1, 0, null, err: 0);
      await _testTwoArgFloat(m, Operations15.cYX, 0, 1, 1);
      await _testTwoArgFloat(m, Operations15.cYX, 0, 1.1, null, err: 0);
      await _testTwoArgFloat(m, Operations15.cYX, 0, 5, 1);
      await _testTwoArgFloat(m, Operations15.cYX, 1, 5, 5);
      await _testTwoArgFloat(m, Operations15.cYX, 2, 5, 10);
      await _testTwoArgFloat(m, Operations15.cYX, 3, 5, 10);
      await _testTwoArgFloat(m, Operations15.cYX, 4, 5, 5);
      await _testTwoArgFloat(m, Operations15.cYX, 5, 5, 1);
      await _testTwoArgFloat(m, Operations15.cYX, 341, 357, 2.365542599e27);
      await expect(m.getFlag(9), false);
      await _testTwoArgFloat(m, Operations15.cYX, 3410, 3570, 9.999999999e99);
      await expect(m.getFlag(9), true);
      m.setFlag(9, false);
      await _testTwoArgFloat(
          m, Operations15.cYX, 10097, 10101, 433499141500425);
      // That's 10 places of accuracy, much more accurate than real 15C
      await expect(m.getFlag(9), false);
      await _testTwoArgFloat(m, Operations15.cYX, 10007, 10101, 9.999999999e99);
      await expect(m.getFlag(9), true);
      m.setFlag(9, false);
    });
  }

  @override
  Future<void> runAll() async {
    await testFloatFunctions();
    await testComplexFunctions();
    await testStatisticsFunctions();
    return super.runAll();
  }
}
