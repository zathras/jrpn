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

import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jrpn/c/controller.dart';
import 'package:jrpn/c/operations.dart';
import 'package:jrpn/m/model.dart';
import 'package:jrpn15c/main.dart';

import 'programs.dart';

const _programs = [
  _Program('Date and Time/Julian Date from Gregorian Date.15c', ''),
  _Program('Date and Time/Delta Days.15C', ''),
  _Program('HP Journal/HP Journal - 08.1980 p23 - W.M. Kahan.15c', ''),
  _Program(
      'HP-15C Advanced Functions Handbook/HP-15C Advanced Functions Handbook - Pages 067-069.15c',
      ''),
  _Program(
      'HP-15C Advanced Functions Handbook/HP-15C Advanced Functions Handbook - Pages 051-055.15c',
      ''),
  _Program(
      'HP-15C Advanced Functions Handbook/HP-15C Advanced Functions Handbook - Pages 013-016.15c',
      ''),
  _Program(
      'HP-15C Advanced Functions Handbook/HP-15C Advanced Functions Handbook - Pages 034-038.15c',
      ''),
  _Program(
      'HP-15C Advanced Functions Handbook/HP-15C Advanced Functions Handbook - Pages 069-072.15c',
      ''),
  _Program(
      'HP-15C Advanced Functions Handbook/HP-15C Advanced Functions Handbook - Pages 056-058.15c',
      ''),
  _Program(
      'HP-15C Advanced Functions Handbook/HP-15C Advanced Functions Handbook - Pages 018-021.15c',
      ''),
  _Program(
      'HP-15C Owner\'s Handbook/HP-15C Owner\'s Handbook - Pages 070-074.15c',
      ''),
  _Program(
      'HP-15C Owner\'s Handbook/HP-15C Owner\'s Handbook - Pages 181-184.15c',
      ''),
  _Program(
      'HP-15C Owner\'s Handbook/HP-15C Owner\'s Handbook - Pages 189-190.15c',
      ''),
  _Program(
      'HP-15C Owner\'s Handbook/HP-15C Owner\'s Handbook - Pages 102-103.15c',
      ''),
  _Program(
      'HP-15C Owner\'s Handbook/HP-15C Owner\'s Handbook - Pages 093-094.15c',
      ''),
  _Program(
      'HP-15C Owner\'s Handbook/HP-15C Owner\'s Handbook - Pages 104-104.15c',
      ''),
  _Program(
      'HP-15C Owner\'s Handbook/HP-15C Owner\'s Handbook - Pages 184-186.15c',
      ''),
  _Program(
      'HP-15C Owner\'s Handbook/HP-15C Owner\'s Handbook - Pages 014-016.15c',
      ''),
  _Program('Math/Gaussian Integration.15c', ''),
  _Program('Math/Quadratic_Equation.15c', ''),
  _Program('Math/Big_Factorial.15c', ''),
  _Program('Math/Gamma function for complex numbers.15C', ''),
  _Program('Math/LnGammaComplex.15c', ''),
  _Program('Math/Sums of five lists.15c', ''),
  _Program('Math/Halley\'s Method.15c', ''),
  _Program('Math/BinaryToDecimal.15c', ''),
  _Program('Math/Complex Number Utilities.15c', ''),
  _Program('Math/Bairstow\'s Method.15c', ''),
  _Program('Math/Convert to Fraction.15c', ''),
  _Program('Math/Little_Gauss.15c', ''),
  _Program('Math/Calculating 208 digits of e.15c', ''),
  _Program('Math/GCD_LCM.15c', ''),
  _Program('Math/DecimalToBinary.15c', ''),
  _Program('Users/Peter Sels/MasterMind2020.15c', ''),
  _Program('Users/Peter Sels/MasterMindGuessScoring.15c', ''),
  _Program('Users/Peter Sels/HigherLower_v1987.15c', ''),
  _Program('Users/D.G. Simpson/Kepler’s Equation.15c', ''),
  _Program('Users/D.G. Simpson/Helmert’s Equation.15C', ''),
  _Program('Users/D.G. Simpson/Reduction of an Angle.15c', ''),
  _Program('Users/D.G. Simpson/1D Perfectly Elastic Collisions.15C', ''),
  _Program('Users/D.G. Simpson/Barker’s Equation.15c', ''),
  _Program('Users/D.G. Simpson/Projectile Problem.15c', ''),
  _Program('Users/D.G. Simpson/Hyperbolic Kepler’s Equation.15C', ''),
  _Program('Users/D.G. Simpson/Pendulum Period.15C', ''),
  _Program('Users/Eddie Shore/Prime Factorization.15c', ''),
  _Program('Users/Eddie Shore/Sign Function.15c', ''),
  _Program('Users/Eddie Shore/Digital Root.15c', ''),
  _Program('Users/Eddie Shore/Prime Factor.15c', ''),
  _Program('Users/Eddie Shore/Pascal\'s Triangle.15c', ''),
  _Program('Users/Eddie Shore/Quadratic formula.15c', ''),
  _Program('Users/Eddie Shore/Countdown.15c', ''),
  _Program('Users/Eddie Shore/Summation.15c', ''),
  _Program('Users/Eddie Shore/Volume of a Cylinder.15c', ''),
  _Program('Users/Eddie Shore/The Game of Bust.15c', ''),
  _Program(
      'Users/Eddie Shore/Quadratic Equation with Complex Coefficients.15C', ''),
  _Program('Users/Eddie Shore/Extended Statistics Program.15c', ''),
  _Program('Users/Eddie Shore/Modulus Function.15c', ''),
  _Program('Users/Eddie Shore/Numerical Derivative.15c', ''),
  _Program('Users/Eddie Shore/Reactance chart solver.15c', ''),
  _Program('Users/Eddie Shore/Coordinates on an Ellipse.15c', ''),
  _Program('Conversion/Imperial to Metric.15c', ''),
  _Program('Finance/Time_Money.15c', ''),
  _Program('HP-15C Matrix/HP-15C Owner\'s Handbook - Pages 157-159.15c', ''),
  _Program('HP-15C Matrix/HP-15C Owner\'s Handbook - Pages 169-171.15c', ''),
  _Program('HP-15C Matrix/HP-15C Owner\'s Handbook - Pages 138-140.15c', ''),
  _Program('HP-15C Matrix/HP-15C Owner\'s Handbook - Pages 177-179.15c', ''),
  _Program('HP-15C Matrix/HP-15C Owner\'s Handbook - Pages 163-168.15c', ''),
  _Program(
      'HP-15C Matrix/HP-15C Advanced Functions Handbook - Page 100.15c', ''),
  _Program(
      'HP-15C Matrix/HP-15C Owner\'s Handbook - Pages 138-140 random.15c', ''),
  _Program(
      'HP-15C Matrix/HP-15C Owner\'s Handbook - Pages 138-140 general.15c', ''),
  _Program('Games/Hamurabi.15C', ''),
  _Program('Games/Dice.15c', ''),
  _Program('Games/Sudoku Solver.15c', ''),
  _Program('Games/Hanoi Towers.15C', ''),
  _Program('Games/Display_Control.15c', ''),
  _Program('Games/Train.15C', ''),
  _Program(
      'HP Applications Books/Thermal and Transport Science/Ideal Gas Equation of State.15c',
      ''),
  _Program('HP Applications Books/Geometry/Triangle Solutions.15c', ''),
  _Program(
      'HP Applications Books/Mechanical Engineering/Kinetic Engergy.15c', ''),
  _Program(
      'HP Applications Books/Mechanical Engineering/Equations of Motion.15c',
      '264 STO 1 35 ENTER 5280 × 3600 ÷ STO I → 51.3333 '
          '4 STO 0 0 STO 2 STO 3 A RCL 3 → 7.3333 '
          '5 STO 0 0 STO 1 STO 2 A RCL 1 → 348.3333 '
          '264 – → 84.3333'),
  _Program('HP Applications Books/Fun and Games/Biorhythms.15c', ''),
  _Program('HP Applications Books/Fun and Games/Moonlanding.15c', ''),
  _Program(
      'HP Applications Books/Fun and Games/Nimb.15c',
      '3 A 15 B 2 R/S -> -12 3 R/S -> -8 3 R/S -> -4 3 R/S -> 3507.1 '
          '3 A → 3. 1 5 B → -15. 3 R/S  → -9. 2 R/S → '
          '-5. 3 R/S → -1. 1 R/S → 55178',
      pauseValues: [13, 9, 5, 1, 12, 7, 2]),
  _Program(
      'HP Applications Books/Electrical Engineering/Impedance of a Ladder Network.15c',
      '4 EEX 6 A 50 GSB 1 → 50.0000 '
          '2400 EEX CHS 12 GSB 3 → 15.73617024 '
          'x↔y → -71.65588319 '
          '2.56 EEX CHS 6 B GSB 2 → 49.6509 '
          'x↔y → 84.2754 '
          '796 EEX CHS 12 GSB 3 → 497.6942 '
          'x↔y → 0.9840'),
  _Program(
      'HP Applications Books/Electrical Engineering/Reactance Chart.15c',
      '.1 EEX 3 CHS STO 5 .2 EEX CHS 6 STO 6 0 STO 4 B → 22.36067977 '
          'RCL 4 → 35588.12718 '
          '100 STO 4 .1 EEX CHS 6 STO 6 0 STO 5 B → 15915.49431'),
  _Program(
      'HP Applications Books/Electrical Engineering/Ohm\'s Law.15c',
      '43.2 STO 0 .1 STO 1 0 STO 2 STO 3 A -> 4.3200 '
          'RCL 2 -> 432.00 430 STO 2 0 STO 1 STO 3 A '
          '-> 4.340093024 RCL 1 -> 0.1004651163'),
  _Program(
      'HP Applications Books/Electrical Engineering/Series-Parallel Resistor Adding.15c',
      '680 ENTER 120 B 330 + 680 + 220 B 680 ENTER 470 B + → 461.5767072 '
          '10 GSB 1 A → 470.0000'),
];

