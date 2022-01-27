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

import 'package:flutter/material.dart';
import 'package:jrpn/c/controller.dart';
import 'package:jrpn/c/operations.dart';
import 'package:jrpn/generic_main.dart';
import 'package:jrpn/m/model.dart';
import 'package:jrpn/v/buttons.dart';
import 'package:jrpn/v/main_screen.dart';

import 'back_panel15c.dart';
import 'tests15c.dart';

void main() async => genericMain(Jrpn(Controller15(Model15())));

/// TODO:  @@ Overflow is flashing display not G
class Model15 extends Model<Operation> {
  Model15() : super(DisplayMode.float(4), 56, 10);

  @override
  reset() {
    super.reset();
    displayMode = DisplayMode.float(4);
  }

  @override
  List<List<MKey<Operation>?>> get logicalKeys => _logicalKeys;

  //
  // See Model.logicalKeys.  This table determines the operation opcodes.
  // Changing the order here would render old JSON files of the
  // calculator's state obsolete.
  static final List<List<MKey<Operation>?>> _logicalKeys = [
    [
      MKey(Operations.sqrtOp15, Operations.letterLabelA, Operations.xSquared),
      MKey(Operations.eX15, Operations.letterLabelB, Operations.lnOp),
      MKey(Operations.tenX15, Operations.letterLabelC, Operations.logOp),
      MKey(Operations.yX15, Operations.letterLabelD, Operations.percent),
      MKey(Operations.reciprocal15, Operations.letterLabelE,
          Operations.deltaPercent),
      MKey(Operations.chs, Operations.matrix, Operations.abs),
      MKey(Operations.n7, Operations.fix, Operations.deg),
      MKey(Operations.n8, Operations.sci, Operations.rad),
      MKey(Operations.n9, Operations.eng, Operations.grd),
      MKey(Operations.div, Operations.solve, Operations.xLEy),
    ],
    [
      MKey(Operations.sst, Operations.lbl, Operations.bst),
      MKey(Operations.gto, Operations.hyp, Operations.hypInverse),
      MKey(Operations.sin, Operations.dim, Operations.sinInverse),
      MKey(Operations.cos, Operations.parenI15, Operations.cosInverse),
      MKey(Operations.tan, Operations.I15, Operations.tanInverse),
      MKey(Operations.eex, Operations.resultOp, Operations.piOp),
      MKey(Operations.n4, Operations.xExchange, Operations.sf),
      MKey(Operations.n5, Operations.dse, Operations.cf),
      MKey(Operations.n6, Operations.isg, Operations.fQuestion),
      MKey(Operations.mult, Operations.integrate, Operations.xEQ0),
    ],
    [
      MKey(Operations.rs, Operations.pse, Operations.pr),
      MKey(Operations.gsb, Operations.clearSigma, Operations.rtn),
      MKey(Operations.rDown, Operations.clearPrgm, Operations.rUp),
      MKey(Operations.xy, Operations.clearReg, Operations.rnd),
      MKey(Operations.bsp, Operations.clearPrefix, Operations.clx),
      MKey(Operations.enter, Operations.ranNum, Operations.lstx),
      MKey(Operations.n1, Operations.toR, Operations.toP),
      MKey(Operations.n2, Operations.toHMS, Operations.toH),
      MKey(Operations.n3, Operations.toRad, Operations.toDeg),
      MKey(Operations.minus, Operations.reImSwap, Operations.testOp),
    ],
    [
      MKey(Operations.onOff, Operations.onOff, Operations.onOff),
      MKey(Operations.fShift, Operations.fShift, Operations.fShift),
      MKey(Operations.gShift, Operations.gShift, Operations.gShift),
      MKey(Operations.sto, Operations.fracOp, Operations.intOp),
      MKey(Operations.rcl, Operations.userOp, Operations.mem),
      null,
      MKey(Operations.n0, Operations.xFactorial, Operations.xBar),
      MKey(Operations.dot, Operations.yHatR, Operations.sOp),
      MKey(Operations.sigmaPlus, Operations.linearRegression,
          Operations.sigmaMinus),
      MKey(Operations.plus, Operations.pYX, Operations.cYX),
    ]
  ];

