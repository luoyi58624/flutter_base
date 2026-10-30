import 'package:flutter/material.dart';
import 'package:flutter_base/desktop.dart' as desktop;
import 'package:flutter_base/mobile.dart' as mobile;
import 'package:flutter_test/flutter_test.dart';

Finder _action(String label) => find.byWidgetPredicate(
  (widget) =>
      widget is mobile.ElView && widget.semantics?.properties.label == label,
);

void main() {
  test('两端入口导出同一套通用组件声明', () {
    expect(mobile.ElButton(), isA<desktop.ElButton>());
    expect(desktop.ElSwitch(value: false), isA<mobile.ElSwitch>());
    expect(mobile.ElTag(child: '标签'), isA<desktop.ElTag>());
  });

  testWidgets('嵌套品牌各自安装配置，通用按钮各切换一次', (tester) async {
    final mobileModel = ValueNotifier(false);
    final desktopModel = ValueNotifier(false);
    addTearDown(mobileModel.dispose);
    addTearDown(desktopModel.dispose);
    final mobileChanges = <bool>[];
    final desktopChanges = <bool>[];
    late mobile.ElComponentBuilders outer;
    late desktop.ElComponentBuilders inner;
    late mobile.ElComponentBuilders after;

    await tester.pumpWidget(
      MaterialApp(
        home: mobile.MyTheme(
          child: Column(
            mainAxisSize: .min,
            children: [
              Builder(
                builder: (context) {
                  outer = mobile.ElComponentProvider.of(context);
                  return mobile.ElButton.toggle(
                    key: ValueKey('mobile'),
                    modelValue: mobileModel,
                    onChanged: mobileChanges.add,
                    semanticLabel: '移动端按钮',
                    child: '移动端',
                  );
                },
              ),
              desktop.ElDesktopTheme(
                child: Builder(
                  builder: (context) {
                    inner = desktop.ElComponentProvider.of(context);
                    return desktop.ElButton.toggle(
                      key: ValueKey('desktop'),
                      modelValue: desktopModel,
                      onChanged: desktopChanges.add,
                      semanticLabel: '桌面端按钮',
                      child: '桌面端',
                    );
                  },
                ),
              ),
              Builder(
                builder: (context) {
                  after = mobile.ElComponentProvider.of(context);
                  return SizedBox();
                },
              ),
            ],
          ),
        ),
      ),
    );

    expect(outer, same(after));
    expect(inner.buttonBuilder, isNot(same(outer.buttonBuilder)));
    expect(outer.buttonBuilder, isNotNull);
    expect(inner.buttonBuilder, isNotNull);
    expect(outer.radioBuilder, isNull);
    expect(inner.radioBuilder, isNull);
    expect(outer.checkboxBuilder, isNull);
    expect(inner.checkboxBuilder, isNull);

    await tester.tap(_action('移动端按钮'));
    await tester.pump();
    expect(mobileModel.value, isTrue);
    expect(desktopModel.value, isFalse);
    expect(mobileChanges, [true]);

    await tester.tap(_action('桌面端按钮'));
    await tester.pump();
    expect(desktopModel.value, isTrue);
    expect(desktopChanges, [true]);
    expect(mobileChanges, [true]);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox());
  });
}
