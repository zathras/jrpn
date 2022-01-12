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
/// The main screen of the calculator.  It uses [ScreenPositioner] to
/// exactly position widgets, and scale them to the screen size.
///
library view.main_screen;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jovial_svg/jovial_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import '../c/controller.dart';
import '../m/model.dart';
import '../generic_main.dart';
import 'buttons.dart';
import 'lcd_display.dart';

// See the library comments, above!  (Android Studio  hides them by default.)

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
  const OrientedScreen({Key? key}) : super(key: key);

  static final ScreenPositioner landscape = ScreenPositioner(12.7, 8);
  static final ScreenPositioner portrait = ScreenPositioner(8, 12.7);

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
  final Jrpn app;
  final ScalableImage icon;

  const MainScreen(this.app, this.icon, {Key? key}) : super(key: key);

  Controller get controller => app.controller;
  Model get model => app.model;

  /// Midnight blue for area outside of calculator UI
  static const deadZoneColor = Color(0xff00002f);

  static const keyboardBaseColor = Color(0xff373436);

  /// Silver frame around the keys keys
  static const keyFrameSilver = Color(0xffdbdad1);

  @override
  Widget buildPortrait(BuildContext context, final ScreenPositioner screen) {
    return Container(
        alignment: Alignment.center,
        color: deadZoneColor,
        child: AspectRatio(
            aspectRatio: screen.width / screen.height,
            child: Stack(fit: StackFit.expand, children: [
              screen.box(Rect.fromLTWH(0, 0, screen.width, screen.height),
                  CustomPaint(painter: DrawnBackground(screen))),
              screen.box(Rect.fromLTWH(0.60, screen.height - 1.5, 0.94, 0.94),
                  _jrpnIcon()),
              screen.box(
                  const Rect.fromLTWH(
                      0.63, 0.6, 6.7, 1.5 * LcdDisplay.heightTweak),
                  LcdDisplay(controller.model, _showMenu)),
              ...PortraitButtonFactory(context, screen, controller)
                  .buildButtons(Rect.fromLTRB(
                      0.7, 2.75, screen.width - 0.7, screen.height - 0.47)),
              MainMenu(this, screen)
            ])));
  }

  @override
  Widget buildLandscape(BuildContext context, final ScreenPositioner screen) {
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
                CustomPaint(painter: DrawnBackground(screen))),
            screen.box(Rect.fromLTWH(screen.width - 1.82, 0.65, 0.94, 0.94),
                _jrpnIcon()),
            screen.box(
                const Rect.fromLTWH(
                    2.0, 0.6, 6.7, 1.5 * LcdDisplay.heightTweak),
                LcdDisplay(controller.model, _showMenu)),
            ...LandscapeButtonFactory(context, screen, controller).buildButtons(
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
              child: Row(children: const [
                Icon(Icons.content_copy),
                Text('Copy to Clipboard')
              ])),
          PopupMenuItem(
              value: _pasteNumberToModel,
              child: Row(children: const [
                Icon(Icons.content_copy),
                Text('Paste from Clipboard')
              ])),
        ]);
    if (f != null) {
      f(context);
    }
  }

  void _copyDisplayToClipboard(BuildContext _) {
    String displayed = model.display.currentWithoutWindow;
    Clipboard.setData(ClipboardData(text: displayed));
  }

  void _pasteNumberToModel(BuildContext context) {
    unawaited(() async {
      final String? cd;
      try {
        cd = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
      } catch (e) {
        return showErrorDialog(context, 'Error accessing clipboard', e);
      }
      if (cd == null || cd == '') {
        return showErrorDialog(context, 'Empty clipboard', null);
      }
      if (model.isRunningProgram) {
        return showErrorDialog(context, 'Program is running', null);
      }
      if (!controller.pasteToX(cd)) {
        return showErrorDialog(context, 'Number format error', null);
      }
    }());
  }

  Widget _jrpnIcon() {
    final Paint p = Paint()
      ..color = const Color(0xffe6edf5)
      ..style = PaintingStyle.fill;
    const border = 3;
    return Container(
        color: Colors.black,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(flex: border),
            Expanded(
              flex: 100,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Spacer(flex: border),
                    Expanded(
                        flex: 64,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CustomPaint(
                                painter: _RoundedBox(widthCM: 0.9, paint: p)),
                            Center(child: ScalableImageWidget(si: icon))
                            // SvgPicture.asset('assets/jupiter.svg'))
                          ],
                        )),
                    const Spacer(flex: 2),
                    Expanded(
                        flex: 34,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CustomPaint(
                                painter: _RoundedBox(widthCM: 0.9, paint: p)),
                            CustomPaint(
                                painter: _ScaledText(
                                    text: model.modelName,
                                    widthCM: 0.9,
                                    embiggen: 1.25,
                                    style: const TextStyle(
                                        fontSize: 0.3, // in cm
                                        fontFamily: 'LogoFont',
                                        fontWeight: FontWeight.w500,
                                        color: Colors.black))),
                          ],
                        )),
                    const Spacer(flex: border),
                  ]),
            ),
            const Spacer(flex: border),
          ],
        ));
  }
}

