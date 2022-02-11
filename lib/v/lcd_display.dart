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
/// Widget to draw the LCD Display, using a `CustomPainter` and
/// direct drawing commands.  The main eleven-digit display doesn't
/// use a font; the individual segments are drawn.
///
/// The structure of this module is pretty straightforward:
/// <img src="dartdoc/view.lcd_display/main.svg"
///     style="align: center; width: 90%;"/>
/// <br>
/// [LcdDisplay] is the main widget.  It uses Flutter's
/// `CustomPainter` to do direct drawing of the different visual elements.
/// The most interesting part of that is the 7 segment digits, which are drawn
/// with [Digit].  There's a Digit instance for each character of our
/// alphabet, which includes the digits from 0 to f, as well as some other
/// characters used by the 16C, e.g. for the flashing "running" message.  A
/// [Digit] is comprised of some number of [Segments], each of which is a
/// Flutter `Path`, one for each of the seven segments, plus the decimal point
/// and the tail that completes a comma.
///
/// Drawing a [Digit] involves some trig, like this:
/// <img src="dartdoc/view.lcd_display/digit_1.jpg"
///     style="align: center; width: 75%;"/>
/// <br>
/// (More is available under [Segments].)
library view.lcd_display;

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../m/model.dart';

// See the library comments, above!  (Android Studio  hides them by default.)

/// A widget that looks like an LCD display.  It uses Flutter's `CustomPainter`
/// to directly draw the visual elements, notably using 7-segment [Digit]
/// instances.  LcdDisplay listens to events from [Model.display].
class LcdDisplay extends StatefulWidget {
  final Model model;
  final Future<void> Function(BuildContext, Offset) showMenu;
  static const double heightTweak = 0.90;

  const LcdDisplay(this.model, this.showMenu, {Key? key}) : super(key: key);

  @override
  _LcdDisplayState createState() => _LcdDisplayState();
}

class _LcdDisplayState extends State<LcdDisplay> {
  LcdContents _contents = LcdContents.blank();
  Offset _tapOffset = const Offset(0, 0);

  @override
  void initState() {
    super.initState();
    widget.model.display.addListener(_update);
  }

  @override
  void dispose() {
    widget.model.display.removeListener(_update);
    super.dispose();
  }

  void _update(final LcdContents next) {
    setState(() {
      _contents = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
        message: 'Copy or Paste Number',
        child: GestureDetector(
            onSecondaryTapDown: (TapDownDetails details) => // Right mouse
                _tapOffset = details.globalPosition,
            onSecondaryTap: () =>
                unawaited(widget.showMenu(context, _tapOffset)),
            onTapDown: (TapDownDetails details) =>
                _tapOffset = details.globalPosition,
            onTap: () => unawaited(widget.showMenu(context, _tapOffset)),
            child: CustomPaint(painter: _DisplayPainter(_contents))));
  }
}

class _DisplayPainter extends CustomPainter {
  LcdContents contents;

  _DisplayPainter(this.contents);

  static const double heightTweak = LcdDisplay.heightTweak;

  static double _gradWidth = -1;