class _Program {
  static const prefix = 'test/HP-15C_4.4.00_Programs/';
  final String sourcePath;
  final String script;
  final List<double> pauseValues;

  const _Program(this.sourcePath, this.script, {this.pauseValues = const []});

  Future<void> run() async {
    final c = TestCalculator(for15C: true);
    final m = c.model;
    final original = await File('$prefix$sourcePath').readAsBytes();
    m.program.importProgramFromFile(original);

    // Smoke test:  Import program, export it, then re-import it
    final List<String> listing = m.program.listing;
    final toImport = StringBuffer();
    toImport.writeln('# a comment');
    toImport.writeln();
    for (final line in listing) {
      toImport.writeln(line);
    }
    m.program.importProgram(toImport.toString());
    expect(listing, m.program.listing);

    final run = _ProgramRun(script, c, pauseValues: pauseValues);
    await run.run();
  }
}

class _ProgramRun {
  Future<void> Function(String) state = (s) => Future.value(null);
  String script;
  TestCalculator c;
  final StreamIterator<ProgramEvent> out;
  final List<double> pauseValues;
  int pauseCount = 0;

  static final letters = <String, Operation>{
    'A': Operations15.letterLabelA,
    'B': Operations15.letterLabelB,
    'C': Operations15.letterLabelC,
    'D': Operations15.letterLabelD,
    'E': Operations15.letterLabelE
  };