///
/// Draw the background of the calculator.
///
class DrawnBackground extends CustomPainter {
  final ScreenPositioner screen;

  DrawnBackground(this.screen);

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
    double y = 2.5 * cm;

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

/// A rounded box for the logo
class _RoundedBox extends CustomPainter {
  final double widthCM;
  final Paint paintArg;

  _RoundedBox({required this.widthCM, required Paint paint}) : paintArg = paint;

  @override
  void paint(Canvas c, Size size) {
    final double cm = size.width / widthCM;
    final outlineR = Radius.circular(0.05 * cm);
    c.drawRRect(
        RRect.fromLTRBR(0, 0, size.width, size.height, outlineR), paintArg);
  }

  @override
  bool shouldRepaint(covariant _RoundedBox oldDelegate) {
    return false; // We never change
  }
}

/// Scaled text for the logo
class _ScaledText extends CustomPainter {
  final String text;
  final TextStyle style;
  final double widthCM;
  final double embiggen;

  _ScaledText(
      {required this.text,
      required this.style,
      required this.widthCM,
      required this.embiggen});

  @override
  void paint(Canvas c, Size size) {
    final span = TextSpan(style: style, text: text);
    final double cm = size.width / widthCM;
    TextPainter tp = TextPainter(
        text: span,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr);
    tp.layout();
    c.save();
    c.translate(
        (size.width - tp.width * cm * embiggen) / 2, size.height * 0.85);
    c.scale(cm * embiggen, cm);
    tp.paint(c, Offset.zero);
    c.restore();
  }

  @override
  bool shouldRepaint(covariant _ScaledText oldDelegate) {
    return false; // We never change
  }
}

///
/// The application's main menu.
///
class MainMenu extends StatefulWidget {
  final MainScreen main;
  final ScreenPositioner screen;

  const MainMenu(this.main, this.screen, {Key? key}) : super(key: key);

  @override
  _MainMenuState createState() => _MainMenuState();
}

class _MainMenuState extends State<MainMenu> {
  Model get model => widget.main.model;
  Controller get controller => widget.main.controller;
  ScreenPositioner get screen => widget.screen;

  void _enabledChanged(bool v) => setState(() {});

  @override
  void initState() {
    model.settings.menuEnabled.addObserver(_enabledChanged);
    super.initState();
  }

  @override
  void dispose() {
    model.settings.menuEnabled.removeObserver(_enabledChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final children = List<Widget>.empty(growable: true);
    final Rect menuIconPosition;
    final Rect menuHitArea;
    if (widget.screen == OrientedScreen.portrait) {
      menuIconPosition = Rect.fromLTWH(screen.width - 1, 0.1, 0.7, 0.7);
      menuHitArea = Rect.fromLTWH(screen.width - 1, 0, 1, 1);
    } else {
      menuIconPosition = Rect.fromLTWH(screen.width - 1, 0.1, 1, 1);
      menuHitArea = Rect.fromLTWH(screen.width - 2, 0, 2, 2);
    }
    if (model.settings.menuEnabled.value) {
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
                value: () {},
                child: _StateMenu('Calculator State', widget.main.app)),
            PopupMenuItem(
                value: () {}, child: _SettingsMenu('Settings', model)),
            // PopupMenuDivider(),
            PopupMenuItem(
                value: () {}, child: _HelpMenu('Help', widget.main.icon, controller))
          ];
        },
      );
}

class _HelpMenu extends StatelessWidget {
  final String title;
  final ScalableImage icon;
  final Controller controller;