  @override
  void paint(Canvas canvas, Size size) {
    final _lcdFrame = Paint()
      ..color = const Color(0xff908d88)
      ..style = PaintingStyle.fill;
    final _outline = Paint()
      ..color = Color(0xff000000 | (0x908d88 * 0.75).floor())
      ..style = PaintingStyle.fill;
    final _lcdBase = Paint()
      ..color = const Color(0xff979980) // that's argb
      ..style = PaintingStyle.fill;
    // Note that, by default, we are not clipped to our size
    final outlineW = size.width / 20;
    final outlineH = size.height / 20;
    final outlineR = Radius.circular(size.height / 15);
    canvas.drawRRect(
        RRect.fromLTRBR(0, 0, size.width, size.height, outlineR), _outline);
    final t = size.height / 250;
    canvas.drawRRect(
        RRect.fromLTRBR(
            t, t, size.width - 2 * t, size.height - 2 * t, outlineR),
        _lcdFrame);
    canvas.drawRRect(
        RRect.fromLTRBR(outlineW, outlineH, size.width - outlineW,
            size.height - outlineH, outlineR),
        _lcdBase);

    if (contents.blank) {
      return;
    }

    // Annunciators:

    final TextStyle aStyle = TextStyle(
        fontSize: size.height / heightTweak / 7,
        fontFamily: 'KeyLabelFont',
        color: Colors.black);

    const double annY = 0.82 * heightTweak;

    if (!contents.hideComplement && contents.sign.annunciatorText != '') {
      final String text = contents.sign.annunciatorText;
      final TextSpan span = TextSpan(style: aStyle, text: text);
      final TextPainter tp = TextPainter(
          text: span,
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr);
      tp.layout();
      tp.paint(canvas, Offset(size.width * 0.09, size.height * annY));
    }
    if (contents.wordSize != null) {
      final String text = contents.wordSize.toString();
      final TextSpan span = TextSpan(style: aStyle, text: text);
      final TextPainter tp = TextPainter(
          text: span,
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr);
      tp.layout();
      tp.paint(canvas, Offset(size.width * 0.16, size.height * annY));
    }
    if (contents.shift.name != '') {
      final TextSpan span = TextSpan(style: aStyle, text: contents.shift.name);
      final TextPainter tp = TextPainter(
          text: span,
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr);
      tp.layout();
      tp.paint(
          canvas,
          Offset(size.width * (contents.shift.offset ? 0.33 : 0.3),
              size.height * annY));
    }
    if (contents.extraShift != null) {
      final TextSpan span =
          TextSpan(style: aStyle, text: contents.extraShift!.name);
      final TextPainter tp = TextPainter(
          text: span,
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr);
      tp.layout();
      tp.paint(
          canvas,
          Offset(size.width * (contents.extraShift!.offset ? 0.33 : 0.3),
              size.height * annY));
    }
    if (contents.cFlag) {
      final TextSpan span = TextSpan(style: aStyle, text: 'C');
      final TextPainter tp = TextPainter(
          text: span,
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr);
      tp.layout();
      tp.paint(canvas, Offset(size.width * 0.6, size.height * annY));
    }
    if (contents.gFlag) {
      final TextSpan span = TextSpan(style: aStyle, text: 'G');
      final TextPainter tp = TextPainter(
          text: span,
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr);
      tp.layout();
      tp.paint(canvas, Offset(size.width * 0.65, size.height * annY));
    }
    final trig = contents.trigMode;
    if (trig.label != null) {
      if (_gradWidth == -1) {
        final TextSpan span = TextSpan(style: aStyle, text: 'GRAD');
        final TextPainter tp = TextPainter(
            text: span,
            textAlign: TextAlign.center,
            textDirection: TextDirection.ltr);
        tp.layout();
        _gradWidth = tp.width;
      }
      final TextSpan span = TextSpan(style: aStyle, text: trig.label);
      final TextPainter tp = TextPainter(
          text: span,
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr);
      tp.layout();
      tp.paint(
          canvas,
          Offset(
              _gradWidth - tp.width + size.width * 0.52, size.height * annY));
    }
    if (contents.complexFlag) {
      final TextSpan span = TextSpan(style: aStyle, text: 'C');
      final TextPainter tp = TextPainter(
          text: span,
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr);
      tp.layout();
      tp.paint(canvas, Offset(size.width * 0.78, size.height * annY));
    }
    if (contents.prgmFlag) {
      final TextSpan span = TextSpan(style: aStyle, text: 'PRGM');
      final TextPainter tp = TextPainter(
          text: span,
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr);
      tp.layout();
      tp.paint(canvas, Offset(size.width * 0.82, size.height * annY));
    }

    // Digits:

    canvas.save();
    // The rest of the space we have to work with:
    final double width = size.width - 2 * outlineW;
    double y = size.height * 0.20 * heightTweak;
    final double digitW = width / 11.5;
    double x = outlineW + digitW / 3;
    canvas.translate(x, y);
    canvas.scale(width / (Segments.instance.width * 11.5));
    final digits = (contents.euroComma) ? Digit.euroDigits : Digit.digits;
    Digit.paint(canvas, contents.mainText, digits,
        rightJustify: contents.rightJustify);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DisplayPainter oldDelegate) {
    return !oldDelegate.contents.equivalent(contents);
  }
}

///
/// Draw a digit, by drawing the individual [Segments].
///
class Digit {
  final List<Path> segments;
  final bool noWidth;

  Digit._p(this.segments, {this.noWidth = false});

  static final Segments _s = Segments.instance;

