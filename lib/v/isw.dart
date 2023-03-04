library view.isw;

import 'dart:async';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../m/model.dart';

class InternalStateWindow extends StatelessWidget {
  final state = Observable<String>('');

  InternalStateWindow({super.key});

  static Future<void> launch(BuildContext context, Model model) async {
    final WindowController window = await DesktopMultiWindow.createWindow('');
    await window.setFrame(const Offset(0, 0) & const Size(600, 720));
    await window.center();
    await window.setTitle('JRPN Calculator Internals');
    await window.show();

    late final void Function(void) observerRef;

    void observer(void _) async {
      try {
        await DesktopMultiWindow.invokeMethod(
            window.windowId, 'frob', model.internalSnapshot.value.text);
      } catch (ex) {
        model.internalSnapshot.removeObserver(observerRef);
        model.optimizeInternalSnapshot();
      }
    }

    observerRef = observer;

    model.internalSnapshot.addObserver(observerRef);
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
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'JRPN Internal State',
        theme: ThemeData(),
        home: _TextViewer(state));
  }
}

class _TextViewer extends StatefulWidget {
  final Observable<String> text;

  const _TextViewer(this.text);

  @override
  State<_TextViewer> createState() => _TextViewerState();
}

class _TextViewerState extends State<_TextViewer> {
  @override
  void initState() {
    super.initState();
    widget.text.addObserver(_newText);
  }

  @override
  void dispose() {
    super.dispose();
    widget.text.removeObserver(_newText);
  }

  void _newText(String text) {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        margin: const EdgeInsets.fromLTRB(10, 25, 10, 10),
        child: InteractiveViewer(
            constrained: false,
            minScale: 0.25,
            maxScale: 10,
            boundaryMargin: const EdgeInsets.all(double.infinity),
            child: Text(
              widget.text.value,
              softWrap: false,
              overflow: TextOverflow.visible,
              style: const TextStyle(
                fontSize: 16.0,
                fontFamily: 'Courier',
                color: Colors.white,
                decoration: TextDecoration.none,
              ),
            )));
  }
}
