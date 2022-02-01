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

import 'package:jrpn/c/operations.dart';
import 'package:jrpn/m/complex.dart';
import 'package:jrpn/m/model.dart';
import 'package:jrpn/c/controller.dart';

import 'main15c.dart';

class SelfTests15 extends SelfTests {
  SelfTests15({bool inCalculator = true}) : super(inCalculator: inCalculator);

  @override
  Model15 newModel() => Model15();

  @override
  Controller newController(Model<Operation> model) => Controller15(model);

  Future<void> _testOneArgComplex(
      Model15 m, Operation op, Complex arg, Complex result,
      [Operation? inverse]) async {
    m.xC = arg;
    op.complexCalc!(m);
    await expect(m.x, Value.fromDouble(result.real));
    await expect(m.xImaginary, Value.fromDouble(result.imaginary));
    if (inverse != null) {
      return _testOneArgComplex(m, inverse, result, arg);
    }
  }

  Future<void> _testTwoArgComplex(
      Model15 m, Operation op, Complex x, Complex y, Complex result) async {
    m.xC = x;
    m.yC = y;
    op.complexCalc!(m);
    await expect(m.x, Value.fromDouble(result.real));
    await expect(m.xImaginary, Value.fromDouble(result.imaginary));
  }

  Future<void> _testOneArgFloat(
      Model15 m, Operation op, double arg, double result,
      [Operation? inverse]) async {
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
      Model15 m, Operation op, double x, double y, double result) async {
    m.xF = x;
    m.yF = y;
    op.floatCalc!(m);
    await expect(m.x, Value.fromDouble(result));
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
          m, Operations.lnOp, 2.37, 0.8628899551, Operations.eX15);
      await _testOneArgFloat(m, Operations.sqrtOp15, 7.37, 2.714774392);
      await _testOneArgFloat(m, Operations.xSquared, 2.714774392, 7.369999999);
      // On the real 15C, the xSquared result is that, too.
      await _testOneArgFloat(
          m, Operations.xSquared, 4, 16, Operations.sqrtOp15);
      await _testOneArgFloat(
          m, Operations.tenX15, 3.7, 5011.872336, Operations.logOp);
      await _testTwoArgFloat(m, Operations.yX15, 1.234, 5.678, 8.524660835);
      await _testOneArgFloat(
          m, Operations.reciprocal15, 0.01, 100, Operations.reciprocal15);
      await _testTwoArgFloat(
          m, Operations.deltaPercent, 5.678, 1.234, 360.1296596);
    });
  }

  Future<void> testComplexFunctions() async {
    await test('15c complex mode functions', () async {
      final m = newModel();
      m.isComplexMode = true;

      await _testOneArgComplex(m, Operations.lnOp, const Complex(1.234, 5.678),
          const Complex(1.759674471, 1.356794138));
      await _testOneArgComplex(
          m,
          Operations.eX15,
          const Complex(1.759674471, 1.356794138),
          const Complex(1.234000001, 5.678));
      await _testOneArgComplex(m, Operations.lnOp, const Complex(1.234, -5.678),
          const Complex(1.759674471, -1.356794138));
      await _testOneArgComplex(
          m,
          Operations.eX15,
          const Complex(1.759674471, -1.356794138),
          const Complex(1.234000001, -5.678));
      await _testOneArgComplex(m, Operations.lnOp, const Complex(-1.234, 5.678),
          const Complex(1.759674471, 1.784798515));
      await _testOneArgComplex(
          m,
          Operations.eX15,
          const Complex(1.759674471, 1.784798515),
          const Complex(-1.233999998, 5.678000001));
      await _testOneArgComplex(
          m,
          Operations.lnOp,
          const Complex(-1.234, -5.678),
          const Complex(1.759674471, -1.784798515));
      await _testOneArgComplex(
          m,
          Operations.eX15,
          const Complex(1.759674471, -1.784798515),
          const Complex(-1.233999998, -5.678000001));

      await _testOneArgComplex(m, Operations.sqrtOp15,
          const Complex(1.234, 5.678), const Complex(1.876771907, 1.512703802));
      await _testOneArgComplex(
          m,
          Operations.xSquared,
          const Complex(1.876771907, 1.512703802),
          const Complex(1.233999998, 5.677999998));
      await _testOneArgComplex(
          m,
          Operations.sqrtOp15,
          const Complex(1.234, -5.678),
          const Complex(1.876771907, -1.512703802));
      await _testOneArgComplex(
          m,
          Operations.xSquared,
          const Complex(1.876771907, -1.512703802),
          const Complex(1.233999998, -5.677999998));
      await _testOneArgComplex(
          m,
          Operations.sqrtOp15,
          const Complex(-1.234, 5.678),
          const Complex(1.512703802, 1.876771907));
      await _testOneArgComplex(
          m,
          Operations.xSquared,
          const Complex(1.512703802, 1.876771907),
          const Complex(-1.233999998, 5.677999998));
      await _testOneArgComplex(
          m,
          Operations.sqrtOp15,
          const Complex(-1.234, -5.678),
          const Complex(1.512703802, -1.876771907));
      await _testOneArgComplex(
          m,
          Operations.xSquared,
          const Complex(1.512703802, -1.876771907),
          const Complex(-1.233999998, -5.677999998));

      await _testOneArgComplex(
          m,
          Operations.tenX15,
          const Complex(-1.234, -5.678),
          const Complex(0.05098501197, -0.02836565620));
      // Note:  The above produces Complex(0.05098501197, -0.02836565619)
      //        on a real 15C.  Our answer is more accurate:  The answer is
      //        (5.09850119703065e-2, -2.83656561954365e-2) to 15 radix
      //        digits.  See misc/test_float/TestFloat.java.
      await _testOneArgComplex(
          m,
          Operations.logOp,
          const Complex(0.05098501197, -0.02836565620),
          const Complex(-1.234, -0.2204945847));

      await _testTwoArgComplex(
          m,
          Operations.yX15,
          const Complex(5.6, 7.8),
          const Complex(1.2, 3.4),
          const Complex(-0.03277613870, -0.08229096286));

      await _testOneArgComplex(
          m,
          Operations.reciprocal15,
          const Complex(0.15, 0.25),
          const Complex(1.764705882, -2.941176471),
          Operations.reciprocal15);
    });
  }

  @override
  Future<void> runAll() async {
    await testFloatFunctions();
    await testComplexFunctions();
    return super.runAll();
  }
}
