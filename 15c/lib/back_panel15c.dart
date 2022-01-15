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
///
/// The back panel of the calculator.
///
library view.back_panel;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:jrpn/v/main_screen.dart';

///
/// The calculator's back panel.
///
class BackPanel extends OrientedScreen {
  const BackPanel({Key? key}) : super(key: key);

  @override
  Widget buildPortrait(BuildContext context, final ScreenPositioner screen) {
    return GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
            alignment: Alignment.center,
            color: MainScreen.deadZoneColor,
            child: AspectRatio(
                aspectRatio: screen.width / screen.height,
                child: Stack(fit: StackFit.expand, children: [
                  Container(color: MainScreen.keyboardBaseColor),
                  screen.box(Rect.fromLTWH(screen.width - 0.8, 0.0, 0.8, 0.8),
                      const Icon(Icons.arrow_back, color: Colors.white)),
                  screen.box(const Rect.fromLTWH(1.175, 1.5, 5.65, 6.5),
                      const Text('@@ TODO')),
                ]))));
  }

  @override
  Widget buildLandscape(BuildContext context, final ScreenPositioner screen) {
    return GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
            alignment: Alignment.center,
            color: MainScreen.deadZoneColor,
            child: AspectRatio(
                aspectRatio: screen.width / screen.height,
                child: Stack(fit: StackFit.expand, children: [
                  Container(color: MainScreen.keyboardBaseColor),
                  screen.box(const Rect.fromLTWH(11.8, 0.0, 0.8, 0.8),
                      const Icon(Icons.arrow_back, color: Colors.white)),
                  screen.box(
                      const Rect.fromLTWH(0.10, 3, 4.97, 4), const Text('@@ TODO')),
                ]))));
  }

  static const TextAlign _ctr = TextAlign.center;

  static _Row row(List<_Cell> cells) => _Row(cells);
  static _Cell cell(_Item item) => _Cell(item);
  static _Cell cellEB(_Item item) => _Cell(item, eraseBottom: true);

  static _Item text(String text,
          {bool box = false,
          double scale = 1,
          TextAlign align = TextAlign.left,
          Offset offset = Offset.zero,
          Offset boxOffset = Offset.zero}) =>
      _TextItem(text,
          box: box,
          scale: scale,
          align: align,
          offset: offset,
          boxOffset: boxOffset);
  static _Item list(List<_Item> items) => _ListItem(items);
  static _Item center(_Item item) => _CenterItem(item);
  static _Item space(double width) => _SpaceItem(width);
  static _Item arrowRight(double width) => _ArrowRightItem(width);
  static _Item arrowLeft(double width) => _ArrowLeftItem(width);
  static _Item registerBox(double width, _Item content) =>
      _RegisterBoxItem(width, content);
  static _Item point() => _PointItem();
  static _Item sqrtText(String text,
          {bool box = false, Offset offset = Offset.zero}) =>
      _SqrtTextItem(text, box: box, offset: offset);
  static _Item carry() =>
      registerBox(2.1, text('c', scale: 0.72, offset: const Offset(.62, -.08)));
}

/// A table on the back panel that scales with the screen size.
///
/// A bit of reinventing the wheel here, but Flutter's built-in widgets
/// aren't designed to scale the content with the screen size.  If you
/// try to use them that way, you end up fighting the framework, and
/// re-inventing a table good enough for the back panel is a lot easier!
///
class _Table extends StatelessWidget {
  final List<_Row> rows;
  final double widthCM;

  const _Table(this.widthCM, this.rows);

  static const double thickLineWidth = 0.65; // mm
  static const double thinLineWidth = 0.3; // mm

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _TablePainter(this));
}

class _TablePainter extends CustomPainter {
  final _Table table;
  final List<double> columnWidths;

  final Paint thickLine = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = _Table.thickLineWidth
    ..color = MainScreen.keyFrameSilver;

  final Paint thinLine = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = _Table.thinLineWidth
    ..color = MainScreen.keyFrameSilver;

  final Paint fill = Paint()
    ..style = PaintingStyle.fill
    ..color = MainScreen.keyFrameSilver;

  _TablePainter(this.table) : columnWidths = _makeColumnWidths(table.rows);

  static List<double> _makeColumnWidths(List<_Row> rows) =>
      List<double>.generate(
          rows[0].cells.length,
          (i) => rows.fold(
              0.0, (double soFar, _Row r) => max(soFar, r.cells[i].width)));

