///
/// The back panel of the calculator.
///
library view.back_panel;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:jrpn/v/main_screen.dart';

abstract class BackPanel extends OrientedScreen {
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
  final TextAlign bpCenter = TextAlign.center;

  @protected
  BPRow row(List<BPCell> cells) => BPRow(cells);

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
      _TextItem(text,
          box: box,
          scale: scale,
          align: align,
          offset: offset,
          boxOffset: boxOffset);
  BPItem list(List<BPItem> items) => _ListItem(items);
  BPItem center(BPItem item) => _CenterItem(item);
  BPItem space(double width) => _SpaceItem(width);
  BPItem arrowRight(double width) => _ArrowRightItem(width);
  BPItem arrowLeft(double width) => _ArrowLeftItem(width);
  BPItem registerBox(double width, BPItem content) =>
      _RegisterBoxItem(width, content);
  BPItem point() => _PointItem();
  BPItem sqrtText(String text,
          {bool box = false, Offset offset = Offset.zero}) =>
      _SqrtTextItem(text, box: box, offset: offset);
  BPItem carry() =>
      registerBox(2.1, text('c', scale: 0.72, offset: const Offset(.62, -.08)));
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

  const BPTable(this.widthCM, this.rows, {Key? key}) : super(key: key);

  static const double thickLineWidth = 0.65; // mm
  static const double thinLineWidth = 0.3; // mm

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: BPTablePainter(this));
}

class BPTablePainter extends CustomPainter {
  final BPTable table;
  final List<double> columnWidths;

  final Paint thickLine = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = BPTable.thickLineWidth
    ..color = MainScreen.keyFrameSilver;

  final Paint thinLine = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = BPTable.thinLineWidth
    ..color = MainScreen.keyFrameSilver;

  final Paint fill = Paint()
    ..style = PaintingStyle.fill
    ..color = MainScreen.keyFrameSilver;

  BPTablePainter(this.table) : columnWidths = _makeColumnWidths(table.rows);

  static List<double> _makeColumnWidths(List<BPRow> rows) =>
      List<double>.generate(
          rows[0].cells.length,
          (i) => rows.fold(
              0.0, (double soFar, BPRow r) => max(soFar, r.cells[i].width)));

  @override
  void paint(Canvas canvas, Size size) {
    // Set the scale so one "pixel" is 1mm at the real caluclator's size
    const thickW = BPTable.thickLineWidth;
    const thinW = BPTable.thinLineWidth;
    canvas.scale(size.width / (table.widthCM * 10));
    double width = columnWidths.fold(0.0, (double x, double e) => x + e) +
        2 * BPTable.thickLineWidth +
        (thinW * (columnWidths.length - 1));
    double height = table.rows.length * BPRow.heightMM + 2 * thickW - thinW;
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
      canvas.translate(0, BPRow.heightMM);
    }
    table.rows.last.paint(canvas, this, last: true);
  }

  @override
  bool shouldRepaint(covariant BPTablePainter oldDelegate) => false;
}

class BPRow {
  final List<BPCell> cells;

  BPRow(this.cells);

  static const double heightMM = 3.9;

  void paint(Canvas c, BPTablePainter p, {required bool last}) {
    double x = BPTable.thickLineWidth;
    const double textUp = 0.20;
    c.translate(0, -textUp);
    const double bottomY = heightMM - BPTable.thinLineWidth;
    Offset bottomStart = const Offset(0, bottomY);
    for (int i = 0; i < cells.length; i++) {
      final cell = cells[i];
      cell.paint(c, p, x, p.columnWidths[i]);
      if (cell.eraseBottom && !last) {
        c.drawLine(bottomStart, Offset(x + 1, bottomY), p.thinLine);
        x += p.columnWidths[i] + BPTable.thinLineWidth;
        bottomStart = Offset(x - 1, bottomY);
      } else {
        x += p.columnWidths[i] + BPTable.thinLineWidth;
      }
    }
    c.translate(0, textUp);
    x += BPTable.thickLineWidth - BPTable.thinLineWidth;
    if (!last) {
      c.drawLine(bottomStart, Offset(x, bottomY), p.thinLine);
    }
  }
}

class BPCell {
  BPItem item;
  bool eraseBottom;

  BPCell(this.item, {this.eraseBottom = false});

  double get width => item.width;

  void paint(Canvas c, BPTablePainter p, double x, double w) =>
      item.paint(c, p, x, w);
}

abstract class BPItem {
  abstract final double width;

  void paint(Canvas c, BPTablePainter p, double x, double w);
}

class _ArrowRightItem extends BPItem {
  @override
  final double width;

  _ArrowRightItem(this.width);

  @override
  void paint(Canvas c, BPTablePainter p, double x, double w) {
    const double y = BPRow.heightMM / 2;
    const double sz = 1.1;
    if (width > 0) {
      c.drawLine(
          Offset(x, BPRow.heightMM / 2), Offset(x + w - sz / 2, y), p.thinLine);
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

  _ArrowLeftItem(this.width);

  @override
  void paint(Canvas c, BPTablePainter p, double x, double w) {
    const double y = BPRow.heightMM / 2;
    const double sz = 1.1;
    if (width > 0) {
      c.drawLine(
          Offset(x + sz / 2, BPRow.heightMM / 2), Offset(x + w, y), p.thinLine);
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
  BPItem content;

  _RegisterBoxItem(this.width, this.content);

  @override
  void paint(Canvas c, BPTablePainter p, double x, double w) {
    const double y = BPRow.heightMM / 2;
    const double sz = 1.9;
    c.drawRect(Rect.fromLTWH(x, y - sz / 2, width, sz), p.thinLine);
    content.paint(c, p, x, w);
  }
}

class _PointItem extends BPItem {
  _PointItem();

  @override
  double get width => 0;

  static const radius = 0.5;

  @override
  void paint(Canvas c, BPTablePainter p, double x, double w) {
    const double y = BPRow.heightMM / 2;
    c.drawCircle(Offset(x, y), radius, p.fill);
  }
}

class BPCustomItem extends BPItem {
  @override
  final double width;
  final void Function(Canvas, BPTablePainter) painter;

  BPCustomItem(this.width, this.painter);

  @override
  void paint(Canvas c, BPTablePainter p, double x, double w) {
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
  void paint(Canvas c, BPTablePainter p, double x, double w) {}
}

class _CenterItem extends BPItem {
  final BPItem item;

  _CenterItem(this.item);

  @override
  double get width => item.width;

  @override
  void paint(Canvas c, BPTablePainter p, double x, double w) =>
      item.paint(c, p, x + (w - item.width) / 2, item.width);
}

class _ListItem extends BPItem {
  final List<BPItem> items;

  _ListItem(this.items);

  @override
  double get width => items.fold(0, (sum, item) => sum + item.width);

  @override
  void paint(Canvas c, BPTablePainter p, double x, double w) {
    for (BPItem item in items) {
      item.paint(c, p, x, item.width);
      x += item.width;
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
      fontSize: BPRow.heightMM * 0.72,
      fontFamily: 'KeyLabelFont',
      fontWeight: FontWeight.normal);

  @override
  void paint(Canvas c, BPTablePainter p, double x, double w) {
    if (scale != 1.0) {
      c.save();
      c.translate(0, BPRow.heightMM * (1.0 - scale) / 2);
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
              BPRow.heightMM * 0.1 + BPTable.thinLineWidth + boxOffset.dy,
              width,
              BPRow.heightMM * 0.80 - BPTable.thinLineWidth * 2),
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
  void paint(Canvas c, BPTablePainter p, double x, double w) {
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
