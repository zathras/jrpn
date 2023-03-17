/*
Copyright (c) 2023 William Foote

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

library view.isw;

import 'dart:async';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../m/model.dart';

bool _linuxBug = !kIsWeb && Platform.isLinux;
const _linuxBugText =
    'NOTE:  On the Linux snap, closing this window exits calculator.  See issue 32.\n\n';

///
/// A separate (desktop) window showing the internal state
///
class InternalStateWindow extends StatelessWidget {
  final state = Observable<ModelSnapshot>(ModelSnapshot(null, ''));

  InternalStateWindow({super.key});

  static Future<void> launch(BuildContext context, Model model) async {
    final WindowController window = await DesktopMultiWindow.createWindow('');
    await window.setFrame(const Offset(0, 0) & const Size(600, 720));
    await window.center();
    await window.setTitle('JRPN Calculator Internals');
    await window.show();

    late final void Function(void) observerRef;
    bool hasLaunched = false;
    void observer(void _) async {
      try {
        await DesktopMultiWindow.invokeMethod(
            window.windowId, 'frob', model.internalSnapshot.value.text);
        hasLaunched = true;
      } catch (ex) {
        if (hasLaunched) {
          model.internalSnapshot.removeObserver(observerRef);
          model.optimizeInternalSnapshot();
          hasLaunched = false;
        }
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
    state.value = ModelSnapshot(null, call.arguments as String);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'JRPN Internal State',
        theme: ThemeData(),
        home: _TextViewer(state));
  }
}

///
/// A panel showing the internal state, for platforms where a separate window
/// can't be launched.
///
class InternalStatePanel extends StatelessWidget {
  final Model model;

  const InternalStatePanel(this.model, {super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Stack(children: [
          Container(
              color: Colors.black,
              child: _TextViewer(model.internalSnapshot, directModel: model)),
          const Positioned(
              top: 16,
              right: 16,
              child: Icon(Icons.arrow_back, color: Colors.white))
        ]));
  }
}

class _TextViewer extends StatefulWidget {
  final Observable<ModelSnapshot> text;
  final Model? directModel;

  const _TextViewer(this.text, {this.directModel});

  @override
  State<_TextViewer> createState() => _TextViewerState();
}

class _TextViewerState extends State<_TextViewer> {
  late final _newTextRef = _newText;

  @override
  void initState() {
    super.initState();
    widget.text.addObserver(_newTextRef);
  }

  @override
  void dispose() {
    super.dispose();
    widget.text.removeObserver(_newTextRef);
    widget.directModel?.optimizeInternalSnapshot();
  }

  void _newText(ModelSnapshot text) {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        padding: const EdgeInsets.fromLTRB(10, 25, 10, 10),
        color: Colors.black,
        child: InteractiveViewer(
            constrained: false,
            minScale: 0.25,
            maxScale: 10,
            boundaryMargin: const EdgeInsets.all(double.infinity),
            child: Text(
              _linuxBug
                  ? _linuxBugText + widget.text.value.text
                  : widget.text.value.text,
              softWrap: false,
              overflow: TextOverflow.visible,
              style: const TextStyle(
                fontSize: 16.0,
                fontFamily: 'Courier',
                fontFamilyFallback: ['LiberationMono'],
                color: Colors.amberAccent,
                backgroundColor: Colors.black,
                decoration: TextDecoration.none,
              ),
            )));
  }
}
