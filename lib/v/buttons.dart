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
/// Buttons for the keyboard.  When pressed, buttons consult the [Model] to see
/// if a shift key has been pressed, and dispatch an appropriate
/// [Operation] to the [Controller].
///
/// The overall structure is this:
/// <img src="dartdoc/view.buttons/buttons.svg" style="width: 100%;"/>
/// <br>
/// See [CalculatorButton] for more details.
library view.buttons;

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jrpn/generic_main.dart'
    show LayoutConfiguration, UpperGoldLabel;

import '../c/controller.dart';
import '../m/model.dart';
import 'main_screen.dart' show ScreenPositioner;

// See the library comments, above!  (Android Studio  hides them by default.)

///
/// A helper to create the buttons and their associated layout.
///
abstract class ButtonFactory {
  final BuildContext context;
  final ScreenPositioner screen;
  final RealController controller;
  Settings get settings => controller.model.settings;

  // All sizes are based on a hypothetical 122x136 button.  This is
  // scaled to screen pixels in the painter.
  final double width = 122;
  final double height = 136;
  final double padRight = 25;
  final TextStyle keyTextStyle = const TextStyle(
      fontSize: 40,
      fontFamily: 'KeyLabelFont',
      fontWeight: FontWeight.normal,
      color: Color(0xffffffff),
      height: 0.97);
  final TextStyle shiftKeyTextStyle = const TextStyle(
      fontSize: 38, fontFamily: 'KeyLabelFont', color: Color(0xff000000));
  final Offset keyTextOffset = const Offset(0, 46);
  final Offset fKeyTextOffset = const Offset(0, 45);
  final Offset gKeyTextOffset = const Offset(0, 39);
  final Offset onKeyTextOffset = const Offset(0, 66);
  final Offset enterKeyTextOffset = const Offset(0, 53);
  late final TextStyle fTextStyle = TextStyle(
      fontSize: 26,
      fontFamily: 'KeyLabelFont',
      fontWeight: FontWeight.bold,
      color: Color(settings.fTextColor));
  late final TextStyle fTextSmallLabelStyle = TextStyle(
      fontSize: 17,
      fontFamily: 'KeyLabelFont',
      fontWeight: FontWeight.bold,
      color: Color(settings.fTextColor));
  Offset get fTextOffset => const Offset(0, -2);
  late final TextStyle gTextStyle = TextStyle(
      fontSize: 26,
      fontFamily: 'KeyLabelFont',
      color: Color(settings.gTextColor));
  late final TextStyle gTextStyleForLJ = TextStyle(
      fontFamily: 'LogoFont',
      fontWeight: FontWeight.w500,
      fontSize: 26,
      color: Color(settings.gTextColor));
  final Offset gTextOffset = const Offset(0, 92);
  final TextStyle specialButtonTextStyle = const TextStyle(
      fontSize: 42,
      fontFamily: 'KeyLabelFont',
      color: Colors.yellow,
      height: 0.97);
  final TextStyle acceleratorTextStyle = const TextStyle(
      fontSize: 32, fontFamily: 'KeyLabelFont', color: Color(0xff5fe88d));
  final RRect outerBorder =
      RRect.fromLTRBR(0, 26, 122, 136, const Radius.circular(7));
  final RRect innerBorder =
      RRect.fromLTRBR(7, 26 + 7, 122 - 7, 136 - 7, const Radius.circular(7));
  final RRect upperSurface = RRect.fromLTRBAndCorners(11, 26 + 11, 122 - 11, 88,
      topLeft: const Radius.circular(7), topRight: const Radius.circular(7));
  final RRect lowerSurface = RRect.fromLTRBAndCorners(
      11, 88, 122 - 11, 136 - 11,
      bottomLeft: const Radius.circular(7),
      bottomRight: const Radius.circular(7));
  final Paint fill = Paint()..style = PaintingStyle.fill;

  @protected
  ButtonFactory(this.context, this.screen, this.controller);

