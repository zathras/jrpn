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

import 'back_panel15c.dart';
import 'tests15c.dart';
import 'model15c.dart';

void main() async {
  runStaticInitialization15();
  genericMain(Jrpn(Controller15(createModel15())));
}

void runStaticInitialization15() {
  // None of these operations has an argument, so there is no circular
  // initialization here.
  Arg.kI = Operations15.I15;
  Arg.kParenI = Operations15.parenI15;
  Arg.kDigits = Controller15.numbers;
  Arg.kDot = Operations.dot;
  Arg.fShift = Operations.fShift;
  Arg.gShift = Operations.gShift;
  Arg.registerISynonyms = {
    Operations.sst: Operations15.I15,
    Operations.rs: Operations15.parenI15
  };
  assert(Arg.assertStaticInitialized());
}

Model15<Operation> createModel15() {
  return Model15<Operation>(() => _logicalKeys, _newProgramInstruction);
}

class Operations15 extends Operations {
  static final letterLabelA = LetterLabel('A', 20);
  static final letterLabelB = LetterLabel('B', 21);
  static final letterLabelC = LetterLabel('C', 22);
  static final letterLabelD = LetterLabel('D', 23);
  static final letterLabelE = LetterLabel('E', 24);

  static final _letterSynonyms = {
    Operations15.sqrtOp15: Operations15.letterLabelA,
    Operations15.eX15: Operations15.letterLabelB,
    Operations15.tenX15: Operations15.letterLabelC,
    Operations15.yX15: Operations15.letterLabelD,
    Operations15.reciprocal15: Operations15.letterLabelE
  };