  @override
  void paint(Canvas canvas, Size size) {
    // Set the scale so one "pixel" is 1mm at the real caluclator's size
    const thickW = _Table.thickLineWidth;
    const thinW = _Table.thinLineWidth;
    canvas.scale(size.width / (table.widthCM * 10));
    double width = columnWidths.fold(0.0, (double x, double e) => x + e) +
        2 * _Table.thickLineWidth +
        (thinW * (columnWidths.length - 1));
    double height = table.rows.length * _Row.heightMM + 2 * thickW - thinW;
    RRect frame = RRect.fromLTRBR(thickW / 2, thickW / 2, width - thickW / 2,
        height - thickW / 2, const Radius.circular(0.1));
    canvas.drawRRect(frame, thickLine);
    double x = thickW - thinW / 2;
    for (int c = 0; c < columnWidths.length - 1; c++) {
      x += columnWidths[c] + thinW;
      canvas.drawLine(Offset(x, 0), Offset(x, height), thinLine);
    }
    canvas.translate(0, thickW);
    for (int r = 0; r < table.rows.length - 1; r++) {
      table.rows[r].paint(canvas, this, last: false);
      canvas.translate(0, _Row.heightMM);
    }
    table.rows.last.paint(canvas, this, last: true);
  }

  @override
  bool shouldRepaint(covariant _TablePainter oldDelegate) => false;
}

class _Row {
  final List<_Cell> cells;

  _Row(this.cells);

  static const double heightMM = 3.9;

  void paint(Canvas c, _TablePainter p, {required bool last}) {
    double x = _Table.thickLineWidth;
    const double textUp = 0.20;
    c.translate(0, -textUp);
    const double bottomY = heightMM - _Table.thinLineWidth;
    Offset bottomStart = const Offset(0, bottomY);
    for (int i = 0; i < cells.length; i++) {
      final cell = cells[i];
      cell.paint(c, p, x, p.columnWidths[i]);
      if (cell.eraseBottom && !last) {
        c.drawLine(bottomStart, Offset(x + 1, bottomY), p.thinLine);
        x += p.columnWidths[i] + _Table.thinLineWidth;
        bottomStart = Offset(x - 1, bottomY);
      } else {
        x += p.columnWidths[i] + _Table.thinLineWidth;
      }
    }
    c.translate(0, textUp);
    x += _Table.thickLineWidth - _Table.thinLineWidth;
    if (!last) {
      c.drawLine(bottomStart, Offset(x, bottomY), p.thinLine);
    }
  }
}

class _Cell {
  _Item item;
  bool eraseBottom;

  _Cell(this.item, {this.eraseBottom = false});

  double get width => item.width;

  void paint(Canvas c, _TablePainter p, double x, double w) =>
      item.paint(c, p, x, w);
}

abstract class _Item {
  abstract final double width;

  void paint(Canvas c, _TablePainter p, double x, double w);
}

class _ArrowRightItem extends _Item {
  @override
  final double width;

  _ArrowRightItem(this.width);

  @override
  void paint(Canvas c, _TablePainter p, double x, double w) {
    const double y = _Row.heightMM / 2;
    const double sz = 1.1;
    if (width > 0) {
      c.drawLine(
          Offset(x, _Row.heightMM / 2), Offset(x + w - sz / 2, y), p.thinLine);
    }
    final path = Path()
      ..addPolygon([
        Offset(x + w, y),
        Offset(x + w - sz, y - sz * 1.2 / 2),
        Offset(x + w - sz, y + sz * 1.2 / 2)
      ], true);
    c.drawPath(path, p.fill);
  }
}

class _ArrowLeftItem extends _Item {
  @override
  final double width;

  _ArrowLeftItem(this.width);

  @override
  void paint(Canvas c, _TablePainter p, double x, double w) {
    const double y = _Row.heightMM / 2;
    const double sz = 1.1;
    if (width > 0) {
      c.drawLine(
          Offset(x + sz / 2, _Row.heightMM / 2), Offset(x + w, y), p.thinLine);
    }
    final path = Path()
      ..addPolygon([
        Offset(x, y),
        Offset(x + sz, y - sz * 1.2 / 2),
        Offset(x + sz, y + sz * 1.2 / 2)
      ], true);
    c.drawPath(path, p.fill);
  }
}

class _RegisterBoxItem extends _Item {
  @override
  final double width;
  _Item content;

  _RegisterBoxItem(this.width, this.content);

  @override
  void paint(Canvas c, _TablePainter p, double x, double w) {
    const double y = _Row.heightMM / 2;
    const double sz = 1.9;
    c.drawRect(Rect.fromLTWH(x, y - sz / 2, width, sz), p.thinLine);
    content.paint(c, p, x, w);
  }
}