  int get numRows;
  int get numColumns;
  double totalButtonHeight(double height, double buttonHeight);

  double get shiftDownTweak => 0.0;

  void addUpperGoldLabels(List<Widget> result, Rect pos,
      {required double th,
      required double tw,
      required double bh,
      required double bw});

  List<Widget> buildButtons(LayoutConfiguration? config, Rect pos) {
    double y = pos.top;
    final result = List<Widget>.empty(growable: true);
    final double bw = pos.width *
        (width / (numColumns * width + (numColumns - 1) * padRight));
    final double tw = bw * (width + padRight) / width;
    final double bh = bw * height / width;
    // Total height for each button, including any label
    final double th = totalButtonHeight(pos.height, bh);

    y += shiftDownTweak;
    // Add the upper yellow labels
    final labels = config?.labels;
    if (labels == null) {
      addUpperGoldLabels(result, pos, th: th, tw: tw, bh: bh, bw: bw);
    } else {
      for (final UpperGoldLabel lbl in labels) {
        final TextStyle s = lbl.big ? fTextStyle : fTextSmallLabelStyle;
        result.add(screen.box(
            lbl.pos,
            CustomPaint(
                painter:
                    UpperLabel(lbl.text, s, height * (0.065 + 0.155) / bh))));
      }
    }

    final buttons = controller.getButtonLayout(this, th, bh);
    final List<List<CalculatorButton?>> rc = buttonLayout(buttons);
    for (int i = 0; i < rc.length; i++) {
      double x = pos.left;
      for (int j = 0; j < rc[i].length; j++) {
        final b = rc[i][j];
        if (b != null) {
          if (b.isEnter) {
            final double dx;
            // Scoot enter over to the left a bit if there's extra room because
            // the logo is to our left
            if (i < rc.length - 1 &&
                j > 0 &&
                rc[i][j - 1] == null &&
                rc[i + 1][j - 1] == null) {
              dx = -0.1;
            } else {
              dx = 0;
            }
            result.add(screen.box(Rect.fromLTWH(x + dx, y, bw, th + bh), b));
          } else {
            result.add(screen.box(Rect.fromLTWH(x, y, bw, bh), b));
          }
        }
        x += tw;
      }
      y += th;
    }

    return result;
  }

  List<List<CalculatorButton?>> buttonLayout(ButtonLayout buttons);

  List<List<CalculatorButton?>> applyButtonConfig(
      LayoutConfiguration? config, List<List<CalculatorButton?>> buttons) {
    if (config != null) {
      final fromAccelerator = <String, CalculatorButton>{};
      for (final row in buttons) {
        for (final b in row) {
          if (b != null) {
            fromAccelerator[b.acceleratorKey.substring(0, 1)] = b;
          }
        }
      }
      final List<List<String?>> configLayout = config.buttonAccelerator;
      buttons =
          List.generate(configLayout.length, (_) => <CalculatorButton?>[]);
      for (int i = 0; i < configLayout.length; i++) {
        final row = buttons[i];
        for (final String? accelerator in configLayout[i]) {
          final b = fromAccelerator.remove(accelerator);
          // Uses remove so a button can't be duplicated
          row.add(b);
        }
      }
    }
    return buttons;
  }

  String? getConfigAcceleratorLabel(String acceleratorKey) {
    final aLabels = controller.screenConfig.acceleratorLabels;
    if (aLabels == null) {
      return null;
    }
    return aLabels[acceleratorKey.substring(0, 1)];
  }
}

abstract class LandscapeButtonFactory extends ButtonFactory {
  LandscapeButtonFactory(super.context, super.screen, super.controller);

  @override
  int get numRows => controller.screenConfig.landscape?.buttonRows ?? 4;

  @override
  int get numColumns => controller.screenConfig.landscape?.buttonCols ?? 10;

  @override
  double totalButtonHeight(double height, double buttonHeight) =>
      (0.033409 + height - numRows * buttonHeight) / (numRows - 1) +
      buttonHeight;