  static final Map<int, Digit> digits = {
    '0'.codeUnitAt(0): Digit._p(
        [_s.top, _s.upL, _s.upR, _s.lowL, _s.lowR, _s.bot]), //         0
    '1'.codeUnitAt(0): Digit._p([_s.upR, _s.lowR]),
    '2'.codeUnitAt(0): Digit._p([_s.top, _s.upR, _s.mid, _s.lowL, _s.bot]),
    '3'.codeUnitAt(0): Digit._p([_s.top, _s.upR, _s.mid, _s.lowR, _s.bot]),
    '4'.codeUnitAt(0): Digit._p([_s.upL, _s.upR, _s.mid, _s.lowR]),
    '5'.codeUnitAt(0): Digit._p([_s.top, _s.upL, _s.mid, _s.lowR, _s.bot]),
    '6'.codeUnitAt(0):
        Digit._p([_s.top, _s.upL, _s.mid, _s.lowL, _s.lowR, _s.bot]),
    '7'.codeUnitAt(0): Digit._p([_s.top, _s.upR, _s.lowR]),
    '8'.codeUnitAt(0):
        Digit._p([_s.top, _s.upL, _s.upR, _s.mid, _s.lowL, _s.lowR, _s.bot]),
    '9'.codeUnitAt(0):
        Digit._p([_s.top, _s.upL, _s.upR, _s.mid, _s.lowR, _s.bot]),
    'a'.codeUnitAt(0):
        Digit._p([_s.top, _s.upL, _s.upR, _s.mid, _s.lowL, _s.lowR]),
    'b'.codeUnitAt(0): Digit._p([_s.upL, _s.mid, _s.lowL, _s.lowR, _s.bot]),
    'c'.codeUnitAt(0): Digit._p([_s.mid, _s.lowL, _s.bot]),
    'd'.codeUnitAt(0): Digit._p([_s.upR, _s.mid, _s.lowL, _s.lowR, _s.bot]),
    'e'.codeUnitAt(0): Digit._p([_s.top, _s.upL, _s.mid, _s.lowL, _s.bot]),
    'f'.codeUnitAt(0): Digit._p([_s.top, _s.upL, _s.mid, _s.lowL]),
    'G'.codeUnitAt(0):
        Digit._p([_s.top, _s.upL, _s.upR, _s.mid, _s.lowR, _s.bot]),
    'h'.codeUnitAt(0): Digit._p([_s.upL, _s.mid, _s.lowL, _s.lowR]),
    'I'.codeUnitAt(0): Digit._p([_s.upR]),
    'i'.codeUnitAt(0): Digit._p([_s.lowR]),
    'N'.codeUnitAt(0): Digit._p([_s.top, _s.upL, _s.upR]),
    'n'.codeUnitAt(0): Digit._p([_s.mid, _s.lowL, _s.lowR]),
    'o'.codeUnitAt(0): Digit._p([_s.mid, _s.lowL, _s.lowR, _s.bot]),
    'p'.codeUnitAt(0): Digit._p([_s.top, _s.upL, _s.upR, _s.mid, _s.lowL]),
    'R'.codeUnitAt(0): Digit._p([_s.top, _s.upL]),
    'r'.codeUnitAt(0): Digit._p([_s.mid, _s.lowL]),
    'U'.codeUnitAt(0): Digit._p([_s.upL, _s.lowL, _s.bot, _s.lowR, _s.upR]),
    'u'.codeUnitAt(0): Digit._p([_s.upL, _s.mid, _s.upR]),
    '.'.codeUnitAt(0): Digit._p([_s.decimalPoint], noWidth: true),
    ','.codeUnitAt(0): Digit._p([_s.decimalPoint, _s.commaTail], noWidth: true),
    'E'.codeUnitAt(0): Digit._p([], noWidth: true), // For exponent
    '-'.codeUnitAt(0): Digit._p([_s.mid]),
    '+'.codeUnitAt(0): Digit._p([]), // Only occurs in exponent
    '?'.codeUnitAt(0): Digit._p([_s.top, _s.upR, _s.mid, _s.lowL]),
    ' '.codeUnitAt(0): Digit._p([]),
  };

  static final Map<int, Digit> euroDigits = Map.from(digits)
    ..[','.codeUnitAt(0)] = digits['.'.codeUnitAt(0)]!
    ..['.'.codeUnitAt(0)] = digits[','.codeUnitAt(0)]!;

  static final Paint _paint = Paint()
    ..color = Colors.black
    ..style = PaintingStyle.fill;

