import 'dart:ui' show SemanticsRole;

import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {bool reduced = true}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduced),
    child: ElMobileTheme(
      child: Align(
        alignment: .topLeft,
        child: SizedBox(width: 320, child: child),
      ),
    ),
  ),
);

Finder _views(bool Function(ElView view) predicate) =>
    find.byWidgetPredicate((widget) => widget is ElView && predicate(widget));

void main() {
  testWidgets('公共加载指示使用数值尺寸并保留加载语义及可见说明', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      final key = ValueKey('loading');
      await tester.pumpWidget(
        _host(ElLoadingIndicator(key: key, size: 30, semanticLabel: '同步中', style: ElStyle(opacity: .4))),
      );
      await tester.pumpAndSettle();
      final data = tester.getSemantics(find.byKey(key)).getSemanticsData();
      expect(data.role, SemanticsRole.loadingSpinner);
      expect(data.label, '同步中');
      final frame = _views((view) => view.style?.width == 30 && view.style?.height == 30);
      expect(tester.getSize(frame), Size.square(30));
      expect(_views((view) => view.style?.opacity == .4), findsOneWidget);

      await tester.pumpWidget(_host(ElLoadingIndicator(child: Text('正在处理'))));
      await tester.pumpAndSettle();
      expect(find.text('正在处理'), findsOneWidget);
      expect(tester.getSemantics(find.text('正在处理')).label, '正在处理');
      expect(find.bySemanticsLabel('加载中'), findsNothing);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('公共进度按完成量与总量归一化，缓冲量不小于当前完成量', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      ElProgressValue? snapshot;
      final key = ValueKey('progress');
      Widget progress(double value, double buffer, double max) => _host(
        ElProgress(
          key: key,
          value: value,
          buffer: buffer,
          max: max,
          semanticLabel: '下载进度',
          textBuilder: (context, current) {
            snapshot = current;
            return Text('${current.value}/${current.max}');
          },
        ),
      );
      await tester.pumpWidget(progress(30, 10, 60));
      await tester.pumpAndSettle();
      expect(snapshot!.value, 30);
      expect(snapshot!.max, 60);
      expect(snapshot!.percentage, 50);
      var data = tester.getSemantics(find.byKey(key)).getSemanticsData();
      expect(data.role, SemanticsRole.progressBar);
      expect(data.value, '50%');
      expect(data.hint, '已缓冲 50%');
      expect(find.text('30.0/60.0'), findsOneWidget);

      await tester.pumpWidget(progress(200, 300, double.nan));
      await tester.pumpAndSettle();
      expect(snapshot!.value, 100);
      expect(snapshot!.max, 100);
      data = tester.getSemantics(find.byKey(key)).getSemanticsData();
      expect(data.value, '100%');
      expect(data.hint, '已缓冲 100%');

      await tester.pumpWidget(progress(-10, -20, 60));
      await tester.pumpAndSettle();
      expect(snapshot!.value, 0);
      expect(snapshot!.percentage, 0);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('公共圆环使用根样式宽高，自定义读数可隐藏后保持实例', (tester) async {
    final readoutKey = GlobalKey();
    final child = SizedBox(key: readoutKey, width: 16, height: 10, child: Text('读数'));
    Widget progress(bool showText) => _host(
      ElProgress.circle(
        value: 25,
        style: ElStyle(width: 80, height: 64),
        showText: showText,
        textBuilder: (_, _) => child,
      ),
    );
    await tester.pumpWidget(progress(true));
    await tester.pumpAndSettle();
    final element = tester.element(find.byKey(readoutKey));
    final paint = find.descendant(of: find.byType(ElProgress), matching: find.byType(CustomPaint));
    expect(paint, findsOneWidget);
    expect(tester.getSize(paint), Size(80, 64));
    await tester.pumpWidget(progress(false));
    await tester.pumpAndSettle();
    expect(find.byKey(readoutKey), findsNothing);
    expect(tester.element(find.byKey(readoutKey, skipOffstage: false)), same(element));
    await tester.pumpWidget(progress(true));
    await tester.pumpAndSettle();
    expect(tester.element(find.byKey(readoutKey)), same(element));
  });

  testWidgets('不确定进度提供进行中语义并响应减少动画设置', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      final key = ValueKey('progress');
      Widget progress(bool reduced) => _host(
        ElProgress(key: key, value: double.infinity),
        reduced: reduced,
      );
      await tester.pumpWidget(progress(false));
      await tester.pump(Duration(milliseconds: 250));
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      var data = tester.getSemantics(find.byKey(key)).getSemanticsData();
      expect(data.role, SemanticsRole.loadingSpinner);
      expect(data.value, '进行中');
      await tester.pumpWidget(progress(true));
      await tester.pumpAndSettle();
      data = tester.getSemantics(find.byKey(key)).getSemanticsData();
      expect(data.value, '进行中');
      expect(tester.binding.transientCallbackCount, 0);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('公共骨架按Web规则限制行数并应用根样式', (tester) async {
    for (final entry in {0: 3, double.nan: 3, 99: 10, -2: 1}.entries) {
      await tester.pumpWidget(_host(ElSkeleton(rows: entry.key, style: ElStyle(opacity: .5), semanticLabel: '列表加载中')));
      await tester.pumpAndSettle();
      expect(_views((view) => view.style?.height == 13), findsNWidgets(entry.value));
      expect(_views((view) => view.style?.opacity == .5), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('公共骨架切换加载时保留正文State并暂停焦点与语义', (tester) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    final childKey = GlobalKey<_CounterState>();
    final child = _Counter(key: childKey, focusNode: focus);
    Widget skeleton(bool loading) => _host(ElSkeleton(loading: loading, child: child));
    await tester.pumpWidget(skeleton(false));
    await tester.pumpAndSettle();
    await tester.tap(find.text('正文 0'));
    await tester.pumpAndSettle();
    final state = childKey.currentState;
    expect(find.text('正文 1'), findsOneWidget);
    focus.requestFocus();
    await tester.pump();
    expect(focus.hasPrimaryFocus, isTrue);

    await tester.pumpWidget(skeleton(true));
    await tester.pumpAndSettle();
    expect(childKey.currentState, same(state));
    expect(find.text('正文 1'), findsNothing);
    expect(focus.canRequestFocus, isFalse);
    expect(focus.hasFocus, isFalse);

    await tester.pumpWidget(skeleton(false));
    await tester.pumpAndSettle();
    expect(childKey.currentState, same(state));
    expect(find.text('正文 1'), findsOneWidget);
    expect(focus.canRequestFocus, isTrue);
  });
}

class _Counter extends StatefulWidget {
  const _Counter({super.key, required this.focusNode});

  final FocusNode focusNode;

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  var count = 0;

  @override
  Widget build(BuildContext context) =>
      TextButton(focusNode: widget.focusNode, onPressed: () => setState(() => count++), child: Text('正文 $count'));
}
