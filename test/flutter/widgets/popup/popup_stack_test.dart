import 'package:flutter_base/src/flutter/widgets/popup/popup_stack.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('LIFO 注册、移除中间层和重复移除', () {
    final stack = PopupStack();
    final a = Object();
    final b = Object();
    final c = Object();
    addTearDown(() {
      for (final handle in [a, b, c]) {
        stack.unregister(handle);
      }
    });
    expect(stack.isTopmost(a), isFalse);
    stack.register(a);
    stack.register(b);
    stack.register(c);
    expect(stack.isTopmost(c), isTrue);
    stack.unregister(b);
    expect(stack.isTopmost(c), isTrue);
    stack.unregister(c);
    expect(stack.isTopmost(a), isTrue);
    stack.unregister(a);
    stack.unregister(a);
    expect(stack.isTopmost(a), isFalse);
  });

  test('重复注册不复制或提升句柄', () {
    final stack = PopupStack();
    final a = Object();
    final b = Object();
    stack.register(a);
    stack.register(b);
    stack.register(a);
    expect(stack.isTopmost(b), isTrue);
    stack.unregister(b);
    expect(stack.isTopmost(a), isTrue);
    stack.unregister(a);
    expect(stack.isTopmost(a), isFalse);
  });
}
