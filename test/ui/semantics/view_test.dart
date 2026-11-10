import 'package:flutter_base/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dart:ui' show SemanticsInputType, Tristate;

import 'package:flutter_base/src/ui/testing/ui_test_api.dart';

import 'common.dart';

void main() {
  final binding = ElSemanticsTestBinding();
  setUp(binding.resetSemanticsRecords);
  _registerGeometryTests(binding);
  _registerTransformGeometryTests(binding);
  group('基本属性', _registerBasicTests);
  group('树结构', _registerTreeTests);
  group('属性与动作', _registerPropertyTests);
  group('重挂生命周期', _registerReattachTests);
}

void _registerTransformGeometryTests(ElSemanticsTestBinding binding) {
  for (final ratio in [1.0, 1.75]) {
    for (final container in [false, true]) {
      testWidgets('仅修改变换及原点同步后代坐标 container=$container dpr=$ratio', (tester) async {
        tester.view.devicePixelRatio = ratio;
        tester.view.physicalSize = Size(600 * ratio, 400 * ratio);
        addTearDown(tester.view.reset);
        final leaf = ElButtonView(
          key: ValueKey('transform-leaf'),
          semanticLabel: '操作',
          onPressed: () {},
          style: ElStyle(width: 40, height: 24),
        );
        Widget host(ElTransform? transform, Alignment alignment) {
          final style = ElStyle(
            width: 200,
            height: 160,
            padding: .all(30),
            transform: transform,
            transformOrigin: alignment,
          );
          return Directionality(
            textDirection: .ltr,
            child: ElView(
              style: ElStyle(alignment: .topLeft, padding: .all(80)),
              child: container
                  ? ElView(semantics: ElSemantics(container: true, explicitChildNodes: true), style: style, child: leaf)
                  : ElView(style: style, child: leaf),
            ),
          );
        }

        int? id;
        for (final spec in <(ElTransform?, Alignment)>[
          (null, .topLeft),
          (ElTransform.translate(16, 8), .topLeft),
          (ElTransform.scale(1.2), .topLeft),
          (ElTransform.scale(1.2), .bottomRight),
          (null, .bottomRight),
        ]) {
          await tester.pumpWidget(host(spec.$1, spec.$2));
          final target = find.byKey(ValueKey('transform-leaf'));
          final node = tester.getSemantics(target);
          id ??= node.id;
          expect(node.id, id, reason: '保留原节点，不能靠重建语义树掩盖漏更新');
          binding.expectGeometry(tester, target);
          final point = tester.getRect(target).center * ratio;
          expect(binding.hitTestWindowsSemantics(point)?.id, id);
          expect(binding.hitTestSemantics(point)?.id, id);
        }
      });
    }

    for (final mode in ['starting', 'transition', 'keyframe']) {
      testWidgets('位移动画逐帧及完成后同步子节点语义 mode=$mode dpr=$ratio', (tester) async {
        tester.view.devicePixelRatio = ratio;
        tester.view.physicalSize = Size(600 * ratio, 400 * ratio);
        addTearDown(tester.view.reset);
        final leaf = ElView(
          key: ValueKey('animated-leaf'),
          child: '动画内容',
          style: ElStyle(width: 80, height: 30),
          semantics: ElSemantics(container: true),
        );
        Widget host({bool shifted = true}) => Directionality(
          textDirection: .ltr,
          child: ElView(
            style: ElStyle(alignment: .topLeft, padding: .all(80)),
            child: ElView(
              semantics: ElSemantics(container: true, explicitChildNodes: true),
              style: ElStyle(
                width: 240,
                height: 180,
                padding: .all(30),
                transform: mode == 'transition' && shifted ? .translate(0, 8) : null,
                starting: mode == 'starting' ? ElStyle(transform: .translate(0, 8)) : null,
                transition: [.field(.transform, Duration(milliseconds: 200), Curves.linear)],
                animation: mode == 'keyframe'
                    ? [
                        ElAnimation(
                          keyframes: {
                            0: ElStyle(transform: .translate(0, 8)),
                            100: ElStyle(transform: .translate(0, 0)),
                          },
                          animationDuration: Duration(milliseconds: 200),
                          animationTimingFunction: Curves.linear,
                        ),
                      ]
                    : null,
              ),
              child: leaf,
            ),
          ),
        );
        await tester.pumpWidget(host());
        if (mode == 'transition') await tester.pumpWidget(host(shifted: false));
        final target = find.byKey(ValueKey('animated-leaf'));
        final id = tester.getSemantics(target).id;
        final start = tester.getRect(target);
        await tester.pump();
        for (var frame = 0; frame < 7; frame++) {
          await tester.pump(Duration(milliseconds: 40));
          expect(tester.getSemantics(target).id, id);
          binding.expectGeometry(tester, target);
          expect(binding.hitTestWindowsSemantics(tester.getRect(target).center * ratio)?.id, id);
        }
        expect(start.top - tester.getRect(target).top, closeTo(8, .001));
        await reassembleSemantics(tester);
        binding.expectGeometry(tester, target);
      });
    }
  }

  testWidgets('纯颜色更新不提交无关语义批次', (tester) async {
    final child = ElView(child: '固定内容');
    Widget host(Color color) => Directionality(
      textDirection: .ltr,
      child: ElView(
        semantics: ElSemantics(container: true, explicitChildNodes: true),
        style: ElStyle(backgroundColor: color),
        child: child,
      ),
    );
    await tester.pumpWidget(host(Color(0xffff0000)));
    final batches = binding.batches;
    await tester.pumpWidget(host(Color(0xff0000ff)));
    expect(binding.batches, batches);
  });
}

