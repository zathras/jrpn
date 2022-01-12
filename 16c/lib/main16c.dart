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

import 'package:jrpn/c/controller.dart';
import 'package:jrpn/generic_main.dart';
import 'package:jrpn/m/model.dart';

import 'tests16c.dart';

void main() async => genericMain(Jrpn(Controller16(Model16())));


class Model16 extends Model<Operation> {

  @override
  bool get displayLeadingZeros => getFlag(3);
  @override
  bool get cFlag => getFlag(4);
  @override
  set cFlag(bool v) => setFlag(4, v);
  @override
  bool get gFlag => getFlag(5);
  @override
  set gFlag(bool v) => setFlag(5, v);

}

class Controller16 extends RealController {

  Controller16(Model<Operation> model) : super(model);

  @override
  SelfTests newSelfTests({bool inCalculator = true}) =>
    SelfTests16(inCalculator: inCalculator);
}