  static final NormalArgOperation lbl15 = NormalArgOperation(
      maxOneByteOpcodes: 15,
      arg: ArgAlternates(synonyms: _letterSynonyms, children: [
        DigitArg(max: 19, calc: (_, __) {}),
        KeyArg(key: letterLabelA, child: ArgDone((m) {})),
        KeyArg(key: letterLabelB, child: ArgDone((m) {})),
        KeyArg(key: letterLabelC, child: ArgDone((m) {})),
        KeyArg(key: letterLabelD, child: ArgDone((m) {})),
        KeyArg(key: letterLabelE, child: ArgDone((m) {}))
      ]),
      name: 'LBL');

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
      name: 'I');

  ///
  /// The HP 15's (i) operation, to see the imaginary part.
  ///
  static final NormalOperation parenI15 = LimitedOperation(
      pressed: (LimitedState cs) => cs.handleShowImaginary(), name: '(i)');

  static final sqrtOp15 =
      NormalOperationOrLetter(Operations.sqrtOp, letterLabelA);
  static final NormalOperation eX15 = NormalOperationOrLetter.floatOnly(
      letter: letterLabelB,
      floatCalc: (Model m) {
        double x = m.xF;
        m.floatOverflow = false;
        m.resultXF = pow(e, x) as double;
      },
      complexCalc: (Model m) {
        m.resultXC = m.xC.exp();
      },
      name: 'eX');
  static final NormalOperation xSquared = NormalOperation.floatOnly(
      floatCalc: (Model m) {
        double x = m.xF;
        m.floatOverflow = false;
        m.resultXF = x * x;
      },
      complexCalc: (Model m) {
        final v = m.xC;
        m.resultXC = v * v;
      },
      name: 'x^2');
  static final NormalOperation lnOp = NormalOperation.floatOnly(
      floatCalc: (Model m) {
        double x = m.xF;
        if (x <= 0) {
          throw CalculatorError(0);
        }
        m.floatOverflow = false;
        m.resultXF = _checkResult(() => log(x), 0);
      },
      complexCalc: (Model m) {
        m.resultXC = _checkResultC(m.xC.ln, 0);
      },
      name: 'ln');
  static final NormalOperation tenX15 = NormalOperationOrLetter.floatOnly(
      letter: letterLabelC,
      floatCalc: (Model m) {
        double x = m.xF;
        m.floatOverflow = false;
        m.resultXF = pow(10, x) as double;
      },
      complexCalc: (Model m) {
        m.resultXC = (m.xC * const Complex(ln10, 0)).exp();
      },
      name: '10^x');
  static final NormalOperation logOp = NormalOperation.floatOnly(
      floatCalc: (Model m) {
        double x = m.xF;
        if (x <= 0) {
          throw CalculatorError(0);
        }
        m.floatOverflow = false;
        m.resultXF = log(x) / ln10;
      },
      complexCalc: (Model m) {
        m.resultXC = _checkResultC(m.xC.ln, 0) / const Complex(ln10, 0);
      },
      name: 'log');
  static final NormalOperation yX15 = NormalOperationOrLetter.floatOnly(
      letter: letterLabelD,
      floatCalc: (Model m) {
        m.floatOverflow = false;
        m.popSetResultXF = pow(m.yF, m.xF) as double;
      },
      complexCalc: (Model m) {
        m.popSetResultXC = m.yC.pow(m.xC);
      },
      name: 'yX');
  static final NormalOperation percent = NormalOperation.floatOnly(
      floatCalc: (Model m) {
        m.floatOverflow = false;
        m.resultXF = m.xF * 0.01 * m.yF;
      },
      name: '%');
  static final reciprocal15 =
      NormalOperationOrLetter(Operations.reciprocal, letterLabelE);
  static final NormalOperation deltaPercent = NormalOperation.floatOnly(
      floatCalc: (Model m) {
        m.floatOverflow = false;
        m.resultXF = ((m.xF - m.yF) / m.yF) * 100.0;
      },
      name: 'delta%');
  static final NormalArgOperation matrix = NormalArgOperation(
      maxOneByteOpcodes: 0,
      arg: ArgAlternates(children: [
        KeyArg(
            key: Operations.n0,
            child: ArgDone((m) {
              for (final mat in (m as Model15).matrices) {
                mat.resize(0, 0);
              }
            })),
        KeyArg(
            key: Operations.n1,
            child: ArgDone((m) {
              m.memory.registers[0] =
                  m.memory.registers[1] = Value.fromDouble(1);
            })),
        KeyArg(key: Operations.n2, child: ArgDone((m) => throw "@@ TODO")),
        KeyArg(key: Operations.n3, child: ArgDone((m) => throw "@@ TODO")),
        KeyArg(key: Operations.n4, child: ArgDone((m) => throw "@@ TODO")),
        KeyArg(key: Operations.n5, child: ArgDone((m) => throw "@@ TODO")),
        KeyArg(key: Operations.n6, child: ArgDone((m) => throw "@@ TODO")),
        KeyArg(key: Operations.n7, child: ArgDone((m) => throw "@@ TODO")),
        KeyArg(key: Operations.n8, child: ArgDone((m) => throw "@@ TODO")),
        KeyArg(key: Operations.n9, child: ArgDone((m) => throw "@@ TODO")),
      ]),
      name: 'MATRIX');
  static final NormalArgOperation fix = NormalArgOperation(
      stackLift: StackLift.neutral,
      maxOneByteOpcodes: 0,
      arg: PrecisionArg(
          f: (m, v) => m.displayMode = DisplayMode.fix(v, m.isComplexMode)),
      name: 'FIX');

  static final NormalArgOperation sf = NormalArgOperation(
      maxOneByteOpcodes: 0,
      arg: LabelArg(maxDigit: 9, f: (m, v) => m.setFlag(v ?? 999, true)),
      name: 'SF');

  static final NormalArgOperation cf = NormalArgOperation(
      maxOneByteOpcodes: 0,
      arg: LabelArg(maxDigit: 9, f: (m, v) => m.setFlag(v ?? 999, false)),
      name: 'CF');

  static final BranchingArgOperation fQuestion = BranchingArgOperation(
      maxOneByteOpcodes: 0,
      arg: LabelArg(
          maxDigit: 9, f: (m, v) => m.program.doNextIf(m.getFlag(v ?? 99))),
      name: 'F?');

  static final NormalArgOperation gsb = GosubOperation(
      arg: LabelArg(
          maxDigit: 19,
          letters: _letterLabelsList,
          f: (m, final int? label) {
            if (label == null) {
              throw CalculatorError(4);
            }
            m.memory.program.goto(label);
          }),
      name: 'GSB');

  static final NormalArgOperation gto = NormalArgOperation(
      maxOneByteOpcodes: 16, // I, A..E, 0..9, and .0-.9
      arg: LabelArg(
          iFirst: true,
          maxDigit: 19,
          letters: _letterLabelsList,
          f: (m, final int? label) {
            if (label == null) {
              throw CalculatorError(4);
            }
            m.memory.program.goto(label);
          }),
      name: 'GTO');

  static final NormalArgOperation sci = NormalArgOperation(
      stackLift: StackLift.neutral,
      maxOneByteOpcodes: 0,
      arg: PrecisionArg(
          f: (m, v) => m.displayMode = DisplayMode.sci(v, m.isComplexMode)),
      name: 'SCI');
  static final NormalArgOperation eng = NormalArgOperation(
      stackLift: StackLift.neutral,
      maxOneByteOpcodes: 0,
      arg: PrecisionArg(
          f: (m, v) => m.displayMode = DisplayMode.eng(v, m.isComplexMode)),
      name: 'SCI');
  static final NormalOperation deg = NormalOperation.floatOnly(
      floatCalc: (Model m) {
        m.trigMode = TrigMode.deg;
      },
      name: 'DEG');
  static final NormalOperation rad = NormalOperation.floatOnly(
      floatCalc: (Model m) {
        m.trigMode = TrigMode.rad;
      },
      name: 'RAD');
  static final NormalOperation grd = NormalOperation.floatOnly(
      floatCalc: (Model m) {
        m.trigMode = TrigMode.grad;
      },
      name: 'GRD');
  static final NormalOperation solve = NormalOperation.floatOnly(
      maxOneByteOpcodes: 0,
      floatCalc: (Model m) {
        throw "@@ TODO";
      },
      name: 'SOLVE');
  static final hyp = NonProgrammableOperation(
      pressed: (LimitedState c) => c.handleShift(ShiftKey.none),
      // Controller15 handles the rest
      name: 'HYP');
  static final hypInverse = NonProgrammableOperation(
      pressed: (LimitedState c) => c.handleShift(ShiftKey.none), name: 'HYP-1');
  static final NormalOperation sin = NormalOperation.floatOnly(
      floatCalc: (Model m) {
        m.xF = dart.sin(m.xF * m.trigMode.scaleFactor);
      },
      complexCalc: (Model m) {
        // Always in radians - see 15C manual p. 131, "For the trigonometric..."
        m.resultXC = m.xC.sin();
      },
      name: 'SIN');
  static final NormalOperation sinInverse = NormalOperation.floatOnly(
      floatCalc: (Model m) {
        m.xF = dart.asin(m.xF) / m.trigMode.scaleFactor;
      },
      complexCalc: (Model m) {
        // Always in radians - see 15C manual p. 131, "For the trigonometric..."
        m.resultXC = m.xC.asin();
      },
      name: 'SIN-1');
  static final NormalOperation cos = NormalOperation.floatOnly(
      floatCalc: (Model m) {
        m.xF = dart.cos(m.xF * m.trigMode.scaleFactor);
      },
      complexCalc: (Model m) {
        // Always in radians - see 15C manual p. 131, "For the trigonometric..."
        m.resultXC = m.xC.cos();
      },
      name: 'COS');
  static final NormalOperation cosInverse = NormalOperation.floatOnly(
      floatCalc: (Model m) {
        m.xF = dart.acos(m.xF) / m.trigMode.scaleFactor;
      },
      complexCalc: (Model m) {
        // Always in radians - see 15C manual p. 131, "For the trigonometric..."
        m.resultXC = m.xC.acos();
      },
      name: 'COS-1');
  static final NormalOperation tan = NormalOperation.floatOnly(
      floatCalc: (Model m) {
        m.xF = dart.tan(m.xF * m.trigMode.scaleFactor);
      },
      complexCalc: (Model m) {
        // Always in radians - see 15C manual p. 131, "For the trigonometric..."
        m.resultXC = m.xC.tan();
      },
      name: 'TAN');
  static final NormalOperation tanInverse = NormalOperation.floatOnly(
      floatCalc: (Model m) {
        m.xF = dart.atan(m.xF) / m.trigMode.scaleFactor;
      },
      complexCalc: (Model m) {
        // Always in radians - see 15C manual p. 131, "For the trigonometric..."
        m.resultXC = m.xC.atan();
      },
      name: 'TAN-1');
  static final NormalOperation sinh = NormalOperation.floatOnly(
      floatCalc: (Model m) {
        m.xF = Real.sinh(m.xF);
      },
      complexCalc: (Model m) {
        // Always in radians - see 15C manual p. 131, "For the trigonometric..."
        m.resultXC = m.xC.sinh();
      },
      name: 'SINH');
  static final NormalOperation sinhInverse = NormalOperation.floatOnly(
      floatCalc: (Model m) {
        m.xF = Real.asinh(m.xF);
      },
      complexCalc: (Model m) {
        // Always in radians - see 15C manual p. 131, "For the trigonometric..."
        m.resultXC = m.xC.asinh();
      },
      name: 'SINH-1');
  static final NormalOperation cosh = NormalOperation.floatOnly(
      floatCalc: (Model m) {
        m.xF = Real.cosh(m.xF);
      },
      complexCalc: (Model m) {
        // Always in radians - see 15C manual p. 131, "For the trigonometric..."
        m.resultXC = m.xC.cosh();
      },
      name: 'COSH');
  static final NormalOperation coshInverse = NormalOperation.floatOnly(
      floatCalc: (Model m) {
        m.xF = Real.acosh(m.xF);
      },
      complexCalc: (Model m) {
        // Always in radians - see 15C manual p. 131, "For the trigonometric..."
        m.resultXC = m.xC.acosh();
      },
      name: 'COSH-1');
  static final NormalOperation tanh = NormalOperation.floatOnly(
      floatCalc: (Model m) {
        m.xF = Real.tanh(m.xF);
      },
      complexCalc: (Model m) {
        // Always in radians - see 15C manual p. 131, "For the trigonometric..."
        m.resultXC = m.xC.tanh();
      },
      name: 'TANH');
  static final NormalOperation tanhInverse = NormalOperation.floatOnly(
      floatCalc: (Model m) {
        m.xF = Real.atanh(m.xF);
      },
      complexCalc: (Model m) {
        // Always in radians - see 15C manual p. 131, "For the trigonometric..."
        m.resultXC = m.xC.atanh();
      },
      name: 'TANH-1');

  static final _matrixSynonyms = {
    Operations.chs: Operations15.matrix,
    Operations.eex: Operations15.resultOp,
    ..._letterSynonyms
  };

  static void _dim(Model m, int arg) {
    if (arg < 0 || arg >= (m as Model15).matrices.length) {
      throw CalculatorError(11);
    }
    int r = m.xF.truncate();
    int c = m.yF.truncate();
    if (r < 0 || c < 0) {
      throw CalculatorError(1);
    }
    final mat = m.matrices[arg];
    m.memory.policy.checkAvailable(r * c - mat.length);
    mat.resize(r, c);
  }

  static final NormalArgOperation dim = NormalArgOperation(
      arg: ArgAlternates(synonyms: _letterSynonyms, children: [
        ...List.generate(
            _letterLabelsList.length,
            (i) => KeyArg(
                key: _letterLabelsList[i], child: ArgDone((m) => _dim(m, i)))),
        KeyArg(
            key: Operations15.I15,
            child: ArgDone(
                (m) => _dim(m, m.memory.registers.index.asMatrix ?? 99))),
        KeyArg(
            key: Operations15.parenI15,
            child: ArgDone((m) =>
                _dim(m, m.memory.registers.indirectIndex.asMatrix ?? 99))),
      ]),
      name: 'DIM');

  static final NormalArgOperation resultOp = NormalArgOperation(
      arg: ArgAlternates(
          synonyms: _letterSynonyms,
          children: List.generate(
              _letterLabelsList.length,
              (i) => KeyArg(
                  key: _letterLabelsList[i],
                  child: ArgDone((m) => (m as Model15).resultMatrix = i)))),
      name: 'RESULT');

  static final NormalOperation piOp = NormalOperation.floatOnly(
      floatCalc: (Model m) {
        m.xF = dart.pi;
      },
      name: 'PI');
  static final NormalArgOperation xExchange = NormalArgOperation(
      maxOneByteOpcodes: 4,
      arg: ArgAlternates(synonyms: Arg.registerISynonyms, children: [
        KeyArg(key: Arg.kParenI, child: ArgDone((m) => throw "@@ TODO")),
        KeyArg(key: Arg.kI, child: ArgDone((m) => throw "@@ TODO")),
        DigitArg(max: 19, calc: (m, i) => throw "@@ TODO")
      ]),
      name: 'x<->');
  static final NormalArgOperation dse = NormalArgOperation(
      maxOneByteOpcodes: 4,
      arg: RegisterWriteOpArg(
          maxDigit: 19, f: (double r, double x) => throw "@@ TODO"),
      name: 'DSE');
  static final NormalArgOperation isg = NormalArgOperation(
      maxOneByteOpcodes: 4,
      arg: RegisterWriteOpArg(
          maxDigit: 19, f: (double r, double x) => throw "@@ TODO"),
      name: 'ISG');
  static final NormalOperation integrate = NormalOperation.floatOnly(
      maxOneByteOpcodes: 0,
      floatCalc: (Model m) {
        throw "@@ TODO";
      },
      name: 'integrate');
  static final NormalOperation clearSigma = NormalOperation.floatOnly(
      floatCalc: (Model m) {
        throw "@@ TODO";
      },
      name: 'CLEAR-E');
  static final NormalOperation rnd = NormalOperation.floatOnly(
      floatCalc: (Model m) {
        throw "@@ TODO";
      },
      name: 'RND');
  static final NormalOperation ranNum = NormalOperation.floatOnly(
      floatCalc: (Model m) {
        throw "@@ TODO";
      },
      name: 'RAN #');
  static final NormalOperation toR = NormalOperation.floatOnly(
      floatCalc: (Model m) {
        double r = m.xF;
        double theta = m.yF;
        m.xF = r * dart.cos(theta * m.trigMode.scaleFactor);
        m.yF = r * dart.sin(theta * m.trigMode.scaleFactor);
      },
      complexCalc: (Model m) {
        Complex v = m.xC;
        m.xC = Complex(v.real * dart.cos(v.imaginary * m.trigMode.scaleFactor),
            v.real * dart.sin(v.imaginary * m.trigMode.scaleFactor));
      },
      name: '->R');
  static final NormalOperation toP = NormalOperation.floatOnly(
      floatCalc: (Model m) {
        double x = m.xF;
        double y = m.yF;
        m.xF = sqrt(x * x + y * y);
        m.yF = atan2(y, x) / m.trigMode.scaleFactor;
      },
      complexCalc: (Model m) {
        Complex v = m.xC;
        m.xC = Complex(sqrt(v.real * v.real + v.imaginary * v.imaginary),
            atan2(v.imaginary, v.real) / m.trigMode.scaleFactor);
      },
      name: '->P');
  static final NormalOperation toHMS = NormalOperation.floatOnly(
      floatCalc: (Model m) {
        throw "@@ TODO";
      },
      name: '->H.MS');
  static final NormalOperation toH = NormalOperation.floatOnly(
      floatCalc: (Model m) {
        throw "@@ TODO";
      },
      name: '->H');
  static final NormalOperation toRad = NormalOperation.floatOnly(
      floatCalc: (Model m) {
        throw "@@ TODO";
      },
      name: '->RAD');
  static final NormalOperation toDeg = NormalOperation.floatOnly(
      floatCalc: (Model m) {
        throw "@@ TODO";
      },
      name: '->DEG');
  static final NormalOperation reImSwap = NormalOperation.floatOnly(
      floatCalc: (Model m) {
        throw "@@ TODO";
      },
      name: 'Re<=>Im');

  static void _testOp(Model m, int arg) {
    throw "@@ TODO";
  }

  static final NormalArgOperation testOp =
      NormalArgOperation(arg: DigitArg(max: 9, calc: _testOp), name: 'TEST');

  static final NormalOperation fracOp = NormalOperation.floatOnly(
      floatCalc: (Model m) {
        throw "@@ TODO";
      },
      name: 'FRAC');
  static final NormalOperation intOp = NormalOperation.floatOnly(
      floatCalc: (Model m) {
        throw "@@ TODO";
      },
      name: 'INT');
  static final userOp = NonProgrammableOperation(
      endsDigitEntry: true,
      calc: (_) {},
      pressed: (LimitedState s) {
        final m = s.model as Model15;
        m.userMode = !m.userMode;
        m.display.update(flash: true); // Needed in program entry mode
      },
      name: 'USER');
  static final NormalOperation xFactorial = NormalOperation.floatOnly(
      floatCalc: (Model m) {
        throw "@@ TODO";
      },
      name: 'x!');
  static final NormalOperation xBar = NormalOperation.floatOnly(
      floatCalc: (Model m) {
        throw "@@ TODO";
      },
      name: 'xBar');
  static final NormalOperation yHatR = NormalOperation.floatOnly(
      floatCalc: (Model m) {
        throw "@@ TODO";
      },
      name: 'yHat,r');
  static final NormalOperation sOp = NormalOperation.floatOnly(
      floatCalc: (Model m) {
        throw "@@ TODO";
      },
      name: 's');
  static final NormalOperation linearRegression = NormalOperation.floatOnly(
      floatCalc: (Model m) {
        throw "@@ TODO";
      },
      name: 'L.R.');
  static final NormalOperation sigmaPlus = NormalOperation.floatOnly(
      floatCalc: (Model m) {
        throw "@@ TODO";
      },
      name: 'E+');
  static final NormalOperation sigmaMinus = NormalOperation.floatOnly(
      floatCalc: (Model m) {
        throw "@@ TODO";
      },
      name: 'E-');
  static final NormalOperation pYX = NormalOperation.floatOnly(
      floatCalc: (Model m) {
        throw "@@ TODO";
      },
      name: 'Py,x');
  static final NormalOperation cYX = NormalOperation.floatOnly(
      floatCalc: (Model m) {
        throw "@@ TODO";
      },
      name: 'Cy,x');

  static void _storeToMatrix(Model m, bool increment, int matrix) {
    throw "@@ TODO";
  }

  static void _storeMatrix(Model m, int matrix) {
    throw "@@ TODO";
  }

  static final NormalArgOperation sto15 = NormalArgOperation(
      maxOneByteOpcodes: 33,
      arg: ArgAlternates(synonyms: _matrixSynonyms, children: [
        // 0-.9, I
        RegisterWriteArg(
            maxDigit: 19, noParenI: true, f: (m) => m.x), // 21 opcodes
        KeyArg(
            key: Operations15.resultOp,
            child: ArgDone((m) {
              final matrix = (m as Model15).x.asMatrix;
              if (matrix == null) {
                throw CalculatorError(11);
              } else {
                m.resultMatrix = matrix;
              }
            })),
        // g A..E
        KeyArg(
            key: Operations15.xSquared, child: ArgDone((m) => throw "@@ TODO")),
        KeyArg(key: Operations15.lnOp, child: ArgDone((m) => throw "@@ TODO")),
        KeyArg(key: Operations15.logOp, child: ArgDone((m) => throw "@@ TODO")),
        KeyArg(
            key: Operations15.percent, child: ArgDone((m) => throw "@@ TODO")),
        KeyArg(
            key: Operations15.deltaPercent,
            child: ArgDone((m) => throw "@@ TODO")),
        // Not user mode, A..E, (i)
        UserArg(
            userMode: false,
            child: ArgAlternates(synonyms: Arg.registerISynonyms, children: [
              KeysArg(
                  keys: _letterLabels,
                  generator: (i) =>
                      ArgDone((m) => _storeToMatrix(m, false, i))),
              KeyArg(
                  key: Operations15.parenI15,
                  child: ArgDone((m) => throw "@@ TODO"))
            ])),
        UserArg(
            userMode: true,
            child: ArgAlternates(
              synonyms: Arg.registerISynonyms,
              children: [
                KeysArg(
                    keys: _letterLabels,
                    generator: (i) =>
                        ArgDone((m) => _storeToMatrix(m, true, i))),
                KeyArg(
                    key: Operations15.parenI15,
                    child: ArgDone((m) => throw "@@ TODO"))
              ],
            )),
        KeyArg(
            // STO MATRIX A..E.  These are two-byte opcodes.
            key: Operations15.matrix,
            child: KeysArg(
                keys: _letterLabels,
                generator: (i) => ArgDone((m) => _storeMatrix(m, i)))),
        KeyArg(
            key: Operations.plus,
            child: RegisterWriteOpArg(
                maxDigit: 19, f: (double r, double x) => r + x)),
        KeyArg(
            key: Operations.minus,
            child: RegisterWriteOpArg(
                maxDigit: 19, f: (double r, double x) => r - x)),
        KeyArg(
            key: Operations.mult,
            child: RegisterWriteOpArg(
                maxDigit: 19, f: (double r, double x) => r * x)),
        KeyArg(
            key: Operations.div,
            child: RegisterWriteOpArg(
                maxDigit: 19, f: (double r, double x) => r / x)),
        KeyArg(
            key: Operations15.cosInverse, // That's g (i)
            child: ArgDone((m) => throw "@@ TODO"))
      ]),
      name: 'STO');

  static void _recallFromMatrix(Model m, bool increment, int matrix) {
    throw "@@ TODO";
  }

  static void _recallMatrix(Model m, int matrix) {
    throw "@@ TODO";
  }

  static final NormalArgOperation rcl15 = NormalArgOperationWithBeforeCalc(
      maxOneByteOpcodes: 44,
      beforeCalculate: (Resting s) {
        s.liftStackIfEnabled();
        return StackLift.neutral;
      },
      arg: ArgAlternates(synonyms: _matrixSynonyms, children: [
        RegisterWriteArg(maxDigit: 19, noParenI: true, f: (m) => m.x),
        // g A..E
        KeyArg(
            key: Operations15.xSquared, child: ArgDone((m) => throw "@@ TODO")),
        KeyArg(key: Operations15.lnOp, child: ArgDone((m) => throw "@@ TODO")),
        KeyArg(key: Operations15.logOp, child: ArgDone((m) => throw "@@ TODO")),
        KeyArg(
            key: Operations15.percent, child: ArgDone((m) => throw "@@ TODO")),
        KeyArg(
            key: Operations15.deltaPercent,
            child: ArgDone((m) => throw "@@ TODO")),
        KeyArg(
            key: Operations15.dim,
            child: ArgAlternates(synonyms: Arg.registerISynonyms, children: [
              KeysArg(
                  keys: _letterLabels,
                  generator: (i) => ArgDone((m) => throw "@@ TODO")),
              KeyArg(
                  key: Operations15.parenI15,
                  child: ArgDone((m) => throw "@@ TODO"))
            ])),
        KeyArg(
            key: Operations15.resultOp,
            child: ArgDone((m) =>
                m.resultX = Value.fromMatrix((m as Model15).resultMatrix))),
        KeyArg(
            // RCL MATRIX A..E.  These are one-byte opcodes.
            key: Operations15.matrix,
            child: KeysArg(
                keys: _letterLabels,
                generator: (i) => ArgDone((m) => _recallMatrix(m, i)))),
        UserArg(
            userMode: false,
            child: ArgAlternates(synonyms: Arg.registerISynonyms, children: [
              KeysArg(
                  keys: _letterLabels,
                  generator: (i) =>
                      ArgDone((m) => _recallFromMatrix(m, false, i))),
              KeyArg(
                  key: Operations15.parenI15,
                  child: ArgDone((m) => throw "@@ TODO"))
            ])),
        UserArg(
            userMode: true,
            child: ArgAlternates(synonyms: Arg.registerISynonyms, children: [
              KeysArg(
                  keys: _letterLabels,
                  generator: (i) =>
                      ArgDone((m) => _recallFromMatrix(m, true, i))),
              KeyArg(
                  key: Operations15.parenI15,
                  child: ArgDone((m) => throw "@@ TODO"))
            ])),
        KeyArg(
            key: Operations.plus,
            child: RegisterReadOpArg(
                maxDigit: 19, f: (double r, double x) => r + x)),
        KeyArg(
            key: Operations.minus,
            child: RegisterReadOpArg(
                maxDigit: 19, f: (double r, double x) => r - x)),
        KeyArg(
            key: Operations.mult,
            child: RegisterReadOpArg(
                maxDigit: 19, f: (double r, double x) => r * x)),
        KeyArg(
            key: Operations.div,
            child: RegisterReadOpArg(
                maxDigit: 19, f: (double r, double x) => r / x)),
        KeyArg(
            key: Operations15.cosInverse, // That's g (i)
            child: ArgDone((m) => throw "@@ TODO"))
      ]),
      name: 'RCL');

  static double _checkResult(double Function() f, int errNo) {
    try {
      final v = f();
      if (v != double.nan) {
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
      if (v.real != double.nan && v.imaginary != double.nan) {
        return v;
      }
    } catch (ex) {
      debugPrint('Converting $ex to CalculatorException($errNo)');
    }
    throw CalculatorError(errNo);
  }
}

