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
library view.back_panel;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:jovial_svg/jovial_svg.dart';
import 'main_screen.dart';

import '../generic_main.dart';

abstract class BackPanel extends OrientedScreen {
  BackPanel({super.key});

  double get thickLineWidth => 0.65; // mm
  double get thinLineWidth => 0.3; // mm
  double get rowHeightMM => 3.9;
  double get fontSize => rowHeightMM * 0.72;
  double get textUp => rowHeightMM * 0.0513;
  double get arrowUp => 0.0;

  late final Paint thickLine = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = thickLineWidth
    ..strokeJoin = StrokeJoin.round
    ..color = MainScreen.keyFrameSilver;

  late final Paint thinLine = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = thinLineWidth
    ..color = MainScreen.keyFrameSilver;

  @override
  Widget buildPortrait(BuildContext context, final ScreenPositioner screen) {
    return GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
            alignment: Alignment.center,
            color: MainScreen.deadZoneColor,
            child: AspectRatio(
                aspectRatio: screen.width / screen.height,
                child: buildBackPanelPortrait(context, screen))));
  }

  Widget buildBackPanelPortrait(
      BuildContext context, final ScreenPositioner screen);

  @override
  Widget buildLandscape(BuildContext context, final ScreenPositioner screen) {
    return GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
            alignment: Alignment.center,
            color: MainScreen.deadZoneColor,
            child: AspectRatio(
                aspectRatio: screen.width / screen.height,
                child: buildBackPanelLandscape(context, screen))));
  }

  Widget buildBackPanelLandscape(
      BuildContext context, final ScreenPositioner screen);

  @protected
  Widget table(double widthCM, List<BPRow> rows,
          {bool drawLines = true, bool? drawVerticalLines}) =>
      BPTable(widthCM, rows, drawLines, drawVerticalLines ?? drawLines, this);

  @protected
  final TextAlign bpCenter = TextAlign.center;

  @protected
  final TextAlign bpRight = TextAlign.right;

  @protected
  BPRow row(List<BPCell> cells) => BPRow(cells, this);

  @protected
  BPCell cell(BPItem item) => BPCell(item);

  @protected
  BPCell cellEB(BPItem item) => BPCell(item, eraseBottom: true);

  @protected
  BPItem text(String text,
          {bool box = false,
          double scale = 1,
          TextAlign align = TextAlign.left,
          Offset offset = Offset.zero,
          Offset boxOffset = Offset.zero}) =>
      _TextItem(text, this,
          box: box,
          scale: scale,
          align: align,
          offset: offset,
          boxOffset: boxOffset);
  @protected
  BPItem italicText(String text,
          {bool box = false,
          double scale = 1,
          TextAlign align = TextAlign.left,
          Offset offset = Offset.zero,
          Offset boxOffset = Offset.zero}) =>
      _TextItem(text, this,
          box: box,
          scale: scale,
          align: align,
          offset: offset,
          boxOffset: boxOffset,
          fontStyle: FontStyle.italic);
  BPItem subText(String t) =>
      text(t, scale: 0.7, offset: Offset(0, 0.25 * rowHeightMM));
  BPItem supText(String t) =>
      text(t, scale: 0.7, offset: Offset(0, -0.25 * rowHeightMM));
  BPItem list(List<BPItem> items) => _ListItem(items);
  BPItem superimpose(List<BPItem> items) => _SuperimposeItem(items);
  BPItem center(BPItem item) => _CenterItem(item);
  BPItem space(double width) => _SpaceItem(width);
  BPItem arrowRight(double width) => _ArrowRightItem(width, this);
  BPItem arrowLeft(double width) => _ArrowLeftItem(width, this);
  BPItem registerBox(double width, BPItem content) =>
      _RegisterBoxItem(width, content, this);
  BPItem point() => _PointItem(this);
  BPItem sqrtText(String text,
          {bool box = false,
          Offset boxOffset = Offset.zero,
          Offset offset = Offset.zero}) =>
      _SqrtTextItem(text, this, box: box, boxOffset: boxOffset, offset: offset);
  BPItem carry() =>
      registerBox(2.1, text('c', scale: 0.72, offset: const Offset(.62, -.08)));
  Widget tryzub(double width) => ScalableImageWidget(si: Jrpn.tryzub);
}

