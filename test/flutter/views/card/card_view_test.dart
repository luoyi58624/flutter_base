import '../../../ui/support/overlay.dart';
import 'dart:ui' show Tristate;

import 'package:flutter_base/ui.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/material.dart' show MaterialApp, Scaffold;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../ui/semantics/common.dart';

Widget _host(Widget child) => Directionality(
  textDirection: .ltr,
  child: ElView(
    style: ElStyle(alignment: .topLeft),
    child: child,
  ),
);

void main() {
  final binding = ElSemanticsTestBinding();
  setUp(binding.resetSemanticsRecords);

  testWidgets('无默认样式：沿用内容尺寸与祖先样式，空区域仍可独立捕获', (tester) async {
    final card = ValueKey('card');
    final plain = ValueKey('plain');
    final content = ValueKey('content');
    await tester.pumpWidget(
      _host(
        ElView(
          style: ElStyle(color: Color(0xff234567), fontSize: 23),
          child: Column(
            mainAxisSize: .min,
            crossAxisAlignment: .start,
            children: [
              ElCardView(
                key: card,
                child: ElView(key: content, child: '区域内容'),
              ),
              ElView(key: plain, child: '区域内容'),
            ],
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byKey(card)), tester.getSize(find.byKey(plain)));
    expect(tester.getRect(find.byKey(card)), tester.getRect(find.byKey(content)));
    final render = tester.renderObject<ElRenderView>(find.byKey(content));
    final reference = tester.renderObject<ElRenderView>(find.byKey(plain));
    expect(render.committedResolvedStyle.inheritedText, reference.committedResolvedStyle.inheritedText);
    expect(
      tester.renderObject<ElRenderView>(find.byKey(card)).committedResolvedStyle.box,
      reference.committedResolvedStyle.box,
    );
    await tester.pumpWidget(_host(ElCardView(key: card, style: ElStyle(width: 180, height: 100))));
    binding.expectContainerHit(tester, find.byKey(card));
    final data = tester.getSemantics(find.byKey(card)).getSemanticsData();
    expect(data.label, isEmpty);
    expect(data.hasAction(SemanticsAction.tap), isFalse);
    expect(data.flagsCollection.isButton, isFalse);
    expect(data.flagsCollection.isFocused, Tristate.none);
  });

  testWidgets('名称只描述区域，标题和两个子按钮独立可读、可操作', (tester) async {
    final card = ValueKey('card');
    var firstTaps = 0;
    var secondTaps = 0;
    await tester.pumpWidget(
      _host(
        ElCardView(
          key: card,
          semanticLabel: '功能区域',
          style: ElStyle(width: 260, height: 200, padding: .all(20)),
          child: Column(
            crossAxisAlignment: .start,
            children: [
              ElView(child: '区域标题'),
              ElView(child: '区域说明'),
              ElButtonView(onPressed: () => firstTaps++, child: '第一个操作'),
              ElButtonView(onPressed: () => secondTaps++, child: '第二个操作'),
            ],
          ),
        ),
      ),
    );
    binding.expectContainerHit(tester, find.byKey(card));
    final parent = tester.getSemantics(find.byKey(card));
    expect(parent.getSemanticsData().label, '功能区域');
    expect(parent.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
    for (final label in ['区域标题', '区域说明', '第一个操作', '第二个操作']) {
      final record = binding.reachableNodes.singleWhere((node) => node.label == label);
      expect(binding.nodes[parent.id]!.children, contains(record.id));
      if (label.endsWith('操作')) parent.owner!.performAction(record.id, SemanticsAction.tap);
    }
    expect(firstTaps, 1);
    expect(secondTaps, 1);
  });

  testWidgets('区域不增加 Tab 停靠点，内部按钮保留键盘激活', (tester) async {
    final first = FocusNode();
    final second = FocusNode();
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    final card = ValueKey('card');
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _host(
            Column(
              children: [
                ElButtonView(focusNode: first, child: '区域前'),
                ElCardView(
                  key: card,
                  semanticLabel: '操作区域',
                  child: ElButtonView(focusNode: second, onPressed: () => taps++, child: '区域内'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    first.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(second.hasPrimaryFocus, isTrue);
    expect(tester.getSemantics(find.byKey(card)).getSemanticsData().flagsCollection.isFocused, Tristate.none);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(taps, 1);
  });

  testWidgets('嵌套区域的边界、留白和后代归属保持独立', (tester) async {
    final outer = ValueKey('outer');
    final inner = ValueKey('inner');
    await tester.pumpWidget(
      _host(
        ElCardView(
          key: outer,
          style: ElStyle(width: 300, height: 220, padding: .all(20), alignment: .topLeft),
          child: ElCardView(
            key: inner,
            style: ElStyle(width: 160, height: 100, padding: .all(16)),
            child: ElView(child: '内层内容'),
          ),
        ),
      ),
    );
    binding.expectContainerHit(tester, find.byKey(outer));
    binding.expectContainerHit(tester, find.byKey(inner));
    final outerNode = tester.getSemantics(find.byKey(outer));
    final innerNode = tester.getSemantics(find.byKey(inner));
    expect(binding.nodes[outerNode.id]!.children, contains(innerNode.id));
    expect(innerNode.id, isNot(outerNode.id));
  });

  for (final ratio in [1.0, 1.75]) {
    testWidgets('富文本内联控件也从容器可见盒起算 dpr=$ratio', (tester) async {
      tester.view.devicePixelRatio = ratio;
      tester.view.physicalSize = Size(500 * ratio, 300 * ratio);
      addTearDown(tester.view.reset);
      final inline = ValueKey('inline-native');
      final card = ValueKey('inline-card');
      await tester.pumpWidget(
        _host(
          ElCardView(
            key: card,
            semanticLabel: '内联区域',
            style: ElStyle(width: 260, height: 100, margin: .only(left: 12, top: 16), padding: .all(10)),
            child: [
              '前',
              Semantics(
                key: inline,
                container: true,
                label: '内联操作',
                child: ElView(style: ElStyle(width: 60, height: 28)),
              ),
              '后',
            ],
          ),
        ),
      );
      binding.expectContainerHit(tester, find.byKey(card), logicalRect: Rect.fromLTWH(12, 16, 260, 100));
      binding.expectGeometry(tester, find.byKey(inline));
      expect(binding.hitTestWindowsSemantics(tester.getCenter(find.byKey(inline)) * ratio)?.label, '内联操作');
      await reassembleSemantics(tester);
      binding.expectGeometry(tester, find.byKey(inline));
    });
    testWidgets('嵌套外边距中的独立子树更新不重复累计坐标 dpr=$ratio', (tester) async {
      tester.view.devicePixelRatio = ratio;
      tester.view.physicalSize = Size(600 * ratio, 400 * ratio);
      addTearDown(tester.view.reset);
      final label = ValueNotifier('原生子节点-0');
      addTearDown(label.dispose);
      final leaf = ValueKey('native-leaf');
      final outer = ValueKey('nested-outer');
      final inner = ValueKey('nested-inner');
      final child = ValueListenableBuilder(
        valueListenable: label,
        builder: (_, value, _) => Semantics(
          key: leaf,
          container: true,
          label: value,
          child: ElView(style: ElStyle(width: 80, height: 32)),
        ),
      );
      int? leafId;
      for (final margin in [16.0, 32.0, 0.0, 16.0]) {
        await tester.pumpWidget(
          _host(
            ElCardView(
              key: outer,
              style: ElStyle(
                width: 260,
                height: 180,
                margin: .only(left: margin, top: margin),
                padding: .all(12),
                alignment: .topLeft,
              ),
              child: ElCardView(
                key: inner,
                style: ElStyle(width: 180, height: 100, margin: .only(left: 8, top: 10), padding: .all(14)),
                child: child,
              ),
            ),
          ),
        );
        for (var update = 0; update < 3; update++) {
          label.value = '原生子节点-$margin-$update';
          await tester.pump();
          final node = tester.getSemantics(find.byKey(leaf));
          leafId ??= node.id;
          expect(node.id, leafId);
          binding.expectGeometry(tester, find.byKey(leaf));
          final rect = tester.getRect(find.byKey(leaf));
          expect(rect.topLeft, Offset(margin + 34, margin + 36));
          expect(binding.hitTestWindowsSemantics(rect.center * ratio)?.label, label.value);
          binding.expectContainerHit(tester, find.byKey(outer), logicalRect: Rect.fromLTWH(margin, margin, 260, 180));
          binding.expectContainerHit(
            tester,
            find.byKey(inner),
            logicalRect: Rect.fromLTWH(margin + 20, margin + 22, 180, 100),
          );
        }
        await reassembleSemantics(tester);
        binding.expectGeometry(tester, find.byKey(leaf));
      }
    });
    for (final cardView in [false, true]) {
      testWidgets('区域外边距不进入语义捕获范围 card=$cardView dpr=$ratio', (tester) async {
        tester.view.devicePixelRatio = ratio;
        tester.view.physicalSize = Size(400 * ratio, 300 * ratio);
        addTearDown(tester.view.reset);
        final key = ValueKey('margin-region');
        for (final margin in [12.0, 28.0, 12.0]) {
          final style = ElStyle(width: 140, height: 80, margin: .all(margin), padding: .all(12));
          final child = ElView(key: ValueKey('margin-content'), child: '区域内容');
          await tester.pumpWidget(
            _host(
              cardView
                  ? ElCardView(key: key, style: style, child: child)
                  : ElView(
                      key: key,
                      style: style,
                      semantics: ElSemantics(container: true, explicitChildNodes: true),
                      child: child,
                    ),
            ),
          );
          final finder = find.byKey(key);
          final id = tester.getSemantics(finder).id;
          final visible = Rect.fromLTWH(margin, margin, 140, 80);
          binding.expectGeometry(tester, finder, logicalRect: visible);
          binding.expectGeometry(tester, find.byKey(ValueKey('margin-content')));
          final inside = (visible.topLeft + Offset(4, 4)) * ratio;
          expect(binding.hitTestWindowsSemantics(inside)?.id, id);
          expect(binding.hitTestSemantics(inside)?.id, id);
          final outside = Offset(4, 4) * ratio;
          expect(binding.hitTestWindowsSemantics(outside)?.id, isNot(id));
          expect(binding.hitTestSemantics(outside)?.id, isNot(id));
        }
      });
    }
    testWidgets('尺寸、变换和热重载同步区域边界 dpr=$ratio', (tester) async {
      tester.view.devicePixelRatio = ratio;
      tester.view.physicalSize = Size(600 * ratio, 400 * ratio);
      addTearDown(tester.view.reset);
      final card = ValueKey('card');
      for (final spec in [(120.0, 0.0, 1.0), (200.0, 80.0, 1.5), (120.0, 0.0, 1.0)]) {
        await tester.pumpWidget(
          _host(
            ElCardView(
              key: card,
              style: ElStyle(
                width: spec.$1,
                height: 100,
                padding: .all(16),
                transform: ElTransform.matrix(spec.$3, 0, 0, spec.$3, spec.$2, 30),
                transformAlignment: .topLeft,
              ),
              child: ElView(child: '内容'),
            ),
          ),
        );
        binding.expectContainerHit(
          tester,
          find.byKey(card),
          logicalRect: Rect.fromLTWH(spec.$2, 30, spec.$1 * spec.$3, 100 * spec.$3),
        );
      }
      await reassembleSemantics(tester);
      binding.expectContainerHit(tester, find.byKey(card), logicalRect: Rect.fromLTWH(0, 30, 120, 100));
    });

    testWidgets('滚动和部分裁剪保留区域及内部控件，回顶恢复边界 dpr=$ratio', (tester) async {
      tester.view.devicePixelRatio = ratio;
      tester.view.physicalSize = Size(400 * ratio, 240 * ratio);
      addTearDown(tester.view.reset);
      final controller = ElScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _host(
          ElScrollView(
            controller: controller,
            scrollbar: ElNoScrollBar(),
            children: [
              for (var i = 0; i < 12; i++)
                ElCardView(
                  key: ValueKey(i),
                  semanticLabel: '区域-$i',
                  style: ElStyle(height: 90, padding: .all(12), alignment: .topLeft),
                  child: ElButtonView(
                    key: ValueKey('button-$i'),
                    style: ElStyle(width: 80, height: 32),
                    onPressed: () {},
                    child: '操作-$i',
                  ),
                ),
            ],
          ),
        ),
      );
      for (final offset in [0.0, 35.0, 310.0, 0.0]) {
        controller.jumpTo(offset);
        await tester.pumpAndSettle();
        var checked = 0;
        for (var i = 0; i < 12; i++) {
          final finder = find.byKey(ValueKey(i));
          final visible = tester.getRect(finder).intersect(Rect.fromLTWH(0, 0, 400, 240));
          if (visible.isEmpty) continue;
          // 边界保留完整区域坐标，视口负责限制可访问命中，不能移动父节点原点。
          binding.expectGeometry(tester, finder);
          final point = Offset(visible.right - 4, visible.center.dy) * ratio;
          expect(binding.hitTestWindowsSemantics(point)?.label, '区域-$i');
          expect(binding.hitTestSemantics(point)?.label, '区域-$i');
          final button = find.byKey(ValueKey('button-$i'));
          final rect = tester.getRect(button);
          if (visible.contains(rect.topLeft) && visible.contains(rect.bottomRight)) {
            binding.expectGeometry(tester, button);
            expect(binding.hitTestWindowsSemantics(rect.center * ratio)?.label, '操作-$i');
          }
          checked++;
        }
        expect(checked, greaterThanOrEqualTo(3));
        expect(binding.hitTestWindowsSemantics(Offset(4, -4) * ratio), isNull);
        expect(binding.hitTestWindowsSemantics(Offset(4, 244) * ratio), isNull);
      }
    });

    testWidgets('浮层区域按层序捕获，关闭后恢复下层区域 dpr=$ratio', (tester) async {
      tester.view.devicePixelRatio = ratio;
      tester.view.physicalSize = Size(600 * ratio, 400 * ratio);
      addTearDown(tester.view.reset);
      final page = GlobalKey();
      final first = GlobalKey();
      final second = GlobalKey();
      await tester.pumpWidget(
        _host(
          ElTestOverlay(
            child: Semantics(
              sortKey: OrdinalSortKey(2),
              child: ElCardView(key: page, semanticLabel: '页面区域', style: ElStyle(width: 600, height: 400)),
            ),
          ),
        ),
      );
      final host = Overlay.of(page.currentContext!);
      var firstOnTop = false;
      OverlayEntry insert(GlobalKey key) {
        final entry = OverlayEntry(
          builder: (_) => Positioned.fromRect(
            rect: Rect.fromLTWH(100, 80, 240, 160),
            // 官方语义排序显式跟随 entry 顺序，Windows 桥按遍历顺序命中。
            child: Semantics(
              sortKey: OrdinalSortKey((identical(key, first) == firstOnTop) ? 0 : 1),
              child: ElCardView(
                key: key,
                style: ElStyle(padding: .all(20)),
                child: ElView(child: '浮层内容'),
              ),
            ),
          ),
        );
        host.insert(entry);
        return entry;
      }

      final firstEntry = insert(first);
      final secondEntry = insert(second);
      await tester.pumpAndSettle();
      binding.expectContainerHit(tester, find.byKey(second));
      final outside = Offset(500, 300) * ratio;
      expect(binding.hitTestWindowsSemantics(outside)?.label, '页面区域');
      host.rearrange([secondEntry, firstEntry], below: secondEntry);
      firstOnTop = true;
      firstEntry.markNeedsBuild();
      secondEntry.markNeedsBuild();
      await tester.pumpAndSettle();
      binding.expectContainerHit(tester, find.byKey(first));
      firstEntry.remove();
      firstEntry.dispose();
      await tester.pumpAndSettle();
      binding.expectContainerHit(tester, find.byKey(second));
      secondEntry.remove();
      secondEntry.dispose();
      await tester.pumpAndSettle();
      binding.expectContainerHit(tester, find.byKey(page));
    });
  }

  testWidgets('区域名称更新、隐藏和恢复不遗留旧节点', (tester) async {
    final card = ValueKey('card');
    Widget tree(String name, {bool hidden = false}) => _host(
      Offstage(
        offstage: hidden,
        child: ElCardView(key: card, semanticLabel: name, style: ElStyle(width: 180, height: 100)),
      ),
    );
    await tester.pumpWidget(tree('旧区域'));
    final id = tester.getSemantics(find.byKey(card)).id;
    await tester.pumpWidget(tree('新区域'));
    expect(tester.getSemantics(find.byKey(card)).id, id);
    expect(binding.reachableNodes.where((node) => node.label == '旧区域'), isEmpty);
    await tester.pumpWidget(tree('新区域', hidden: true));
    expect(binding.reachableNodes.where((node) => node.label == '新区域'), isEmpty);
    await tester.pumpWidget(tree('新区域'));
    binding.expectContainerHit(tester, find.byKey(card));
    await tester.pumpWidget(_host(ElView()));
    expect(binding.reachableNodes.where((node) => node.label == '新区域'), isEmpty);
  });

  testWidgets('语义延迟开启和重新开启仍自动建立区域', semanticsEnabled: false, (tester) async {
    final card = ValueKey('card');
    await tester.pump();
    expect(binding.semanticsEnabled, isFalse);
    binding.resetSemanticsRecords();
    await tester.pumpWidget(_host(ElCardView(key: card, style: ElStyle(width: 180, height: 100))));
    expect(binding.batches, 0);
    for (var attempt = 0; attempt < 2; attempt++) {
      final handle = tester.ensureSemantics();
      try {
        await tester.pump();
        binding.expectContainerHit(tester, find.byKey(card));
        await reassembleSemantics(tester);
        binding.expectContainerHit(tester, find.byKey(card));
      } finally {
        handle.dispose();
      }
      await tester.pump();
    }
  });
}
