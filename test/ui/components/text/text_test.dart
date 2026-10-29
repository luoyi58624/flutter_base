import 'package:flutter_base/ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('文本声明原样分派，参数平铺不被注册表擦除', (tester) async {
    final seen = <Widget>[];
    Widget text(BuildContext context, ElText component) {
      seen.add(component);
      return const ElView();
    }

    final declaration = ElText(
      'hello',
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      strutStyle: const StrutStyle(height: 1.2),
      textAlign: TextAlign.center,
      textDirection: TextDirection.rtl,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      textScaler: const TextScaler.linear(1.5),
      maxLines: 2,
      textWidthBasis: TextWidthBasis.longestLine,
      selectionColor: const Color(0xffff0000),
    );
    final builders = ElComponentBuilders(textBuilder: text);
    expect(builders.merge(ElComponentBuilders()), builders);
    expect(builders.copyWith(textBuilder: null).textBuilder, isNull);
    await tester.pumpWidget(
      Directionality(
        textDirection: .ltr,
        child: ElComponentProvider(
          builders: builders,
          child: declaration,
        ),
      ),
    );
    expect(seen, orderedEquals([declaration]));
    final seenText = seen.single as ElText;
    expect(seenText.data, 'hello');
    expect(seenText.style?.fontSize, 18);
    expect(seenText.strutStyle?.height, 1.2);
    expect(seenText.textAlign, TextAlign.center);
    expect(seenText.textDirection, TextDirection.rtl);
    expect(seenText.softWrap, isFalse);
    expect(seenText.overflow, TextOverflow.ellipsis);
    expect(seenText.textScaler, const TextScaler.linear(1.5));
    expect(seenText.maxLines, 2);
    expect(seenText.textWidthBasis, TextWidthBasis.longestLine);
    expect(seenText.selectionColor, const Color(0xffff0000));
  });

  test('文本 builder 参与复制、清空、合并与相等比较', () {
    Widget text(BuildContext context, ElText component) => const ElView();
    final data = ElComponentBuilders(textBuilder: text);
    expect(data.copyWith(), data);
    expect(data.copyWith().hashCode, data.hashCode);
    expect(data.copyWith(textBuilder: null).textBuilder, isNull);
    expect(ElComponentBuilders().merge(data), data);
    expect(data.merge(ElComponentBuilders()), data);
  });

  testWidgets('缺少提供器由 of 断言，缺少实现由 builder 非空操作报错', (tester) async {
    await tester.pumpWidget(
      const Directionality(textDirection: TextDirection.ltr, child: ElText('hello')),
    );
    expect(
      tester.takeException(),
      isA<AssertionError>().having((e) => e.message, 'message', contains('ElComponentProvider')),
    );
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: ElComponentProvider(builders: ElComponentBuilders(), child: ElText('hello')),
      ),
    );
    expect(tester.takeException(), isA<TypeError>());
  });
}