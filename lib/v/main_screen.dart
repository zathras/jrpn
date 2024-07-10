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
///
/// The main screen of the calculator.  It uses [ScreenPositioner] to
/// exactly position widgets, and scale them to the screen size.
///
library view.main_screen;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jovial_svg/jovial_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import '../c/controller.dart';
import '../m/model.dart';
import '../generic_main.dart';
import 'buttons.dart';
import 'isw.dart';
import 'lcd_display.dart';

// See the library comments, above!  (Android Studio  hides them by default.)

final _filesWork = kIsWeb ||
    Platform.isWindows ||
    Platform.isIOS ||
    Platform.isLinux ||
    Platform.isMacOS;

final _canLaunchWindow = !kIsWeb && (Platform.isLinux || Platform.isMacOS);

const _topSilverColor = Color(0xffcdcdcd);

/// A utility to to position something in absolute positions on the screen,
/// relative to the calculator face in virtual centimeters, which correspond
/// to the real HP-16c.  This encloses a child widget within a suitable
/// container to be put inside Stack widget with StackFit.expand set.
class ScreenPositioner {
  final double width; // cm
  final double height; // cm

  ScreenPositioner(this.width, this.height);

  /// x, y, w and h are in cm
  Widget box(final Rect pos, final Widget child) {
    final double dx = (pos.width >= width) ? 0 : pos.left / (width - pos.width);
    final double dy =
        (pos.height >= height) ? 0 : pos.top / (height - pos.height);
    return Align(
        alignment: FractionalOffset(dx, dy),
        child: FractionallySizedBox(
            widthFactor: pos.width / width,
            heightFactor: pos.height / height,
            child: child));
  }
}

abstract class OrientedScreen extends StatelessWidget {
  const OrientedScreen({super.key});

  static final ScreenPositioner _landscape = ScreenPositioner(12.7, 8);
  ScreenPositioner get landscape => _landscape;
  static final ScreenPositioner _portrait = ScreenPositioner(8, 12.7);
  ScreenPositioner get portrait => _portrait;

  Widget buildLandscape(BuildContext context, final ScreenPositioner screen);
  Widget buildPortrait(BuildContext context, final ScreenPositioner screen);

  @override
  Widget build(BuildContext context) {
    // As of this writing, OrientationBuilder doesn't work on macos desktop
    // (and probably elsewhere), though it does work in a desktop browser.
    // Maybe it's intentional (and in that case a bit silly), or maybe it's
    // some kind of oversight?
    // https://github.com/flutter/flutter/issues/82112
    return LayoutBuilder(builder: (BuildContext c2, BoxConstraints o) {
      if (o.hasBoundedHeight && o.hasBoundedWidth && o.maxHeight > o.maxWidth) {
        return buildPortrait(c2, portrait);
      } else {
        return buildLandscape(c2, landscape);
      }
    });
  }
}

///
/// The main screen.  Most of the interesting work happens in
/// [LcdDisplay] and [CalculatorButton].
///
class MainScreen extends OrientedScreen {
  final JrpnState jrpnState;
  final Jrpn topWidget;
  final ScalableImage icon;

  MainScreen(this.jrpnState, this.icon, {super.key})
      : topWidget = jrpnState.widget;

  RealController get controller => topWidget.controller;
  Model get model => topWidget.model;

  /// Midnight blue for area outside of calculator UI
  static const deadZoneColor = Color(0xff00002f);

  static const keyboardBaseColor = Color(0xff373436);

  /// Silver frame around the keys keys
  static const keyFrameSilver = Color(0xffdbdad1);

  @override
  ScreenPositioner get landscape =>
      jrpnState.controller.screenConfig.landscape?.screenSize ??
      super.landscape;
  @override
  ScreenPositioner get portrait =>
      jrpnState.controller.screenConfig.portrait?.screenSize ?? super.portrait;

  @override
  Widget buildPortrait(BuildContext context, ScreenPositioner screen) {
    final display = controller.model.display;
    // In portrait, we first shrink the font down, up to 18 digits (enough
    // for a 16 digit hex or binary number).  Beyond that, we grow the display
    // vertically, but since the font is half-sized, we only need to increase
    // the size once we get over 32 digits.  The display never gets wider.
    //
    // So:  lines is in the range 2..4, inclusive, because it's really
    // half-lines, in a sense.
    final lcdLines = max(1, (display.lcdDigits - 3) ~/ 16) + 1;
    final extraV = (lcdLines - 2) * 0.8;
    if (extraV > 0) {
      screen = ScreenPositioner(screen.width, screen.height + extraV);
      // So yes, we might shrink the whole calculator, if it was just
      // fitting vertically.  The size only changes when the display mode
      // (BIN/HEX/DEC) changes, or the word size changes.  That's a pretty
      // rare thing, so I'm OK with the buttons and stuff moving around a
      // little.
    }
    final Rect lp = controller.screenConfig.portrait?.logoPos ??
        Rect.fromLTWH(0.60, screen.height - 1.5, 0.94, 0.94);
    final lcdScale = min(6.7, screen.width - 1.3) / 6.7;
    final lcdHeight = lcdScale * (1.5 * LcdDisplay.heightTweak + extraV);
    final Rect lcdPos = Rect.fromLTWH(
        0.63, 0.6 + lcdHeight * (1 - lcdScale) / 2, 6.7 * lcdScale, lcdHeight);
    return Container(
        alignment: Alignment.center,
        color: deadZoneColor,
        child: AspectRatio(
            aspectRatio: screen.width / screen.height,
            child: Stack(fit: StackFit.expand, children: [
              screen.box(Rect.fromLTWH(0, 0, screen.width, screen.height),
                  CustomPaint(painter: DrawnBackground(screen, extraV))),
              ...((lp.width == 0 || lp.height == 0)
                  ? []
                  : [
                      screen.box(lp, _jrpnLogo()),
                    ]),
              screen.box(
                  lcdPos,
                  LcdDisplay(controller.model, _showMenu, 11, jrpnState,
                      extraTall: extraV > 0)),
              ...controller
                  .getPortraitButtonFactory(context, screen)
                  .buildButtons(
                      controller.screenConfig.portrait,
                      Rect.fromLTRB(0.7, 2.75 + extraV, screen.width - 0.7,
                          screen.height - 0.47)),
              MainMenu(this, screen)
            ])));
  }

