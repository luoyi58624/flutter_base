import 'package:flutter_base/src/ui/cores/popup/popup_stack.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('LIFO 注册、移除中间层和重复移除', () {
    final a = Object();
    final b = Object();
    final c = Object();
    addTearDown(() {
      for (final handle in [a, b, c]) {
        ElPopupStack.unregister(handle);
      }
    });
    expect(ElPopupStack.isTopmost(a), isFalse);
    ElPopupStack.register(a);
    ElPopupStack.register(b);
    ElPopupStack.register(c);
    expect(ElPopupStack.isTopmost(c), isTrue);
    ElPopupStack.unregister(b);
    expect(ElPopupStack.isTopmost(c), isTrue);
    ElPopupStack.unregister(c);
    expect(ElPopupStack.isTopmost(a), isTrue);
    ElPopupStack.unregister(a);
    ElPopupStack.unregister(a);
    expect(ElPopupStack.isTopmost(a), isFalse);
  });

  test('重复注册不复制或提升句柄', () {
    final a = Object();
    final b = Object();
    ElPopupStack.register(a);
    ElPopupStack.register(b);
    ElPopupStack.register(a);
    expect(ElPopupStack.isTopmost(b), isTrue);
    ElPopupStack.unregister(b);
    expect(ElPopupStack.isTopmost(a), isTrue);
    ElPopupStack.unregister(a);
    expect(ElPopupStack.isTopmost(a), isFalse);
  });
}