///
/// The layout of the buttons (part of the view, but retrieved by the
/// controller as part of initialization).
///
class ButtonLayout15 extends ButtonLayout {
  final ButtonFactory factory;
  final double _totalButtonHeight;
  final double _buttonHeight;

  ButtonLayout15(this.factory, this._totalButtonHeight, this._buttonHeight);

  CalculatorButton get sqrt => CalculatorWhiteSqrtButton(
      factory,
      '\u221Ax',
      'A',
      'x^2',
      Operations15.sqrtOp15,
      Operations15.letterLabelA,
      Operations15.xSquared,
      'A');
  CalculatorButton get eX => CalculatorButton(factory, 'e^x', 'B', 'LN',
      Operations15.eX15, Operations15.letterLabelB, Operations15.lnOp, 'B');
  CalculatorButton get tenX => CalculatorButton(factory, '10^x', 'C', 'LOG',
      Operations15.tenX15, Operations15.letterLabelC, Operations15.logOp, 'C');
  CalculatorButton get yX => CalculatorButton(factory, 'y^x', 'D', '%',
      Operations15.yX15, Operations15.letterLabelD, Operations15.percent, 'D');
  CalculatorButton get reciprocal => CalculatorButton(
      factory,
      '1/x',
      'E',
      '\u0394%',
      Operations15.reciprocal15,
      Operations15.letterLabelE,
      Operations15.deltaPercent,
      'E');
  CalculatorButton get chs => CalculatorButton(factory, 'CHS', 'MATRIX', 'ABS',
      Operations.chs, Operations15.matrix, Operations.abs, 'F');
  CalculatorButton get n7 => CalculatorButton(factory, '7', 'FIX', 'DEG',
      Operations.n7, Operations15.fix, Operations15.deg, '7');
  CalculatorButton get n8 => CalculatorButton(factory, '8', 'SCI', 'RAD',
      Operations.n8, Operations15.sci, Operations15.rad, '8');
  CalculatorButton get n9 => CalculatorButton(factory, '9', 'ENG', 'GRD',
      Operations.n9, Operations15.eng, Operations15.grd, '9');
  CalculatorButton get div => CalculatorButton(factory, '\u00F7', 'SOLVE',
      'x\u2264y', Operations.div, Operations15.solve, Operations.xLEy, '/');