  @override
  Widget buildLandscape(BuildContext context, final ScreenPositioner screen) {
    final display = controller.model.display;
    int digitsH = min(18, display.lcdDigits);
    // Over 18 digits, we shrink the font.  18 is enough for
    // 16 hex digits, which fits a 64 bit number.
    assert(digitsH >= 11 && digitsH <= 18);
    final maxLcdWidth = screen.width - 2.17; // 10.53 at default width of 12.7
    final maxExpander = (maxLcdWidth - 6.7) / 3.83; // 1.0 at default width
    final expander =
        min(maxExpander, (digitsH - 11) / 7); // In the range [0, 1]
    final lcdLeft = 2.0 - 1.47 * (expander / maxExpander);
    final lcdWidth = 6.7 + 3.83 * expander;
    final iconL = screen.width - 1.82 + 0.392 * (expander / maxExpander);
    final Rect lp = controller.screenConfig.landscape?.logoPos ??
        Rect.fromLTWH(iconL, 0.65, 0.94, 0.94);
    return Container(
      // Midnight blue for slop when aspect ratio not matched
      alignment: Alignment.center,
      color: deadZoneColor,
      child: AspectRatio(
        aspectRatio: screen.width / screen.height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            screen.box(Rect.fromLTWH(0, 0, screen.width, screen.height),
                CustomPaint(painter: DrawnBackground(screen, 0))),
            ...((lp.width == 0 || lp.height == 0)
                ? []
                : [
                    screen.box(lp, _jrpnLogo()),
                  ]),
            screen.box(
                Rect.fromLTWH(
                    lcdLeft, 0.6, lcdWidth, 1.5 * LcdDisplay.heightTweak),
                LcdDisplay(controller.model, _showMenu, digitsH, jrpnState)),
            ...controller
                .getLandscapeButtonFactory(context, screen)
                .buildButtons(
                    controller.screenConfig.landscape,
                    Rect.fromLTRB(
                        0.7, 2.75, screen.width - 0.7, screen.height - 0.47)),
            MainMenu(this, screen)
          ],
        ),
      ),
    );
  }

  Future<void> _showMenu(BuildContext context, Offset tapOffset) async {
    void Function(BuildContext)? f = await showMenu(
        position: RelativeRect.fromLTRB(
            tapOffset.dx, tapOffset.dy, tapOffset.dx + 1, tapOffset.dy + 1),
        context: context,
        items: [
          PopupMenuItem(
              value: _copyDisplayToClipboard,
              child: const Row(children: [
                Icon(Icons.content_copy),
                Text('Copy to Clipboard')
              ])),
          PopupMenuItem(
              value: _pasteNumberToModel,
              child: const Row(children: [
                Icon(Icons.content_copy),
                Text('Paste from Clipboard')
              ])),
        ]);
    if (f != null && context.mounted) {
      f(context);
    }
  }

  void _copyDisplayToClipboard(BuildContext _) {
    String displayed = model.display.currentWithoutWindow;
    if (!model.isFloatMode) {
      displayed = displayed.replaceAll(',', '');
    }
    displayed = model.settings.swapCommaIfEuro(displayed);
    Clipboard.setData(ClipboardData(text: displayed));
  }

  void _pasteNumberToModel(BuildContext context) {
    unawaited(() async {
      final String? cd;
      try {
        cd = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
      } catch (e) {
        if (context.mounted) {
          return showErrorDialog(context, 'Error accessing clipboard', e);
        } else {
          return;
        }
      }
      if (cd == null || cd == '') {
        if (context.mounted) {
          return showErrorDialog(context, 'Empty clipboard', null);
        }
      } else if (model.displayDisabled) {
        if (context.mounted) {
          return showErrorDialog(
              context, 'Program is running / display disabled', null);
        }
      } else if (!controller.pasteToX(cd) && context.mounted) {
        return showErrorDialog(context, 'Number format error', null);
      }
    }());
  }

  Widget _jrpnLogo() =>
      CustomPaint(painter: JrpnLogoPainter(icon, model.modelName));
}

///
/// Draw the background of the calculator.
///
class DrawnBackground extends CustomPainter {
  final ScreenPositioner screen;
  final double extraLcdHeight;

  DrawnBackground(this.screen, this.extraLcdHeight);

  @override
  void paint(Canvas canvas, Size size) {
    // conversion factor from cm to the coordinate system of the Canvas
    final double cm = size.width / screen.width;

    // Outside frame (raised):
    final p = Paint()
      ..color = const Color(0xff4b4b50)
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTRB(0, 0, size.width, size.height), p);

    double x = 0.27 * cm;
    double y = (2.5 + extraLcdHeight) * cm;

    // Silver along top:
    p.color = _topSilverColor;
    canvas.drawRect(Rect.fromLTRB(x, 0, size.width - x, y), p);
    // Darker silver along very top edge:
    p.color = const Color(0xff7c7c7c);
    canvas.drawRect(Rect.fromLTRB(x, 0, size.width - x, 0.2 * cm), p);

    // Darker on top and bottom of raised frame
    p.color = const Color(0xff2b2b2f);
    canvas.drawRect(Rect.fromLTRB(0, 0, x, 0.2 * cm), p);
    canvas.drawRect(Rect.fromLTRB(size.width - x, 0, size.width, 0.2 * cm), p);
    canvas.drawRect(
        Rect.fromLTRB(0, size.height - 0.15 * cm, x, size.height), p);
    canvas.drawRect(
        Rect.fromLTRB(
            size.width - x, size.height - 0.15 * cm, size.width, size.height),
        p);

    // Outer keyboard base
    p.color = MainScreen.keyboardBaseColor;
    y += 0.1 * cm;
    double bottom = size.height - 0.05 * cm;
    canvas.drawRect(Rect.fromLTRB(x, y, size.width - x, bottom), p);

    x += 0.05 * cm;
    y += 0.05 * cm;
    bottom -= 0.05 * cm;
    p.color = MainScreen.keyFrameSilver;
    canvas.drawRRect(
        RRect.fromLTRBR(
            x, y, size.width - x, bottom, Radius.circular(0.1 * cm)),
        p);
    x += 0.07 * cm;
    y += 0.07 * cm;
    bottom -= 0.2 * cm;
    p.color = MainScreen.keyboardBaseColor;
    canvas.drawRRect(
        RRect.fromLTRBR(
            x, y, size.width - x, bottom, Radius.circular(0.05 * cm)),
        p);