  static void paint(Canvas c, String message, Map<int, Digit> digits,
      {required bool rightJustify}) {
    final Iterable<Digit> values = message.codeUnits.map(((ch) {
      final d = digits[ch];
      assert(d != null, 'No LCD character for ${String.fromCharCode(ch)} in $message');
      return d!;
    }));
    int width =
        values.fold(0, (int count, Digit d) => d.noWidth ? count : count + 1);
    if (rightJustify && width <= 11) {
      // Go one to the left of the first digit
      c.translate(_s.width * (10 - width), 0);
    } else {
      c.translate(0, Segments.h / 2);
      final double sf = 11.0 / max(width, 11);
      c.scale(sf);
      c.translate(-_s.width, -Segments.h / 2);
    }
    for (final Digit d in values) {
      if (!d.noWidth) {
        c.translate(_s.width, 0);
      }
      for (final Path p in d.segments) {
        c.drawPath(p, _paint);
      }
    }
  }
}

///
/// Singleton to do the math of where tho display the digit segments.
/// These segments are based on a 72-pixel high digit whose upper-left hand
/// corner is at 0,0.  it is expected that the client will scale and translate
/// the Canvas accordingly.
///
/// This involves some trig.  The variable names are taken from the following
/// drawings:
/// <br>
/// <br>
/// <img src="dartdoc/view.lcd_display/digit_1.jpg" style="width: 100%;"/>
/// <br>
/// <br>
/// <img src="dartdoc/view.lcd_display/digit_2.jpg" style="width: 100%"/>
/// <br>
/// <br>
/// A real LCD doesn't have perfectly sharp corners that meet with no
/// gap, so we add a rounded corner:
/// <br>
/// <br>
/// <img src="dartdoc/view.lcd_display/add_corner.jpg" style="width: 100%"/>
/// <br>
///
class Segments {
  // This class could be private, but it's nice for it to show up in the
  // dartdocs.
  static final instance = Segments._private();

  // The seven segments:
  late final Path upL, lowL, top, mid, bot, upR, lowR;

  late final Path decimalPoint;

  /// Add this to decimalPoint
  late final Path commaTail;

  /// The width of a segment, including space on the right
  late final double width;

  static const double h = 72;