  CalculatorButton get sst => CalculatorButton(factory, 'SST', 'LBL', 'BST',
      Operations.sst, Operations15.lbl15, Operations.bst, 'U');
  CalculatorButton get gto => CalculatorButton(
      factory,
      'GTO',
      'HYP',
      'HYP^\u2009\u22121',
      Operations15.gto,
      Operations15.hyp,
      Operations15.hypInverse,
      'T');
  CalculatorButton get sin => CalculatorButtonHyperbolic(
      factory,
      'SIN',
      'DIM',
      'SIN^\u2009\u22121',
      Operations15.sin,
      Operations15.dim,
      Operations15.sinInverse,
      Operations15.sinh,
      Operations15.sinhInverse,
      'I');
  CalculatorButton get cos => CalculatorButtonHyperbolic(
      factory,
      'COS',
      '(i)',
      'COS^\u2009\u22121',
      Operations15.cos,
      Operations15.parenI15,
      Operations15.cosInverse,
      Operations15.cosh,
      Operations15.coshInverse,
      'Z');
  CalculatorButton get tan => CalculatorButtonHyperbolic(
      factory,
      'TAN',
      'I',
      'TAN^\u2009\u22121',
      Operations15.tan,
      Operations15.I15,
      Operations15.tanInverse,
      Operations15.tanh,
      Operations15.tanhInverse,
      'K');

