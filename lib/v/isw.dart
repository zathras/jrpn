library view.isw;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
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
import 'lcd_display.dart';

class InternalStateWindow extends StatelessWidget {
  final state = Observable<String>('');

  InternalStateWindow({super.key});

  static Future<void> launch(
      BuildContext context, Model<Operation> model) async {
    final WindowController window = await DesktopMultiWindow.createWindow('');
    await window.setFrame(const Offset(0, 0) & const Size(1280, 720));
    await window.center();
    await window.setTitle('JRPN Calculator Internals');
    await window.show();
    unawaited(() async {
      for (;;) {
        await Future<void>.delayed(Duration(seconds: 5));
        await DesktopMultiWindow.invokeMethod(window.windowId, 'frob', 'glorp');
      }
    }());
  }

  static Future<bool> takeControl(List<String> args) async {
    if (args.length != 3 || args[0] != 'multi_window') {
      return false;
    }
    final isw = InternalStateWindow();
    runApp(isw);
    isw.setupHandler();
    return true;
  }

  void setupHandler() {
    WidgetsFlutterBinding.ensureInitialized();
    DesktopMultiWindow.setMethodHandler(_handler);
  }

  Future<void> _handler(MethodCall call, int fromWindowID) async {
    // Could check call.method, but we only get the update call
    state.value = call.arguments as String;
    print("@@ ISW got $call from $fromWindowID");
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'JRPN Internal State',
        theme: ThemeData(),
        home: Container(color: Colors.blue));
  }
}