class _PointItem extends _Item {
  _PointItem();

  @override
  double get width => 0;

  static const radius = 0.5;

  @override
  void paint(Canvas c, _TablePainter p, double x, double w) {
    const double y = _Row.heightMM / 2;
    c.drawCircle(Offset(x, y), radius, p.fill);
  }
}

class _CustomItem extends _Item {
  @override
  final double width;
  final void Function(Canvas, _TablePainter) painter;

  _CustomItem(this.width, this.painter);

  @override
  void paint(Canvas c, _TablePainter p, double x, double w) {
    c.translate(x, 0);
    painter(c, p);
    c.translate(-x, 0);
  }
}

class _SpaceItem extends _Item {
  @override
  final double width;

  _SpaceItem(this.width);

  @override
  void paint(Canvas c, _TablePainter p, double x, double w) {}
}

class _CenterItem extends _Item {
  final _Item item;

  _CenterItem(this.item);

  @override
  double get width => item.width;

  @override
  void paint(Canvas c, _TablePainter p, double x, double w) =>
      item.paint(c, p, x + (w - item.width) / 2, item.width);
}

class _ListItem extends _Item {
  final List<_Item> items;

  _ListItem(this.items);

  @override
  double get width => items.fold(0, (sum, item) => sum + item.width);

  @override
  void paint(Canvas c, _TablePainter p, double x, double w) {
    for (_Item item in items) {
      item.paint(c, p, x, item.width);
      x += item.width;
    }
  }
}

class _TextItem extends _Item {
  final TextPainter painter;
  final bool box;
  // We scale the font and the width by scale, but not the height
  final double scale;
  final Offset offset;
  final Offset boxOffset;
  @override
  final double width;

  _TextItem._p(this.painter, this.box, this.scale, this.width, this.offset,
      this.boxOffset);

  factory _TextItem(String text,
      {bool box = false,
      double scale = 1,
      TextAlign align = TextAlign.left,
      Offset offset = Offset.zero,
      Offset boxOffset = Offset.zero}) {
    final painter = TextPainter(
        text: TextSpan(style: style, text: text),
        textAlign: align,
        textDirection: TextDirection.ltr);
    painter.layout();
    var width = (painter.width) * scale;
    if (text == 'SR' || text == 'RR') {
      width += 0.2; // Bug in font with hairline space, I think
    }
    return _TextItem._p(painter, box, scale, width, offset, boxOffset);
  }

  static const style = TextStyle(
      color: MainScreen.keyFrameSilver,
      fontSize: _Row.heightMM * 0.72,
      fontFamily: 'KeyLabelFont',
      fontWeight: FontWeight.normal);

  @override
  void paint(Canvas c, _TablePainter p, double x, double w) {
    if (scale != 1.0) {
      c.save();
      c.translate(0, _Row.heightMM * (1.0 - scale) / 2);
      c.scale(scale);
    }
    painter.layout(minWidth: w / scale);
    painter.paint(c, Offset(offset.dx + x / scale, -0.15 + offset.dy));
    if (scale != 1.0) {
      c.restore();
    }
    if (box) {
      c.drawRect(
          Rect.fromLTWH(
              x + boxOffset.dx,
              _Row.heightMM * 0.1 + _Table.thinLineWidth + boxOffset.dy,
              width,
              _Row.heightMM * 0.80 - _Table.thinLineWidth * 2),
          p.thinLine);
    }
  }
}

class _SqrtTextItem extends _TextItem {
  _SqrtTextItem._p(
      TextPainter painter, bool box, double scale, double width, Offset offset)
      : super._p(painter, box, scale, width, offset, Offset.zero);

  factory _SqrtTextItem(String text,
      {bool box = false, Offset offset = Offset.zero}) {
    final init = _TextItem(text, scale: 0.75, box: box, offset: offset);
    return _SqrtTextItem._p(
        init.painter, init.box, init.scale, init.width, init.offset);
  }

  @override
  double get width => super.width + 0.6;

  @override
  void paint(Canvas c, _TablePainter p, double x, double w) {
    super.paint(c, p, x, w);
    // Extend the line on the top of the square root symbol
    TextSpan span = TextSpan(style: painter.text!.style, text: '\u203E');
    TextPainter tp = TextPainter(
        text: span,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr);
    tp.layout();
    c.save();
    c.scale(0.75);
    tp.paint(c, Offset(offset.dx + x / 0.75 + 1.35, 0.32 + offset.dy));
    tp.paint(c, Offset(offset.dx + (x + width - 2.2) / 0.75, 0.32 + offset.dy));
    c.restore();
  }
}