void _registerGeometryTests(ElSemanticsTestBinding binding) {
  testWidgets('ElStyle 变换、尺寸和内边距更新同步后代语义几何', (tester) async {
    tester.view.devicePixelRatio = 1.75;
    tester.view.physicalSize = Size(600 * 1.75, 400 * 1.75);
    addTearDown(tester.view.reset);
    Widget host(double shift, double scale, double width, double padding) => Directionality(
      textDirection: .ltr,
      child: ElView(
        style: ElStyle(alignment: .topLeft),
        child: ElView(
          style: ElStyle(
            width: width,
            height: 120,
            padding: .all(padding),
            alignment: .topLeft,
            transform: ElTransform.matrix(scale, 0, 0, scale, shift, 20),
            transformOrigin: .topLeft,
          ),
          child: ElView(
            key: ValueKey('styled-child'),
            style: ElStyle(width: 60, height: 40),
            semantics: ElSemantics(container: true, label: 'styled-child'),
          ),
        ),
      ),
    );
    for (final values in [(0.0, 1.0, 120.0, 8.0), (100.0, 1.5, 180.0, 16.0), (20.0, 1.0, 120.0, 8.0)]) {
      await tester.pumpWidget(host(values.$1, values.$2, values.$3, values.$4));
      binding.expectGeometry(tester, find.byKey(ValueKey('styled-child')));
      final center = physicalSemanticsRect(tester, tester.getRect(find.byKey(ValueKey('styled-child')))).center;
      expect(binding.hitTestSemantics(center)?.label, 'styled-child');
    }
  });

  for (final ratio in [1.0, 1.75]) {
    testWidgets('盒模型平移、缩放、重建和重挂后语义几何同步 dpr=$ratio', (tester) async {
      tester.view.physicalSize = Size(600 * ratio, 400 * ratio);
      tester.view.devicePixelRatio = ratio;
      addTearDown(tester.view.reset);
      final key = GlobalKey();
      Widget host(double shift, double scale, {bool wrapped = false}) {
        final child = ElView(
          key: key,
          style: ElStyle(width: 120, height: 60, padding: .all(8)),
          semantics: ElSemantics(container: true, label: 'geometry-target'),
        );
        return Directionality(
          textDirection: .ltr,
          child: ElView(
            style: ElStyle(alignment: .topLeft),
            child: Transform(
              transform: Matrix4.identity()
                ..translateByDouble(shift, 30, 0, 1)
                ..scaleByDouble(scale, scale, 1, 1),
              child: wrapped ? RepaintBoundary(child: child) : child,
            ),
          ),
        );
      }

      await tester.pumpWidget(host(20, 1));
      final element = tester.element(find.byKey(key));
      for (final config in [(20.0, 1.0, false), (100.0, 1.0, false), (100.0, 1.5, false), (20.0, 1.0, true)]) {
        await tester.pumpWidget(host(config.$1, config.$2, wrapped: config.$3));
        binding.expectGeometry(tester, find.byKey(key));
        final center = physicalSemanticsRect(tester, tester.getRect(find.byKey(key))).center;
        expect(binding.hitTestSemantics(center)?.label, 'geometry-target');
        expect(tester.element(find.byKey(key)), same(element));
      }
      await tester.pumpWidget(Directionality(textDirection: .ltr, child: ElView()));
      expect(binding.reachableNodes.where((node) => node.label == 'geometry-target'), isEmpty);
    });
  }

  testWidgets('焦点状态、语义动作和节点卸载保持一致', (tester) async {
    final first = FocusNode();
    final second = FocusNode();
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    var taps = 0;
    Widget host({bool visible = true}) => Directionality(
      textDirection: .ltr,
      child: Row(
        children: [
          if (visible)
            ElView(
              key: ValueKey('first'),
              focusNode: first,
              style: ElStyle(width: 100, height: 50),
              semantics: ElSemantics(label: 'first', button: true, onTap: () => taps++),
            ),
          ElView(key: ValueKey('second'), focusNode: second, style: ElStyle(width: 100, height: 50), child: 'second'),
        ],
      ),
    );
    await tester.pumpWidget(host());
    first.requestFocus();
    await tester.pump();
    // 焦点变更在帧后提交，语义标记再等一帧刷新。
    await tester.pump();
    final node = tester.getSemantics(find.byKey(ValueKey('first')));
    expect(node.getSemanticsData().flagsCollection.isFocused, Tristate.isTrue);
    node.owner!.performAction(node.id, SemanticsAction.tap);
    expect(taps, 1);
    second.requestFocus();
    await tester.pump();
    await tester.pump();
    expect(node.getSemanticsData().flagsCollection.isFocused, Tristate.isFalse);
    expect(
      tester.getSemantics(find.byKey(ValueKey('second'))).getSemanticsData().flagsCollection.isFocused,
      Tristate.isTrue,
    );
    await tester.pumpWidget(host(visible: false));
    expect(binding.reachableNodes.where((node) => node.label == 'first'), isEmpty);
    expect(second.hasPrimaryFocus, isTrue);
  });

  testWidgets('排除和恢复子树后提交内容与初次构建一致', (tester) async {
    Widget host(bool exclude) => Directionality(
      textDirection: .ltr,
      child: ElView(
        semantics: ElSemantics(exclude: exclude),
        child: ElView(key: ValueKey('leaf'), style: ElStyle(width: 100, height: 50), child: 'visible-leaf'),
      ),
    );
    await tester.pumpWidget(host(false));
    final original = binding.reachableNodes.singleWhere((node) => node.label == 'visible-leaf');
    final rect = binding.submittedRect(original.id);
    await tester.pumpWidget(host(true));
    expect(binding.reachableNodes.where((node) => node.label == 'visible-leaf'), isEmpty);
    await tester.pumpWidget(host(false));
    final restored = binding.reachableNodes.singleWhere((node) => node.label == 'visible-leaf');
    expectSemanticsRect(binding.submittedRect(restored.id), rect);
  });
}

