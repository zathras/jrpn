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

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jrpn/c/operations.dart';
import 'package:jrpn/m/model.dart';

import 'programs.dart';

const _programs = [
  _Program('Date and Time/Julian Date from Gregorian Date.15c'),
  _Program('Date and Time/Delta Days.15C'),
  _Program('HP Journal/HP Journal - 08.1980 p23 - W.M. Kahan.15c'),
  _Program(
      'HP-15C Advanced Functions Handbook/HP-15C Advanced Functions Handbook - Pages 067-069.15c'),
  _Program(
      'HP-15C Advanced Functions Handbook/HP-15C Advanced Functions Handbook - Pages 051-055.15c'),
  _Program(
      'HP-15C Advanced Functions Handbook/HP-15C Advanced Functions Handbook - Pages 013-016.15c'),
  _Program(
      'HP-15C Advanced Functions Handbook/HP-15C Advanced Functions Handbook - Pages 034-038.15c'),
  _Program(
      'HP-15C Advanced Functions Handbook/HP-15C Advanced Functions Handbook - Pages 069-072.15c'),
  _Program(
      'HP-15C Advanced Functions Handbook/HP-15C Advanced Functions Handbook - Pages 056-058.15c'),
  _Program(
      'HP-15C Advanced Functions Handbook/HP-15C Advanced Functions Handbook - Pages 018-021.15c'),
  _Program(
      'HP-15C Owner\'s Handbook/HP-15C Owner\'s Handbook - Pages 070-074.15c'),
  _Program(
      'HP-15C Owner\'s Handbook/HP-15C Owner\'s Handbook - Pages 181-184.15c'),
  _Program(
      'HP-15C Owner\'s Handbook/HP-15C Owner\'s Handbook - Pages 189-190.15c'),
  _Program(
      'HP-15C Owner\'s Handbook/HP-15C Owner\'s Handbook - Pages 102-103.15c'),
  _Program(
      'HP-15C Owner\'s Handbook/HP-15C Owner\'s Handbook - Pages 093-094.15c'),
  _Program(
      'HP-15C Owner\'s Handbook/HP-15C Owner\'s Handbook - Pages 104-104.15c'),
  _Program(
      'HP-15C Owner\'s Handbook/HP-15C Owner\'s Handbook - Pages 184-186.15c'),
  _Program(
      'HP-15C Owner\'s Handbook/HP-15C Owner\'s Handbook - Pages 014-016.15c'),
  _Program('Math/Gaussian Integration.15c'),
  _Program('Math/Quadratic_Equation.15c'),
  _Program('Math/Big_Factorial.15c'),
  _Program('Math/Gamma function for complex numbers.15C'),
  _Program('Math/LnGammaComplex.15c'),
  _Program('Math/Sums of five lists.15c'),
  _Program('Math/Halley\'s Method.15c'),
  _Program('Math/BinaryToDecimal.15c'),
  _Program('Math/Complex Number Utilities.15c'),
  _Program('Math/Bairstow\'s Method.15c'),
  _Program('Math/Convert to Fraction.15c'),
  _Program('Math/Little_Gauss.15c'),
  _Program('Math/Calculating 208 digits of e.15c'),
  _Program('Math/GCD_LCM.15c'),
  _Program('Math/DecimalToBinary.15c'),
  _Program('Users/Peter Sels/MasterMind2020.15c'),
  _Program('Users/Peter Sels/MasterMindGuessScoring.15c'),
  _Program('Users/Peter Sels/HigherLower_v1987.15c'),
  _Program('Users/D.G. Simpson/Kepler’s Equation.15c'),
  _Program('Users/D.G. Simpson/Helmert’s Equation.15C'),
  _Program('Users/D.G. Simpson/Reduction of an Angle.15c'),
  _Program('Users/D.G. Simpson/1D Perfectly Elastic Collisions.15C'),
  _Program('Users/D.G. Simpson/Barker’s Equation.15c'),
  _Program('Users/D.G. Simpson/Projectile Problem.15c'),
  _Program('Users/D.G. Simpson/Hyperbolic Kepler’s Equation.15C'),
  _Program('Users/D.G. Simpson/Pendulum Period.15C'),
  _Program('Users/Eddie Shore/Prime Factorization.15c'),
  _Program('Users/Eddie Shore/Sign Function.15c'),
  _Program('Users/Eddie Shore/Digital Root.15c'),
  _Program('Users/Eddie Shore/Prime Factor.15c'),
  _Program('Users/Eddie Shore/Pascal\'s Triangle.15c'),
  _Program('Users/Eddie Shore/Quadratic formula.15c'),
  _Program('Users/Eddie Shore/Countdown.15c'),
  _Program('Users/Eddie Shore/Summation.15c'),
  _Program('Users/Eddie Shore/Volume of a Cylinder.15c'),
  _Program('Users/Eddie Shore/The Game of Bust.15c'),
  _Program(
      'Users/Eddie Shore/Quadratic Equation with Complex Coefficients.15C'),
  _Program('Users/Eddie Shore/Extended Statistics Program.15c'),
  _Program('Users/Eddie Shore/Modulus Function.15c'),
  _Program('Users/Eddie Shore/Numerical Derivative.15c'),
  _Program('Users/Eddie Shore/Reactance chart solver.15c'),
  _Program('Users/Eddie Shore/Coordinates on an Ellipse.15c'),
  _Program('Conversion/Imperial to Metric.15c'),
  _Program('Finance/Time_Money.15c'),
  _Program('HP-15C Matrix/HP-15C Owner\'s Handbook - Pages 157-159.15c'),
  _Program('HP-15C Matrix/HP-15C Owner\'s Handbook - Pages 169-171.15c'),
  _Program('HP-15C Matrix/HP-15C Owner\'s Handbook - Pages 138-140.15c'),
  _Program('HP-15C Matrix/HP-15C Owner\'s Handbook - Pages 177-179.15c'),
  _Program('HP-15C Matrix/HP-15C Owner\'s Handbook - Pages 163-168.15c'),
  _Program('HP-15C Matrix/HP-15C Advanced Functions Handbook - Page 100.15c'),
  _Program('HP-15C Matrix/HP-15C Owner\'s Handbook - Pages 138-140 random.15c'),
  _Program(
      'HP-15C Matrix/HP-15C Owner\'s Handbook - Pages 138-140 general.15c'),
  _Program('Games/Hamurabi.15C'),
  _Program('Games/Dice.15c'),
  _Program('Games/Sudoku Solver.15c'),
  _Program('Games/Hanoi Towers.15C'),
  _Program('Games/Display_Control.15c'),
  _Program('Games/Train.15C'),
  _Program(
      'HP Applications Books/Thermal and Transport Science/Ideal Gas Equation of State.15c'),
  _Program('HP Applications Books/Geometry/Triangle Solutions.15c'),
  _Program('HP Applications Books/Mechanical Engineering/Kinetic Engergy.15c'),
  _Program(
      'HP Applications Books/Mechanical Engineering/Equations of Motion.15c'),
  _Program('HP Applications Books/Fun and Games/Biorhythms.15c'),
  _Program('HP Applications Books/Fun and Games/Moonlanding.15c'),
  _Program('HP Applications Books/Fun and Games/Nimb.15c'),
  _Program(
      'HP Applications Books/Electrical Engineering/Impedance of a Ladder Network.15c'),
  _Program('HP Applications Books/Electrical Engineering/Reactance Chart.15c'),
  _Program('HP Applications Books/Electrical Engineering/Ohm\'s Law.15c'),
  _Program(
      'HP Applications Books/Electrical Engineering/Series-Parallel Resistor Adding.15c')
];

class _Program {
  static const prefix = 'test/HP-15C_4.4.00_Programs/';
  final String sourcePath;

  const _Program(this.sourcePath);

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
  }
}

void test15cPrograms() {
  for (final p in _programs) {
    test(p.sourcePath, p.run);
  }
}

// @@ TODO:  Run programs