    // The JRPN URL on the bottom
    final span = TextSpan(
        style: TextStyle(
            color: MainScreen.keyFrameSilver,
            fontFamily: 'LogoFont',
            fontWeight: FontWeight.w400,
            fontSize: 0.26 * cm),
        text: 'J R P N . J O V I A L . C O M');
    TextPainter tp = TextPainter(
        text: span,
        textAlign: TextAlign.left,
        textDirection: TextDirection.ltr);
    tp.layout();
    // Background for the text, in keyboardBase
    canvas.drawRect(
        Rect.fromLTRB(x + 0.3 * cm, bottom - 1, x + 0.7 * cm + tp.width,
            bottom + 0.2 * cm + 1),
        p);
    tp.paint(canvas, Offset(x + 0.5 * cm, bottom - 0.06 * cm));
  }

  @override
  bool shouldRepaint(covariant DrawnBackground oldDelegate) {
    return oldDelegate.screen != screen;
  }
}

@immutable
class JrpnLogoPainter extends CustomPainter {
  final ScalableImage jupiter;
  final String modelName;
  final bool adaptive;

  const JrpnLogoPainter(this.jupiter, this.modelName, {this.adaptive = false});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint foreground = Paint()
      ..color = const Color(0xffe6edf5)
      ..style = PaintingStyle.fill;
    final Paint background = Paint()
      ..color = const Color(0xff000000)
      ..style = PaintingStyle.fill;
    if (!adaptive) {
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), background);
    }

    const border = 3 / 106;
    double x = border * size.width;
    double y = border * size.height;
    size = Size(size.width - 2 * x, size.height - 2 * y);

    Size rectSize = Size(size.width, size.height * 0.64);
    final cornerRadius = Radius.circular(0.05 * rectSize.width * 0.9);
    if (!adaptive) {
      canvas.drawRRect(
          RRect.fromLTRBR(
              x, y, x + rectSize.width, y + rectSize.height, cornerRadius),
          foreground);
    }
    canvas.save();
    canvas.translate(x + (rectSize.width - rectSize.height) / 2, y);
    canvas.scale(
        rectSize.height / jupiter.height!, rectSize.height / jupiter.width!);
    jupiter.paint(canvas);
    canvas.restore();

    y += rectSize.height;
    if (adaptive) {
      y += 0.01 * size.height;
      background.strokeWidth = 0.02 * size.height;
      canvas.drawLine(Offset(0, y), Offset(size.width + 2 * x, y), background);
      y += 0.01 * size.height;
    } else {
      y += 0.02 * size.height;
    }

    rectSize = Size(size.width, size.height * 0.34);
    if (!adaptive) {
      canvas.drawRRect(
          RRect.fromLTRBR(
              x, y, x + rectSize.width, y + rectSize.height, cornerRadius),
          foreground);
    }

    const embiggen = 1.25;
    const style = TextStyle(
        fontSize: 0.3, // in cm
        fontFamily: 'LogoFont',
        fontWeight: FontWeight.w500,
        color: Colors.black);
    final span = TextSpan(style: style, text: modelName);
    final double cm = rectSize.width / 0.9;
    TextPainter tp = TextPainter(
        text: span,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr);
    tp.layout();
    canvas.save();
    canvas.translate(x, y);
    canvas.translate((rectSize.width - tp.width * cm * embiggen) / 2,
        rectSize.height * 0.85);
    canvas.scale(cm * embiggen, cm);
    tp.paint(canvas, Offset.zero);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant JrpnLogoPainter oldDelegate) {
    return false; // We never change
  }
}

///
/// The application's main menu.
///
class MainMenu extends StatefulWidget {
  final MainScreen main;
  final ScreenPositioner screen;

  const MainMenu(this.main, this.screen, {super.key});

  @override
  State<MainMenu> createState() => _MainMenuState();
}

class _MainMenuState extends State<MainMenu> {
  Model get model => widget.main.model;
  RealController get controller => widget.main.controller;
  ScreenPositioner get screen => widget.screen;

  void _enabledChanged(bool v) => setState(() {});

  @override
  void initState() {
    model.settings.menuEnabledObservable.addObserver(_enabledChanged);
    super.initState();
  }

  @override
  void dispose() {
    model.settings.menuEnabledObservable.removeObserver(_enabledChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final children = List<Widget>.empty(growable: true);
    final Rect menuIconPosition;
    final Rect menuHitArea;
    if (widget.screen.width < widget.screen.height) {
      menuIconPosition = Rect.fromLTWH(screen.width - 1, 0.1, 0.7, 0.7);
      menuHitArea = Rect.fromLTWH(screen.width - 1, 0, 1, 1);
    } else {
      menuIconPosition = Rect.fromLTWH(screen.width - 1, 0.1, 1, 1);
      menuHitArea = Rect.fromLTWH(screen.width - 2, 0, 2, 2);
    }
    if (model.settings.menuEnabled) {
      children.add(screen.box(menuIconPosition, Icon(Icons.adaptive.more)));
    }
    children.add(screen.box(menuHitArea, _buildMenu(context)));
    return Stack(children: children);
  }

  Widget _buildMenu(BuildContext context) => PopupMenuButton(
        icon: const Icon(null),
        onSelected: (void Function() action) => setState(() => action()),
        itemBuilder: (BuildContext context) {
          return <PopupMenuEntry<void Function()>>[
            PopupMenuItem(
                value: () {}, child: _FileMenu('File', widget.main.topWidget)),
            PopupMenuItem(
                value: () {},
                child: _SettingsMenu('Settings', widget.main.topWidget)),
            // PopupMenuDivider(),
            PopupMenuItem(
                value: () {},
                child: _HelpMenu('Help', widget.main.icon, controller))
          ];
        },
      );
}

class _HelpMenu extends StatelessWidget {
  final String title;
  final ScalableImage icon;
  final RealController controller;

