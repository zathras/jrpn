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

///
/// The calculator's back panel.
///
class BackPanel16 extends BackPanel {
  BackPanel16({Key? key}) : super(key: key);

  @override
  Widget buildBackPanelPortrait(
          BuildContext context, final ScreenPositioner screen) =>
      Stack(fit: StackFit.expand, children: [
        Container(color: MainScreen.keyboardBaseColor),
        screen.box(Rect.fromLTWH(screen.width - 0.8, 0.0, 0.8, 0.8),
            const Icon(Icons.arrow_back, color: Colors.white)),
        screen.box(const Rect.fromLTWH(0.1, 0.1, 5.03 * 0.7, 1.98 * 0.7),
            Image.asset('assets/NAFO_OFAN_brain_damaged_cartoon_dogs.jpeg')),
        screen.box(const Rect.fromLTWH(4.15, -.7, .75, 3), tryzub(1)),
        screen.box(
            const Rect.fromLTWH(1.175, 1.8, 5.65, 6.5), operationTable(5.65)),
        screen.box(const Rect.fromLTWH(0.45, 8.5, 4.97, 4), errorTable(4.97)),
        screen.box(const Rect.fromLTWH(6.0, 8.5, 1.57, 3), flagTable(1.57)),
      ]);

  @override
  Widget buildBackPanelLandscape(
          BuildContext context, final ScreenPositioner screen) =>
      Stack(fit: StackFit.expand, children: [
        Container(color: MainScreen.keyboardBaseColor),
        screen.box(const Rect.fromLTWH(11.8, 0.0, 0.8, 0.8),
            const Icon(Icons.arrow_back, color: Colors.white)),
        screen.box(const Rect.fromLTWH(0.1, 0.1, 5.03 * 0.7, 1.98 * 0.7),
            Image.asset('assets/NAFO_OFAN_brain_damaged_cartoon_dogs.jpeg')),
        screen.box(const Rect.fromLTWH(1.55, .8, .75, 3), tryzub(1)),
        screen.box(const Rect.fromLTWH(0.10, 3.4, 4.97, 4), errorTable(4.97)),
        screen.box(Rect.fromLTWH(5.225, 1.1, 5.65, screen.height - 1.5),
            operationTable(5.65)),
        screen.box(const Rect.fromLTWH(11.03, 3, 1.57, 3), flagTable(1.57)),
      ]);

  Widget errorTable(double widthCM) => table(widthCM, [
        row([cell(space(3)), cell(text('Error', align: bpCenter))]),
        row([
          cell(text('0', align: bpCenter)),
          cell(list([
            text('\u200ay\u00F70,'),
            sqrtText('\u221A   '),
            space(-3.4),
            text('-4', scale: 0.75, offset: const Offset(0.2, 0.3)),
            text(',...')
          ]))
        ]),
        row([
          cell(text('1', align: bpCenter)),
          cell(text('\u200aFLOAT>9,GTO.>9,WINDOW>7,F>5', scale: 0.9))
        ]),
        row([
          cell(text('2', align: bpCenter)),
          cell(text('\u200aMASK,B,RL,RR>WSIZE;WSIZE>64', scale: 0.9))
        ]),
        row([
          cell(text('3', align: bpCenter)),
          cell(list([
            text('\u200aR'),
            space(-0.8),
            text('n', scale: 0.80, offset: const Offset(0, 0.57)),
            text('>MEM')
          ]))
        ]),
        row([
          cell(text('4', align: bpCenter)),
          cell(list(
              [text('\u200aLBL?'), space(-0.7), text(',GTO>MEM,PRGM>203')]))
        ]),
        row([
          cell(text('5', align: bpCenter)),
          cell(list([
            text('\u200a>4'),
            text('RTN', offset: const Offset(0.2, 0.2), scale: 0.9, box: true)
          ]))
        ]),
        row([
          cell(text('6', align: bpCenter)),
          cell(text('\u200aR\u2260FLOAT'))
        ]),
      ]);

