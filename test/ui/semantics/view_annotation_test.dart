import 'package:flutter_base/ui.dart';
import 'package:flutter_base/src/ui/cores/view/semantics/render_semantics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

SemanticsConfiguration _configuration(
  ElSemantics? semantics, {
  String? label,
  TextDirection direction = TextDirection.ltr,
  bool includeFocus = false,
  bool focusable = false,
  bool focused = false,
}) {
  final config = SemanticsConfiguration();
  applyViewSemanticsConfiguration(
    config,
    semantics: semantics,
    textLabel: label,
    textDirection: direction,
    includeFocusSemantics: includeFocus,
    focusableForSemantics: focusable,
    focusedForSemantics: focused,
  );
  return config;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('共享声明保留各次查询的方向，并复用已转换的属性文本', () {
    final declaration = ElSemantics(label: '内容', hint: '提示');
    final first = _configuration(declaration);
    final second = _configuration(declaration, direction: TextDirection.rtl);
    expect(first.textDirection, TextDirection.ltr);
    expect(second.textDirection, TextDirection.rtl);
    expect(identical(first.attributedLabel, second.attributedLabel), isTrue);
    expect(identical(first.attributedHint, second.attributedHint), isTrue);
  });

  test('后续声明求值不改变旧配置的动作及其参数', () {
    final calls = <String>[];
    TextSelection? selected;
    final first = _configuration(
      ElSemantics(
        properties: SemanticsProperties(
          onTap: () => calls.add('first'),
          onSetText: calls.add,
          onSetSelection: (value) => selected = value,
        ),
      ),
    );
    final second = _configuration(ElSemantics(onTap: () => calls.add('second')));
    first.onTap!();
    second.onTap!();
    first.onSetText!('text');
    first.onSetSelection!(TextSelection(baseOffset: 1, extentOffset: 3));
    expect(calls, ['first', 'second', 'text']);
    expect(selected, TextSelection(baseOffset: 1, extentOffset: 3));
  });

  test('空声明不生成边界，非文本属性不注入文本方向', () {
    final empty = _configuration(ElSemantics());
    expect(empty.hasBeenAnnotated, isFalse);
    expect(empty.isSemanticBoundary, isFalse);
    final button = _configuration(ElSemantics(button: true));
    expect(button.isButton, isTrue);
    expect(button.textDirection, isNull);
    expect(button.isSemanticBoundary, isTrue);
  });

  test('显式空 label 和富属性 label 均优先于宿主文本', () {
    expect(_configuration(ElSemantics(label: ''), label: '宿主').label, '');
    final attributed = AttributedString('属性文本');
    final config = _configuration(
      ElSemantics(
        properties: SemanticsProperties(attributedLabel: attributed, textDirection: TextDirection.rtl),
      ),
      label: '宿主',
    );
    expect(config.attributedLabel, same(attributed));
    expect(config.textDirection, TextDirection.rtl);
  });

  test('官方 focusable 声明生效，显式 focused 优先于宿主', () {
    final properties = SemanticsProperties(
      // ignore: deprecated_member_use — 验证 SDK 仍公开的兼容输入也被正确转发。
      focusable: true,
    );
    expect(_configuration(ElSemantics(properties: properties)).isFocused, isFalse);
    final explicit = _configuration(
      ElSemantics(properties: SemanticsProperties(focused: false)),
      includeFocus: true,
      focusable: true,
      focused: true,
    );
    expect(explicit.isFocused, isFalse);
    expect(_configuration(null, includeFocus: true, focusable: true, focused: true).isFocused, isTrue);
  });

  test('排除语义时不贡献自身文本、动作和焦点', () {
    final config = _configuration(
      ElSemantics(exclude: true, label: '隐藏', onTap: () {}),
      label: '隐藏文本',
      includeFocus: true,
      focusable: true,
      focused: true,
    );
    expect(config.hasBeenAnnotated, isFalse);
    expect(config.isSemanticBoundary, isFalse);
    expect(config.onTap, isNull);
  });

  testWidgets('显式语义适配不增加渲染树节点', (tester) async {
    final handle = tester.ensureSemantics();
    try {
      final key = GlobalKey();
      for (final declaration in [null, ElSemantics(label: '显式')]) {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: ElView(key: key, semantics: declaration, child: '文本'),
          ),
        );
        final render = tester.renderObject<ElRenderView>(find.byKey(key));
        expect(render.childCount, 0);
        expect(tester.getSemantics(find.byKey(key)).label, declaration == null ? '文本' : '显式');
      }
    } finally {
      handle.dispose();
    }
  });
}
