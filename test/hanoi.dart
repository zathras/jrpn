/*
Copyright (c) 2021-2024 William Foote

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

void main() {
  for (final move in hanoi(15, 1, 3, 2)) {
    // ignore: avoid_print
    print(move);
  }
}

class Move {
  final int from;
  final int to;

  Move(this.from, this.to);

  @override
  String toString() => 'from $from to $to';
}

Iterable<Move> hanoi(int discs, int from, int to, int other) sync* {
  if (discs == 1) {
    yield Move(from, to);
  } else {
    yield* hanoi(discs - 1, from, other, to);
    yield Move(from, to);
    yield* hanoi(discs - 1, other, to, from);
  }
}