  const _HelpMenu(this.title, this.icon, this.controller);

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<void Function()>(
      offset: const Offset(-100, 0),
      onSelected: (void Function() action) => action(),
      onCanceled: () {
        Navigator.pop(context);
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<void Function()>>[
        PopupMenuItem(
            value: () {
              Navigator.pop<void>(context);
              unawaited(launchUrl(applicationHelpAddress,
                  mode: LaunchMode.externalApplication));
            },
            child: const Text('User Guide')),
        PopupMenuItem(
            value: () {
              Navigator.pop<void>(context);
              unawaited(
                  showDialog(context: context, builder: _showNonWarranty));
            },
            child: const Text('Non-warranty')),
        PopupMenuItem(
            value: () {
              Navigator.pop<void>(context);
              if (_canLaunchWindow) {
                unawaited(
                    InternalStateWindow.launch(context, controller.model));
              } else {
                Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                        builder: (context) =>
                            InternalStatePanel(controller.model)));
              }
            },
            child: const Text('See Calculator Internals')),
        PopupMenuItem(
            value: () {
              Navigator.pop<void>(context);
              unawaited(launchUrl(applicationIssueAddress,
                  mode: LaunchMode.externalApplication));
            },
            child: const Text('Submit Issue (Web)')),
        PopupMenuItem(
            value: () {
              Navigator.pop<void>(context);
              Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                      builder: (context) => controller.getBackPanel()));
            },
            child: const Text('Back Panel')),
        PopupMenuItem(
            value: () {
              Navigator.pop<void>(context);
              showAboutDialog(
                  context: context,
                  applicationIcon: ScalableImageWidget(si: icon, scale: 0.15),
                  applicationName: 'JRPN ${controller.model.modelName}',
                  applicationVersion: 'Version $applicationVersion',
                  applicationLegalese: '© 2021-2024 Bill Foote',
                  children: [
                    const SizedBox(height: 40),
                    InkWell(
                        onTap: () => unawaited(launchUrl(applicationWebAddress,
                            mode: LaunchMode.externalApplication)),
                        child: RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                                style: TextStyle(
                                    fontSize: 18,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .secondary),
                                text: applicationWebAddress.toString())))
                  ]);
            },
            child: const Text('About')),
      ],
      child: Row(
        children: [
          Text(title),
          const Spacer(),
          const Icon(Icons.arrow_right, size: 30.0),
        ],
      ),
    );
  }
}

Widget _showNonWarranty(BuildContext context) => AlertDialog(
        title: const Text('Non-Warranty'),
        content: Text(nonWarranty.replaceAll('\n', ' ')),
        actions: [
          TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'))
        ]);

class _SettingsMenu extends StatefulWidget {
  final String title;
  final Jrpn app;
  const _SettingsMenu(this.title, this.app);

  Model get model => app.model;
  RealController get controller => app.controller;

  @override
  __SettingsMenuState createState() => __SettingsMenuState();
}

class __SettingsMenuState extends State<_SettingsMenu> {
  Settings get settings => widget.model.settings;

  DisplayModel get display => widget.model.display;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<void Function()>(
      // how much the submenu should offset from parent.
      offset: const Offset(-100, 0),
      onSelected: (void Function() action) {
        setState(() => action());
        Navigator.pop(context);
      },
      onCanceled: () => Navigator.pop(context),
      itemBuilder: (BuildContext context) => <PopupMenuEntry<void Function()>>[
        CheckedPopupMenuItem(
            checked: settings.menuEnabled,
            value: () {
              settings.menuEnabled = !settings.menuEnabled;
              unawaited(widget.app.model.writeToPersistentStorage());
            },
            child: const Text('Show Menu Icon')),
        ...(settings.isMobilePlatform
            ? [
                CheckedPopupMenuItem(
                    checked: settings.systemOverlaysDisabled,
                    value: () {
                      settings.systemOverlaysDisabled =
                          !settings.systemOverlaysDisabled;
                      unawaited(widget.app.model.writeToPersistentStorage());
                    },
                    child: const Text('Disable System UI Overlays')),
                PopupMenuItem(
                    child: Row(children: [
                  DropdownButton(
                      value: settings.orientation,
                      onChanged: (OrientationSetting? v) {
                        if (v != null) {
                          settings.orientation = v;
                          unawaited(
                              widget.app.model.writeToPersistentStorage());
                          Navigator.pop(context, () {});
                        }
                      },
                      items: const [
                        DropdownMenuItem(
                            value: OrientationSetting.auto,
                            child: Text('Automatic')),
                        DropdownMenuItem(
                            value: OrientationSetting.portrait,
                            child: Text('Portrait')),
                        DropdownMenuItem(
                            value: OrientationSetting.landscape,
                            child: Text('Landscape'))
                      ]),
                  const Text('    Orientation')
                ])),
                PopupMenuItem(
                    child: Row(children: [
                  DropdownButton(
                      value: settings.keyFeedback,
                      onChanged: (KeyFeedbackSetting? v) {
                        if (v != null) {
                          settings.keyFeedback = v;
                          unawaited(
                              widget.app.model.writeToPersistentStorage());
                          Navigator.pop(context, () {});
                        }
                      },
                      items: const [
                        DropdownMenuItem(
                            value: KeyFeedbackSetting.platform,
                            child: Text('Platform Default')),
                        DropdownMenuItem(
                            value: KeyFeedbackSetting.click,
                            child: Text('Click')),
                        DropdownMenuItem(
                            value: KeyFeedbackSetting.haptic,
                            child: Text('Haptic')),
                        DropdownMenuItem(
                            value: KeyFeedbackSetting.both,
                            child: Text('Both')),
                        DropdownMenuItem(
                            value: KeyFeedbackSetting.hapticHeavy,
                            child: Text('Haptic - Heavy')),
                        DropdownMenuItem(
                            value: KeyFeedbackSetting.bothHeavy,
                            child: Text('Both - Heavy')),
                        DropdownMenuItem(
                            value: KeyFeedbackSetting.none, child: Text('None'))
                      ]),
                  const Text('    Key Feedback')
                ])),
              ]
            : []),
        PopupMenuItem(
            child: Row(children: [
          DropdownButton(
              value: settings.longNumbers,
              onChanged: (LongNumbersSetting? v) {
                if (v != null) {
                  settings.longNumbers = v;
                  unawaited(widget.app.model.writeToPersistentStorage());
                  display.update();
                  Navigator.pop(context, () {});
                }
              },
              items: [
                DropdownMenuItem(
                    value: LongNumbersSetting.window,
                    child: Text(
                        widget.controller.menus15C ? 'Disable' : 'Window')),
                const DropdownMenuItem(
                    value: LongNumbersSetting.growLCD, child: Text('Grow LCD')),
                const DropdownMenuItem(
                    value: LongNumbersSetting.shrinkDigits,
                    child: Text('Shrink Digits')),
              ]),
          const Text('    Long\n    Numbers')
        ])),
        ...(widget.controller.menus15C
            ? []
            : [
                CheckedPopupMenuItem(
                    checked: settings.hideComplement,
                    value: () {
                      settings.hideComplement = !settings.hideComplement;
                      unawaited(widget.app.model.writeToPersistentStorage());
                      display.update();
                    },
                    child: const Text('Hide Complement Status')),
                CheckedPopupMenuItem(
                    checked: settings.showWordSize,
                    value: () {
                      settings.showWordSize = !settings.showWordSize;
                      unawaited(widget.app.model.writeToPersistentStorage());
                      display.update();
                    },
                    child: const Text('Show Word Size')),
                CheckedPopupMenuItem(
                    checked: settings.integerModeCommas,
                    value: () {
                      settings.integerModeCommas = !settings.integerModeCommas;
                      unawaited(widget.app.model.writeToPersistentStorage());
                      display.update();
                    },
                    child: const Text('Integer Mode Commas')),
              ]),
        CheckedPopupMenuItem(
            checked: settings.showAccelerators,
            value: () {
              settings.showAccelerators = !settings.showAccelerators;
              unawaited(widget.app.model.writeToPersistentStorage());
            },
            child: const Text('Show Accelerators (toggle with "?")')),
        PopupMenuItem(
            child: _SystemSettingsMenu('System Settings', widget.app)),
      ],
      child: Row(
        children: [
          Text(widget.title),
          const Spacer(),
          const Icon(Icons.arrow_right, size: 30.0),
        ],
      ),
    );
  }
}

