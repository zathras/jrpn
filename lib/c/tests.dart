/*
Copyright (c) 2021-2023 William Foote

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
part of 'controller.dart';

///
/// Some built-in regression tests.  There aren't just an excuse to flash
/// "running" when a user triggers the 16C's self test fonction.  It's also
/// a way of easily running some of the tests involving integer and floating
/// point behavior in different browsers. This might be a bit of a pain point
/// for Dart, since the numeric types behave differently given JavaScript's
/// deficiencies in ths regard.
///
/// I note that I've seen Dart documentation that mention the 53 bit mantissa
/// of the underlying double that JavaScript uses, but it seems that Dart
/// clamps ints on (perhaps only some?) JavaScript runtime(s) to 32 bits.  It
/// seems the prudent thing to do for interoperable code is to limit usage
/// of the int type to 32 bit ints, which is unfortunate.  In fairness, the
/// Dart language designers were in a bit of a bind, with no really good answers
/// for putting a normal type system on top of JavaScript's odd (and IMHO
/// terrible) choice as regards integers.
///
abstract class SelfTests {
  final bool inCalculator;
  int testsRun = 0;
  int errorsSeen = 0;
  int _expectsSeen = 0;
  DateTime _lastPause = DateTime.now();
  static const _minSleep = Duration(milliseconds: 4); // min JS resolution
  int get pauseEvery => 500;

  SelfTests({this.inCalculator = true});

  Model<Operation> newModel();

  /// Create a new controller with its model
  Controller newController();

  @protected
  Future<void> expect(Object? val, Object? expected, {String? reason}) async {
    if (inCalculator) {
      if (_expectsSeen++ % pauseEvery == 0) {
        DateTime now = DateTime.now();
        Duration sleep =
            (const Duration(milliseconds: 16)) - now.difference(_lastPause);
        _lastPause = now;
        if (sleep < _minSleep) {
          sleep = _minSleep; // Don't monopolize the CPU
        }
        await Future<void>.delayed(sleep);
        // JS resolution is only 4 ms
      }
    }
    if (val != expected) {
      debugPrint('');
      debugPrint('*** Error in self-test:  $val != expected $expected');
      if (reason != null) {
        debugPrint('  $reason');
        debugPrint('');
      }
      throw CalculatorError(9);
    }
  }

  @protected
  Future<void> test(String msg, Future<void> Function() tests) async {
    debugPrint('Running tests:  $msg');
    testsRun++;
    try {
      await tests();
      // ignore: avoid_catches_without_on_clauses
    } catch (e, s) {
      debugPrint('');
      debugPrint('*** Exception in test:  $e');
      debugPrint('');
      debugPrint(s.toString());
      debugPrint('');
      errorsSeen++;
    }
  }

// Format a double to a couple more digits than we need, and a couple
// less than we have.
  @protected
  String fd(double d) => d.toStringAsExponential(12);

  Future<void> testFloatValues() async {
    await test('Float Value constants', () async {
      await expect(Value.zero, Value.fromDouble(0.0));
      await expect(Value.fMaxValue, Value.fromDouble(9.999999999e99));
      await expect(Value.fMinValue, Value.fromDouble(-9.999999999e99));
    });
    await test('Float Value internal representation', () async {
      Model m = newModel();
      m.displayMode = DisplayMode.float(4);
      await expect(m.tryParseValue('0')!.internal, BigInt.from(0));
      await expect(
          m.tryParseValue('42')!.internal, BigInt.from(0x04200000000001));
      await expect(m.tryParseValue('-42')!.internal,
          BigInt.parse('94200000000001', radix: 16));
      await expect(
          m.tryParseValue('1e42')!.internal, BigInt.from(0x1000000000042));
      await expect(
          m.tryParseValue('1e-42')!.internal, BigInt.from(0x1000000000958));
    });
    await test('FloatValue from double to double', () async {
      await expect(fd(Value.fromDouble(42.0).asDouble), fd(42.0));
      await expect(fd(Value.fromDouble(-42.0).asDouble), fd(-42.0));
      await expect(Value.fromDouble(-42).negateAsFloat(), Value.fromDouble(42));
      await expect(fd(Value.fromDouble(12.3456e78).asDouble), fd(12.3456e78));
      await expect(fd(Value.fromDouble(-12.3456e78).asDouble), fd(-12.3456e78));
      await expect(fd(Value.fromDouble(12.3456e-78).asDouble), fd(12.3456e-78));
      await expect(
          fd(Value.fromDouble(-12.3456e-78).asDouble), fd(-12.3456e-78));
      await expect(
          fd(Value.fromDouble(9.999999999e-99).asDouble), fd(9.999999999e-99));
      await expect(fd(Value.fromDouble(-9.999999999e-99).asDouble),
          fd(-9.999999999e-99));
    });
    await test('Float rounding to zero', () async {
      await expect(Value.fromDouble(1e-100), Value.zero);
      await expect(Value.fromDouble(-1e-100), Value.zero);
      await expect(fd(Value.fromDouble(1e-100).asDouble), fd(0.0));
      await expect(fd(Value.fromDouble(-1e-100).asDouble), fd(0.0));
      await expect(fd(Value.fromDouble(1e-101).asDouble), fd(0.0));
      await expect(fd(Value.fromDouble(-1e-101).asDouble), fd(0.0));
    });
    await test('Float rounding to infinity', () async {
      await expect(Value.fromDouble(9.9999999996e99), Value.fInfinity);
      await expect(Value.fromDouble(-9.9999999996e99), Value.fNegativeInfinity);
      await expect(Value.fromDouble(9.9999999996e99), Value.fInfinity);
      await expect(Value.fromDouble(-9.9999999996e99), Value.fNegativeInfinity);
    });
  }

  Future<void> testJson() async {
    final Model<Operation> m = newModel();
    final String s = json.encoder.convert(m.toJson());
    m.decodeJson(json.decoder.convert(s) as Map<String, dynamic>,
        needsSave: false);
    await expect(
        json.encoder.convert(m.toJson()), s); // It's not much of a test :-)
  }

  Future<void> testNumbers() async {
    newController(); // initializes late final values.
    // Only really needed if no prior test has done this.
    await expect(Operations.n0.numericValue, 0x0);
    await expect(Operations.n1.numericValue, 0x1);
    await expect(Operations.n2.numericValue, 0x2);
    await expect(Operations.n3.numericValue, 0x3);
    await expect(Operations.n4.numericValue, 0x4);
    await expect(Operations.n5.numericValue, 0x5);
    await expect(Operations.n6.numericValue, 0x6);
    await expect(Operations.n7.numericValue, 0x7);
    await expect(Operations.n8.numericValue, 0x8);
    await expect(Operations.n9.numericValue, 0x9);
  }

  @mustCallSuper
  Future<void> runAll() async {
    await testJson();
    await testFloatValues();
    await testNumbers();
    debugPrint('');
    debugPrint('***  $testsRun self tests run.  $errorsSeen errors seen');
    debugPrint('');
    if (errorsSeen > 0) {
      throw CalculatorError(9);
    }
  }
}
