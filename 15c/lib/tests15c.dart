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


import 'package:jrpn/m/model.dart';
import 'package:jrpn/c/controller.dart';

import 'main15c.dart';

class SelfTests15 extends SelfTests {
  SelfTests15({bool inCalculator = true}) : super(inCalculator: inCalculator);

  @override
  Model<Operation> newModel() => Model15();

  @override
  Controller newController(Model<Operation> model) => Controller15(model);

  /* @@ TODO:
  @override
  Future<void> runAll() async {
    return super.runAll();
  }
   */
}