class _TextEntry extends StatefulWidget {
  final void Function(String) onDone;
  final String initial;
  final bool text;

  const _TextEntry(
      {required this.initial, required this.onDone, required this.text})
      : super();

  @override
  _TextEntryState createState() => _TextEntryState();
}

class _TextEntryState extends State<_TextEntry> {
  late final TextEditingController controller;
  _TextEntryState();

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    super.dispose();
    widget.onDone(controller.text);
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
        textAlign: TextAlign.right,
        controller: controller,
        onTap: () => controller.selection = TextSelection(
            baseOffset: 0, extentOffset: controller.value.text.length),
        keyboardType: widget.text ? TextInputType.text : TextInputType.number,
        // We could do an onSubmitted: here, if the
        // virtual keyboard is covering the entered value, the user never
        // gets to see the entry.  On desktop (April 2021, before desktop
        // support was finalized), we never saw onSubmitted.
      );
}

class _FileMenu extends StatefulWidget {
  final String title;
  final Jrpn app;

  const _FileMenu(this.title, this.app);

  @override
  _FileMenuState createState() => _FileMenuState();
}

class _FileMenuState extends State<_FileMenu> {
  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<Future<void> Function()>(
      // how much the submenu should offset from parent.
      offset: const Offset(-100, 0),
      onSelected: (Future<void> Function() action) async {
        await action();
        setState(() {});
        if (context.mounted) {
          Navigator.pop(context, () {});
        }
      },
      onCanceled: () => Navigator.pop(context),
      itemBuilder: (BuildContext context) => [
        PopupMenuItem(
            value: () async {}, child: _FileReadMenu('Read', widget.app)),
        PopupMenuItem(
            value: () async {}, child: _FileSaveMenu('Save', widget.app)),
        PopupMenuItem(
            value: () async {},
            child: _ImportProgramMenu('Import Program', widget.app)),
        PopupMenuItem(
            value: () async {},
            child: _ExportProgramMenu('Export Program', widget.app)),
        PopupMenuItem(
            value: () async {
              widget.app.controller.resetAll();
              widget.app.model.reset();
              await widget.app.model.writeToPersistentStorage();
            },
            child: const Text('Reset All'))
      ],
      child: Row(
        children: [
          Text(widget.title),
          const Spacer(),
          const Icon(Icons.arrow_right, size: 30.0),
        ],
      ),
    );
  }
}

class _FileSaveMenu extends StatefulWidget {
  final String title;
  final Jrpn app;

  const _FileSaveMenu(this.title, this.app);

  @override
  __FileSaveMenuState createState() => __FileSaveMenuState();
}

class __FileSaveMenuState extends State<_FileSaveMenu> {
  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<Future<void> Function()>(
      // how much the submenu should offset from parent.
      offset: const Offset(-100, 0),
      onSelected: (Future<void> Function() action) async {
        await action();
        setState(() {});
        if (context.mounted) {
          Navigator.pop<Future<void> Function()>(context, () async {});
        }
      },
      itemBuilder: (BuildContext context) => [
        PopupMenuItem(
          value: () =>
              widget.app.model.writeToPersistentStorage(unconditional: true),
          child: const Text('Save as Starting State'),
        ),
        ...(_filesWork
            ? [
                PopupMenuItem(
                  value: () => _saveToFile(context),
                  child: const Text('Save to File...'),
                ),
              ]
            : []),
        PopupMenuItem(
          value: () => widget.app.sendJsonToClipboard(),
          child: const Text('Copy to Clipboard'),
        ),
        PopupMenuItem(
          value: () => widget.app.sendJsonToExternalApp(),
          child: const Text('Export to Application'),
        ),
        PopupMenuItem(
          value: () => widget.app.sendUrlToClipboard(),
          child: const Text('Copy URL to Clipboard'),
        ),
      ],
      child: Row(
        children: [
          Text(widget.title),
          const Spacer(),
          const Icon(Icons.arrow_right, size: 30.0),
        ],
      ),
    );
  }

  Future<void> _saveToFile(BuildContext context) async {
    final model = widget.app.model;
    final ext = 'j${model.modelName.toLowerCase()}';
    final suggested = 'calculator.$ext';
    final String? path =
        (await getSaveLocation(suggestedName: suggested))?.path;
    if (path == null) {
      return;
    }
    final String data = json.encoder.convert(model.toJson());
    final f = XFile.fromData(utf8.encoder.convert(data),
        mimeType: 'application/json', name: suggested);
    try {
      await f.saveTo(path);
    } catch (e, s) {
      debugPrint('\n\n$e\n\n$s');
      if (context.mounted) {
        return showErrorDialog(context, 'Error saving', e);
      }
    }
  }
}

class _ImportProgramMenu extends StatefulWidget {
  final String title;
  final Jrpn app;

  const _ImportProgramMenu(this.title, this.app);

  @override
  __ImportProgramMenuState createState() => __ImportProgramMenuState();
}