/// A table on the back panel that scales with the screen size.
///
/// A bit of reinventing the wheel here, but Flutter's built-in widgets
/// aren't designed to scale the content with the screen size.  If you
/// try to use them that way, you end up fighting the framework, and
/// re-inventing a table good enough for the back panel is a lot easier!
///
class BPTable extends StatelessWidget {
  final List<BPRow> rows;
  final double widthCM;
  final BackPanel panel;
  final bool drawHorizontalLines;
  final bool drawVerticalLines;

  const BPTable(this.widthCM, this.rows, this.drawHorizontalLines,
      this.drawVerticalLines, this.panel,
      {super.key});

  double get thickLineWidth => panel.thickLineWidth;
  double get thinLineWidth => panel.thinLineWidth;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: BPTablePainter(this));
}

abstract class BPItemPainter extends CustomPainter {
  final BackPanel panel;
  late final Paint thickLine = panel.thickLine;
  late final Paint thinLine = panel.thinLine;
  Paint get fill => _fill;
  static final Paint _fill = Paint()
    ..style = PaintingStyle.fill
    ..color = MainScreen.keyFrameSilver;

  BPItemPainter(this.panel);
}

class BPTablePainter extends BPItemPainter {
  final BPTable table;
  final List<double> columnWidths;

  BPTablePainter(this.table)
      : columnWidths = _makeColumnWidths(table.rows),
        super(table.panel);

  static List<double> _makeColumnWidths(List<BPRow> rows) =>
      List<double>.generate(
          rows[0].cells.length,
          (i) => rows.fold(
              0.0, (double soFar, BPRow r) => max(soFar, r.cells[i].width)));

  void drawOutline(Canvas canvas, double width, double height) {
    final thickW = table.thickLineWidth;
    RRect frame = RRect.fromLTRBR(thickW / 2, thickW / 2, width - thickW / 2,
        height - thickW / 2, const Radius.circular(0.1));
    canvas.drawRRect(frame, thickLine);
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Set the scale so one "pixel" is 1mm at the real caluclator's size
    final thickW = table.thickLineWidth;
    final thinW = table.thinLineWidth;
    final heightMM = table.panel.rowHeightMM;
    final drawLines = table.drawHorizontalLines;
    canvas.scale(size.width / (table.widthCM * 10));
    double width = columnWidths.fold(0.0, (double x, double e) => x + e) +
        2 * thickW +
        (thinW * (columnWidths.length - 1));
    double height = table.rows.length * heightMM + 2 * thickW - thinW;
    drawOutline(canvas, width, height);
    double x = thickW - thinW / 2;
    if (table.drawVerticalLines) {
      for (int c = 0; c < columnWidths.length - 1; c++) {
        x += columnWidths[c] + thinW;
        paintVerticalLine(canvas, x, height, c);
      }
    }
    canvas.save();
    canvas.translate(0, thickW);
    for (int r = 0; r < table.rows.length - 1; r++) {
      table.rows[r].paint(canvas, this, drawLine: drawLines || r == 0);
      canvas.translate(0, heightMM);
    }
    table.rows.last.paint(canvas, this, drawLine: false);
    canvas.restore();
  }

  void paintVerticalLine(Canvas canvas, double x, double height, int c) {
    canvas.drawLine(Offset(x, 0), Offset(x, height), thinLine);
  }

  @override
  bool shouldRepaint(covariant BPTablePainter oldDelegate) => false;
}

class BPRow {
  final List<BPCell> cells;
  final BackPanel panel;

  BPRow(this.cells, this.panel);

  double get heightMM => panel.rowHeightMM;

  bool get drawLastTwoColumnsBottomLine => true;

