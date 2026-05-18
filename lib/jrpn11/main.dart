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
import 'package:jrpn/c/operations_scientific.dart';
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
import 'package:jrpn/m/more_math.dart';

void main(List<String> args) async {
  if (!await InternalStateWindow.takeControl(args)) {
    runStaticInitialization11();
    genericMain(Jrpn(Controller11(createModel11())));
  }
}

void runStaticInitialization11() {
  // None of these operations has an argument, so there is no circular
  // initialization here.
  Arg.kI = OperationsScientific.iOp;
  Arg.kParenI = OperationsScientific.parenIOp;
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

class Operations11 extends OperationsScientific {
  // The numeric values match the I register values for GSB I, as per the
  // table on page 107 of the 15C manual.

  static final _registerISynonyms = {
    OperationsScientific.tan: OperationsScientific.iOp,
    OperationsScientific.cos: OperationsScientific.parenIOp,
  };

  static final _letterSynonyms = {
    OperationsScientific.sqrtOp15: OperationsScientific.letterLabelA,
    OperationsScientific.eX15: OperationsScientific.letterLabelB,
    OperationsScientific.tenX15: OperationsScientific.letterLabelC,
    OperationsScientific.yX15: OperationsScientific.letterLabelD,
    Operations11.reciprocal15: OperationsScientific.letterLabelE,
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
        KeyArg(key: OperationsScientific.letterLabelA, child: ArgDone((m) {})),
        KeyArg(key: OperationsScientific.letterLabelB, child: ArgDone((m) {})),
        KeyArg(key: OperationsScientific.letterLabelC, child: ArgDone((m) {})),
        KeyArg(key: OperationsScientific.letterLabelD, child: ArgDone((m) {})),
        KeyArg(key: OperationsScientific.letterLabelE, child: ArgDone((m) {})),
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

  ///
  /// The HP 15's (i) operation, to see the imaginary part.
  ///


  static final NormalOperationOrLetter reciprocal15 =
      NormalOperationOrLetter.floatOnly(
        letter: OperationsScientific.letterLabelE,
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

  static final _stoRclSynonyms = {
    Operations.enter: Operations11.ranNum,
  };

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

  static final NormalOperation ranNum = NormalOperation.floatOnly(
    pressed: (ActiveState s) => s.liftStackIfEnabled(),
    floatCalc: (Model m) {
      m.resultXF = (m as Model11).rand.nextValue;
    },
    name: 'RAN #',
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
          key: OperationsScientific.sigmaPlus,
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
    OperationsScientific.sqrtOp15,
    OperationsScientific.letterLabelA,
    OperationsScientific.xSquared,
    'A',
  );
  CalculatorButton get eX => CalculatorButton(
    factory,
    'e^x',
    'B',
    'LN',
    OperationsScientific.eX15,
    OperationsScientific.letterLabelB,
    OperationsScientific.lnOp,
    'B',
  );
  CalculatorButton get tenX => CalculatorButton(
    factory,
    '10^x',
    'C',
    'LOG',
    OperationsScientific.tenX15,
    OperationsScientific.letterLabelC,
    OperationsScientific.logOp,
    'C',
  );
  CalculatorButton get yX => CalculatorButton(
    factory,
    'y^x',
    'D',
    '%',
    OperationsScientific.yX15,
    OperationsScientific.letterLabelD,
    OperationsScientific.percent,
    'D',
  );
  CalculatorButton get reciprocal => CalculatorButton(
    factory,
    '1/x',
    'E',
    '\u0394%',
    Operations11.reciprocal15,
    OperationsScientific.letterLabelE,
    OperationsScientific.deltaPercent,
    'E',
  );
  CalculatorButton get chs => CalculatorButton(
    factory,
    'CHS',
    '\u03c0',
    'ABS',
    Operations.chs,
    OperationsScientific.piOp,
    Operations.abs,
    'H',
  );
  CalculatorButton get n7 => CalculatorButton(
    factory,
    '7',
    'FIX',
    'DEG',
    Operations.n7,
    OperationsScientific.fix,
    OperationsScientific.deg,
    '7',
  );
  CalculatorButton get n8 => CalculatorButton(
    factory,
    '8',
    'SCI',
    'RAD',
    Operations.n8,
    OperationsScientific.sci,
    OperationsScientific.rad,
    '8',
  );
  CalculatorButton get n9 => CalculatorButton(
    factory,
    '9',
    'ENG',
    'GRD',
    Operations.n9,
    OperationsScientific.eng,
    OperationsScientific.grd,
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
    OperationsScientific.gto,
    OperationsScientific.hyp,
    OperationsScientific.hypInverse,
    'L',
  );
  CalculatorButton get sin => CalculatorButtonHyperbolic(
    factory,
    'SIN',
    'x\u2b0c(i)',
    'SIN^\u2009\u22121',
    OperationsScientific.sin,
    Operations.xSwapParenI,
    OperationsScientific.sinInverse,
    OperationsScientific.sinh,
    OperationsScientific.sinhInverse,
    'S',
  );
  CalculatorButton get cos => CalculatorButtonHyperbolic(
    factory,
    'COS',
    '(i)',
    'COS^\u2009\u22121',
    OperationsScientific.cos,
    OperationsScientific.parenIOp,
    OperationsScientific.cosInverse,
    OperationsScientific.cosh,
    OperationsScientific.coshInverse,
    'O',
  );
  CalculatorButton get tan => CalculatorButtonHyperbolic(
    factory,
    'TAN',
    'I',
    'TAN^\u2009\u22121',
    OperationsScientific.tan,
    OperationsScientific.iOp,
    OperationsScientific.tanInverse,
    OperationsScientific.tanh,
    OperationsScientific.tanhInverse,
    'T',
  );

  CalculatorButton get eex => CalculatorButton(
    factory,
    'EEX',
    '\u279cR',
    '\u279cP',
    Operations.eex,
    OperationsScientific.toR,
    OperationsScientific.toP,
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
    OperationsScientific.gsb,
    OperationsScientific.clearSigma,
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
    OperationsScientific.rnd,
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
    OperationsScientific.lstx15,
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
    OperationsScientific.toHMS,
    OperationsScientific.toH,
    '2',
  );
  CalculatorButton get n3 => CalculatorButton(
    factory,
    '3',
    '\u279cRAD',
    '\u279cDEG',
    Operations.n3,
    OperationsScientific.toRad,
    OperationsScientific.toDeg,
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
    OperationsScientific.fracOp,
    OperationsScientific.intOp,
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
    OperationsScientific.xFactorial,
    OperationsScientific.xBar,
    '0',
  );
  CalculatorButton get dot => CalculatorDotButton(
    factory,
    '\u2219',
    'y\u0302,r',
    's',
    Operations.dot,
    OperationsScientific.yHatR,
    OperationsScientific.stdDeviation,
    '.,',
    '\u2219/\u201a',
    factory.settings,
  );
  CalculatorButton get sum => CalculatorButton(
    factory,
    '\u03a3+',
    'L.R.',
    '\u03a3\u2212',
    OperationsScientific.sigmaPlus,
    OperationsScientific.linearRegression,
    OperationsScientific.sigmaMinus,
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
    OperationsScientific.letterLabelA: _makeShortcut(
      OperationsScientific.gsb.arg,
      OperationsScientific.letterLabelA,
    )!,
    OperationsScientific.letterLabelB: _makeShortcut(
      OperationsScientific.gsb.arg,
      OperationsScientific.letterLabelB,
    )!,
    OperationsScientific.letterLabelC: _makeShortcut(
      OperationsScientific.gsb.arg,
      OperationsScientific.letterLabelC,
    )!,
    OperationsScientific.letterLabelD: _makeShortcut(
      OperationsScientific.gsb.arg,
      OperationsScientific.letterLabelD,
    )!,
    OperationsScientific.letterLabelE: _makeShortcut(
      OperationsScientific.gsb.arg,
      OperationsScientific.letterLabelE,
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
    OperationsScientific.hyp,
    OperationsScientific.hypInverse,
    Operations11.userOp,
    OperationsScientific.parenIOp,
  ];

  static final _userModeSwapped = <Operation, Operation>{
    OperationsScientific.letterLabelA: OperationsScientific.sqrtOp15,
    OperationsScientific.sqrtOp15: OperationsScientific.letterLabelA,
    OperationsScientific.letterLabelB: OperationsScientific.eX15,
    OperationsScientific.eX15: OperationsScientific.letterLabelB,
    OperationsScientific.letterLabelC: OperationsScientific.tenX15,
    OperationsScientific.tenX15: OperationsScientific.letterLabelC,
    OperationsScientific.letterLabelD: OperationsScientific.yX15,
    OperationsScientific.yX15: OperationsScientific.letterLabelD,
    OperationsScientific.letterLabelE: Operations11.reciprocal15,
    Operations11.reciprocal15: OperationsScientific.letterLabelE,
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
    } else if (lastKey == OperationsScientific.hyp) {
      buttonDown(b.hyperOp);
    } else if (lastKey == OperationsScientific.hypInverse) {
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
  NormalArgOperation get gsbOperation => OperationsScientific.gsb;

  @override
  NormalArgOperation get gtoOperation => OperationsScientific.gto;

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
      OperationsScientific.sqrtOp15,
      OperationsScientific.letterLabelA,
      OperationsScientific.xSquared,
    ),
    MKey(OperationsScientific.eX15, OperationsScientific.letterLabelB, OperationsScientific.lnOp),
    MKey(OperationsScientific.tenX15, OperationsScientific.letterLabelC, OperationsScientific.logOp),
    MKey(OperationsScientific.yX15, OperationsScientific.letterLabelD, OperationsScientific.percent),
    MKey(
      Operations11.reciprocal15,
      OperationsScientific.letterLabelE,
      OperationsScientific.deltaPercent,
    ),
    MKey(Operations.chs, OperationsScientific.piOp, Operations.abs),
    MKey(Operations.n7, OperationsScientific.fix, OperationsScientific.deg),
    MKey(Operations.n8, OperationsScientific.sci, OperationsScientific.rad),
    MKey(Operations.n9, OperationsScientific.eng, OperationsScientific.grd),
    MKey(Operations11.div, Operations.xLEy, Operations.xLT0),
  ],
  [
    MKey(Operations.sst, Operations11.lbl15, Operations.bst),
    MKey(OperationsScientific.gto, OperationsScientific.hyp, OperationsScientific.hypInverse),
    MKey(
      OperationsScientific.sin,
      Operations.xSwapParenI,
      OperationsScientific.sinInverse,
      extensionOps: [
        MKeyExtensionOp(OperationsScientific.sinh, Operations.fShift, OperationsScientific.hyp),
        MKeyExtensionOp(
          OperationsScientific.sinhInverse,
          Operations.gShift,
          OperationsScientific.hypInverse,
        ),
      ],
    ),
    MKey(
      OperationsScientific.cos,
      OperationsScientific.parenIOp,
      OperationsScientific.cosInverse,
      extensionOps: [
        MKeyExtensionOp(OperationsScientific.cosh, Operations.fShift, OperationsScientific.hyp),
        MKeyExtensionOp(
          OperationsScientific.coshInverse,
          Operations.gShift,
          OperationsScientific.hypInverse,
        ),
      ],
    ),
    MKey(
      OperationsScientific.tan,
      OperationsScientific.iOp,
      OperationsScientific.tanInverse,
      extensionOps: [
        MKeyExtensionOp(OperationsScientific.tanh, Operations.fShift, OperationsScientific.hyp),
        MKeyExtensionOp(
          OperationsScientific.tanhInverse,
          Operations.gShift,
          OperationsScientific.hypInverse,
        ),
      ],
    ),
    MKey(Operations.eex, OperationsScientific.toR, OperationsScientific.toP),
    MKey(Operations.n4, Operations11.xExchange, Operations11.sf),
    MKey(Operations.n5, Operations11.dse, Operations11.cf),
    MKey(Operations.n6, Operations11.isg, Operations11.fQuestion),
    MKey(Operations11.mult, Operations.xGTy, Operations.xGT0),
  ],
  [
    MKey(Operations.rs, Operations.pse, Operations.pr),
    MKey(OperationsScientific.gsb, OperationsScientific.clearSigma, Operations.rtn),
    MKey(Operations.rDown, Operations.clearPrgm, Operations.rUp),
    MKey(Operations.xy, Operations.clearReg, OperationsScientific.rnd),
    MKey(Operations.bsp, Operations.clearPrefix, Operations.clx),
    MKey(Operations.enter, Operations11.ranNum, OperationsScientific.lstx15),
    MKey(Operations.n1, Operations11.pYX, Operations11.cYX),
    MKey(Operations.n2, OperationsScientific.toHMS, OperationsScientific.toH),
    MKey(Operations.n3, OperationsScientific.toRad, OperationsScientific.toDeg),
    MKey(Operations11.minus, Operations.xNEy, Operations.xNE0),
  ],
  [
    MKey(Operations.onOff, Operations.onOff, Operations.onOff),
    MKey(Operations.fShift, Operations.fShift, Operations.fShift),
    MKey(Operations.gShift, Operations.gShift, Operations.gShift),
    MKey(Operations11.sto15, OperationsScientific.fracOp, OperationsScientific.intOp),
    MKey(Operations11.rcl15, Operations11.userOp, Operations.mem),
    null,
    MKey(Operations.n0, OperationsScientific.xFactorial, OperationsScientific.xBar),
    MKey(Operations.dot, OperationsScientific.yHatR, OperationsScientific.stdDeviation),
    MKey(
      OperationsScientific.sigmaPlus,
      OperationsScientific.linearRegression,
      OperationsScientific.sigmaMinus,
    ),
    MKey(Operations11.plus, Operations.xEQy, Operations.xEQ0),
  ],
];

ProgramInstruction<Operation> _newProgramInstruction(
  Operation operation,
  ArgDone arg,
) {
  if (OperationsScientific.letterLabels.contains(operation)) {
    arg = OperationsScientific.gsb.arg.matches(operation, false) as ArgDone;
    operation = OperationsScientific.gsb;
  }
  return ProgramInstruction11(operation, arg);
}

class ProgramInstruction11<OT extends ProgramOperation>
    extends ProgramInstruction<OT> {
  ProgramInstruction11(super.op, super.arg);
}