  const _HelpMenu(this.title, this.icon, this.controller, {Key? key}) : super(key: key);

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
              unawaited(
                  showDialog(context: context, builder: _showNonWarranty));
            },
            child: const Text('Non-warranty')),
        PopupMenuItem(
            value: () {
              Navigator.pop<void>(context);
              launch(applicationIssueAddress);
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
                  applicationLegalese: '© 2021, 2022 Bill Foote',
                  children: [
                    const SizedBox(height: 40),
                    InkWell(
                        onTap: () => unawaited(launch(applicationWebAddress)),
                        child: RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                                style: TextStyle(
                                    fontSize: 18,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .secondary),
                                text: applicationWebAddress)))
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
  final Model model;
  const _SettingsMenu(this.title, this.model, {Key? key}) : super(key: key);

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
            checked: settings.menuEnabled.value,
            value: () {
              settings.menuEnabled.value = !settings.menuEnabled.value;
            },
            child: const Text('Show Menu Icon')),
        CheckedPopupMenuItem(
            checked: settings.windowEnabled,
            value: () {
              settings.windowEnabled = !settings.windowEnabled;
              display.update();
            },
            child: const Text('Enable Window')),
        CheckedPopupMenuItem(
            checked: settings.hideComplement,
            value: () {
              settings.hideComplement = !settings.hideComplement;
              display.update();
            },
            child: const Text('Hide Complement Status')),
        CheckedPopupMenuItem(
            checked: settings.showWordSize,
            value: () {
              settings.showWordSize = !settings.showWordSize;
              display.update();
            },
            child: const Text('Show Word Size')),
        CheckedPopupMenuItem(
            checked: settings.showAccelerators.value,
            value: () {
              settings.showAccelerators.value =
                  !settings.showAccelerators.value;
            },
            child: const Text('Show Accelerators (toggle with "?")')),
        CheckedPopupMenuItem(
            checked: widget.model.captureDebugLog,
            value: () {
              widget.model.captureDebugLog = !widget.model.captureDebugLog;
              widget.model.display.update();
            },
            child: const Text('Capture Debug Log')),
        ...(settings.isMobilePlatform
            ? [
                CheckedPopupMenuItem(
                    checked: settings.systemOverlaysDisabled,
                    value: () => settings.systemOverlaysDisabled =
                        !settings.systemOverlaysDisabled,
                    child: const Text('Disable System UI Overlays')),
                PopupMenuItem(
                    child: Row(children: [
                  DropdownButton(
                      value: settings.orientation,
                      onChanged: (OrientationSetting? v) {
                        if (v != null) {
                          settings.orientation = v;
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
                ]))
              ]
            : []),
        PopupMenuItem(
            child: ListTile(
                leading: SizedBox(
                    width: 40,
                    child: _TextEntry(
                        initial: settings.msPerInstruction
                            .toString()
                            .replaceFirst(RegExp('.0\$'), ''),
                        onDone: (v) {
                          settings.msPerInstruction = double.tryParse(v);
                        })),
                title: const Text('ms/Program Instruction'))),
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

  const _TextEntry({required this.initial, required this.onDone}) : super();

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
        keyboardType: TextInputType.number,
        // We could do an onSubmitted: here, if the
        // virtual keyboard is covering the entered value, the user never
        // gets to see the entry.  On desktop (April 2021, before desktop
        // support was finalized), we never saw onSubmitted.
      );
}

class _StateMenu extends StatefulWidget {
  final String title;
  final Jrpn app;

  const _StateMenu(this.title, this.app, {Key? key}) : super(key: key);

  @override
  __StateMenuState createState() => __StateMenuState();
}

class __StateMenuState extends State<_StateMenu> {
  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<Future<void> Function()>(
      // how much the submenu should offset from parent.
      offset: const Offset(-100, 0),
      onSelected: (Future<void> Function() action) async {
        await action();
        setState(() {});
        Navigator.pop(context, () {});
      },
      onCanceled: () => Navigator.pop(context),
      itemBuilder: (BuildContext context) => [
        PopupMenuItem(
          value: () => widget.app.model.writeToPersistentStorage(),
          child: const Text('Save'),
        ),
        PopupMenuItem(
          value: () {
            widget.app.controller.resetAll();
            return widget.app.model.resetFromPersistentStorage();
          },
          child: const Text('Restore from Saved'),
        ),
        PopupMenuItem(
            value: () async {},
            child: _ExportMenu('Share State', widget.app, false)),
        PopupMenuItem(
            value: () async {},
            child: _ExportMenu('State with Comments', widget.app, true)),
        PopupMenuItem(
          value: () => _pasteFromClipboard(context),
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

  Future<void> _pasteFromClipboard(BuildContext context) async {
    final String? cd;
    try {
      cd = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
    } catch (e) {
      return showErrorDialog(context, 'Error accessing clipboard', e);
    }
    if (cd == null) {
      widget.app.controller.showMessage('bad c1ip ');
    } else {
      try {
        widget.app.model.initializeFromJsonOrUri(cd);
      } catch (e, s) {
        debugPrint('\n\n$e\n\n$s');
        widget.app.controller.showMessage('bad c1ip ');
        return showErrorDialog(context, 'Bad data in clipboard', e);
      }
    }
  }
}

class _ExportMenu extends StatefulWidget {
  final String title;
  final Jrpn app;
  final bool comments;

  const _ExportMenu(this.title, this.app, this.comments, {Key? key})
      : super(key: key);

  @override
  __ExportMenuState createState() => __ExportMenuState();
}

class __ExportMenuState extends State<_ExportMenu> {
  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<Future<void> Function()>(
      // how much the submenu should offset from parent.
      offset: const Offset(-100, 0),
      onSelected: (Future<void> Function() action) async {
        await action();
        setState(() {});
        Navigator.pop<Future<void> Function()>(context, () async {});
      },
      itemBuilder: (BuildContext context) => [
        PopupMenuItem(
          value: () =>
              widget.app.sendJsonToClipboard(comments: widget.comments),
          child: const Text('Copy to Clipboard'),
        ),
        PopupMenuItem(
          value: () =>
              widget.app.sendJsonToExternalApp(comments: widget.comments),
          child: const Text('Export to Application'),
        ),
        PopupMenuItem(
          value: () => widget.app.sendUrlToClipboard(comments: widget.comments),
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
}

Future<void> showErrorDialog(
        BuildContext context, String message, Object? exception) =>
    showDialog(
        context: context,
        builder: (BuildContext context) => ErrorDialog(message, exception));

class ErrorDialog extends StatelessWidget {
  final String message;
  final Object? exception;

  const ErrorDialog(this.message, this.exception, {Key? key}) : super(key: key);

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
