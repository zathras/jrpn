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

void main() async => genericMain(Jrpn(Controller15(Model15())));

class Model15 extends Model<Operation> {
  Model15() : super(DisplayMode.fix(4, false), 56, 10);

  @override
  reset() {
    super.reset();
    displayMode = DisplayMode.fix(4, false);
  }

  @override
  List<List<MKey<Operation>?>> get logicalKeys => _logicalKeys;

  //
  // See Model.logicalKeys.  This table determines the operation opcodes.
  // Changing the order here would render old JSON files of the
  // calculator's state obsolete.
  static final List<List<MKey<Operation>?>> _logicalKeys = [
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
      MKey(Operations.gto, Operations15.hyp, Operations15.hypInverse),
      MKey(Operations15.sin, Operations15.dim, Operations15.sinInverse,
          extensionOps: [
            MKeyExtensionOp(Operations15.sinh, '42,22,'),
            MKeyExtensionOp(Operations15.sinhInverse, '43,22,')
          ]),
      MKey(Operations15.cos, Operations15.parenI15, Operations15.cosInverse,
          extensionOps: [
            MKeyExtensionOp(Operations15.cosh, '42,22,'),
            MKeyExtensionOp(Operations15.coshInverse, '43,22,')
          ]),
      MKey(Operations15.tan, Operations15.I15, Operations15.tanInverse,
          extensionOps: [
            MKeyExtensionOp(Operations15.tanh, '42,22,'),
            MKeyExtensionOp(Operations15.tanhInverse, '43,22,')
          ]),
      MKey(Operations.eex, Operations15.resultOp, Operations15.piOp),
      MKey(Operations.n4, Operations15.xExchange, Operations.sf),
      MKey(Operations.n5, Operations15.dse, Operations.cf),
      MKey(Operations.n6, Operations15.isg, Operations.fQuestion),
      MKey(Operations.mult, Operations15.integrate, Operations.xEQ0),
    ],
    [
      MKey(Operations.rs, Operations.pse, Operations.pr),
      MKey(Operations.gsb, Operations15.clearSigma, Operations.rtn),
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

  static final Set<LetterLabel> _letterLabels = {
    Operations15.letterLabelA,
    Operations15.letterLabelB,
    Operations15.letterLabelC,
    Operations15.letterLabelD,
    Operations15.letterLabelE
  };

  @override
  bool get displayLeadingZeros => false;

  @override
  bool get cFlag => false;

  @override
  set cFlag(bool v) {
    assert(false);
  }

  @override
  bool get gFlag => false;

  @override
  set gFlag(bool v) {
    assert(false);
  }

  @override
  String get modelName => '15C';

  @override
  ProgramInstruction<Operation> newProgramInstruction(
      Operation operation, int argValue) {
    if (_letterLabels.contains(operation)) {
      assert(argValue == 0);
      argValue = operation.numericValue!;
      operation = Operations.gsb;
    }
    return ProgramInstruction15(operation, argValue);
  }

  @override
  int get returnStackSize => 7;

  @override
  bool get floatOverflow => getFlag(9);

  @override
  set floatOverflow(bool v) {
    if (v) {
      setFlag(9, v);
    }
  }

  @override
  void setFlag(int i, bool v) {
    if (i == 8) {
      isComplexMode = v;
    } else {
      super.setFlag(i, v);
    }
  }

  @override
  set isComplexMode(bool v) {
    super.setFlag(8, v);
    super.isComplexMode = v;
  }

  @override
  bool get errorBlink => floatOverflow;
  @override
  void resetErrorBlink() => setFlag(9, false);

  @override
  void decodeJson(Map<String, dynamic> json, {required bool needsSave}) {
    super.decodeJson(json, needsSave: needsSave);
    isComplexMode = getFlag(8);
  }

  @override
  int get registerNumberBase => 10;

  @override
  LcdContents selfTestContents() => LcdContents(
      hideComplement: false,
      windowEnabled: false,
      mainText: '-8,8,8,8,8,8,8,8,8,8,',
      cFlag: false,
      complexFlag: true,
      euroComma: false,
      rightJustify: false,
      bits: 64,
      sign: SignMode.unsigned,
      wordSize: 64,
      gFlag: true,
      prgmFlag: true,
      shift: ShiftKey.g,
      trigMode: TrigMode.grad,
      extraShift: ShiftKey.f);
}

class Operations15 extends Operations {
  static final letterLabelA = LetterLabel('A', 20);
  static final letterLabelB = LetterLabel('B', 21);
  static final letterLabelC = LetterLabel('C', 22);
  static final letterLabelD = LetterLabel('D', 23);
  static final letterLabelE = LetterLabel('E', 24);

