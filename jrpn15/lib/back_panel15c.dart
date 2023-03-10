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
///
/// The back panel of the calculator.
///

import 'package:flutter/material.dart';
import 'package:jrpn/v/main_screen.dart';
import 'package:jrpn/v/back_panel.dart';
import 'dart:math' as dart;

///
/// The calculator's back panel.
///
class BackPanel15 extends BackPanel {
  BackPanel15({Key? key}) : super(key: key);

  @override
  get thickLineWidth => rowHeightMM * 0.09;
  @override
  get thinLineWidth => rowHeightMM * 0.05;
  @override
  get rowHeightMM => 3.7;
  @override
  double get fontSize => rowHeightMM * 0.60;
  @override
  double get textUp => rowHeightMM * -.10;
  @override
  double get arrowUp => rowHeightMM * 0.14;

  @override
  Widget buildBackPanelPortrait(
          BuildContext context, final ScreenPositioner screen) =>
      Stack(fit: StackFit.expand, children: [
        Container(color: MainScreen.keyboardBaseColor),
        screen.box(Rect.fromLTWH(screen.width - 0.8, 0.0, 0.8, 0.8),
            const Icon(Icons.arrow_back, color: Colors.white)),
        screen.box(
            const Rect.fromLTWH(0.1, 0.1, 5.03 * 0.57, 1.98 * 0.57),
            Image.asset(
                'packages/jrpn/assets/NAFO_OFAN_brain_damaged_cartoon_dogs.jpeg')),
        screen.box(const Rect.fromLTWH(0.78, 3.6, .75, 3), tryzub(1)),
        screen.box(const Rect.fromLTWH(0.4, 7.23, 1.6, 2.2), sigmaTable(1.6)),
        screen.box(const Rect.fromLTWH(2.52, 3.27, 5, 3.4), drawingTable(5)),
        ...jumpTableList(screen, 3.70, 0.2),
        screen.box(const Rect.fromLTWH(0.2, 1.57, 3.5, 2.2), metricTable(3.5)),
        screen.box(const Rect.fromLTWH(2.10, 7.20, 4, 5), numberTable(4.0))
      ]);

  @override
  Widget buildBackPanelLandscape(
          BuildContext context, final ScreenPositioner screen) =>
      Stack(fit: StackFit.expand, children: [
        Container(color: MainScreen.keyboardBaseColor),
        screen.box(const Rect.fromLTWH(11.8, 0.4, 0.8, 0.8),
            const Icon(Icons.arrow_back, color: Colors.white)),
        screen.box(
            const Rect.fromLTWH(0.1, 0.5, 5.03 * 0.57, 1.98 * 0.57),
            Image.asset(
                'packages/jrpn/assets/NAFO_OFAN_brain_damaged_cartoon_dogs.jpeg')),
        screen.box(const Rect.fromLTWH(1.05, 1.0, .75, 3), tryzub(1)),
        screen.box(const Rect.fromLTWH(0.2, 3.96, 1.6, 2.2), sigmaTable(1.6)),
        screen.box(const Rect.fromLTWH(1.43, 3.76, 5, 3.4), drawingTable(5)),
        ...jumpTableList(screen, 3.49, 0.7),
        screen.box(const Rect.fromLTWH(6.83, 0.7, 3.5, 2.2), metricTable(3.5)),
        screen.box(const Rect.fromLTWH(6.83, 2.40, 4, 5), numberTable(4.0))
      ]);

  List<Widget> jumpTableList(ScreenPositioner screen, double x, double y) => [
        screen.box(Rect.fromLTWH(x, y, 3.2, 2.9), jumpTable(3.2, 2.9)),
        screen.box(Rect.fromLTWH(x - 3.49 + 4.05, y - 0.7 + 1.9, 1.5, 3),
            jumpTableKey('\u200a\u200a\u200aISG', 1.9)),
        screen.box(Rect.fromLTWH(x - 3.49 + 5.6, y - 0.7 + 1.9, 1.5, 3),
            jumpTableKey('DSE', 1.9))
      ];

