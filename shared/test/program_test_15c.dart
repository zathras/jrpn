// ignore_for_file: avoid_print

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

import 'package:flutter_test/flutter_test.dart';
import 'package:jrpn/c/controller.dart';
import 'package:jrpn/c/operations.dart';
import 'package:jrpn/m/model.dart';
import 'package:jrpn15/main.dart';

import 'programs.dart';

const _programs = [
  _Program('Date and Time/Julian Date from Gregorian Date.15c',
      '7 STO 1 23 STO 2 1982 STO 3 A -> 2445174'),
  _Program(
      'Date and Time/Delta Days.15C',
      'CF 0 04.122007 ENTER 12.072021 A -> 5353.0000 '
          'SF 0 04.122007 ENTER 12.072021 A -> 4969.0000'),
  _Program('HP Journal/HP Journal - 08.1980 p23 - W.M. Kahan.15c',
      '0 ENTER 1 INTEGRATE A -> 1.8130 X<=>Y -> 9.6089e-7'),
  _Program(
      'HP-15C Advanced Functions Handbook/HP-15C Advanced Functions Handbook - Pages 067-069.15c',
      '100 ENTER 1 A -> 1 RE<=>IM -> 0 RE<=>IM '
          'R/S -> 0.9980 RE<=>IM -> 0.0628 50 STO I '
          '0 ENTER ENTER ENTER RCL I -> 50 '
          'R/S -> -1 RE<=>IM -> 1.2246e-16'),
  _Program(
      'HP-15C Advanced Functions Handbook/HP-15C Advanced Functions Handbook - Pages 051-055.15c',
      '20 f B → 2.7536e-89 1.234 A -> 8.914e-1 .5 E -> 0.5205 '
          '2 ENTER 2.151 - 1.085 / f A → 4.447e-1 STO 3 '
          '3 ENTER 2.151 - 1.085 / f A → 7.830e-1 '
          'RCL 3 - -> 0.3384'),
  _Program(
      'HP-15C Advanced Functions Handbook/HP-15C Advanced Functions Handbook - Pages 013-016.15c',
      'GSB 1 1 ENTER 32 SOLVE A -> 7.5137 rDown rDown -> 0'),
  _Program(
      'HP-15C Advanced Functions Handbook/HP-15C Advanced Functions Handbook - Pages 034-038.15c',
      '5 f DIM (i) f USER 3 ENTER 2 f DIM argC f MATRIX 1 '
          '4000 CHS STO argC 1 STO argC 125 STO argC 1 STO argC 4100 STO argC '
          '1 STO argC B → 2.8168'),
  _Program(
      'HP-15C Advanced Functions Handbook/HP-15C Advanced Functions Handbook - Pages 069-072.15c',
      '0 A -> 1.6279 B -> -0.1487 B -> -0.1497 B -> -0.1497 '
          'RE<=>IM -> 2.8319 RE<=>IM C -> 1e-10 X<=>Y -> -0.1497'),
  _Program(
      'HP-15C Advanced Functions Handbook/HP-15C Advanced Functions Handbook - Pages 056-058.15c',
      'B 4.2 A -> 2.0486 FIX 9 -> 2.048555637 3.2 x! -> 7.756689536 '
          'LN -> 2.048555637 1 ENTER 5 I A -> -6.130324145 RE<=>IM 3.815898575'),
  _Program(
      'HP-15C Advanced Functions Handbook/HP-15C Advanced Functions Handbook - Pages 018-021.15c',
      'g RAD 2 g PI * .6 × STO 0 COS STO 1 CHS 1 + 1/x STO 2 '
          '10 f ->RAD 60 ->RAD f SOLVE 0 -> 0.4899 '
          'rDown rDown -> 5.5279e-11 rUp rUp ->DEG -> 28.0680'),
  _Program(
      'HP-15C Owner\'s Handbook/HP-15C Owner\'s Handbook - Pages 070-074.15c',
      ''),
  _Program(
      'HP-15C Owner\'s Handbook/HP-15C Owner\'s Handbook - Pages 181-184.15c',
      'A -> 5 B -> -2'),
  _Program(
      'HP-15C Owner\'s Handbook/HP-15C Owner\'s Handbook - Pages 189-190.15c',
      ''),
  _Program(
      'HP-15C Owner\'s Handbook/HP-15C Owner\'s Handbook - Pages 102-103.15c',
      '0.52 ENTER 1.25 GSB 9 -> 1.1507 '
          '1 CHS ENTER 1 GSB 9 -> -0.8415 '
          '0.81 ENTER 0.98 GSB 9 -> 1.1652'),
  _Program(
      'HP-15C Owner\'s Handbook/HP-15C Owner\'s Handbook - Pages 093-094.15c',
      '2 STO 0 100 STO 1 50 STO 2 A -> 50',
      pauseValues: [2, 84.0896, 5, 64.8420, 8, 50]),
  _Program(
      'HP-15C Owner\'s Handbook/HP-15C Owner\'s Handbook - Pages 104-104.15c',
      '8 ENTER 1.3 ENTER 7.9 ENTER 4.3 GSB .4 -> 12.1074'),
  _Program(
      'HP-15C Owner\'s Handbook/HP-15C Owner\'s Handbook - Pages 184-186.15c',
      '5 ENTER SOLVE A -> 9.2843'),
  _Program(
      'HP-15C Owner\'s Handbook/HP-15C Owner\'s Handbook - Pages 014-016.15c',
      '300.51 f A → 7.8313'),
  _Program(
      'Math/Gaussian Integration.15c', 'RAD 5 STO I 1 ENTER 3 A -> 0.9026'),
  _Program(
      'Math/Quadratic_Equation.15c',
      '3.3 ENTER 2.2 ENTER 1.1 E -> -0.3333 RE<=>IM -> -0.4714 '
          'X<=>Y -> -0.3333 RE<=>IM -> 0.4714 '
          '3.3 ENTER 2.2 ENTER 1.1 E -> -0.3628 RE<=>IM -> -0.5781 '
          'X<=>Y -> -0.3039 RE<=>IM -> 0.5781 ',
      pauseValues: [-9.68, -14.52, 1.4832]),
  _Program('Math/Big_Factorial.15c', '235 A -> 456 X<=>Y -> 5.3275',
      pauseValues: [5.3275]),
  _Program('Math/Gamma function for complex numbers.15C',
      'f FIX 9 0 ENTER 1 I A -> -0.154949828 Re<=>Im -> -0.498015669'),
  _Program('Math/LnGammaComplex.15c',
      '1.2 ENTER 3.4 I A -> -3.5627 Re<=>Im -> 1.8006'),
  _Program(
      'Math/Sums of five lists.15c',
      'f MATRIX 0 g CF 1 f USER 250 A 150 A 525 A 275 A '
          '300 A 10 B 10 B 2 B 100 B 10 B GSB 1 -> 1500 '
          'R/S -> 132 R/S -> 0',
      pauseValues: ['a      5  1', 'b      5  1']),
  _Program('Math/Halley\'s Method.15c',
      'f FIX 9 RCL MATRIX argB STO I EEX 4 CHS STO 0 2 A -> 1.854105968',
      pauseValues: [0.148589460, 0.002695411, 0.000000017, 0]),
  _Program('Math/BinaryToDecimal.15c', '1010011010 D -> 666 101010 D -> 42'),
  _Program('Math/Complex Number Utilities.15c', ''),
  _Program(
      'Math/Bairstow\'s Method.15c',
      '2 STO 9 9 CHS STO .0 15 STO .1 65 STO .2 267 CHS STO .3 234 STO .4 '
          '9.014 STO 8 1 STO 0 STO 1 A '
          '-> -52 RCL 0 -> 1.5 RCL 1 -> -4.5 RCL 9 -> 2 RCL .0 -> -12 '
          'RCL .1 -> 42 RCL .2 -> -52 GSB B -> 1.5 X<=>Y -> -3 '
          'GSB A -> -4 RCL 0 -> -4 RCL 1 -> 13 RCL 9 -> 2 RCL .0 -> -4 '),
  _Program('Math/Convert to Fraction.15c', '0.15625 GSB 1 -> 32',
      pauseValues: [5]),
  _Program('Math/Little_Gauss.15c',
      '19 A -> 190 19 B -> 190 219 A -> 24090 219 B -> 24090'),
  _Program(
      'Math/Calculating 208 digits of e.15c', '2 DIM (i) 1 A -> -0.71828178',
      pauseValues: [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]),
  _Program(
      'Math/GCD_LCM.15c',
      '48 ENTER 180 A -> 12 '
          '12 ENTER 44 B -> 132 '
          'PI C -> 3.1429'),
  _Program('Math/DecimalToBinary.15c', '42 B -> 101010 666 B -> 1010011010'),
  _Program('Users/Peter Sels/MasterMind2020.15c', ''),
  _Program('Users/Peter Sels/MasterMindGuessScoring.15c', ''),
  _Program('Users/Peter Sels/HigherLower_v1987.15c', ''),
  _Program('Users/D.G. Simpson/Kepler’s Equation.15c',
      '60 ENTER .15 f A -> 67.9667'),
  _Program(
      'Users/D.G. Simpson/Helmert’s Equation.15C',
      // Doesn't give a sensible answer, but it agrees with a real 15C, and
      // is within 0.2 of Torsten's simulator.
      // I suspect a bug in the Helmert's program.
      '0.025928 STO .1 9.80616 STO .2 6.9 EEX 5 STO .3 3.086 EEX 6 STO . 4 '
          '38.898 ENTER 53 f A -> -163527156.2'),
  _Program('Users/D.G. Simpson/Reduction of an Angle.15c', '5000 f A -> 320'),
  _Program(
      'Users/D.G. Simpson/1D Perfectly Elastic Collisions.15C',
      '2 ENTER 7 ENTER 4 ENTER 5 CHS f A '
          '-> -10 X<=>Y -> -1'),
  _Program('Users/D.G. Simpson/Barker’s Equation.15c', '19.38 f A -> 149.0847'),
  _Program('Users/D.G. Simpson/Projectile Problem.15c',
      '30 ENTER 50 ENTER 20 ENTER 30 f A -> 41.5357'),
  _Program('Users/D.G. Simpson/Hyperbolic Kepler’s Equation.15C',
      '60 ENTER 1.15 f A -> 1.7502'),
  _Program(
      'Users/D.G. Simpson/Pendulum Period.15C', '1.2 ENTER 65 f A -> 2.3898'),
  _Program('Users/Eddie Shore/Prime Factorization.15c',
      '150 GSB B -> 2 R/S -> 3 R/S -> 5 R/S -> 5 R/S -> 150'),
  _Program(
      'Users/Eddie Shore/Sign Function.15c',
      '52 CHS C -> -1 '
          '0 C -> 0 '
          '36 C -> 1 '),
  _Program(
      'Users/Eddie Shore/Digital Root.15c',
      '4514 A -> 5 '
          '9376 A -> 7 '
          '636088 A -> 4 '
          '761997 A -> 3 '),
  _Program('Users/Eddie Shore/Prime Factor.15c',
      '150 GSB B -> 2 R/S -> 3 R/S -> 5 R/S -> 5 R/S -> 150'),
  _Program(
      'Users/Eddie Shore/Pascal\'s Triangle.15c',
      '4 A  -> 1 R/S -> 4 R/S -> 6 R/S -> 4 R/S -> 1 '
          '8 A -> 1 R/S -> 8 R/S -> 28 R/S -> 56 R/S -> 70 '
          'R/S -> 56 R/S -> 28 R/S -> 8 R/S -> 1'),
  _Program(
      'Users/Eddie Shore/Quadratic formula.15c',
      '1 STO 1 4 STO 2 6 STO 3 A '
          '-> -8 R/S -> -2 R/S -> 1.4142 '
          '1 STO 1 5 CHS STO 2 3 STO 3 A '
          '-> 13 R/S -> 4.3028 R/S -> 0.6972 '),
  _Program('Users/Eddie Shore/Countdown.15c', ''),
  _Program('Users/Eddie Shore/Summation.15c', ''),
  _Program(
      'Users/Eddie Shore/Volume of a Cylinder.15c',
      '1000 STO 3 10 STO 2 1 STO I 0 ENTER 1000 f SOLVE A '
          '-> 5.6419 '
          '2498.65 STO 3 39.43 STO 1 2 STO I 0 ENTER 1000 f SOLVE A '
          '-> 0.5116'),
  _Program('Users/Eddie Shore/The Game of Bust.15c', ''),
  _Program(
      'Users/Eddie Shore/Quadratic Equation with Complex Coefficients.15C',
      '2 STO 0 3 STO 1 3 CHS STO 2 4 CHS STO 3 0 STO 4 2 STO 5 '
          'A -> 1.1268 R/S -> -0.4538 R/S -> 0.2578 R/S -> 0.3769 '),
  _Program(
      'Users/Eddie Shore/Extended Statistics Program.15c',
      'CF 1 CF 2 '
          'A 104.5 ENTER 40.5 f B -> 1 102 ENTER 38.6 f B -> 2 '
          '100 ENTER 37.9 f B  -> 3 97.5 ENTER 36.2 f B -> 4 '
          '95.5 ENTER 35.1 f B -> 5 94 ENTER 34.6 f B -> 6 '
          'C -> 33.5271 R/S -> 1.7601 R/S -> 0.9955 '
          'SF 1 CF 2 '
          'A 104.5 ENTER 40.5 f B -> 1 102 ENTER 38.6 f B -> 2 '
          '100 ENTER 37.9 f B  -> 3 97.5 ENTER 36.2 f B -> 4 '
          '95.5 ENTER 35.1 f B -> 5 94 ENTER 34.6 f B -> 6 '
          'C -> -139.0086 R/S -> 65.8446 R/S -> 0.9965 '
          'CF 1 SF 2 '
          'A 104.5 ENTER 40.5 f B -> 1 102 ENTER 38.6 f B -> 2 '
          '100 ENTER 37.9 f B  -> 3 97.5 ENTER 36.2 f B -> 4 '
          '95.5 ENTER 35.1 f B -> 5 94 ENTER 34.6 f B -> 6 '
          'C -> 51.1312 R/S -> 0.0177 R/S -> 0.9945 '
          'SF 1 SF 2 '
          'A 104.5 ENTER 40.5 f B -> 1 102 ENTER 38.6 f B -> 2 '
          '100 ENTER 37.9 f B  -> 3 97.5 ENTER 36.2 f B -> 4 '
          '95.5 ENTER 35.1 f B -> 5 94 ENTER 34.6 f B -> 6 '
          'C -> 8.9731 R/S -> 0.6640 R/S -> 0.9959 '),
  _Program(
      'Users/Eddie Shore/Modulus Function.15c',
      '48 ENTER 3 B -> 0 '
          '41.3 ENTER 12 B -> 5.3 '
          '48 ENTER 7 CHS B -> -1 '
          '50.2 CHS ENTER 36 B -> 21.8 '),
  _Program('Users/Eddie Shore/Numerical Derivative.15c', ''),
  _Program('Users/Eddie Shore/Reactance chart solver.15c',
      '60 STO 0 2.5 STO 1 2 STO I 0 ENTER 1 f SOLVE D -> 2.8145e-6'),
  _Program(
      'Users/Eddie Shore/Coordinates on an Ellipse.15c',
      '7 STO 0 2 STO 1 3 STO 2 B -> 0 R/S -> 2 R/S -> 0 '
          'R/S -> 1 R/S -> 1.2470 R/S -> 2.3455 '
          'R/S -> 2 R/S -> -0.4450 R/S -> 2.9248 '
          'R/S -> 3 R/S -> -1.8019 R/S -> 1.3017 '
          'R/S -> 4 R/S -> -1.8019 R/S -> -1.3017 '
          'R/S -> 5 R/S -> -0.4450 R/S -> -2.9248 '
          'R/S -> 6 R/S -> 1.2470 R/S -> -2.3455 '),
  _Program(
      'Conversion/Imperial to Metric.15c',
      '10 GSB .2 -> 23.5215 '
          '19 GSB 2 -> 12.3797 '
          '213 GSB .3 -> 6.1186 '
          '315 GSB 3 -> 9601.2000 '),
  _Program(
      'Finance/Time_Money.15c',
      'f FIX 2 CF 0 30 ENTER 12 * A '
          '5.85 ENTER 1 2 / B 50000 C '
          'D R/S -> -294.97 '
          'CLx D E R/S -> -287941.99'),
  _Program('HP-15C Matrix/HP-15C Owner\'s Handbook - Pages 157-159.15c', ''),
  _Program('HP-15C Matrix/HP-15C Owner\'s Handbook - Pages 169-171.15c', ''),
  _Program('HP-15C Matrix/HP-15C Owner\'s Handbook - Pages 138-140.15c',
      'GSB 1 -> 8.2496',
      pauseValues: [3.80, 7.20, 1.30, -0.90, 16.5, -22.1, -11.2887, -11.2887]),
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
  _Program(
      'Games/Sudoku Solver.15c',
      '34 DIM (i) '
          '875921346 STO 8 361754892 STO 9 249863715 STO .0 '
          '584697123 STO .1 713248659 STO .2 926135487 STO .3 '
          '697 412 538 STO .4 158379264 STO .5 432 586 971 STO .6 '
          'GSB A '
          '17 STO I RCL (i) -> 875921346 '
          '18 STO I RCL (i) -> 361754892 '
          '19 STO I RCL (i) -> 249863715 '
          '20 STO I RCL (i) -> 584697123 '
          '21 STO I RCL (i) -> 713248659 '
          '22 STO I RCL (i) -> 926135487 '
          '23 STO I RCL (i) -> 697412538 '
          '24 STO I RCL (i) -> 158379264 '
          '25 STO I RCL (i) -> 432586971 '
          '1 DIM (i) 34 DIM (i) '
          'RCL 8 -> 0 '
          '12000570 STO 8 600501004 STO 9 400020008 STO .0 '
          '20010050 STO .1  4907800 STO .2  70080010 STO .3 '
          '700090005 STO .4  500408006 STO .5  38000940 STO .6 '
          'GSB A '
          '17 STO I RCL (i) -> 912846573 '
          '18 STO I RCL (i) -> 683571294 '
          '19 STO I RCL (i) -> 457329168 '
          '20 STO I RCL (i) -> 829613457 '
          '21 STO I RCL (i) -> 164957832 '
          '22 STO I RCL (i) -> 375284619 '
          '23 STO I RCL (i) -> 746192385 '
          '24 STO I RCL (i) -> 591438726 '
          '25 STO I RCL (i) -> 238765941'),
  _Program('Games/Hanoi Towers.15C', ''),
  _Program('Games/Display_Control.15c', ''),
  _Program('Games/Train.15C', ''),
  _Program(
      'HP Applications Books/Thermal and Transport Science/Ideal Gas Equation of State.15c',
      '83.14 STO 0 25000 STO 2 .63 STO 3 1200 STO 4 GSB 1 → 2.5142 '
          '82.05 STO 0 GSB 1 → 2.4812'),
  _Program(
      'HP Applications Books/Geometry/Triangle Solutions.15c',
      'g DEG f FIX 2 171.63 ENTER → 171.63 98.12 g →H → 98.20 '
          '297.35 GSB 4 → 25256.21 RCL 4 → 27.83 RCL 5 → 363.91 RCL 6 → 53.97 '
          '25.6 ENTER → 25.60 32.9 ENTER → 32.90 42.3 GSB 5 → 2 '
          'R/S RCL 0 → 411.65 A → 127.15 RCL 1 → 25.60'),
  _Program('HP Applications Books/Mechanical Engineering/Kinetic Engergy.15c',
      'B 775 STO 1 5 ENTER 4 ENTER 16 ÷ + STO 2 GSB 3 → 97.4627'),
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
  final List<Object> pauseValues;

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
  final List<Object> pauseValues; // String or double
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
    'DEG': Operations15.deg,
    '->DEG': Operations15.toDeg,
    'RAD': Operations15.rad,
    '->RAD': Operations15.toRad,
    'FIX': Operations15.fix,
    '→H': Operations15.toH,
    'DIM': Operations15.dim,
    '(i)': Operations15.parenI15,
    'I': Operations15.I15,
    'CF': Operations15.cf,
    'SF': Operations15.sf,
    'R/S': Operations.rs,
    'CLx': Operations.clx,
    'SOLVE': Operations15.solve,
    'X<=>Y': Operations.xy,
    'RE<=>IM': Operations15.reImSwap,
    'PI': Operations15.piOp,
    'MATRIX': Operations15.matrix,
    'USER': Operations15.userOp,
    'argA': Operations15.letterLabelA,
    'argB': Operations15.letterLabelB,
    'argC': Operations15.letterLabelC,
    'argD': Operations15.letterLabelD,
    'argE': Operations15.letterLabelE,
    'Re<=>Im': Operations15.reImSwap,
    'INTEGRATE': Operations15.integrate,
    'x!': Operations15.xFactorial,
    'LN': Operations15.lnOp,
    '1/x': Operations15.reciprocal15,
    'COS': Operations15.cos,
    'SIN': Operations15.sin,
    'TAN': Operations15.tan,
    'rDown': Operations.rDown,
    'rUp': Operations.rUp,
  };

  _ProgramRun(this.script, this.c, {required this.pauseValues})
      : out = StreamIterator<ProgramEvent>(c.output.stream);

  Future<void> run() async {
    state = normalState;
    for (final keys in script.split(' ')) {
      if (keys.isNotEmpty) {
        await state(keys);
      }
    }
    expect(pauseCount, pauseValues.length);
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
    } else if (keys == 'SOLVE') {
      state = gsbState;
      play(Operations15.solve);
    } else if (keys == 'GSB') {
      state = gsbState;
      play(Operations15.gsb);
    } else if (keys == 'R/S') {
      play(Operations.rs);
      await waitProgramDone();
    } else if (keys == 'f' || keys == 'g') {
      // do nothing
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
        expect(pauseCount < pauseValues.length, true,
            reason: '${out.current.pauseValue} $pauseCount $pauseValues');
        final pv = pauseValues[pauseCount++];
        if (pv is num) {
          expect(c.model.formatValue(out.current.pauseValue!),
              c.model.formatValue(Value.fromDouble(pv.toDouble())));
        } else {
          expect(c.model.formatValue(out.current.pauseValue!), pv);
        }
        c.resume();
      } else {
        expect(out.current, ProgramEvent.done);
        break;
      }
    }
    state = normalState;
  }

  void playLabel(String keys) {
    if (otherOperations[keys] != null) {
      play(otherOperations[keys]!);
      return;
    }
    for (int i = 0; i < keys.length; i++) {
      final ch = keys[i];
      final op = letters[ch] ?? numbers[ch];
      expect(op != null, true, reason: keys);
      play(op!);
    }
  }

  Future<void> stoRclState(String keys) async {
    playLabel(keys);
    state = normalState;
  }

  Future<void> expectState(String keys) async {
    final v = double.parse(keys);
    if (c.model.formatValue(c.model.x) !=
        c.model.formatValue(Value.fromDouble(v))) {
      for (int i = 0; i <= 7; i++) {
        print('  r$i: ${c.model.memory.registers[i]}');
      }
    }
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