  CalculatorButton get eex => CalculatorButton(factory, 'EEX', 'RESULT',
      '\u03c0', Operations.eex, Operations15.resultOp, Operations15.piOp, 'L');
  CalculatorButton get n4 => CalculatorButton(factory, '4', 'x\u2b0c', 'SF',
      Operations.n4, Operations15.xExchange, Operations15.sf, '4');
  CalculatorButton get n5 => CalculatorButton(factory, '5', 'DSE', 'CF',
      Operations.n5, Operations15.dse, Operations15.cf, '5');
  CalculatorButton get n6 => CalculatorButton(factory, '6', 'ISG', 'F?',
      Operations.n6, Operations15.isg, Operations15.fQuestion, '6');
  CalculatorButton get mult => CalculatorOnSpecialButton(
      factory,
      '\u00D7',
      '\u222b^\u200ax^y',
      'x=0',
      Operations.mult,
      Operations15.integrate,
      Operations.xEQ0,
      'X*',
      'TST',
      acceleratorLabel: '*\u00d7');

  CalculatorButton get rs => CalculatorButton(factory, 'R/S', 'PSE', 'P/R',
      Operations.rs, Operations.pse, Operations.pr, '[');
  CalculatorButton get gsb => CalculatorButton(factory, 'GSB', '\u03a3', 'RTN',
      Operations15.gsb, Operations15.clearSigma, Operations.rtn, ']');
  CalculatorButton get rdown => CalculatorButton(factory, 'R\u2193', 'PRGM',
      'R\u2191', Operations.rDown, Operations.clearPrgm, Operations.rUp, 'V');
  CalculatorButton get xy => CalculatorButton(factory, 'x\u2b0cy', 'REG', 'RND',
      Operations.xy, Operations.clearReg, Operations15.rnd, 'Y');
  CalculatorButton get bsp => CalculatorButton(
      factory,
      '\u2b05',
      'PREFIX',
      'CLx',
      Operations.bsp,
      Operations.clearPrefix,
      Operations.clx,
      '\u0008\u007f\uf728',
      acceleratorLabel: '\u2190');
  @override
  CalculatorButton get enter => CalculatorEnterButton(
      factory,
      'E\nN\nT\nE\nR',
      'RAN #',
      'LSTx',
      Operations.enter,
      Operations15.ranNum,
      Operations.lstx,
      '\n\r',
      extraHeight: factory.height * _totalButtonHeight / _buttonHeight,
      acceleratorLabel: ' \u23ce');
  CalculatorButton get n1 => CalculatorButton(factory, '1', '\u279cR',
      '\u279cP', Operations.n1, Operations15.toR, Operations15.toP, '1');
  CalculatorButton get n2 => CalculatorButton(factory, '2', '\u279cH.MS',
      '\u279cH', Operations.n2, Operations15.toHMS, Operations15.toH, '2');
  CalculatorButton get n3 => CalculatorButton(factory, '3', '\u279cRAD',
      '\u279cDEG', Operations.n3, Operations15.toRad, Operations15.toDeg, '3');
  CalculatorButton get minus => CalculatorOnSpecialButton(
      factory,
      '\u2212',
      'Re\u2b0cIm',
      'TEST',
      Operations.minus,
      Operations15.reImSwap,
      Operations15.testOp,
      '-',
      'CLR',
      acceleratorLabel: '\u2212');