  @override
  List<List<CalculatorButton?>> buttonLayout(ButtonLayout buttons) =>
      applyButtonConfig(
          controller.screenConfig.landscape, buttons.landscapeLayout);
}

abstract class PortraitButtonFactory extends ButtonFactory {
  PortraitButtonFactory(super.context, super.screen, super.controller);

  @override
  int get numRows => controller.screenConfig.portrait?.buttonRows ?? 7;

  @override
  int get numColumns => controller.screenConfig.portrait?.buttonCols ?? 6;

  @override
  double totalButtonHeight(double height, double buttonHeight) =>
      (height - 0.219672 - numRows * buttonHeight) / (numRows - 1) +
      buttonHeight;

  @override
  List<List<CalculatorButton?>> buttonLayout(ButtonLayout buttons) =>
      applyButtonConfig(
          controller.screenConfig.portrait, buttons.portraitLayout);
}

///
/// The layout of the buttons.
///
abstract class ButtonLayout {
  ButtonLayout() {
    assert(_noDuplicateAccelerators(landscapeLayout));
    assert(_noDuplicateAccelerators(portraitLayout));
  }

  bool _noDuplicateAccelerators(List<List<CalculatorButton?>> buttons) {
    final seen = <String>{};
    for (final row in buttons) {
      for (final b in row) {
        if (b != null) {
          final a = b.acceleratorKey;
          for (int i = 0; i < a.length; i++) {
            if (seen.contains(a[i])) {
              assert(false, '$a in $b');
              return false;
            }
            seen.add(a[i]);
          }
        }
      }
    }
    return true;
  }

  List<List<CalculatorButton?>> get landscapeLayout;

  List<List<CalculatorButton?>> get portraitLayout;

  CalculatorButton get enter;
}

/// The gold label above some groups of keys
class UpperLabel extends CustomPainter {
  final String text;
  final TextStyle style;
  final double height;

  UpperLabel(this.text, this.style, this.height);

  late final Paint linePaint = Paint()
    ..color = style.color!
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
    const double x = 2;
    final double w = (size.width / sf) - 2 * x;
    tp.layout();
    tp.paint(canvas, Offset(x + (w - tp.width) / 2, 0));
    final double y = -1 + tp.height / 2;
    final double h = (size.height / sf) - 2 * x; // Yes, x

