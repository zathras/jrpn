

void main() {
  for (final move in hanoi(15, 1, 3, 2)) {
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
    yield* hanoi(discs-1, from, other, to);
    yield Move(from, to);
    yield* hanoi(discs-1, other, to, from);
  }
}