  static final Set<LetterLabel> _letterLabels = {
    Operations.letterLabelA,
    Operations.letterLabelB,
    Operations.letterLabelC,
    Operations.letterLabelD,
    Operations.letterLabelE
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
      extraShift: ShiftKey.f);
}

class ProgramInstruction15 extends ProgramInstruction<Operation> {
  ProgramInstruction15(Operation op, int argValue) : super(op, argValue);

  @override
  String get programDisplay {
    if (op.maxArg > 0) {
      final String as;
      if (argValue < 16) {
        if (argValue < 10) {
          as = ' ${argValue.toRadixString(10)}';
        } else {
          as = '1${argValue - 9}'; // A-F are keys R/C 11..16
        }
      } else {
        as = ' .${(argValue - 16).toRadixString(10)}';
      }
      return rightJustify('${op.programDisplay}$as', 6);
    } else {
      return rightJustify(op.programDisplay, 6);
    }
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
      Operations.sqrtOp15,
      Operations.letterLabelA,
      Operations.xSquared,
      'A');
  CalculatorButton get eX => CalculatorButton(factory, 'e^x', 'B', 'LN',
      Operations.eX15, Operations.letterLabelB, Operations.lnOp, 'B');
  CalculatorButton get tenX => CalculatorButton(factory, '10^x', 'C', 'LOG',
      Operations.tenX15, Operations.letterLabelC, Operations.logOp, 'C');
  CalculatorButton get yX => CalculatorButton(factory, 'y^x', 'D', '%',
      Operations.yX15, Operations.letterLabelD, Operations.percent, 'D');
  CalculatorButton get reciprocal => CalculatorButton(
      factory,
      '1/x',
      'E',
      '\u0394%',
      Operations.reciprocal15,
      Operations.letterLabelE,
      Operations.deltaPercent,
      'E');
  CalculatorButton get chs => CalculatorButton(factory, 'CHS', 'MATRIX', 'ABS',
      Operations.chs, Operations.matrix, Operations.abs, 'F');
  CalculatorButton get n7 => CalculatorButton(factory, '7', 'FIX', 'DEG',
      Operations.n7, Operations.fix, Operations.deg, '7');
  CalculatorButton get n8 => CalculatorButton(factory, '8', 'SCI', 'RAD',
      Operations.n8, Operations.sci, Operations.rad, '8');
  CalculatorButton get n9 => CalculatorButton(factory, '9', 'ENG', 'GRD',
      Operations.n9, Operations.eng, Operations.grd, '9');
  CalculatorButton get div => CalculatorButton(factory, '\u00F7', 'SOLVE',
      'x\u2264y', Operations.div, Operations.solve, Operations.xLEy, '/');

  CalculatorButton get sst => CalculatorButton(factory, 'SST', 'LBL', 'BST',
      Operations.sst, Operations.lbl, Operations.bst, 'U');
  CalculatorButton get gto => CalculatorButton(
      factory,
      'GTO',
      'HYP',
      'HYP^\u2009\u22121',
      Operations.gto,
      Operations.hyp,
      Operations.hypInverse,
      'T');
  CalculatorButton get sin => CalculatorButton(
      factory,
      'SIN',
      'DIM',
      'SIN^\u2009\u22121',
      Operations.sin,
      Operations.dim,
      Operations.sinInverse,
      'I');
  CalculatorButton get cos => CalculatorButton(
      factory,
      'COS',
      '(i)',
      'COS^\u2009\u22121',
      Operations.cos,
      Operations.parenI15,
      Operations.cosInverse,
      'Z');
  CalculatorButton get tan => CalculatorButton(
      factory,
      'TAN',
      'I',
      'TAN^\u2009\u22121',
      Operations.tan,
      Operations.I15,
      Operations.tanInverse,
      'K');
  CalculatorButton get eex => CalculatorButton(factory, 'EEX', 'RESULT',
      '\u03c0', Operations.eex, Operations.resultOp, Operations.piOp, 'L');
  CalculatorButton get n4 => CalculatorButton(factory, '4', 'x\u2b0c', 'SF',
      Operations.n4, Operations.xExchange, Operations.sf, '4');
  CalculatorButton get n5 => CalculatorButton(factory, '5', 'DSE', 'CF',
      Operations.n5, Operations.dse, Operations.cf, '5');
  CalculatorButton get n6 => CalculatorButton(factory, '6', 'ISG', 'F?',
      Operations.n6, Operations.isg, Operations.fQuestion, '6');
  CalculatorButton get mult => CalculatorOnSpecialButton(
      factory,
      '\u00D7',
      '\u222b^\u200ax^y',
      'x=0',
      Operations.mult,
      Operations.integrate,
      Operations.xEQ0,
      'X*',
      'TST',
      acceleratorLabel: '*\u00d7');

