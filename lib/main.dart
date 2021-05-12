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
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pedantic/pedantic.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uni_links/uni_links.dart';

import 'c/controller.dart';
import 'm/model.dart';
import 'v/main_screen.dart';

const NON_WARRANTY = '''
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
''';

const MIT_LICENSE = '''
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

$NON_WARRANTY
''';

/// package_info doesn't exist for all platforms, so I'm doing it the old
/// fashioned way.
const APPLICATION_VERSION = '2.0';
const APPLICATION_WEB_ADDRESS = 'https://jrpn.jovial.com';
const APPLICATION_ISSUE_ADDRESS = 'https://github.com/zathras/jrpn/issues';

void main() async {
  // Get there first!
  LicenseRegistry.addLicense(_getLicenses);

  if (!kIsWeb && Platform.isIOS) {
    // Get rid of ugly black bar along bottom.  It doesn't seem to do
    // anything -- maybe to be functional it has to be configured
    // somehow?
    WidgetsFlutterBinding.ensureInitialized();
    SystemChrome.setEnabledSystemUIOverlays([SystemUiOverlay.top]);
  }
  final j = Jrpn(Controller(Model()));
  runApp(j);
}

Stream<LicenseEntry> _getLicenses() async* {
  yield LicenseEntryWithLineBreaks(['jrpn'], MIT_LICENSE);
}

class Jrpn extends StatefulWidget {
  /// The state for a calculator instance is held both in the Controller,
  /// and in the Model referenced by the controller.
  final Controller controller;

  Jrpn(this.controller);

  Model get model => controller.model;

  Future<void> sendUrlToClipboard({required bool comments}) {
    final bytes = ZLibEncoder().encode(_getJson(comments: comments).codeUnits);
    final j = base64UrlEncode(bytes);
    final s = 'https://jrpn.jovial.com/run/index.html?state=$j';
    return Clipboard.setData(ClipboardData(text: s));
  }

  Future<void> sendJsonToExternalApp({required bool comments}) =>
      Share.share(_getJson(comments: comments),
          subject: 'JRPN Calculator State');

  Future<void> sendJsonToClipboard({required bool comments}) =>
      Clipboard.setData(ClipboardData(text: _getJson(comments: comments)));

  String _getJson({required bool comments}) {
    if (comments) {
      return JsonEncoder.withIndent('    ')
              .convert(model.toJson(comments: true)) +
          '\n';
    } else {
      return json.encoder.convert(model.toJson());
    }
  }

  @override
  JrpnState createState() => JrpnState(controller);
}

// ignore: prefer_mixin
class JrpnState extends State<Jrpn> with WidgetsBindingObserver {
  Controller controller;
  bool _initDone = false;
  bool _disposed = false;
  StreamSubscription? _linksSubscription;
  String? _incomingLink;
  Object? _pendingError;
  late final FocusNode keyboard;

  JrpnState(this.controller) {
    keyboard = FocusNode(
        onKey: (FocusNode _, RawKeyEvent e) => controller.keyboard.onKey(e));
  }

  @override
  void initState() {
    super.initState();
    unawaited(_init());
  }

  @override
  void dispose() {
    super.dispose();
    WidgetsBinding.instance!.removeObserver(this);
    _disposed = true;
    _linksSubscription?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'JRPN 16c',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: Material(
            type: MaterialType.transparency, child: _buildScreen(context)));
    // The Material widget is needed for text widgets to work:
    // https://stackoverflow.com/questions/47114639/yellow-lines-under-text-widgets-in-flutter
  }

  Widget _buildScreen(BuildContext context) {
    if (!_initDone) {
      return Container(color: Colors.black54);
    }
    if (_pendingError != null) {
      return _showError(context);
    }
    final link = _incomingLink;
    if (link != null) {
      return _showIncomingLink(link, context);
    }
    return RawKeyboardListener(
        focusNode: keyboard, autofocus: true, child: MainScreen(widget));
  }

  Widget _showIncomingLink(String link, BuildContext context) {
    return AspectRatio(
      aspectRatio: 2 / 3,
      child: Container(
        color: Colors.white,
        child: Column(children: [
          Text(' ',
              style:
                  const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
          Text('Incoming Link',
              style:
                  const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
          SizedBox(height: 30),
          Text('Import the contents of the incoming link?',
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          SizedBox(height: 30),
          Row(children: [
            Spacer(flex: 2),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _incomingLink = null;
                  _importLink(link);
                });
              },
              child: Padding(
                  padding: EdgeInsets.all(5),
                  child: Text('Import', style: TextStyle(fontSize: 20))),
            ),
            Spacer(),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _incomingLink = null;
                });
              },
              child: Padding(
                  padding: EdgeInsets.all(5),
                  child: Text('Discard Link', style: TextStyle(fontSize: 20))),
            ),
            Spacer(flex: 2),
          ])
        ]),
      ),
    );
  }

  Widget _showError(BuildContext context) {
    String exs = 'Error';
    try {
      exs = _pendingError!.toString();
    } catch (ex) {
      print('Error in exception.toString()');
    }
    return Container(
      color: Colors.white,
      child: Column(children: [
        Text(' ',
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
        Text('Error',
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
        SizedBox(height: 30),
        Text(exs,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        SizedBox(height: 30),
        ElevatedButton(
          onPressed: () {
            setState(() {
              _pendingError = null;
            });
          },
          child: Padding(
              padding: EdgeInsets.all(5),
              child: Text('CONTINUE', style: TextStyle(fontSize: 20))),
        ),
      ]),
    );
  }

  void _importLink(String link) {
    controller.resetAll();
    try {
      bool ok = controller.model.initializeFromJsonOrUri(link);
      if (!ok) {
        _pendingError =
            'Link does not contain calculator state.\nCalculator reset.';
      }
    } catch (e) {
      _pendingError = 'Error decoding link:  $e.\nCalculator reset.';
    }
  }

  Future<void> _init() async {
    if (_disposed) {
      return;
    }
    try {
      String? link;
      bool done = false;
      try {
        link = await getInitialLink();
      } on PlatformException catch (_) {} on MissingPluginException catch (_) {}
      if (link != null) {
        try {
          done = controller.model.initializeFromJsonOrUri(link);
        } catch (e, s) {
          print('\n$e:\n\n$s\n');
          _pendingError = e;
        }
      }
      if (!done) {
        try {
          await controller.model.readFromPersistentStorage();
        } catch (e) {
          _pendingError = e;
        }
      }
    } finally {
      setState(() {
        _initDone = true;
      });
    }
    if (!_disposed && (!kIsWeb && (Platform.isAndroid || Platform.isIOS))) {
      try {
        _linksSubscription = linkStream.listen((String? link) {
          setState(() {
            _incomingLink = link;
          });
        }, onError: (Object err) {
          print('Error from linkStream:  $err');
        });
      } catch (e) {
        print('uni_links ignoring stream subscription error');
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      unawaited(widget.controller.model.writeToPersistentStorage());
    }
  }
}
