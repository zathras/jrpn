/*
Copyright (c) 2021-2024 William Foote

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

library;

import 'dart:math' as dart;

import 'package:flutter/foundation.dart';

import 'package:jrpn/c/controller.dart';
import 'package:jrpn/c/operations.dart';
import 'package:jrpn/c/states.dart';
import 'package:jrpn/m/complex.dart';
import 'package:jrpn/m/model.dart';
import 'package:jrpn/m/more_math.dart';

/// Pure-float operations shared by the HP-11C and HP-15C. Bodies are
/// byte-identical between Operations11 and Operations15 and don't depend
/// on target-specific model state.
///
/// Each scientific calculator inherits a *single* instance of every
/// declaration here. `OperationMap` init mutates per-instance state
/// (`rcName`) during boot — safe because 11C and 15C run in separate
/// processes, same contract as the shared ops in [Operations] itself.
class OperationsScientific extends Operations {

  static final letterLabelA = LetterLabel('A', 20);

  static final letterLabelB = LetterLabel('B', 21);

  static final letterLabelC = LetterLabel('C', 22);

  static final letterLabelD = LetterLabel('D', 23);

  static final letterLabelE = LetterLabel('E', 24);

  static final Set<LetterLabel> letterLabels = {
    letterLabelA,
    letterLabelB,
    letterLabelC,
    letterLabelD,
    letterLabelE,
  };

  static final List<LetterLabel> letterLabelsList =
      letterLabels.toList(growable: false);

  static final sqrtOp15 = NormalOperationOrLetter(
    Operations.sqrtOp,
    letterLabelA,
  );

  static final NormalOperation eX15 = NormalOperationOrLetter.floatOnly(
    letter: letterLabelB,
    floatCalc: (Model m) {
      double x = m.xF;
      m.resultXF = dart.pow(dart.e, x) as double;
    },
    complexCalc: (Model m) {
      m.resultXC = m.xC.exp();
    },
    name: 'eX',
  );

  static final NormalOperation xSquared = NormalOperationShiftedArg.floatOnly(
    argShift: Operations.gShift,
    programListingArgName: 'g A',
    floatCalc: (Model m) {
      final x = DecimalFP22(m.x);
      m.resultX = m.checkOverflow(() => (x * x).toValue());
    },
    complexCalc: (Model m) {
      final v = m.xCV;
      m.resultXCV = v.decimalMultiply(v, m.checkOverflow);
    },
    name: 'x^2',
  );

  static final NormalOperation lnOp = NormalOperationShiftedArg.floatOnly(
    argShift: Operations.gShift,
    programListingArgName: 'g B',
    floatCalc: (Model m) {
      double x = m.xF;
      if (x <= 0) {
        throw CalculatorError(0);
      }
      m.resultXF = _checkResult(() => dart.log(x), 0);
    },
    complexCalc: (Model m) {
      m.resultXC = _checkResultC(m.xC.ln, 0);
    },
    name: 'ln',
  );

  static final NormalOperation tenX15 = NormalOperationOrLetter.floatOnly(
    letter: letterLabelC,
    floatCalc: (Model m) {
      double x = m.xF;
      m.resultXF = dart.pow(10.0, x) as double;
    },
    complexCalc: (Model m) {
      m.resultXC = (m.xC * const Complex(dart.ln10, 0)).exp();
    },
    name: '10^x',
  );

  static final NormalOperation logOp = NormalOperationShiftedArg.floatOnly(
    programListingArgName: 'g C',
    argShift: Operations.gShift,
    floatCalc: (Model m) {
      double x = m.xF;
      if (x <= 0) {
        throw CalculatorError(0);
      }
      m.resultXF = dart.log(x) / dart.ln10;
    },
    complexCalc: (Model m) {
      m.resultXC = _checkResultC(m.xC.ln, 0) / const Complex(dart.ln10, 0);
    },
    name: 'log',
  );

  static final NormalOperation yX15 = NormalOperationOrLetter.floatOnly(
    letter: letterLabelD,
    floatCalc: (Model m) {
      if (m.x == Value.zero && m.y == Value.zero) {
        throw CalculatorError(0);
        // https://github.com/zathras/jrpn/issues/126
      }
      m.popSetResultXF = dart.pow(m.yF, m.xF) as double;
    },
    complexCalc: (Model m) {
      m.popSetResultXC = m.yC.pow(m.xC);
    },
    name: 'yX',
  );

  static final NormalOperation percent = NormalOperationShiftedArg.floatOnly(
    programListingArgName: 'g D',
    argShift: Operations.gShift,
    floatCalc: (Model m) {
      final x = DecimalFP12(m.x);
      final y = DecimalFP12(m.y);
      final hundred = DecimalFP12(Value.fromDouble(100));
      m.resultX = m.checkOverflow(() => ((x * y) / hundred).toValue());
    },
    name: '%',
  );

  static final NormalOperation deltaPercent =
      NormalOperationShiftedArg.floatOnly(
        programListingArgName: 'g E',
        argShift: Operations.gShift,
        floatCalc: (Model m) {
          final x = DecimalFP12(m.x);
          final y = DecimalFP12(m.y);
          final hundred = DecimalFP12(Value.fromDouble(100));
          final result = ((x - y) / y) * hundred;
          m.resultX = m.checkOverflow(() => result.toValue());
        },
        name: 'delta%',
      );

  static final NormalOperation piOp = NormalOperation.floatOnly(
    pressed: (ActiveState s) => s.liftStackIfEnabled(),
    floatCalc: (Model m) {
      m.resultXF = dart.pi;
    },
    name: 'PI',
  );

  static final NormalOperation iOp = NormalOperation.floatOnly(
    floatCalc: (Model m) {
      m.isComplexMode = true;
      iOp.complexCalc!(m);
    },
    complexCalc: (Model m) {
      final im = m.x;
      m.popStack();
      m.xImaginary = im;
    },
    name: 'I',
  );

  static final NormalOperation parenIOp = NonProgrammableOperation(
    pressed: (LimitedState cs) => cs.handleShowImaginary(),
    name: '(i)',
  );

  static final NormalOperation deg = NormalOperation.floatOnly(
    floatCalc: (Model m) {
      m.trigMode = TrigMode.deg;
    },
    name: 'DEG',
  );

  static final NormalOperation rad = NormalOperation.floatOnly(
    floatCalc: (Model m) {
      m.trigMode = TrigMode.rad;
    },
    name: 'RAD',
  );

  static final NormalOperation grd = NormalOperation.floatOnly(
    floatCalc: (Model m) {
      m.trigMode = TrigMode.grad;
    },
    name: 'GRD',
  );

  static final hyp = NonProgrammableOperation(
    pressed: (LimitedState c) => c.handleShift(ShiftKey.none),
    // Controller subclass handles the rest
    name: 'HYP',
  );

  static final hypInverse = NonProgrammableOperation(
    pressed: (LimitedState c) => c.handleShift(ShiftKey.none),
    name: 'HYP-1',
  );

  static final NormalOperation sin = NormalOperation.floatOnly(
    floatCalc: (Model m) {
      m.resultXF = sin15(m.x, m.trigMode);
    },
    complexCalc: (Model m) {
      // Always in radians - see 15C manual p. 131, "For the trigonometric..."
      m.resultXC = m.xC.sin();
    },
    name: 'SIN',
  );

  static final NormalOperation sinInverse = NormalOperation.floatOnly(
    floatCalc: (Model m) {
      m.resultXF = dart.asin(m.xF) / m.trigMode.scaleFactor;
    },
    complexCalc: (Model m) {
      // Always in radians - see 15C manual p. 131, "For the trigonometric..."
      m.resultXC = m.xC.asin();
    },
    name: 'SIN-1',
  );

  static final NormalOperation cos = NormalOperation.floatOnly(
    floatCalc: (Model m) {
      m.resultXF = cos15(m.x, m.trigMode);
    },
    complexCalc: (Model m) {
      // Always in radians - see 15C manual p. 131, "For the trigonometric..."
      m.resultXC = m.xC.cos();
    },
    name: 'COS',
  );

  static final NormalOperation cosInverse = NormalOperationShiftedArg.floatOnly(
    argShift: Operations.gShift,
    programListingArgName: 'g (i)',
    floatCalc: (Model m) {
      m.resultXF = dart.acos(m.xF) / m.trigMode.scaleFactor;
    },
    complexCalc: (Model m) {
      // Always in radians - see 15C manual p. 131, "For the trigonometric..."
      m.resultXC = m.xC.acos();
    },
    name: 'COS-1',
  );

  static final NormalOperation tan = NormalOperation.floatOnly(
    floatCalc: (Model m) {
      m.resultXF = tan15(m.x, m.trigMode);
    },
    complexCalc: (Model m) {
      // Always in radians - see 15C manual p. 131, "For the trigonometric..."
      m.resultXC = m.xC.tan();
    },
    name: 'TAN',
  );

  static final NormalOperation tanInverse = NormalOperation.floatOnly(
    floatCalc: (Model m) {
      m.resultXF = dart.atan(m.xF) / m.trigMode.scaleFactor;
    },
    complexCalc: (Model m) {
      // Always in radians - see 15C manual p. 131, "For the trigonometric..."
      m.resultXC = m.xC.atan();
    },
    name: 'TAN-1',
  );

  static final NormalOperation sinh = NormalOperation.floatOnly(
    floatCalc: (Model m) {
      m.resultXF = Real.sinh(m.xF);
    },
    complexCalc: (Model m) {
      // Always in radians - see 15C manual p. 131, "For the trigonometric..."
      m.resultXC = m.xC.sinh();
    },
    name: 'SINH',
  );

  static final NormalOperation sinhInverse = NormalOperation.floatOnly(
    floatCalc: (Model m) {
      m.resultXF = Real.asinh(m.xF);
    },
    complexCalc: (Model m) {
      // Always in radians - see 15C manual p. 131, "For the trigonometric..."
      m.resultXC = m.xC.asinh();
    },
    name: 'SINH-1',
  );

  static final NormalOperation cosh = NormalOperation.floatOnly(
    floatCalc: (Model m) {
      m.resultXF = Real.cosh(m.xF);
    },
    complexCalc: (Model m) {
      // Always in radians - see 15C manual p. 131, "For the trigonometric..."
      m.resultXC = m.xC.cosh();
    },
    name: 'COSH',
  );

  static final NormalOperation coshInverse = NormalOperation.floatOnly(
    floatCalc: (Model m) {
      m.resultXF = Real.acosh(m.xF);
    },
    complexCalc: (Model m) {
      // Always in radians - see 15C manual p. 131, "For the trigonometric..."
      m.resultXC = m.xC.acosh();
    },
    name: 'COSH-1',
  );

  static final NormalOperation tanh = NormalOperation.floatOnly(
    floatCalc: (Model m) {
      m.resultXF = Real.tanh(m.xF);
    },
    complexCalc: (Model m) {
      // Always in radians - see 15C manual p. 131, "For the trigonometric..."
      m.resultXC = m.xC.tanh();
    },
    name: 'TANH',
  );

  static final NormalOperation tanhInverse = NormalOperation.floatOnly(
    floatCalc: (Model m) {
      m.resultXF = Real.atanh(m.xF);
    },
    complexCalc: (Model m) {
      // Always in radians - see 15C manual p. 131, "For the trigonometric..."
      m.resultXC = m.xC.atanh();
    },
    name: 'TANH-1',
  );

  static final NormalOperation lstx15 = NormalOperation.floatOnly(
    pressed: (ActiveState s) => s.liftStackIfEnabled(),
    floatCalc: (Model m) {
      m.x = m.lastX;
      m.display.displayX();
    },
    complexCalc: (Model m) {
      m.x = m.lastX;
      m.xImaginary = m.lastXImaginary;
      m.display.displayX();
    },
    name: 'LSTx',
  );

  static final NormalOperation toR = NormalOperation.floatOnly(
    floatCalc: (Model m) {
      double r = m.xF;
      double theta = m.yF;
      m.resultXF = r * dart.cos(theta * m.trigMode.scaleFactor);
      m.yF = r * dart.sin(theta * m.trigMode.scaleFactor);
    },
    complexCalc: (Model m) {
      Complex v = m.xC;
      m.resultXC = Complex(
        v.real * dart.cos(v.imaginary * m.trigMode.scaleFactor),
        v.real * dart.sin(v.imaginary * m.trigMode.scaleFactor),
      );
    },
    name: '->R',
  );

  static final NormalOperation toP = NormalOperation.floatOnly(
    floatCalc: (Model m) {
      double x = m.xF;
      double y = m.yF;
      m.resultXF = dart.sqrt(x * x + y * y);
      m.yF = dart.atan2(y, x) / m.trigMode.scaleFactor;
    },
    complexCalc: (Model m) {
      Complex v = m.xC;
      m.resultXC = Complex(
        dart.sqrt(v.real * v.real + v.imaginary * v.imaginary),
        dart.atan2(v.imaginary, v.real) / m.trigMode.scaleFactor,
      );
    },
    name: '->P',
  );

  static final NormalOperation toHMS = NormalOperation.floatOnly(
    floatCalc: convertHtoHMS,
    name: '->H.MS',
  );

  static final NormalOperation toH = NormalOperation.floatOnly(
    floatCalc: convertHMStoH,
    name: '->H',
  );

  static final NormalOperation toRad = NormalOperation.floatOnly(
    floatCalc: (Model m) {
      m.resultXF = m.xF * dart.pi / 180;
    },
    name: '->RAD',
  );

  static final NormalOperation toDeg = NormalOperation.floatOnly(
    floatCalc: (Model m) {
      m.resultXF = 180 * m.xF / dart.pi;
    },
    name: '->DEG',
  );

  static final NormalOperation fracOp = NormalOperation.floatOnly(
    floatCalc: (Model m) {
      m.resultX = m.x.fracOp();
    },
    name: 'FRAC',
  );

  static final NormalOperation intOp = NormalOperation.floatOnly(
    floatCalc: (Model m) {
      m.resultX = m.x.intOp();
    },
    name: 'INT',
  );

  static final NormalOperation xFactorial = NormalOperation.floatOnly(
    floatCalc: (Model m) {
      m.resultX = m.checkOverflow(() => factorial(m.x));
    },
    name: 'x!',
  );

  static final NormalOperation rnd = NormalOperation.floatOnly(
    floatCalc: (Model m) {
      m.resultX = m.displayMode.round(m.x);
    },
    name: 'RND',
  );

  static final NormalOperation xBar = StackLiftingNormalOperation.floatOnly(
    floatCalc: (Model m) {
      final s = m.statsRegisters;
      final denom = m.memory.registers[s.n];
      m.x = m.checkOverflow(() => m.memory.registers[s.sumY].decimalDivideBy(denom));
      // Don't set LastX - checked on 15C
      m.pushStack();
      m.x = m.checkOverflow(() => m.memory.registers[s.sumX].decimalDivideBy(denom));
    },
    needsStackLiftIfEnabled: _statsLift,
    name: 'xBar',
  );

  static final NormalOperation yHatR = NormalOperation.floatOnly(
    floatCalc: (Model m) {
      final lr = LinearRegression(m.memory.registers, m.statsRegisters);
      final x = m.x;
      m.resultX = m.checkOverflow(() => lr.r.toValue());
      // Do set LastX - checked on 15C.
      m.pushStack();
      // We do push the stack, without regard to stack lift.  This is how
      // the real 15C behaves, and is checked with a regression test.
      m.y = m.checkOverflow(() => lr.r.toValue());
      m.x = m.checkOverflow(() => lr.yHat(DecimalFP22(x)).toValue());
    },
    name: 'yHat,r',
  );

  static final NormalOperation stdDeviation =
      StackLiftingNormalOperation.floatOnly(
        floatCalc: (Model m) {
          final s = m.statsRegisters;
          final n = m.memory.registers[s.n];
          m.x = m.checkOverflow(
              () => _stdDev(m.memory.registers, s.sumY, s.sumYSq, n));
          // Don't set LastX - checked on 15C
          m.pushStack();
          m.x = m.checkOverflow(
              () => _stdDev(m.memory.registers, s.sumX, s.sumXSq, n));
        },
        needsStackLiftIfEnabled: (m) =>
            _statsLift(m) && m.memory.registers[m.statsRegisters.n] != Value.oneF,
        name: 's',
      );

  static final NormalOperation linearRegression =
      StackLiftingNormalOperation.floatOnly(
        floatCalc: (Model m) {
          final lr = LinearRegression(m.memory.registers, m.statsRegisters);
          m.x = m.checkOverflow(() => lr.slope.toValue());
          // Don't set LastX - checked on 15C
          m.pushStack();
          m.x = m.checkOverflow(() => lr.yIntercept.toValue());
        },
        needsStackLiftIfEnabled: (m) {
          LinearRegression(m.memory.registers, m.statsRegisters); // Throws if error
          return true;
        },
        name: 'L.R.',
      );

  static final NormalOperation sigmaPlus = NormalOperation.floatOnly(
    stackLift: StackLift.disable,
    floatCalc: (Model m) {
      final s = m.statsRegisters;
      final reg = m.memory.registers;
      final x = DecimalFP22(m.x);
      final y = DecimalFP22(m.y);
      reg[s.sumXY] = m.checkOverflow(() => (DecimalFP22(reg[s.sumXY]) + x * y).toValue());
      reg[s.sumYSq] = m.checkOverflow(() => (DecimalFP22(reg[s.sumYSq]) + y * y).toValue());
      reg[s.sumY] = m.checkOverflow(() => (DecimalFP22(reg[s.sumY]) + y).toValue());
      reg[s.sumXSq] = m.checkOverflow(() => (DecimalFP22(reg[s.sumXSq]) + x * x).toValue());
      reg[s.sumX] = m.checkOverflow(() => (DecimalFP22(reg[s.sumX]) + x).toValue());
      final newReg = m.checkOverflow(() => reg[s.n].decimalAdd(Value.oneF));
      reg[s.n] = newReg;
      if (m.isComplexMode) {
        m.lastXCV = m.xCV;
        m.xCV = ComplexValue(newReg, m.xCV.imaginary);
      } else {
        m.lastX = m.x;
        m.x = newReg;
      }
    },
    name: 'E+',
  );

  static final NormalOperation sigmaMinus = NormalOperation.floatOnly(
    stackLift: StackLift.disable,
    floatCalc: (Model m) {
      final s = m.statsRegisters;
      final reg = m.memory.registers;
      final x = DecimalFP22(m.x);
      final y = DecimalFP22(m.y);
      reg[s.sumXY] = m.checkOverflow(() => (DecimalFP22(reg[s.sumXY]) - x * y).toValue());
      reg[s.sumYSq] = m.checkOverflow(() => (DecimalFP22(reg[s.sumYSq]) - y * y).toValue());
      reg[s.sumY] = m.checkOverflow(() => (DecimalFP22(reg[s.sumY]) - y).toValue());
      reg[s.sumXSq] = m.checkOverflow(() => (DecimalFP22(reg[s.sumXSq]) - x * x).toValue());
      reg[s.sumX] = m.checkOverflow(() => (DecimalFP22(reg[s.sumX]) - x).toValue());
      final newReg = m.checkOverflow(() => reg[s.n].decimalSubtract(Value.oneF));
      reg[s.n] = newReg;
      if (m.isComplexMode) {
        m.lastXCV = m.xCV;
        m.xCV = ComplexValue(newReg, m.xCV.imaginary);
      } else {
        m.lastX = m.x;
        m.x = reg[s.n];
      }
    },
    name: 'E-',
  );

  static final NormalOperation clearSigma = NormalOperation.floatOnly(
    floatCalc: (Model m) {
      for (final i in m.statsRegisters.all) {
        m.memory.registers[i] = Value.zero;
      }
      m.setXYZT(Value.zero);
    },
    name: 'CLEAR-E',
  );

  static final NormalArgOperation fix = NormalArgOperation(
    stackLift: StackLift.neutral,
    maxOneByteOpcodes: 0,
    arg: PrecisionArg(
      f: (m, v) => m.displayMode = DisplayMode.fix(v, m.isComplexMode),
    ),
    name: 'FIX',
  );

  static final NormalArgOperation sci = NormalArgOperation(
    stackLift: StackLift.neutral,
    maxOneByteOpcodes: 0,
    arg: PrecisionArg(
      f: (m, v) => m.displayMode = DisplayMode.sci(v, m.isComplexMode),
    ),
    name: 'SCI',
  );

  static final NormalArgOperation eng = NormalArgOperation(
    stackLift: StackLift.neutral,
    maxOneByteOpcodes: 0,
    arg: PrecisionArg(
      f: (m, v) => m.displayMode = DisplayMode.eng(v, m.isComplexMode),
    ),
    name: 'SCI',
  );

  static final NormalArgOperation gsb = RunProgramOperation(
    maxOneByteOpcodes:
        16, // The user's guide is wrong on p. 218, GSB .0-.9 are two-byte
    runner: () => GosubProgramRunner(),
    arg: LabelArg(
      maxDigit: 19,
      letters: letterLabelsList,
      iFirst: true,
      negativeIsLineNumber: true,
      f: (m, final int? label) {
        if (label == null) {
          throw CalculatorError(4);
        }
        m.memory.program.gosub(label);
      },
    ),
    name: 'GSB',
  );

  static final NormalArgOperation gto = NormalArgOperation(
    maxOneByteOpcodes: 16, // I, A..E, 0..9.  .0-.9 are two byte.
    arg: LabelArg(
      iFirst: true,
      maxDigit: 19,
      letters: letterLabelsList,
      negativeIsLineNumber: true,
      f: (m, final int? label) {
        if (label == null) {
          throw CalculatorError(4);
        }
        m.memory.program.goto(label);
      },
    ),
    name: 'GTO',
  );

  static bool _statsLift(Model m) {
    final s = m.statsRegisters;
    m.memory.registers[s.sumXY]; // Throw exception if not valid
    if (m.memory.registers[s.n] == Value.zero) {
      throw CalculatorError(0);
    }
    return true;
  }

  static Value _stdDev(Registers r, int sumR, int sumSqR, Value nV) {
    final n = DecimalFP22(nV);
    final sum = DecimalFP22(r[sumR]);
    final sumSq = DecimalFP22(r[sumSqR]);
    final m = n * sumSq - sum * sum;
    return Value.fromDouble(
      dart.sqrt(m.asDouble / (n.asDouble * (n.asDouble - 1))),
    );
  }

  static double _checkResult(double Function() f, int errNo) {
    try {
      final v = f();
      if (!v.isNaN) {
        return v;
      }
    } catch (ex) {
      debugPrint('Converting $ex to CalculatorException($errNo)');
    }
    throw CalculatorError(errNo);
  }

  static Complex _checkResultC(Complex Function() f, int errNo) {
    try {
      final v = f();
      if (!v.real.isNaN && !v.imaginary.isNaN) {
        return v;
      }
    } catch (ex) {
      debugPrint('Converting $ex to CalculatorException($errNo)');
    }
    throw CalculatorError(errNo);
  }
}

///
/// The argument to the FIX, SCI and ENG keys.
///
class PrecisionArg extends ArgAlternates {
  final void Function(Model m, int v) f;

  static int _translate(Model m, Value v) =>
      dart.min(9, dart.max(0, v.floatIntPart()));

  PrecisionArg({required this.f})
    : super(
        synonyms: Arg.registerISynonyms,
        children: [
          DigitArg(max: 9, calc: (m, i) => f(m, i)),
          KeyArg(
            key: Arg.kI,
            child: ArgDone(
              (m) => f(m, _translate(m, m.memory.registers.index)),
            ),
          ),
        ],
      );
}