  static final numbers = <String, Operation>{
    // Also other keys in labels
    '.': Operations.dot,
    '0': Operations.n0,
    '1': Operations.n1,
    '2': Operations.n2,
    '3': Operations.n3,
    '4': Operations.n4,
    '5': Operations.n5,
    '6': Operations.n6,
    '7': Operations.n7,
    '8': Operations.n8,
    '9': Operations.n9,
    'I': Operations15.I15
  };

  static final otherOperations = <String, Operation>{
    'ENTER': Operations.enter,
    'EEX': Operations.eex,
    'CHS': Operations.chs,
    'STO': Operations15.sto15,
    'RCL': Operations15.rcl15,
    '+': Operations15.plus,
    '×': Operations15.mult,
    '*': Operations15.mult,
    '÷': Operations15.div,
    '/': Operations15.div,
    '-': Operations15.minus,
    '–': Operations15.minus,
    'x↔y': Operations.xy,
  };

  _ProgramRun(this.script, this.c, {required this.pauseValues})
      : out = StreamIterator<ProgramEvent>(c.output.stream);

  Future<void> run() async {
    state = normalState;
    for (final keys in script.split(' ')) {
      if (keys.isNotEmpty) {
        print(' @@ $keys @@');
        await state(keys);
      }
    }
  }

  Future<void> normalState(String keys) async {
    final v = double.tryParse(keys);
    if (v != null) {
      for (int i = 0; i < keys.length; i++) {
        play(numbers[keys[i]]!);
      }
    } else if (letters[keys] != null) {
      state = gsbState;
      await state(keys);
    } else if (keys == '->' || keys == '→') {
      state = expectState;
    } else if (keys == 'GSB') {
      state = gsbState;
      play(Operations15.gsb);
    } else if (keys == 'R/S') {
      play(Operations.rs);
      await waitProgramDone();
    } else {
      final op = otherOperations[keys];
      expect(op != null, true, reason: keys);
      play(op!);

      if (keys == 'STO' || keys == 'RCL') {
        state = stoRclState;
      }
    }
  }

  Future<void> gsbState(String keys) {
    playLabel(keys);
    return waitProgramDone();
  }

  Future<void> waitProgramDone() async {
    for (;;) {
      expect(await out.moveNext(), true);
      if (out.current == ProgramEvent.runStop) {
        expect(await out.moveNext(), true);
        expect(out.current, ProgramEvent.stop);
        break;
      } else if (out.current.pauseValue != null) {
        expect(c.model.formatValue(out.current.pauseValue!),
            c.model.formatValue(Value.fromDouble(pauseValues[pauseCount++])));
        c.resume();
      } else {
        expect(out.current, ProgramEvent.done);
        break;
      }
    }
    state = normalState;
  }

  void playLabel(String keys) {
    for (int i = 0; i < keys.length; i++) {
      final ch = keys[i];
      final op = letters[ch] ?? numbers[ch];
      expect(op != null, true);
      play(op!);
    }
  }

  Future<void> stoRclState(String keys) async {
    playLabel(keys);
    state = normalState;
  }

  Future<void> expectState(String keys) async {
    final v = double.parse(keys);
    expect(c.model.formatValue(c.model.x),
        c.model.formatValue(Value.fromDouble(v)));
    state = normalState;
  }

  void play(Operation op) {
    c.controller.buttonDown(op);
    c.controller.buttonUp();
  }
}

void test15cPrograms() {
  for (final p in _programs) {
    test(p.sourcePath, p.run);
  }
}

// @@ TODO:  Run programs
