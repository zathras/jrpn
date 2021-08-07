/*
MIT License

Copyright (c) 2021 William Foote

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/
/// Buttons for the keyboard.  When pressed, buttons consult the [Model] to see
/// if a shift key has been pressed, and dispatch an appropriate
/// [Operation] to the [Controller].
///
/// The overall structure is this:
/// <img src="dartdoc/view.buttons/buttons.svg" style="width: 100%;"/>
/// <br>
/// See [CalculatorButton] for more details.
library view.buttons;

import 'package:flutter/material.dart';

import '../c/controller.dart';
import '../c/operations.dart';
import '../m/model.dart';
import 'main_screen.dart' show ScreenPositioner;

// See the library comments, above!  (Android Studio  hides them by default.)

///
/// A helper to create the buttons and their associated layout.
///
abstract class ButtonFactory {
  final BuildContext context;
  final ScreenPositioner screen;
  final Controller controller;

  // All sizes are based on a hypothetical 122x136 button.  This is
  // scaled to screen pixels in the painter.
  final double width = 122;
  final double height = 136;
  final double padRight = 25;
  final TextStyle keyTextStyle = TextStyle(
      fontSize: 40,
      fontFamily: 'KeyLabelFont',
      fontWeight: FontWeight.normal,
      color: Color(0xffffffff),
      height: 0.97);
  final TextStyle shiftKeyTextStyle = TextStyle(
      fontSize: 38, fontFamily: 'KeyLabelFont', color: Color(0xff000000));
  final Offset keyTextOffset = Offset(0, 46);
  final Offset fKeyTextOffset = Offset(0, 45);
  final Offset gKeyTextOffset = Offset(0, 39);
  final Offset onKeyTextOffset = Offset(0, 66);
  final Offset enterKeyTextOffset = Offset(0, 53);
  final TextStyle fTextStyle = TextStyle(
      fontSize: 26,
      fontFamily: 'KeyLabelFont',
      fontWeight: FontWeight.bold,
      color: Color(0xfff98c35));
  final TextStyle fTextSmallLabelStyle = TextStyle(
      fontSize: 17,
      fontFamily: 'KeyLabelFont',
      fontWeight: FontWeight.bold,
      color: Color(0xfff98c35));
  final Offset fTextOffset = Offset(0, -2);
  final TextStyle gTextStyle = TextStyle(
      fontSize: 26, fontFamily: 'KeyLabelFont', color: Color(0xff12cdff));
  final TextStyle gTextStyleForLJ = TextStyle(
      fontFamily: 'LogoFont',
      fontWeight: FontWeight.w500,
      fontSize: 26,
      color: Color(0xff12cdff));
  final Offset gTextOffset = Offset(0, 92);
  final TextStyle specialButtonTextStyle = TextStyle(
      fontSize: 42,
      fontFamily: 'KeyLabelFont',
      color: Colors.yellow,
      height: 0.97);
  final TextStyle acceleratorTextStyle = TextStyle(
      fontSize: 32, fontFamily: 'KeyLabelFont', color: Color(0xff5fe88d));
  final RRect outerBorder =
      RRect.fromLTRBR(0, 26, 122, 136, Radius.circular(7));
  final RRect innerBorder =
      RRect.fromLTRBR(7, 26 + 7, 122 - 7, 136 - 7, Radius.circular(7));
  final RRect upperSurface = RRect.fromLTRBAndCorners(11, 26 + 11, 122 - 11, 88,
      topLeft: Radius.circular(7), topRight: Radius.circular(7));
  final RRect lowerSurface = RRect.fromLTRBAndCorners(
      11, 88, 122 - 11, 136 - 11,
      bottomLeft: Radius.circular(7), bottomRight: Radius.circular(7));
  final Paint fill = Paint()..style = PaintingStyle.fill;

  @protected
  ButtonFactory(this.context, this.screen, this.controller);

  int get numRows;
  int get numColumns;
  double totalButtonHeight(double height, double buttonHeight);

  double addUpperGoldLabels(List<Widget> result, Rect pos,
      {required double th,
      required double tw,
      required double bh,
      required double bw});

  Rect enterPos(Rect pos,
      {required double th,
      required double tw,
      required double bh,
      required double bw});

  List<Widget> buildButtons(Rect pos) {
    double y = pos.top;
    final result = List<Widget>.empty(growable: true);
    final double bw = pos.width *
        (width / (numColumns * width + (numColumns - 1) * padRight));
    final double tw = bw * (width + padRight) / width;
    final double bh = bw * height / width;
    // Total height for each button, including any label
    final double th = totalButtonHeight(pos.height, bh);

    // Add the upper yellow labels
    y += addUpperGoldLabels(result, pos, th: th, tw: tw, bh: bh, bw: bw);

    final buttons = _Buttons(this, th, bh);
    final List<List<CalculatorButton?>> rc = buttonLayout(buttons);
    for (int i = 0; i < rc.length; i++) {
      double x = pos.left;
      for (int j = 0; j < rc[i].length; j++) {
        final b = rc[i][j];
        if (b != null) {
          result.add(screen.box(Rect.fromLTWH(x, y, bw, bh), b));
        }
        x += tw;
      }
      y += th;
    }
    result.add(screen.box(
        enterPos(pos, th: th, tw: tw, bh: bh, bw: bw), buttons.enter));

    return result;
  }

  List<List<CalculatorButton?>> buttonLayout(_Buttons buttons);
}

class LandscapeButtonFactory extends ButtonFactory {
  LandscapeButtonFactory(
      BuildContext context, ScreenPositioner screen, Controller controller)
      : super(context, screen, controller);

  @override
  int get numRows => 4;

  @override
  int get numColumns => 10;

  @override
  double totalButtonHeight(double height, double buttonHeight) =>
      (height - numRows * buttonHeight) / (numRows - 1) * buttonHeight +
      buttonHeight;

  @override
  double addUpperGoldLabels(List<Widget> result, Rect pos,
      {required double th,
      required double tw,
      required double bh,
      required double bw}) {
    double y = pos.top;
    result.add(screen.box(
        Rect.fromLTRB(pos.left + 2 * tw - 0.05, y + th - 0.14,
            pos.left + 5 * tw + bw + 0.05, y + th + 0.11),
        CustomPaint(
            painter:
                _UpperLabel('SHOW', fTextStyle, height * (0.14 + 0.11) / bh))));
    result.add(screen.box(
        Rect.fromLTRB(pos.left + 2 * tw - 0.05, y + 2 * th - 0.155,
            pos.left + 4 * tw + bw + 0.05, y + 2 * th + 0.065),
        CustomPaint(
            painter: _UpperLabel('CLEAR', fTextSmallLabelStyle,
                height * (0.065 + 0.155) / bh))));
    result.add(screen.box(
        Rect.fromLTRB(pos.left + 6 * tw - 0.05, y + 2 * th - 0.155,
            pos.left + 8 * tw + bw + 0.05, y + 2 * th + 0.065),
        CustomPaint(
            painter: _UpperLabel('SET COMPL', fTextSmallLabelStyle,
                height * (0.065 + 0.155) / bh))));
    return 0;
  }

  @override
  Rect enterPos(Rect pos,
          {required double th,
          required double tw,
          required double bh,
          required double bw}) =>
      Rect.fromLTWH(pos.left + 5 * tw, pos.top + 2 * th, bw, bh + th);

  @override
  List<List<CalculatorButton?>> buttonLayout(_Buttons buttons) =>
      buttons.landscapeLayout;
}

class PortraitButtonFactory extends ButtonFactory {
  PortraitButtonFactory(
      BuildContext context, ScreenPositioner screen, Controller controller)
      : super(context, screen, controller);

  @override
  int get numRows => 7;

  @override
  int get numColumns => 6;

  @override
  double totalButtonHeight(double height, double buttonHeight) =>
      (height - numRows * buttonHeight) / numRows * buttonHeight + buttonHeight;

  @override
  double addUpperGoldLabels(List<Widget> result, Rect pos,
      {required double th,
      required double tw,
      required double bh,
      required double bw}) {
    double y = pos.top;
    result.add(screen.box(
        Rect.fromLTWH(pos.left + tw - 0.05, y + 0.07, 2 * tw + bw + 0.10, 0.22),
        CustomPaint(
            painter: _UpperLabel('CLEAR', fTextSmallLabelStyle,
                height * (0.065 + 0.155) / bh))));
    result.add(screen.box(
        Rect.fromLTWH(
            pos.left + 2 * tw - 0.05, y + th + 0.18, 3 * tw + bw + 0.10, 0.25),
        CustomPaint(
            painter:
                _UpperLabel('SHOW', fTextStyle, height * (0.14 + 0.11) / bh))));
    result.add(screen.box(
        Rect.fromLTWH(pos.left + 2 * tw - 0.05, y + 5 * th + 0.08,
            2 * tw + bw + 0.1, 0.22),
        CustomPaint(
            painter: _UpperLabel('SET COMPL', fTextSmallLabelStyle,
                height * (0.065 + 0.155) / bh))));
    return 0.28;
  }

  @override
  Rect enterPos(Rect pos,
          {required double th,
          required double tw,
          required double bh,
          required double bw}) =>
      Rect.fromLTWH(pos.left + tw - 0.1, 0.28 + pos.top + 5 * th, bw, bh + th);

  @override
  List<List<CalculatorButton?>> buttonLayout(_Buttons buttons) =>
      buttons.portraitLayout;
}

///
/// This helper just gives names for each of the buttons.
/// Within this class, the fields are ordered as per the landscape layout,
/// but they can be placed elsewhere on the screen.
///
class _Buttons {
  final ButtonFactory factory;
  double th;
  double bh;

  _Buttons(this.factory, this.th, this.bh);

  CalculatorButton get a => CalculatorButtonWithLJ(factory, 'A', 'SL',
      'L\u200AJ', Operations.a, Operations.sl, Operations.lj, 'A');
  CalculatorButton get b => CalculatorButton(factory, 'B', 'SR', 'ASR',
      Operations.b, Operations.sr, Operations.asr, 'B');
  CalculatorButton get c => CalculatorButton(factory, 'C', 'RL', 'RLC',
      Operations.c, Operations.rl, Operations.rlc, 'C');
  CalculatorButton get d => CalculatorButton(factory, 'D', 'RR', 'RRC',
      Operations.d, Operations.rr, Operations.rrc, 'D');
  CalculatorButton get e => CalculatorButton(factory, 'E', 'RLn', 'RLCn',
      Operations.e, Operations.rln, Operations.rlcn, 'E');
  CalculatorButton get f => CalculatorButton(factory, 'F', 'RRn', 'RRCn',
      Operations.f, Operations.rrn, Operations.rrcn, 'F');
  CalculatorButton get n7 => CalculatorButton(factory, '7', 'MASKL', '#B',
      Operations.n7, Operations.maskl, Operations.poundB, '7');
  CalculatorButton get n8 => CalculatorButton(factory, '8', 'MASKR', 'ABS',
      Operations.n8, Operations.maskr, Operations.abs, '8');
  CalculatorButton get n9 => CalculatorButton(factory, '9', 'RMD', 'DBLR',
      Operations.n9, Operations.rmd, Operations.dblr, '9');
  CalculatorButton get div => CalculatorButton(factory, '\u00F7', 'XOR',
      'DBL\u00F7', Operations.div, Operations.xor, Operations.dblDiv, '/');

  CalculatorButton get gsb => CalculatorButton(factory, 'GSB', 'x\u2B0C(i)',
      'RTN', Operations.gsb, Operations.xSwapParenI, Operations.rtn, 'U');
  CalculatorButton get gto => CalculatorButton(factory, 'GTO', 'x\u2B0CI',
      'LBL', Operations.gto, Operations.xSwapI, Operations.lbl, 'T');
  CalculatorButton get hex => CalculatorButton(factory, 'HEX', '', 'DSZ',
      Operations.hex, Operations.showHex, Operations.dsz, 'I');
  CalculatorButton get dec => CalculatorButton(factory, 'DEC', '', 'ISZ',
      Operations.dec, Operations.showDec, Operations.isz, 'Z');
  CalculatorButton get oct => CalculatorSqrtButton(factory, 'OCT', '',
      '\u221Ax', Operations.oct, Operations.showOct, Operations.sqrtOp, 'K');
  CalculatorButton get bin => CalculatorButton(factory, 'BIN', '', '1/x',
      Operations.bin, Operations.showBin, Operations.reciprocal, 'L');
  CalculatorButton get n4 => CalculatorButton(factory, '4', 'SB', 'SF',
      Operations.n4, Operations.sb, Operations.sf, '4');
  CalculatorButton get n5 => CalculatorButton(factory, '5', 'CB', 'CF',
      Operations.n5, Operations.cb, Operations.cf, '5');
  CalculatorButton get n6 => CalculatorButton(factory, '6', 'B?', 'F?',
      Operations.n6, Operations.bQuestion, Operations.fQuestion, '6');
  CalculatorButton get mult => CalculatorOnSpecialButton(
      factory,
      '\u00D7',
      'AND',
      'DBLx',
      Operations.mult,
      Operations.and,
      Operations.dblx,
      'X*',
      'TST',
      acceleratorLabel: '*\u00d7');
  CalculatorButton get rs => CalculatorButton(factory, 'R/S', '(i)', 'P/R',
      Operations.rs, Operations.parenI, Operations.pr, '[');
  CalculatorButton get sst => CalculatorButton(factory, 'SST', 'I', 'BST',
      Operations.sst, Operations.I, Operations.bst, ']');
  CalculatorButton get rdown => CalculatorButton(factory, 'R\u2193', 'PRGM',
      'R\u2191', Operations.rDown, Operations.clearPrgm, Operations.rUp, 'V');
  CalculatorButton get xy => CalculatorButton(factory, 'x\u2B0Cy', 'REG', 'PSE',
      Operations.xy, Operations.clearReg, Operations.pse, 'Y');
  CalculatorButton get bsp => CalculatorButton(
      factory,
      'BSP',
      'PREFIX',
      'CLx',
      Operations.bsp,
      Operations.clearPrefix,
      Operations.clx,
      '\u0008\u007f\uf728',
      acceleratorLabel: '\u2190');
  CalculatorButton get enter => CalculatorEnterButton(
      factory,
      'E\nN\nT\nE\nR',
      'WINDOW',
      'LSTx',
      Operations.enter,
      Operations.window,
      Operations.lstx,
      '\n\r',
      extraHeight: factory.height * th / bh,
      acceleratorLabel: ' \u23ce');
  CalculatorButton get n1 => CalculatorButton(factory, '1', '1\'s', 'x\u2264y',
      Operations.n1, Operations.onesCompl, Operations.xLEy, '1');
  CalculatorButton get n2 => CalculatorButton(factory, '2', '2\'s', 'x<0',
      Operations.n2, Operations.twosCompl, Operations.xLT0, '2');
  CalculatorButton get n3 => CalculatorButton(factory, '3', 'UNSGN', 'x>y',
      Operations.n3, Operations.unsign, Operations.xGTy, '3');
  CalculatorButton get minus => CalculatorOnSpecialButton(
      factory,
      '\u2212',
      'NOT',
      'x>0',
      Operations.minus,
      Operations.not,
      Operations.xGT0,
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
  CalculatorButton get sto => CalculatorButton(factory, 'STO', 'WSIZE', '<',
      Operations.sto, Operations.wSize, Operations.windowRight, 'S<');
  CalculatorButton get rcl => CalculatorButton(factory, 'RCL', 'FLOAT', '>',
      Operations.rcl, Operations.floatKey, Operations.windowLeft, 'R>');
  CalculatorButton get n0 => CalculatorButton(factory, '0', 'MEM', 'x\u2260y',
      Operations.n0, Operations.mem, Operations.xNEy, '0');
  CalculatorButton get dot => CalculatorOnSpecialButton(
      factory,
      '\u2219',
      'STATUS',
      'x\u22600',
      Operations.dot,
      Operations.status,
      Operations.xNE0,
      '.',
      '\u2219/\u201a',
      acceleratorLabel: '\u2219');
  CalculatorButton get chs => CalculatorButton(factory, 'CHS', 'EEX', 'x=y',
      Operations.chs, Operations.eex, Operations.xEQy, 'H');
  CalculatorButton get plus => CalculatorButton(factory, '+', 'OR', 'x=0',
      Operations.plus, Operations.or, Operations.xEQ0, '+=');

  List<List<CalculatorButton?>> get landscapeLayout => [
        [a, b, c, d, e, f, n7, n8, n9, div],
        [gsb, gto, hex, dec, oct, bin, n4, n5, n6, mult],
        [rs, sst, rdown, xy, bsp, null, n1, n2, n3, minus],
        [onOff, fShift, gShift, sto, rcl, null, n0, dot, chs, plus]
      ];

  List<List<CalculatorButton?>> get portraitLayout => [
        [onOff, rdown, xy, bsp, fShift, gShift],
        [gsb, gto, hex, dec, oct, bin],
        [a, b, c, d, e, f],
        [rs, sst, n7, n8, n9, div],
        [sto, rcl, n4, n5, n6, mult],
        [null, null, n1, n2, n3, minus],
        [null, null, n0, dot, chs, plus],
      ];
}

/// The gold label above some groups of keys
class _UpperLabel extends CustomPainter {
  final String text;
  final TextStyle style;
  final double height;

  _UpperLabel(this.text, this.style, this.height);

  final Paint linePaint = Paint()
    ..color = Color(0xfff98c35)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3
    ..strokeCap = StrokeCap.butt;

  @override
  void paint(Canvas canvas, Size size) {
    final double sf = size.height / height;
    canvas.scale(sf);
    TextSpan span = TextSpan(style: style, text: text);
    TextPainter tp = TextPainter(
        text: span,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr);
    final double x = 2;
    final double w = (size.width / sf) - 2 * x;
    tp.layout();
    tp.paint(canvas, Offset(x + (w - tp.width) / 2, 0));
    final double y = -1 + tp.height / 2;
    final double h = (size.height / sf) - 2 * x; // Yes, x

    Path p = Path()
      ..addPolygon(
          [Offset(x, h), Offset(x, y), Offset(x + (w - tp.width) / 2 - 18, y)],
          false);
    canvas.drawPath(p, linePaint);
    p = Path()
      ..addPolygon([
        Offset(x + (w + tp.width) / 2 + 18, y),
        Offset(x + w, y),
        Offset(x + w, h)
      ], false);
    canvas.drawPath(p, linePaint);
    // Add in the lines...
  }

  @override
  bool shouldRepaint(covariant _UpperLabel oldDelegate) {
    return false; // We never change
  }
}

///
/// A button on the calculator keyboard.  `CalculatorButton` uses a
/// Flutter `CustomPaint` with a painter that delegates back to the
/// `CalculatorButton`'s [paintForPainter] method.  This is a template
/// method that uses the various `drawXXX()` methods and the getters defined
/// here to draw a button.  The defaults provided here work for most buttons,
/// but are specialized for buttons that have a distinct visual appearance.
///
/// <img src="dartdoc/view.buttons/buttons.svg" style="width: 100%;"/>
/// <br>
///
/// A `CalculatorButton` is associated with three [Operation]s, one when
/// unshifted, and one each for the f ang g shift states.  On a button press,
/// the button consults the model to find the current shift status, and
/// dispatches the correct [Operation] to the [Controller].  This could be
/// done with a `switch` statement, but since this application uses the
/// GoF state pattern so heavily, I did that -- see [ShiftKey.select].
///
class CalculatorButton extends StatefulWidget with ShiftKeySelected<Operation> {
  final ButtonFactory bFactory;
  final String uText; // unshifted
  final String fText;
  final String gText;
  @override
  final Operation uKey;
  @override
  final Operation fKey;
  @override
  final Operation gKey;

  /// Key (or keys) to generate a press of this button
  final String acceleratorKey;
  final String? _acceleratorLabel;

  CalculatorButton(this.bFactory, this.uText, this.fText, this.gText, this.uKey,
      this.fKey, this.gKey, this.acceleratorKey,
      {String? acceleratorLabel})
      : _acceleratorLabel = acceleratorLabel;

  @override
  CalculatorButtonState createState() => CalculatorButtonState();

  String get acceleratorLabel => _acceleratorLabel ?? acceleratorKey;
  double get width => bFactory.width;
  double get height => bFactory.height;

  RRect get outerBorder => bFactory.outerBorder;
  Color get innerBorderColor => const Color(0xff646467);
  RRect get innerBorder => bFactory.innerBorder;
  RRect get lowerSurface => bFactory.lowerSurface;
  Color get lowerSurfaceColor => const Color(0xff373437);
  Color get lowerSurfaceColorPressed => const Color(0xff403e40);
  RRect get upperSurface => bFactory.upperSurface;
  Color get upperSurfaceColor => const Color(0xff4b4b4e);
  Color get upperSurfaceColorPressed => const Color(0xff4e4e4f);
  TextStyle get keyTextStyle => bFactory.keyTextStyle;
  Offset get keyTextOffset => bFactory.keyTextOffset;
  Offset get gTextOffset => bFactory.gTextOffset;
  double get outerBorderPressedScale => 1.06;

  void paintForPainter(final Canvas canvas, final Size size,
      {required final bool pressed,
      required final bool pressedFromKeyboard,
      required final bool showAccelerators}) {
    final double h = height;
    final double w = width;
    assert((size.height / h - size.width / w) / w < 0.0000001);
    canvas.scale(size.height / h);

    // Draw  gold text
    TextSpan span = TextSpan(style: bFactory.fTextStyle, text: fText);
    TextPainter tp = TextPainter(
        text: span,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr);
    tp.layout(minWidth: w);
    tp.paint(canvas, bFactory.fTextOffset);

    final Paint p = bFactory.fill;

    // Draw borders
    // That's 1 for all but the enter key
    p.color = Colors.black;
    canvas.drawRRect(outerBorder, p);
    if (pressed) {
      canvas.save();
      canvas.translate(0, innerBorder.bottom);
      canvas.scale(1.0, outerBorderPressedScale);
      canvas.translate(0, -innerBorder.bottom);
    }
    p.color = innerBorderColor;
    canvas.drawRRect(innerBorder, p);

    // draw lower surface
    if (pressed) {
      canvas.translate(0, innerBorder.bottom);
      canvas.scale(1.0, 1.11 / outerBorderPressedScale);
      canvas.translate(0, -innerBorder.bottom);
      p.color = lowerSurfaceColorPressed;
    } else {
      p.color = lowerSurfaceColor;
    }
    canvas.drawRRect(lowerSurface, p);

    // draw blue text
    drawBlueText(canvas, w);
    span = TextSpan(style: bFactory.gTextStyle, text: gText);

    // draw upper surface
    if (pressed) {
      canvas.translate(0, upperSurface.bottom);
      canvas.scale(1.0, 1.0 / 1.11);
      canvas.translate(0, -upperSurface.bottom);
      p.color = upperSurfaceColorPressed;
    } else {
      p.color = upperSurfaceColor;
    }
    canvas.drawRRect(upperSurface, p);
    drawWhiteText(canvas, keyTextStyle, uText, w);

    if (pressed) {
      if (pressedFromKeyboard) {
        Paint p = Paint()
          ..color = Color(0xff00ef00)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
        canvas.drawRRect(outerBorder, p);
      }
      canvas.restore();
    }
    if (showAccelerators) {
      drawKeyboardAccelerator(canvas);
    }
  }

  void drawKeyboardAccelerator(Canvas canvas) {
    final s = bFactory.acceleratorTextStyle;
    final double x = -25;
    double y = 7 + s.fontSize!;
    for (String ch in Characters(acceleratorLabel)) {
      TextPainter p = TextPainter(
          text: TextSpan(style: s, text: ch),
          textAlign: TextAlign.right,
          textDirection: TextDirection.ltr);
      p.layout(minWidth: 25);
      p.paint(canvas, Offset(x, y));
      y += s.fontSize!;
    }
  }

  void drawWhiteText(Canvas canvas, TextStyle style, String text, double w) {
    // draw white text
    TextSpan span = TextSpan(style: style, text: text);
    TextPainter tp = TextPainter(
        text: span,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr);
    tp.layout(minWidth: w);
    tp.paint(canvas, keyTextOffset);
  }

  void drawBlueText(Canvas canvas, double w) {
    // Separated out for the special handling of sqrt(x)
    TextSpan span = TextSpan(style: bFactory.gTextStyle, text: gText);
    TextPainter tp = TextPainter(
        text: span,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr);
    tp.layout(minWidth: w);
    tp.paint(canvas, gTextOffset);
  }
}

/// A [CalculatorButton] that has a special function when used with conjunction
/// with the on'off button.  Such buttons show text describing their special
/// function when the on/off button has been pressed.
class CalculatorOnSpecialButton extends CalculatorButton {
  final String specialText; // For the special function when on is pressed

  CalculatorOnSpecialButton(
      ButtonFactory factory,
      String uText,
      String fText,
      String gText,
      Operation uKey,
      Operation fKey,
      Operation gKey,
      String rawKeyboardKey,
      this.specialText,
      {String? acceleratorLabel})
      : super(factory, uText, fText, gText, uKey, fKey, gKey, rawKeyboardKey,
            acceleratorLabel: acceleratorLabel);

  @override
  CalculatorButtonState createState() => _CalculatorOnSpecialButtonState();

  @override
  Color get lowerSurfaceColor => (bFactory.controller.model.onIsPressed.value)
      ? const Color(0xff1f0000)
      : super.lowerSurfaceColor;
  @override
  Color get upperSurfaceColor => (bFactory.controller.model.onIsPressed.value)
      ? const Color(0xff3f0000)
      : super.upperSurfaceColor;

  @override
  void drawWhiteText(Canvas canvas, TextStyle style, String text, double w) {
    if (bFactory.controller.model.onIsPressed.value) {
      drawCustomWhiteText(canvas, specialText, w);
    } else {
      super.drawWhiteText(canvas, style, text, w);
    }
  }

  void drawCustomWhiteText(Canvas canvas, String text, double w) =>
      super.drawWhiteText(canvas, bFactory.specialButtonTextStyle, text, w);
}

/// The on/off button, which is flat on the 16C.
/// This button also has a special function when the on button is pressed,
/// because pressing it a second time turns the calculator off, so
/// it's also a [CalculatorOnSpecialButton].
class CalculatorOnButton extends CalculatorOnSpecialButton {
  CalculatorOnButton(
      ButtonFactory factory,
      String uText,
      String fText,
      String gText,
      Operation uKey,
      Operation fKey,
      Operation gKey,
      String rawKeyboardKey,
      String specialText)
      : super(factory, uText, fText, gText, uKey, fKey, gKey, rawKeyboardKey,
            specialText);

  @override
  Color get lowerSurfaceColor => upperSurfaceColor;
  @override
  Color get lowerSurfaceColorPressed => upperSurfaceColorPressed;
  @override
  Offset get keyTextOffset => bFactory.onKeyTextOffset;

  @override
  void drawWhiteText(Canvas canvas, TextStyle style, String text, double w) {
    if (bFactory.controller.model.onIsPressed.value) {
      canvas.save();
      // The translate values are super hacky - I really should be calculating
      // font metrics on the strings.  But I'm also using a bundled font, so
      // just using values obtained from trial and error like this is pretty
      // safe.
      canvas.translate(0, -14);
      super.drawWhiteText(canvas, style, text, w);
      canvas.translate(14, 81);
      canvas.scale(0.5);
      super.drawCustomWhiteText(canvas, '+ SAVE', w);
      canvas.restore();
    } else {
      super.drawWhiteText(canvas, style, text, w);
    }
  }
}

class _CalculatorOnSpecialButtonState extends CalculatorButtonState {
  @protected
  @override
  void initState() {
    super.initState();
    widget.bFactory.controller.model.onIsPressed.addObserver(_onUpdate);
  }

  @protected
  @override
  void dispose() {
    super.dispose();
    widget.bFactory.controller.model.onIsPressed.removeObserver(_onUpdate);
  }

  void _onUpdate(bool arg) => setState(() {});
}

abstract class CalculatorShiftButton extends CalculatorButton {
  CalculatorShiftButton(
      ButtonFactory factory,
      String uText,
      String fText,
      String gText,
      Operation uKey,
      Operation fKey,
      Operation gKey,
      String rawKeyboardKey,
      {String? acceleratorLabel})
      : super(factory, uText, fText, gText, uKey, fKey, gKey, rawKeyboardKey,
            acceleratorLabel: acceleratorLabel);

  String get extraAcceleratorName;

  @override
  void drawKeyboardAccelerator(Canvas canvas) {
    super.drawKeyboardAccelerator(canvas);
    final s = TextStyle(
        fontSize: 20, fontFamily: 'KeyLabelFont', color: Color(0xff5fe88d));
    final double x = -29;
    double y = 7 + s.fontSize! * 3.7;
    TextPainter p = TextPainter(
        text: TextSpan(style: s, text: extraAcceleratorName),
        textAlign: TextAlign.right,
        textDirection: TextDirection.ltr);
    p.layout(minWidth: 29);
    p.paint(canvas, Offset(x, y));
    y += s.fontSize!;
  }
}

///
/// The f shift button, which is gold instead of black.
///
class CalculatorFButton extends CalculatorShiftButton {
  CalculatorFButton(
      ButtonFactory factory,
      String uText,
      String fText,
      String gText,
      Operation uKey,
      Operation fKey,
      Operation gKey,
      String rawKeyboardKey,
      {String? acceleratorLabel})
      : super(factory, uText, fText, gText, uKey, fKey, gKey, rawKeyboardKey,
            acceleratorLabel: acceleratorLabel);

  @override
  Color get innerBorderColor => const Color(0xfffc8f3b);
  @override
  Color get lowerSurfaceColor => const Color(0xffb66b34);
  @override
  Color get lowerSurfaceColorPressed => const Color(0xffbf7238);
  @override
  Color get upperSurfaceColor => const Color(0xfff58634);
  @override
  Color get upperSurfaceColorPressed => const Color(0xfffd8b38);
  @override
  Offset get keyTextOffset => bFactory.fKeyTextOffset;
  @override
  TextStyle get keyTextStyle => bFactory.shiftKeyTextStyle;

  @override
  String get extraAcceleratorName => '^F';
}

///
/// The g shift button, which is blue instead of black.
///
class CalculatorGButton extends CalculatorShiftButton {
  CalculatorGButton(
      ButtonFactory factory,
      String uText,
      String fText,
      String gText,
      Operation uKey,
      Operation fKey,
      Operation gKey,
      String rawKeyboardKey,
      {String? acceleratorLabel})
      : super(factory, uText, fText, gText, uKey, fKey, gKey, rawKeyboardKey,
            acceleratorLabel: acceleratorLabel);

  @override
  Color get innerBorderColor => const Color(0xff30bfdf);
  @override
  Color get lowerSurfaceColor => const Color(0xff008ebd);
  @override
  Color get lowerSurfaceColorPressed => const Color(0xff0099e2);
  @override
  Color get upperSurfaceColor => const Color(0xff00afef);
  @override
  Color get upperSurfaceColorPressed => const Color(0xff00b7f7);
  @override
  Offset get keyTextOffset => bFactory.gKeyTextOffset;
  @override
  TextStyle get keyTextStyle => bFactory.shiftKeyTextStyle;

  @override
  String get extraAcceleratorName => '^G';
}

///
/// The button that has LJ in blue text.  Deja vu Sans has a really ugly "J",
/// so we change the font.
///
class CalculatorButtonWithLJ extends CalculatorButton {
  CalculatorButtonWithLJ(
      ButtonFactory factory,
      String uText,
      String fText,
      String gText,
      Operation uKey,
      Operation fKey,
      Operation gKey,
      String rawKeyboardKey)
      : super(factory, uText, fText, gText, uKey, fKey, gKey, rawKeyboardKey);

  @override
  void drawBlueText(Canvas canvas, double w) {
    TextSpan span = TextSpan(style: bFactory.gTextStyleForLJ, text: gText);
    TextPainter tp = TextPainter(
        text: span,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr);
    tp.layout(minWidth: w);
    tp.paint(canvas, gTextOffset);
  }
}

///
/// The square root button, which draws and extra line above the blue
/// label to visually complete the square-root symbol.  Lining this
/// up depends on the specific font, which is bundled with the app.
///
class CalculatorSqrtButton extends CalculatorButton {
  CalculatorSqrtButton(
      ButtonFactory factory,
      String uText,
      String fText,
      String gText,
      NormalOperation uKey,
      NormalOperation fKey,
      NormalOperation gKey,
      String rawKeyboardKey)
      : super(factory, uText, fText, gText, uKey, fKey, gKey, rawKeyboardKey);

  @override
  void drawBlueText(Canvas canvas, double w) {
    super.drawBlueText(canvas, w);
    // Extend the line on the top of the square root symbol
    TextSpan span = TextSpan(style: bFactory.gTextStyle, text: '\u203E');
    TextPainter tp = TextPainter(
        text: span,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr);
    tp.layout(minWidth: w);
    tp.paint(canvas, gTextOffset.translate(5.4, -2.2));
    tp.paint(canvas, gTextOffset.translate(13, -2.2));
  }
}

///
/// The enter button, which occupies two rows on the keyboard.
///
class CalculatorEnterButton extends CalculatorButton {
  CalculatorEnterButton(
      ButtonFactory factory,
      String uText,
      String fText,
      String gText,
      Operation uKey,
      Operation fKey,
      Operation gKey,
      String rawKeyboardKey,
      {required this.extraHeight,
      String? acceleratorLabel})
      : _outerBorder = _calculateOuterBorder(factory, extraHeight),
        _innerBorder = _calculateInnerBorder(factory, extraHeight),
        _lowerSurface = _calculateLowerSurface(factory, extraHeight),
        _upperSurface = _calculateUpperSurface(factory, extraHeight),
        _gTextOffset = factory.gTextOffset.translate(0, extraHeight),
        super(factory, uText, fText, gText, uKey, fKey, gKey, rawKeyboardKey,
            acceleratorLabel: acceleratorLabel);

  final double extraHeight;
  final RRect _outerBorder;
  final RRect _innerBorder;
  final RRect _lowerSurface;
  final RRect _upperSurface;
  final Offset _gTextOffset;
  @override
  double get outerBorderPressedScale =>
      1 +
      (super.outerBorderPressedScale * super.height - super.height) / height;

  @override
  double get height => super.height + extraHeight;

  @override
  RRect get outerBorder => _outerBorder;

  @override
  RRect get innerBorder => _innerBorder;

  @override
  RRect get lowerSurface => _lowerSurface;

  @override
  RRect get upperSurface => _upperSurface;

  @override
  Offset get keyTextOffset => bFactory.enterKeyTextOffset;

  @override
  Offset get gTextOffset => _gTextOffset;

  static RRect _calculateOuterBorder(ButtonFactory f, double extraHeight) {
    final RRect r = f.outerBorder;
    return RRect.fromLTRBR(
        r.left, r.top, r.right, r.bottom + extraHeight, r.tlRadius);
  }

  static RRect _calculateInnerBorder(ButtonFactory f, double extraHeight) {
    final RRect r = f.innerBorder;
    return RRect.fromLTRBR(
        r.left, r.top, r.right, r.bottom + extraHeight, r.tlRadius);
  }

  static RRect _calculateLowerSurface(ButtonFactory f, double extraHeight) {
    final RRect r = f.lowerSurface;
    return RRect.fromLTRBAndCorners(
        r.left, r.top + extraHeight, r.right, r.bottom + extraHeight,
        topLeft: r.tlRadius, topRight: r.trRadius);
  }

  static RRect _calculateUpperSurface(ButtonFactory f, double extraHeight) {
    final RRect r = f.upperSurface;
    return RRect.fromLTRBAndCorners(
        r.left, r.top, r.right, r.bottom + extraHeight,
        bottomLeft: r.blRadius, bottomRight: r.brRadius);
  }
}

class CalculatorButtonState extends State<CalculatorButton> {
  bool _pressed = false;
  bool _pressedFromKeyboard = false;

  ButtonFactory get factory => widget.bFactory;

  @override
  void initState() {
    super.initState();
    widget.bFactory.controller.model.settings.showAccelerators
        .addObserver(_repaint);
    widget.bFactory.controller.keyboard.register(this, widget.acceleratorKey);
  }

  @override
  void dispose() {
    super.dispose();
    widget.bFactory.controller.model.settings.showAccelerators
        .removeObserver(_repaint);
    widget.bFactory.controller.keyboard.deregister(this, widget.acceleratorKey);
  }

  @override
  @protected
  void didUpdateWidget(covariant CalculatorButton old) {
    KeyboardController c = widget.bFactory.controller.keyboard;
    if (old.acceleratorKey != widget.acceleratorKey) {
      if (_pressed) {
        setState(() {
          _pressed = false;
          _pressedFromKeyboard = false;
        }); // Hard to imagine this happening
      }
      c.deregister(this, old.acceleratorKey);
      c.register(this, widget.acceleratorKey);
    }
    super.didUpdateWidget(old);
  }

  void _repaint(bool _) => setState(() {});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        onTap: () {},
        onTapCancel: () {
          setState(() {
            _pressed = false;
          });
          // We don't distinguish cancel and up, because calculator buttons
          // have most of their effect when pressed.  Releasing the button
          // is only meaningful for thingsk like show-hex or clear-prefix,
          // where the transitory display is held as long as the button is.
          factory.controller.buttonUp();
        },
        onTapDown: (TapDownDetails details) {
          setState(() {
            _pressed = true;
          });
          // In case they're holding down a keyboard key while they press
          // a button with the mouse:
          factory.controller.keyboard.releasePressedButton();

          // yes, I could have use a simple three-way switch statement here,
          // but I like the State pattern.
          final Operation key = factory.controller.model.shift.select(widget);
          factory.controller.buttonDown(key);
        },
        onTapUp: (TapUpDetails details) {
          setState(() {
            _pressed = false;
          });
          factory.controller.buttonUp();
        },
        child: CustomPaint(
            painter: _ButtonPainter(widget,
                pressed: _pressed,
                pressedFromKeyboard: _pressedFromKeyboard,
                showAccelerators:
                    factory.controller.model.settings.showAccelerators.value)));
  }

  /// When the button is "pressed" with an accelerator key
  void keyPressed() {
    setState(() {
      _pressed = true;
      _pressedFromKeyboard = true;
    });
    final Operation key = factory.controller.model.shift.select(widget);
    factory.controller.buttonDown(key);
  }

  /// When the button is released with an accelerator key
  void keyReleased() {
    setState(() {
      _pressed = false;
      _pressedFromKeyboard = false;
    });
    factory.controller.buttonUp();
  }
}

class _ButtonPainter extends CustomPainter {
  final CalculatorButton _button;
  final bool pressed;
  final bool pressedFromKeyboard;
  final bool showAccelerators;

  _ButtonPainter(this._button,
      {required this.pressed,
      required this.pressedFromKeyboard,
      required this.showAccelerators});

  @override
  void paint(Canvas canvas, Size size) {
    // Redirect to the button, so that button subtypes can
    // paint differently.
    _button.paintForPainter(canvas, size,
        pressed: pressed,
        pressedFromKeyboard: pressedFromKeyboard,
        showAccelerators: showAccelerators);
  }

  @override
  bool shouldRepaint(covariant _ButtonPainter oldDelegate) {
    return oldDelegate.pressed != pressed ||
        oldDelegate.pressedFromKeyboard != pressedFromKeyboard ||
        oldDelegate.showAccelerators != showAccelerators;
  }
}