  Segments._private() {
    const deg45 = pi / 4;
    const double w = 44;
    const double t = 12;
    const double slant = 5 * pi / 180.0; // 5 degrees

    // The 14 points, 6 on the outer edge, and 8 on the inner edge.
    // See dartdoc/view.lcd_display/digit_1.jpg and
    // dartdoc/view.lcd_display/digit_2.jpg to know what the variable names
    // mean.
    final double ax, ay, bx, by, apx, apy, bpx, bpy;
    final double cx, cy, dx, dy, cpx, cpy, cppx, cppy, dpx, dpy, dppx, dppy;
    final double ex, ey, fx, fy, epx, epy, fpx, fpy;

    // It would be nice if more of this could be const, but the Dart team hasn't
    // gotten around to implementing const functions.
    // https://github.com/dart-lang/language/issues/1048
    ax = h * tan(slant);
    bx = ax + w;
    ay = by = 0;
    apx = ax + t / tan(deg45 + slant / 2);
    apy = ay + t;
    bpx = bx - t / tan(deg45 - slant / 2);
    bpy = by + t;

    cx = ax / 2;
    dx = cx + w;
    cy = dy = h / 2;

    cpy = dpy = cy - t / 2;
    cppy = dppy = cy + t / 2;
    cpx = cx + t / cos(slant) + t * tan(slant) / 2;
    cppx = cx + t / cos(slant) - t * tan(slant) / 2;
    dpx = dx - t / cos(slant) + t * tan(slant) / 2;
    dppx = dx - t / cos(slant) - t * tan(slant) / 2;

    ex = 0;
    fx = w;
    ey = fy = h;
    epx = ex + t / tan(deg45 - slant / 2);
    fpx = fx - t / tan(deg45 + slant / 2);
    epy = fpy = ey - t;

    // Top segment, start with upper left corner and go clockwise
    top = Path();
    _addCorner(top, apx, apy, ax, ay, bx, by);
    _addCorner(top, ax, ay, bx, by, bpx, bpy);
    _addCorner(top, bx, by, bpx, bpy, apx, apy);
    _addCorner(top, bpx, bpy, apx, apy, ax, ay);
    top.close();

    // Upper left segment
    upL = Path();
    _addCorner(upL, cx, cy, ax, ay, apx, apy);
    _addCorner(upL, ax, ay, apx, apy, cpx, cpy);
    _addCorner(upL, apx, apy, cpx, cpy, cx, cy);
    _addCorner(upL, cpx, cpy, cx, cy, ax, ay);
    upL.close();

    // lower left segment
    lowL = Path();
    _addCorner(lowL, epx, epy, ex, ey, ex, cy);
    _addCorner(lowL, ex, ey, cx, cy, cppx, cppy);
    _addCorner(lowL, cx, cy, cppx, cppy, epx, epy);
    _addCorner(lowL, cppx, cppy, epx, epy, ex, ey);
    lowL.close();

    // bottom segment
    bot = Path();
    _addCorner(bot, fx, fy, ex, ey, epx, epy);
    _addCorner(bot, ex, ey, epx, epy, fpx, fpy);
    _addCorner(bot, epx, epy, fpx, fpy, fx, fy);
    _addCorner(bot, fpx, fpy, fx, fy, ex, ey);
    bot.close();

    // lower right segment
    lowR = Path();
    _addCorner(lowR, dx, dy, fx, fy, fpx, fpy);
    _addCorner(lowR, fx, fy, fpx, fpy, dppx, dppy);
    _addCorner(lowR, fpx, fpy, dppx, dppy, dx, dy);
    _addCorner(lowR, dppx, dppy, dx, dy, fx, fy);
    lowR.close();

    // upper right segment
    upR = Path();
    _addCorner(upR, bpx, bpy, bx, by, dx, dy);
    _addCorner(upR, bx, by, dx, dy, dpx, dpy);
    _addCorner(upR, dx, dy, dpx, dpy, bpx, bpy);
    _addCorner(upR, dpx, dpy, bpx, bpy, bx, by);
    upR.close();

    // middle segment
    mid = Path();
    _addCorner(mid, cppx, cppy, cx, cy, cpx, cpy);
    _addCorner(mid, cx, cy, cpx, cpy, dpx, dpy);
    _addCorner(mid, cpx, cpy, dpx, dpy, dx, dy);
    _addCorner(mid, dpx, dpy, dx, dy, dppx, dppy);
    _addCorner(mid, dx, dy, dppx, dppy, cppx, cppy);
    _addCorner(mid, dppx, dppy, cppx, cppy, cx, cy);
    mid.close();

    double x, y; // lower-left corner of decimal point
    final double xp, yp; // upper-left corner
    y = fy;
    x = fx + 1.0 * t;
    xp = x + t * sin(slant);
    yp = y - t * cos(slant);
    decimalPoint = Path();
    _addCorner(decimalPoint, x + t, y, x, y, xp, yp);
    _addCorner(decimalPoint, x, y, xp, yp, xp + t, yp);
    _addCorner(decimalPoint, xp, yp, xp + t, yp, x + t, y);
    _addCorner(decimalPoint, xp + t, yp, x + t, y, x, y);
    decimalPoint.close();

    final double tpx, tpy; // the point at the bottom of the triangle
    y += 0.15; // A bit more separation
    tpy = y + t * 1.58;
    tpx = x - 0.82 * t;
    commaTail = Path();
    _addCorner(commaTail, x, y, x + t * 1.35, y, tpx, tpy);
    _addCorner(commaTail, x + t * 1.35, y, tpx, tpy, x, y);
    _addCorner(commaTail, tpx, tpy, x, y, x + t * 1.35, y);
    commaTail.close();

    width = x + t + t; // To the right of right edge of decimal point
  }

  ///
  /// Add a rounded corner for the angle ABC, inscribed within the angle.
  ///
  /// <img src="dartdoc/view.lcd_display/add_corner.jpg" style="width: 100%"/>
  ///
  static void _addCorner(final Path path, final double xa, double ya, double xb,
      double yb, double xc, double yc) {
    const deg90 = pi / 2;
    const deg180 = pi;
    const double r = 2.0;
    const double s = 1.0;
    double phi = atan2(yc - yb, xc - xb);
    double theta = atan2(ya - yb, xa - xb) - phi;
    double len = (r + s) / sin(theta / 2);
    double xe = xb + len * cos(phi + theta / 2);
    double ye = yb + len * sin(phi + theta / 2);
    path.arcTo(Rect.fromLTRB(xe - r, ye - r, xe + r, ye + r),
        deg90 + phi + theta, deg180 - theta, false);
  }
}