  static final NormalArgOperation lbl15 = NormalArgOperation(
      arg: OperationArg.both(
          desc: const ArgDescription15C(maxArg: 24), calc: (_, __) {}),
      name: 'LBL');
  // @@@@ I am here

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
        final x = m.xC;
        final eXr = exp(x.real);
        m.resultXC =
            Complex(eXr * dart.cos(x.imaginary), eXr * dart.sin(x.imaginary));
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
        final x = m.xC;
        final r = x.r;
        if (r == 0) {
          throw CalculatorError(0);
        }
        m.resultXC = Complex(_checkResult(() => dart.log(r), 0), x.theta);
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
        final x = m.xC * const Complex(ln10, 0);
        final eXr = exp(x.real);
        m.resultXC =
            Complex(eXr * dart.cos(x.imaginary), eXr * dart.sin(x.imaginary));
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
        final x = m.xC;
        final r = x.r;
        if (r == 0) {
          throw CalculatorError(0);
        }
        m.resultXC = Complex(_checkResult(() => dart.log(r), 0), x.theta) /
            const Complex(ln10, 0);
      },
      name: 'log');
  static final NormalOperation yX15 = NormalOperationOrLetter.floatOnly(
      letter: letterLabelD,
      floatCalc: (Model m) {
        m.floatOverflow = false;
        m.popSetResultXF = pow(m.yF, m.xF) as double;
      },
      complexCalc: (Model m) {
        // y^x = e^(x ln y)
        final x = m.xC;
        final y = m.yC;
        final yR = y.r;
        if (yR == 0) {
          if (x == Complex.zero) {
            throw CalculatorError(0);
          }
          m.popSetResultXC = Complex.zero;
        } else {
          final lnY = Complex(_checkResult(() => dart.log(yR), 0), y.theta);
          final xLnY = x * lnY;
          final resultR = _checkResult(() => exp(xLnY.real), 0);
          m.popSetResultXC = Complex(resultR * dart.cos(xLnY.imaginary),
              resultR * dart.sin(xLnY.imaginary));
        }
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
  static final NormalOperation matrix = NormalOperation.floatOnly(
      floatCalc: (Model m) {
        throw "@@ TODO";
      },
      name: 'MATRIX');
  static final NormalArgOperation fix = NormalArgOperation(
      stackLift: StackLift.neutral,
      numExtendedOpCodes: 11,
      arg: OperationArg.both(
          desc: const ArgDescription15CJustI(maxArg: 10),
          calc: (Model m, int arg) {
            final digits = _precisionDigits(arg, m);
            m.displayMode = DisplayMode.fix(digits, m.isComplexMode);
          }),
      name: 'FIX');
  static int _precisionDigits(int arg, Model m) {
    if (arg == 0) {
      int i = m.memory.registers.index.asDouble.toInt();
      return max(0, min(i, 9));
    } else {
      return arg - 1;
    }
  }
  static final NormalArgOperation sci = NormalArgOperation(
      stackLift: StackLift.neutral,
      numExtendedOpCodes: 11,
      arg: OperationArg.both(
          desc: const ArgDescription15CJustI(maxArg: 10),
          calc: (Model m, int arg) {
            final digits = _precisionDigits(arg, m);
            m.displayMode = DisplayMode.sci(min(digits, 6), m.isComplexMode);
          }),
      name: 'SCI');
  static final NormalArgOperation eng = NormalArgOperation(
      stackLift: StackLift.neutral,
      numExtendedOpCodes: 11,
      arg: OperationArg.both(
          desc: const ArgDescription15CJustI(maxArg: 10),
          calc: (Model m, int arg) {
            final digits = _precisionDigits(arg, m);
            m.displayMode = DisplayMode.eng(min(6, digits), m.isComplexMode);
          }),
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
      floatCalc: (Model m) {
        throw "@@ TODO";
      },
      name: 'SOLVE');
  static final LimitedOperation hyp = LimitedOperation(
    pressed: (LimitedState c) => c.handleShift(ShiftKey.none),
      // Controller15 handles the rest
      name: 'HYP');
  static final LimitedOperation hypInverse =
      LimitedOperation(
          pressed: (LimitedState c) => c.handleShift(ShiftKey.none),
          name: 'HYP-1');
  static final NormalOperation sin = NormalOperation.floatOnly(
      floatCalc: (Model m) {
        throw "@@ TODO";
      },
      name: 'SIN');
  static final NormalOperation sinInverse = NormalOperation.floatOnly(
      floatCalc: (Model m) {
        throw "@@ TODO";
      },
      name: 'SIN-1');
  static final NormalOperation cos = NormalOperation.floatOnly(
      floatCalc: (Model m) {
        throw "@@ TODO";
      },
      name: 'COS');
  static final NormalOperation cosInverse = NormalOperation.floatOnly(
      floatCalc: (Model m) {
        throw "@@ TODO";
      },
      name: 'COS-1');
  static final NormalOperation tan = NormalOperation.floatOnly(
      floatCalc: (Model m) {
        throw "@@ TODO";
      },
      name: 'TAN');
  static final NormalOperation tanInverse = NormalOperation.floatOnly(
      floatCalc: (Model m) {
        throw "@@ TODO";
      },
      name: 'TAN-1');
  static final NormalOperation sinh = NormalOperation.floatOnly(
      floatCalc: (Model m) {
        throw "@@ TODO sinh";
      },
      name: 'SINH');
  static final NormalOperation sinhInverse = NormalOperation.floatOnly(
      floatCalc: (Model m) {
        throw "@@ TODO";
      },
      name: 'SINH-1');
  static final NormalOperation cosh = NormalOperation.floatOnly(
      floatCalc: (Model m) {
        throw "@@ TODO";
      },
      name: 'COSH');
  static final NormalOperation coshInverse = NormalOperation.floatOnly(
      floatCalc: (Model m) {
        throw "@@ TODO";
      },
      name: 'COSH-1');
  static final NormalOperation tanh = NormalOperation.floatOnly(
      floatCalc: (Model m) {
        throw "@@ TODO";
      },
      name: 'TANH');
  static final NormalOperation tanhInverse = NormalOperation.floatOnly(
      floatCalc: (Model m) {
        throw "@@ TODO";
      },
      name: 'TANH-1');
  static final NormalOperation dim = NormalOperation.floatOnly(
      floatCalc: (Model m) {
        throw "@@ TODO";
      },
      name: 'DIM');
  static final NormalOperation resultOp = NormalOperation.floatOnly(
      floatCalc: (Model m) {
        throw "@@ TODO";
      },
      name: 'RESULT');
  static final NormalOperation piOp = NormalOperation.floatOnly(
      floatCalc: (Model m) {
        throw "@@ TODO";
      },
      name: 'PI');
  static final NormalOperation xExchange = NormalOperation.floatOnly(
      floatCalc: (Model m) {
        throw "@@ TODO";
      },
      name: 'x<->');
  static final NormalOperation dse = NormalOperation.floatOnly(
      floatCalc: (Model m) {
        throw "@@ TODO";
      },
      name: 'DSE');
  static final NormalOperation isg = NormalOperation.floatOnly(
      floatCalc: (Model m) {
        throw "@@ TODO";
      },
      name: 'ISG');
  static final NormalOperation integrate = NormalOperation.floatOnly(
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
        throw "@@ TODO";
      },
      name: '->R');
  static final NormalOperation toP = NormalOperation.floatOnly(
      floatCalc: (Model m) {
        throw "@@ TODO";
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
  static final NormalOperation testOp = NormalOperation.floatOnly(
      floatCalc: (Model m) {
        throw "@@ TODO";
      },
      name: 'TEST');
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
  static final LimitedOperation userOp = LimitedOperation(
      pressed: (LimitedState s) {
        throw "@@ TODO";
      },
      name: 'USER');
  static final NormalOperation memOp = NormalOperation.floatOnly(
      floatCalc: (Model m) {
        throw "@@ TODO";
      },
      name: 'MEM');
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

  static final NormalArgOperation sto15 = NormalArgOperation(
      arg: OperationArg.both(
          desc: const ArgDescription15C(maxArg: 21),
          calc: (Model m, int arg) =>
              m.memory.registers.setValue(arg, sto15.arg, m.x)),
      name: 'STO');

  static final NormalArgOperation rcl15 = NormalArgOperation(
      arg: OperationArg.both(
          desc: const ArgDescription15C(maxArg: 21),
          pressed: (ActiveState s) => s.liftStackIfEnabled(),
          calc: (Model m, int arg) =>
              m.x = m.memory.registers.getValue(arg, rcl15.arg)),
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
}

class ProgramInstruction15 extends ProgramInstruction<Operation> {
  ProgramInstruction15(Operation op, int argValue) : super(op, argValue);

  @override
  String get programDisplay {
    if (op.maxArg == 0) {
      return rightJustify(op.programDisplay, 6);
    }
    final String as;
    if (argIsParenI) {
      as = '24';
    } else if (argIsI) {
      as = '25';
    } else {
      final av = argValue - op.arg!.desc.r0ArgumentValue;
      assert(av >= 0 && av < 25);
      if (av < 10) {
        as = ' ${av.toRadixString(10)}';
      } else if (av < 20) {
        as = ' .${(av- 10).toRadixString(10)}';
      } else {
        // A..F
        as = '1${av - 19}';
      }
    }
    return rightJustify('${op.programDisplay}$as', 6);
  }

  @override
  String get programListing {
    final String as;
    if (op.maxArg > 0) {
      if (argIsParenI) {
        as = ' (i)';
      } else if (argIsI) {
        as = ' I';
      } else {
        final av = argValue - op.arg!.desc.r0ArgumentValue;
        assert(av >= 0 && av < 25);
        if (av < 20) {
          as = ' ${argValue.toRadixString(10)}';
        } else {
          final cc = 'A'.codeUnitAt(0) + av - 20;
          as = ' ${String.fromCharCode(cc)}';
        }
      }
    } else {
      as = '';
    }
    return '${op.name}$as';
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
      Operations.gto,
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
      Operations.n4, Operations15.xExchange, Operations.sf, '4');
  CalculatorButton get n5 => CalculatorButton(factory, '5', 'DSE', 'CF',
      Operations.n5, Operations15.dse, Operations.cf, '5');
  CalculatorButton get n6 => CalculatorButton(factory, '6', 'ISG', 'F?',
      Operations.n6, Operations15.isg, Operations.fQuestion, '6');
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
      Operations.gsb, Operations15.clearSigma, Operations.rtn, ']');
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

class Controller15 extends RealController {
  Controller15(Model<Operation> model)
      : super(model, _numbers, const {}, Operations15.lbl15);

  @override
  void buttonWidgetDown(CalculatorButton b) {
    if (b is! CalculatorButtonHyperbolic) {
      super.buttonWidgetDown(b);
    } else if (lastKey == Operations15.hyp) {
      buttonDown(b.hyperOp);
    } else if (lastKey == Operations15.hypInverse) {
      buttonDown(b.inverseHyperOp);
    } else {
      super.buttonWidgetDown(b);
    }
  }

  /// The numbers.  This must be in order.
  static final List<NumberEntry> _numbers = [
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
  ButtonLayout getButtonLayout(ButtonFactory factory, double totalHeight,
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
  Set<Operation> get argIops => _argIops;
  static final Set<Operation> _argIops = {Operations15.tan, Operations15.I15};

  /// Abbreviated key sequences for (i) used as an argument
  /// cf. 16C manual p. 68
  @override
  Set<Operation> get argParenIops => _argParenIops;
  static final Set<Operation> _argParenIops = {
    Operations15.cos,
    Operations15.parenI15
  };

  @override
  int get argBase => 10;

  @override
  Set<LimitedOperation> get nonProgrammableKeys => nonProgrammableKeysStatic;

  static final Set<LimitedOperation> nonProgrammableKeysStatic = {
    ...RealController.nonProgrammableKeysStatic,
    Operations15.hyp,
    Operations15.hypInverse,
    Operations15.userOp
  };

}