class __ImportProgramMenuState extends State<_ImportProgramMenu> {
  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<Future<void> Function()>(
      // how much the submenu should offset from parent.
      offset: const Offset(-100, 0),
      onSelected: (Future<void> Function() action) async {
        await action();
        setState(() {});
        if (context.mounted) {
          Navigator.pop<Future<void> Function()>(context, () async {});
        }
      },
      itemBuilder: (BuildContext context) => [
        ...(_filesWork
            ? [
                PopupMenuItem(
                  value: () => _importFromFile(context),
                  child: const Text('Import from File...'),
                ),
              ]
            : []),
        PopupMenuItem(
          value: () => _importFromClipboard(context),
          child: const Text('Import from Clipboard'),
        ),
      ],
      child: Row(
        children: [
          Text(widget.title),
          const Spacer(),
          const Icon(Icons.arrow_right, size: 30.0),
        ],
      ),
    );
  }

  Future<void> _importFromClipboard(BuildContext context) async {
    widget.app.controller.resetAll();
    final String? cd;
    try {
      cd = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
    } catch (e) {
      if (context.mounted) {
        return showErrorDialog(context, 'Error accessing clipboard', e);
      } else {
        return;
      }
    }
    if (cd == null) {
      widget.app.controller.showMessage('bad c1ip ');
    } else {
      try {
        widget.app.model.program.importProgram(cd);
      } catch (e, s) {
        debugPrint('\n\n$e\n\n$s');
        widget.app.controller.showMessage('bad c1ip ');
        if (context.mounted) {
          return showErrorDialog(context, 'Bad data in clipboard', e);
        }
      }
    }
  }

  Future<void> _importFromFile(BuildContext context) async {
    final model = widget.app.model;
    final ext = model.modelName.toLowerCase();
    final typeGroup = XTypeGroup(
        label: 'JRPN Program (.$ext)', extensions: [ext, ext.toUpperCase()]);
    const any = XTypeGroup(label: 'JRPN Program (any extension)');
    final file = await openFile(acceptedTypeGroups: [typeGroup, any]);
    if (file == null) {
      return;
    }
    widget.app.controller.resetAll();
    try {
      final data = await file.readAsBytes();
      widget.app.model.program.importProgramFromFile(data);
    } catch (e, s) {
      debugPrint('\n\n$e\n\n$s');
      widget.app.controller.showMessage('bad fi1e ');
      if (context.mounted) {
        return showErrorDialog(context, 'Bad data in file', e);
      }
    }
  }
}

class _ExportProgramMenu extends StatefulWidget {
  final String title;
  final Jrpn app;

  const _ExportProgramMenu(this.title, this.app);

  @override
  __ExportProgramMenuState createState() => __ExportProgramMenuState();
}

class __ExportProgramMenuState extends State<_ExportProgramMenu> {
  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<Future<void> Function()>(
      // how much the submenu should offset from parent.
      offset: const Offset(-100, 0),
      onSelected: (Future<void> Function() action) async {
        await action();
        setState(() {});
        if (context.mounted) {
          Navigator.pop<Future<void> Function()>(context, () async {});
        }
      },
      itemBuilder: (BuildContext context) => [
        ...(_filesWork
            ? [
                PopupMenuItem(
                  value: () => _exportToFile(context, true),
                  child: const Text('Export to File...'),
                ),
                PopupMenuItem(
                  value: () => _exportToFile(context, false),
                  child: const Text('Export to UTF-16LE File...'),
                ),
              ]
            : []),
        PopupMenuItem(
          value: () => widget.app.sendProgramToClipboard(),
          child: const Text('Export to Clipboard'),
        ),
        PopupMenuItem(
          value: () => widget.app.sendProgramToExternalApp(),
          child: const Text('Export to Application'),
        ),
      ],
      child: Row(
        children: [
          Text(widget.title),
          const Spacer(),
          const Icon(Icons.arrow_right, size: 30.0),
        ],
      ),
    );
  }

  Future<void> _exportToFile(BuildContext context, bool inUtf8) async {
    final model = widget.app.model;
    final ext = model.modelName.toLowerCase();
    final suggested = 'program.$ext';
    final String? path =
        (await getSaveLocation(suggestedName: suggested))?.path;
    if (path == null) {
      return;
    }
    final XFile f;
    if (inUtf8) {
      final String data = widget.app.getProgram('UTF-8');
      f = XFile.fromData(utf8.encoder.convert(data),
          mimeType: 'text/plain;charset=UTF-8', name: suggested);
    } else {
      final String s = widget.app.getProgram('UTF-16LE');
      final data = Uint8List(s.length * 2 + 2);
      int pos = 0;
      data[pos++] = 0xff;
      data[pos++] = 0xfe;
      for (final c in s.codeUnits) {
        data[pos++] = c & 0xff;
        data[pos++] = (c >> 8) & 0xff;
      }
      f = XFile.fromData(data,
          mimeType: 'text/plain;charset=UTF-16LE', name: suggested);
    }
    try {
      await f.saveTo(path);
    } catch (e, s) {
      debugPrint('\n\n$e\n\n$s');
      if (context.mounted) {
        return showErrorDialog(context, 'Error saving', e);
      }
    }
  }
}

class _FileReadMenu extends StatefulWidget {
  final String title;
  final Jrpn app;

  const _FileReadMenu(this.title, this.app);

  @override
  __FileReadMenuState createState() => __FileReadMenuState();
}

class __FileReadMenuState extends State<_FileReadMenu> {
  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<Future<void> Function()>(
      // how much the submenu should offset from parent.
      offset: const Offset(-100, 0),
      onSelected: (Future<void> Function() action) async {
        await action();
        setState(() {});
        if (context.mounted) {
          Navigator.pop<Future<void> Function()>(context, () async {});
        }
      },
      itemBuilder: (BuildContext context) => [
        PopupMenuItem(
          value: () {
            widget.app.controller.resetAll();
            return widget.app.model.resetFromPersistentStorage();
          },
          child: const Text('Restore Starting State'),
        ),
        ...(_filesWork
            ? [
                PopupMenuItem(
                  value: () => _readFromFile(context),
                  child: const Text('Read from File...'),
                ),
              ]
            : []),
        PopupMenuItem(
          value: () => _pasteFromClipboard(context),
          child: const Text('Read from Clipboard'),
        ),
      ],
      child: Row(
        children: [
          Text(widget.title),
          const Spacer(),
          const Icon(Icons.arrow_right, size: 30.0),
        ],
      ),
    );
  }

  Future<void> _pasteFromClipboard(BuildContext context) async {
    final String? cd;
    widget.app.controller.resetAll();
    try {
      cd = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
    } catch (e) {
      if (context.mounted) {
        return showErrorDialog(context, 'Error accessing clipboard', e);
      } else {
        return;
      }
    }
    if (cd == null) {
      widget.app.controller.showMessage('bad c1ip ');
    } else {
      try {
        widget.app.model.initializeFromJsonOrUri(cd);
      } catch (e, s) {
        debugPrint('\n\n$e\n\n$s');
        widget.app.controller.showMessage('bad c1ip ');
        if (context.mounted) {
          return showErrorDialog(context, 'Bad data in clipboard', e);
        }
      }
    }
  }

  Future<void> _readFromFile(BuildContext context) async {
    final model = widget.app.model;
    final ext = 'j${model.modelName.toLowerCase()}';
    final typeGroup = XTypeGroup(
        label: 'Calculator State (.$ext)',
        extensions: [ext, ext.toUpperCase()]);
    const any = XTypeGroup(label: 'Calculator State (any extension)');
    final file = await openFile(acceptedTypeGroups: [typeGroup, any]);
    if (file == null) {
      return;
    }
    try {
      widget.app.controller.resetAll();
      final data = await file.readAsString();
      widget.app.model.initializeFromJsonOrUri(data);
    } catch (e, s) {
      debugPrint('\n\n$e\n\n$s');
      widget.app.controller.showMessage('bad fi1e ');
      if (context.mounted) {
        return showErrorDialog(context, 'Bad data in file', e);
      }
    }
  }
}