  CalculatorButton get onOff => CalculatorOnButton(factory, 'ON', '', '',
      Operations.onOff, Operations.onOff, Operations.onOff, 'O', 'OFF');
  CalculatorButton get fShift => CalculatorFButton(factory, 'f', '', '',
      Operations.fShift, Operations.fShift, Operations.fShift, 'M\u0006',
      acceleratorLabel: 'M');
  CalculatorButton get gShift => CalculatorGButton(factory, 'g', '', '',
      Operations.gShift, Operations.gShift, Operations.gShift, 'G\u0007',
      acceleratorLabel: 'G');
  CalculatorButton get sto => CalculatorButton(factory, 'STO', 'FRAC', 'INT',
      Operations15.sto15, Operations15.fracOp, Operations15.intOp, 'S<');
  CalculatorButton get rcl => CalculatorButton(factory, 'RCL', 'USER', 'MEM',
      Operations15.rcl15, Operations15.userOp, Operations.mem, 'R>');
  CalculatorButton get n0 => CalculatorButton(factory, '0', 'x!', 'x\u0305',
      Operations.n0, Operations15.xFactorial, Operations15.xBar, '0');
  CalculatorButton get dot => CalculatorOnSpecialButton(
      factory,
      '\u2219',
      'y\u0302,r',
      'x\u22600',
      Operations.dot,
      Operations15.yHatR,
      Operations15.sOp,
      '.',
      '\u2219/\u201a',
      acceleratorLabel: '\u2219');
  CalculatorButton get sum => CalculatorButton(
      factory,
      '\u03a3+',
      'L.R.',
      '\u03a3-',
      Operations15.sigmaPlus,
      Operations15.linearRegression,
      Operations15.sigmaMinus,
      'H');
  CalculatorButton get plus => CalculatorButton(factory, '+', 'P\u200ay,x',
      'C\u2009y,x', Operations.plus, Operations15.pYX, Operations15.cYX, '+=');