  CalculatorButton get rs => CalculatorButton(factory, 'R/S', 'PSE', 'P/R',
      Operations.rs, Operations.pse, Operations.pr, '[');
  CalculatorButton get gsb => CalculatorButton(factory, 'GSB', '\u03a3', 'RTN',
      Operations.gsb, Operations.clearSigma, Operations.rtn, ']');
  CalculatorButton get rdown => CalculatorButton(factory, 'R\u2193', 'PRGM',
      'R\u2191', Operations.rDown, Operations.clearPrgm, Operations.rUp, 'V');
  CalculatorButton get xy => CalculatorButton(factory, 'x\u2b0cy', 'REG', 'RND',
      Operations.xy, Operations.clearReg, Operations.rnd, 'Y');
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
      Operations.ranNum,
      Operations.lstx,
      '\n\r',
      extraHeight: factory.height * _totalButtonHeight / _buttonHeight,
      acceleratorLabel: ' \u23ce');
  CalculatorButton get n1 => CalculatorButton(factory, '1', '\u279cR',
      '\u279cP', Operations.n1, Operations.toR, Operations.toP, '1');
  CalculatorButton get n2 => CalculatorButton(factory, '2', '\u279cH.MS',
      '\u279cH', Operations.n2, Operations.toHMS, Operations.toH, '2');
  CalculatorButton get n3 => CalculatorButton(factory, '3', '\u279cRAD',
      '\u279cDEG', Operations.n3, Operations.toRad, Operations.toDeg, '3');
  CalculatorButton get minus => CalculatorOnSpecialButton(
      factory,
      '\u2212',
      'Re\u2b0cIm',
      'TEST',
      Operations.minus,
      Operations.reImSwap,
      Operations.testOp,
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
      Operations.sto, Operations.fracOp, Operations.intOp, 'S<');
  CalculatorButton get rcl => CalculatorButton(factory, 'RCL', 'USER', 'MEM',
      Operations.rcl, Operations.userOp, Operations.mem, 'R>');
  CalculatorButton get n0 => CalculatorButton(factory, '0', 'x!', 'x\u0305',
      Operations.n0, Operations.xFactorial, Operations.xBar, '0');
  CalculatorButton get dot => CalculatorOnSpecialButton(
      factory,
      '\u2219',
      'y\u0302,r',
      'x\u22600',
      Operations.dot,
      Operations.yHatR,
      Operations.sOp,
      '.',
      '\u2219/\u201a',
      acceleratorLabel: '\u2219');
  CalculatorButton get sum => CalculatorButton(
      factory,
      '\u03a3+',
      'L.R.',
      '\u03a3-',
      Operations.sigmaPlus,
      Operations.linearRegression,
      Operations.sigmaMinus,
      'H');
  CalculatorButton get plus => CalculatorButton(factory, '+', 'P\u200ay,x',
      'C\u2009y,x', Operations.plus, Operations.pYX, Operations.cYX, '+=');

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
  Controller15(Model<Operation> model) : super(model, _numbers, const {});

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
}