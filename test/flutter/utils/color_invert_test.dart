import 'package:flutter_base/flutter_base.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ElColorExt.invert', () {
    test('inverts RGB channels and preserves alpha', () {
      const color = Color.fromARGB(128, 0x12, 0x34, 0x56);

      expect(color.reversal, const Color.fromARGB(128, 0xed, 0xcb, 0xa9));
    });

    test('swaps black and white', () {
      expect(Colors.black.reversal, Colors.white);
      expect(Colors.white.reversal, Colors.black);
    });

    test('inverting twice restores the original color', () {
      const color = Color.fromARGB(77, 1, 128, 254);

      expect(color.reversal.reversal, color);
    });
  });
}