  @override
  List<List<CalculatorButton?>> get landscapeLayout => [
        [sqrt, eX, tenX, yX, reciprocal, chs, n7, n8, n9, div],
        [sst, gto, sin, cos, tan, eex, n4, n5, n6, mult],
        [rs, gsb, rdown, xy, bsp, null, n1, n2, n3, minus],
        [onOff, fShift, gShift, sto, rcl, null, n0, dot, sum, plus]
      ];

  @override
  List<List<CalculatorButton?>> get portraitLayout => [
        [sqrt, eX, tenX, yX, reciprocal, onOff],
        [sst, gto, sin, cos, tan, chs],
        [rs, gsb, rdown, xy, bsp, eex],
        [sto, rcl, n7, n8, n9, div],
        [fShift, gShift, n4, n5, n6, mult],
        [null, null, n1, n2, n3, minus],
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
      String acceleratorKey,
      {String? acceleratorLabel,
      Key? key})
      : super(bFactory, uText, fText, gText, uKey, fKey, gKey, acceleratorKey,
            acceleratorLabel: acceleratorLabel, key: key);
}

class LandscapeButtonFactory15 extends LandscapeButtonFactory {
  LandscapeButtonFactory15(
      BuildContext context, ScreenPositioner screen, RealController controller)
      : super(context, screen, controller);

  @override
  Offset get fTextOffset => const Offset(0, -4);

  @override
  double get shiftDownTweak => 0.014;

  @override
  double addUpperGoldLabels(List<Widget> result, Rect pos,
      {required double th,
      required double tw,
      required double bh,
      required double bw}) {
    double y = pos.top;
    result.add(screen.box(
        Rect.fromLTRB(pos.left + 1 * tw - 0.05, y + 2 * th - 0.155,
            pos.left + 4 * tw + bw + 0.05, y + 2 * th + 0.065),
        CustomPaint(
            painter: UpperLabel('CLEAR', fTextSmallLabelStyle,
                height * (0.065 + 0.155) / bh))));
    return shiftDownTweak;
  }
}

class PortraitButtonFactory15 extends PortraitButtonFactory {
  PortraitButtonFactory15(
      BuildContext context, ScreenPositioner screen, RealController controller)
      : super(context, screen, controller);

  @override
  Offset get fTextOffset => const Offset(0, -4);

  @override
  double addUpperGoldLabels(List<Widget> result, Rect pos,
      {required double th,
      required double tw,
      required double bh,
      required double bw}) {
    double y = pos.top;
    result.add(screen.box(
        Rect.fromLTWH(
            pos.left + tw - 0.05, y + 2 * th + 0.07, 3 * tw + bw + 0.10, 0.22),
        CustomPaint(
            painter: UpperLabel('CLEAR', fTextSmallLabelStyle,
                height * (0.065 + 0.155) / bh))));
    return 0.28;
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
      String acceleratorKey,
      {String? acceleratorLabel,
      Key? key})
      : super(bFactory, uText, fText, gText, uKey, fKey, gKey, acceleratorKey,
            acceleratorLabel: acceleratorLabel, key: key);
}

class Controller15 extends RealController {
  Controller15(Model<Operation> model)
      : super(model,
            numbers: numbers,
            shortcuts: const {},
            lblOperation: Operations15.lbl15);

  @override
  List<Operation> get nonProgrammableOperations => _nonProgrammableOperations;

  static final _nonProgrammableOperations = [
    ...Operations.special,
    Operations15.hyp,
    Operations15.hypInverse,
    Operations15.userOp,
  ];

  static final _userModeSwapped = <Operation, Operation>{
    Operations15.letterLabelA: Operations15.sqrtOp15,
    Operations15.sqrtOp15: Operations15.letterLabelA,
    Operations15.letterLabelB: Operations15.eX15,
    Operations15.eX15: Operations15.letterLabelB,
    Operations15.letterLabelC: Operations15.tenX15,
    Operations15.tenX15: Operations15.letterLabelC,
    Operations15.letterLabelD: Operations15.yX15,
    Operations15.yX15: Operations15.letterLabelD,
    Operations15.letterLabelE: Operations15.reciprocal15,
    Operations15.reciprocal15: Operations15.letterLabelE
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
    } else if (lastKey == Operations15.hyp) {
      buttonDown(b.hyperOp);
    } else if (lastKey == Operations15.hypInverse) {
      buttonDown(b.inverseHyperOp);
    } else {
      super.buttonWidgetDown(b);
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
    Operations.n9
  ];