  Widget sigmaTable(double widthCM) => table(
      widthCM,
      [
        row([
          cell(space(1)),
          cell(text('\u03a3', align: bpCenter)),
          cell(space(1))
        ]),
        row([
          cell(list([italicText('n', align: bpRight), space(.7)])),
          cell(arrowRight(2)),
          cell(list([text('R'), space(-.5), subText('2'), space(.2)]))
        ]),
        row([
          cell(list([text('\u03a3x', align: bpRight), space(.9)])),
          cell(arrowRight(2)),
          cell(list([text('R'), space(-.5), subText('3')]))
        ]),
        row([
          cell(list(
              [text('\u03a3x', align: bpRight), supText('2'), space(-.5)])),
          cell(arrowRight(2)),
          cell(list([text('R'), space(-.5), subText('4')]))
        ]),
        row([
          cell(list([text('\u03a3y', align: bpRight), space(.9)])),
          cell(arrowRight(2)),
          cell(list([text('R'), space(-.5), subText('5')]))
        ]),
        row([
          cell(list(
              [text('\u03a3y', align: bpRight), supText('2'), space(-.5)])),
          cell(arrowRight(2)),
          cell(list([text('R'), space(-.5), subText('6')]))
        ]),
        row([
          cell(text('\u03a3xy', align: bpRight)),
          cell(arrowRight(2)),
          cell(list([text('R'), space(-.5), subText('7')]))
        ]),
      ],
      drawLines: false);

  Widget jumpTable(double widthCM, double heightCM) =>
      _JumpTable(widthCM * 10, heightCM * 10, this,
          topText: cell(text('R = nnnnn.xxxyy', scale: .85, align: bpCenter)),
          mainText: [
            [
              cell(text('nnnnn + yy', scale: .65, align: bpCenter)),
              cell(text('\u2264 xxx', scale: .65, align: bpCenter))
            ],
            [
              cell(list([
                text('nnnnn', scale: .65, align: bpCenter),
                space(0.1),
                text('+', scale: .65, offset: const Offset(0, -0.55)),
                text('\u2212', scale: .65, offset: const Offset(-2.0, .4)),
                space(1.1),
                text('yy', scale: .65)
              ])),
              cell(text('> xxx', scale: .65, align: bpCenter))
            ],
            [
              cell(text('nnnnn \u2212 yy', scale: .65, align: bpCenter)),
              cell(text('\u2264 xxx', scale: .65, align: bpCenter))
            ]
          ]);

  Widget jumpTableKey(String key, double widthCM) =>
      _JumpTableKey(widthCM, this, [
        row([
          cell(text('')),
        ]),
        row([
          cell(list([
            space(.55),
            text(key,
                box: true,
                offset: const Offset(0, .1),
                boxOffset: const Offset(-.1, -.55)),
            space(.45)
          ])),
        ]),
        row([
          cell(text('')),
        ]),
        row([
          cell(text('')),
        ]),
      ]);

  Widget metricTable(double widthCM) => table(
      widthCM,
      [
        row([
          cell(text(' cm \u00f7 2.54')),
          cell(arrowRight(2)),
          cell(text('in'))
        ]),
        row([
          cell(text(' kg \u00d7 2.204622622')),
          cell(arrowRight(2)),
          cell(list([text('lbm'), space(0.3)]))
        ]),
        row([
          cell(text(' \u200a\u2113 \u00f7 3.785411784')),
          cell(arrowRight(2)),
          cell(text('gal'))
        ]),
        row([
          cell(text(' \u00b0C \u00d7 1.8 + 32')),
          cell(arrowRight(2)),
          cell(text('\u00b0F'))
        ]),
      ],
      drawVerticalLines: false);