class _SystemSettingsMenu extends StatefulWidget {
  final String title;
  final Jrpn app;

  const _SystemSettingsMenu(this.title, this.app);

  @override
  _SystemSettingsMenuState createState() => _SystemSettingsMenuState();
}

class _SystemSettingsMenuState extends State<_SystemSettingsMenu> {
  Model get model => widget.app.model;
  Settings get settings => model.settings;

  @override
  Widget build(BuildContext outerContext) {
    final mem = model.memory;
    return PopupMenuButton<Future<void> Function()>(
      // how much the submenu should offset from parent.
      offset: const Offset(-100, 0),
      onSelected: (Future<void> Function() action) async {
        await action();
        setState(() {});
        if (outerContext.mounted) {
          Navigator.pop(outerContext, () {});
        }
      },
      onCanceled: () => Navigator.pop(outerContext),
      itemBuilder: (BuildContext context) => [
        PopupMenuItem(
            child: ListTile(
                leading: SizedBox(
                    width: 70,
                    child: _TextEntry(
                        text: false,
                        initial: settings.msPerInstruction
                            .toString()
                            .replaceFirst(RegExp('.0\$'), ''),
                        onDone: (v) {
                          settings.msPerInstruction = double.tryParse(v);
                          unawaited(
                              widget.app.model.writeToPersistentStorage());
                        })),
                title: const Text('ms/Program Instruction'))),
        PopupMenuItem(
            child: ListTile(
                leading: SizedBox(
                    width: 70,
                    child: _TextEntry(
                        text: false,
                        initial: (mem.totalNybbles - mem.minimumMemoryNybbles)
                            .toString(),
                        onDone: (v) {
                          final dv = double.tryParse(v);
                          if (dv != null) {
                            final mm = mem.minimumMemoryNybbles;
                            final err = mem.changeMemorySize(mm + dv.round());
                            if (err == null) {
                              unawaited(
                                  widget.app.model.writeToPersistentStorage());
                            } else {
                              Future.delayed(
                                  const Duration(milliseconds: 30),
                                  () => showErrorDialog(
                                      Jrpn.lastContext, err, null));
                            }
                          }
                        })),
                title: const Text('Extra memory (nybbles)'))),
        PopupMenuItem(child: _ColorSettingsMenu('Color Settings', widget.app)),
        ...(_filesWork
            ? [
                PopupMenuItem(
                    value: () => _importConfigurationFromFile(context),
                    child: const Row(children: [
                      SizedBox(width: 65),
                      Text('Read layout from File...'),
                    ])),
                PopupMenuItem(
                    value: () => _exportConfigurationToFile(context),
                    child: const Row(children: [
                      SizedBox(width: 65),
                      Text('Write layout to File...'),
                    ])),
              ]
            : [
                PopupMenuItem(
                    value: () => _importConfigurationFromClipboard(context),
                    child: const Row(children: [
                      SizedBox(width: 65),
                      Text('Import layout from Clipboard'),
                    ])),
                PopupMenuItem(
                    value: () => _exportConfigurationToClipboard(context),
                    child: const Row(children: [
                      SizedBox(width: 65),
                      Text('Export layout to Clipboard'),
                    ])),
              ]),
        CheckedPopupMenuItem(
            padding: EdgeInsets.only(
                // Space for the virtual keyboard on Android:
                bottom: model.settings.isMobilePlatform ? 150 : 0),
            checked: model.captureDebugLog,
            value: () async {
              model.captureDebugLog = !model.captureDebugLog;
              model.display.update();
            },
            child: const Row(
                children: [SizedBox(width: 30), Text('Capture Debug\nLog')])),
      ],
      child: Row(
        children: [
          const SizedBox(width: 65),
          Text(widget.title),
          const Spacer(),
          const Icon(Icons.arrow_right, size: 30.0),
        ],
      ),
    );
  }

  Future<void> _exportConfigurationToClipboard(BuildContext context) {
    final jsonMap = widget.app.controller.screenConfig.toJson();
    Clipboard.setData(ClipboardData(text: json.encoder.convert(jsonMap)));
    return Future.value(null);
  }

  Future<void> _exportConfigurationToFile(BuildContext context) async {
    final jsonMap = widget.app.controller.screenConfig.toJson();
    final jsonStr = json.encoder.convert(jsonMap);
    final model = widget.app.model;
    const ext = 'config';
    final suggested = 'jrpn${model.modelName.toLowerCase()}.$ext';
    final typeGroup = XTypeGroup(
        label: 'JRPN Configuration (.$ext)',
        extensions: [ext, ext.toUpperCase()]);
    const any = XTypeGroup(label: 'JRPN Configuration (any extension)');
    final String? path = (await getSaveLocation(
            suggestedName: suggested, acceptedTypeGroups: [typeGroup, any]))
        ?.path;
    if (path == null) {
      return;
    }
    final f = XFile.fromData(utf8.encoder.convert(jsonStr),
        mimeType: 'application/json', name: suggested);
    try {
      await f.saveTo(path);
    } catch (e, s) {
      debugPrint('\n\n$e\n\n$s');
      if (context.mounted) {
        return showErrorDialog(context, 'Error saving', e);
      }
    }
  }

  void _setScreenConfiguration(ScreenConfiguration? config) {
    final controller = widget.app.controller;
    config ??= controller.screenConfig.newFromJson('{}');
    controller.screenConfig = config;
    config.saveToPersistentStore();
    widget.app.setChanged();
  }

