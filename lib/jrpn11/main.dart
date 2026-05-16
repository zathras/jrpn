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

import 'package:flutter/material.dart';
import 'package:jrpn/c/controller.dart';
import 'package:jrpn/c/operations.dart';
import 'package:jrpn/c/states.dart';
import 'package:jrpn/generic_main.dart';
import 'package:jrpn/m/complex.dart';
import 'package:jrpn/m/model.dart';
import 'package:jrpn/v/buttons.dart';
import 'package:jrpn/v/main_screen.dart';
import 'package:jrpn/v/isw.dart';

import 'back_panel11c.dart';
import 'tests11c.dart';
import 'model11c.dart';
import 'more_math.dart';

void main(List<String> args) async {
  if (!await InternalStateWindow.takeControl(args)) {
    runStaticInitialization11();
    genericMain(Jrpn(Controller11(createModel11())));
  }
}

void runStaticInitialization11() {
  // None of these operations has an argument, so there is no circular
  // initialization here.
  Arg.kI = Operations11.I15;
  Arg.kParenI = Operations11.parenI15;
  Arg.kDigits = Controller11.numbers;
  Arg.kDot = Operations.dot;
  Arg.fShift = Operations.fShift;
  Arg.gShift = Operations.gShift;
  Arg.registerISynonyms = Operations11._registerISynonyms;
  Arg.gsbLabelSynonyms = Operations11._letterAndRegisterISynonyms;
  assert(Arg.assertStaticInitialized());
}

Model11<Operation> createModel11() {
  return Model11<Operation>(() => _logicalKeys, _newProgramInstruction);
}

class Operations11 extends Operations {
  static final letterLabelA = LetterLabel('A', 20);
  static final letterLabelB = LetterLabel('B', 21);
  static final letterLabelC = LetterLabel('C', 22);
  static final letterLabelD = LetterLabel('D', 23);
  static final letterLabelE = LetterLabel('E', 24);
  // The numeric values match the I register values for GSB I, as per the
  // table on page 107 of the 15C manual.

  static final _registerISynonyms = {
    Operations11.tan: Operations11.I15,
    Operations11.cos: Operations11.parenI15,
  };

  static final _letterSynonyms = {
    Operations11.sqrtOp15: Operations11.letterLabelA,
    Operations11.eX15: Operations11.letterLabelB,
    Operations11.tenX15: Operations11.letterLabelC,
    Operations11.yX15: Operations11.letterLabelD,
    Operations11.reciprocal15: Operations11.letterLabelE,
  };

  static final _letterAndRegisterISynonyms = {
    ..._letterSynonyms,
    ..._registerISynonyms,
  };

  static final NormalArgOperation lbl15 = NormalArgOperation(
    maxOneByteOpcodes: 15,
    arg: ArgAlternates(
      synonyms: _letterSynonyms,
      children: [
        KeyArg(key: letterLabelA, child: ArgDone((m) {})),
        KeyArg(key: letterLabelB, child: ArgDone((m) {})),
        KeyArg(key: letterLabelC, child: ArgDone((m) {})),
        KeyArg(key: letterLabelD, child: ArgDone((m) {})),
        KeyArg(key: letterLabelE, child: ArgDone((m) {})),
        DigitArg(max: 19, calc: (_, _) {}),
      ],
    ),
    name: 'LBL',
  );

  static final NormalOperation div = NormalOperation.floatOnly(
    floatCalc: (Model m) {
      m.popSetResultX = m.checkOverflow(() => m.y.decimalDivideBy(m.x));
    },
    complexCalc: (Model m) {
      if (m.xC == Complex.zero) {
        throw CalculatorError(0);
      }
      m.popSetResultXCV = m.yCV.decimalDivideBy(m.xCV, m.checkOverflow);
    },
    name: '/',
  );

  static final NormalOperation mult = NormalOperation.floatOnly(
    floatCalc: (Model m) {
      m.popSetResultX = m.checkOverflow(() => m.y.decimalMultiply(m.x));
    },
    complexCalc: (Model m) {
      m.popSetResultXCV = m.yCV.decimalMultiply(m.xCV, m.checkOverflow);
    },
    name: '*',
  );

  static final NormalOperation plus = NormalOperation.floatOnly(
    floatCalc: (Model m) {
      m.popSetResultX = m.checkOverflow(() => m.y.decimalAdd(m.x));
    },
    complexCalc: (Model m) {
      m.popSetResultXCV = m.yCV.decimalAdd(m.xCV, m.checkOverflow);
    },
    name: '+',
  );

  static final NormalOperation minus = NormalOperation.floatOnly(
    floatCalc: (Model m) {
      m.popSetResultX = m.checkOverflow(() => m.y.decimalSubtract(m.x));
    },
    complexCalc: (Model m) {
      m.popSetResultXCV = m.yCV.decimalSubtract(m.xCV, m.checkOverflow);
    },
    name: '-',
  );