  Widget operationTable(double widthCM) => table(widthCM, [
        row([
          cell(space(0)),
          cell(text('C', align: bpCenter)),
          cell(text('G', align: bpCenter)),
          cell(space(0))
        ]),
        row([
          cell(center(list([
            text('+', offset: const Offset(0.3, 0), box: true),
            space(1.2),
            text('\u2212', offset: const Offset(0.3, 0), box: true)
          ]))),
          cell(text('x', align: bpCenter)),
          cell(text('x', align: bpCenter)),
          cell(space(0))
        ]),
        row([
          cell(center(text('\u00D7',
              box: true, offset: const Offset(0.3, 0)))), // multiply
          cell(text('--', align: bpCenter)),
          cell(text('x', align: bpCenter)),
          cell(space(0))
        ]),
        row([
          cell(center(text('\u00F7',
              box: true, offset: const Offset(0.3, 0)))), //  divide
          cell(text('x', align: bpCenter)),
          cell(text('x', align: bpCenter)),
          cell(list(
              [text('\u200aRMD\u22600'), arrowRight(2), space(0.4), text('C')]))
        ]),
        row([
          cell(center(sqrtText('\u221Ax',
              box: true, offset: const Offset(0.1, 0.3)))), // sqrt(x)
          cell(text('x', align: bpCenter)),
          cell(text('--', align: bpCenter)),
          cell(list(
              [text('\u200aRMD\u22600'), arrowRight(2), space(0.4), text('C')]))
        ]),
        row([
          cell(center(list([
            space(0.7),
            text('\u200aCHS',
                offset: const Offset(0.2, 0), box: true, scale: 0.75),
            text(','),
            text(' ABS', offset: const Offset(-0.1, 0), box: true, scale: 0.75),
            space(0.7)
          ]))),
          cell(text('--', align: bpCenter)),
          cell(text('x', align: bpCenter)),
          cell(space(0))
        ]),
        row([
          cell(center(text('DBL\u00D7',
              offset: const Offset(0.5, 0.1),
              box: true,
              scale: 0.9))), // multiply
          cell(text('--', align: bpCenter)),
          cell(text('x', align: bpCenter)),
          cell(list([text('\u200ay\u2219x'), arrowRight(2), text('X&Y')]))
        ]),
        row([
          cell(center(text('DBL\u00F7',
              offset: const Offset(0.5, 0.1),
              box: true,
              scale: 0.91))), // multiply
          cell(text('x', align: bpCenter)),
          cell(text('o', align: bpCenter)),
          cell(list([
            text('\u200a(y&z)\u00F7x'),
            arrowRight(2),
            text('X ; '),
            text('RMD\u22600'),
            arrowRight(2),
            space(0.4),
            text('C')
          ])),
        ]),
        row([
          cell(center(text('\u200aSL',
              offset: const Offset(0.0, 0.0),
              box: true,
              boxOffset: const Offset(0, -0.15),
              scale: 0.88))),
          cell(text('x', align: bpCenter)),
          cell(text('--', align: bpCenter)),
          cellEB(list([
            space(2),
            carry(),
            arrowLeft(3.7),
            registerBox(20, list([space(0.8), arrowLeft(17.8), point()])),
            arrowLeft(3.7),
            space(0.2),
            text('0', scale: 0.8),
            space(2)
          ]))
        ]),
        row([
          cell(center(text('SR',
              offset: const Offset(0.20, 0.0),
              box: true,
              boxOffset: const Offset(0, -0.15),
              scale: 0.88))),
          cell(text('x', align: bpCenter)),
          cell(text('--', align: bpCenter)),
          cellEB(list([
            space(2),
            text('0', scale: 0.8, offset: const Offset(.38, 0.10)),
            space(0.5),
            arrowRight(3.7),
            registerBox(
                20,
                list([
                  space(1.3),
                  point(),
                  arrowRight(18.0),
                ])),
            arrowRight(3.7),
            space(0.2),
            carry()
          ]))
        ]),
        row([
          cell(center(text('\u200aASR',
              offset: const Offset(-0.07, 0.0),
              box: true,
              boxOffset: const Offset(0, -0.15),
              scale: 0.88))),
          cell(text('x', align: bpCenter)),
          cell(text('--', align: bpCenter)),
          cellEB(list([
            space(2.0),
            BPCustomItem(1.9, (Canvas c, BPItemPainter p) {
              final double ym = rowHeightMM / 2;
              var path = Path()
                ..moveTo(1.9, ym)
                ..lineTo(0, ym)
                ..lineTo(0, rowHeightMM + 0.1)
                ..lineTo(2.9, rowHeightMM + 0.1)
                ..lineTo(2.9, rowHeightMM - 0.8);
              c.drawPath(path, p.thinLine);
              path = Path()
                ..addPolygon([
                  Offset(2.9, rowHeightMM - 0.7),
                  Offset(2.45, rowHeightMM - 0.2),
                  Offset(3.35, rowHeightMM - 0.2),
                ], true);
              c.drawPath(path, p.fill);
            }),
            registerBox(
                24,
                list([
                  space(1.3),
                  point(),
                  arrowRight(22.0),
                ])),
            arrowRight(3.7),
            space(0.2),
            carry()
          ]))
        ]),
        row([
          cell(center(text('\u200aRL',
              offset: const Offset(-0.10, -0.04),
              box: true,
              boxOffset: const Offset(0, -0.15),
              scale: 0.88))),
          cell(text('x', align: bpCenter)),
          cell(text('--', align: bpCenter)),
          cellEB(list([
            space(4),
            carry(),
            space(2.3),
            point(),
            BPCustomItem(0, (Canvas c, BPItemPainter p) {
              final double ym = rowHeightMM / 2;
              var path = Path()
                ..moveTo(0, ym)
                ..lineTo(0, rowHeightMM - 0.45)
                ..lineTo(25, rowHeightMM - 0.45)
                ..lineTo(25, ym)
                ..lineTo(23.4, ym);
              c.drawPath(path, p.thinLine);
            }),
            space(-2.3),
            arrowLeft(3.7),
            registerBox(21, list([space(0.8), arrowLeft(18.8), point()])),
            arrowLeft(0)
          ]))
        ]),
        row([
          cell(center(text('RR',
              offset: const Offset(0.10, -0.04),
              box: true,
              boxOffset: const Offset(0, -0.15),
              scale: 0.88))),
          cell(text('x', align: bpCenter)),
          cell(text('--', align: bpCenter)),
          cellEB(list([
            space(3.9),
            arrowRight(0),
            space(-1.9),
            BPCustomItem(1.9, (Canvas c, BPItemPainter p) {
              final double ym = rowHeightMM / 2;
              var path = Path()
                ..moveTo(1.9, ym)
                ..lineTo(0, ym)
                ..lineTo(0, rowHeightMM - 0.45)
                ..lineTo(27.3, rowHeightMM - 0.45)
                ..lineTo(27.3, ym);
              c.drawPath(path, p.thinLine);
            }),
            registerBox(
                24,
                list([
                  space(1.3),
                  point(),
                  arrowRight(22.0),
                ])),
            space(1.4),
            point(),
            space(-1.4),
            arrowRight(3.7),
            space(0.2),
            carry()
          ]))
        ]),
        row([
          cell(center(text('\u200aRLC',
              offset: const Offset(-0.10, -0.04),
              box: true,
              boxOffset: const Offset(0, -0.15),
              scale: 0.88))),
          cell(text('x', align: bpCenter)),
          cell(text('--', align: bpCenter)),
          cellEB(list([
            space(4),
            carry(),
            space(2.3),
            BPCustomItem(0, (Canvas c, BPItemPainter p) {
              final double ym = rowHeightMM / 2;
              var path = Path()
                ..moveTo(-4.3, ym)
                ..lineTo(-6.4, ym)
                ..lineTo(-6.4, rowHeightMM - 0.45)
                ..lineTo(25, rowHeightMM - 0.45)
                ..lineTo(25, ym)
                ..lineTo(23.4, ym);
              c.drawPath(path, p.thinLine);
            }),
            space(-2.3),
            arrowLeft(3.7),
            registerBox(21, list([space(0.8), arrowLeft(18.8), point()])),
            arrowLeft(0)
          ]))
        ]),
        row([
          cell(center(text('RRC',
              offset: const Offset(0.10, -0.04),
              box: true,
              boxOffset: const Offset(0, -0.15),
              scale: 0.88))),
          cell(text('x', align: bpCenter)),
          cell(text('--', align: bpCenter)),
          cellEB(list([
            space(3.9),
            arrowRight(0),
            space(-1.9),
            BPCustomItem(1.9, (Canvas c, BPItemPainter p) {
              final double ym = rowHeightMM / 2;
              var path = Path()
                ..moveTo(1.9, ym)
                ..lineTo(0, ym)
                ..lineTo(0, rowHeightMM - 0.45)
                ..lineTo(30.9, rowHeightMM - 0.45)
                ..lineTo(30.9, rowHeightMM - .9);
              c.drawPath(path, p.thinLine);
            }),
            registerBox(
                24,
                list([
                  space(1.3),
                  point(),
                  arrowRight(22.0),
                ])),
            arrowRight(3.7),
            space(0.2),
            carry()
          ]))
        ]),
      ]);

  Widget flagTable(double widthCM) => table(widthCM, [
        row([cell(space(3)), cell(text('SF', align: bpCenter))]),
        row([cell(text('0', align: bpCenter)), cell(space(0))]),
        row([cell(text('1', align: bpCenter)), cell(space(0))]),
        row([cell(text('2', align: bpCenter)), cell(space(0))]),
        row([cell(text('3', align: bpCenter)), cell(text('\u200a0...0A7'))]),
        row([cell(text('4', align: bpCenter)), cell(text('\u200aC'))]),
        row([cell(text('5', align: bpCenter)), cell(text('\u200aG'))]),
      ]);
}