  Widget drawingTable(double widthCM) => _TableWithDrawing(widthCM, this, [
        row([
          cell(space(0)),
          cell(text('x', align: TextAlign.center)),
          cell(text('y', align: TextAlign.center))
        ]),
        row([
          cell(text('\u279cP',
              box: true,
              align: TextAlign.center,
              boxOffset: const Offset(-.3, -.77))),
          cell(text('r', align: TextAlign.center)),
          cell(text('\u03b8', align: TextAlign.center))
        ]),
        row([
          cell(text('\u279cR',
              box: true,
              align: TextAlign.center,
              boxOffset: const Offset(-.3, -.77))),
          cell(text('x', align: TextAlign.center)),
          cell(text('y', align: TextAlign.center))
        ]),
        row([
          cell(text('x\u0305',
              box: true,
              align: TextAlign.center,
              boxOffset: const Offset(-.37, -.77))),
          cell(text('x\u0305', align: TextAlign.center)),
          cell(text('y\u0305', align: TextAlign.center))
        ]),
        row([
          cell(text('s',
              box: true,
              align: TextAlign.center,
              boxOffset: const Offset(-.37, -.77))),
          cell(list([text('s', align: TextAlign.center), subText('x')])),
          cell(list([text('s', align: TextAlign.center), subText('y')]))
        ]),
        row([
          cell(text('y\u0302,r',
              box: true,
              align: TextAlign.center,
              boxOffset: const Offset(-.37, -.70))),
          cell(text('y\u0302', align: TextAlign.center)),
          cell(text('r', align: TextAlign.center))
        ]),
        row([
          cell(text('L.R.',
              box: true,
              align: TextAlign.center,
              boxOffset: const Offset(-.37, -.77))),
          cell(italicText('B', align: TextAlign.center)),
          cell(italicText('A', align: TextAlign.center))
        ]),
        row([
          cell(list([
            space(0.8),
            text('RCL', box: true, boxOffset: const Offset(-.20, -.77)),
            space(0.1),
            text('\u03a3')
          ])),
          cell(text('\u03a3x', align: TextAlign.center)),
          cell(text(' \u03a3y ', align: TextAlign.center))
        ]),
        row([
          cell(text('%',
              box: true,
              align: TextAlign.center,
              offset: const Offset(0, .1),
              boxOffset: const Offset(-.37, -.70))),
          cell(superimpose([
            text('x \u2219 y',
                scale: 0.6,
                offset: const Offset(0, -2),
                align: TextAlign.center),
            text(('_______'),
                scale: 0.6,
                offset: const Offset(0, -1.7),
                align: TextAlign.center),
            text('100',
                scale: 0.6,
                offset: const Offset(0, 1.2),
                align: TextAlign.center),
          ])),
          cell(text('y', align: TextAlign.center))
        ]),
        row([
          cell(text('\u200a\u0394%',
              box: true,
              offset: const Offset(0, .1),
              boxOffset: const Offset(-.37, -.70),
              align: TextAlign.center)),
          cell(list([
            space(.8),
            superimpose([
              text('x \u2212 y',
                  scale: 0.6,
                  offset: const Offset(0, -2),
                  align: TextAlign.center),
              text(('_______'),
                  scale: 0.6,
                  offset: const Offset(0, -1.7),
                  align: TextAlign.center),
              text('y',
                  scale: 0.6,
                  offset: const Offset(0, 1.2),
                  align: TextAlign.center),
            ]),
            text(' \u00D7 100'),
            space(.8)
          ])),
          cell(text('y', align: TextAlign.center))
        ]),
      ]);

