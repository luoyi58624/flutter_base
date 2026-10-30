import 'package:flutter_base/src/flutter/utils/internal/benchmark_probe.dart';
import 'package:flutter_base/src/flutter/utils/internal/bit_mask.dart';
import 'package:flutter_base/src/flutter/views/view/style/cascade/fast_patch.dart';
import 'package:flutter_base/src/flutter/views/view/style/cascade/style_spec.dart';
import 'package:flutter_base/src/flutter/views/view/style/internal/responsive.dart';
import 'package:flutter_base/src/flutter/views/view/style/resolved/builder.dart';
import 'package:flutter_base/src/ui/testing/ui_test_api.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _directionalHost(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(alignment: Alignment.topLeft, child: child),
);

class _PathClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => Path()..addRect(Offset.zero & size);

  @override
  bool shouldReclip(_PathClipper oldClipper) => false;
}

/// 暴露 ElRenderView 类型断言用（committedResolvedStyle / setHover 等已 public）。
typedef ElRenderBox = dynamic;

/// 继承传播 fast path 单测（[CascadeFastPatch.tryInheritPatch]）。
///
/// 触发场景：父 cascade 后 InheritancePropagator 把变化字段送给子的
/// reresolveFromInheritance。fast path 仅 patch 这些字段而不重 cascade。
void _inheritPatchTests() {
  ResolvedStyle parentWithFields({Color? color, double? fontSize, TextDirection? textDirection}) {
    final b = ResolvedStyleBuilder.empty();
    if (color != null) b.writeColor(color);
    if (fontSize != null) b.writeFontSize(fontSize);
    if (textDirection != null) b.writeTextDirection(textDirection);
    return b.build();
  }

  ResolvedStyle baseTargetWith({Color? color, double? fontSize}) {
    final b = ResolvedStyleBuilder.empty();
    if (color != null) b.writeColor(color);
    if (fontSize != null) b.writeFontSize(fontSize);
    return b.build();
  }

  int noState() => 0;

  group('tryInheritPatch fast hit', () {
    test('单 color 字段传播：patch + changedFields 一致', () {
      final newParent = parentWithFields(color: const Color(0xFFFF0000));
      final oldTarget = baseTargetWith(color: const Color(0xFF000000));

      final result = CascadeFastPatch.tryInheritPatch(
        style: null,
        oldTarget: oldTarget,
        newParent: newParent,
        oldParent: null,
        state: noState(),
        changedMask: fieldsMask({ElTransitionField.color}),
        hasActiveAnimations: false,
      );

      expect(result, isNotNull);
      expect(result!.changedMask.fields.toSet(), {ElTransitionField.color});
      expect(result.newTarget.inheritedText.color, const Color(0xFFFF0000));
      expect(identical(result.newCommitted, result.newTarget), isTrue);
    });

    test('多字段同时传播（color + fontSize）', () {
      final newParent = parentWithFields(color: const Color(0xFFFF0000), fontSize: 20);
      final oldTarget = baseTargetWith(color: const Color(0xFF000000), fontSize: 14);

      final result = CascadeFastPatch.tryInheritPatch(
        style: null,
        oldTarget: oldTarget,
        newParent: newParent,
        oldParent: null,
        state: noState(),
        changedMask: fieldsMask({ElTransitionField.color, ElTransitionField.fontSize}),
        hasActiveAnimations: false,
      );

      expect(result, isNotNull);
      expect(result!.newTarget.inheritedText.color, const Color(0xFFFF0000));
      expect(result.newTarget.inheritedText.fontSize, 20);
    });

    test('child has 部分 base 字段（不覆写传播字段）：fast path 命中', () {
      // 模拟 Card text child: 自己声明 fontSize/fontWeight，但不覆 color
      const childStyle = ElStyle(width: 100, height: 28, fontSize: 18, fontWeight: FontWeight.w700);
      final newParent = parentWithFields(color: const Color(0xFFFFFFFF));
      final oldTarget = baseTargetWith(color: const Color(0xFF000000), fontSize: 18);

      final result = CascadeFastPatch.tryInheritPatch(
        style: childStyle,
        oldTarget: oldTarget,
        newParent: newParent,
        oldParent: null,
        state: noState(),
        changedMask: fieldsMask({ElTransitionField.color}), // 已被 propagator 剔除子的 fontSize
        hasActiveAnimations: false,
      );

      expect(result, isNotNull);
      expect(result!.newTarget.inheritedText.color, const Color(0xFFFFFFFF));
      // child 自己声明的 fontSize 保留
      expect(result.newTarget.inheritedText.fontSize, 18);
    });

    test('textDirection / cursor (InheritedBox) 传播', () {
      final b = ResolvedStyleBuilder.empty();
      b.writeTextDirection(TextDirection.rtl);
      final newParent = b.build();

      final oldB = ResolvedStyleBuilder.empty();
      oldB.writeTextDirection(TextDirection.ltr);
      final oldTarget = oldB.build();

      final result = CascadeFastPatch.tryInheritPatch(
        style: null,
        oldTarget: oldTarget,
        newParent: newParent,
        oldParent: null,
        state: noState(),
        changedMask: fieldsMask({ElTransitionField.textDirection}),
        hasActiveAnimations: false,
      );

      expect(result, isNotNull);
      expect(result!.newTarget.inheritedBox.textDirection, TextDirection.rtl);
    });
  });

  group('tryInheritPatch bail', () {
    test('changedFields 为空 → bail', () {
      expect(
        CascadeFastPatch.tryInheritPatch(
          style: null,
          oldTarget: ResolvedStyle.initial,
          newParent: ResolvedStyle.initial,
          oldParent: null,
          state: noState(),
          changedMask: fieldsMask({}),
          hasActiveAnimations: false,
        ),
        isNull,
      );
    });

    test('newParent 为 null → bail', () {
      expect(
        CascadeFastPatch.tryInheritPatch(
          style: null,
          oldTarget: ResolvedStyle.initial,
          newParent: null,
          oldParent: null,
          state: noState(),
          changedMask: fieldsMask({ElTransitionField.color}),
          hasActiveAnimations: false,
        ),
        isNull,
      );
    });

    test('hasActiveAnimations=true → bail', () {
      final newParent = parentWithFields(color: const Color(0xFFFF0000));
      expect(
        CascadeFastPatch.tryInheritPatch(
          style: null,
          oldTarget: ResolvedStyle.initial,
          newParent: newParent,
          oldParent: null,
          state: noState(),
          changedMask: fieldsMask({ElTransitionField.color}),
          hasActiveAnimations: true,
        ),
        isNull,
      );
    });

    test('style 含 active variant + state 命中且变体覆写传播字段 → bail', () {
      const style = ElStyle(width: 100, onHover: ElStyle(color: Color(0xFF111111)));
      final newParent = parentWithFields(color: const Color(0xFFFF0000));
      final mask = (1 << ViewState.hover.index);
      expect(
        CascadeFastPatch.tryInheritPatch(
          style: style,
          oldTarget: ResolvedStyle.initial,
          newParent: newParent,
          oldParent: null,
          state: mask,
          changedMask: fieldsMask({ElTransitionField.color}),
          hasActiveAnimations: false,
        ),
        isNull,
      );
    });

    test('T-variant3：active variant 覆写字段与传播字段不相交 → fast hit', () {
      // hover 激活但变体只覆写 opacity（box 字段）；传播的是 color →
      // 不相交，patch 安全命中（旧判定下 hover 中的继承传播全体 bail）。
      const style = ElStyle(width: 100, onHover: ElStyle(opacity: 0.5));
      final newParent = parentWithFields(color: const Color(0xFFFF0000));
      final oldTarget = baseTargetWith(color: const Color(0xFF000000));
      final mask = (1 << ViewState.hover.index);
      final result = CascadeFastPatch.tryInheritPatch(
        style: style,
        oldTarget: oldTarget,
        newParent: newParent,
        oldParent: null,
        state: mask,
        changedMask: fieldsMask({ElTransitionField.color}),
        hasActiveAnimations: false,
      );
      expect(result, isNotNull);
      expect(result!.newTarget.inheritedText.color, const Color(0xFFFF0000));
    });

    test('T-variant3：响应式 md 激活（累进恒亮）不覆写传播字段 → fast hit', () {
      const style = ElStyle(width: 100, md: ElStyle(padding: EdgeInsets.all(24)));
      final newParent = parentWithFields(color: const Color(0xFFFF0000));
      final oldTarget = baseTargetWith(color: const Color(0xFF000000));
      final mask = (((1 << ViewState.xs.index) | (1 << ViewState.sm.index)) | (1 << ViewState.md.index));
      final result = CascadeFastPatch.tryInheritPatch(
        style: style,
        oldTarget: oldTarget,
        newParent: newParent,
        oldParent: null,
        state: mask,
        changedMask: fieldsMask({ElTransitionField.color}),
        hasActiveAnimations: false,
      );
      expect(result, isNotNull);
      expect(result!.newTarget.inheritedText.color, const Color(0xFFFF0000));
    });

    test('T-variant3：激活变体声明 transitions → bail', () {
      const style = ElStyle(
        width: 100,
        onHover: ElStyle(opacity: 0.5, transitions: [ElTransition.all(Duration(milliseconds: 100))]),
      );
      final newParent = parentWithFields(color: const Color(0xFFFF0000));
      final mask = (1 << ViewState.hover.index);
      expect(
        CascadeFastPatch.tryInheritPatch(
          style: style,
          oldTarget: ResolvedStyle.initial,
          newParent: newParent,
          oldParent: null,
          state: mask,
          changedMask: fieldsMask({ElTransitionField.color}),
          hasActiveAnimations: false,
        ),
        isNull,
      );
    });

    test('style 含 transitions → bail', () {
      final style = ElStyle(width: 100, transitions: const [ElTransition.all(Duration(milliseconds: 100))]);
      final newParent = parentWithFields(color: const Color(0xFFFF0000));
      expect(
        CascadeFastPatch.tryInheritPatch(
          style: style,
          oldTarget: ResolvedStyle.initial,
          newParent: newParent,
          oldParent: null,
          state: noState(),
          changedMask: fieldsMask({ElTransitionField.color}),
          hasActiveAnimations: false,
        ),
        isNull,
      );
    });

    test('changedFields 含非 inherited 字段 → bail（contract 违反）', () {
      final newParent = parentWithFields(color: const Color(0xFFFF0000));
      for (final field in [ElTransitionField.bgColor, ElTransitionField.decoration]) {
        expect(
          CascadeFastPatch.tryInheritPatch(
            style: null,
            oldTarget: ResolvedStyle.initial,
            newParent: newParent,
            oldParent: null,
            state: noState(),
            // 非继承字段不是 propagator 合法输入；防御性 bail。
            changedMask: fieldsMask({field}),
            hasActiveAnimations: false,
          ),
          isNull,
          reason: field.name,
        );
      }
    });
  });
}

FieldMask _maskOf(List<ElTransitionField> fields) {
  var mask = FieldMask.empty;
  for (final field in fields) {
    mask = maskOr(mask, maskBit(field.index));
  }
  return mask;
}