    if (w - tp.width > 50) {
      Path p = Path()
        ..addPolygon([
          Offset(x, h),
          Offset(x, y),
          Offset(x + (w - tp.width) / 2 - 18, y)
        ], false);
      canvas.drawPath(p, linePaint);
      p = Path()
        ..addPolygon([
          Offset(x + (w + tp.width) / 2 + 18, y),
          Offset(x + w, y),
          Offset(x + w, h)
        ], false);
      canvas.drawPath(p, linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant UpperLabel oldDelegate) {
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
  final String acceleratorLabel;

  CalculatorButton(this.bFactory, this.uText, this.fText, this.gText, this.uKey,
      this.fKey, this.gKey, this.acceleratorKey,
      {String? acceleratorLabel, super.key})
      : acceleratorLabel = bFactory.getConfigAcceleratorLabel(acceleratorKey) ??
            acceleratorLabel ??
            acceleratorKey;

  @override
  CalculatorButtonState createState() => CalculatorButtonState();

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
  bool get isEnter => false;

  void paintForPainter(final Canvas canvas, final Size size,
      {required final bool pressed,
      required final bool pressedFromKeyboard,
      required final bool showAccelerators}) {
    final double h = height;
    final double w = width;
    assert((size.height / h - size.width / w) / w < 0.0000001);
    canvas.scale(size.height / h);

    drawGoldText(canvas, w);

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

    drawBlueText(canvas, w);

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
          ..color = const Color(0xff00ef00)
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
    const double x = -25;
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

  void drawText(
      Canvas canvas, TextStyle style, String text, double w, Offset offset) {
    final String normal;
    final String? superscript;
    final String? subscript;
    final caret = text.indexOf('^');
    if (caret == -1) {
      normal = text;
      superscript = subscript = null;
    } else {
      normal = text.substring(0, caret);
      final remain = text.substring(caret + 1);
      final caret2 = remain.indexOf('^');
      if (caret2 == -1) {
        superscript = remain;
        subscript = null;
      } else {
        superscript = remain.substring(0, caret2);
        subscript = remain.substring(caret2 + 1);
      }
    }
    TextSpan span = TextSpan(style: style, text: normal);
    TextPainter tp = TextPainter(
        text: span,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr);
    if (superscript == null && subscript == null) {
      tp.layout(minWidth: w);
      tp.paint(canvas, offset);
    } else {
      const scale = 0.75;
      tp.layout();
      double width = tp.width;
      final TextPainter? tpSup;
      final TextPainter? tpSub;
      if (superscript == null) {
        tpSup = null;
      } else {
        tpSup = TextPainter(
            text: TextSpan(style: style, text: superscript),
            textAlign: TextAlign.center,
            textDirection: TextDirection.ltr);
        tpSup.layout();
        width += tpSup.width * scale;
      }
      if (subscript == null) {
        tpSub = null;
      } else {
        tpSub = TextPainter(
            text: TextSpan(style: style, text: subscript),
            textAlign: TextAlign.center,
            textDirection: TextDirection.ltr);
        tpSub.layout();
        if (tpSup != null) {
          final extra = tpSub.width - tpSup.width;
          if (extra > 0) {
            width += extra * scale;
          }
        } else {
          width += tpSub.width * scale;
        }
      }
      canvas.save();
      canvas.translate(offset.dx + (w - width) / 2, offset.dy);
      final integralCheat = normal == '\u222b';
      if (integralCheat) {
        canvas.translate(0, -5);
      }
      tp.paint(canvas, const Offset(0, 0));
      if (integralCheat) {
        canvas.translate(0, -6);
      }
      canvas.translate(tp.width, 30 - tp.height);
      canvas.scale(scale);
      tpSup?.paint(canvas, const Offset(0, 0));
      canvas.translate(0, 22);
      tpSub?.paint(canvas, const Offset(0, 0));
      canvas.restore();
    }
  }

  void drawGoldText(Canvas canvas, double w) =>
      drawText(canvas, bFactory.fTextStyle, fText, w, bFactory.fTextOffset);

  void drawWhiteText(Canvas canvas, TextStyle style, String text, double w) =>
      drawText(canvas, style, text, w, keyTextOffset);

  void drawBlueText(Canvas canvas, double w) =>
      drawText(canvas, bFactory.gTextStyle, gText, w, gTextOffset);
}

/// A [CalculatorButton] that has a special function when used with conjunction
/// with the on'off button.  Such buttons show text describing their special
/// function when the on/off button has been pressed.
class CalculatorOnSpecialButton extends CalculatorButton {
  final String specialText; // For the special function when on is pressed

  CalculatorOnSpecialButton(
      super.factory,
      super.uText,
      super.fText,
      super.gText,
      super.uKey,
      super.fKey,
      super.gKey,
      super.rawKeyboardKey,
      this.specialText,
      {super.acceleratorLabel,
      super.key});

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

///
/// The button with the decimal point on it is really, really special in that
/// its keyboard accelerator allows ',' when in Euro comma mode
///
class CalculatorDotButton extends CalculatorOnSpecialButton {
  final Settings settings;

  CalculatorDotButton(
      super.factory,
      super.uText,
      super.fText,
      super.gText,
      super.uKey,
      super.fKey,
      super.gKey,
      super.rawKeyboardKey,
      super.specialText,
      this.settings,
      {super.key})
      : super(acceleratorLabel: '');

  @override
  String get acceleratorLabel => settings.euroComma ? '\u2219\u201a' : '\u2219';
}

/// The on/off button, which is flat on the 16C.
/// This button also has a special function when the on button is pressed,
/// because pressing it a second time turns the calculator off, so
/// it's also a [CalculatorOnSpecialButton].
class CalculatorOnButton extends CalculatorOnSpecialButton {
  CalculatorOnButton(
      super.factory,
      super.uText,
      super.fText,
      super.gText,
      super.uKey,
      super.fKey,
      super.gKey,
      super.rawKeyboardKey,
      super.specialText,
      {super.key});

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
  CalculatorShiftButton(super.factory, super.uText, super.fText, super.gText,
      super.uKey, super.fKey, super.gKey, super.rawKeyboardKey,
      {super.acceleratorLabel, super.key});

  String get extraAcceleratorName;

  @override
  late final Color upperSurfaceColorPressed =
      _brighter(upperSurfaceColor, 0.04);
  @override
  late final Color innerBorderColor = _brighter(upperSurfaceColor, 0.05);
  @override
  late final Color lowerSurfaceColor = _brighter(upperSurfaceColor, -0.19);
  @override
  late final Color lowerSurfaceColorPressed =
      _brighter(upperSurfaceColor, -0.12);

  static Color _brighter(Color src, double factor) {
    final h = HSVColor.fromColor(src);
    return h.withValue(max(0, min(1, h.value * (1 + factor)))).toColor();
  }

  @override
  void drawKeyboardAccelerator(Canvas canvas) {
    super.drawKeyboardAccelerator(canvas);
    const s = TextStyle(
        fontSize: 20, fontFamily: 'KeyLabelFont', color: Color(0xff5fe88d));
    const double x = -29;
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
  CalculatorFButton(super.factory, super.uText, super.fText, super.gText,
      super.uKey, super.fKey, super.gKey, super.rawKeyboardKey,
      {required this.extraAcceleratorName, super.acceleratorLabel, super.key});

  @override
  late final upperSurfaceColor = Color(bFactory.settings.fKeyColor);
  @override
  Offset get keyTextOffset => bFactory.fKeyTextOffset;
  @override
  TextStyle get keyTextStyle => bFactory.shiftKeyTextStyle;

  @override
  final String extraAcceleratorName;
}

///
/// The g shift button, which is blue instead of black.
///
class CalculatorGButton extends CalculatorShiftButton {
  CalculatorGButton(super.factory, super.uText, super.fText, super.gText,
      super.uKey, super.fKey, super.gKey, super.rawKeyboardKey,
      {required this.extraAcceleratorName, super.acceleratorLabel, super.key});

  @override
  late final Color upperSurfaceColor = Color(bFactory.settings.gKeyColor);
  @override
  Offset get keyTextOffset => bFactory.gKeyTextOffset;
  @override
  TextStyle get keyTextStyle => bFactory.shiftKeyTextStyle;

  @override
  final String extraAcceleratorName;
}

///
/// The button that has LJ in blue text.  Deja vu Sans has a really ugly "J",
/// so we change the font.
///
class CalculatorButtonWithLJ extends CalculatorButton {
  CalculatorButtonWithLJ(super.factory, super.uText, super.fText, super.gText,
      super.uKey, super.fKey, super.gKey, super.rawKeyboardKey,
      {super.key});

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
/// The 15C's square root button, which draws an extra line above the blue
/// label to visually complete the square-root symbol.  Lining this
/// up depends on the specific font, which is bundled with the app.
///
class CalculatorWhiteSqrtButton extends CalculatorButton {
  CalculatorWhiteSqrtButton(super.factory, super.uText, super.fText,
      super.gText, super.uKey, super.fKey, super.gKey, super.rawKeyboardKey,
      {super.key});

  @override
  void drawWhiteText(Canvas canvas, TextStyle style, String text, double w) {
    super.drawWhiteText(canvas, style, text, w);
    // Extend the line on the top of the square root symbol
    TextSpan span = TextSpan(style: style, text: '\u203E');
    TextPainter tp = TextPainter(
        text: span,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr);
    tp.layout(minWidth: w);
    tp.paint(canvas, keyTextOffset.translate(8.4, -2.2));
    tp.paint(canvas, keyTextOffset.translate(16, -2.2));
  }
}

///
/// The 16C's square root button, which draws an extra line above the blue
/// label to visually complete the square-root symbol.  Lining this
/// up depends on the specific font, which is bundled with the app.
///
class CalculatorBlueSqrtButton extends CalculatorButton {
  CalculatorBlueSqrtButton(
      super.factory,
      super.uText,
      super.fText,
      super.gText,
      NormalOperation super.uKey,
      NormalOperation super.fKey,
      NormalOperation super.gKey,
      super.rawKeyboardKey,
      {super.key});

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
  CalculatorEnterButton(super.factory, super.uText, super.fText, super.gText,
      super.uKey, super.fKey, super.gKey, super.rawKeyboardKey,
      {required this.extraHeight, super.acceleratorLabel, super.key})
      : _outerBorder = _calculateOuterBorder(factory, extraHeight),
        _innerBorder = _calculateInnerBorder(factory, extraHeight),
        _lowerSurface = _calculateLowerSurface(factory, extraHeight),
        _upperSurface = _calculateUpperSurface(factory, extraHeight),
        _gTextOffset = factory.gTextOffset.translate(0, extraHeight);

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

  @override
  bool get isEnter => true;

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
    widget.bFactory.controller.model.settings.showAcceleratorsObservable
        .addObserver(_repaint);
    widget.bFactory.controller.keyboard.register(this, widget.acceleratorKey);
  }

  @override
  void dispose() {
    super.dispose();
    widget.bFactory.controller.model.settings.showAcceleratorsObservable
        .removeObserver(_repaint);
    widget.bFactory.controller.keyboard.deregister(this, widget.acceleratorKey);
  }

  @override
  @protected
  void didUpdateWidget(covariant CalculatorButton oldWidget) {
    KeyboardController c = widget.bFactory.controller.keyboard;
    if (oldWidget.acceleratorKey != widget.acceleratorKey) {
      if (_pressed) {
        setState(() {
          _pressed = false;
          _pressedFromKeyboard = false;
        }); // Hard to imagine this happening
      }
      c.deregister(this, oldWidget.acceleratorKey);
      c.register(this, widget.acceleratorKey);
    }
    super.didUpdateWidget(oldWidget);
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
          switch (widget.bFactory.settings.keyFeedback) {
            case KeyFeedbackSetting.platform:
              unawaited(Feedback.forTap(context));
              break;
            case KeyFeedbackSetting.click:
              unawaited(SystemSound.play(SystemSoundType.click));
              break;
            case KeyFeedbackSetting.haptic:
              unawaited(HapticFeedback.selectionClick());
              break;
            case KeyFeedbackSetting.hapticHeavy:
              unawaited(HapticFeedback.heavyImpact());
              break;
            case KeyFeedbackSetting.both:
              unawaited(SystemSound.play(SystemSoundType.click));
              unawaited(HapticFeedback.selectionClick());
              break;
            case KeyFeedbackSetting.bothHeavy:
              unawaited(SystemSound.play(SystemSoundType.click));
              unawaited(HapticFeedback.heavyImpact());
              break;
            case KeyFeedbackSetting.none:
              break;
          }
          setState(() {
            _pressed = true;
          });
          // In case they're holding down a keyboard key while they press
          // a button with the mouse:
          factory.controller.keyboard.releasePressedButton();

          factory.controller.buttonWidgetDown(widget);
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
                    factory.controller.model.settings.showAccelerators)));
  }

  /// When the button is "pressed" with an accelerator key
  void keyPressed() {
    setState(() {
      _pressed = true;
      _pressedFromKeyboard = true;
    });
    factory.controller.buttonWidgetDown(widget);
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