  Widget numberTable(double widthCM) => _NumberTable(widthCM, this, [
        row([
          cell(text('')),
          cell(text('ERROR', align: bpCenter)),
          cell(list([text('TEST', align: bpCenter)])),
          cell(text('MATRIX', align: bpCenter))
        ]),
        row([
          cell(text('0', align: bpCenter)),
          cell(text(' y \u00f7 0, LN 0, ...')),
          cell(text('x\u200a\u2260\u200a0', align: bpCenter)),
          cell(text(' 0 DIM'))
        ]),
        row([
          cell(text('1', align: bpCenter)),
          cell(text(' LN A , SIN A , ...')),
          cell(text('x\u200a>\u200a0', align: bpCenter)),
          cell(list([
            text(' 1'),
            space(-1),
            arrowRight(2),
            text('R'),
            space(-.5),
            subText('0'),
            space(-.4),
            text(',\u200a1'),
            space(-.8),
            arrowRight(2),
            text('R'),
            space(-.5),
            subText('1')
          ]))
        ]),
        row([
          cell(text('2', align: bpCenter)),
          cell(text(' \u03a3 Error')),
          cell(text('x\u200a<\u200a0', align: bpCenter)),
          cell(list([
            text(' A'),
            space(-.8),
            supText('P'),
            space(-.4),
            arrowRight(2),
            text('A'),
            space(-2.2),
            text('~', offset: const Offset(0, -1.3))
          ]))
        ]),
        row([
          cell(text('3', align: bpCenter)),
          cell(list([
            text(' R?, A'),
            space(-.2),
            text('i\u200aj', scale: 0.8, offset: Offset(0, 0.15 * rowHeightMM)),
            text('?')
          ])),
          cell(text('x\u200a\u2265\u200a0', align: bpCenter)),
          cell(list([
            text(' A'),
            space(-2.4),
            text('~', offset: const Offset(0, -1.3)),
            arrowRight(2),
            space(0.1),
            text('A'),
            space(-.6),
            supText('P')
          ]))
        ]),
        row([
          cell(text('4', align: bpCenter)),
          cell(list([text('LBL?,GTO>MEM,PRGM>MEM'), space(-.9)])),
          cell(text('x\u200a\u2264\u200a0', align: bpCenter)),
          cell(list([text(' A'), space(-.9), supText('T')]))
        ]),
        row([
          cell(text('5', align: bpCenter)),
          cell(list([
            text(' > 7 '),
            text('RTN', boxOffset: const Offset(-.28, -.64), box: true)
          ])),
          cell(text('x\u200a=\u200ay', align: bpCenter)),
          cell(list(
              [text(' A'), space(-.9), supText('T'), space(-.2), text('B')]))
        ]),
        row([
          cell(text('6', align: bpCenter)),
          cell(text(' SF > 9 , CF > 9 , F? > 9')),
          cell(text('x\u200a\u2260\u200ay', align: bpCenter)),
          cell(text(' B = B - AC'))
        ]),
        row([
          cell(text('7', align: bpCenter)),
          cell(list([
            text(' SOLVE(SOLVE), \u222b'),
            space(-1),
            subText('y'),
            space(-1),
            supText('x'),
            text('(\u222b'),
            space(-1),
            subText('y'),
            space(-1),
            supText('x'),
            text(')')
          ])),
          cell(text('x\u200a>\u200ay', align: bpCenter)),
          cell(list([
            space(.5),
            text('MAX', scale: .7, offset: const Offset(0, -1.2)),
            space(-1.85),
            text('i', scale: .6, offset: const Offset(0, .85)),
            space(2.0),
            text('j', scale: .6, offset: const Offset(0, .85)),
            space(-1),
            text('\u03a3', scale: .8, offset: const Offset(0, -0.95)),
            text('|\u200aa', scale: .7, offset: const Offset(0, -1.2)),
            space(-.45),
            text('i\u200aj', scale: .65, offset: const Offset(.2, -0.5)),
            text('|', scale: .7, offset: const Offset(-.2, -1.2)),
          ]))
        ]),
        row([
          cell(text('8', align: bpCenter)),
          cell(text(' SOLVE ?')),
          cell(text('x\u200a<\u200ay', align: bpCenter)),
          cell(list([
            space(0.25),
            text('('),
            space(0.25),
            text('i\u200aj', scale: 0.6, offset: const Offset(0, 1)),
            space(-1.4),
            text('\u03a3', scale: .8, offset: const Offset(0, -0.90)),
            space(-.3),
            text('|\u200aa', scale: .7, offset: const Offset(0, -1.2)),
            space(-.4),
            text('i\u200aj', scale: .65, offset: const Offset(0, -0.5)),
            space(-.14),
            text('|', scale: .7, offset: const Offset(0, -1.2)),
            space(-.1),
            text('2', scale: .4, offset: const Offset(0, -3.8)),
            text(')'),
            space(-.2),
            text('1', scale: .4, offset: const Offset(0, -3.8)),
            space(-.2),
            text('/', scale: .4, offset: const Offset(0, -3.5)),
            space(-.1),
            text('2', scale: .4, offset: const Offset(0, -2.5)),
          ]))
        ]),
        _NumberTableBottomRow([
          cell(text('9', align: bpCenter)),
          cell(list([
            space(.55),
            text('ON', box: true, boxOffset: const Offset(-.28, -.64)),
            text(' / '),
            text('\u00d7',
                box: true,
                offset: const Offset(-.03, -.01),
                boxOffset: const Offset(-.09, -.64))
          ])),
          cell(text('x\u200a\u2265\u200ay', align: bpCenter)),
          cell(text(' |\u200aA\u200a| '))
        ], this),
        _NumberTableBottomRow([
          cell(text('10\u200a', align: bpCenter)),
          cell(text(' DIM > MEM')),
          cell(text('')),
          cell(text(''))
        ], this),
        _NumberTableBottomRow([
          cell(text('11', align: bpCenter)),
          cell(text(' DIM A \u2260 DIM B')),
          cell(text('')),
          cell(text(''))
        ], this),
      ]);
}