void main() {
  group('挂载继承链', () {
    List<ElRenderView> allRenderViews(WidgetTester tester) =>
        tester.renderObjectList<ElRenderView>(find.byType(ElView)).toList();

    group('attach 时建立继承链路', () {
      testWidgets('父 color → 子未声明 → 子拿父 color', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: ElView(
              style: ElStyle(color: Color(0xFFFF0000)),
              child: ElView(child: 'hello'),
            ),
          ),
        );

        final views = allRenderViews(tester);
        expect(views, hasLength(2));
        final outer = views.first;
        final inner = views.last;
        expect(outer.committedResolvedStyle.inheritedText.color, const Color(0xFFFF0000));
        expect(
          inner.committedResolvedStyle.inheritedText.color,
          const Color(0xFFFF0000),
          reason: 'inner 未声明 color → attach 时反查父，拿到父 color',
        );
      });

      testWidgets('父子之间穿过 Padding：仍能继承', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: ElView(
              style: ElStyle(color: Color(0xFFFF0000), fontSize: 18),
              child: Padding(
                padding: EdgeInsets.all(8),
                child: ElView(child: 'hello'),
              ),
            ),
          ),
        );

        final views = allRenderViews(tester);
        expect(views, hasLength(2));
        expect(
          views.last.committedResolvedStyle.inheritedText.color,
          const Color(0xFFFF0000),
          reason: '穿过非 ElRenderView 中间节点，attach 反查父链不中断',
        );
        expect(views.last.committedResolvedStyle.inheritedText.fontSize, 18);
      });

      testWidgets('子显式 color：截断祖先 color', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: ElView(
              style: ElStyle(color: Color(0xFFFF0000)),
              child: ElView(
                style: ElStyle(color: Color(0xFF00FF00)),
                child: 'hello',
              ),
            ),
          ),
        );

        final views = allRenderViews(tester);
        expect(views.last.committedResolvedStyle.inheritedText.color, const Color(0xFF00FF00));
      });

      testWidgets('多继承字段同时下传', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: ElView(
              style: ElStyle(
                color: Color(0xFFFF0000),
                fontSize: 22,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
                letterSpacing: 1.5,
              ),
              child: ElView(child: 'hello'),
            ),
          ),
        );

        final inner = allRenderViews(tester).last;
        final text = inner.committedResolvedStyle.inheritedText;
        expect(text.color, const Color(0xFFFF0000));
        expect(text.fontSize, 22);
        expect(text.fontWeight, FontWeight.w700);
        expect(text.fontFamily, 'monospace');
        expect(text.letterSpacing, 1.5);
      });

      testWidgets('父 inheritedText group 内的非继承字段不会下传', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: ElView(
              style: ElStyle(
                color: Color(0xFFFF0000),
                fontSize: 22,
                decoration: TextDecoration.underline,
                textBackgroundColor: Color(0xFFFFFF00),
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              child: ElView(child: 'hello'),
            ),
          ),
        );

        final text = allRenderViews(tester).last.committedResolvedStyle.inheritedText;
        expect(text.color, const Color(0xFFFF0000));
        expect(text.fontSize, 22);
        expect(text.decoration, isNull);
        expect(text.textBackgroundColor, isNull);
        expect(text.softWrap, isNull);
        expect(text.overflow, isNull);
        expect(text.maxLines, isNull);
      });

      testWidgets('inheritedText 在父子之间 identical 共享（性能不变量）', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: ElView(
              style: ElStyle(color: Color(0xFFFF0000), fontSize: 14),
              child: ElView(child: 'hello'),
            ),
          ),
        );

        final views = allRenderViews(tester);
        final outerText = views.first.committedResolvedStyle.inheritedText;
        final innerText = views.last.committedResolvedStyle.inheritedText;
        expect(
          identical(outerText, innerText),
          isTrue,
          reason: '子未写入 inheritedText 字段 → 整组应 identical 共享父引用（plan §16）',
        );
      });
    });

    group('父 cascade 变化时通知后代', () {
      testWidgets('父改 color → 子拿到新 color', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: ElView(
              style: ElStyle(color: Color(0xFFFF0000)),
              child: ElView(child: 'hello'),
            ),
          ),
        );

        await tester.pumpWidget(
          const MaterialApp(
            home: ElView(
              style: ElStyle(color: Color(0xFF0000FF)), // 父变
              child: ElView(child: 'hello'),
            ),
          ),
        );
        await tester.pump();

        final inner = allRenderViews(tester).last;
        expect(
          inner.committedResolvedStyle.inheritedText.color,
          const Color(0xFF0000FF),
          reason: '父 cascade 后 propagator 把新值推给子，子重 cascade 拿到新 color',
        );
      });

      testWidgets('父改 color，但子有显式 color：子不变', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: ElView(
              style: ElStyle(color: Color(0xFFFF0000)),
              child: ElView(
                style: ElStyle(color: Color(0xFF00FF00)),
                child: 'hello',
              ),
            ),
          ),
        );

        await tester.pumpWidget(
          const MaterialApp(
            home: ElView(
              style: ElStyle(color: Color(0xFF0000FF)), // 父变
              child: ElView(
                style: ElStyle(color: Color(0xFF00FF00)), // 子保持
                child: 'hello',
              ),
            ),
          ),
        );
        await tester.pump();

        final inner = allRenderViews(tester).last;
        expect(
          inner.committedResolvedStyle.inheritedText.color,
          const Color(0xFF00FF00),
          reason: '子显式声明 color → propagator 截断该字段',
        );
      });

      testWidgets('父改 hover → onHover.color 触发后代继承', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: ElView(
              style: ElStyle(
                color: Color(0xFFFF0000),
                onHover: ElStyle(color: Color(0xFF0000FF)),
              ),
              child: ElView(child: 'hello'),
            ),
          ),
        );

        final outer = allRenderViews(tester).first;
        outer.setHover(true);
        await tester.pump();

        final inner = allRenderViews(tester).last;
        expect(
          inner.committedResolvedStyle.inheritedText.color,
          const Color(0xFF0000FF),
          reason: '父 hover 切 color → propagator 通知子拿父最新 color',
        );

        outer.setHover(false);
        await tester.pump();
        expect(inner.committedResolvedStyle.inheritedText.color, const Color(0xFFFF0000));
      });

      testWidgets('深层传播使用直接父节点最新 resolved style', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: ElView(
              style: ElStyle(color: Color(0xFFFF0000), fontSize: 12),
              child: ElView(
                style: ElStyle(fontSize: 20),
                child: ElView(child: 'leaf'),
              ),
            ),
          ),
        );

        var views = allRenderViews(tester);
        expect(views[2].committedResolvedStyle.inheritedText.color, const Color(0xFFFF0000));
        expect(views[2].committedResolvedStyle.inheritedText.fontSize, 20);

        await tester.pumpWidget(
          const MaterialApp(
            home: ElView(
              style: ElStyle(color: Color(0xFF0000FF), fontSize: 12),
              child: ElView(
                style: ElStyle(fontSize: 20),
                child: ElView(child: 'leaf'),
              ),
            ),
          ),
        );
        await tester.pump();

        views = allRenderViews(tester);
        expect(views[2].committedResolvedStyle.inheritedText.color, const Color(0xFF0000FF));
        expect(
          views[2].committedResolvedStyle.inheritedText.fontSize,
          20,
          reason: 'leaf 应继承直接父节点的新 committed style，保留直接父显式 fontSize',
        );
      });
    });

    group('继承传播的 damage 通道', () {
      testWidgets('父 color 变化：父子 ElView 不重 layout，子纯文本 painter lazy layout', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: ElView(
              style: ElStyle(width: 200, height: 80, color: Color(0xFFFF0000)),
              child: ElView(child: 'inherited text'),
            ),
          ),
        );

        final views = allRenderViews(tester);
        final outer = views.first;
        final inner = views.last;
        final outerBefore = outer.debugLayoutCount;
        final innerBefore = inner.debugLayoutCount;
        final textBefore = ((inner.textEngineForTest?.stringPainterLayoutCountForTest) ?? 0);

        await tester.pumpWidget(
          const MaterialApp(
            home: ElView(
              style: ElStyle(width: 200, height: 80, color: Color(0xFF0000FF)),
              child: ElView(child: 'inherited text'),
            ),
          ),
        );
        await tester.pump();

        // color 对父子 ElView 都是 paint-only，不触发 performLayout；
        // **T21**：painter 侧也走 paint-only 分级，painter.layout 计数**不**再增——
        // ensureStringPainterFresh 内 compareTo 判定 paint 级，SDK TextPainter
        // 内部保 layout cache（_rebuildParagraphForPaint 惰性重建 paragraph）。
        expect(outer.debugLayoutCount, outerBefore, reason: '父 ElView color 是 paint-only，不重 layout');
        expect(inner.debugLayoutCount, innerBefore, reason: '子 ElView color 是 paint-only，不重 performLayout');
        expect(
          ((inner.textEngineForTest?.stringPainterLayoutCountForTest) ?? 0),
          textBefore,
          reason: 'T21：子文本 color paint-only 分级，不再触发 painter.layout()',
        );
        expect(inner.committedResolvedStyle.inheritedText.color, const Color(0xFF0000FF));
      });

      testWidgets('父 fontSize 变化：父子 debugLayoutCount 都增（layout-affecting）', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: ElView(
              style: ElStyle(width: 200, height: 80, fontSize: 14),
              child: ElView(child: 'inherited'),
            ),
          ),
        );

        final views = allRenderViews(tester);
        final outer = views.first;
        final inner = views.last;
        final outerLayoutsBefore = outer.debugLayoutCount;
        final innerLayoutsBefore = inner.debugLayoutCount;

        await tester.pumpWidget(
          const MaterialApp(
            home: ElView(
              style: ElStyle(width: 200, height: 80, fontSize: 24),
              child: ElView(child: 'inherited'),
            ),
          ),
        );
        await tester.pump();

        expect(outer.debugLayoutCount, greaterThan(outerLayoutsBefore));
        expect(
          inner.debugLayoutCount,
          greaterThan(innerLayoutsBefore),
          reason: 'fontSize 是 layout-affecting 继承字段，子必须重 layout',
        );
      });
    });

    group('深嵌套 + 截断', () {
      testWidgets('grandparent.color → 中间子显式 color → 叶子被中间截断', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: ElView(
              style: ElStyle(color: Color(0xFFFF0000)), // grandparent: red
              child: ElView(
                style: ElStyle(color: Color(0xFF00FF00)), // parent: green
                child: ElView(child: 'leaf'), // leaf 无 color，继承 parent
              ),
            ),
          ),
        );

        final views = allRenderViews(tester);
        expect(views, hasLength(3));
        expect(views[0].committedResolvedStyle.inheritedText.color, const Color(0xFFFF0000));
        expect(views[1].committedResolvedStyle.inheritedText.color, const Color(0xFF00FF00));
        expect(
          views[2].committedResolvedStyle.inheritedText.color,
          const Color(0xFF00FF00),
          reason: 'leaf 继承 parent.color (绿)，被 parent 截断从 grandparent (红) 的传播',
        );
      });

      testWidgets('grandparent.color 变 → 中间子截断 → leaf 不受影响', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: ElView(
              style: ElStyle(color: Color(0xFFFF0000)),
              child: ElView(
                style: ElStyle(color: Color(0xFF00FF00)),
                child: ElView(child: 'leaf'),
              ),
            ),
          ),
        );

        final leafBefore = allRenderViews(tester)[2].committedResolvedStyle.inheritedText.color;

        await tester.pumpWidget(
          const MaterialApp(
            home: ElView(
              style: ElStyle(color: Color(0xFF0000FF)), // grandparent 改
              child: ElView(
                style: ElStyle(color: Color(0xFF00FF00)),
                child: ElView(child: 'leaf'),
              ),
            ),
          ),
        );
        await tester.pump();

        final leafAfter = allRenderViews(tester)[2].committedResolvedStyle.inheritedText.color;
        expect(leafAfter, leafBefore, reason: 'grandparent.color 变化被中间子截断 → leaf 应不变');
      });
    });
  });

  group('显式继承优先级', () {
    ResolvedStyle childText(WidgetTester tester) =>
        tester.renderObject<ElRenderView>(find.byKey(const ValueKey('child'))).committedResolvedStyle;

    testWidgets('子显式 decorationColor：祖先改 decorationColor 不覆盖子', (tester) async {
      Widget tree(Color ancestor) => MaterialApp(
        home: ElView(
          style: ElStyle(decorationColor: ancestor),
          child: const ElView(
            key: ValueKey('child'),
            style: ElStyle(decorationColor: Color(0xFF00FF00)),
            child: 'x',
          ),
        ),
      );

      await tester.pumpWidget(tree(const Color(0xFFFF0000)));
      expect(childText(tester).inheritedText.decorationColor, const Color(0xFF00FF00), reason: '子显式 green，初始即 green');

      await tester.pumpWidget(tree(const Color(0xFF0000FF)));
      expect(
        childText(tester).inheritedText.decorationColor,
        const Color(0xFF00FF00),
        reason: '修复前：propagator 未截断 decorationColor → tryInheritPatch 用父 blue 覆盖子 green',
      );
    });

    testWidgets('子显式 textAlign：祖先改 textAlign 不覆盖子', (tester) async {
      Widget tree(TextAlign ancestor) => MaterialApp(
        home: ElView(
          style: ElStyle(textAlign: ancestor),
          child: const ElView(
            key: ValueKey('child'),
            style: ElStyle(textAlign: TextAlign.right),
            child: 'x',
          ),
        ),
      );

      await tester.pumpWidget(tree(TextAlign.left));
      expect(childText(tester).inheritedText.textAlign, TextAlign.right);

      await tester.pumpWidget(tree(TextAlign.center));
      expect(childText(tester).inheritedText.textAlign, TextAlign.right, reason: '子显式 right 不应被祖先 center 覆盖');
    });

    testWidgets('正控：子未声明 decorationColor → 正常继承且随祖先变化', (tester) async {
      Widget tree(Color ancestor) => MaterialApp(
        home: ElView(
          style: ElStyle(decorationColor: ancestor),
          child: const ElView(key: ValueKey('child'), child: 'x'),
        ),
      );

      await tester.pumpWidget(tree(const Color(0xFFFF0000)));
      expect(childText(tester).inheritedText.decorationColor, const Color(0xFFFF0000), reason: '未声明 → 继承祖先 red');

      await tester.pumpWidget(tree(const Color(0xFF0000FF)));
      expect(
        childText(tester).inheritedText.decorationColor,
        const Color(0xFF0000FF),
        reason: '未声明 → 传播未被截断，跟随祖先 red→blue（确认修复没误伤正常继承）',
      );
    });
  });

  group('挂载级联', () {
    List<ElRenderView> allRenderViews(WidgetTester tester) =>
        tester.renderObjectList<ElRenderView>(find.byType(ElView)).toList();

    Widget wrap(Widget child) => MediaQuery(
      data: const MediaQueryData(),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Align(alignment: Alignment.topLeft, child: child),
      ),
    );

    setUp(() {
      elViewDebugUseMountFastPath = true;
    });

    tearDown(() {
      elViewDebugUseMountFastPath = true; // 恢复默认
    });

    testWidgets('探针：EmptyView-100 mount 计数 ≤ N + 慢路径 = 2N（对照锁）', (tester) async {
      tester.view.physicalSize = const Size(720, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      Widget build() => ElView(
        style: const ElStyle(width: 360, height: 800),
        child: List<Widget>.generate(100, (_) => const ElView(), growable: false),
      );

      // 快路径：期望 cascadeTick ≈ N+1
      elViewDebugUseMountFastPath = true;
      BenchmarkProbe.reset();
      await tester.pumpWidget(wrap(build()));
      final fastSnap = BenchmarkProbe.snapshot();
      debugPrint('T24 mount test: EmptyView-100 fast snap=$fastSnap');
      expect(fastSnap['cascadeTickCount'], lessThanOrEqualTo(101));
      expect(fastSnap['builderBuildCount'], 101);
      expect(fastSnap['mountFastPathHitCount'], 101);
      expect(fastSnap['attachReresolveCount'], 0);

      await tester.pumpWidget(wrap(const SizedBox.shrink()));

      // 慢路径：期望 cascadeTick ≈ 2N（对照锁）
      elViewDebugUseMountFastPath = false;
      BenchmarkProbe.reset();
      await tester.pumpWidget(wrap(build()));
      final slowSnap = BenchmarkProbe.snapshot();
      debugPrint('T24 mount test: EmptyView-100 slow snap=$slowSnap');
      expect(slowSnap['cascadeTickCount'], 201);
      // 不再跨节点缓存解析结果；每次 tick 构建一次，快路径仍省去重复 attach 工作。
      expect(slowSnap['builderBuildCount'], 201);
      expect(slowSnap['attachReresolveCount'], 100);
      expect(slowSnap['mountFastPathHitCount'], 0);
    });

    ({List<Map<ElTransitionField, Object?>> perNodeCommitted, List<Map<ElTransitionField, Object?>> perNodeTarget})
    captureSnapshot(WidgetTester tester) {
      final views = allRenderViews(tester);
      final committed = <Map<ElTransitionField, Object?>>[];
      final target = <Map<ElTransitionField, Object?>>[];
      for (final v in views) {
        final c = <ElTransitionField, Object?>{};
        final t = <ElTransitionField, Object?>{};
        for (final f in ElTransitionField.values) {
          final spec = fieldSpecOf(f);
          c[f] = spec.read(v.committedResolvedStyle);
          t[f] = spec.read(v.targetStyleForTest);
        }
        committed.add(c);
        target.add(t);
      }
      return (perNodeCommitted: committed, perNodeTarget: target);
    }

    Future<
      ({List<Map<ElTransitionField, Object?>> perNodeCommitted, List<Map<ElTransitionField, Object?>> perNodeTarget})
    >
    pumpAndCapture(WidgetTester tester, Widget child) async {
      await tester.pumpWidget(wrap(child));
      return captureSnapshot(tester);
    }

    testWidgets('bit-identical：base 树快慢路径 committed 逐字段相等', (tester) async {
      final tree = ElView(
        style: const ElStyle(
          width: 400,
          height: 200,
          color: Color(0xffff0000),
          fontSize: 18,
          fontWeight: FontWeight.w700,
          padding: .all(8),
          bgColor: Color(0xff112233),
        ),
        child: const ElView(child: 'inherited hello'),
      );

      elViewDebugUseMountFastPath = true;
      final fast = await pumpAndCapture(tester, tree);
      await tester.pumpWidget(wrap(const SizedBox.shrink()));
      elViewDebugUseMountFastPath = false;
      final slow = await pumpAndCapture(tester, tree);

      expect(fast.perNodeCommitted.length, slow.perNodeCommitted.length);
      for (var n = 0; n < fast.perNodeCommitted.length; n++) {
        for (final f in ElTransitionField.values) {
          expect(fast.perNodeCommitted[n][f], slow.perNodeCommitted[n][f], reason: 'committed 节点$n 字段 $f 快慢不等');
          expect(fast.perNodeTarget[n][f], slow.perNodeTarget[n][f], reason: 'target 节点$n 字段 $f 快慢不等');
        }
      }
    });

    testWidgets('bit-identical：变体预置态（onDisabled/onDark）快慢等价', (tester) async {
      // 预置 事件 disabled=true + brightness=dark，让 base + 变体全命中
      final tree = ElView(
        themeMode: const ElThemeMode(brightness: Brightness.dark),
        event: ElEvent(disabled: true),

        style: const ElStyle(
          width: 300,
          height: 100,
          color: Color(0xff000000),
          bgColor: Color(0xff111111),
          padding: .all(4),
          onDisabled: ElStyle(color: Color(0xff888888), bgColor: Color(0xff222222)),
          onDark: ElStyle(color: Color(0xffe0e0e0), bgColor: Color(0xff333333)),
        ),
        child: const ElView(child: 'variant preset'),
      );

      elViewDebugUseMountFastPath = true;
      final fast = await pumpAndCapture(tester, tree);
      await tester.pumpWidget(wrap(const SizedBox.shrink()));
      elViewDebugUseMountFastPath = false;
      final slow = await pumpAndCapture(tester, tree);

      for (var n = 0; n < fast.perNodeCommitted.length; n++) {
        for (final f in ElTransitionField.values) {
          expect(fast.perNodeCommitted[n][f], slow.perNodeCommitted[n][f], reason: 'committed 节点$n $f 快慢不等');
        }
      }
    });

    testWidgets('mount 后 setStyle 触发 transition + 走原路径 fast_patch/slow', (tester) async {
      elViewDebugUseMountFastPath = true;
      Widget build(Color bg) => ElView(
        style: ElStyle(
          width: 200,
          height: 100,
          bgColor: bg,
          transitions: const [ElTransition.all(Duration(milliseconds: 200))],
        ),
      );

      await tester.pumpWidget(wrap(build(const Color(0xff000000))));
      final rv = tester.renderObject<ElRenderView>(find.byType(ElView));
      expect(rv.hasActiveAnimationsForTest, isFalse, reason: '首挂载不启动动画');

      // 首次 rebuild — style 改（新 ElStyle 实例），transition 应生效。
      // 注：`transitions != null` 会让 fast_patch tryPatch bail 4 走 slow path；
      // 通过 driver 状态判定：动画是否启动。
      await tester.pumpWidget(wrap(build(const Color(0xffffffff))));
      expect(rv.hasActiveAnimationsForTest, isTrue, reason: '首挂后 setStyle 触发 transition（快路径只影响首帧，之后 update 路径原样）');
    });

    testWidgets('mount 后 setStyle（无 transition）fast_patch 命中', (tester) async {
      elViewDebugUseMountFastPath = true;
      Widget build(Color bg) => ElView(style: ElStyle(width: 200, height: 100, bgColor: bg));

      await tester.pumpWidget(wrap(build(const Color(0xff000000))));
      BenchmarkProbe.reset();
      await tester.pumpWidget(wrap(build(const Color(0xffffffff))));
      expect(BenchmarkProbe.fastPatchHitCount, greaterThanOrEqualTo(1), reason: '无 transitions 时 update 走 fast_patch');
    });

    testWidgets('reparent（GlobalKey）：detach + re-attach 后 committed 与首挂等价', (tester) async {
      elViewDebugUseMountFastPath = true;
      final k = GlobalKey();

      Widget parentA(Widget child) => ElView(
        style: const ElStyle(color: Color(0xffff0000), fontSize: 16),
        child: child,
      );
      Widget parentB(Widget child) => ElView(
        style: const ElStyle(color: Color(0xff00ff00), fontSize: 20),
        child: child,
      );

      final leaf = ElView(key: k, child: 'leaf');

      // 首挂到 A 下
      await tester.pumpWidget(wrap(parentA(leaf)));
      final rv1 = tester.renderObject<ElRenderView>(find.byKey(k));
      expect(rv1.committedResolvedStyle.inheritedText.color, const Color(0xffff0000));
      expect(rv1.committedResolvedStyle.inheritedText.fontSize, 16);

      // reparent 到 B 下
      await tester.pumpWidget(wrap(parentB(leaf)));
      final rv2 = tester.renderObject<ElRenderView>(find.byKey(k));
      expect(rv2.committedResolvedStyle.inheritedText.color, const Color(0xff00ff00));
      expect(rv2.committedResolvedStyle.inheritedText.fontSize, 20);
    });

    testWidgets('root 无 ElView 祖先：mount 快路径下 committed 仍正确', (tester) async {
      elViewDebugUseMountFastPath = true;
      await tester.pumpWidget(
        wrap(
          const ElView(
            style: ElStyle(width: 100, height: 50, bgColor: Color(0xff112233), color: Color(0xff445566)),
          ),
        ),
      );

      final rv = tester.renderObject<ElRenderView>(find.byType(ElView));
      expect(rv.committedResolvedStyle.box.bgColor, const Color(0xff112233));
      expect(rv.committedResolvedStyle.inheritedText.color, const Color(0xff445566));
    });
  });

  group('嵌套暗色继承', () {
    const base = Color(0xffcc3300);

    const activeDark = Color(0xff2266cc);

    const targetKey = ValueKey('nested-dark');

    Widget page({required Brightness brightness, required Widget child}) => Directionality(
      textDirection: .ltr,
      child: Align(
        alignment: .topLeft,
        child: ElView(
          themeMode: ElThemeMode(brightness: brightness, duration: Duration.zero),
          child: child,
        ),
      ),
    );

    ElView target({required bool disabled, bool enabled = true, ElThemeMode? themeMode}) => ElView(
      key: targetKey,
      event: disabled && enabled ? ElEvent(disabled: true) : null,

      themeMode: themeMode,
      style: ElStyle(
        width: 60,
        height: 30,
        bgColor: base,
        onDark: !disabled && enabled ? const ElStyle(bgColor: activeDark) : null,
        onDisabled: disabled ? const ElStyle(onDark: ElStyle(bgColor: activeDark)) : null,
      ),
    );

    for (final disabled in [false, true]) {
      final state = disabled ? 'disabled' : '普通样式';
      testWidgets('$state 嵌套 onDark 在继承暗色的第一帧生效', (tester) async {
        await tester.pumpWidget(
          page(
            brightness: .dark,
            child: target(disabled: disabled),
          ),
        );
        expect(tester.getSize(find.byKey(targetKey)), const Size(60, 30));
        expect(find.byKey(targetKey), paints..rect(color: activeDark));
      });

      testWidgets('$state 保持激活时，祖先明暗往返更新嵌套颜色', (tester) async {
        final child = target(disabled: disabled);
        for (final brightness in [Brightness.light, Brightness.dark, Brightness.light]) {
          await tester.pumpWidget(page(brightness: brightness, child: child));
          final render = tester.renderObject<ElRenderView>(find.byKey(targetKey));
          expect(render.targetStyleForTest.box.bgColor, brightness == .dark ? activeDark : base);
          await tester.pumpAndSettle();
          expect(find.byKey(targetKey), paints..rect(color: brightness == .dark ? activeDark : base));
        }
      });

      testWidgets('$state 未激活或本地明确浅色时，嵌套暗色不得生效', (tester) async {
        await tester.pumpWidget(
          page(
            brightness: .dark,
            child: target(disabled: disabled, enabled: false),
          ),
        );
        expect(find.byKey(targetKey), paints..rect(color: base));
        await tester.pumpWidget(
          page(
            brightness: .dark,
            child: target(
              disabled: disabled,
              themeMode: const ElThemeMode(brightness: .light),
            ),
          ),
        );
        final render = tester.renderObject<ElRenderView>(find.byKey(targetKey));
        expect(render.targetStyleForTest.box.bgColor, base);
        await tester.pumpAndSettle();
        expect(find.byKey(targetKey), paints..rect(color: base));
      });
    }
  });

  group('嵌套状态渲染', () {
    ElRenderView renderOf(WidgetTester tester) => tester.renderObject<ElRenderView>(find.byType(ElView));

    testWidgets('嵌套 onDark(onHover:...) 无顶层 onHover — hover+dark 生效', (tester) async {
      const base = Color(0xFF000000);
      const darkHover = Color(0xFF00FFAA);
      await tester.pumpWidget(
        const MaterialApp(
          home: ElView(
            style: ElStyle(
              bgColor: base,
              onDark: ElStyle(onHover: ElStyle(bgColor: darkHover)),
            ),
          ),
        ),
      );
      final render = renderOf(tester);

      // 未 dark 未 hover：base
      expect(render.committedResolvedStyle.box.bgColor, base);

      // dark on, no hover：base（onDark 本身未声明 bgColor，嵌套 hover 未激活）
      render.setDark(true);
      await tester.pump();
      expect(render.committedResolvedStyle.box.bgColor, base, reason: 'dark on 但 hover 未激活 → 嵌套链剪枝');

      // dark + hover：嵌套链激活
      render.setHover(true);
      await tester.pump();
      expect(render.committedResolvedStyle.box.bgColor, darkHover, reason: 'dark+hover 齐活，嵌套链 bgColor 生效');

      // hover 退出 → 回到 base
      render.setHover(false);
      await tester.pump();
      expect(render.committedResolvedStyle.box.bgColor, base);
    });

    testWidgets('setStyle 移除嵌套 hover 声明 → stale hover 位被清', (tester) async {
      const base = Color(0xFF010203);
      const nested = Color(0xFF040506);
      Widget build(bool withNested) => MaterialApp(
        home: ElView(
          style: withNested
              ? const ElStyle(
                  bgColor: base,
                  onDark: ElStyle(onHover: ElStyle(bgColor: nested)),
                )
              : const ElStyle(bgColor: base),
        ),
      );
      await tester.pumpWidget(build(true));
      final render = renderOf(tester);
      render.setDark(true);
      render.setHover(true);
      await tester.pump();
      expect(render.committedResolvedStyle.box.bgColor, nested);

      // 移除嵌套声明：hover state bit 应被清（新 mask 里无 hover 位）
      await tester.pumpWidget(build(false));
      await tester.pump();
      // 无嵌套 hover 声明后：paint 应回 base（stale hover bit 清 0 后就算残留也无变体可 emit）
      expect(render.committedResolvedStyle.box.bgColor, base, reason: 'stale hover 位清除后 emit 回 base');
    });

    testWidgets('嵌套变体激活时 set style 改 base 字段走 slow path — 输出正确', (tester) async {
      const nested = Color(0xFF778899);
      const baseA = Color(0xFF010101);
      const baseB = Color(0xFF020202);
      Widget build(Color baseColor) => MaterialApp(
        home: ElView(
          style: ElStyle(
            bgColor: baseColor,
            onDark: const ElStyle(onHover: ElStyle(bgColor: nested)),
          ),
        ),
      );
      await tester.pumpWidget(build(baseA));
      final render = renderOf(tester);
      render.setDark(true);
      render.setHover(true);
      await tester.pump();
      expect(render.committedResolvedStyle.box.bgColor, nested);

      // 嵌套激活时切 base 字段（fast patch Bail 2 应触发 → slow path）
      await tester.pumpWidget(build(baseB));
      await tester.pump();
      // 嵌套仍激活 → 输出仍是 nested（嵌套 bgColor 覆盖 base）
      expect(render.committedResolvedStyle.box.bgColor, nested, reason: '嵌套激活时改 base，结果仍是嵌套值');

      // 关掉 hover → base 换成新的 baseB 生效
      render.setHover(false);
      await tester.pump();
      expect(render.committedResolvedStyle.box.bgColor, baseB, reason: '嵌套退出后新 base 生效');
    });
  });

  group('嵌套断点传播', () {
    void setWindow(WidgetTester tester, double width) {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    }

    ElRenderView findByKey(WidgetTester tester, Key key) => tester.renderObject<ElRenderView>(find.byKey(key));

    testWidgets('嵌套断点声明者的透明后代：resize 传播后仍按声明者断点取位', (tester) async {
      setWindow(tester, 690);
      const bg = Color(0xFF000000);
      const bgSm = Color(0xFF00FF00);
      final leafKey = UniqueKey();
      await tester.pumpWidget(
        _directionalHost(
          ElView(
            child: ElView(
              breakpoint: const ElBreakpoint(sm: 700),
              child: ElView(
                key: leafKey,
                style: const ElStyle(
                  bgColor: bg,
                  sm: ElStyle(bgColor: bgSm),
                ),
                child: SizedBox(width: 100, height: 50),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        findByKey(tester, leafKey).committedResolvedStyle.box.bgColor,
        bgSm,
        reason: '690 <= 声明者 sm(700) → 后代 sm 命中（根默认 sm 上界 640 不命中）',
      );

      // 根节点位不跨档的 resize（690 → 680 对默认断点同档），传播后叶子必须保持
      // 声明者口径的 sm 位——若外层 walker 在声明者接管后继续下钻，会用根节点
      // 的位（sm 关）把声明者刚写下的位覆盖掉。
      tester.view.physicalSize = const Size(680, 900);
      await tester.pump();
      await tester.pump();
      expect(
        findByKey(tester, leafKey).committedResolvedStyle.box.bgColor,
        bgSm,
        reason: '680 仍 <= 声明者 sm(700)，resize 传播不得用根节点位覆盖声明者子树',
      );
    });

    testWidgets('透明链后代：resize 跨档后位照常下推翻转', (tester) async {
      setWindow(tester, 800);
      const bg = Color(0xFF000000);
      const bgMd = Color(0xFF0000FF);
      final leafKey = UniqueKey();
      await tester.pumpWidget(
        _directionalHost(
          ElView(
            child: ElView(
              child: ElView(
                key: leafKey,
                style: const ElStyle(
                  bgColor: bg,
                  md: ElStyle(bgColor: bgMd),
                ),
                child: SizedBox(width: 100, height: 50),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(findByKey(tester, leafKey).committedResolvedStyle.box.bgColor, bgMd, reason: '800 <= md(1024) → md 命中');

      tester.view.physicalSize = const Size(1300, 900);
      await tester.pump();
      await tester.pump();
      expect(
        findByKey(tester, leafKey).committedResolvedStyle.box.bgColor,
        bg,
        reason: '1300 > md(1024) → md 位关闭，透明链下推仍生效',
      );
    });
  });

  group('响应式渲染', () {
    void setWindow(WidgetTester tester, double width) {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    }

    ElRenderView findByKey(WidgetTester tester, Key key) => tester.renderObject<ElRenderView>(find.byKey(key));

    testWidgets('窗口 800：sm 不命中，md/lg 同时命中，高档 lg 胜出', (tester) async {
      setWindow(tester, 800);
      const bg = Color(0xFF000000);
      const bgSm = Color(0xFF00FF00);
      const bgMd = Color(0xFF0000FF);
      const bgLg = Color(0xFFFF0000);
      final key = UniqueKey();
      await tester.pumpWidget(
        _directionalHost(
          ElView(
            key: key,
            style: ElStyle(
              bgColor: bg,
              sm: ElStyle(bgColor: bgSm),
              md: ElStyle(bgColor: bgMd),
              lg: ElStyle(bgColor: bgLg),
            ),
            child: SizedBox(width: 100, height: 50),
          ),
        ),
      );
      await tester.pump();
      final render = findByKey(tester, key);
      // 800 > sm(640) → sm 不命中；800 <= md(1024) 且 <= lg(1920) → 双命中，
      // 档序后 emit 的 lg 覆盖 md。
      expect(render.committedResolvedStyle.box.bgColor, bgLg, reason: '上界语义多档命中，高档 lg 胜出');
    });

    testWidgets('resize 跨档 800→1300：md 位翻转关闭，样式回落 base', (tester) async {
      setWindow(tester, 800);
      const bg = Color(0xFF000000);
      const bgMd = Color(0xFF0000FF);
      final key = UniqueKey();
      await tester.pumpWidget(
        _directionalHost(
          ElView(
            key: key,
            style: ElStyle(
              bgColor: bg,
              md: ElStyle(bgColor: bgMd),
            ),
            child: SizedBox(width: 100, height: 50),
          ),
        ),
      );
      await tester.pump();
      var render = findByKey(tester, key);
      expect(render.committedResolvedStyle.box.bgColor, bgMd, reason: '800 <= md(1024) → md 命中');

      // resize
      tester.view.physicalSize = const Size(1300, 900);
      await tester.pump();
      await tester.pump();
      render = findByKey(tester, key);
      expect(render.committedResolvedStyle.box.bgColor, bg, reason: '1300 > md(1024) → md 位关闭，回落 base');
    });

    testWidgets('breakpoint 配置覆盖：sm=700 → 690 命中 sm，720 不命中', (tester) async {
      setWindow(tester, 690);
      const bg = Color(0xFF000000);
      const bgSm = Color(0xFF00FF00);
      final key = UniqueKey();
      await tester.pumpWidget(
        _directionalHost(
          ElView(
            key: key,
            // 声明本地断点：sm 上界 640 → 700。
            breakpoint: const ElBreakpoint(sm: 700),
            style: ElStyle(
              bgColor: bg,
              sm: ElStyle(bgColor: bgSm),
            ),
            child: SizedBox(width: 100, height: 50),
          ),
        ),
      );
      await tester.pump();
      var render = findByKey(tester, key);
      // 690 <= sm(700) → sm 命中（默认上界 640 时 690 不会命中，证明覆盖生效）。
      expect(render.committedResolvedStyle.box.bgColor, bgSm, reason: '690 <= 覆盖后的 sm(700) → 命中');

      tester.view.physicalSize = const Size(720, 900);
      await tester.pump();
      await tester.pump();
      render = findByKey(tester, key);
      expect(render.committedResolvedStyle.box.bgColor, bg, reason: '720 > sm(700) → sm 位关闭');
    });

    testWidgets('breakpoint 配置继承合并：祖先 sm=700，后代补 md=1200', (tester) async {
      setWindow(tester, 1100);
      final mdChildKey = UniqueKey();
      final smChildKey = UniqueKey();
      const bg = Color(0xFF000000);
      const bgSm = Color(0xFF00FF00);
      const bgMd = Color(0xFF0000FF);
      await tester.pumpWidget(
        _directionalHost(
          ElView(
            breakpoint: const ElBreakpoint(sm: 700),
            child: ElView(
              key: mdChildKey,
              breakpoint: const ElBreakpoint(md: 1200),
              // 后代 effective = sm:700（继承祖先）+ md:1200（本地）。
              // 1100 <= md(1200) → md 命中（默认 md=1024 时 1100 不会命中，
              // 证明本地覆盖生效）。
              style: ElStyle(
                bgColor: bg,
                md: ElStyle(bgColor: bgMd),
              ),
              child: ElView(
                key: smChildKey,
                // 孙代无本地声明，effective 全部继承：sm=700。
                // 1100 > sm(700) → sm 不命中 → base。
                style: ElStyle(
                  bgColor: bg,
                  sm: ElStyle(bgColor: bgSm),
                ),
                child: const SizedBox(width: 50, height: 50),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        findByKey(tester, mdChildKey).committedResolvedStyle.box.bgColor,
        bgMd,
        reason: '本地 md=1200 覆盖默认 1024，1100 命中 md',
      );
      expect(findByKey(tester, smChildKey).committedResolvedStyle.box.bgColor, bg, reason: '继承 sm=700，1100 > 700 不命中');

      // 缩窄到 690：孙代 sm 命中（继承的 700 上界；默认 640 时 690 不会命中，
      // 证明 sm=700 确实沿链继承）。
      tester.view.physicalSize = const Size(690, 900);
      await tester.pump();
      await tester.pump();
      expect(
        findByKey(tester, smChildKey).committedResolvedStyle.box.bgColor,
        bgSm,
        reason: '继承祖先 sm=700，690 <= 700 命中',
      );
    });

    testWidgets('ElView.of 观察响应式位翻转', (tester) async {
      setWindow(tester, 800);
      final key = UniqueKey();
      bool? lastMd;
      await tester.pumpWidget(
        _directionalHost(
          ElView(
            key: key,
            style: const ElStyle(bgColor: Color(0xFF000000)),
            child: Builder(
              builder: (context) {
                lastMd = ElView.of(context).md;
                return const SizedBox(width: 100, height: 50);
              },
            ),
          ),
        ),
      );
      await tester.pump();
      expect(lastMd, isTrue, reason: '800 <= md(1024) → md 命中');

      tester.view.physicalSize = const Size(1300, 900);
      await tester.pump();
      await tester.pump();
      expect(lastMd, isFalse, reason: 'resize 到 1300 > md(1024)，md 位关闭并重建读取者');
    });

    testWidgets('inheritSize:false 容器基准：自宽 600 命中 sm，不按窗口 1920 断档', (tester) async {
      setWindow(tester, 1920);
      const bg = Color(0xFF000000);
      const bgSm = Color(0xFF00FF00);
      final key = UniqueKey();
      await tester.pumpWidget(
        _directionalHost(
          SizedBox(
            width: 600,
            height: 300,
            child: ElView(
              key: key,
              inheritSize: false,
              style: ElStyle(
                bgColor: bg,
                sm: ElStyle(bgColor: bgSm),
              ),
              child: const SizedBox(width: 50, height: 50),
            ),
          ),
        ),
      );
      // 首帧 selfSizeBasis 位可能未收敛，等一帧 post-frame 回调 + 一帧生效。
      await tester.pump();
      await tester.pump();
      await tester.pump();
      final render = findByKey(tester, key);
      // 自宽 600 <= sm(640) → sm 命中；若基准错误取窗口 1920（> 640）→ sm
      // 不会命中 → 断言失败。
      expect(render.committedResolvedStyle.box.bgColor, bgSm, reason: 'inheritSize:false 以本节点 600 宽为基准，sm 命中');
    });
  });

  group('状态切换快路径', () {
    Widget wrap(Widget child) => MediaQuery(
      data: const MediaQueryData(size: Size(1280, 800)),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Align(alignment: Alignment.topLeft, child: child),
      ),
    );

    testWidgets('T-variant3：声明 md 响应式变体的 20 子翻转 bgColor → fast patch 全命中', (tester) async {
      // 1000 <= md(1024) → md 位激活（上界语义，2026-07-16 定版）。
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      Widget build(Color color) => ElView(
        style: const ElStyle(width: 1000, height: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 20; i++)
              ElView(
                // 每帧新建 ElStyle 实例（churn 形态）；md 声明 padding（1000
                // 宽下 md 位激活但不覆写 bgColor）。const 变体保 Bail 1 identical。
                style: ElStyle(
                  width: 100,
                  height: 20,
                  bgColor: color,
                  md: const ElStyle(padding: EdgeInsets.all(4)),
                ),
              ),
          ],
        ),
      );

      await tester.pumpWidget(wrap(build(const Color(0xFFFF0000))));
      BenchmarkProbe.reset();
      await tester.pumpWidget(wrap(build(const Color(0xFF0000FF))));

      // 20 个子 bgColor 变化全走 fast patch；旧 Bail 2 下此值恒 0（md 位激活
      // 即整体 bail）、cascadeTick = 20。
      expect(BenchmarkProbe.fastPatchHitCount, 20, reason: '响应式变体激活不再一票 bail');
      expect(BenchmarkProbe.cascadeTickCount, 0, reason: '零 slow path 逃逸');

      // 视觉正确性：md 激活的 padding 生效 + 新 bgColor 生效。
      final renders = tester.renderObjectList<ElRenderView>(find.byType(ElView)).toList();
      final child = renders.firstWhere((r) => r.committedResolvedStyle.box.bgColor == const Color(0xFF0000FF));
      expect(child.committedResolvedStyle.box.padding?.resolve(TextDirection.ltr).left, 4);
    });

    testWidgets('T-variant3：dark 态下声明 onDark 的子翻转 width → fast patch 命中', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      Widget build(double width) => ElView(
        themeMode: const ElThemeMode(brightness: Brightness.dark),
        style: const ElStyle(width: 1000, height: 700),
        child: ElView(
          style: ElStyle(
            width: width,
            height: 20,
            // dark 激活但只覆写 color（继承字段），width diff 不相交。
            onDark: const ElStyle(color: Color(0xFFEEEEEE)),
          ),
        ),
      );

      await tester.pumpWidget(wrap(build(100)));
      BenchmarkProbe.reset();
      await tester.pumpWidget(wrap(build(200)));

      expect(BenchmarkProbe.fastPatchHitCount, greaterThanOrEqualTo(1), reason: 'dark 主题下 onDark 声明不再一票 bail');
      // dark 变体 color 保持生效。
      final renders = tester.renderObjectList<ElRenderView>(find.byType(ElView)).toList();
      final child = renders.firstWhere((r) => r.committedResolvedStyle.box.width == const ElDimension.pixels(200));
      expect(child.committedResolvedStyle.inheritedText.color, const Color(0xFFEEEEEE));
    });

    testWidgets('T-variant3 安全锁：diff 字段被激活变体覆写 → 回 slow path 且末态取变体值', (tester) async {
      // 1000 <= md(1024) → md 位激活（上界语义）。
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // md 覆写 bgColor（md 激活）；base bgColor 翻转必须走 slow path，
      // 且末态恒为变体色（base 新值不得穿透）。
      Widget build(Color base) => ElView(
        style: ElStyle(
          width: 100,
          height: 20,
          bgColor: base,
          md: const ElStyle(bgColor: Color(0xFF00FF00)),
        ),
      );

      await tester.pumpWidget(wrap(build(const Color(0xFFFF0000))));
      BenchmarkProbe.reset();
      await tester.pumpWidget(wrap(build(const Color(0xFF0000FF))));

      expect(BenchmarkProbe.fastPatchHitCount, 0, reason: 'dirty ∩ 激活链 declaredMask 非空必须 bail');
      final render = tester.renderObject<ElRenderView>(find.byType(ElView));
      expect(render.committedResolvedStyle.box.bgColor, const Color(0xFF00FF00), reason: '变体覆写值不被 base 穿透');
    });
  });

  group('基础解析', () {
    final emptyState = 0;

    group('StyleResolver.resolve 基础', () {
      test('null style + null parent → initial', () {
        final r = StyleResolver.resolve(style: null, parent: null, state: emptyState);
        expect(r.inheritedText.color, InheritedText.initial.color);
        expect(r.inheritedText.fontSize, InheritedText.initial.fontSize);
        expect(r.box.width, isNull);
        expect(r.box.bgColor, isNull);
      });

      test('全 group 字段写入', () {
        final r = StyleResolver.resolve(
          style: const ElStyle(
            color: Color(0xFFFF0000),
            fontSize: 16,
            width: 100,
            height: 50,
            bgColor: Color(0xFFFFFFFF),
          ),
          parent: null,
          state: emptyState,
        );
        expect(r.inheritedText.color, const Color(0xFFFF0000));
        expect(r.inheritedText.fontSize, 16);
        expect(r.box.width, const ElDimension.pixels(100));
        expect(r.box.height, const ElDimension.pixels(50));
        expect(r.box.bgColor, const Color(0xFFFFFFFF));
      });

      test('Adjuster: 负 width → null', () {
        final r = StyleResolver.resolve(style: const ElStyle(width: -10), parent: null, state: emptyState);
        expect(r.box.width, isNull, reason: '负值应被 adjuster clamp 成 null');
      });

      test('Adjuster: maxLines = 0 → null', () {
        final r = StyleResolver.resolve(style: const ElStyle(maxLines: 0), parent: null, state: emptyState);
        expect(r.inheritedText.maxLines, isNull);
      });

      test('Adjuster: 负 lineHeight → null', () {
        final r = StyleResolver.resolve(style: const ElStyle(lineHeight: -1.0), parent: null, state: emptyState);
        expect(r.inheritedText.lineHeight, isNull);
      });
    });
  });

  group('继承对象共享', () {
    final emptyState = 0;

    group('identical 共享 — 关键不变量', () {
      test('子声明 box 字段不影响 inherited group 共享', () {
        const parent = ResolvedStyle(
          inheritedText: InheritedText(color: Color(0xFFFF0000)),
          inheritedBox: InheritedBox(textDirection: TextDirection.ltr),
          box: Box(),
        );
        final r = StyleResolver.resolve(
          style: const ElStyle(width: 100, height: 50, bgColor: Color(0xFFFFFFFF)),
          parent: parent,
          state: emptyState,
        );
        expect(identical(r.inheritedText, parent.inheritedText), isTrue);
        expect(identical(r.inheritedBox, parent.inheritedBox), isTrue);
        // box 是独立写入
        expect(r.box.width, const ElDimension.pixels(100));
        expect(r.box.bgColor, const Color(0xFFFFFFFF));
      });

      test('子声明 color → inheritedText identical 断裂，inheritedBox 仍 identical', () {
        const parent = ResolvedStyle(
          inheritedText: InheritedText(color: Color(0xFFFF0000), fontSize: 16),
          inheritedBox: InheritedBox(textDirection: TextDirection.ltr),
          box: Box(),
        );
        final r = StyleResolver.resolve(
          style: const ElStyle(color: Color(0xFF00FF00)),
          parent: parent,
          state: emptyState,
        );
        expect(identical(r.inheritedText, parent.inheritedText), isFalse, reason: '写入 color 后 inheritedText 应是新对象');
        expect(identical(r.inheritedBox, parent.inheritedBox), isTrue, reason: '未触碰的 inheritedBox 必须保持 identical');
        expect(r.inheritedText.color, const Color(0xFF00FF00));
        expect(r.inheritedText.fontSize, 16, reason: '其他继承字段必须保留');
      });

      test('子声明 cursor → inheritedBox identical 断裂，inheritedText 保持', () {
        const parent = ResolvedStyle(
          inheritedText: InheritedText(color: Color(0xFFFF0000)),
          inheritedBox: InheritedBox(textDirection: TextDirection.ltr),
          box: Box(),
        );
        final r = StyleResolver.resolve(
          style: const ElStyle(cursor: SystemMouseCursors.click),
          parent: parent,
          state: emptyState,
        );
        expect(identical(r.inheritedText, parent.inheritedText), isTrue);
        expect(identical(r.inheritedBox, parent.inheritedBox), isFalse);
        expect(r.inheritedBox.cursor, SystemMouseCursors.click);
        expect(r.inheritedBox.textDirection, TextDirection.ltr, reason: 'textDirection 必须保留');
      });

      test('selfVariant 写入字段也会断 identical（但仅在状态激活时）', () {
        const parent = ResolvedStyle(
          inheritedText: InheritedText(color: Color(0xFFFF0000)),
          inheritedBox: InheritedBox(),
          box: Box(),
        );
        // 状态未激活：identical 保持
        final r1 = StyleResolver.resolve(
          style: const ElStyle(onHover: ElStyle(color: Color(0xFF00FF00))),
          parent: parent,
          state: emptyState,
        );
        expect(identical(r1.inheritedText, parent.inheritedText), isTrue);

        // 激活 hover：写入新 color，identical 断
        final hoverState = (1 << ViewState.hover.index);
        final r2 = StyleResolver.resolve(
          style: const ElStyle(onHover: ElStyle(color: Color(0xFF00FF00))),
          parent: parent,
          state: hoverState,
        );
        expect(identical(r2.inheritedText, parent.inheritedText), isFalse);
        expect(r2.inheritedText.color, const Color(0xFF00FF00));
      });

      test('子写入和父同值的 color → identical 共享（写入短路）', () {
        const parent = ResolvedStyle(
          inheritedText: InheritedText(color: Color(0xFFFF0000)),
          inheritedBox: InheritedBox(),
          box: Box(),
        );
        final r = StyleResolver.resolve(
          style: const ElStyle(color: Color(0xFFFF0000)),
          parent: parent,
          state: emptyState,
        );
        expect(
          identical(r.inheritedText, parent.inheritedText),
          isTrue,
          reason: '子写入与父同值时 withColor 短路，identical 关系保留',
        );
      });
    });
  });

  group('级联优先级', () {
    group('cascade 优先级 — base / inherited / selfVariant / groupVariant', () {
      test('base 覆盖 inherited（base 优先级更高）', () {
        const parent = ResolvedStyle(
          inheritedText: InheritedText(color: Color(0xFFFF0000)),
          inheritedBox: InheritedBox.initial,
          box: Box.initial,
        );
        final r = StyleResolver.resolve(
          style: const ElStyle(color: Color(0xFF00FF00)),
          parent: parent,
          state: 0,
        );
        expect(r.inheritedText.color, const Color(0xFF00FF00), reason: 'base 写明的 color 必须覆盖父继承');
      });

      test('selfVariant (hover) 覆盖 base', () {
        final state = (1 << ViewState.hover.index);
        final r = StyleResolver.resolve(
          style: const ElStyle(
            color: Color(0xFF000000),
            onHover: ElStyle(color: Color(0xFFFF0000)),
          ),
          parent: null,
          state: state,
        );
        expect(r.inheritedText.color, const Color(0xFFFF0000));
      });

      test('selfVariant 未激活时不生效', () {
        final r = StyleResolver.resolve(
          style: const ElStyle(
            color: Color(0xFF000000),
            onHover: ElStyle(color: Color(0xFFFF0000)),
          ),
          parent: null,
          state: 0,
        );
        expect(r.inheritedText.color, const Color(0xFF000000));
      });

      test('disabled 优先级最高（在 selfVariants 内排最后）', () {
        final state = ((1 << ViewState.hover.index) | (1 << ViewState.disabled.index));
        final r = StyleResolver.resolve(
          style: const ElStyle(
            color: Color(0xFF000000),
            onHover: ElStyle(color: Color(0xFFFF0000)),
            onDisabled: ElStyle(color: Color(0xFF888888)),
          ),
          parent: null,
          state: state,
        );
        expect(
          r.inheritedText.color,
          const Color(0xFF888888),
          reason: 'disabled.index > hover.index，cascade 内 disabled 压过 hover',
        );
      });

      test('多 selfVariant 同字段时按 ViewState 顺序，后者胜', () {
        final state = ((1 << ViewState.hover.index) | (1 << ViewState.focus.index));
        final r = StyleResolver.resolve(
          style: const ElStyle(
            color: Color(0xFF000000),
            onHover: ElStyle(color: Color(0xFFFF0000)),
            onFocus: ElStyle(color: Color(0xFF00FF00)),
          ),
          parent: null,
          state: state,
        );
        expect(r.inheritedText.color, const Color(0xFF00FF00), reason: 'focus.index > hover.index');
      });
    });
  });

  group('声明收集', () {
    ResolvedStyle parentWithColor(Color c) {
      final b = ResolvedStyleBuilder.empty();
      b.writeColor(c);
      return b.build();
    }

    ResolvedStyle applyAndBuild({ElStyle? style, ResolvedStyle? parent, int? state}) {
      return StyleResolver.resolve(style: style, parent: parent, state: state ?? 0);
    }

    group('五类 origin 末态语义', () {
      test('只有 base：style.color → 输出 base 值', () {
        const style = ElStyle(color: Color(0xFFFF0000));
        final resolved = applyAndBuild(style: style);
        expect(resolved.inheritedText.color, const Color(0xFFFF0000));
      });

      test('inherited：parent color → 子 identical 借引用', () {
        final parent = parentWithColor(const Color(0xFFFF0000));
        final resolved = applyAndBuild(parent: parent);
        // 语义：resolver 输出 fall-back 到 parent.color（identical 共享）。
        expect(resolved.inheritedText.color, const Color(0xFFFF0000));
        expect(
          identical(resolved.inheritedText, parent.inheritedText),
          isTrue,
          reason: 'self 未写入 inheritedText group → 保留 parent identity',
        );
      });

      test('父 + 自身都声明 color：base 覆盖 inherited', () {
        const style = ElStyle(color: Color(0xFF0000FF));
        final parent = parentWithColor(const Color(0xFFFF0000));
        final resolved = applyAndBuild(style: style, parent: parent);
        expect(resolved.inheritedText.color, const Color(0xFF0000FF));
      });

      test('selfVariant 仅 mask 命中时生效', () {
        const style = ElStyle(
          color: Color(0xFF0000FF),
          onHover: ElStyle(color: Color(0xFFFF0000)),
        );
        // hover 未激活 → base 值
        final off = applyAndBuild(style: style);
        expect(off.inheritedText.color, const Color(0xFF0000FF));

        // hover 激活 → variant 值
        final mask = (1 << ViewState.hover.index);
        final on = applyAndBuild(style: style, state: mask);
        expect(on.inheritedText.color, const Color(0xFFFF0000));
      });

      test('transition 采样只写 committed，target 始终保留声明值', () {
        const red = Color(0xFFFF0000), blue = Color(0xFF0000FF);
        final driver = StyleAnimationDriver(onTick: () {});
        addTearDown(driver.dispose);
        final result = CascadeTick.tick(
          style: const ElStyle(color: red, transitions: [ElTransition.all(Duration(milliseconds: 100), Curves.linear)]),
          parent: null,
          oldCommitted: applyAndBuild(style: const ElStyle(color: blue)),
          state: 0,
          driver: driver,
        );
        final animation = driver.animationOf(ElTransitionField.color)!..advance(const Duration(milliseconds: 50));
        final (sampled, changed) = CascadeTick.writeFieldsFromAnimation(
          oldCommitted: result.newCommitted,
          fieldValues: {ElTransitionField.color: animation.currentValue()},
        );
        expect(sampled.inheritedText.color, lerpColorPremul(blue, red, 0.5));
        expect(maskHas(changed, ElTransitionField.color.index), isTrue);
        expect(result.newTarget.inheritedText.color, red);
        expect(result.newCommitted.inheritedText.color, blue);
      });
    });

    group('四种 origin 优先级序（端到端）', () {
      test('inherited fall-back：所有 origin 都未声明 color → 走 parent identity', () {
        final parent = parentWithColor(const Color(0xFF040404));
        final resolved = StyleResolver.resolve(style: const ElStyle(), parent: parent, state: 0);
        expect(resolved.inheritedText.color, const Color(0xFF040404));
        expect(identical(resolved.inheritedText, parent.inheritedText), isTrue);
      });
    });

    group('null style 路径（cascade 根 / 空节点）', () {
      test('style=null + parent=null：输出 identical InheritedText.initial（零 alloc）', () {
        final resolved = applyAndBuild();
        // 无 parent 时 fromParent 用 InheritedText.initial；无 base 写入 → 保留 initial identity。
        expect(identical(resolved.inheritedText, InheritedText.initial), isTrue);
        expect(identical(resolved.inheritedBox, InheritedBox.initial), isTrue);
        expect(identical(resolved.box, Box.initial), isTrue);
      });
    });
  });

  group('显式继承字段', () {
    group('StyleResolver.explicitInheritedMask', () {
      test('null style → 空集', () {
        expect(StyleResolver.explicitInheritedMask(null).fields.toSet(), isEmpty);
      });

      test('只含 isInherited 字段（非继承字段被过滤）', () {
        // 设了一堆非继承 box 字段 + 一个继承字段
        const style = ElStyle(
          bgColor: Color(0xFF000000),
          width: 10,
          height: 10,
          padding: .all(4),
          decoration: TextDecoration.underline, // InheritedText 组但 isInherited:false
          softWrap: false, // 同上
          color: Color(0xFFFF0000), // 唯一继承字段
        );
        final result = StyleResolver.explicitInheritedMask(style).fields.toSet();
        expect(result, <ElTransitionField>{ElTransitionField.color});
        expect(result.difference(inheritedFields), isEmpty, reason: '派生结果必须是 inheritedFields 子集');
      });

      test('设置全部继承字段 → 派生 == inheritedFields（同步护栏）', () {
        final style = ElStyle(
          // --- InheritedText 继承字段（21）---
          color: const Color(0xFF010101),
          fontSize: 12,
          fontWeight: FontWeight.w600,
          fontStyle: FontStyle.italic,
          fontFamily: 'Roboto',
          fontFamilyFallback: const <String>['Arial'],
          lineHeight: 1.5,
          letterSpacing: 0.5,
          wordSpacing: 1,
          fontFeatures: <FontFeature>[const FontFeature.enable('smcp')],
          fontVariations: const <FontVariation>[FontVariation('wght', 700)],
          textAlign: TextAlign.center,
          textBaseline: TextBaseline.ideographic,
          leadingDistribution: TextLeadingDistribution.even,
          textShadow: const <Shadow>[Shadow(blurRadius: 1)],
          textGradient: const ElLinearGradient(angle: 90, colors: [Color(0xFF030303), Color(0xFF040404)]),
          decorationColor: const Color(0xFF020202),
          decorationStyle: TextDecorationStyle.dashed,
          decorationThickness: 2,
          // --- InheritedBox 继承字段（5）---
          textDirection: TextDirection.rtl,
          cursor: SystemMouseCursors.click,
          pointerEvents: ElPointerEvents.none,
          iconSize: 18,
          iconColor: const Color(0xFF050505),
        );
        final result = StyleResolver.explicitInheritedMask(style).fields.toSet();
        expect(
          result.length,
          inheritedFields.length,
          reason: '新增继承字段后须在此处可见：若 emitStyleFields 漏 emit 或 isInherited 标错，长度不符',
        );
        expect(result.containsAll(inheritedFields), isTrue);
      });

      test('回归：曾被手写清单漏掉的继承字段都被收进', () {
        final style = ElStyle(
          fontFamilyFallback: const <String>['A'],
          fontFeatures: <FontFeature>[const FontFeature.enable('smcp')],
          fontVariations: const <FontVariation>[FontVariation('wght', 700)],
          textBaseline: TextBaseline.ideographic,
          leadingDistribution: TextLeadingDistribution.even,
          decorationColor: const Color(0xFF112233),
          decorationStyle: TextDecorationStyle.dashed,
          decorationThickness: 2,
        );
        expect(
          StyleResolver.explicitInheritedMask(style).fields.toSet(),
          containsAll(<ElTransitionField>{
            ElTransitionField.fontFamilyFallback,
            ElTransitionField.fontFeatures,
            ElTransitionField.fontVariations,
            ElTransitionField.textBaseline,
            ElTransitionField.leadingDistribution,
            ElTransitionField.decorationColor,
            ElTransitionField.decorationStyle,
            ElTransitionField.decorationThickness,
          }),
        );
      });
    });
  });

  group('生成字段快路径', () {
    final samples = <ElTransitionField, ElStyle>{
      .color: const ElStyle(color: Colors.red),
      .fontSize: const ElStyle(fontSize: 20),
      .fontWeight: const ElStyle(fontWeight: .w700),
      .fontStyle: const ElStyle(fontStyle: .italic),
      .fontFamily: const ElStyle(fontFamily: 'sample'),
      .fontFamilyFallback: const ElStyle(fontFamilyFallback: ['fallback']),
      .lineHeight: const ElStyle(lineHeight: 1.8),
      .letterSpacing: const ElStyle(letterSpacing: 2),
      .wordSpacing: const ElStyle(wordSpacing: 3),
      .fontFeatures: const ElStyle(fontFeatures: [FontFeature.tabularFigures()]),
      .fontVariations: const ElStyle(fontVariations: [FontVariation('wght', 500)]),
      .textAlign: const ElStyle(textAlign: .right),
      .textBaseline: const ElStyle(textBaseline: .ideographic),
      .leadingDistribution: const ElStyle(leadingDistribution: .proportional),
      .textShadow: const ElStyle(textShadow: [Shadow(blurRadius: 2)]),
      .textGradient: const ElStyle(textGradient: LinearGradient(colors: [Colors.red, Colors.blue])),
      .decoration: const ElStyle(decoration: TextDecoration.underline),
      .decorationColor: const ElStyle(decorationColor: Colors.red),
      .decorationStyle: const ElStyle(decorationStyle: .dashed),
      .decorationThickness: const ElStyle(decorationThickness: 2),
      .textBackgroundColor: const ElStyle(textBackgroundColor: Colors.red),
      .softWrap: const ElStyle(softWrap: false),
      .overflow: const ElStyle(overflow: .ellipsis),
      .maxLines: const ElStyle(maxLines: 2),
      .textDirection: const ElStyle(textDirection: .rtl),
      .cursor: const ElStyle(cursor: SystemMouseCursors.click),
      .pointerEvents: const ElStyle(pointerEvents: .none),
      .iconSize: const ElStyle(iconSize: 32),
      .iconColor: const ElStyle(iconColor: Colors.blue),
      .width: const ElStyle(width: '80%'),
      .height: const ElStyle(height: 90),
      .widthFactor: const ElStyle(widthFactor: 0.5),
      .heightFactor: const ElStyle(heightFactor: 1.5),
      .bgColor: const ElStyle(bgColor: Colors.blue),
      .padding: const ElStyle(padding: EdgeInsets.all(10)),
      .margin: const ElStyle(margin: .all(3)),
      .alignment: const ElStyle(alignment: .center),
      .border: const ElStyle(border: .all(color: Colors.red)),
      .borderRadius: const ElStyle(borderRadius: BorderRadius.all(Radius.circular(10))),
      .clipper: ElStyle(clipper: _PathClipper()),
      .boxShadow: const ElStyle(boxShadow: [BoxShadow(blurRadius: 3)]),
      .minWidth: const ElStyle(minWidth: 25),
      .maxWidth: const ElStyle(maxWidth: '90%'),
      .minHeight: const ElStyle(minHeight: 26),
      .maxHeight: const ElStyle(maxHeight: '95%'),
      .opacity: const ElStyle(opacity: 0.4),
      .transform: ElStyle(transform: ElTransform.rotate(0.3)),
      .transformAlignment: const ElStyle(transformAlignment: .topLeft),
      .clipBehavior: const ElStyle(clipBehavior: .hardEdge),
      .gradient: const ElStyle(gradient: LinearGradient(colors: [Colors.red, Colors.blue])),
      .bgImage: const ElStyle(bgImage: DecorationImage(image: NetworkImage('https://example.invalid/sample.png'))),
      .outline: const ElStyle(outline: ElOutline(width: 2, color: Colors.red)),
      .aspectRatio: const ElStyle(aspectRatio: 1.5),
      .filter: const ElStyle(filter: ElFilter(blur: 2)),
      .backdropFilter: const ElStyle(backdropFilter: ElFilter(blur: 3)),
    };

    final state = 0;

    ResolvedStyle resolve(ElStyle style, ResolvedStyle? parent) =>
        StyleResolver.resolve(style: style, parent: parent, state: state);

    test('所有有 spec 的字段都有实际声明、清空与继承场景', () {
      expect(samples.keys.toSet(), fieldSpecs.keys.toSet());
    });

    for (final entry in samples.entries) {
      test('${entry.key.name} 写入与清空等价完整级联', () {
        for (final parent in <ResolvedStyle?>[null, resolve(entry.value, null)]) {
          for (final (oldStyle, newStyle) in [(const ElStyle(), entry.value), (entry.value, const ElStyle())]) {
            final result = CascadeFastPatch.tryPatch(
              oldStyle: oldStyle,
              newStyle: newStyle,
              oldTarget: resolve(oldStyle, parent),
              parent: parent,
              state: state,
              hasActiveAnimations: false,
            );
            expect(result, isNotNull);
            final expected = resolve(newStyle, parent);
            expect(result!.newTarget.inheritedText, expected.inheritedText);
            expect(result.newTarget.inheritedBox, expected.inheritedBox);
            expect(result.newTarget.box, expected.box);
            expect(result.changedMask.fields.toSet(), {entry.key});
          }
        }
      });
    }

    testWidgets('图标与背景一起更新时 glyph 同步刷新', (tester) async {
      Widget page(double size, Color color) => Directionality(
        textDirection: .ltr,
        child: ElView(
          style: ElStyle(iconSize: size, iconColor: color, bgColor: color),
          child: const IconData(0xe716, fontFamily: 'MaterialIcons'),
        ),
      );
      await tester.pumpWidget(page(18, Colors.red));
      await tester.pumpWidget(page(30, Colors.blue));
      final render = tester.renderObject<ElRenderView>(find.byType(ElView));
      final text = (render.textEngineForTest?.painterForTest.text) as TextSpan;
      expect(text.style!.fontSize, 30);
      expect(text.style!.color, Colors.blue);
    });

    testWidgets('父图标字段变化沿有自有继承声明的子节点正确回退', (tester) async {
      const childKey = ValueKey('glyph-child');
      Widget page(double size, Color color) => Directionality(
        textDirection: .ltr,
        child: ElView(
          style: ElStyle(iconSize: size, iconColor: color, bgColor: color),
          child: Column(
            children: const [
              ElView(
                key: childKey,
                style: ElStyle(cursor: SystemMouseCursors.click),
                child: IconData(0xe716, fontFamily: 'MaterialIcons'),
              ),
            ],
          ),
        ),
      );
      await tester.pumpWidget(page(18, Colors.red));
      await tester.pumpWidget(page(30, Colors.blue));
      final render = tester.renderObject<ElRenderView>(find.byKey(childKey));
      final text = (render.textEngineForTest?.painterForTest.text) as TextSpan;
      expect(text.style!.fontSize, 30);
      expect(text.style!.color, Colors.blue);
      expect(render.committedResolvedStyle.inheritedBox.cursor, SystemMouseCursors.click);
    });
  });

  group('样式增量更新', () {
    _inheritPatchTests();

    int noState() => 0;

    ResolvedStyle resolveSlow(ElStyle? style, {ResolvedStyle? parent, int? state}) {
      return StyleResolver.resolve(style: style, parent: parent, state: state ?? noState());
    }

    ElStyle boxStyle({
      Object? width,
      Object? height,
      Color? bgColor,
      EdgeInsetsGeometry? padding,
      BorderRadiusGeometry? borderRadius,
      List<BoxShadow>? boxShadow,
      double? opacity,
    }) => ElStyle(
      width: width ?? 100,
      height: height ?? 50,
      bgColor: bgColor,
      padding: padding,
      borderRadius: borderRadius,
      boxShadow: boxShadow,
      opacity: opacity,
    );

    test('连续更新返回独立的变更字段集合', () {
      const initial = ElStyle(width: 100, bgColor: Colors.red);
      const recolored = ElStyle(width: 100, bgColor: Colors.blue);
      const resized = ElStyle(width: 200, bgColor: Colors.blue);
      final first = CascadeFastPatch.tryPatch(
        oldStyle: initial,
        newStyle: recolored,
        oldTarget: resolveSlow(initial),
        parent: null,
        state: noState(),
        hasActiveAnimations: false,
      )!;
      final second = CascadeFastPatch.tryPatch(
        oldStyle: recolored,
        newStyle: resized,
        oldTarget: first.newTarget,
        parent: null,
        state: noState(),
        hasActiveAnimations: false,
      )!;

      expect(first.changedMask.fields.toSet(), {ElTransitionField.bgColor});
      expect(second.changedMask.fields.toSet(), {ElTransitionField.width});
      expect(identical(first.changedMask.fields.toSet(), second.changedMask.fields.toSet()), isFalse);
    });

    group('bail：variant / group / transition 引用差异', () {
      test('onHover ref 不同 → bail', () {
        final old = ElStyle(
          width: 100,
          bgColor: Colors.red,
          onHover: const ElStyle(bgColor: Color(0xFF111111)),
        );
        final newS = ElStyle(
          width: 100,
          bgColor: Colors.blue,
          onHover: const ElStyle(bgColor: Color(0xFF222222)),
        );
        final result = CascadeFastPatch.tryPatch(
          oldStyle: old,
          newStyle: newS,
          oldTarget: resolveSlow(old),
          parent: null,
          state: noState(),
          hasActiveAnimations: false,
        );
        expect(result, isNull);
      });

      test('onTap ref 不同 → bail', () {
        final old = ElStyle(
          bgColor: Colors.red,
          onTap: const ElStyle(bgColor: Color(0xFF111111)),
        );
        final newS = ElStyle(
          bgColor: Colors.blue,
          onTap: const ElStyle(bgColor: Color(0xFF222222)),
        );
        expect(
          CascadeFastPatch.tryPatch(
            oldStyle: old,
            newStyle: newS,
            oldTarget: resolveSlow(old),
            parent: null,
            state: noState(),
            hasActiveAnimations: false,
          ),
          isNull,
        );
      });

      test('其余 5 个 self variants ref 不同 → bail', () {
        const baseVariant = ElStyle(bgColor: Color(0xFF111111));
        const otherVariant = ElStyle(bgColor: Color(0xFF222222));

        ElStyle build({
          ElStyle? focus,
          ElStyle? focusWithin,
          ElStyle? disabled,
          ElStyle? focusVisible,
          ElStyle? dark,
        }) => ElStyle(
          width: 100,
          onFocus: focus,
          onFocusWithin: focusWithin,
          onDisabled: disabled,
          onFocusVisible: focusVisible,
          onDark: dark,
        );

        for (final variantKey in ['focus', 'focusWithin', 'disabled', 'focusVisible', 'dark']) {
          final oldArgs = <String, ElStyle?>{variantKey: baseVariant};
          final newArgs = <String, ElStyle?>{variantKey: otherVariant};

          ElStyle styleFromMap(Map<String, ElStyle?> m) => build(
            focus: m['focus'],
            focusWithin: m['focusWithin'],
            disabled: m['disabled'],
            focusVisible: m['focusVisible'],
            dark: m['dark'],
          );

          final old = styleFromMap(oldArgs);
          final newS = styleFromMap(newArgs);

          expect(
            CascadeFastPatch.tryPatch(
              oldStyle: old,
              newStyle: newS,
              oldTarget: resolveSlow(old),
              parent: null,
              state: noState(),
              hasActiveAnimations: false,
            ),
            isNull,
            reason: 'variant key=$variantKey ref 不同 → 必须 bail',
          );
        }
      });

      test('transitions ref 不同 → bail', () {
        final old = ElStyle(bgColor: Colors.red, transitions: const [ElTransition.all(Duration(milliseconds: 100))]);
        final newS = ElStyle(bgColor: Colors.blue, transitions: const [ElTransition.all(Duration(milliseconds: 200))]);
        expect(
          CascadeFastPatch.tryPatch(
            oldStyle: old,
            newStyle: newS,
            oldTarget: resolveSlow(old),
            parent: null,
            state: noState(),
            hasActiveAnimations: false,
          ),
          isNull,
        );
      });
    });

    group('bail：state 命中 active self variant', () {
      test('newStyle 有 onHover + state.hover=true → bail', () {
        const variant = ElStyle(bgColor: Color(0xFF111111));
        final old = ElStyle(bgColor: Colors.red, onHover: variant);
        final newS = ElStyle(bgColor: Colors.blue, onHover: variant);
        final mask = (1 << ViewState.hover.index);
        expect(
          CascadeFastPatch.tryPatch(
            oldStyle: old,
            newStyle: newS,
            oldTarget: resolveSlow(old, state: mask),
            parent: null,
            state: mask,
            hasActiveAnimations: false,
          ),
          isNull,
        );
      });

      test('newStyle 有 onTap + state.active=true → bail', () {
        const variant = ElStyle(bgColor: Color(0xFF111111));
        final old = ElStyle(bgColor: Colors.red, onTap: variant);
        final newS = ElStyle(bgColor: Colors.blue, onTap: variant);
        final mask = (1 << ViewState.tap.index);
        expect(
          CascadeFastPatch.tryPatch(
            oldStyle: old,
            newStyle: newS,
            oldTarget: resolveSlow(old, state: mask),
            parent: null,
            state: mask,
            hasActiveAnimations: false,
          ),
          isNull,
        );
      });

      test('newStyle 有 onHover 但 state.hover=false → 不 bail（其他条件都过的情况）', () {
        const variant = ElStyle(bgColor: Color(0xFF111111));
        final old = ElStyle(bgColor: Colors.red, onHover: variant);
        final newS = ElStyle(bgColor: Colors.blue, onHover: variant);
        final result = CascadeFastPatch.tryPatch(
          oldStyle: old,
          newStyle: newS,
          oldTarget: resolveSlow(old),
          parent: null,
          state: noState(),
          hasActiveAnimations: false,
        );
        expect(result, isNotNull);
        expect(result!.changedMask.fields.toSet(), {ElTransitionField.bgColor});
      });

      // =========================================================================
      // T-variant3 diff-后-裁决：激活变体不再一票 bail，只有 dirty ∩ 激活链
      // declaredMask 非空 / 激活链声明 transitions 才回 slow path。
      // =========================================================================

      test('T-variant3：hover 激活但变体只覆写 opacity、diff 是 bgColor → fast hit 且与 slow 等价', () {
        const variant = ElStyle(opacity: 0.5);
        final old = ElStyle(bgColor: Colors.red, onHover: variant);
        final newS = ElStyle(bgColor: Colors.blue, onHover: variant);
        final mask = (1 << ViewState.hover.index);
        final state = mask;
        final oldTarget = resolveSlow(old, state: state);
        final result = CascadeFastPatch.tryPatch(
          oldStyle: old,
          newStyle: newS,
          oldTarget: oldTarget,
          parent: null,
          state: state,
          hasActiveAnimations: false,
        );
        expect(result, isNotNull);
        expect(result!.changedMask.fields.toSet(), {ElTransitionField.bgColor});
        // 变体覆写的 opacity 原样保留（来自 oldTarget），bgColor 取 base 新值。
        final slow = resolveSlow(newS, state: state);
        expect(result.newTarget.box.opacity, slow.box.opacity);
        expect(result.newTarget.box.bgColor, slow.box.bgColor);
      });

      test('T-variant3：hover 激活且变体覆写 bgColor、diff 是 bgColor → bail（dirty 相交）', () {
        const variant = ElStyle(bgColor: Color(0xFF111111));
        final old = ElStyle(bgColor: Colors.red, onHover: variant);
        final newS = ElStyle(bgColor: Colors.blue, onHover: variant);
        final mask = (1 << ViewState.hover.index);
        expect(
          CascadeFastPatch.tryPatch(
            oldStyle: old,
            newStyle: newS,
            oldTarget: resolveSlow(old, state: mask),
            parent: null,
            state: mask,
            hasActiveAnimations: false,
          ),
          isNull,
        );
      });

      test('T-variant3：响应式 md 激活（累进位恒亮）但只覆写 padding、diff 是 bgColor → fast hit', () {
        // T-variant2 累进语义：宽屏下 xs..md 全亮。旧 Bail 2 下本场景永久 bail
        // ——一切声明响应式变体的样式失去 fast path，是本轮修复的核心场景。
        const variant = ElStyle(padding: EdgeInsets.all(24));
        final old = ElStyle(bgColor: Colors.red, md: variant);
        final newS = ElStyle(bgColor: Colors.blue, md: variant);
        final mask = (((1 << ViewState.xs.index) | (1 << ViewState.sm.index)) | (1 << ViewState.md.index));
        final state = mask;
        final oldTarget = resolveSlow(old, state: state);
        final result = CascadeFastPatch.tryPatch(
          oldStyle: old,
          newStyle: newS,
          oldTarget: oldTarget,
          parent: null,
          state: state,
          hasActiveAnimations: false,
        );
        expect(result, isNotNull);
        expect(result!.changedMask.fields.toSet(), {ElTransitionField.bgColor});
        final slow = resolveSlow(newS, state: state);
        expect(result.newTarget.box.padding, slow.box.padding);
        expect(result.newTarget.box.bgColor, slow.box.bgColor);
      });

      test('T-variant3：xs..xl 引用差异 → Bail 1 兜住（补进 identical 清单）', () {
        final old = ElStyle(
          bgColor: Colors.red,
          md: const ElStyle(padding: EdgeInsets.all(8)),
        );
        final newS = ElStyle(
          bgColor: Colors.blue,
          md: const ElStyle(padding: EdgeInsets.all(16)),
        );
        expect(
          CascadeFastPatch.tryPatch(
            oldStyle: old,
            newStyle: newS,
            oldTarget: resolveSlow(old),
            parent: null,
            state: noState(),
            hasActiveAnimations: false,
          ),
          isNull,
        );
      });

      test('T-variant3：dark 激活但 onDark 只覆写 color、diff 是 width → fast hit 且与 slow 等价', () {
        const variant = ElStyle(color: Color(0xFFEEEEEE));
        final old = ElStyle(width: 100, onDark: variant);
        final newS = ElStyle(width: 200, onDark: variant);
        final mask = (1 << ViewState.dark.index);
        final state = mask;
        final oldTarget = resolveSlow(old, state: state);
        final result = CascadeFastPatch.tryPatch(
          oldStyle: old,
          newStyle: newS,
          oldTarget: oldTarget,
          parent: null,
          state: state,
          hasActiveAnimations: false,
        );
        expect(result, isNotNull);
        expect(result!.changedMask.fields.toSet(), {ElTransitionField.width});
        final slow = resolveSlow(newS, state: state);
        expect(result.newTarget.inheritedText.color, slow.inheritedText.color);
        expect(result.newTarget.box.width, slow.box.width);
      });

      test('T-variant3：激活嵌套链 onHover(onTap) 覆写字段与 diff 相交 → bail', () {
        // 链 AND 语义：hover+active 双态齐活 → 嵌套 X(width) 激活。diff 是
        // width → 相交 bail。
        const nested = ElStyle(onTap: ElStyle(width: 300));
        final old = ElStyle(width: 100, onHover: nested);
        final newS = ElStyle(width: 200, onHover: nested);
        final mask = ((1 << ViewState.hover.index) | (1 << ViewState.tap.index));
        expect(
          CascadeFastPatch.tryPatch(
            oldStyle: old,
            newStyle: newS,
            oldTarget: resolveSlow(old, state: mask),
            parent: null,
            state: mask,
            hasActiveAnimations: false,
          ),
          isNull,
        );
      });

      test('T-variant3：激活变体声明 transitions → bail', () {
        const variant = ElStyle(opacity: 0.5, transitions: [ElTransition.all(Duration(milliseconds: 100))]);
        final old = ElStyle(bgColor: Colors.red, onHover: variant);
        final newS = ElStyle(bgColor: Colors.blue, onHover: variant);
        final mask = (1 << ViewState.hover.index);
        expect(
          CascadeFastPatch.tryPatch(
            oldStyle: old,
            newStyle: newS,
            oldTarget: resolveSlow(old, state: mask),
            parent: null,
            state: mask,
            hasActiveAnimations: false,
          ),
          isNull,
        );
      });

      test('T-variant3：未激活变体声明 transitions 不影响 fast hit', () {
        // onHover 声明 transitions 但 hover 未激活 → effective transitions
        // 仍取 base（null）→ fast path 安全。
        const variant = ElStyle(opacity: 0.5, transitions: [ElTransition.all(Duration(milliseconds: 100))]);
        final old = ElStyle(bgColor: Colors.red, onHover: variant);
        final newS = ElStyle(bgColor: Colors.blue, onHover: variant);
        final result = CascadeFastPatch.tryPatch(
          oldStyle: old,
          newStyle: newS,
          oldTarget: resolveSlow(old),
          parent: null,
          state: noState(),
          hasActiveAnimations: false,
        );
        expect(result, isNotNull);
        expect(result!.changedMask.fields.toSet(), {ElTransitionField.bgColor});
      });
    });

    group('bail：声明 transitions / hasActiveAnimations', () {
      test('newStyle 声明 transitions（非空）→ bail（即使 ref 一致）', () {
        const sharedT = [ElTransition.all(Duration(milliseconds: 100))];
        final old = ElStyle(bgColor: Colors.red, transitions: sharedT);
        final newS = ElStyle(bgColor: Colors.blue, transitions: sharedT);
        expect(
          CascadeFastPatch.tryPatch(
            oldStyle: old,
            newStyle: newS,
            oldTarget: resolveSlow(old),
            parent: null,
            state: noState(),
            hasActiveAnimations: false,
          ),
          isNull,
        );
      });

      test('hasActiveAnimations=true → bail', () {
        final old = ElStyle(bgColor: Colors.red);
        final newS = ElStyle(bgColor: Colors.blue);
        expect(
          CascadeFastPatch.tryPatch(
            oldStyle: old,
            newStyle: newS,
            oldTarget: resolveSlow(old),
            parent: null,
            state: noState(),
            hasActiveAnimations: true,
          ),
          isNull,
        );
      });
    });

    group('fast hit：inherited 字段 patch（含 parent fallback）', () {
      test('color 差异：patch + dirty 含 color', () {
        final old = ElStyle(width: 100, color: const Color(0xFF000000));
        final newS = ElStyle(width: 100, color: const Color(0xFFFF0000));
        final fast = CascadeFastPatch.tryPatch(
          oldStyle: old,
          newStyle: newS,
          oldTarget: resolveSlow(old),
          parent: null,
          state: noState(),
          hasActiveAnimations: false,
        );
        expect(fast, isNotNull);
        expect(fast!.changedMask.fields.toSet(), {ElTransitionField.color});
        expect(fast.newTarget.inheritedText.color, const Color(0xFFFF0000));
        // 与 slow path 等价
        final slow = resolveSlow(newS);
        expect(fast.newTarget.inheritedText.color, slow.inheritedText.color);
      });

      test('fontSize 差异：patch + dirty 含 fontSize', () {
        final old = ElStyle(width: 100, fontSize: 14);
        final newS = ElStyle(width: 100, fontSize: 18);
        final fast = CascadeFastPatch.tryPatch(
          oldStyle: old,
          newStyle: newS,
          oldTarget: resolveSlow(old),
          parent: null,
          state: noState(),
          hasActiveAnimations: false,
        );
        expect(fast, isNotNull);
        expect(fast!.changedMask.fields.toSet(), {ElTransitionField.fontSize});
        expect(fast.newTarget.inheritedText.fontSize, 18);
      });

      test('color 切到 null + 有 parent：fall back parent.color', () {
        final parent = ResolvedStyleBuilder.empty();
        parent.writeColor(const Color(0xFF111111));
        final parentResolved = parent.build();

        final old = ElStyle(width: 100, color: const Color(0xFF000000));
        final newS = ElStyle(width: 100); // color 切到 null
        final fast = CascadeFastPatch.tryPatch(
          oldStyle: old,
          newStyle: newS,
          oldTarget: resolveSlow(old, parent: parentResolved),
          parent: parentResolved,
          state: noState(),
          hasActiveAnimations: false,
        );
        expect(fast, isNotNull);
        expect(fast!.changedMask.fields.toSet(), {ElTransitionField.color});
        // 应 fall back 到 parent
        expect(fast.newTarget.inheritedText.color, const Color(0xFF111111));
      });

      test('非继承 text 字段切到 null + 有 parent：不 fall back parent', () {
        final parent = ResolvedStyleBuilder.empty();
        parent.writeDecoration(TextDecoration.underline);
        parent.writeTextBackgroundColor(const Color(0xFFFFFF00));
        parent.writeSoftWrap(false);
        parent.writeOverflow(TextOverflow.ellipsis);
        parent.writeMaxLines(1);
        final parentResolved = parent.build();

        const old = ElStyle(
          width: 100,
          decoration: TextDecoration.overline,
          textBackgroundColor: Color(0xFF00FF00),
          softWrap: true,
          overflow: TextOverflow.clip,
          maxLines: 3,
        );
        const newS = ElStyle(width: 100);
        final fast = CascadeFastPatch.tryPatch(
          oldStyle: old,
          newStyle: newS,
          oldTarget: resolveSlow(old, parent: parentResolved),
          parent: parentResolved,
          state: noState(),
          hasActiveAnimations: false,
        );

        expect(fast, isNotNull);
        expect(fast!.changedMask.fields.toSet(), {
          ElTransitionField.decoration,
          ElTransitionField.textBackgroundColor,
          ElTransitionField.softWrap,
          ElTransitionField.overflow,
          ElTransitionField.maxLines,
        });
        expect(fast.newTarget.inheritedText.decoration, isNull);
        expect(fast.newTarget.inheritedText.textBackgroundColor, isNull);
        expect(fast.newTarget.inheritedText.softWrap, isNull);
        expect(fast.newTarget.inheritedText.overflow, isNull);
        expect(fast.newTarget.inheritedText.maxLines, isNull);

        final slow = resolveSlow(newS, parent: parentResolved);
        expect(fast.newTarget.inheritedText, slow.inheritedText);
      });

      test('textDirection 差异：patch + dirty 含 textDirection', () {
        final old = ElStyle(width: 100, textDirection: TextDirection.ltr);
        final newS = ElStyle(width: 100, textDirection: TextDirection.rtl);
        final fast = CascadeFastPatch.tryPatch(
          oldStyle: old,
          newStyle: newS,
          oldTarget: resolveSlow(old),
          parent: null,
          state: noState(),
          hasActiveAnimations: false,
        );
        expect(fast, isNotNull);
        expect(fast!.changedMask.fields.toSet(), {ElTransitionField.textDirection});
        expect(fast.newTarget.inheritedBox.textDirection, TextDirection.rtl);
      });

      test('cursor 差异：patch + dirty 含 cursor', () {
        final old = ElStyle(width: 100, cursor: SystemMouseCursors.basic);
        final newS = ElStyle(width: 100, cursor: SystemMouseCursors.click);
        final fast = CascadeFastPatch.tryPatch(
          oldStyle: old,
          newStyle: newS,
          oldTarget: resolveSlow(old),
          parent: null,
          state: noState(),
          hasActiveAnimations: false,
        );
        expect(fast, isNotNull);
        expect(fast!.changedMask.fields.toSet(), {ElTransitionField.cursor});
        expect(fast.newTarget.inheritedBox.cursor, SystemMouseCursors.click);
      });

      test('根节点（parent=null）移除继承声明：fall back InheritedText.initial 且与 slow 等价', () {
        // 回归：旧实现 parent==null 时 fallback 恒写 null，而 slow path
        // `fromParent(null)` 回 `InheritedText.initial`——根节点 rebuild 移除
        // color/fontSize/lineHeight/leadingDistribution 声明时 fast/slow 分歧。
        final old = ElStyle(
          width: 100,
          color: const Color(0xFF123456),
          fontSize: 20,
          lineHeight: 2.0,
          leadingDistribution: TextLeadingDistribution.proportional,
        );
        final newS = ElStyle(width: 100); // 四个继承声明全部移除
        final fast = CascadeFastPatch.tryPatch(
          oldStyle: old,
          newStyle: newS,
          oldTarget: resolveSlow(old),
          parent: null,
          state: noState(),
          hasActiveAnimations: false,
        );
        expect(fast, isNotNull);
        expect(fast!.changedMask.fields.toSet(), {
          ElTransitionField.color,
          ElTransitionField.fontSize,
          ElTransitionField.lineHeight,
          ElTransitionField.leadingDistribution,
        });
        final slow = resolveSlow(newS);
        expect(fast.newTarget.inheritedText.color, slow.inheritedText.color);
        expect(fast.newTarget.inheritedText.fontSize, slow.inheritedText.fontSize);
        expect(fast.newTarget.inheritedText.lineHeight, slow.inheritedText.lineHeight);
        expect(fast.newTarget.inheritedText.leadingDistribution, slow.inheritedText.leadingDistribution);
        // 落到组初值而非 null。
        expect(fast.newTarget.inheritedText.color, InheritedText.initial.color);
        expect(fast.newTarget.inheritedText.fontSize, InheritedText.initial.fontSize);
        expect(fast.newTarget.inheritedText.lineHeight, InheritedText.initial.lineHeight);
        expect(fast.newTarget.inheritedText.leadingDistribution, InheritedText.initial.leadingDistribution);
      });

      test('根节点（parent=null）移除初值为 null 的继承声明：仍写 null 与 slow 等价', () {
        final old = ElStyle(width: 100, fontWeight: FontWeight.w700, letterSpacing: 1.2);
        final newS = ElStyle(width: 100);
        final fast = CascadeFastPatch.tryPatch(
          oldStyle: old,
          newStyle: newS,
          oldTarget: resolveSlow(old),
          parent: null,
          state: noState(),
          hasActiveAnimations: false,
        );
        expect(fast, isNotNull);
        final slow = resolveSlow(newS);
        expect(fast!.newTarget.inheritedText.fontWeight, slow.inheritedText.fontWeight);
        expect(fast.newTarget.inheritedText.letterSpacing, slow.inheritedText.letterSpacing);
        expect(fast.newTarget.inheritedText.fontWeight, isNull);
        expect(fast.newTarget.inheritedText.letterSpacing, isNull);
      });

      test('lineHeight 切到非法值后 adjuster clamp 仍生效', () {
        final old = ElStyle(width: 100, lineHeight: 1.5);
        final newS = ElStyle(width: 100, lineHeight: -1); // 非法 → clamp 到 null
        final fast = CascadeFastPatch.tryPatch(
          oldStyle: old,
          newStyle: newS,
          oldTarget: resolveSlow(old),
          parent: null,
          state: noState(),
          hasActiveAnimations: false,
        );
        expect(fast, isNotNull);
        // adjuster 把负值 clamp 到 null
        expect(fast!.newTarget.inheritedText.lineHeight, isNull);
      });
    });

    group('bail：null style', () {
      test('oldStyle = null → bail', () {
        expect(
          CascadeFastPatch.tryPatch(
            oldStyle: null,
            newStyle: ElStyle(bgColor: Colors.red),
            oldTarget: resolveSlow(null),
            parent: null,
            state: noState(),
            hasActiveAnimations: false,
          ),
          isNull,
        );
      });

      test('newStyle = null → bail', () {
        final old = ElStyle(bgColor: Colors.red);
        expect(
          CascadeFastPatch.tryPatch(
            oldStyle: old,
            newStyle: null,
            oldTarget: resolveSlow(old),
            parent: null,
            state: noState(),
            hasActiveAnimations: false,
          ),
          isNull,
        );
      });
    });

    group('fast hit：单字段 patch + 与 slow path 等价', () {
      test('bgColor 单字段变化', () {
        final old = boxStyle(bgColor: Colors.green);
        final newS = boxStyle(bgColor: Colors.blue);
        final oldT = resolveSlow(old);
        final fast = CascadeFastPatch.tryPatch(
          oldStyle: old,
          newStyle: newS,
          oldTarget: oldT,
          parent: null,
          state: noState(),
          hasActiveAnimations: false,
        );
        expect(fast, isNotNull);
        expect(fast!.changedMask.fields.toSet(), {ElTransitionField.bgColor});

        final slow = resolveSlow(newS);
        expect(fast.newTarget.box.bgColor, slow.box.bgColor);
        expect(fast.newTarget.box.width, slow.box.width);
        expect(fast.newCommitted, same(fast.newTarget));
      });

      test('width 单字段变化', () {
        final old = boxStyle(width: 100);
        final newS = boxStyle(width: 200);
        final fast = CascadeFastPatch.tryPatch(
          oldStyle: old,
          newStyle: newS,
          oldTarget: resolveSlow(old),
          parent: null,
          state: noState(),
          hasActiveAnimations: false,
        );
        expect(fast, isNotNull);
        expect(fast!.changedMask.fields.toSet(), {ElTransitionField.width});
        final slow = resolveSlow(newS);
        expect(fast.newTarget.box.width, slow.box.width);
      });

      test('height 单字段变化', () {
        final old = boxStyle(height: 50);
        final newS = boxStyle(height: 80);
        final fast = CascadeFastPatch.tryPatch(
          oldStyle: old,
          newStyle: newS,
          oldTarget: resolveSlow(old),
          parent: null,
          state: noState(),
          hasActiveAnimations: false,
        );
        expect(fast, isNotNull);
        expect(fast!.changedMask.fields.toSet(), {ElTransitionField.height});
      });

      test('opacity 单字段变化', () {
        final old = boxStyle(opacity: 1.0);
        final newS = boxStyle(opacity: 0.5);
        final fast = CascadeFastPatch.tryPatch(
          oldStyle: old,
          newStyle: newS,
          oldTarget: resolveSlow(old),
          parent: null,
          state: noState(),
          hasActiveAnimations: false,
        );
        expect(fast, isNotNull);
        expect(fast!.changedMask.fields.toSet(), {ElTransitionField.opacity});
        expect(fast.newTarget.box.opacity, 0.5);
      });

      test('borderRadius 单字段变化', () {
        final old = boxStyle(borderRadius: .zero);
        final newS = boxStyle(borderRadius: const BorderRadius.all(Radius.elliptical(8, 8)));
        final fast = CascadeFastPatch.tryPatch(
          oldStyle: old,
          newStyle: newS,
          oldTarget: resolveSlow(old),
          parent: null,
          state: noState(),
          hasActiveAnimations: false,
        );
        expect(fast, isNotNull);
        expect(fast!.changedMask.fields.toSet(), {ElTransitionField.borderRadius});
      });

      test('boxShadow 单字段变化', () {
        final old = boxStyle();
        final newS = boxStyle(boxShadow: const [BoxShadow(blurRadius: 4, color: Color(0x33000000))]);
        final fast = CascadeFastPatch.tryPatch(
          oldStyle: old,
          newStyle: newS,
          oldTarget: resolveSlow(old),
          parent: null,
          state: noState(),
          hasActiveAnimations: false,
        );
        expect(fast, isNotNull);
        expect(fast!.changedMask.fields.toSet(), {ElTransitionField.boxShadow});
        expect(fast.newTarget.box.boxShadow, isNotEmpty);
      });

      test('padding 单字段变化', () {
        final old = boxStyle();
        final newS = boxStyle(padding: const .all(8));
        final fast = CascadeFastPatch.tryPatch(
          oldStyle: old,
          newStyle: newS,
          oldTarget: resolveSlow(old),
          parent: null,
          state: noState(),
          hasActiveAnimations: false,
        );
        expect(fast, isNotNull);
        expect(fast!.changedMask.fields.toSet(), {ElTransitionField.padding});
      });

      test('多字段同时变化（bgColor + width + opacity）', () {
        final old = boxStyle(bgColor: Colors.green, width: 100, opacity: 1.0);
        final newS = boxStyle(bgColor: Colors.blue, width: 200, opacity: 0.5);
        final fast = CascadeFastPatch.tryPatch(
          oldStyle: old,
          newStyle: newS,
          oldTarget: resolveSlow(old),
          parent: null,
          state: noState(),
          hasActiveAnimations: false,
        );
        expect(fast, isNotNull);
        expect(fast!.changedMask.fields.toSet(), {
          ElTransitionField.bgColor,
          ElTransitionField.width,
          ElTransitionField.opacity,
        });
        final slow = resolveSlow(newS);
        expect(fast.newTarget.box.bgColor, slow.box.bgColor);
        expect(fast.newTarget.box.width, slow.box.width);
        expect(fast.newTarget.box.opacity, slow.box.opacity);
      });

      test('changedFields 不含未变字段（只含真实差异）', () {
        final old = boxStyle(bgColor: Colors.green, width: 100);
        final newS = boxStyle(bgColor: Colors.blue, width: 100); // width 未变
        final fast = CascadeFastPatch.tryPatch(
          oldStyle: old,
          newStyle: newS,
          oldTarget: resolveSlow(old),
          parent: null,
          state: noState(),
          hasActiveAnimations: false,
        );
        expect(fast, isNotNull);
        expect(fast!.changedMask.fields.toSet(), {ElTransitionField.bgColor});
        expect(fast.changedMask.fields.toSet(), isNot(contains(ElTransitionField.width)));
      });

      test('aspectRatio 单字段变化', () {
        final old = ElStyle(width: 100, aspectRatio: 1);
        final newS = ElStyle(width: 100, aspectRatio: 2);
        final fast = CascadeFastPatch.tryPatch(
          oldStyle: old,
          newStyle: newS,
          oldTarget: resolveSlow(old),
          parent: null,
          state: noState(),
          hasActiveAnimations: false,
        );
        expect(fast, isNotNull);
        expect(fast!.changedMask.fields.toSet(), contains(ElTransitionField.aspectRatio));
      });

      test('widthFactor / heightFactor 字段变化', () {
        final old = ElStyle(widthFactor: 0.5, heightFactor: 0.25);
        final newS = ElStyle(widthFactor: 1, heightFactor: 0.75);
        final fast = CascadeFastPatch.tryPatch(
          oldStyle: old,
          newStyle: newS,
          oldTarget: resolveSlow(old),
          parent: null,
          state: noState(),
          hasActiveAnimations: false,
        );
        expect(fast, isNotNull);
        expect(fast!.changedMask.fields.toSet(), {ElTransitionField.widthFactor, ElTransitionField.heightFactor});
        expect(fast.newTarget.box.widthFactor, 1.0);
        expect(fast.newTarget.box.heightFactor, 0.75);
      });

      test('backdropFilter 单字段变化', () {
        final old = ElStyle(width: 100);
        final newS = ElStyle(width: 100, backdropFilter: ElFilter(blur: 4));
        final fast = CascadeFastPatch.tryPatch(
          oldStyle: old,
          newStyle: newS,
          oldTarget: resolveSlow(old),
          parent: null,
          state: noState(),
          hasActiveAnimations: false,
        );
        expect(fast, isNotNull);
        expect(fast!.changedMask.fields.toSet(), {ElTransitionField.backdropFilter});
      });
    });

    group('与 slow path 输出端到端等价', () {
      test('fast.newTarget.box 与 slow.box 字段全等（多种 patch 组合）', () {
        final old = ElStyle(width: 100, height: 50, bgColor: Colors.green, padding: const .all(8), opacity: 1.0);
        final newS = ElStyle(width: 200, height: 80, bgColor: Colors.blue, padding: const .all(16), opacity: 0.5);

        final oldT = resolveSlow(old);
        final fast = CascadeFastPatch.tryPatch(
          oldStyle: old,
          newStyle: newS,
          oldTarget: oldT,
          parent: null,
          state: noState(),
          hasActiveAnimations: false,
        );
        expect(fast, isNotNull);

        final slow = resolveSlow(newS);
        // box group 字段全等
        expect(fast!.newTarget.box.width, slow.box.width);
        expect(fast.newTarget.box.height, slow.box.height);
        expect(fast.newTarget.box.bgColor, slow.box.bgColor);
        expect(fast.newTarget.box.padding, slow.box.padding);
        expect(fast.newTarget.box.opacity, slow.box.opacity);
      });

      test('fast path 保留 inheritedText / inheritedBox identity（不写 inherited 字段）', () {
        final old = boxStyle(bgColor: Colors.green);
        final newS = boxStyle(bgColor: Colors.blue);
        final oldT = resolveSlow(old);

        final fast = CascadeFastPatch.tryPatch(
          oldStyle: old,
          newStyle: newS,
          oldTarget: oldT,
          parent: null,
          state: noState(),
          hasActiveAnimations: false,
        );
        expect(fast, isNotNull);
        // fast patch 只动 box group → inheritedText/Box 与 oldTarget 同 identity
        expect(identical(fast!.newTarget.inheritedText, oldT.inheritedText), isTrue);
        expect(identical(fast.newTarget.inheritedBox, oldT.inheritedBox), isTrue);
        // box 不应该 identity 共享（值变了）
        expect(identical(fast.newTarget.box, oldT.box), isFalse);
      });

      test('parent 非空 + child 仅 box 字段变化：fast path 与 slow path 等价', () {
        final parent = ResolvedStyleBuilder.empty();
        parent.writeColor(const Color(0xFFFF0000));
        final parentResolved = parent.build();

        final old = boxStyle(bgColor: Colors.green);
        final newS = boxStyle(bgColor: Colors.blue);
        final oldT = resolveSlow(old, parent: parentResolved);

        final fast = CascadeFastPatch.tryPatch(
          oldStyle: old,
          newStyle: newS,
          oldTarget: oldT,
          parent: parentResolved,
          state: noState(),
          hasActiveAnimations: false,
        );
        expect(fast, isNotNull);

        final slow = resolveSlow(newS, parent: parentResolved);
        // 继承字段保留 parent.color
        expect(fast!.newTarget.inheritedText.color, const Color(0xFFFF0000));
        expect(fast.newTarget.inheritedText.color, slow.inheritedText.color);
        // box 字段 = newStyle 字段
        expect(fast.newTarget.box.bgColor, Colors.blue);
        expect(fast.newTarget.box.bgColor, slow.box.bgColor);
      });

      test('newCommitted 与 newTarget 同 identity（无 active animation 路径）', () {
        final old = boxStyle(bgColor: Colors.green);
        final newS = boxStyle(bgColor: Colors.blue);
        final fast = CascadeFastPatch.tryPatch(
          oldStyle: old,
          newStyle: newS,
          oldTarget: resolveSlow(old),
          parent: null,
          state: noState(),
          hasActiveAnimations: false,
        );
        expect(fast, isNotNull);
        expect(identical(fast!.newCommitted, fast.newTarget), isTrue);
      });
    });

    group('集成：ElView widget 走 fast path 不破坏 cascade 末态', () {
      testWidgets('Flex60 bgColor 翻转：所有子 resolved.bgColor 正确', (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        Widget build({required bool active}) => MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ElView(
                style: const ElStyle(width: 360),
                child: ElView(
                  style: ElStyle(),
                  child: List<Widget>.generate(60, (i) {
                    return ElView(
                      style: ElStyle(width: 360, height: 18, bgColor: (i.isEven == active) ? Colors.red : Colors.green),
                    );
                  }, growable: false),
                ),
              ),
            ),
          ),
        );

        await tester.pumpWidget(build(active: false));
        // 验证初始：even=green, odd=red
        final initial = tester.renderObjectList<RenderBox>(find.byType(ElView)).toList();
        // find.byType(ElView) DFS pre-order 抓到 62 个 ElView：
        //   [0] = root container(width 360, 无 bgColor)
        //   [1] = 内层 flex column 容器 (无 bgColor)
        //   [2..61] = 60 个叶子 ElView（唯一带 bgColor 的层）
        // 跳前 2 个容器；老实现只跳 index 0 会把 flex 容器当叶子读，
        // resolved.box.bgColor = null → 崩在 `as Color` 上。
        for (var i = 0; i < 60; i++) {
          final view = initial[i + 2];
          final color = (view as dynamic).committedResolvedStyle.box.bgColor as Color;
          expect(color, i.isEven ? Colors.green : Colors.red, reason: 'i=$i initial active=false');
        }

        // 翻转
        await tester.pumpWidget(build(active: true));
        final after = tester.renderObjectList<RenderBox>(find.byType(ElView)).toList();
        for (var i = 0; i < 60; i++) {
          final view = after[i + 2];
          final color = (view as dynamic).committedResolvedStyle.box.bgColor as Color;
          expect(color, i.isEven ? Colors.red : Colors.green, reason: 'i=$i flipped active=true');
        }
      });

      testWidgets('hover 命中的节点不走 fast path：active state 切换正确', (tester) async {
        // 验证：onHover + state.hover=true 时 cascade 走 slow path，仍正确解算变体
        late ElRenderBox hoverableRender;

        Widget build({required Color baseColor}) => MaterialApp(
          home: Scaffold(
            body: Center(
              child: ElView(
                style: ElStyle(
                  width: 100,
                  height: 100,
                  bgColor: baseColor,
                  onHover: const ElStyle(bgColor: Color(0xFF111111)),
                ),
              ),
            ),
          ),
        );

        await tester.pumpWidget(build(baseColor: Colors.red));
        final view = tester.renderObject<RenderBox>(find.byType(ElView));
        hoverableRender = view as ElRenderBox;
        // 触发 hover state
        hoverableRender.setHover(true);
        await tester.pump();
        // 此时 resolved.bgColor 应该来自 onHover（0xFF111111）
        expect(
          (hoverableRender as dynamic).committedResolvedStyle.box.bgColor,
          const Color(0xFF111111),
          reason: 'hover 命中 → variant 值',
        );

        // 改变 baseColor，但 hover 仍命中：fast patch 应 bail，slow path 算出 variant 值不变
        await tester.pumpWidget(build(baseColor: Colors.blue));
        expect(
          (hoverableRender as dynamic).committedResolvedStyle.box.bgColor,
          const Color(0xFF111111),
          reason: 'hover 仍命中 → variant 值（不被 base 变化覆盖）',
        );

        // 退出 hover：基色应回到 newStyle.bgColor = blue
        hoverableRender.setHover(false);
        await tester.pump();
        expect((hoverableRender as dynamic).committedResolvedStyle.box.bgColor, Colors.blue);
      });
    });
  });

  group('继承借用', () {
    Widget shell(Widget child) => MaterialApp(home: Scaffold(body: child));

    List<ElRenderView> allRenderViews(WidgetTester tester) =>
        tester.renderObjectList<ElRenderView>(find.byType(ElView)).toList();

    ElRenderView viewOf(WidgetTester tester, Key key) => tester.renderObject<ElRenderView>(find.byKey(key));

    group('T22 深链共享恢复', () {
      testWidgets('root color 翻转 → 4 层无声明子的 inheritedText 与 root identical，叶子色更新', (tester) async {
        const rootKey = ValueKey('root');
        const l1Key = ValueKey('l1');
        const l2Key = ValueKey('l2');
        const l3Key = ValueKey('l3');
        const l4Key = ValueKey('l4');
        const leafKey = ValueKey('leaf');

        Widget build(Color color) => shell(
          ElView(
            key: rootKey,
            style: .new(width: 240, height: 60, color: color, fontSize: 14),
            child: ElView(
              key: l1Key,
              child: ElView(
                key: l2Key,
                child: ElView(
                  key: l3Key,
                  child: ElView(
                    key: l4Key,
                    child: ElView(key: leafKey, child: 'leaf 文本'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pumpWidget(build(const Color(0xff000000)));
        await tester.pump();

        // 初始 attach 已让子从父借用同一份 inheritedText（root 无非继承字段
        // → fromInheritedParent 直接返回 parent 实例）。
        final root0 = viewOf(tester, rootKey).committedResolvedStyle.inheritedText;
        expect(
          identical(viewOf(tester, l1Key).committedResolvedStyle.inheritedText, root0),
          isTrue,
          reason: 'attach 阶段 l1 应借用 root 的 inheritedText',
        );
        expect(
          identical(viewOf(tester, leafKey).committedResolvedStyle.inheritedText, root0),
          isTrue,
          reason: 'attach 阶段 leaf 也应借用同一实例（identical 链保持到叶）',
        );

        BenchmarkProbe.reset();

        // 翻转 root color → propagator 向下推 {color}。
        await tester.pumpWidget(build(const Color(0xffff0000)));
        await tester.pump();

        final root1 = viewOf(tester, rootKey).committedResolvedStyle.inheritedText;
        expect(root1.color, const Color(0xffff0000));

        // 5 层无声明子（l1..l4 + leaf）应全部借用 root1 的新 inheritedText。
        for (final k in const [l1Key, l2Key, l3Key, l4Key, leafKey]) {
          final childText = viewOf(tester, k).committedResolvedStyle.inheritedText;
          expect(identical(childText, root1), isTrue, reason: '$k 应借用 root 新 inheritedText（借用恢复）');
        }

        expect(
          BenchmarkProbe.inheritBorrowHitCount,
          greaterThanOrEqualTo(5),
          reason: '5 层 propagator visit 至少 5 次借用命中',
        );
      });
    });

    group('T22 声明干扰的正确性', () {
      testWidgets('中间子声明 fontSize（不等父）→ 不走借用；fontSize 保持自有值、color 更新', (tester) async {
        const rootKey = ValueKey('root');
        const midKey = ValueKey('mid');
        const leafKey = ValueKey('leaf');

        Widget build(Color color) => shell(
          ElView(
            key: rootKey,
            style: .new(width: 240, height: 40, color: color, fontSize: 16),
            child: ElView(
              key: midKey,
              style: .new(fontSize: 22),
              child: ElView(key: leafKey, child: 'leaf'),
            ),
          ),
        );

        await tester.pumpWidget(build(const Color(0xff000000)));
        await tester.pump();

        BenchmarkProbe.reset();

        await tester.pumpWidget(build(const Color(0xffff0000)));
        await tester.pump();

        final mid = viewOf(tester, midKey);
        final midText = mid.committedResolvedStyle.inheritedText;
        expect(midText.color, const Color(0xffff0000), reason: 'mid 未声明 color → 拿新父 color');
        expect(midText.fontSize, 22, reason: 'mid 自有 fontSize=22 必须保留');

        final rootText = viewOf(tester, rootKey).committedResolvedStyle.inheritedText;
        expect(identical(midText, rootText), isFalse, reason: 'mid 声明 fontSize（不等父）→ 组 identity 断开、不能借用');

        // leaf 未声明任何继承字段 + mid 值形成新组 → leaf 应借用 mid 的新组
        final leafText = viewOf(tester, leafKey).committedResolvedStyle.inheritedText;
        expect(identical(leafText, midText), isTrue, reason: 'leaf 借用 mid → identical mid 新组（借用恢复沿 mid 继续）');
      });
    });

    group('T22 等值声明防泄漏（关键回归锁）', () {
      testWidgets('子声明 fontSize 恰好等于父当前值；root 同时改 color 和 fontSize → 子 color 更新、fontSize 保持子自有声明值', (tester) async {
        const rootKey = ValueKey('root');
        const childKey = ValueKey('child');

        Widget build(Color color, double fontSize) => shell(
          ElView(
            key: rootKey,
            style: .new(width: 240, height: 30, color: color, fontSize: fontSize),
            child: ElView(
              key: childKey,
              // child 显式声明 fontSize=16，恰好等于父的当前值。
              style: .new(fontSize: 16),
              child: 'value',
            ),
          ),
        );

        await tester.pumpWidget(build(const Color(0xff000000), 16));
        await tester.pump();

        final child = viewOf(tester, childKey);
        final childText0 = child.committedResolvedStyle.inheritedText;
        final rootText0 = viewOf(tester, rootKey).committedResolvedStyle.inheritedText;

        // buffer flush 等值短路：identity 借用可能保住。
        expect(identical(childText0, rootText0), isTrue, reason: '子写 fontSize=16 与父等值 → flush 等值短路，identical 借用保留');

        BenchmarkProbe.reset();

        // 同时改 color 和 fontSize —— propagator 从 changedFields 剔除子的 fontSize 后
        // 只传 {color}。旧实现的借用泄漏路径会让子的 fontSize 跟着变成 24。
        await tester.pumpWidget(build(const Color(0xffff0000), 24));
        await tester.pump();

        final childText1 = child.committedResolvedStyle.inheritedText;
        expect(childText1.color, const Color(0xffff0000), reason: '子 color 更新为父新值');
        expect(childText1.fontSize, 16, reason: '关键回归：子自有声明 fontSize=16 必须保留，不能借用泄漏父的 24');
      });
    });

    group('T22 父带非继承字段不泄漏', () {
      testWidgets('父声明 decoration: underline + color 翻转 → 无声明子的 decoration 保持 null（重置语义）', (tester) async {
        const rootKey = ValueKey('root');
        const childKey = ValueKey('child');

        Widget build(Color color) => shell(
          ElView(
            key: rootKey,
            style: .new(width: 240, height: 30, color: color, fontSize: 14, decoration: TextDecoration.underline),
            child: ElView(key: childKey, child: 'text'),
          ),
        );

        await tester.pumpWidget(build(const Color(0xff000000)));
        await tester.pump();

        final child = viewOf(tester, childKey);
        final childText0 = child.committedResolvedStyle.inheritedText;
        expect(childText0.decoration, isNull, reason: '父 decoration 是非继承字段，子应保持 null / initial');

        await tester.pumpWidget(build(const Color(0xffff0000)));
        await tester.pump();

        final childText1 = child.committedResolvedStyle.inheritedText;
        expect(childText1.color, const Color(0xffff0000), reason: '子 color 更新');
        expect(childText1.decoration, isNull, reason: '借用恢复必须承接 fromInheritedParent 重置语义，decoration 不泄漏');
      });
    });

    group('T22 inheritedBox 借用', () {
      testWidgets('root textDirection 翻转 → 无声明子的 inheritedBox 与父 identical', (tester) async {
        const rootKey = ValueKey('root');
        const childKey = ValueKey('child');

        Widget build(TextDirection dir) => shell(
          ElView(
            key: rootKey,
            style: .new(width: 240, height: 30, textDirection: dir),
            child: ElView(key: childKey, child: 'text'),
          ),
        );

        await tester.pumpWidget(build(TextDirection.ltr));
        await tester.pump();

        BenchmarkProbe.reset();

        await tester.pumpWidget(build(TextDirection.rtl));
        await tester.pump();

        final rootBox = viewOf(tester, rootKey).committedResolvedStyle.inheritedBox;
        final childBox = viewOf(tester, childKey).committedResolvedStyle.inheritedBox;
        expect(rootBox.textDirection, TextDirection.rtl);
        expect(identical(childBox, rootBox), isTrue, reason: 'inheritedBox 组借用恢复：子共享父新组实例');
        expect(BenchmarkProbe.inheritBorrowHitCount, greaterThanOrEqualTo(1), reason: 'inheritedBox 传播路径应命中借用');
      });
    });

    group('T22 与 T21 协同：借用路径下 paint-only 文本失效路由不重排', () {
      testWidgets('root color 翻转（借用路径）→ 文本子 stringPainterLayoutCount 不增', (tester) async {
        const rootKey = ValueKey('root');
        const childKey = ValueKey('child');

        Widget build(Color color) => shell(
          ElView(
            key: rootKey,
            style: .new(width: 240, height: 30, color: color, fontSize: 14),
            child: ElView(key: childKey, style: .new(width: 240, height: 20), child: 'inherited'),
          ),
        );

        await tester.pumpWidget(build(const Color(0xff000000)));
        await tester.pump();

        final child = viewOf(tester, childKey);
        final baselineLayout = ((child.textEngineForTest?.stringPainterLayoutCountForTest) ?? 0);

        BenchmarkProbe.reset();

        await tester.pumpWidget(build(const Color(0xffff0000)));
        await tester.pump();

        expect(BenchmarkProbe.inheritBorrowHitCount, greaterThanOrEqualTo(1), reason: '本路径应命中借用（与 T21 分级共存）');
        expect(
          ((child.textEngineForTest?.stringPainterLayoutCountForTest) ?? 0),
          baselineLayout,
          reason: '借用路径下 changedFields={color} 仍走 paint-only 分级，painter 不 relayout',
        );

        final span = (child.textEngineForTest?.painterForTest.text) as TextSpan?;
        expect(span?.style?.color, const Color(0xffff0000));
      });
    });

    group('T22 build() clamp 语义回归（双 flush 重构未破坏 clamp）', () {
      test('负 width 修正为 null', () {
        final b = ResolvedStyleBuilder.empty();
        b.writeWidth(const ElDimension.pixels(-10));
        final resolved = b.build();
        expect(resolved.box.width, isNull, reason: '负 width 必须 clamp 到 null');
      });

      test('负 height 修正为 null', () {
        final b = ResolvedStyleBuilder.empty();
        b.writeHeight(const ElDimension.pixels(-5));
        final resolved = b.build();
        expect(resolved.box.height, isNull);
      });

      test('负 lineHeight 修正为 null', () {
        final b = ResolvedStyleBuilder.empty();
        b.writeLineHeight(-1.0);
        final resolved = b.build();
        expect(resolved.inheritedText.lineHeight, isNull);
      });

      test('maxLines=0 修正为 null', () {
        final b = ResolvedStyleBuilder.empty();
        b.writeMaxLines(0);
        final resolved = b.build();
        expect(resolved.inheritedText.maxLines, isNull, reason: '0 视为无限制 → null');
      });

      test('maxLines<0 修正为 null', () {
        final b = ResolvedStyleBuilder.empty();
        b.writeMaxLines(-2);
        final resolved = b.build();
        expect(resolved.inheritedText.maxLines, isNull);
      });

      test('合法值不受 clamp 干扰', () {
        final b = ResolvedStyleBuilder.empty();
        b.writeWidth(const ElDimension.pixels(100));
        b.writeHeight(const ElDimension.pixels(50));
        b.writeLineHeight(1.5);
        b.writeMaxLines(3);
        final resolved = b.build();
        expect(resolved.box.width, isNotNull);
        expect(resolved.box.height, isNotNull);
        expect(resolved.inheritedText.lineHeight, 1.5);
        expect(resolved.inheritedText.maxLines, 3);
      });

      test('空 builder build → identical initial groups（每组无写入 flush 零分配）', () {
        final b = ResolvedStyleBuilder.empty();
        final resolved = b.build();
        expect(identical(resolved.inheritedText, InheritedText.initial), isTrue);
        expect(identical(resolved.inheritedBox, InheritedBox.initial), isTrue);
        expect(identical(resolved.box, Box.initial), isTrue);
      });
    });

    test('allRenderViews 工具函数 sanity', () {
      // 只做形式引用，避免未使用 lint。
      expect(allRenderViews, isNotNull);
    });
  });

  group('深链传播开销', () {
    Widget chain(int depth, Key rootKey) {
      Widget child = const ElView(child: 'leaf text');
      for (var i = 0; i < depth; i++) {
        child = ElView(
          style: const ElStyle(padding: .all(0.5)),
          child: child,
        );
      }
      return MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: ElView(
            key: rootKey,
            style: const ElStyle(
              color: Color(0xff222222),
              onDark: ElStyle(color: Color(0xffeeeeee)),
            ),
            child: child,
          ),
        ),
      );
    }

    Future<int> workForDepth(WidgetTester tester, int depth) async {
      final rootKey = ValueKey<int>(depth);
      await tester.pumpWidget(chain(depth, rootKey));
      await tester.pump();

      BenchmarkProbe.reset();
      tester.renderObject<ElRenderView>(find.byKey(rootKey)).setDark(true);
      await tester.pump();
      final s = BenchmarkProbe.snapshot();
      final work =
          (s['cascadeTickCount'] ?? 0) +
          (s['fastPatchHitCount'] ?? 0) +
          (s['inheritBorrowHitCount'] ?? 0) +
          (s['builderBuildCount'] ?? 0);
      debugPrint(
        'depth=$depth work=$work '
        '(tick=${s['cascadeTickCount']} fastPatch=${s['fastPatchHitCount']} '
        'borrow=${s['inheritBorrowHitCount']} build=${s['builderBuildCount']} '
        'propagate=${s['propagateCount']})',
      );
      return work;
    }

    testWidgets('dark 翻转传播成本随深度线性，禁止指数', (tester) async {
      final w12 = await workForDepth(tester, 12);
      final w24 = await workForDepth(tester, 24);

      // 线性合约：深度 ×2 → 工作量 ≤ ×3 + 常数余量（借用/补链的头部开销）。
      // 指数回归下 w24 ≈ 4096 × w12，一触即挂。
      expect(w24, lessThanOrEqualTo(w12 * 3 + 64), reason: '继承传播工作量随深度超线性增长——双走指数回归？');
      // 绝对数量级兜底：24 层链一次翻转的总工作量应在百级，不允许上万。
      expect(w24, lessThan(10000), reason: '24 层链单次 dark 翻转工作量数量级异常');
    });
  });

  group('嵌套状态', () {
    int stateOf(List<ViewState> active) => active.fold(0, (bits, state) => bits | (1 << state.index));

    ResolvedStyle resolve(ElStyle? style, {int? state, ResolvedStyle? parent}) {
      return StyleResolver.resolve(style: style, parent: parent, state: state ?? 0);
    }

    group('AND 链语义', () {
      const bgHover = Color(0xFF00FF00);
      const bgActive = Color(0xFFFF00FF);
      const bgNested = Color(0xFF123456);
      test('onHover(onTap: X) — 仅 hover 不生效', () {
        final r = resolve(
          const ElStyle(
            bgColor: Color(0xFF000000),
            onHover: ElStyle(
              bgColor: bgHover,
              onTap: ElStyle(bgColor: bgNested),
            ),
          ),
          state: stateOf([ViewState.hover]),
        );
        expect(r.box.bgColor, bgHover, reason: '仅 hover 命中顶层 onHover.bgColor，嵌套 onTap 未激活');
      });

      test('onHover(onTap: X) — 仅 active 不生效（顶层 onHover 未激活）', () {
        final r = resolve(
          const ElStyle(
            bgColor: Color(0xFF000000),
            onHover: ElStyle(
              bgColor: bgHover,
              onTap: ElStyle(bgColor: bgNested),
            ),
            onTap: ElStyle(bgColor: bgActive),
          ),
          state: stateOf([ViewState.tap]),
        );
        expect(r.box.bgColor, bgActive, reason: '仅 active：顶层 onTap 生效，嵌套链因 hover 未激活被剪枝');
      });

      test('onHover(onTap: X) — hover+active 都激活 → 嵌套链生效', () {
        final r = resolve(
          const ElStyle(
            bgColor: Color(0xFF000000),
            onHover: ElStyle(
              bgColor: bgHover,
              onTap: ElStyle(bgColor: bgNested),
            ),
            onTap: ElStyle(bgColor: bgActive),
          ),
          state: stateOf([ViewState.hover, ViewState.tap]),
        );
        expect(r.box.bgColor, bgNested, reason: 'hover+active 同时激活，链长 2 压过链长 1 顶层');
      });
    });

    group('特异性覆盖（链长 > 顶层）', () {
      test('链长 2 嵌套 hover(active) 压过顶层 onTap', () {
        const topActive = Color(0xFFAAAAAA);
        const nested = Color(0xFFBBBBBB);
        final r = resolve(
          const ElStyle(
            onTap: ElStyle(bgColor: topActive),
            onHover: ElStyle(onTap: ElStyle(bgColor: nested)),
          ),
          state: stateOf([ViewState.hover, ViewState.tap]),
        );
        expect(r.box.bgColor, nested, reason: '链长 2 特异性 > 顶层链长 1');
      });
    });

    group('onDark(onHover / onTap) 组合', () {
      const darkHover = Color(0xFF111111);
      const darkActive = Color(0xFF222222);
      const base = Color(0xFF000000);
      test('dark+hover → darkHover', () {
        final r = resolve(
          const ElStyle(
            bgColor: base,
            onDark: ElStyle(
              onHover: ElStyle(bgColor: darkHover),
              onTap: ElStyle(bgColor: darkActive),
            ),
          ),
          state: stateOf([ViewState.dark, ViewState.hover]),
        );
        expect(r.box.bgColor, darkHover);
      });

      test('dark+active → darkActive', () {
        final r = resolve(
          const ElStyle(
            bgColor: base,
            onDark: ElStyle(
              onHover: ElStyle(bgColor: darkHover),
              onTap: ElStyle(bgColor: darkActive),
            ),
          ),
          state: stateOf([ViewState.dark, ViewState.tap]),
        );
        expect(r.box.bgColor, darkActive);
      });

      test('dark+hover+active → 按表序 active(表序靠后) 覆 hover 同名字段', () {
        final r = resolve(
          const ElStyle(
            bgColor: base,
            onDark: ElStyle(
              onHover: ElStyle(bgColor: darkHover),
              onTap: ElStyle(bgColor: darkActive),
            ),
          ),
          state: stateOf([ViewState.dark, ViewState.hover, ViewState.tap]),
        );
        expect(r.box.bgColor, darkActive, reason: '同链长（都为 2），DFS pathOrder onHover 先、onTap 后 → active 胜出');
      });
    });

    group('三层嵌套 onDark(onHover(onTap))', () {
      const deep = Color(0xFFDEADBE);
      test('三态齐活才生效', () {
        final style = const ElStyle(
          onDark: ElStyle(
            onHover: ElStyle(onTap: ElStyle(bgColor: deep)),
          ),
        );
        // dark+hover 缺 active
        final a = resolve(style, state: stateOf([ViewState.dark, ViewState.hover]));
        expect(a.box.bgColor, isNull, reason: 'active 未激活 → 三层链剪枝');
        // 全齐
        final b = resolve(style, state: stateOf([ViewState.dark, ViewState.hover, ViewState.tap]));
        expect(b.box.bgColor, deep, reason: '三态齐活 → 链长 3 生效');
      });
    });

    group('嵌套链 vars', () {});

    group('回归锚点（无嵌套 style 输出不变）', () {
      test('普通顶层 onHover 语义与旧行为一致', () {
        final active = resolve(
          const ElStyle(
            bgColor: Color(0xFF000000),
            onHover: ElStyle(bgColor: Color(0xFFFF0000)),
          ),
          state: stateOf([ViewState.hover]),
        );
        expect(active.box.bgColor, const Color(0xFFFF0000));
        final inactive = resolve(
          const ElStyle(
            bgColor: Color(0xFF000000),
            onHover: ElStyle(bgColor: Color(0xFFFF0000)),
          ),
        );
        expect(inactive.box.bgColor, const Color(0xFF000000));
      });
    });

    group('style_spec 判据', () {
      test('单层变体仅在状态命中时进入级联', () {
        const s = ElStyle(onHover: ElStyle(bgColor: Color(0xFF111111)));
        // mask 至少包含 hover 位（顶层声明）
        expect(variantStatesMaskOf(s) & (1 << ViewState.hover.index), isNot(0));
        expect(activeVariantsOf(s, 0), isEmpty);
        expect(activeVariantsOf(s, stateOf([ViewState.hover])), [same(s.onHover)]);
      });

      test('嵌套条件必须全部命中，mask 涵盖各层状态', () {
        const s = ElStyle(
          onDark: ElStyle(
            onHover: ElStyle(onTap: ElStyle(bgColor: Color(0xFF222222))),
          ),
        );
        final m = variantStatesMaskOf(s);
        expect(m & (1 << ViewState.dark.index), isNot(0));
        expect(m & (1 << ViewState.hover.index), isNot(0));
        expect(m & (1 << ViewState.tap.index), isNot(0));
        expect(activeVariantsOf(s, stateOf([ViewState.hover, ViewState.tap])), isEmpty);
        expect(activeVariantsOf(s, m), [same(s.onDark), same(s.onDark!.onHover), same(s.onDark!.onHover!.onTap)]);
      });

      test('null style 判据平稳返回', () {
        expect(variantStatesMaskOf(null), 0);
        expect(mayDeclareTransitionsOf(null), isFalse);
        expect(mayDeclareAnimationsOf(null), isFalse);
      });

      test('按组合深度保持优先级，共享声明经不同路径出现时不去重', () {
        final sharedLeaf = ElStyle(bgColor: Color(0xff111111));
        final otherLeaf = ElStyle(bgColor: Color(0xff222222));
        final hoverTap = ElStyle(onDisabled: sharedLeaf);
        final hoverDark = ElStyle();
        final tapHover = ElStyle();
        final tapDark = ElStyle(onHover: otherLeaf);
        final hover = ElStyle(onTap: hoverTap, onDark: hoverDark);
        final tap = ElStyle(onHover: tapHover, onDark: tapDark);
        final dark = ElStyle(onHover: hoverTap);
        final style = ElStyle(onHover: hover, onTap: tap, onDark: dark);
        final active = activeVariantsOf(
          style,
          stateOf([ViewState.hover, ViewState.tap, ViewState.dark, ViewState.disabled]),
        );
        expect(active, [
          same(hover),
          same(tap),
          same(dark),
          same(hoverTap),
          same(hoverDark),
          same(tapHover),
          same(tapDark),
          same(hoverTap),
          same(sharedLeaf),
          same(otherLeaf),
          same(sharedLeaf),
        ]);
      });
    });
  });

  group('响应式状态', () {
    int bitFor(ViewState s) => 1 << s.index;

    group('computeResponsiveBits 上界边界', () {
      test('宽度 0 —— 落在全部上界之内，xs..xl 全命中', () {
        final bits = computeResponsiveBits(0, null);
        expect(bits & bitFor(ViewState.xs), isNonZero);
        expect(bits & bitFor(ViewState.sm), isNonZero);
        expect(bits & bitFor(ViewState.md), isNonZero);
        expect(bits & bitFor(ViewState.lg), isNonZero);
        expect(bits & bitFor(ViewState.xl), isNonZero);
      });

      test('320 恰在 xs 上界（<=）→ xs 仍命中', () {
        final bits = computeResponsiveBits(320, null);
        expect(bits & bitFor(ViewState.xs), isNonZero);
        expect(bits & bitFor(ViewState.sm), isNonZero);
      });

      test('321 恰过 xs=320 上界 → xs 掉档，sm..xl 命中', () {
        final bits = computeResponsiveBits(321, null);
        expect(bits & bitFor(ViewState.xs), 0);
        expect(bits & bitFor(ViewState.sm), isNonZero);
        expect(bits & bitFor(ViewState.md), isNonZero);
        expect(bits & bitFor(ViewState.lg), isNonZero);
        expect(bits & bitFor(ViewState.xl), isNonZero);
      });

      test('800 → md+lg+xl（不再是移动端）', () {
        final bits = computeResponsiveBits(800, null);
        expect(bits & bitFor(ViewState.xs), 0);
        expect(bits & bitFor(ViewState.sm), 0);
        expect(bits & bitFor(ViewState.md), isNonZero);
        expect(bits & bitFor(ViewState.lg), isNonZero);
        expect(bits & bitFor(ViewState.xl), isNonZero);
      });

      test('1300 → lg+xl', () {
        final bits = computeResponsiveBits(1300, null);
        expect(bits & bitFor(ViewState.md), 0);
        expect(bits & bitFor(ViewState.lg), isNonZero);
        expect(bits & bitFor(ViewState.xl), isNonZero);
      });

      test('2200 —— 过 lg 上界、在 xl 上界内 → 仅 xl', () {
        final bits = computeResponsiveBits(2200, null);
        expect(bits & bitFor(ViewState.lg), 0);
        expect(bits & bitFor(ViewState.xl), isNonZero);
      });

      test('3000 —— 超过 xl 上界 2560 → 全 5 档均为 false（超大布局）', () {
        final bits = computeResponsiveBits(3000, null);
        expect(bits & bitFor(ViewState.xs), 0);
        expect(bits & bitFor(ViewState.sm), 0);
        expect(bits & bitFor(ViewState.md), 0);
        expect(bits & bitFor(ViewState.lg), 0);
        expect(bits & bitFor(ViewState.xl), 0);
      });

      test('自定义断点覆盖 default（sm=700）→ 650 处于 sm 上界内', () {
        final bits = computeResponsiveBits(650, ElBreakpoint(sm: 700));
        // 650 <= sm(700) → sm 位置位；650 > xs(320) → xs 位不置位。
        expect(bits & bitFor(ViewState.sm), isNonZero);
        expect(bits & bitFor(ViewState.xs), 0);
      });

      test('自定义断点覆盖 default（sm=700）→ 720 过 sm 上界，sm 掉档', () {
        final bits = computeResponsiveBits(720, ElBreakpoint(sm: 700));
        expect(bits & bitFor(ViewState.sm), 0);
        expect(bits & bitFor(ViewState.md), isNonZero);
      });
    });

    group('ElBreakpoint.mergeAncestor', () {
      test('self 全 null → 返 ancestor identity', () {
        final ancestor = ElBreakpoint(sm: 700);
        final self = ElBreakpoint();
        final merged = self.mergeAncestor(ancestor);
        expect(identical(merged, ancestor), isTrue);
      });

      test('self 全声明 → 返 self identity', () {
        final ancestor = ElBreakpoint(sm: 700);
        final self = ElBreakpoint(xs: 300, sm: 600, md: 900, lg: 1800, xl: 2400);
        final merged = self.mergeAncestor(ancestor);
        expect(identical(merged, self), isTrue);
      });

      test('部分覆盖 → 逐字段合并', () {
        final ancestor = ElBreakpoint(sm: 700, md: 900);
        final self = ElBreakpoint(sm: 600);
        final merged = self.mergeAncestor(ancestor);
        expect(merged.sm, 600);
        expect(merged.md, 900);
      });
    });

    int stateOf(List<ViewState> active) => active.fold(0, (bits, state) => bits | (1 << state.index));

    ResolvedStyle resolve(ElStyle? style, {int? state}) {
      return StyleResolver.resolve(style: style, parent: null, state: state ?? 0);
    }

    group('StyleResolver 响应式变体 emit', () {
      const bg = Color(0xFF000000);
      const bgSm = Color(0xFF00FF00);
      const bgMd = Color(0xFF0000FF);
      const bgHover = Color(0xFFFF00FF);

      test('移动端宽度（sm+md+lg+xl 位）命中 sm 变体', () {
        final r = resolve(
          const ElStyle(
            bgColor: bg,
            sm: ElStyle(bgColor: bgSm),
          ),
          state: stateOf([ViewState.sm, ViewState.md, ViewState.lg, ViewState.xl]),
        );
        expect(r.box.bgColor, bgSm);
      });

      test('多档同时命中：极小宽度下 sm+md 同亮，后 emit 的 md 胜出', () {
        final r = resolve(
          const ElStyle(
            bgColor: bg,
            sm: ElStyle(bgColor: bgSm),
            md: ElStyle(bgColor: bgMd),
          ),
          state: stateOf([ViewState.xs, ViewState.sm, ViewState.md, ViewState.lg, ViewState.xl]),
        );
        expect(r.box.bgColor, bgMd, reason: '档序升序 emit，后写覆前');
      });

      test('宽屏不命中窄档：lg+xl 位时 md 不生效', () {
        final r = resolve(
          const ElStyle(
            bgColor: bg,
            md: ElStyle(bgColor: bgMd),
          ),
          state: stateOf([ViewState.lg, ViewState.xl]),
        );
        expect(r.box.bgColor, bg);
      });

      test('交互变体压过响应式：hover + md → onHover 胜出', () {
        final r = resolve(
          const ElStyle(
            bgColor: bg,
            md: ElStyle(bgColor: bgMd),
            onHover: ElStyle(bgColor: bgHover),
          ),
          state: stateOf([ViewState.md, ViewState.lg, ViewState.xl, ViewState.hover]),
        );
        expect(r.box.bgColor, bgHover, reason: '交互变体优先级高于响应式');
      });

      test('嵌套 md(onHover:X) — 两位都激活时命中', () {
        const bgNested = Color(0xFF123456);
        final r = resolve(
          const ElStyle(
            bgColor: bg,
            md: ElStyle(
              bgColor: bgMd,
              onHover: ElStyle(bgColor: bgNested),
            ),
          ),
          state: stateOf([ViewState.md, ViewState.lg, ViewState.xl, ViewState.hover]),
        );
        expect(r.box.bgColor, bgNested);
      });

      test('嵌套 md(onHover:X) — 仅 md 无 hover 时回落到 md', () {
        const bgNested = Color(0xFF123456);
        final r = resolve(
          const ElStyle(
            bgColor: bg,
            md: ElStyle(
              bgColor: bgMd,
              onHover: ElStyle(bgColor: bgNested),
            ),
          ),
          state: stateOf([ViewState.md, ViewState.lg, ViewState.xl]),
        );
        expect(r.box.bgColor, bgMd);
      });

      test('嵌套 onHover(md:X) — 反向嵌套：hover+md 时命中', () {
        const bgNested = Color(0xFF654321);
        final r = resolve(
          const ElStyle(
            bgColor: bg,
            onHover: ElStyle(
              bgColor: bgHover,
              md: ElStyle(bgColor: bgNested),
            ),
          ),
          state: stateOf([ViewState.md, ViewState.lg, ViewState.xl, ViewState.hover]),
        );
        expect(r.box.bgColor, bgNested);
      });
    });
  });

  group('共享样式', () {
    testWidgets('共享行样式的八个兄弟均绘制声明的颜色', (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ElView(
            style: const ElStyle(width: 320, height: 200),
            child: List<Widget>.generate(
              8,
              (_) => ElView(style: const ElStyle(width: 24, height: 20, bgColor: Color(0xFF4CAF50))),
              growable: false,
            ),
          ),
        ),
      );
      for (var index = 1; index <= 8; index++) {
        expect(find.byType(ElView).at(index), paints..rect(color: const Color(0xFF4CAF50)));
      }
    });

    testWidgets('共享声明的兄弟节点 hover 状态独立', (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ElView(
            style: const ElStyle(width: 320, height: 200),
            child: List<Widget>.generate(
              2,
              (_) => ElView(
                style: const ElStyle(
                  width: 24,
                  height: 20,
                  bgColor: Color(0xFF4CAF50),
                  onHover: ElStyle(bgColor: Color(0xFF2196F3)),
                ),
              ),
              growable: false,
            ),
          ),
        ),
      );
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await gesture.moveTo(tester.getCenter(find.byType(ElView).at(1)));
      await tester.pumpAndSettle();

      // hover 命中的节点用变体色，其余兄弟保持基础色。
      expect(find.byType(ElView).at(1), paints..rect(color: const Color(0xFF2196F3)));
      expect(find.byType(ElView).at(2), paints..rect(color: const Color(0xFF4CAF50)));
    });
  });

  group('声明掩码', () {
    group('StyleSpec.declaredMask', () {
      test('empty ElStyle → mask == 0', () {
        expect(specOf(ElStyle()).declaredMask, FieldMask.empty);
      });

      test('单字段（bgColor） → 仅该位为 1', () {
        final s = ElStyle(bgColor: Color(0xff112233));
        expect(specOf(s).declaredMask, maskBit(ElTransitionField.bgColor.index));
      });

      test('三字段声明 → 三位 popcount = 3', () {
        final s = ElStyle(bgColor: Color(0xff123456), padding: .all(4), fontSize: 12);
        final expected = _maskOf([ElTransitionField.bgColor, ElTransitionField.padding, ElTransitionField.fontSize]);
        expect(specOf(s).declaredMask, expected);
      });

      test('borderRadius.round sugar → borderRadius 位置位', () {
        expect(
          specOf(ElStyle(borderRadius: BorderRadius.all(Radius.circular(9999)))).declaredMask,
          maskBit(ElTransitionField.borderRadius.index),
        );
      });

      test('borderRadius.circle sugar → borderRadius 位置位', () {
        expect(
          specOf(ElStyle(borderRadius: BorderRadius.all(Radius.circular(9999)))).declaredMask,
          maskBit(ElTransitionField.borderRadius.index),
        );
      });

      test('顶层 spec 不含变体位（onHover 独立查）', () {
        final s = ElStyle(
          bgColor: Color(0xff123456),
          onHover: ElStyle(bgColor: Color(0xffaabbcc), padding: .all(2)),
        );
        // 顶层 mask 只包含 bgColor（onHover 字段本身不进 declaration 流）
        expect(specOf(s).declaredMask, maskBit(ElTransitionField.bgColor.index));
        // 变体本身也是 ElStyle，可查
        final hoverExpected = _maskOf([ElTransitionField.bgColor, ElTransitionField.padding]);
        expect(specOf(s.onHover!).declaredMask, hoverExpected);
      });

      test('同一声明重复扫描的位图一致', () {
        final s = ElStyle(bgColor: Color(0xff123456));
        final a = specOf(s);
        final b = specOf(s);
        expect(a.declaredMask, b.declaredMask);
      });

      test('值等的新声明实例得到相同位图', () {
        final s1 = ElStyle(bgColor: Color(0xff123456));
        final s2 = ElStyle(bgColor: Color(0xff123456));
        expect(s1 == s2, isTrue); // 前提确认
        final a = specOf(s1);
        final b = specOf(s2);
        expect(a.declaredMask, b.declaredMask);
      });
    });

    group('activeVariantDeclaredMask', () {
      test('self 与 nested 只收集当前完整命中的字段链', () {
        const style = ElStyle(
          onHover: ElStyle(width: 120, onTap: ElStyle(color: Color(0xFFFF0000))),
        );
        final hoverBits = 1 << ViewState.hover.index;
        final activeBits = 1 << ViewState.tap.index;
        final colorBit = maskBit(ElTransitionField.color.index);
        final widthBit = maskBit(ElTransitionField.width.index);

        expect(activeVariantDeclaredMask(style, hoverBits), widthBit, reason: 'active 未命中时不能提前保护 nested color');
        expect(activeVariantDeclaredMask(style, hoverBits | activeBits), maskOr(widthBit, colorBit));
      });
    });
  });

  group('过渡声明级联', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    final red = const Color(0xFFFF0000);

    final blue = const Color(0xFF0000FF);

    final green = const Color(0xFF00FF00);

    const transitionFast = ElTransition.all(Duration.zero);

    const transitionSlow = ElTransition.all();

    int stateWith(List<ViewState> states) => states.fold(0, (bits, state) => bits | (1 << state.index));

    ({CascadeTickResult result, StyleAnimationDriver driver}) tickWith({
      required ElStyle style,
      required List<ViewState> activeStates,
      List<ViewState>? oldActiveStates,
    }) {
      final oldCommitted = StyleResolver.resolve(
        style: style,
        parent: null,
        state: stateWith(oldActiveStates ?? const []),
      );
      final driver = StyleAnimationDriver(onTick: () {});
      final result = CascadeTick.tick(
        style: style,
        parent: null,
        oldCommitted: oldCommitted,
        state: stateWith(activeStates),

        driver: driver,
      );
      return (result: result, driver: driver);
    }

    void cleanup(StyleAnimationDriver d) {
      d.cancelAll();
      d.dispose();
    }

    group('单个状态变体的 transitions 覆盖根 (7 状态全覆盖)', () {
      // 每个状态都构造同样的场景：根 transitions=slow，onXxx.transitions=fast，
      // 命中 Xxx 时 bgColor red→blue 应立即生效（不启动动画）。
      final cases = <(String, ViewState, ElStyle Function())>[
        (
          'onHover',
          ViewState.hover,
          () => const ElStyle(
            bgColor: Color(0xFFFF0000),
            onHover: ElStyle(bgColor: Color(0xFF0000FF), transitions: [transitionFast]),
            transitions: [transitionSlow],
          ),
        ),
        (
          'onTap',
          ViewState.tap,
          () => const ElStyle(
            bgColor: Color(0xFFFF0000),
            onTap: ElStyle(bgColor: Color(0xFF0000FF), transitions: [transitionFast]),
            transitions: [transitionSlow],
          ),
        ),
        (
          'onFocus',
          ViewState.focus,
          () => const ElStyle(
            bgColor: Color(0xFFFF0000),
            onFocus: ElStyle(bgColor: Color(0xFF0000FF), transitions: [transitionFast]),
            transitions: [transitionSlow],
          ),
        ),
        (
          'onFocusWithin',
          ViewState.focusWithin,
          () => const ElStyle(
            bgColor: Color(0xFFFF0000),
            onFocusWithin: ElStyle(bgColor: Color(0xFF0000FF), transitions: [transitionFast]),
            transitions: [transitionSlow],
          ),
        ),
        (
          'onDisabled',
          ViewState.disabled,
          () => const ElStyle(
            bgColor: Color(0xFFFF0000),
            onDisabled: ElStyle(bgColor: Color(0xFF0000FF), transitions: [transitionFast]),
            transitions: [transitionSlow],
          ),
        ),
        (
          'onFocusVisible',
          ViewState.focusVisible,
          () => const ElStyle(
            bgColor: Color(0xFFFF0000),
            onFocusVisible: ElStyle(bgColor: Color(0xFF0000FF), transitions: [transitionFast]),
            transitions: [transitionSlow],
          ),
        ),
        (
          'onDark',
          ViewState.dark,
          () => const ElStyle(
            bgColor: Color(0xFFFF0000),
            onDark: ElStyle(bgColor: Color(0xFF0000FF), transitions: [transitionFast]),
            transitions: [transitionSlow],
          ),
        ),
      ];

      for (final (label, state, build) in cases) {
        test('$label.transitions 覆盖根：duration=0 命中时 bgColor 立即生效', () {
          final (:result, :driver) = tickWith(style: build(), activeStates: [state]);
          try {
            expect(
              result.changedMask.fields.toSet(),
              contains(ElTransitionField.bgColor),
              reason: '$label 状态变体的 transitions=[all(0)] 应被识别 → 立即生效',
            );
            expect(driver.activeFields, isEmpty, reason: '$label 状态下 0-duration 不应启动动画（short-circuit）');
          } finally {
            cleanup(driver);
          }
        });

        test('$label 未声明 transitions：fallback 到根 slow → 启动动画', () {
          // 同样的 variant 但去掉 transitions，根仍是 slow（250ms）
          final style = ElStyle(
            bgColor: red,
            onHover: state == ViewState.hover ? const ElStyle(bgColor: Color(0xFF0000FF)) : null,
            onTap: state == ViewState.tap ? const ElStyle(bgColor: Color(0xFF0000FF)) : null,
            onFocus: state == ViewState.focus ? const ElStyle(bgColor: Color(0xFF0000FF)) : null,
            onFocusWithin: state == ViewState.focusWithin ? const ElStyle(bgColor: Color(0xFF0000FF)) : null,
            onDisabled: state == ViewState.disabled ? const ElStyle(bgColor: Color(0xFF0000FF)) : null,
            onFocusVisible: state == ViewState.focusVisible ? const ElStyle(bgColor: Color(0xFF0000FF)) : null,
            onDark: state == ViewState.dark ? const ElStyle(bgColor: Color(0xFF0000FF)) : null,
            transitions: const [transitionSlow],
          );
          final (:result, :driver) = tickWith(style: style, activeStates: [state]);
          try {
            expect(
              driver.activeFields,
              contains(ElTransitionField.bgColor),
              reason: '$label 未声明 transitions → fallback 根 slow → 启动动画',
            );
            expect(
              result.changedMask.fields.toSet(),
              isNot(contains(ElTransitionField.bgColor)),
              reason: '字段进入动画时不应出现在 changedFields',
            );
          } finally {
            cleanup(driver);
          }
        });
      }
    });

    group('cascade 优先级冲突', () {
      test('hover + active 同时命中：active.transitions 胜出（depth 高）', () {
        final style = ElStyle(
          bgColor: red,
          onHover: ElStyle(
            bgColor: green,
            transitions: const [transitionSlow], // 故意 slow
          ),
          onTap: ElStyle(
            bgColor: blue,
            transitions: const [transitionFast], // active 是 fast
          ),
          transitions: const [transitionSlow],
        );
        final (:result, :driver) = tickWith(style: style, activeStates: [ViewState.hover, ViewState.tap]);
        try {
          // active.bgColor=blue 是高优先级；transitions 也是 active 的（fast）→ 立即生效
          expect(result.changedMask.fields.toSet(), contains(ElTransitionField.bgColor));
          expect(driver.activeFields, isEmpty);
        } finally {
          cleanup(driver);
        }
      });

      test('hover + active 同时命中，active 未声明 transitions → fallback 到 hover', () {
        final style = ElStyle(
          bgColor: red,
          onHover: const ElStyle(
            bgColor: Color(0xFF00FF00),
            transitions: [transitionFast], // hover 是 fast
          ),
          onTap: const ElStyle(
            bgColor: Color(0xFF0000FF),
            // 没声明 transitions
          ),
          transitions: const [transitionSlow], // 根 slow
        );
        final (:result, :driver) = tickWith(style: style, activeStates: [ViewState.hover, ViewState.tap]);
        try {
          // active 没声明 transitions → 不能跳过 active 直接走 base，应回退到次高优先级 hover.transitions
          expect(
            result.changedMask.fields.toSet(),
            contains(ElTransitionField.bgColor),
            reason: 'active 未声明 transitions → 回退到 hover.transitions=fast → 立即生效',
          );
          expect(driver.activeFields, isEmpty);
        } finally {
          cleanup(driver);
        }
      });

      test('disabled > active > hover：disabled.transitions 应胜出', () {
        // disabled.depth=4 > active.depth=1 > hover.depth=0
        final style = ElStyle(
          bgColor: red,
          onHover: const ElStyle(bgColor: Color(0xFFFFFF00), transitions: [transitionSlow]),
          onTap: const ElStyle(bgColor: Color(0xFF00FFFF), transitions: [transitionSlow]),
          onDisabled: const ElStyle(
            bgColor: Color(0xFFFF00FF),
            transitions: [transitionFast], // 仅 disabled 是 fast
          ),
          transitions: const [transitionSlow],
        );
        final (:result, :driver) = tickWith(
          style: style,
          activeStates: [ViewState.hover, ViewState.tap, ViewState.disabled],
        );
        try {
          expect(result.changedMask.fields.toSet(), contains(ElTransitionField.bgColor));
          expect(driver.activeFields, isEmpty);
        } finally {
          cleanup(driver);
        }
      });
    });

    group('fallback 到 base', () {
      test('所有变体都未声明 transitions → 用 base', () {
        final style = ElStyle(
          bgColor: red,
          onHover: const ElStyle(bgColor: Color(0xFF0000FF)),
          onTap: const ElStyle(bgColor: Color(0xFF00FF00)),
          transitions: const [transitionFast], // base 是 fast
        );
        final (:result, :driver) = tickWith(style: style, activeStates: [ViewState.hover, ViewState.tap]);
        try {
          expect(
            result.changedMask.fields.toSet(),
            contains(ElTransitionField.bgColor),
            reason: '所有变体均未声明 transitions → base.transitions=fast → 立即生效',
          );
          expect(driver.activeFields, isEmpty);
        } finally {
          cleanup(driver);
        }
      });

      test('未命中任何变体 → 用 base', () {
        final style = ElStyle(
          bgColor: red,
          onTap: ElStyle(bgColor: blue, transitions: const [transitionFast]),
          transitions: const [transitionSlow],
        );
        // 不命中 active：cascade 没改 bgColor → 啥也不发生
        final (:result, :driver) = tickWith(style: style, activeStates: const []);
        try {
          expect(result.changedMask.fields.toSet(), isNot(contains(ElTransitionField.bgColor)));
          expect(driver.activeFields, isEmpty);
        } finally {
          cleanup(driver);
        }
      });
    });

    group('groupVariant 的 transitions 也走 cascade', () {});

    group('0 duration short-circuit', () {
      test('transitions=[all(0)] 字段立即生效，不启动 driver 动画', () {
        final style = ElStyle(
          bgColor: red,
          onTap: ElStyle(bgColor: blue, transitions: const [transitionFast]),
        );
        final (:result, :driver) = tickWith(style: style, activeStates: [ViewState.tap]);
        try {
          expect(result.changedMask.fields.toSet(), contains(ElTransitionField.bgColor));
          expect(driver.activeFields, isEmpty, reason: '0-duration short-circuit：不应启动 0 时长的 placeholder 动画');
        } finally {
          cleanup(driver);
        }
      });

      test('对照：transitions=[all(默认 250ms)] 启动动画', () {
        final style = ElStyle(
          bgColor: red,
          onTap: ElStyle(
            bgColor: blue,
            transitions: const [transitionSlow], // 250ms
          ),
        );
        final (:result, :driver) = tickWith(style: style, activeStates: [ViewState.tap]);
        try {
          expect(driver.activeFields, contains(ElTransitionField.bgColor));
          expect(result.changedMask.fields.toSet(), isNot(contains(ElTransitionField.bgColor)));
        } finally {
          cleanup(driver);
        }
      });
    });

    group('回归：oldCommitted 用作初始 ResolvedStyle 时不死锁 cascade', () {
      // 防御 _effectiveTransitions 内 closure 不被 walker.walk 内多次 visit 时
      // 误覆盖；同时验证返回值是 ResolvedStyle 而不会 throw。
    });
  });
}