  void paint(Canvas c, BPTablePainter p, {required bool drawLine}) {
    double x = panel.thickLineWidth;
    final double textUp = panel.textUp;
    c.translate(0, -textUp);
    final double bottomY = heightMM - panel.thinLineWidth;
    Offset bottomStart = Offset(0, bottomY);
    for (int i = 0; i < cells.length; i++) {
      final cell = cells[i];
      cell.paint(c, p, x, p.columnWidths[i]);
      if (cell.eraseBottom && drawLine) {
        c.drawLine(bottomStart, Offset(x + 1, bottomY), p.thinLine);
        x += p.columnWidths[i] + panel.thinLineWidth;
        bottomStart = Offset(x - 1, bottomY);
      } else {
        x += p.columnWidths[i] + panel.thinLineWidth;
      }
    }
    if (!drawLastTwoColumnsBottomLine) {
      x -= p.columnWidths[cells.length - 1] +
          p.columnWidths[cells.length - 2] +
          2 * panel.thinLineWidth;
    } else {
      x += panel.thickLineWidth - panel.thinLineWidth;
    }
    c.translate(0, textUp);
    if (drawLine) {
      c.drawLine(bottomStart, Offset(x, bottomY), p.thinLine);
    }
  }
}

class BPCell {
  BPItem item;
  bool eraseBottom;

  BPCell(this.item, {this.eraseBottom = false});

  double get width => item.width;

  void paint(Canvas c, BPItemPainter p, double x, double w) =>
      item.paint(c, p, x, w);
}

abstract class BPItem {
  abstract final double width;
  TextAlign get align => TextAlign.left;

  void paint(Canvas c, BPItemPainter p, double x, double w);
}

class _ArrowRightItem extends BPItem {
  @override
  final double width;
  final BackPanel panel;

  _ArrowRightItem(this.width, this.panel);