void _registerBasicTests() {
  Widget shell(Widget child) => MaterialApp(
    home: Align(
      alignment: .topLeft,
      child: ConstrainedBox(constraints: BoxConstraints(maxWidth: 400, maxHeight: 400), child: child),
    ),
  );

  testWidgets('ElView exposes explicit semantics role label hint and actions', (tester) async {
    const hostKey = ValueKey<String>('semantic-button');
    var taps = 0;
    var longPresses = 0;

    await tester.pumpWidget(
      shell(
        ElView(
          key: hostKey,
          semantics: ElSemantics(
            label: 'Save',
            hint: 'Stores current changes',
            button: true,
            enabled: true,
            onTap: () => taps++,
            onLongPress: () => longPresses++,
          ),
          child: 'visual label',
        ),
      ),
    );

    final semantics = tester.ensureSemantics();
    try {
      final node = tester.getSemantics(find.byKey(hostKey));
      expect(
        node,
        matchesSemantics(
          label: 'Save',
          hint: 'Stores current changes',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
          hasLongPressAction: true,
        ),
      );

      node.owner!.performAction(node.id, SemanticsAction.tap);
      node.owner!.performAction(node.id, SemanticsAction.longPress);

      expect(taps, 1);
      expect(longPresses, 1);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('ElView exposes disabled and checked semantics state', (tester) async {
    const hostKey = ValueKey<String>('semantic-checkbox');

    await tester.pumpWidget(
      shell(
        ElView(
          key: hostKey,
          semantics: ElSemantics(label: 'Accept terms', enabled: false, checked: true),
          child: 'Accept',
        ),
      ),
    );

    final semantics = tester.ensureSemantics();
    try {
      expect(
        tester.getSemantics(find.byKey(hostKey)),
        matchesSemantics(label: 'Accept terms', hasEnabledState: true, hasCheckedState: true, isChecked: true),
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('ElView forwards Flutter structural semantics role', (tester) async {
    const hostKey = ValueKey<String>('semantic-dialog');

    await tester.pumpWidget(
      shell(
        ElView(
          key: hostKey,
          semantics: ElSemantics(label: 'Confirm', role: .dialog),
          child: 'Confirm',
        ),
      ),
    );

    final semantics = tester.ensureSemantics();
    try {
      final node = tester.getSemantics(find.byKey(hostKey));
      expect(node, matchesSemantics(label: 'Confirm'));
      expect(node.getSemanticsData().role, SemanticsRole.dialog);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('ElSemantics without label keeps default text label from child', (tester) async {
    const hostKey = ValueKey<String>('semantic-text-default');

    await tester.pumpWidget(shell(ElView(key: hostKey, semantics: ElSemantics(button: true), child: 'Buy now')));

    final semantics = tester.ensureSemantics();
    try {
      expect(tester.getSemantics(find.byKey(hostKey)), matchesSemantics(label: 'Buy now', isButton: true));
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('explicit properties override default text label', (tester) async {
    const hostKey = ValueKey<String>('semantic-text-override');

    await tester.pumpWidget(
      shell(
        ElView(
          key: hostKey,
          semantics: ElSemantics(properties: SemanticsProperties(label: 'Spoken')),
          child: 'painted',
        ),
      ),
    );

    final semantics = tester.ensureSemantics();
    try {
      expect(tester.getSemantics(find.byKey(hostKey)), matchesSemantics(label: 'Spoken'));
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('attributedLabel wins over default text label', (tester) async {
    const hostKey = ValueKey<String>('semantic-attributed');

    await tester.pumpWidget(
      shell(
        ElView(
          key: hostKey,
          semantics: ElSemantics(
            properties: SemanticsProperties(attributedLabel: AttributedString('Attributed spoken')),
          ),
          child: 'painted',
        ),
      ),
    );

    final semantics = tester.ensureSemantics();
    try {
      final node = tester.getSemantics(find.byKey(hostKey));
      expect(node.getSemanticsData().attributedLabel.string, 'Attributed spoken');
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('explicit focused property is reported to semantics', (tester) async {
    const hostKey = ValueKey<String>('semantic-focused');

    await tester.pumpWidget(
      shell(
        ElView(
          key: hostKey,
          semantics: ElSemantics(properties: SemanticsProperties(label: 'field', focused: true)),
          child: 'field',
        ),
      ),
    );

    final semantics = tester.ensureSemantics();
    try {
      expect(
        tester.getSemantics(find.byKey(hostKey)),
        matchesSemantics(label: 'field', isFocused: true, isFocusable: true),
      );
    } finally {
      semantics.dispose();
    }
  });

  test('convenience params and properties are mutually exclusive', () {
    expect(
      () => ElSemantics(
        label: 'x',
        properties: SemanticsProperties(hint: 'y'),
      ),
      throwsA(isA<AssertionError>()),
    );
  });
}

void _registerTreeTests() {
  Widget shell(Widget child) => MaterialApp(
    home: Align(
      alignment: .topLeft,
      child: ConstrainedBox(constraints: BoxConstraints(maxWidth: 400, maxHeight: 400), child: child),
    ),
  );

  testWidgets('exclude drops own text and child semantics from the tree', (tester) async {
    await tester.pumpWidget(
      shell(
        ElView(
          style: ElStyle(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElView(
                semantics: ElSemantics(exclude: true),
                child: Semantics(label: 'hidden widget child', child: SizedBox(width: 10, height: 10)),
              ),
              ElView(semantics: ElSemantics(exclude: true), child: 'hidden text'),
              ElView(child: 'visible text'),
            ],
          ),
        ),
      ),
    );

    final semantics = tester.ensureSemantics();
    try {
      expect(find.semantics.byLabel('hidden widget child'), findsNothing);
      expect(find.semantics.byLabel('hidden text'), findsNothing);
      expect(find.semantics.byLabel('visible text'), findsOne);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('exclude update immediately removes an existing semantic subtree', (tester) async {
    var excluded = false;
    late StateSetter update;
    // 壳节点：自身不可聚焦、不暴露焦点语义，按 excluded 动态挡住后代焦点。
    final blocker = FocusNode(canRequestFocus: false, descendantsAreFocusable: true, descendantsAreTraversable: true);
    addTearDown(blocker.dispose);
    await tester.pumpWidget(
      shell(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            blocker
              ..descendantsAreFocusable = !excluded
              ..descendantsAreTraversable = !excluded;
            return ElView(
              semantics: excluded
                  ? ElSemantics(container: true, blockUserActions: true)
                  : ElSemantics(
                      container: true,
                      properties: const SemanticsProperties(role: SemanticsRole.status, label: 'dynamic semantic root'),
                    ),
              child: ElView(
                semantics: excluded ? ElSemantics(exclude: true) : null,
                focusNode: blocker,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElButtonView(
                      semanticLabel: 'dynamic semantic child',
                      style: const ElStyle(width: 80, height: 32),
                      child: 'action',
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );

    final semantics = tester.ensureSemantics();
    try {
      expect(find.semantics.byLabel('dynamic semantic child'), findsOne);
      update(() => excluded = true);
      await tester.pump();
      expect(find.semantics.byLabel('dynamic semantic child'), findsNothing);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('container creates a dedicated node that children do not leak past', (tester) async {
    const hostKey = ValueKey<String>('semantic-container');

    await tester.pumpWidget(
      shell(
        ElView(
          key: hostKey,
          semantics: ElSemantics(container: true),
          child: ElView(child: 'inner text'),
        ),
      ),
    );

    final semantics = tester.ensureSemantics();
    try {
      // container 节点自身成为独立 boundary node；inner text 语义保留在其子树内。
      final node = tester.getSemantics(find.byKey(hostKey));
      expect(node.label, isEmpty);
      expect(find.semantics.byLabel('inner text'), findsOne);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('explicitChildNodes keeps children as separate semantic nodes', (tester) async {
    const hostKey = ValueKey<String>('semantic-explicit');

    await tester.pumpWidget(
      shell(
        ElView(
          key: hostKey,
          semantics: ElSemantics(container: true, explicitChildNodes: true),
          style: ElStyle(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElView(
                semantics: ElSemantics(label: 'first'),
                child: SizedBox(width: 10, height: 10),
              ),
              ElView(
                semantics: ElSemantics(label: 'second'),
                child: SizedBox(width: 10, height: 10),
              ),
            ],
          ),
        ),
      ),
    );

    final semantics = tester.ensureSemantics();
    try {
      final node = tester.getSemantics(find.byKey(hostKey));
      expect(node.label, isEmpty);
      final childLabels = <String>[];
      node.visitChildren((child) {
        childLabels.add(child.label);
        return true;
      });
      expect(childLabels, <String>['first', 'second']);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('mergeDescendants merges child semantics into one node', (tester) async {
    const hostKey = ValueKey<String>('semantic-merge');
    var taps = 0;

    await tester.pumpWidget(
      shell(
        ElView(
          key: hostKey,
          semantics: ElSemantics(mergeDescendants: true, button: true, onTap: () => taps++),
          style: ElStyle(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElView(child: 'icon glyph'),
              ElView(
                semantics: ElSemantics(properties: SemanticsProperties(checked: true)),
                child: 'Accept',
              ),
            ],
          ),
        ),
      ),
    );

    final semantics = tester.ensureSemantics();
    try {
      final node = tester.getSemantics(find.byKey(hostKey));
      // label 合并由 Flutter pipeline 完成：两个子节点 label 以 \n 连接。
      expect(
        node,
        matchesSemantics(
          label: 'icon glyph\nAccept',
          isButton: true,
          hasCheckedState: true,
          isChecked: true,
          hasTapAction: true,
        ),
      );
      node.owner!.performAction(node.id, SemanticsAction.tap);
      expect(taps, 1);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('blockPreviousSemantics drops earlier painted siblings', (tester) async {
    await tester.pumpWidget(
      shell(
        ElView(
          style: ElStyle(),
          child: Stack(
            children: [
              ElView(child: 'behind content'),
              ElView(
                semantics: ElSemantics(blockPreviousSemantics: true, label: 'modal scrim'),
                child: SizedBox.expand(),
              ),
            ],
          ),
        ),
      ),
    );

    final semantics = tester.ensureSemantics();
    try {
      expect(find.semantics.byLabel('behind content'), findsNothing);
      expect(find.semantics.byLabel('modal scrim'), findsOne);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('blockUserActions keeps label but blocks pointer actions', (tester) async {
    const hostKey = ValueKey<String>('semantic-block-actions');
    var taps = 0;

    await tester.pumpWidget(
      shell(
        ElView(
          key: hostKey,
          semantics: ElSemantics(blockUserActions: true, label: 'locked', onTap: () => taps++),
          child: 'locked',
        ),
      ),
    );

    final semantics = tester.ensureSemantics();
    try {
      final node = tester.getSemantics(find.byKey(hostKey));
      expect(node.label, 'locked');
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
      expect(taps, 0);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('indexInParent is reported on node data', (tester) async {
    const hostKey = ValueKey<String>('semantic-indexed');

    await tester.pumpWidget(
      shell(
        ElView(
          key: hostKey,
          semantics: ElSemantics(indexInParent: 4, label: 'row item'),
          child: 'row item',
        ),
      ),
    );

    final semantics = tester.ensureSemantics();
    try {
      final node = tester.getSemantics(find.byKey(hostKey));
      expect(node.indexInParent, 4);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('sortKey orders semantic children', (tester) async {
    const hostKey = ValueKey<String>('semantic-sorted');

    await tester.pumpWidget(
      shell(
        ElView(
          key: hostKey,
          semantics: ElSemantics(container: true, explicitChildNodes: true),
          style: ElStyle(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElView(
                semantics: ElSemantics(
                  properties: SemanticsProperties(label: 'painted first', sortKey: OrdinalSortKey(2)),
                ),
                child: SizedBox(width: 10, height: 10),
              ),
              ElView(
                semantics: ElSemantics(
                  properties: SemanticsProperties(label: 'painted second', sortKey: OrdinalSortKey(1)),
                ),
                child: SizedBox(width: 10, height: 10),
              ),
            ],
          ),
        ),
      ),
    );

    final semantics = tester.ensureSemantics();
    try {
      final node = tester.getSemantics(find.byKey(hostKey));
      final ordered = node
          .debugListChildrenInOrder(DebugSemanticsDumpOrder.traversalOrder)
          .map((child) => child.label)
          .toList();
      // traversal 顺序按 sortKey：ordinal 1 在前。
      expect(ordered, <String>['painted second', 'painted first']);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('localeForSubtree flows into descendant semantics', (tester) async {
    const hostKey = ValueKey<String>('semantic-locale');

    await tester.pumpWidget(
      shell(
        ElView(
          key: hostKey,
          semantics: ElSemantics(container: true, localeForSubtree: Locale('ja', 'JP'), label: 'こんにちは'),
          child: 'こんにちは',
        ),
      ),
    );

    final semantics = tester.ensureSemantics();
    try {
      final node = tester.getSemantics(find.byKey(hostKey));
      expect(node.getSemanticsData().locale, Locale('ja', 'JP'));
    } finally {
      semantics.dispose();
    }
  });
}

void _registerPropertyTests() {
  Widget shell(Widget child) => MaterialApp(
    home: Align(
      alignment: .topLeft,
      child: ConstrainedBox(constraints: BoxConstraints(maxWidth: 400, maxHeight: 400), child: child),
    ),
  );

  testWidgets('textField group: readOnly obscured multiline lengths and text actions', (tester) async {
    const hostKey = ValueKey<String>('semantic-textfield');
    String? typed;
    TextSelection? selected;

    await tester.pumpWidget(
      shell(
        ElView(
          key: hostKey,
          semantics: ElSemantics(
            properties: SemanticsProperties(
              label: 'Password',
              value: 'secret',
              textField: true,
              readOnly: false,
              obscured: true,
              multiline: false,
              maxValueLength: 12,
              currentValueLength: 6,
              onSetText: (text) => typed = text,
              onSetSelection: (selection) => selected = selection,
            ),
          ),
          child: 'field',
        ),
      ),
    );

    final semantics = tester.ensureSemantics();
    try {
      final node = tester.getSemantics(find.byKey(hostKey));
      expect(
        node,
        matchesSemantics(
          label: 'Password',
          value: 'secret',
          isTextField: true,
          isObscured: true,
          maxValueLength: 12,
          currentValueLength: 6,
          hasSetTextAction: true,
          hasSetSelectionAction: true,
        ),
      );

      node.owner!.performAction(node.id, SemanticsAction.setText, 'hello');
      expect(typed, 'hello');
      node.owner!.performAction(node.id, SemanticsAction.setSelection, <String, int>{'base': 1, 'extent': 3});
      expect(selected, TextSelection(baseOffset: 1, extentOffset: 3));
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('slider group: value endpoints and increase/decrease actions', (tester) async {
    const hostKey = ValueKey<String>('semantic-slider');
    var increases = 0;
    var decreases = 0;

    await tester.pumpWidget(
      shell(
        ElView(
          key: hostKey,
          semantics: ElSemantics(
            properties: SemanticsProperties(
              label: 'Volume',
              value: '50',
              increasedValue: '55',
              decreasedValue: '45',
              slider: true,
              minValue: '0',
              maxValue: '100',
              onIncrease: () => increases++,
              onDecrease: () => decreases++,
            ),
          ),
          child: 'slider',
        ),
      ),
    );

    final semantics = tester.ensureSemantics();
    try {
      final node = tester.getSemantics(find.byKey(hostKey));
      expect(
        node,
        matchesSemantics(
          label: 'Volume',
          value: '50',
          increasedValue: '55',
          decreasedValue: '45',
          isSlider: true,
          minValue: '0',
          maxValue: '100',
          hasIncreaseAction: true,
          hasDecreaseAction: true,
        ),
      );

      node.owner!.performAction(node.id, SemanticsAction.increase);
      node.owner!.performAction(node.id, SemanticsAction.decrease);
      expect(increases, 1);
      expect(decreases, 1);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('route/live group: scopesRoute namesRoute liveRegion', (tester) async {
    const routeKey = ValueKey<String>('semantic-route');
    const liveKey = ValueKey<String>('semantic-live');

    await tester.pumpWidget(
      shell(
        ElView(
          style: ElStyle(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElView(
                key: routeKey,
                semantics: ElSemantics(explicitChildNodes: true, properties: SemanticsProperties(scopesRoute: true)),
                child: ElView(
                  semantics: ElSemantics(properties: SemanticsProperties(label: 'Dialog title', namesRoute: true)),
                  child: 'Dialog title',
                ),
              ),
              ElView(
                key: liveKey,
                semantics: ElSemantics(properties: SemanticsProperties(label: 'status', liveRegion: true)),
                child: 'status',
              ),
            ],
          ),
        ),
      ),
    );

    final semantics = tester.ensureSemantics();
    try {
      final routeNode = tester.getSemantics(find.byKey(routeKey));
      expect(
        routeNode,
        matchesSemantics(
          scopesRoute: true,
          children: <Matcher>[matchesSemantics(label: 'Dialog title', namesRoute: true)],
        ),
      );
      expect(tester.getSemantics(find.byKey(liveKey)), matchesSemantics(label: 'status', isLiveRegion: true));
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('web/form group: identifier isRequired validationResult inputType controlsNodes', (tester) async {
    const hostKey = ValueKey<String>('semantic-form');

    await tester.pumpWidget(
      shell(
        ElView(
          key: hostKey,
          semantics: ElSemantics(
            properties: SemanticsProperties(
              label: 'Email',
              textField: true,
              identifier: 'email-input',
              isRequired: true,
              validationResult: .invalid,
              inputType: .email,
              controlsNodes: <String>{'suggestions-popup'},
            ),
          ),
          child: 'email',
        ),
      ),
    );

    final semantics = tester.ensureSemantics();
    try {
      final node = tester.getSemantics(find.byKey(hostKey));
      final data = node.getSemanticsData();
      expect(data.identifier, 'email-input');
      expect(
        node,
        matchesSemantics(
          label: 'Email',
          isTextField: true,
          hasRequiredState: true,
          isRequired: true,
          validationResult: .invalid,
        ),
      );
      expect(data.validationResult, SemanticsValidationResult.invalid);
      expect(data.inputType, SemanticsInputType.email);
      expect(data.controlsNodes, <String>{'suggestions-popup'});
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('actions group: scroll dismiss copy cut paste expand focus a11y-focus', (tester) async {
    const hostKey = ValueKey<String>('semantic-actions');
    final calls = <String>[];

    await tester.pumpWidget(
      shell(
        ElView(
          key: hostKey,
          semantics: ElSemantics(
            properties: SemanticsProperties(
              label: 'panel',
              expanded: false,
              onScrollLeft: () => calls.add('scrollLeft'),
              onScrollUp: () => calls.add('scrollUp'),
              onDismiss: () => calls.add('dismiss'),
              onCopy: () => calls.add('copy'),
              onCut: () => calls.add('cut'),
              onPaste: () => calls.add('paste'),
              onExpand: () => calls.add('expand'),
              onFocus: () => calls.add('focus'),
              onDidGainAccessibilityFocus: () => calls.add('gainA11y'),
              onDidLoseAccessibilityFocus: () => calls.add('loseA11y'),
            ),
          ),
          child: 'panel',
        ),
      ),
    );

    final semantics = tester.ensureSemantics();
    try {
      final node = tester.getSemantics(find.byKey(hostKey));
      expect(
        node,
        matchesSemantics(
          label: 'panel',
          hasExpandedState: true,
          hasScrollLeftAction: true,
          hasScrollUpAction: true,
          hasDismissAction: true,
          hasCopyAction: true,
          hasCutAction: true,
          hasPasteAction: true,
          hasFocusAction: true,
          hasDidGainAccessibilityFocusAction: true,
          hasDidLoseAccessibilityFocusAction: true,
        ),
      );

      final owner = node.owner!;
      owner.performAction(node.id, SemanticsAction.scrollLeft);
      owner.performAction(node.id, SemanticsAction.scrollUp);
      owner.performAction(node.id, SemanticsAction.dismiss);
      owner.performAction(node.id, SemanticsAction.copy);
      owner.performAction(node.id, SemanticsAction.cut);
      owner.performAction(node.id, SemanticsAction.paste);
      owner.performAction(node.id, SemanticsAction.expand);
      owner.performAction(node.id, SemanticsAction.focus);
      owner.performAction(node.id, SemanticsAction.didGainAccessibilityFocus);
      owner.performAction(node.id, SemanticsAction.didLoseAccessibilityFocus);
      expect(calls, <String>[
        'scrollLeft',
        'scrollUp',
        'dismiss',
        'copy',
        'cut',
        'paste',
        'expand',
        'focus',
        'gainA11y',
        'loseA11y',
      ]);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('custom semantics actions and hintOverrides', (tester) async {
    const hostKey = ValueKey<String>('semantic-custom');
    var archived = 0;
    final archive = CustomSemanticsAction(label: 'Archive');

    await tester.pumpWidget(
      shell(
        ElView(
          key: hostKey,
          semantics: ElSemantics(
            properties: SemanticsProperties(
              label: 'mail',
              customSemanticsActions: <CustomSemanticsAction, VoidCallback>{archive: () => archived++},
              hintOverrides: SemanticsHintOverrides(onTapHint: 'open mail'),
            ),
          ),
          child: 'mail',
        ),
      ),
    );

    final semantics = tester.ensureSemantics();
    try {
      final node = tester.getSemantics(find.byKey(hostKey));
      expect(
        node,
        matchesSemantics(label: 'mail', customActions: <CustomSemanticsAction>[archive], onTapHint: 'open mail'),
      );
      expect(node.getSemanticsData().customSemanticsActionIds, contains(CustomSemanticsAction.getIdentifier(archive)));

      node.owner!.performAction(node.id, SemanticsAction.customAction, CustomSemanticsAction.getIdentifier(archive));
      expect(archived, 1);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('heading and link metadata map into node data', (tester) async {
    const hostKey = ValueKey<String>('semantic-heading-link');

    await tester.pumpWidget(
      shell(
        ElView(
          key: hostKey,
          semantics: ElSemantics(
            properties: SemanticsProperties(
              label: 'Docs',
              header: true,
              headingLevel: 2,
              link: true,
              linkUrl: Uri.parse('https://example.com/docs'),
            ),
          ),
          child: 'Docs',
        ),
      ),
    );

    final semantics = tester.ensureSemantics();
    try {
      final node = tester.getSemantics(find.byKey(hostKey));
      expect(node, matchesSemantics(label: 'Docs', isHeader: true, isLink: true));
      final data = node.getSemanticsData();
      expect(data.headingLevel, 2);
      expect(data.linkUrl, Uri.parse('https://example.com/docs'));
    } finally {
      semantics.dispose();
    }
  });
}

// GlobalKey 重挂带文本子树 × 语义激活 —— ElRenderView owner 绑定回归。
//
// 真机现场（Android 预测性返回，路由过渡包装变化触发 GlobalKey retake）：
// 子树整体 move 只走 detach→attach，ElRenderView ↔ ElRenderView 的 parent
// 链不断；Flutter 3.44 `RenderObject.attach` 在语义激活时急切触发
// markNeedsSemanticsUpdate → describeSemanticsConfiguration。attach 级联
// 自顶向下：父 ElRenderView attach 时读 _textChild.semanticsTextLabel →
// committedResolvedStyle，此刻 ElRenderView 尚未 attach。若 detach 曾无条件清
// _ownerView，这里就炸 "committedResolvedStyle requires attached owner"，随后
// attach 级联中断 → 回声 "'child._parent == this': is not true"。
//
// 修复：detach 只在 parent == null（真正被 dropChild 移除）时清 _ownerView，
// 纯 move 保留绑定。

void _registerReattachTests() {
  testWidgets('GlobalKey 重挂带文本子树（语义激活）不抛 owner 断言', (tester) async {
    final semantics = tester.ensureSemantics();
    final subtreeKey = GlobalKey();
    const textKey = ValueKey<String>('inner-text');

    // 嵌套 ElView，内层持文本载荷（挂 ElRenderView）——
    // 外层 attach 期的语义重算会经 _textChild.semanticsTextLabel 读
    // committedResolvedStyle。
    Widget subtree() => ElView(
      key: subtreeKey,
      style: ElStyle(padding: EdgeInsets.all(8)),
      child: ElView(key: textKey, style: ElStyle(fontSize: 14), child: 'hello semantics'),
    );

    Widget host({required bool wrapped}) => MaterialApp(
      home: Scaffold(
        // 换一层包装 → 结构差异迫使 GlobalKey 子树 deactivate → retake →
        // 整体 move（detach→attach，内部 parent 链不断）。
        body: wrapped
            ? Center(
                child: Padding(padding: EdgeInsets.all(4), child: subtree()),
              )
            : Align(alignment: .topLeft, child: subtree()),
      ),
    );

    try {
      await tester.pumpWidget(host(wrapped: false));
      expect(tester.takeException(), isNull);

      // 关键前置：文本宿主 ElRenderView 的语义 config 缓存必须为空（真机上
      // 来自路由过渡期的语义失效——markNeedsUpdate/clearSemantics 均会清缓存；
      // 框架在语义 owner 重连、BlockSemantics 变化等场景递归调 clearSemantics）。
      // 随后 GlobalKey retake 整体 move：detach→attach（RTV.parent 链不断），
      // Flutter 3.44 `RenderObject.attach` 评估 `configProvider.effective` 时
      // 惰性重跑 describeSemanticsConfiguration → 读 _textChild
      // .semanticsTextLabel → committedResolvedStyle，此刻 ElRenderView 尚未
      // attach。旧代码 detach 无条件清 _ownerView → 抛
      // "committedResolvedStyle requires attached owner"。
      tester.renderObject(find.byKey(textKey)).clearSemantics();
      await tester.pumpWidget(host(wrapped: true));
      expect(tester.takeException(), isNull, reason: '重挂 #1 不应抛 owner 断言');
      tester.renderObject(find.byKey(textKey)).clearSemantics();
      await tester.pumpWidget(host(wrapped: false));
      expect(tester.takeException(), isNull, reason: '重挂 #2 不应抛 owner 断言');

      // 树健康：文本语义仍在（ElView 文本走自绘，find.text 不可见，
      // 经 semantics label 断言）。
      await tester.pump();
      final node = tester.getSemantics(find.byKey(textKey));
      expect(node.label, contains('hello semantics'));
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('真正移除文本子树后 owner 绑定清空，重新挂载可重绑', (tester) async {
    // 覆盖 detach 收窄后的另一半：dropChild 路径（parent 置 null）仍要清绑定，
    // 新宿主 attach 时经 _bindOwnerView 重绑。
    const hostKey = ValueKey<String>('transient-host');
    Widget host({required bool showText}) => MaterialApp(
      home: Align(
        alignment: .topLeft,
        child: ElView(
          key: hostKey,
          style: ElStyle(padding: EdgeInsets.all(8)),
          child: showText ? 'transient text' : null,
        ),
      ),
    );

    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(host(showText: true));
      expect(tester.getSemantics(find.byKey(hostKey)).label, contains('transient text'));

      await tester.pumpWidget(host(showText: false));
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(host(showText: true));
      expect(tester.takeException(), isNull);
      expect(tester.getSemantics(find.byKey(hostKey)).label, contains('transient text'));
    } finally {
      semantics.dispose();
    }
  });
}