class _JumpTable extends StatelessWidget {
  final double widthMM;
  final double heightMM;
  final BackPanel panel;
  final BPCell topText;
  final List<List<BPCell>> mainText;

  const _JumpTable(this.widthMM, this.heightMM, this.panel,
      {required this.topText, required this.mainText, Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _JumpTablePainter(this));
}

class _JumpTablePainter extends BPItemPainter {
  final _JumpTable table;

  _JumpTablePainter(this.table) : super(table.panel);

  @override
  bool shouldRepaint(_JumpTablePainter oldDelegate) => false;

  @override
  void paint(Canvas canvas, Size size) {
    // Set the scale so one "pixel" is 1mm at the real caluclator's size
    final thickW = panel.thickLineWidth;
    canvas.scale(size.width / table.widthMM);

    RRect frame = RRect.fromLTRBR(
        thickW / 2,
        thickW / 2,
        table.widthMM - thickW / 2,
        table.heightMM - thickW / 2,
        const Radius.circular(0.1));
    canvas.drawRRect(frame, thickLine);
    canvas.translate(0, .5);
    table.topText.paint(canvas, this, 0, table.widthMM);
    canvas.translate(0, 2.7);

    canvas.save();
    final mtW = table.widthMM / 3.8;
    final mtFrame =
        RRect.fromLTRBR(1.0, 0.2, mtW + 1.9, 4.1, const Radius.circular(0.1));
    for (final mt in table.mainText) {
      canvas.drawRRect(mtFrame, panel.thinLine);
      mt[0].paint(canvas, this, 1.4, mtW);
      canvas.translate(0, 1.5);
      mt[1].paint(canvas, this, 1.4, mtW);
      canvas.translate(0, -1.5);
      canvas.translate(table.widthMM / 3.1, 0);
    }
    canvas.restore();
    canvas.translate(-.5, 4.1);
    for (int j = 0; j < 2; j++) {
      canvas.drawLine(const Offset(4.0, 0), const Offset(4.0, 18.1), thinLine);
      canvas.drawLine(
          const Offset(13.2, 0), const Offset(13.2, 10.0), thinLine);
      for (int i = 0; i < 4; i++) {
        const dashLen = dart.pi / 5;
        const dashAdvance = dart.pi * 0.27;
        canvas.drawArc(const Rect.fromLTWH(10.95, 9.95, 4.5, 4.5),
            i * dashAdvance + 3 * dart.pi / 2.0, dashLen, false, thinLine);
      }
      canvas.drawLine(
          const Offset(13.2, 14.5), const Offset(13.2, 18.1), thinLine);
      for (int i = 0; i < 2; i++) {
        const sz = 0.6;
        final downArrow = Path()
          ..addPolygon(const [
            Offset(4, 18 + sz * 2.7),
            Offset(4 - sz, 18),
            Offset(4 + sz, 18)
          ], true);
        canvas.drawPath(downArrow, fill);
        canvas.translate(9.2, 0);
      }
      canvas.translate(-2.8, 0);
    }
  }
}

class _JumpTableKey extends BPTable {
  const _JumpTableKey(double width, BackPanel panel, List<BPRow> rows)
      : super(width, rows, true, true, panel);

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _JumpTableKeyPainter(this));
}