  ///
  /// The HP15'c I operation, for entry of imaginary numbers.
  ///
  // ignore: non_constant_identifier_names
  static final NormalOperation I15 = NormalOperation.floatOnly(
    floatCalc: (Model m) {
      m.isComplexMode = true;
      I15.complexCalc!(m);
    },
    complexCalc: (Model m) {
      final im = m.x;
      m.popStack();
      m.xImaginary = im;
    },
    name: 'I',
  );

  ///
  /// The HP 15's (i) operation, to see the imaginary part.
  ///
  static final NormalOperation parenI15 = NonProgrammableOperation(
    pressed: (LimitedState cs) => cs.handleShowImaginary(),
    name: '(i)',
  );

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

  static final NormalOperationOrLetter reciprocal15 =
      NormalOperationOrLetter.floatOnly(
        letter: letterLabelE,
        floatCalc: (Model m) {
          Value x = m.x;
          final one = DecimalFP12.tenTo(0);
          m.resultX = m.checkOverflow(() => (one / DecimalFP12(x)).toValue());
        },
        complexCalc: (Model m) {
          final one = ComplexValue(Value.fromDouble(1), Value.zero);
          m.resultXCV = one.decimalDivideBy(m.xCV, m.checkOverflow);
        },
        name: '1/x',
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
  static final NormalArgOperation fix = NormalArgOperation(
    stackLift: StackLift.neutral,
    maxOneByteOpcodes: 0,
    arg: PrecisionArg(
      f: (m, v) => m.displayMode = DisplayMode.fix(v, m.isComplexMode),
    ),
    name: 'FIX',
  );

  static final NormalArgOperation sf = NormalArgOperation(
    maxOneByteOpcodes: 0,
    arg: LabelArg(
      maxDigit: 1,
      noI: true,
      f: (m, v) => m.setFlag(v ?? 999, true),
    ),
    name: 'SF',
  );

  static final NormalArgOperation cf = NormalArgOperation(
    maxOneByteOpcodes: 0,
    arg: LabelArg(
      maxDigit: 1,
      noI: true,
      f: (m, v) => m.setFlag(v ?? 999, false),
    ),
    name: 'CF',
  );

  static final fQuestion = NormalArgOperation(
    maxOneByteOpcodes: 0,
    arg: LabelArg(
      maxDigit: 1,
      noI: true,
      f: (m, v) => m.program.doNextIf(m.getFlag(v ?? 99)),
    ),
    name: 'F?',
  );

  static final NormalArgOperation gsb = RunProgramOperation(
    maxOneByteOpcodes:
        16, // The user's guide is wrong on p. 218, GSB .0-.9 are two-byte
    runner: () => GosubProgramRunner(),
    arg: LabelArg(
      maxDigit: 19,
      letters: _letterLabelsList,
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
      letters: _letterLabelsList,
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
    // Controller11 handles the rest
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

  static final _stoRclSynonyms = {
    Operations.enter: Operations11.ranNum,
  };

  static final NormalOperation piOp = NormalOperation.floatOnly(
    pressed: (ActiveState s) => s.liftStackIfEnabled(),
    floatCalc: (Model m) {
      m.resultXF = dart.pi;
    },
    name: 'PI',
  );
  static final NormalArgOperation xExchange = NormalArgOperation(
    maxOneByteOpcodes: 4,
    arg: RegisterWriteOpArg(
      maxDigit: 19,
      f: (m, reg, x) {
        m.x = reg;
        return x;
      },
    ),
    name: 'x<->',
  );
  static final NormalOperation dse = NormalOperation.floatOnly(
    floatCalc: (Model m) {
      m.memory.registers.index = _skipIf(
        m,
        m.memory.registers.index,
        (n, x) => n <= x,
        (n, y) => n - y,
      );
    },
    name: 'DSE',
  );

  static final NormalOperation isg = NormalOperation.floatOnly(
    floatCalc: (Model m) {
      m.memory.registers.index = _skipIf(
        m,
        m.memory.registers.index,
        (n, x) => n > x,
        (n, y) => n + y,
      );
    },
    name: 'ISG',
  );

  static Value _skipIf(
    Model m,
    Value val,
    bool Function(DecimalFP12 n, DecimalFP12 x) skip,
    DecimalFP12 Function(DecimalFP12 n, DecimalFP12 y) f,
  ) {
    var n = DecimalFP12(val.intOp());
    final fracV = val.fracOp().timesTenTo(5).intOp().abs();
    final int frac = fracV.floatIntPart();
    final int x = frac ~/ 100;
    final int y = frac % 100;
    n = f(n, DecimalFP12(Value.fromDouble(dart.max(1, y).toDouble())));
    if (skip(n, DecimalFP12(Value.fromDouble(x.toDouble())))) {
      m.program.incrementCurrentLine(); // Even if not running
    }
    if (n.isNegative) {
      n = n - DecimalFP12(fracV) * DecimalFP12.tenTo(-5);
    } else {
      n = n + DecimalFP12(fracV) * DecimalFP12.tenTo(-5);
    }
    return n.toValue();
  }

  static final NormalOperation clearSigma = NormalOperation.floatOnly(
    floatCalc: (Model m) {
      for (final i in m.statsRegisters.all) {
        m.memory.registers[i] = Value.zero;
      }
      m.setXYZT(Value.zero);
    },
    name: 'CLEAR-E',
  );
  static final NormalOperation rnd = NormalOperation.floatOnly(
    floatCalc: (Model m) {
      m.resultX = m.displayMode.round(m.x);
    },
    name: 'RND',
  );
  static final NormalOperation ranNum = NormalOperation.floatOnly(
    pressed: (ActiveState s) => s.liftStackIfEnabled(),
    floatCalc: (Model m) {
      m.resultXF = (m as Model11).rand.nextValue;
    },
    name: 'RAN #',
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
  static final userOp = NonProgrammableOperation(
    endsDigitEntry: true,
    calc: (_) {},
    pressed: (LimitedState s) {
      final m = s.model as Model11;
      m.userMode = !m.userMode;
      m.display.update(flash: true); // Needed in program entry mode
    },
    name: 'USER',
  );
  static final NormalOperation xFactorial = NormalOperation.floatOnly(
    floatCalc: (Model m) {
      m.resultX = m.checkOverflow(() => factorial(m.x));
    },
    name: 'x!',
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
          LinearRegression(m.memory.registers, m.statsRegisters); // Throw exception if error
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
  static final NormalOperation pYX = NormalOperation.floatOnly(
    floatCalc: (Model m) {
      m.popSetResultX = m.checkOverflow(() => permutations(m.y, m.x));
    },
    name: 'Py,x',
  );
  static final NormalOperation cYX = NormalOperation.floatOnly(
    floatCalc: (Model m) {
      m.popSetResultX = m.checkOverflow(() => binomialCoefficient(m.y, m.x));
    },
    name: 'Cy,x',
  );


  static final NormalArgOperation sto15 = NormalArgOperation(
    maxOneByteOpcodes: 34,
    arg: ArgAlternates(
      synonyms: _stoRclSynonyms,
      children: [
        // 0-.9, I
        RegisterWriteArg(
          maxDigit: 19,
          noParenI: true,
          f: (m) => m.x,
        ), // 21 opcodes
        KeyArg(
          key: Operations11.ranNum,
          child: ArgDone(((m) {
            (m as Model11).rand.setSeed(m.xF);
          })),
        ),
        KeyArg(
          key: Operations11.plus,
          child: RegisterWriteOpArg(
            maxDigit: 19,
            f: (m, r, x) => m.checkOverflow(
              () => (DecimalFP12(r) + DecimalFP12(x)).toValue(),
            ),
          ),
        ),
        KeyArg(
          key: Operations11.minus,
          child: RegisterWriteOpArg(
            maxDigit: 19,
            f: (m, r, x) => m.checkOverflow(
              () => (DecimalFP12(r) - DecimalFP12(x)).toValue(),
            ),
          ),
        ),
        KeyArg(
          key: Operations11.mult,
          child: RegisterWriteOpArg(
            maxDigit: 19,
            f: (m, r, x) => m.checkOverflow(
              () => (DecimalFP12(r) * DecimalFP12(x)).toValue(),
            ),
          ),
        ),
        KeyArg(
          key: Operations11.div,
          child: RegisterWriteOpArg(
            maxDigit: 19,
            f: (m, r, x) => m.checkOverflow(
              () => (DecimalFP12(r) / DecimalFP12(x)).toValue(),
            ),
          ),
        ),
      ],
    ),
    name: 'STO',
  );

  static final NormalArgOperation rcl15 = NormalArgOperationWithBeforeCalc(
    beforeCalculate: (Resting s) {
      s.liftStackIfEnabled();
      return StackLift.neutral;
      // Stack lift is set after the calculation completes, as with
      // normal operations.
    },
    arg: ArgAlternates(
      synonyms: _stoRclSynonyms,
      children: [
        RegisterReadArg(maxDigit: 19, noParenI: true, f: (m, v) => m.x = v),
        KeyArg(
          key: Operations11.ranNum,
          child: ArgDone(((m) {
            m.xF = (m as Model11).rand.lastValue;
          })),
        ),
        KeyArg(
          key: Operations11.sigmaPlus,
          child: StackLiftingArgDone(
            (m) {
              final s = m.statsRegisters;
              m.x = m.memory.registers[s.sumY]; // Don't set lastX
              m.pushStack();
              m.x = m.memory.registers[s.sumX];
            },
            needsStackLiftIfEnabled: (m) =>
                (m as Model11).memory.numRegisters >= 6,
          ),
        ),
      ],
    ),
    name: 'RCL',
  );

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
/// The argument to the 15C's FIX, SCI and ENG keys
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

class RegisterWriteOpArg extends ArgAlternates {
  final Value Function(Model m, Value reg, Value x) f;

  RegisterWriteOpArg({required int maxDigit, required this.f})
    : super(
        synonyms: Operations11._registerISynonyms,
        children: [
          KeyArg(
            key: Arg.kParenI,
            child: ArgDone((m) {
              m.memory.registers.indirectIndex = f(
                m,
                m.memory.registers.indirectIndex,
                m.x,
              );
            }),
          ),
          KeyArg(
            key: Arg.kI,
            child: ArgDone(
              (m) => m.memory.registers.index = f(
                m,
                m.memory.registers.index,
                m.x,
              ),
            ),
          ),
          DigitArg(
            max: maxDigit,
            calc: (m, i) =>
                m.memory.registers[i] = f(m, m.memory.registers[i], m.x),
          ),
        ],
      );
}

///
/// The layout of the buttons (part of the view, but retrieved by the
/// controller as part of initialization).
///
class ButtonLayout11 extends ButtonLayout {
  final ButtonFactory factory;
  final double _totalButtonHeight;
  final double _buttonHeight;

  ButtonLayout11(this.factory, this._totalButtonHeight, this._buttonHeight);

  CalculatorButton get sqrt => CalculatorWhiteSqrtButton(
    factory,
    '\u221Ax',
    'A',
    'x^2',
    Operations11.sqrtOp15,
    Operations11.letterLabelA,
    Operations11.xSquared,
    'A',
  );
  CalculatorButton get eX => CalculatorButton(
    factory,
    'e^x',
    'B',
    'LN',
    Operations11.eX15,
    Operations11.letterLabelB,
    Operations11.lnOp,
    'B',
  );
  CalculatorButton get tenX => CalculatorButton(
    factory,
    '10^x',
    'C',
    'LOG',
    Operations11.tenX15,
    Operations11.letterLabelC,
    Operations11.logOp,
    'C',
  );
  CalculatorButton get yX => CalculatorButton(
    factory,
    'y^x',
    'D',
    '%',
    Operations11.yX15,
    Operations11.letterLabelD,
    Operations11.percent,
    'D',
  );
  CalculatorButton get reciprocal => CalculatorButton(
    factory,
    '1/x',
    'E',
    '\u0394%',
    Operations11.reciprocal15,
    Operations11.letterLabelE,
    Operations11.deltaPercent,
    'E',
  );
  CalculatorButton get chs => CalculatorButton(
    factory,
    'CHS',
    '\u03c0',
    'ABS',
    Operations.chs,
    Operations11.piOp,
    Operations.abs,
    'H',
  );
  CalculatorButton get n7 => CalculatorButton(
    factory,
    '7',
    'FIX',
    'DEG',
    Operations.n7,
    Operations11.fix,
    Operations11.deg,
    '7',
  );
  CalculatorButton get n8 => CalculatorButton(
    factory,
    '8',
    'SCI',
    'RAD',
    Operations.n8,
    Operations11.sci,
    Operations11.rad,
    '8',
  );
  CalculatorButton get n9 => CalculatorButton(
    factory,
    '9',
    'ENG',
    'GRD',
    Operations.n9,
    Operations11.eng,
    Operations11.grd,
    '9',
  );
  CalculatorButton get div => CalculatorButton(
    factory,
    '\u00F7',
    'x\u2264y',
    'x<0',
    Operations11.div,
    Operations.xLEy,
    Operations.xLT0,
    '/',
  );

  CalculatorButton get sst => CalculatorButton(
    factory,
    'SST',
    'LBL',
    'BST',
    Operations.sst,
    Operations11.lbl15,
    Operations.bst,
    ']',
  );
  CalculatorButton get gto => CalculatorButton(
    factory,
    'GTO',
    'HYP',
    'HYP^\u2009\u22121',
    Operations11.gto,
    Operations11.hyp,
    Operations11.hypInverse,
    'L',
  );
  CalculatorButton get sin => CalculatorButtonHyperbolic(
    factory,
    'SIN',
    'x\u2b0c(i)',
    'SIN^\u2009\u22121',
    Operations11.sin,
    Operations.xSwapParenI,
    Operations11.sinInverse,
    Operations11.sinh,
    Operations11.sinhInverse,
    'S',
  );
  CalculatorButton get cos => CalculatorButtonHyperbolic(
    factory,
    'COS',
    '(i)',
    'COS^\u2009\u22121',
    Operations11.cos,
    Operations11.parenI15,
    Operations11.cosInverse,
    Operations11.cosh,
    Operations11.coshInverse,
    'O',
  );
  CalculatorButton get tan => CalculatorButtonHyperbolic(
    factory,
    'TAN',
    'I',
    'TAN^\u2009\u22121',
    Operations11.tan,
    Operations11.I15,
    Operations11.tanInverse,
    Operations11.tanh,
    Operations11.tanhInverse,
    'T',
  );

  CalculatorButton get eex => CalculatorButton(
    factory,
    'EEX',
    '\u279cR',
    '\u279cP',
    Operations.eex,
    Operations11.toR,
    Operations11.toP,
    'P',
  );
  CalculatorButton get n4 => CalculatorButton(
    factory,
    '4',
    'x\u2b0cI',
    'SF',
    Operations.n4,
    Operations11.xExchange,
    Operations11.sf,
    '4',
  );
  CalculatorButton get n5 => CalculatorButton(
    factory,
    '5',
    'DSE',
    'CF',
    Operations.n5,
    Operations11.dse,
    Operations11.cf,
    '5',
  );
  CalculatorButton get n6 => CalculatorButton(
    factory,
    '6',
    'ISG',
    'F?',
    Operations.n6,
    Operations11.isg,
    Operations11.fQuestion,
    '6',
  );
  CalculatorButton get mult => CalculatorOnSpecialButton(
    factory,
    '\u00d7',
    'x>y',
    'x>0',
    Operations11.mult,
    Operations.xGTy,
    Operations.xGT0,
    'X*',
    'TST',
    acceleratorLabel: '*\u00d7',
  );

  CalculatorButton get rs => CalculatorButton(
    factory,
    'R/S',
    'PSE',
    'P/R',
    Operations.rs,
    Operations.pse,
    Operations.pr,
    '[',
  );
  CalculatorButton get gsb => CalculatorButton(
    factory,
    'GSB',
    '\u03a3',
    'RTN',
    Operations11.gsb,
    Operations11.clearSigma,
    Operations.rtn,
    'U',
  );
  CalculatorButton get rdown => CalculatorButton(
    factory,
    'R\u2193',
    'PRGM',
    'R\u2191',
    Operations.rDown,
    Operations.clearPrgm,
    Operations.rUp,
    'V',
  );
  CalculatorButton get xy => CalculatorButton(
    factory,
    'x\u2b0cy',
    'REG',
    'RND',
    Operations.xy,
    Operations.clearReg,
    Operations11.rnd,
    'Y',
  );
  CalculatorButton get bsp => CalculatorButton(
    factory,
    '\u2b05',
    'PREFIX',
    'CLx',
    Operations.bsp,
    Operations.clearPrefix,
    Operations.clx,
    '\u0008\u007f\uf728',
    acceleratorLabel: '\u2190',
  );
  @override
  CalculatorButton get enter => CalculatorEnterButton(
    factory,
    'E\nN\nT\nE\nR',
    'RAN #',
    'LSTx',
    Operations.enter,
    Operations11.ranNum,
    Operations11.lstx15,
    '\n\r',
    extraHeight: factory.height * _totalButtonHeight / _buttonHeight,
    acceleratorLabel: ' \u23ce',
  );
  CalculatorButton get n1 => CalculatorButton(
    factory,
    '1',
    'P\u200ay,x',
    'C\u2009y,x',
    Operations.n1,
    Operations11.pYX,
    Operations11.cYX,
    '1',
  );
  CalculatorButton get n2 => CalculatorButton(
    factory,
    '2',
    '\u279cH.MS',
    '\u279cH',
    Operations.n2,
    Operations11.toHMS,
    Operations11.toH,
    '2',
  );
  CalculatorButton get n3 => CalculatorButton(
    factory,
    '3',
    '\u279cRAD',
    '\u279cDEG',
    Operations.n3,
    Operations11.toRad,
    Operations11.toDeg,
    '3',
  );
  CalculatorButton get minus => CalculatorOnSpecialButton(
    factory,
    '\u2212',
    'x\u2260y',
    'x\u22600',
    Operations11.minus,
    Operations.xNEy,
    Operations.xNE0,
    '-',
    'CLR',
    acceleratorLabel: '\u2212',
  );

  CalculatorButton get onOff => CalculatorOnButton(
    factory,
    'ON',
    '',
    '',
    Operations.onOff,
    Operations.onOff,
    Operations.onOff,
    'N',
    'OFF',
  );
  CalculatorButton get fShift => CalculatorFButton(
    factory,
    'f',
    '',
    '',
    Operations.fShift,
    Operations.fShift,
    Operations.fShift,
    'F\u0006',
    extraAcceleratorName: '',
    acceleratorLabel: 'F',
  );
  CalculatorButton get gShift => CalculatorGButton(
    factory,
    'g',
    '',
    '',
    Operations.gShift,
    Operations.gShift,
    Operations.gShift,
    'G\u0007',
    extraAcceleratorName: '',
    acceleratorLabel: 'G',
  );
  CalculatorButton get sto => CalculatorButton(
    factory,
    'STO',
    'FRAC',
    'INT',
    Operations11.sto15,
    Operations11.fracOp,
    Operations11.intOp,
    'M',
  );
  CalculatorButton get rcl => CalculatorButton(
    factory,
    'RCL',
    'USER',
    'MEM',
    Operations11.rcl15,
    Operations11.userOp,
    Operations.mem,
    'R',
  );
  CalculatorButton get n0 => CalculatorButton(
    factory,
    '0',
    'x!',
    'x\u0305',
    Operations.n0,
    Operations11.xFactorial,
    Operations11.xBar,
    '0',
  );
  CalculatorButton get dot => CalculatorDotButton(
    factory,
    '\u2219',
    'y\u0302,r',
    's',
    Operations.dot,
    Operations11.yHatR,
    Operations11.stdDeviation,
    '.,',
    '\u2219/\u201a',
    factory.settings,
  );
  CalculatorButton get sum => CalculatorButton(
    factory,
    '\u03a3+',
    'L.R.',
    '\u03a3\u2212',
    Operations11.sigmaPlus,
    Operations11.linearRegression,
    Operations11.sigmaMinus,
    'W',
  );
  CalculatorButton get plus => CalculatorButton(
    factory,
    '+',
    'x=y',
    'x=0',
    Operations11.plus,
    Operations.xEQy,
    Operations.xEQ0,
    '+=',
  );

  @override
  List<List<CalculatorButton?>> get landscapeLayout => [
    [sqrt, eX, tenX, yX, reciprocal, chs, n7, n8, n9, div],
    [sst, gto, sin, cos, tan, eex, n4, n5, n6, mult],
    [rs, gsb, rdown, xy, bsp, enter, n1, n2, n3, minus],
    [onOff, fShift, gShift, sto, rcl, null, n0, dot, sum, plus],
  ];

  @override
  List<List<CalculatorButton?>> get portraitLayout => [
    [sqrt, eX, tenX, yX, reciprocal, onOff],
    [sst, gto, sin, cos, tan, chs],
    [rs, gsb, rdown, xy, bsp, eex],
    [sto, rcl, n7, n8, n9, div],
    [fShift, gShift, n4, n5, n6, mult],
    [null, enter, n1, n2, n3, minus],
    [null, null, n0, dot, sum, plus],
  ];
}

///
/// Calculator button for the hyperbolic functions
///
class CalculatorButtonHyperbolic extends CalculatorButton {
  final Operation hyperOp;
  final Operation inverseHyperOp;

  CalculatorButtonHyperbolic(
    ButtonFactory bFactory,
    String uText,
    String fText,
    String gText,
    Operation uKey,
    Operation fKey,
    Operation gKey,
    this.hyperOp,
    this.inverseHyperOp,
    String acceleratorKey, {
    String? acceleratorLabel,
    Key? key,
  }) : super(
         bFactory,
         uText,
         fText,
         gText,
         uKey,
         fKey,
         gKey,
         acceleratorKey,
         acceleratorLabel: acceleratorLabel,
         key: key,
       );
}

class LandscapeButtonFactory11 extends LandscapeButtonFactory {
  LandscapeButtonFactory11(super.context, super.screen, super.controller);

  @override
  Offset get fTextOffset => const Offset(0, -4);

  @override
  double get shiftDownTweak => 0.014;

  @override
  void addUpperGoldLabels(
    List<Widget> result,
    Rect pos, {
    required double th,
    required double tw,
    required double bh,
    required double bw,
  }) {
    double y = pos.top;
    result.add(
      screen.box(
        Rect.fromLTRB(
          pos.left + 1 * tw - 0.05,
          y + 2 * th - 0.155,
          pos.left + 4 * tw + bw + 0.05,
          y + 2 * th + 0.065,
        ),
        CustomPaint(
          painter: UpperLabel(
            'CLEAR',
            fTextSmallLabelStyle,
            height * (0.065 + 0.155) / bh,
          ),
        ),
      ),
    );
  }
}

class PortraitButtonFactory11 extends PortraitButtonFactory {
  PortraitButtonFactory11(super.context, super.screen, super.controller);

  @override
  Offset get fTextOffset => const Offset(0, -4);

  @override
  double get shiftDownTweak => 0.28;

  @override
  void addUpperGoldLabels(
    List<Widget> result,
    Rect pos, {
    required double th,
    required double tw,
    required double bh,
    required double bw,
  }) {
    double y = pos.top;
    final box = Rect.fromLTWH(
      pos.left + tw - 0.05,
      y + 2 * th + 0.07,
      3 * tw + bw + 0.10,
      0.22,
    );
    result.add(
      screen.box(
        box,
        CustomPaint(
          painter: UpperLabel(
            'CLEAR',
            fTextSmallLabelStyle,
            height * (0.065 + 0.155) / bh,
          ),
        ),
      ),
    );
  }
}

class CalculatorButtonWithUserMode extends CalculatorButton {
  final Operation uKeyUser;
  final Operation fKeyUser;

  CalculatorButtonWithUserMode(
    ButtonFactory bFactory,
    String uText,
    String fText,
    String gText,
    Operation uKey,
    Operation fKey,
    Operation gKey,
    this.uKeyUser,
    this.fKeyUser,
    String acceleratorKey, {
    String? acceleratorLabel,
    Key? key,
  }) : super(
         bFactory,
         uText,
         fText,
         gText,
         uKey,
         fKey,
         gKey,
         acceleratorKey,
         acceleratorLabel: acceleratorLabel,
         key: key,
       );
}

class Controller11 extends RealController {
  @override
  final Model11<Operation> model;

  Controller11(this.model)
    : super(
        numbers: numbers,
        shortcuts: _shortcuts,
        lblOperation: Operations11.lbl15,
        rtn: Operations.rtn,
      );

  static final Map<Operation, ArgDone> _shortcuts = {
    Operations11.letterLabelA: _makeShortcut(
      Operations11.gsb.arg,
      Operations11.letterLabelA,
    )!,
    Operations11.letterLabelB: _makeShortcut(
      Operations11.gsb.arg,
      Operations11.letterLabelB,
    )!,
    Operations11.letterLabelC: _makeShortcut(
      Operations11.gsb.arg,
      Operations11.letterLabelC,
    )!,
    Operations11.letterLabelD: _makeShortcut(
      Operations11.gsb.arg,
      Operations11.letterLabelD,
    )!,
    Operations11.letterLabelE: _makeShortcut(
      Operations11.gsb.arg,
      Operations11.letterLabelE,
    )!,
  };

  /// Map from operation that is a shortcut to what it's a shortcut for, with
  /// the key as an argument.  We want the identical instance of ArgDone, so
  /// we climb down the tree.  It's admittedly a bit of a hack.
  static ArgDone? _makeShortcut(Arg arg, Operation wanted) {
    if (arg is ArgAlternates) {
      for (final a in arg.children) {
        final r = _makeShortcut(a, wanted);
        if (r != null) {
          return r;
        }
      }
    } else if (arg is KeyArg) {
      if (arg.key == wanted) {
        return arg.child as ArgDone;
      }
    }
    return null;
  }

  @override
  List<Operation> get nonProgrammableOperations => _nonProgrammableOperations;

  static final _nonProgrammableOperations = [
    ...Operations.special,
    Operations11.hyp,
    Operations11.hypInverse,
    Operations11.userOp,
    Operations11.parenI15,
  ];

  static final _userModeSwapped = <Operation, Operation>{
    Operations11.letterLabelA: Operations11.sqrtOp15,
    Operations11.sqrtOp15: Operations11.letterLabelA,
    Operations11.letterLabelB: Operations11.eX15,
    Operations11.eX15: Operations11.letterLabelB,
    Operations11.letterLabelC: Operations11.tenX15,
    Operations11.tenX15: Operations11.letterLabelC,
    Operations11.letterLabelD: Operations11.yX15,
    Operations11.yX15: Operations11.letterLabelD,
    Operations11.letterLabelE: Operations11.reciprocal15,
    Operations11.reciprocal15: Operations11.letterLabelE,
  };

  @override
  void buttonWidgetDown(CalculatorButton b) {
    if (b is! CalculatorButtonHyperbolic) {
      if (model.userMode) {
        final Operation op = model.shift.select(b);
        buttonDown(_userModeSwapped[op] ?? op);
      } else {
        super.buttonWidgetDown(b);
      }
    } else if (lastKey == Operations11.hyp) {
      buttonDown(b.hyperOp);
    } else if (lastKey == Operations11.hypInverse) {
      buttonDown(b.inverseHyperOp);
    } else {
      super.buttonWidgetDown(b);
    }
  }

  @override
  bool doDeferred() {
    try {
      bool s = super.doDeferred();
      final deferred = model.deferToButtonUp;
      if (deferred != null) {
        if (deferred()) {
          enableStackLift();
        }
        s = true;
      }
      return s;
    } finally {
      model.deferToButtonUp = null;
    }
  }

  /// The numbers.  This must be in order.
  static final List<NumberEntry> numbers = [
    Operations.n0,
    Operations.n1,
    Operations.n2,
    Operations.n3,
    Operations.n4,
    Operations.n5,
    Operations.n6,
    Operations.n7,
    Operations.n8,
    Operations.n9,
  ];

  @override
  Operation get gotoLineNumberKey => Operations.chs;

  @override
  SelfTests newSelfTests({bool inCalculator = true}) =>
      SelfTests11(inCalculator: inCalculator);

  @override
  ButtonLayout11 getButtonLayout(
    ButtonFactory factory,
    double totalHeight,
    double totalButtonHeight,
  ) => ButtonLayout11(factory, totalHeight, totalButtonHeight);

  @override
  BackPanel11 getBackPanel() => BackPanel11();

  @override
  LandscapeButtonFactory getLandscapeButtonFactory(
    BuildContext context,
    ScreenPositioner screen,
  ) => LandscapeButtonFactory11(context, screen, this);

  @override
  PortraitButtonFactory getPortraitButtonFactory(
    BuildContext context,
    ScreenPositioner screen,
  ) => PortraitButtonFactory11(context, screen, this);

  @override
  int get argBase => 10;

  @override
  int getErrorNumber(CalculatorError err) => err.num15;

  @override
  NormalArgOperation get gsbOperation => Operations11.gsb;

  @override
  NormalArgOperation get gtoOperation => Operations11.gto;

  @override
  Operation get minusOp => Operations11.minus;

  @override
  Operation get multOp => Operations11.mult;

  @override
  bool get menus15C => true;
}

//
// See Model.logicalKeys.  This table determines the operation opcodes.
// Changing the order here would render old JSON files of the
// calculator's state obsolete.
final List<List<MKey<Operation>?>> _logicalKeys = [
  [
    MKey(
      Operations11.sqrtOp15,
      Operations11.letterLabelA,
      Operations11.xSquared,
    ),
    MKey(Operations11.eX15, Operations11.letterLabelB, Operations11.lnOp),
    MKey(Operations11.tenX15, Operations11.letterLabelC, Operations11.logOp),
    MKey(Operations11.yX15, Operations11.letterLabelD, Operations11.percent),
    MKey(
      Operations11.reciprocal15,
      Operations11.letterLabelE,
      Operations11.deltaPercent,
    ),
    MKey(Operations.chs, Operations11.piOp, Operations.abs),
    MKey(Operations.n7, Operations11.fix, Operations11.deg),
    MKey(Operations.n8, Operations11.sci, Operations11.rad),
    MKey(Operations.n9, Operations11.eng, Operations11.grd),
    MKey(Operations11.div, Operations.xLEy, Operations.xLT0),
  ],
  [
    MKey(Operations.sst, Operations11.lbl15, Operations.bst),
    MKey(Operations11.gto, Operations11.hyp, Operations11.hypInverse),
    MKey(
      Operations11.sin,
      Operations.xSwapParenI,
      Operations11.sinInverse,
      extensionOps: [
        MKeyExtensionOp(Operations11.sinh, Operations.fShift, Operations11.hyp),
        MKeyExtensionOp(
          Operations11.sinhInverse,
          Operations.gShift,
          Operations11.hypInverse,
        ),
      ],
    ),
    MKey(
      Operations11.cos,
      Operations11.parenI15,
      Operations11.cosInverse,
      extensionOps: [
        MKeyExtensionOp(Operations11.cosh, Operations.fShift, Operations11.hyp),
        MKeyExtensionOp(
          Operations11.coshInverse,
          Operations.gShift,
          Operations11.hypInverse,
        ),
      ],
    ),
    MKey(
      Operations11.tan,
      Operations11.I15,
      Operations11.tanInverse,
      extensionOps: [
        MKeyExtensionOp(Operations11.tanh, Operations.fShift, Operations11.hyp),
        MKeyExtensionOp(
          Operations11.tanhInverse,
          Operations.gShift,
          Operations11.hypInverse,
        ),
      ],
    ),
    MKey(Operations.eex, Operations11.toR, Operations11.toP),
    MKey(Operations.n4, Operations11.xExchange, Operations11.sf),
    MKey(Operations.n5, Operations11.dse, Operations11.cf),
    MKey(Operations.n6, Operations11.isg, Operations11.fQuestion),
    MKey(Operations11.mult, Operations.xGTy, Operations.xGT0),
  ],
  [
    MKey(Operations.rs, Operations.pse, Operations.pr),
    MKey(Operations11.gsb, Operations11.clearSigma, Operations.rtn),
    MKey(Operations.rDown, Operations.clearPrgm, Operations.rUp),
    MKey(Operations.xy, Operations.clearReg, Operations11.rnd),
    MKey(Operations.bsp, Operations.clearPrefix, Operations.clx),
    MKey(Operations.enter, Operations11.ranNum, Operations11.lstx15),
    MKey(Operations.n1, Operations11.pYX, Operations11.cYX),
    MKey(Operations.n2, Operations11.toHMS, Operations11.toH),
    MKey(Operations.n3, Operations11.toRad, Operations11.toDeg),
    MKey(Operations11.minus, Operations.xNEy, Operations.xNE0),
  ],
  [
    MKey(Operations.onOff, Operations.onOff, Operations.onOff),
    MKey(Operations.fShift, Operations.fShift, Operations.fShift),
    MKey(Operations.gShift, Operations.gShift, Operations.gShift),
    MKey(Operations11.sto15, Operations11.fracOp, Operations11.intOp),
    MKey(Operations11.rcl15, Operations11.userOp, Operations.mem),
    null,
    MKey(Operations.n0, Operations11.xFactorial, Operations11.xBar),
    MKey(Operations.dot, Operations11.yHatR, Operations11.stdDeviation),
    MKey(
      Operations11.sigmaPlus,
      Operations11.linearRegression,
      Operations11.sigmaMinus,
    ),
    MKey(Operations11.plus, Operations.xEQy, Operations.xEQ0),
  ],
];

final Set<LetterLabel> _letterLabels = {
  Operations11.letterLabelA,
  Operations11.letterLabelB,
  Operations11.letterLabelC,
  Operations11.letterLabelD,
  Operations11.letterLabelE,
};

final _letterLabelsList = _letterLabels.toList(growable: false);

ProgramInstruction<Operation> _newProgramInstruction(
  Operation operation,
  ArgDone arg,
) {
  if (_letterLabels.contains(operation)) {
    arg = Operations11.gsb.arg.matches(operation, false) as ArgDone;
    operation = Operations11.gsb;
  }
  return ProgramInstruction11(operation, arg);
}

class ProgramInstruction11<OT extends ProgramOperation>
    extends ProgramInstruction<OT> {
  ProgramInstruction11(super.op, super.arg);
}