  @override
  Operation get gotoLineNumberKey => Operations.chs;

  @override
  SelfTests newSelfTests({bool inCalculator = true}) =>
      SelfTests15(inCalculator: inCalculator);

  @override
  ButtonLayout15 getButtonLayout(ButtonFactory factory, double totalHeight,
          double totalButtonHeight) =>
      ButtonLayout15(factory, totalHeight, totalButtonHeight);

  @override
  BackPanel15 getBackPanel() => const BackPanel15();

  @override
  LandscapeButtonFactory getLandscapeButtonFactory(
          BuildContext context, ScreenPositioner screen) =>
      LandscapeButtonFactory15(context, screen, this);

  @override
  PortraitButtonFactory getPortraitButtonFactory(
          BuildContext context, ScreenPositioner screen) =>
      PortraitButtonFactory15(context, screen, this);

  @override
  int get argBase => 10;

  @override
  int getErrorNumber(CalculatorError err) => err.num15;

  @override
  NormalArgOperation get gsbOperation => Operations15.gsb;

  @override
  NormalArgOperation get gtoOperation => Operations15.gto;
}

//
// See Model.logicalKeys.  This table determines the operation opcodes.
// Changing the order here would render old JSON files of the
// calculator's state obsolete.
final List<List<MKey<Operation>?>> _logicalKeys = [
  [
    MKey(Operations15.sqrtOp15, Operations15.letterLabelA,
        Operations15.xSquared),
    MKey(Operations15.eX15, Operations15.letterLabelB, Operations15.lnOp),
    MKey(Operations15.tenX15, Operations15.letterLabelC, Operations15.logOp),
    MKey(Operations15.yX15, Operations15.letterLabelD, Operations15.percent),
    MKey(Operations15.reciprocal15, Operations15.letterLabelE,
        Operations15.deltaPercent),
    MKey(Operations.chs, Operations15.matrix, Operations.abs),
    MKey(Operations.n7, Operations15.fix, Operations15.deg),
    MKey(Operations.n8, Operations15.sci, Operations15.rad),
    MKey(Operations.n9, Operations15.eng, Operations15.grd),
    MKey(Operations.div, Operations15.solve, Operations.xLEy),
  ],
  [
    MKey(Operations.sst, Operations15.lbl15, Operations.bst),
    MKey(Operations15.gto, Operations15.hyp, Operations15.hypInverse),
    MKey(Operations15.sin, Operations15.dim, Operations15.sinInverse,
        extensionOps: [
          MKeyExtensionOp(
              Operations15.sinh, Operations.fShift, Operations15.hyp),
          MKeyExtensionOp(Operations15.sinhInverse, Operations.gShift,
              Operations15.hypInverse)
        ]),
    MKey(Operations15.cos, Operations15.parenI15, Operations15.cosInverse,
        extensionOps: [
          MKeyExtensionOp(
              Operations15.cosh, Operations.fShift, Operations15.hyp),
          MKeyExtensionOp(Operations15.coshInverse, Operations.gShift,
              Operations15.hypInverse)
        ]),
    MKey(Operations15.tan, Operations15.I15, Operations15.tanInverse,
        extensionOps: [
          MKeyExtensionOp(
              Operations15.tanh, Operations.fShift, Operations15.hyp),
          MKeyExtensionOp(Operations15.tanhInverse, Operations.gShift,
              Operations15.hypInverse)
        ]),
    MKey(Operations.eex, Operations15.resultOp, Operations15.piOp),
    MKey(Operations.n4, Operations15.xExchange, Operations15.sf),
    MKey(Operations.n5, Operations15.dse, Operations15.cf),
    MKey(Operations.n6, Operations15.isg, Operations15.fQuestion),
    MKey(Operations.mult, Operations15.integrate, Operations.xEQ0),
  ],
  [
    MKey(Operations.rs, Operations.pse, Operations.pr),
    MKey(Operations15.gsb, Operations15.clearSigma, Operations.rtn),
    MKey(Operations.rDown, Operations.clearPrgm, Operations.rUp),
    MKey(Operations.xy, Operations.clearReg, Operations15.rnd),
    MKey(Operations.bsp, Operations.clearPrefix, Operations.clx),
    MKey(Operations.enter, Operations15.ranNum, Operations.lstx),
    MKey(Operations.n1, Operations15.toR, Operations15.toP),
    MKey(Operations.n2, Operations15.toHMS, Operations15.toH),
    MKey(Operations.n3, Operations15.toRad, Operations15.toDeg),
    MKey(Operations.minus, Operations15.reImSwap, Operations15.testOp),
  ],
  [
    MKey(Operations.onOff, Operations.onOff, Operations.onOff),
    MKey(Operations.fShift, Operations.fShift, Operations.fShift),
    MKey(Operations.gShift, Operations.gShift, Operations.gShift),
    MKey(Operations15.sto15, Operations15.fracOp, Operations15.intOp),
    MKey(Operations15.rcl15, Operations15.userOp, Operations.mem),
    null,
    MKey(Operations.n0, Operations15.xFactorial, Operations15.xBar),
    MKey(Operations.dot, Operations15.yHatR, Operations15.sOp),
    MKey(Operations15.sigmaPlus, Operations15.linearRegression,
        Operations15.sigmaMinus),
    MKey(Operations.plus, Operations15.pYX, Operations15.cYX),
  ]
];

final Set<LetterLabel> _letterLabels = {
  Operations15.letterLabelA,
  Operations15.letterLabelB,
  Operations15.letterLabelC,
  Operations15.letterLabelD,
  Operations15.letterLabelE
};

final _letterLabelsList = _letterLabels.toList(growable: false);

ProgramInstruction<Operation> _newProgramInstruction(
    Operation operation, ArgDone arg) {
  if (_letterLabels.contains(operation)) {
    arg = Operations15.gsb.arg.matches(operation, false) as ArgDone;
    operation = Operations15.gsb;
  }
  return ProgramInstruction15(operation, arg);
}

class ProgramInstruction15<OT extends ProgramOperation>
    extends ProgramInstruction<OT> {
  ProgramInstruction15(OT op, ArgDone arg) : super(op, arg);
}