class _JumpTableKeyPainter extends BPTablePainter {
  _JumpTableKeyPainter(_JumpTableKey table) : super(table);

  @override
  void drawOutline(Canvas canvas, double width, double height) {
    final thinW = table.thinLineWidth;
    RRect frame = RRect.fromLTRBR(thinW / 2, thinW / 2, width - thinW / 2,
        height - thinW / 2, const Radius.circular(0.1));
    canvas.drawRRect(frame, thickLine);
  }
}

class _TableWithDrawing extends BPTable {
  const _TableWithDrawing(double width, BackPanel panel, List<BPRow> rows)
      : super(width, rows, true, true, panel);

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _TableWithDrawingPainter(this));
}

class _TableWithDrawingPainter extends BPTablePainter {
  _TableWithDrawingPainter(_TableWithDrawing table) : super(table);

  @override
  void drawOutline(Canvas canvas, double width, double height) {
    super.drawOutline(canvas, width + 24.3, height);
    canvas.drawLine(Offset(width, 0), Offset(width, height), thinLine);
  }

  @override
  void paint(Canvas canvas, Size size) {
    super.paint(canvas, size);
    final curlyStyle = TextStyle(
        color: MainScreen.keyFrameSilver,
        fontSize: panel.fontSize * .7,
        fontWeight: FontWeight.normal,
        fontFamily: 'KeyLabelFont');
    final style = curlyStyle.copyWith(fontStyle: FontStyle.italic);
    final curlyT = TextPainter(
        text: TextSpan(style: curlyStyle, text: '}'),
        textDirection: TextDirection.ltr)
      ..layout();
    final xT = TextPainter(
        text: TextSpan(style: style, text: 'x'),
        textDirection: TextDirection.ltr)
      ..layout();
    final yT = TextPainter(
        text: TextSpan(style: style, text: 'y'),
        textDirection: TextDirection.ltr)
      ..layout();
    final rT = TextPainter(
        text: TextSpan(style: style, text: 'r'),
        textDirection: TextDirection.ltr)
      ..layout();
    final thetaT = TextPainter(
        text: TextSpan(style: style, text: '\u03b8'),
        textDirection: TextDirection.ltr)
      ..layout();
    final bT = TextPainter(
        text: TextSpan(style: style, text: 'B'),
        textDirection: TextDirection.ltr)
      ..layout();
    final formulaT = TextPainter(
        text: TextSpan(style: style, text: 'A = y\u200a/\u200ax'),
        textDirection: TextDirection.ltr)
      ..layout();

    canvas.translate(28.40, 0);
    canvas.save();
    canvas.scale(1, 3.80 / .7);
    curlyT.paint(canvas, const Offset(0, 0.86));
    canvas.scale(1, 0.5);
    curlyT.paint(canvas, const Offset(0, 8.4));
    canvas.restore();
    canvas.translate(1.8, 0);
    final rArrow = Path()
      ..addPolygon(
          const [Offset(0, 0), Offset(-.95, -0.4), Offset(-.95, 0.4)], true);
    canvas.translate(-.4, 7.5);
    for (int i = 0; i < 2; i++) {
      canvas.drawLine(const Offset(0, 0), const Offset(0.9, 0), thinLine);
      canvas.translate(1.6, 0);
      canvas.drawPath(rArrow, fill);
      canvas.translate(-1.6, 16.7);
    }
    canvas.translate(.4, -7.5 - 2 * 16.7);
    canvas.translate(2.0, 16);
    canvas.drawLine(const Offset(0, 0), const Offset(0, -14), thinLine);
    canvas.drawLine(const Offset(0, 0), const Offset(17.7, 0), thinLine);
    dashedLine(canvas, .71, 1.49, const Offset(17.5, 0),
        const Offset(17.5, -13.0), thinLine);
    dashedLine(canvas, .71, 1.49, const Offset(0, -13.0),
        const Offset(17.5, -13.0), thinLine);
    canvas.drawLine(
        const Offset(0, 0), const Offset(17.5, -13.0) * .95, thinLine);
    xT.paint(canvas, const Offset(9, -14.8));
    yT.paint(canvas, const Offset(18.2, -7.5));
    const theta = 0.743;
    canvas.drawArc(const Rect.fromLTRB(-14, -14, 14, 14), 0, -dart.atan(theta),
        false, thinLine);
    thetaT.paint(canvas, const Offset(11.4, -4.7));
    canvas.save();
    canvas.translate(7.8, -8.4);
    canvas.rotate(-theta);
    rT.paint(canvas, const Offset(0, .2));
    canvas.restore();
    canvas.save();
    canvas.translate(14 * dart.cos(.86 * theta), -14 * dart.sin(.86 * theta));
    canvas.rotate(1.3 * theta + 2 * dart.pi / 2);
    canvas.drawPath(rArrow, fill);
    canvas.restore();

    canvas.translate(0, 17.5);
    canvas.drawLine(const Offset(0, 0), const Offset(0, -14), thinLine);
    canvas.drawLine(const Offset(-.6, 0), const Offset(17.7, 0), thinLine);
    const start = Offset(0, -1);
    const end = Offset(17.5 * .95, -14 * .95);
    canvas.drawLine(start, end, thinLine);
    canvas.drawCircle(const Offset(0, -1), .32, fill);
    bT.paint(canvas, const Offset(1.4, -1.42));
    formulaT.paint(canvas, const Offset(2.7, -11));
    final delta = end - start;
    final p1 = start + delta * .2;
    final p2 = end - delta * .1;
    final mid = Offset(p2.dx, p1.dy);
    dashedLine(canvas, .66, 1.32, p1, mid, thinLine);
    dashedLine(canvas, .72, 1.44, p2, mid, thinLine);
    xT.paint(canvas, const Offset(9, -2.8));
    yT.paint(canvas, const Offset(15.7, -7.5));
  }

