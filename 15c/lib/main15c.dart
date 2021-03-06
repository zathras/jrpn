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

import 'dart:async';
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
import 'matrix.dart';
import 'tests15c.dart';
import 'model15c.dart';
import 'linear_algebra.dart' as linalg;

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
  Arg.registerISynonyms = Operations15._registerISynonyms;
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
  // The numeric values match the I register values for GSB I, as per the
  // table on page 107 of the 15C manual.

  static final _registerISynonyms = {
    Operations15.tan: Operations15.I15,
    Operations15.cos: Operations15.parenI15
  };

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
        KeyArg(key: letterLabelA, child: ArgDone((m) {})),
        KeyArg(key: letterLabelB, child: ArgDone((m) {})),
        KeyArg(key: letterLabelC, child: ArgDone((m) {})),
        KeyArg(key: letterLabelD, child: ArgDone((m) {})),
        KeyArg(key: letterLabelE, child: ArgDone((m) {})),
        DigitArg(max: 19, calc: (_, __) {})
      ]),
      name: 'LBL');

  static final NormalOperation div = NormalOperation.floatOnly(
      floatCalc: (Model m) {
        _scalarOrMatrix(m, scalar: (x, y) {
          try {
            return y / x;
            // ignore: avoid_catches_without_on_clauses
          } catch (e) {
            throw CalculatorError(0);
          }
        }, matrix: (m, x, y, r) {
          if (x != r) {
            r.resize(m, y.rows, y.columns);
          }
          try {
            linalg.solve(x, y, r);
          } on linalg.MatrixOverflow {
            m.floatOverflow = true;
          }
        });
      },
      complexCalc: (Model m) {
        if (m.x.asMatrix != null || m.y.asMatrix != null) {
          div.floatCalc!(m);
        } else {
          m.popSetResultXC = m.yC / m.xC;
        }
      },
      name: '/');

  static void _scalarOrMatrix(Model m,
      {required double Function(double, double) scalar,
      required void Function(Model15 m, Matrix x, Matrix y, Matrix r) matrix}) {
    m as Model15;
    final int? mx = m.x.asMatrix;
    final int? my = m.y.asMatrix;
    if (mx == null && my == null) {
      m.popSetResultXF = scalar(m.xF, m.yF);
    } else {
      final result = m.matrices[m.resultMatrix];
      if (mx == null) {
        final matY = m.matrices[my!];
        final x = m.xF;
        result.resize(m, matY.rows, matY.columns);
        matY.visit((r, c) {
          result.setF(r, c, scalar(x, matY.getF(r, c)));
        });
      } else if (my == null) {
        final matX = m.matrices[mx];
        final y = m.yF;
        result.resize(m, matX.rows, matX.columns);
        matX.visit((r, c) {
          result.setF(r, c, scalar(matX.getF(r, c), y));
        });
      } else {
        final matX = m.matrices[mx];
        final matY = m.matrices[my];
        final result = m.matrices[m.resultMatrix];
        matrix(m, matX, matY, result);
      }
      m.popSetResultX = Value.fromMatrix(m.resultMatrix);
    }
  }

  static final NormalOperation mult = NormalOperation.floatOnly(
      floatCalc: (Model m) {
        _scalarOrMatrix(m,
            scalar: (x, y) => y * x,
            matrix: (m, x, y, r) => _matrixMultiply(m, x, y, r));
      },
      complexCalc: (Model m) {
        if (m.x.asMatrix != null || m.y.asMatrix != null) {
          mult.floatCalc!(m);
        } else {
          m.popSetResultXC = m.yC * m.xC;
        }
      },
      name: '*');

  /// Calculate result = y * x
  static void _matrixMultiply(Model15 m, AMatrix x, AMatrix y, Matrix result) {
    if (result == x || result == y) {
      throw CalculatorError(11);
    }
    if (y.columns != x.rows) {
      throw CalculatorError(11);
    }
    result.resize(m, y.rows, x.columns);
    result.dot(y, x);
  }

  static final NormalOperation plus = NormalOperation.floatOnly(
      floatCalc: (Model m) {
        _scalarOrMatrix(m,
            scalar: (x, y) => y + x,
            matrix: (m, x, y, r) {
              _addOrSubtractMatricesXY((x, y) => y + x, m, x, y, r);
            });
      },
      complexCalc: (Model m) {
        if (m.x.asMatrix != null || m.y.asMatrix != null) {
          plus.floatCalc!(m);
        } else {
          m.popSetResultXC = m.yC + m.xC;
        }
      },
      name: '+');

  static void _addOrSubtractMatricesXY(double Function(double, double) f,
      Model15 m, Matrix x, Matrix y, Matrix result) {
    if (x.rows != y.rows || x.columns != y.columns) {
      throw CalculatorError(11);
    }
    result.resize(m, x.rows, x.columns);
    result.visit((r, c) => result.setF(r, c, f(x.getF(r, c), y.getF(r, c))));
  }

  static final NormalOperation minus = NormalOperation.floatOnly(
      floatCalc: (Model m) {
        _scalarOrMatrix(m,
            scalar: (x, y) => y - x,
            matrix: (m, x, y, r) {
              _addOrSubtractMatricesXY((x, y) => y - x, m, x, y, r);
            });
      },
      complexCalc: (Model m) {
        if (m.x.asMatrix != null || m.y.asMatrix != null) {
          minus.floatCalc!(m);
        } else {
          m.popSetResultXC = m.yC - m.xC;
        }
      },
      name: '-');

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
        m.resultXF = pow(e, x) as double;
      },
      complexCalc: (Model m) {
        m.resultXC = m.xC.exp();
      },
      name: 'eX');
  static final NormalOperation xSquared = NormalOperation.floatOnly(
      floatCalc: (Model m) {
        double x = m.xF;
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
        m.resultXF = log(x) / ln10;
      },
      complexCalc: (Model m) {
        m.resultXC = _checkResultC(m.xC.ln, 0) / const Complex(ln10, 0);
      },
      name: 'log');
  static final NormalOperation yX15 = NormalOperationOrLetter.floatOnly(
      letter: letterLabelD,
      floatCalc: (Model m) {
        m.popSetResultXF = pow(m.yF, m.xF) as double;
      },
      complexCalc: (Model m) {
        m.popSetResultXC = m.yC.pow(m.xC);
      },
      name: 'yX');
  static final NormalOperation percent = NormalOperation.floatOnly(
      floatCalc: (Model m) {
        m.resultXF = m.xF * 0.01 * m.yF;
      },
      name: '%');

  static final reciprocal15 = NormalOperationOrLetter.floatOnly(
      letter: letterLabelE,
      floatCalc: (Model m) {
        final mat = m.x.asMatrix;
        if (mat == null) {
          double x = m.xF;
          if (x == 0.0) {
            throw CalculatorError(0);
          } else {
            m.resultXF = 1.0 / x;
          }
        } else {
          final result = (m as Model15).matrices[m.resultMatrix];
          result.copyFrom(m, m.matrices[mat]);
          linalg.invert(result);
          m.resultX = Value.fromMatrix(m.resultMatrix);
        }
      },
      complexCalc: (Model m) {
        if (m.x.asMatrix != null) {
          return reciprocal15.floatCalc!(m);
        }
        final x = m.xC;
        if (x == Complex.zero) {
          throw CalculatorError(0);
        } else {
          m.resultXC = const Complex(1, 0) / x;
        }
      },
      name: '1/x');

  static final NormalOperation deltaPercent = NormalOperation.floatOnly(
      floatCalc: (Model m) {
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
                mat.resize(m, 0, 0);
              }
            })),
        KeyArg(
            key: Operations.n1,
            child: ArgDone((m) {
              m.memory.registers[0] =
                  m.memory.registers[1] = Value.fromDouble(1);
            })),
        KeyArg(
            key: Operations.n2,
            child: ArgDone((m) {
              final mat = _getMatrixFromValue(m as Model15, m.x);
              mat.convertToZTilde(m);
            })),
        KeyArg(
            key: Operations.n3,
            child: ArgDone((m) {
              final mat = _getMatrixFromValue(m as Model15, m.x);
              mat.convertFromZTilde(m);
            })),
        KeyArg(
            key: Operations.n4,
            child: ArgDone((m) {
              final mat = _getMatrixFromValue(m as Model15, m.x);
              mat.transpose();
            })),
        KeyArg(
            key: Operations.n5,
            child: ArgDone((m) {
              final result = (m as Model15).matrices[m.resultMatrix];
              final x = _getMatrixFromValue(m, m.x);
              final y = _getMatrixFromValue(m, m.y);
              final yt = TransposeMatrix(y);
              _matrixMultiply(m, x, yt, result);
              m.popSetResultX = Value.fromMatrix(m.resultMatrix);
            })),
        KeyArg(
            key: Operations.n6,
            child: ArgDone((m) {
              final result = (m as Model15).matrices[m.resultMatrix];
              final x = _getMatrixFromValue(m, m.x);
              final y = _getMatrixFromValue(m, m.y);
              if (result == x || result == y) {
                throw CalculatorError(11);
              }
              if (y.columns != x.rows) {
                throw CalculatorError(11);
              }
              if (result.rows != y.rows || result.columns != x.columns) {
                throw CalculatorError(11);
              }
              result.residual(y, x);
              m.popSetResultX = Value.fromMatrix(m.resultMatrix);
            })),
        KeyArg(
            key: Operations.n7,
            child: ArgDone((m) {
              final mat = m.x.asMatrix;
              if (mat != null) {
                m.resultXF = linalg.rowNorm((m as Model15).matrices[mat]);
              }
            })),
        KeyArg(
            key: Operations.n8,
            child: ArgDone((m) {
              final mat = m.x.asMatrix;
              if (mat != null) {
                m.resultXF = linalg.frobeniusNorm((m as Model15).matrices[mat]);
              }
            })),
        KeyArg(
            key: Operations.n9,
            child: ArgDone((m) {
              final mat = m.x.asMatrix;
              if (mat == null) {
                throw CalculatorError(11);
              }
              final result = (m as Model15).matrices[m.resultMatrix];
              result.copyFrom(m, m.matrices[mat]);
              m.resultXF = linalg.determinant(result);
            })),
      ]),
      name: 'MATRIX');

  static Matrix _getMatrixFromValue(Model15 m, Value v) {
    final vi = v.asMatrix;
    if (vi == null) {
      throw CalculatorError(11);
    }
    return m.matrices[vi];
  }

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
            m.memory.program.gosub(label);
          }),
      name: 'GSB');

  static final NormalArgOperation gto = NormalArgOperation(
      maxOneByteOpcodes: 16, // I, A..E, 0..9.  .0-.9 are two byte.
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
    int r = m.yF.truncate();
    int c = m.xF.truncate();
    if (r < 0 || c < 0) {
      throw CalculatorError(1);
    }
    final mat = m.matrices[arg];
    m.memory.policy.checkAvailable(r * c - mat.length);
    mat.resize(m, r, c);
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
      arg: RegisterWriteOpArg(
          maxDigit: 19,
          f: (m, reg, x) {
            m.xF = reg;
            return x;
          }),
      name: 'x<->');
  static final NormalArgOperation dse = NormalArgOperation(
      maxOneByteOpcodes: 4,
      arg: RegisterWriteOpArg(
          maxDigit: 19,
          f: (m, double r, double x) {
            return _skipIf(m, r, (n, x) => n > x, (n, y) => n - y);
          }),
      name: 'DSE');
  static final NormalArgOperation isg = NormalArgOperation(
      maxOneByteOpcodes: 4,
      arg: RegisterWriteOpArg(
          maxDigit: 19,
          f: (m, double r, double x) {
            return _skipIf(m, r, (n, x) => n <= x, (n, y) => n + y);
          }),
      name: 'ISG');

  static double _skipIf(Model m, double val,
      bool Function(double n, int x) skip, double Function(double n, int y) f) {
    double n = val.truncateToDouble();
    final double fracD = (val - n).abs();
    final int frac = (fracD * 100000).truncate();
    final int x = frac ~/ 100;
    final int y = frac % 100;
    n = f(n, y);
    if (skip(n, x)) {
      m.program.incrementCurrentLine(); // Even if not running
    }
    if (n > 0) {
      return n + fracD;
    } else {
      return n - fracD;
    }
  }

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
        final mx = m.x.asMatrix;
        if (mx == null) {
          throw "@@ TODO";
        } else {
          (m as Model15).matrices[mx].convertToZP();
        }
      },
      name: 'Py,x');
  static final NormalOperation cYX = NormalOperation.floatOnly(
      floatCalc: (Model m) {
        final mx = m.x.asMatrix;
        if (mx == null) {
          throw "@@ TODO";
        } else {
          (m as Model15).matrices[mx].convertToZC();
        }
      },
      name: 'Cy,x');

  static void _storeToMatrix(Model m, bool increment, int matrixNumber) {
    final matrix = (m as Model15).matrices[matrixNumber];
    int toI(int r) => m.memory.registers[r].asDouble.truncate().abs();

    int row = toI(0) - 1;
    int col = toI(1) - 1;
    _showMatrixR0R1(m, matrix);
    m.deferToButtonUp = DeferredFunction(m, () {
      if (row == 1 && col == 1) {
        matrix.isLU = false;
      }
      matrix.set(row, col, m.x);
      if (increment) {
        _incrementR0R1(m, row, col, matrix);
      }
    }).run;
  }

  static void _recallFromMatrix(Model m, Matrix matrix, bool increment) {
    int toI(int r) => m.memory.registers[r].asDouble.truncate().abs();

    int row = toI(0) - 1;
    int col = toI(1) - 1;
    m.x = matrix.get(row, col);
    if (increment) {
      _incrementR0R1(m, row, col, matrix);
    }
  }

  static void _incrementR0R1(Model m, int row, int col, Matrix matrix) {
    void storeI(int r, int v) {
      final d = m.memory.registers[r].asDouble;
      m.memory.registers[r] = Value.fromDouble(v * d.sign + (d - d.truncate()));
    }

    col++;
    if (col >= matrix.columns) {
      col = 0;
      row++;
      if (row >= matrix.rows) {
        row = 0;
        m.program.skipIfRunning();
      }
    }
    storeI(0, row + 1);
    storeI(1, col + 1);
  }

  static void _showMatrixR0R1(Model m, Matrix matrix) {
    int toI(int r) => m.memory.registers[r].asDouble.truncate().abs();
    int row = toI(0) - 1;
    int col = toI(1) - 1;
    matrix.checkIndices(row, col);
    _showMatrix(m, matrix, row, col);
  }

  static void _showMatrix(Model m, Matrix matrix, int row, int col) {
    m.display.current = '${matrix.name}  $row,$col';
    m.display.update(flash: false);
  }

  static void _storeMatrix(Model m, int matrix) {
    final srcMatrix = m.x.asMatrix;
    final dest = (m as Model15).matrices[matrix];
    if (srcMatrix != null) {
      dest.copyFrom(m, m.matrices[srcMatrix]);
    } else {
      dest.isLU = false; // @@ TODO:  Where else does this happen?
      for (int i = 0; i < dest.rows; i++) {
        for (int j = 0; j < dest.columns; j++) {
          dest.set(i, j, m.x);
        }
      }
    }
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
        // g A..E:
        KeysArg(
            keys: _letterLabelsGShifted,
            generator: (i) => ArgDone((m) {
                  final matrix = (m as Model15).matrices[i];
                  final int row = m.yF.truncate().abs() - 1;
                  final int col = m.xF.truncate().abs() - 1;
                  m.z.asDouble; // Make sure it's a float
                  matrix.set(row, col, m.z);
                  m.popStack();
                  m.popStack();
                })),
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
                synonyms: _matrixSynonyms,
                keys: _letterLabels,
                generator: (i) => ArgDone((m) => _storeMatrix(m, i)))),
        KeyArg(
            key: Operations15.plus,
            child: RegisterWriteOpArg(
                maxDigit: 19, f: (m, double r, double x) => r + x)),
        KeyArg(
            key: Operations15.minus,
            child: RegisterWriteOpArg(
                maxDigit: 19, f: (m, double r, double x) => r - x)),
        KeyArg(
            key: Operations15.mult,
            child: RegisterWriteOpArg(
                maxDigit: 19, f: (m, double r, double x) => r * x)),
        KeyArg(
            key: Operations15.div,
            child: RegisterWriteOpArg(
                maxDigit: 19, f: (m, double r, double x) => r / x)),
        KeyArg(
            key: Operations15.cosInverse, // That's g (i)
            child: ArgDone((m) => throw "@@ TODO"))
      ]),
      name: 'STO');

  static final NormalArgOperation rcl15 = NormalArgOperationWithBeforeCalc(
      maxOneByteOpcodes: 44,
      beforeCalculate: (Resting s) {
        // For the matrix operations, this is deferred to key release.  It is
        // not run if the operation is cancelled.
        s.liftStackIfEnabled();
        return StackLift.neutral;
      },
      arg: ArgAlternates(synonyms: _matrixSynonyms, children: [
        RegisterReadArg(
            maxDigit: 19, noParenI: true, f: (m, v) => m.resultX = v),
        // g A..E
        KeysArg(
            keys: _letterLabelsGShifted,
            generator: (i) => DeferredRclArg(
                matrixNumber: i,
                noStackLift: true,
                pressed: (m, matrix) {
                  final int row = m.yF.truncate().abs() - 1;
                  final int col = m.xF.truncate().abs() - 1;
                  _showMatrix(m, matrix, row, col);
                },
                released: (m, matrix) {
                  final int row = m.yF.truncate().abs() - 1;
                  final int col = m.xF.truncate().abs() - 1;
                  m.popStack();
                  m.popSetResultX = matrix.get(row, col);
                })),
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
                synonyms: _matrixSynonyms,
                keys: _letterLabels,
                generator: (i) =>
                    ArgDone((m) => m.resultX = Value.fromMatrix(i)))),
        UserArg(
            userMode: false,
            child: ArgAlternates(synonyms: Arg.registerISynonyms, children: [
              KeysArg(
                  keys: _letterLabels,
                  generator: (i) => DeferredRclArg(
                      matrixNumber: i,
                      pressed: _showMatrixR0R1,
                      released: (m, matrix) =>
                          _recallFromMatrix(m, matrix, false))),
              KeyArg(
                  key: Operations15.parenI15,
                  child: ArgDone((m) => throw "@@ TODO"))
            ])),
        UserArg(
            userMode: true,
            child: ArgAlternates(synonyms: Arg.registerISynonyms, children: [
              KeysArg(
                  keys: _letterLabels,
                  generator: (i) => DeferredRclArg(
                      matrixNumber: i,
                      pressed: _showMatrixR0R1,
                      released: (m, matrix) =>
                          _recallFromMatrix(m, matrix, true))),
              KeyArg(
                  key: Operations15.parenI15,
                  child: ArgDone((m) => throw "@@ TODO"))
            ])),
        KeyArg(
            key: Operations15.plus,
            child: RegisterReadOpArg(
                maxDigit: 19, f: (double r, double x) => r + x)),
        KeyArg(
            key: Operations15.minus,
            child: RegisterReadOpArg(
                maxDigit: 19, f: (double r, double x) => r - x)),
        KeyArg(
            key: Operations15.mult,
            child: RegisterReadOpArg(
                maxDigit: 19, f: (double r, double x) => r * x)),
        KeyArg(
            key: Operations15.div,
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
/// The argument to the 15C's FIX, SCI and ENG keys
///
class PrecisionArg extends ArgAlternates {
  final void Function(Model m, int v) f;

  static int _translate(Model m, Value v) => min(9, max(0, m.xF)).floor();

  PrecisionArg({required this.f})
      : super(synonyms: Arg.registerISynonyms, children: [
          DigitArg(max: 9, calc: (m, i) => f(m, i)),
          KeyArg(
              key: Arg.kI,
              child: ArgDone(
                  (m) => f(m, _translate(m, m.memory.registers.index)))),
        ]);
}

class RegisterReadOpArg extends ArgAlternates {
  final double Function(double, double) f;

  RegisterReadOpArg({required int maxDigit, required this.f})
      : super(synonyms: RegisterWriteOpArg.targetSynonyms, children: [
          KeyArg(
              key: Arg.kParenI,
              child: ArgDone((m) {
                final mi = m.memory.registers.index.asMatrix;
                if (mi == null) {
                  m.resultXF =
                      f(m.xF, m.memory.registers.indirectIndex.asDouble);
                } else {
                  // See bottom of page 173
                  _forMatrix(m as Model15, mi, f);
                }
              })),
          KeyArg(
              key: Arg.kI,
              child: ArgDone((m) =>
                  m.resultXF = f(m.xF, m.memory.registers.index.asDouble))),
          DigitArg(
              max: maxDigit,
              calc: (m, i) =>
                  m.resultXF = f(m.xF, m.memory.registers[i].asDouble)),
          ...List.generate(
              _letterLabelsList.length,
              (i) => KeyArg(
                  key: _letterLabelsList[i],
                  child: ArgDone((m) {
                    _forMatrix(m as Model15, i, f);
                  }))),
        ]);

  static void _forMatrix(
      Model15 m, int mi, final double Function(double, double) f) {
    final mat = m.matrices[mi];
    int toI(int r) => m.memory.registers[r].asDouble.truncate().abs();
    int row = toI(0) - 1;
    int col = toI(1) - 1;
    m.resultXF = f(m.xF, mat.getF(row, col));
  }
}

class RegisterWriteOpArg extends ArgAlternates {
  final double Function(Model m, double reg, double x) f;
  static final targetSynonyms = {
    ...Operations15._registerISynonyms,
    ...Operations15._letterSynonyms
  };

  RegisterWriteOpArg({required int maxDigit, required this.f})
      : super(synonyms: targetSynonyms, children: [
          KeyArg(
              key: Arg.kParenI,
              child: ArgDone((m) {
                final mi = m.memory.registers.index.asMatrix;
                if (mi == null) {
                  m.memory.registers.indirectIndex = Value.fromDouble(
                      f(m, m.memory.registers.indirectIndex.asDouble, m.xF));
                } else {
                  // See bottom of page 173
                  _forMatrix(m as Model15, mi, f);
                }
              })),
          KeyArg(
              key: Arg.kI,
              child: ArgDone((m) => m.memory.registers.index = Value.fromDouble(
                  f(m, m.memory.registers.index.asDouble, m.xF)))),
          DigitArg(
              max: maxDigit,
              calc: (m, i) => m.memory.registers[i] =
                  Value.fromDouble(f(m, m.memory.registers[i].asDouble, m.xF))),
          ...List.generate(
              _letterLabelsList.length,
              (i) => KeyArg(
                  key: _letterLabelsList[i],
                  child: ArgDone((m) {
                    _forMatrix(m as Model15, i, f);
                  }))),
        ]);

  static void _forMatrix(
      Model15 m, int mi, final double Function(Model, double, double) f) {
    final mat = m.matrices[mi];
    int toI(int r) => m.memory.registers[r].asDouble.truncate().abs();
    int row = toI(0) - 1;
    int col = toI(1) - 1;
    mat.setF(row, col, f(m, mat.getF(row, col), m.xF));
  }
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
  void init(int registerBase,
      {required OpInitFunction f,
      required ProgramOperation? shift,
      required bool argDot,
      required ProgramOperation? arg,
      required bool userMode}) {
    assert(!argDot);
    child.init(registerBase,
        f: f, shift: shift, argDot: argDot, arg: arg, userMode: this.userMode);
  }
}

class DeferredRclArg extends ArgDone {
  final bool noStackLift;
  final int matrixNumber;

  ///
  /// Our superclasses calculate function is a NOP, because we defer the
  /// real calculation.  We need a non-null NOP there, however, so that the
  /// state machine will call our beforeCalculate().  It's a little tangled,
  /// but the 15C has a really complicated state machine!
  ///
  final void Function(Model, Matrix) pressed;
  final void Function(Model, Matrix) released;

  DeferredRclArg(
      {required this.pressed,
      required this.released,
      required this.matrixNumber,
      this.noStackLift = false})
      : super((_) {});

  ///
  /// For many of the RCL operations on matrices, we need to take over
  /// stack lift, so we do the deferral on beforeCalculate rather than
  /// calc.
  ///
  @override
  void handleOpBeforeCalculate(Model m, void Function() opBeforeCalculate) {
    final matrix = (m as Model15).matrices[matrixNumber];
    pressed(m, matrix);
    m.deferToButtonUp = DeferredFunction(m, () {
      if (!noStackLift) {
        opBeforeCalculate();
      }
      released(m, matrix);
    }).run;
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
      'x\u2264y', Operations15.div, Operations15.solve, Operations.xLEy, '/');

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
      Operations15.mult,
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
      Operations15.minus,
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
  CalculatorButton get plus => CalculatorButton(
      factory,
      '+',
      'P\u200ay,x',
      'C\u2009y,x',
      Operations15.plus,
      Operations15.pYX,
      Operations15.cYX,
      '+=');

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
  @override
  final Model15<Operation> model;

  Controller15(this.model)
      : super(
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

  @override
  bool doDeferred() {
    try {
      bool s = super.doDeferred();
      final deferred = model.deferToButtonUp;
      if (deferred != null) {
        deferred();
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

  @override
  Operation get minusOp => Operations15.minus;

  @override
  Operation get multOp => Operations15.mult;
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
    MKey(Operations15.div, Operations15.solve, Operations.xLEy),
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
    MKey(Operations15.mult, Operations15.integrate, Operations.xEQ0),
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
    MKey(Operations15.minus, Operations15.reImSwap, Operations15.testOp),
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
    MKey(Operations15.plus, Operations15.pYX, Operations15.cYX),
  ]
];

final Set<LetterLabel> _letterLabels = {
  Operations15.letterLabelA,
  Operations15.letterLabelB,
  Operations15.letterLabelC,
  Operations15.letterLabelD,
  Operations15.letterLabelE
};

final _letterLabelsGShifted = [
  Operations15.xSquared,
  Operations15.lnOp,
  Operations15.logOp,
  Operations15.percent,
  Operations15.deltaPercent
];

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

///
/// A function that is deferred  until button up, like storing matrix
/// elements (e.g. STO A).
///
class DeferredFunction {
  final void Function() f;
  final Model m;
  final bool disableDisplay;
  late final Timer _timeout;

  DeferredFunction(this.m, this.f) : disableDisplay = m.displayDisabled {
    _timeout = Timer(const Duration(seconds: 2), _expired);
    m.displayDisabled = true;
  }

  void _expired() {
    m.displayDisabled = disableDisplay;
    m.display.current = 'nv11';
    m.display.update(flash: false);
  }

  void run() {
    if (_timeout.isActive) {
      m.displayDisabled = disableDisplay;
      _timeout.cancel();
      f(); // could throw exception
    }
  }
}