  Future<void> _importConfigurationFromClipboard(BuildContext context) async {
    final String? cd;
    try {
      cd = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
    } catch (e) {
      _setScreenConfiguration(null);
      if (context.mounted) {
        return showErrorDialog(context, 'Error accessing clipboard', e);
      } else {
        return;
      }
    }
    if (cd == null) {
      _setScreenConfiguration(null);
      widget.app.controller.showMessage('bad c1ip ');
    } else {
      try {
        _setScreenConfiguration(
            widget.app.controller.screenConfig.newFromJson(cd));
      } catch (e, s) {
        _setScreenConfiguration(null);
        debugPrint('\n\n$e\n\n$s');
        widget.app.controller.showMessage('bad c1ip ');
        if (context.mounted) {
          return showErrorDialog(context, 'Bad data in clipboard', e);
        }
      }
    }
  }

  Future<void> _importConfigurationFromFile(BuildContext context) async {
    const ext = 'config';
    final typeGroup = XTypeGroup(
        label: 'JRPN Configuration (.$ext)',
        extensions: [ext, ext.toUpperCase()]);
    const any = XTypeGroup(label: 'JRPN Configuration (any extension)');
    final file = await openFile(acceptedTypeGroups: [typeGroup, any]);
    if (file == null) {
      return;
    }
    try {
      final data = await file.readAsString();
      _setScreenConfiguration(
          widget.app.controller.screenConfig.newFromJson(data));
    } catch (e, s) {
      _setScreenConfiguration(null);
      debugPrint('\n\n$e\n\n$s');
      widget.app.controller.showMessage('bad fi1e ');
      if (context.mounted) {
        return showErrorDialog(context, 'Bad data in file', e);
      }
    }
  }
}

class _ColorSettingsMenu extends StatefulWidget {
  final String title;
  final Jrpn app;

  const _ColorSettingsMenu(this.title, this.app);

  @override
  _ColorSettingsMenuState createState() => _ColorSettingsMenuState();
}

class _ColorSettingsMenuState extends State<_ColorSettingsMenu> {
  Model get model => widget.app.model;
  Settings get settings => model.settings;

  @override
  Widget build(BuildContext outerContext) {
    return PopupMenuButton<Future<void> Function()>(
      // how much the submenu should offset from parent.
      offset: const Offset(-100, 0),
      onSelected: (Future<void> Function() action) async {
        await action();
        setState(() {});
        if (outerContext.mounted) {
          Navigator.pop(outerContext, () {});
        }
      },
      onCanceled: () => Navigator.pop(outerContext),
      itemBuilder: (BuildContext context) => [
        PopupMenuItem(
            child: ListTile(
                leading: SizedBox(
                    width: 70,
                    child: _TextEntry(
                        text: true,
                        initial: _formatColor(settings.fKeyColor),
                        onDone: (v) {
                          settings.fKeyColor = _toColor(v);
                          widget.app.setChanged();
                          unawaited(
                              widget.app.model.writeToPersistentStorage());
                        })),
                title: const Text('f Key Color'))),
        PopupMenuItem(
            child: ListTile(
                leading: SizedBox(
                    width: 70,
                    child: _TextEntry(
                        text: true,
                        initial: _formatColor(settings.fTextColor),
                        onDone: (v) {
                          settings.fTextColor = _toColor(v);
                          widget.app.setChanged();
                          unawaited(
                              widget.app.model.writeToPersistentStorage());
                        })),
                title: const Text('f Text Color'))),
        PopupMenuItem(
            child: ListTile(
                leading: SizedBox(
                    width: 70,
                    child: _TextEntry(
                        text: true,
                        initial: _formatColor(settings.gKeyColor),
                        onDone: (v) {
                          settings.gKeyColor = _toColor(v);
                          widget.app.setChanged();
                          unawaited(
                              widget.app.model.writeToPersistentStorage());
                        })),
                title: const Text('g Key Color'))),
        PopupMenuItem(
            child: ListTile(
                leading: SizedBox(
                    width: 70,
                    child: _TextEntry(
                        text: true,
                        initial: _formatColor(settings.gTextColor),
                        onDone: (v) {
                          settings.gTextColor = _toColor(v);
                          widget.app.setChanged();
                          unawaited(
                              widget.app.model.writeToPersistentStorage());
                        })),
                title: const Text('g Text Color'))),
        PopupMenuItem(
            child: ListTile(
                leading: SizedBox(
                    width: 70,
                    child: _TextEntry(
                        text: true,
                        initial: _formatColor(settings.lcdBackgroundColor),
                        onDone: (v) {
                          settings.lcdBackgroundColor = _toColor(v);
                          widget.app.setChanged();
                          unawaited(
                              widget.app.model.writeToPersistentStorage());
                        })),
                title: const Text('LCD Background Color'))),
        PopupMenuItem(
            child: ListTile(
                leading: SizedBox(
                    width: 70,
                    child: _TextEntry(
                        text: true,
                        initial: _formatColor(settings.lcdForegroundColor),
                        onDone: (v) {
                          settings.lcdForegroundColor = _toColor(v);
                          widget.app.setChanged();
                          unawaited(
                              widget.app.model.writeToPersistentStorage());
                        })),
                title: const Text('LCD Foreground Color'))),
      ],
      child: Row(
        children: [
          const SizedBox(width: 65),
          Text(widget.title),
          const Spacer(),
          const Icon(Icons.arrow_right, size: 30.0),
        ],
      ),
    );
  }

  String _formatColor(int value) =>
      (value & 0xffffff).toRadixString(16).padLeft(6, '0');
  int? _toColor(String v) {
    final int? i = int.tryParse(v, radix: 16);
    if (i == null) {
      return null;
    } else {
      return i | 0xff000000;
    }
  }
}

Future<void> showErrorDialog(
        BuildContext context, String message, Object? exception) =>
    showDialog(
        context: context,
        builder: (BuildContext context) => ErrorDialog(message, exception));

class ErrorDialog extends StatelessWidget {
  final String message;
  final Object? exception;

  const ErrorDialog(this.message, this.exception, {super.key});

  @override
  Widget build(BuildContext context) {
    String exs = '';
    if (exception != null) {
      exs = 'Error';
      try {
        exs = exception.toString();
      } catch (ex) {
        debugPrint('Error in exception.toString()');
      }
    }
    // return object of type Dialog
    return AlertDialog(
      title: Text(message),
      content: (exception == null)
          ? const Text('')
          : SingleChildScrollView(
              child: Column(children: [
                const SizedBox(height: 20),
                Text(exs),
              ]),
            ),
      actions: <Widget>[
        // usually buttons at the bottom of the dialog
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('OK'),
        )
      ],
    );
  }
}