  void dashedLine(Canvas canvas, double blank, double dash, Offset start,
      Offset end, Paint p) {
    final delta = end - start;
    final len = delta.distance;
    double pos = blank;
    while (pos < len) {
      final a = start + delta * (pos / len);
      pos = dart.min(len, pos + dash);
      final b = start + delta * (pos / len);
      canvas.drawLine(a, b, p);
      pos += blank;
    }
  }
}

class _NumberTable extends BPTable {
  const _NumberTable(double width, BackPanel panel, List<BPRow> rows)
      : super(width, rows, true, true, panel);

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _NumberTablePainter(this));
}

class _NumberTablePainter extends BPTablePainter {
  _NumberTablePainter(_NumberTable table) : super(table);

  @override
  void drawOutline(Canvas canvas, double width, double height) {
    final thickW = table.thickLineWidth;
    final path = Path()
      ..moveTo(thickW / 2, thickW / 2)
      ..lineTo(width - thickW / 2, thickW / 2)
      ..lineTo(width - thickW / 2, height * 0.842)
      ..lineTo(width * 0.645, height * 0.842)
      ..lineTo(width * 0.645, height - thickW / 2)
      ..lineTo(thickW / 2, height - thickW / 2)
      ..close();
    canvas.drawPath(path, thickLine);
  }

  @override
  void paintVerticalLine(Canvas canvas, double x, double height, int c) {
    if (c != 2) {
      super.paintVerticalLine(canvas, x, height, c);
    } else {
      super.paintVerticalLine(
          canvas, x, height - 2 * panel.rowHeightMM - panel.thickLineWidth, c);
    }
  }
}

class _NumberTableBottomRow extends BPRow {
  _NumberTableBottomRow(super.cells, super.panel);

  @override
  bool get drawLastTwoColumnsBottomLine => false;
}