  @override
  void paint(Canvas c, BPItemPainter p, double x, double w) {
    final rowHeightMM = panel.rowHeightMM;
    final double y = rowHeightMM / 2 - panel.arrowUp;
    const double sz = 1.1;
    if (width > 0) {
      c.drawLine(Offset(x, y), Offset(x + w - sz / 2, y), p.thinLine);
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

class _ArrowLeftItem extends BPItem {
  @override
  final double width;
  final BackPanel panel;

  _ArrowLeftItem(this.width, this.panel);

  @override
  void paint(Canvas c, BPItemPainter p, double x, double w) {
    final rowHeightMM = panel.rowHeightMM;
    final double y = rowHeightMM / 2;
    const double sz = 1.1;
    if (width > 0) {
      c.drawLine(
          Offset(x + sz / 2, rowHeightMM / 2), Offset(x + w, y), p.thinLine);
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

class _RegisterBoxItem extends BPItem {
  @override
  final double width;
  final BPItem content;
  final BackPanel panel;

  _RegisterBoxItem(this.width, this.content, this.panel);

  @override
  void paint(Canvas c, BPItemPainter p, double x, double w) {
    final double y = panel.rowHeightMM / 2;
    const double sz = 1.9;
    c.drawRect(Rect.fromLTWH(x, y - sz / 2, width, sz), p.thinLine);
    content.paint(c, p, x, w);
  }
}

class _PointItem extends BPItem {
  final BackPanel panel;

  _PointItem(this.panel);

  @override
  double get width => 0;

  static const radius = 0.5;

  @override
  void paint(Canvas c, BPItemPainter p, double x, double w) {
    final double y = panel.rowHeightMM / 2;
    c.drawCircle(Offset(x, y), radius, p.fill);
  }
}

class BPCustomItem extends BPItem {
  @override
  final double width;
  final void Function(Canvas, BPItemPainter) painter;

  BPCustomItem(this.width, this.painter);

  @override
  void paint(Canvas c, BPItemPainter p, double x, double w) {
    c.translate(x, 0);
    painter(c, p);
    c.translate(-x, 0);
  }
}

class _SpaceItem extends BPItem {
  @override
  final double width;

  _SpaceItem(this.width);

  @override
  void paint(Canvas c, BPItemPainter p, double x, double w) {}
}

class _CenterItem extends BPItem {
  final BPItem item;

  _CenterItem(this.item);

  @override
  double get width => item.width;

  @override
  void paint(Canvas c, BPItemPainter p, double x, double w) =>
      item.paint(c, p, x + (w - item.width) / 2, item.width);
}

class _ListItem extends BPItem {
  final List<BPItem> items;

  _ListItem(this.items);

  @override
  double get width => items.fold(0, (sum, item) => sum + item.width);

  @override
  void paint(Canvas c, BPItemPainter p, double x, double w) {
    if (items.isNotEmpty) {
      final align = items[0].align;
      if (align == TextAlign.left) {
        // do nothing
      } else if (align == TextAlign.center) {
        x += (w - width) / 2;
      } else {
        assert(align == TextAlign.right);
        x += w - width;
      }
    }
    for (BPItem item in items) {
      item.paint(c, p, x, item.width);
      x += item.width;
    }
  }
}

class _SuperimposeItem extends BPItem {
  final List<BPItem> items;

  _SuperimposeItem(this.items);

  @override
  double get width => items.fold(0, (v, item) => max(v, item.width));

  @override
  void paint(Canvas c, BPItemPainter p, double x, double w) {
    for (BPItem item in items) {
      item.paint(c, p, x, w);
    }
  }
}

class _TextItem extends BPItem {
  final TextPainter painter;
  final bool box;
  // We scale the font and the width by scale, but not the height
  final double scale;
  final Offset offset;
  final Offset boxOffset;
  final BackPanel panel;
  @override
  final double width;

  _TextItem._p(this.painter, this.panel, this.box, this.scale, this.width,
      this.offset, this.boxOffset);

  factory _TextItem(String text, BackPanel panel,
      {bool box = false,
      double scale = 1,
      TextAlign align = TextAlign.left,
      Offset offset = Offset.zero,
      Offset boxOffset = Offset.zero,
      FontStyle fontStyle = FontStyle.normal}) {
    final painter = TextPainter(
        text: TextSpan(
            style: TextStyle(
                color: MainScreen.keyFrameSilver,
                fontSize: panel.fontSize,
                fontFamily: 'KeyLabelFont',
                fontStyle: fontStyle,
                fontWeight: FontWeight.normal),
            text: text),
        textAlign: align,
        textDirection: TextDirection.ltr);
    painter.layout();
    var width = (painter.width) * scale;
    if (text == 'SR' || text == 'RR') {
      width += 0.2; // Bug in font with hairline space, I think
    }
    width += offset.dx;
    return _TextItem._p(painter, panel, box, scale, width, offset, boxOffset);
  }

  @override
  TextAlign get align => painter.textAlign;

  @override
  void paint(Canvas c, BPItemPainter p, double x, double w) {
    if (scale != 1.0) {
      c.save();
      c.translate(0, panel.rowHeightMM * (1.0 - scale) / 2);
      c.scale(scale);
    }
    painter.layout(minWidth: w / scale);
    painter.paint(c,
        Offset(offset.dx + x / scale, -0.0038 * panel.rowHeightMM + offset.dy));
    if (scale != 1.0) {
      c.restore();
    }
    if (box) {
      switch (painter.textAlign) {
        case TextAlign.center:
          x += (w - width) / 2;
          break;
        case TextAlign.right:
          x += w - width;
          break;
        default:
        // Do nothing
      }
      c.drawRect(
          Rect.fromLTWH(
              x + boxOffset.dx,
              panel.rowHeightMM * 0.1 + panel.thinLineWidth + boxOffset.dy,
              width,
              panel.rowHeightMM * 0.80 - panel.thinLineWidth * 2),
          p.thinLine);
    }
  }
}

class _SqrtTextItem extends _TextItem {
  _SqrtTextItem._p(super.painter, super.panel, super.box, super.scale,
      super.width, super.offset, super.boxOffset)
      : super._p();

  factory _SqrtTextItem(String text, BackPanel panel,
      {bool box = false,
      Offset boxOffset = Offset.zero,
      Offset offset = Offset.zero}) {
    final init = _TextItem(text, panel,
        scale: 0.75, box: box, boxOffset: boxOffset, offset: offset);
    return _SqrtTextItem._p(init.painter, panel, init.box, init.scale,
        init.width, init.offset, init.boxOffset);
  }

  @override
  double get width => super.width + 0.6;

  @override
  void paint(Canvas c, BPItemPainter p, double x, double w) {
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
