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
/// The back panel of the calculator.
///

import 'package:flutter/material.dart';
import 'package:jrpn/v/main_screen.dart';
import 'package:jrpn/v/back_panel.dart';

///
/// The calculator's back panel.
///
class BackPanel15 extends BackPanel {
  const BackPanel15({Key? key}) : super(key: key);

  @override
  Widget buildPortrait(BuildContext context, final ScreenPositioner screen) {
    return GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
            alignment: Alignment.center,
            color: MainScreen.deadZoneColor,
            child: AspectRatio(
                aspectRatio: screen.width / screen.height,
                child: Stack(fit: StackFit.expand, children: [
                  Container(color: MainScreen.keyboardBaseColor),
                  screen.box(Rect.fromLTWH(screen.width - 0.8, 0.0, 0.8, 0.8),
                      const Icon(Icons.arrow_back, color: Colors.white)),
                  screen.box(const Rect.fromLTWH(1.175, 1.5, 5.65, 6.5),
                      const Text('@@ TODO')),
                ]))));
  }

  @override
  Widget buildBackPanelPortrait(
      BuildContext context, final ScreenPositioner screen) =>
      Stack(fit: StackFit.expand, children: [
        Container(color: MainScreen.keyboardBaseColor),
        screen.box(Rect.fromLTWH(screen.width - 0.8, 0.0, 0.8, 0.8),
            const Icon(Icons.arrow_back, color: Colors.white)),
        screen.box(const Rect.fromLTWH(1.175, 1.5, 5.65, 6.5),
            const Text('@@ TODO')),
      ]);

  @override
  Widget buildBackPanelLandscape(
      BuildContext context, final ScreenPositioner screen) =>
      Stack(fit: StackFit.expand, children: [
        Container(color: MainScreen.keyboardBaseColor),
        screen.box(const Rect.fromLTWH(11.8, 0.0, 0.8, 0.8),
            const Icon(Icons.arrow_back, color: Colors.white)),
        screen.box(
            const Rect.fromLTWH(0.10, 3, 4.97, 4), const Text('@@ TODO')),
      ]);
}
