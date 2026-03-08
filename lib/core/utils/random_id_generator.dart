import 'dart:math';

class RandomId{
  String generate() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    Random rnd = Random();

    return String.fromCharCodes(
      Iterable.generate(
        10,
            (_) => chars.codeUnitAt(rnd.nextInt(chars.length)),
      ),
    );
  }
}