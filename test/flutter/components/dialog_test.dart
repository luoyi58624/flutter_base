import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_base/desktop.dart';
import 'package:flutter_base/mobile.dart' show ElMobileExt;
import 'package:flutter_base/src/flutter/widgets/popup/modal_layer.dart' show ModalLayer;
import 'package:flutter_test/flutter_test.dart';

Widget _app(ElComponents components, void Function(BuildContext context) capture) => MaterialApp(
  builder: (context, child) => ElComponentProvider(components: components, child: child!),
  home: Scaffold(
    body: Builder(
      builder: (context) {
        capture(context);
        return SizedBox.expand();
      },
    ),
  ),
);

Finder _copy(String text) =>
    find.byWidgetPredicate((w) => w is Text && w.data == text || w is ElView && w.child == text);

Finder _button(String label) => find.byWidgetPredicate((w) => w is ElButton && w.child == label);

// 品牌面板是组件下的第一个 ElView，遮罩不含 ElView。
Finder _panel(Type type) => find.descendant(of: find.byType(type), matching: find.byType(ElView)).first;

/// 打开弹层并把结果记到 [results]，不在测试里等待 Future，避免结果缺失时卡住。
Future<void> _open<T>(WidgetTester tester, Future<T> future, List<Object?> results) async {
  future.then(results.add);
  await tester.pumpAndSettle();
}

void main() {
  for (final (brand, components) in [('桌面', el.desktopComponents), ('移动', el.mobileComponents)]) {
    group('$brand品牌', () {
      testWidgets('confirm 确认得到 true，取消、遮罩和 Esc 得到 false', (tester) async {
        late BuildContext source;
        await tester.pumpWidget(_app(components, (c) => source = c));
        final results = <Object?>[];

        Future<void> confirm() => _open(tester, el.dialog.confirm(source, title: '删除文件', content: '删除后无法恢复'), results);

        await confirm();
        expect(_copy('删除文件'), findsOneWidget);
        expect(_copy('删除后无法恢复'), findsOneWidget);
        await tester.tap(_button('确定'));
        await tester.pumpAndSettle();
        expect(find.byType(ElDialog), findsNothing);

        await confirm();
        await tester.tap(_button('取消'));
        await tester.pumpAndSettle();

        await confirm();
        await tester.tapAt(Offset(4, 4));
        await tester.pumpAndSettle();

        await confirm();
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.byType(ElDialog), findsNothing);
        expect(results, [true, false, false, false]);
      });

      testWidgets('alert 只有确认按钮，确认后完成', (tester) async {
        late BuildContext source;
        await tester.pumpWidget(_app(components, (c) => source = c));
        final results = <Object?>[];
        await _open(tester, el.dialog.alert(source, content: '已同步', confirmText: '知道了'), results);
        expect(_button('取消'), findsNothing);
        await tester.tap(_button('知道了'));
        await tester.pumpAndSettle();
        expect(results, hasLength(1));
        expect(find.byType(ElDialog), findsNothing);
      });

      testWidgets('prompt 校验失败留在面板内提示，修改后清除提示，回车提交，取消得到 null', (tester) async {
        late BuildContext source;
        await tester.pumpWidget(_app(components, (c) => source = c));
        final results = <Object?>[];
        Future<String?> prompt() => el.dialog.prompt(
          source,
          title: '重命名',
          value: '旧名称',
          placeholder: '输入名称',
          validator: (value) => value.trim().isEmpty ? '名称不能为空' : null,
        );

        await _open(tester, prompt(), results);
        tester.testTextInput.enterText('  ');
        await tester.pump();
        await tester.tap(_button('确定'));
        await tester.pumpAndSettle();
        expect(_copy('名称不能为空'), findsOneWidget);
        expect(find.byType(ElDialog), findsOneWidget);
        expect(results, isEmpty);

        // 桌面点击确认会取走焦点，校验失败后焦点回到输入框，可以直接继续输入。
        expect(tester.testTextInput.hasAnyClients, isTrue);
        tester.testTextInput.enterText('新名称');
        await tester.pump();
        expect(_copy('名称不能为空'), findsNothing);
        await tester.testTextInput.receiveAction(.done);
        await tester.pumpAndSettle();
        expect(find.byType(ElDialog), findsNothing);

        await _open(tester, prompt(), results);
        await tester.tap(_button('确定'));
        await tester.pumpAndSettle();

        await _open(tester, prompt(), results);
        await tester.tap(_button('取消'));
        await tester.pumpAndSettle();
        expect(results, ['新名称', '旧名称', null]);
      });

      testWidgets('dismissible 为假时遮罩、Esc 与系统返回都不关闭，按钮仍可关闭', (tester) async {
        late BuildContext source;
        await tester.pumpWidget(_app(components, (c) => source = c));
        final results = <Object?>[];
        await _open(tester, el.dialog.confirm(source, content: '必须选择', dismissible: false), results);

        await tester.tapAt(Offset(4, 4));
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.binding.handlePopRoute();
        expect(await Navigator.of(source).maybePop(), isTrue);
        await tester.pumpAndSettle();
        expect(find.byType(ElDialog), findsOneWidget);
        expect(results, isEmpty);

        await tester.tap(_button('取消'));
        await tester.pumpAndSettle();
        expect(results, [false]);
        expect(find.byType(ElDialog), findsNothing);
      });
    });
  }

  testWidgets('show 经 Navigator.pop 返回值：关闭即交付结果，退场结束后才移除', (tester) async {
    late BuildContext source;
    await tester.pumpWidget(_app(el.desktopComponents, (c) => source = c));
    final results = <Object?>[];
    await _open(
      tester,
      el.dialog.show<String>(
        source,
        title: '选择',
        child: Builder(
          builder: (context) => ElButton(onPressed: () => Navigator.pop(context, '已选'), child: '返回'),
        ),
      ),
      results,
    );

    await tester.tap(_button('返回'));
    await tester.pump();
    expect(results, ['已选']);
    expect(_copy('选择'), findsOneWidget);
    await tester.pump(Duration(milliseconds: 150));
    expect(_copy('选择'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byType(ElDialog), findsNothing);
    expect(Navigator.of(source).canPop(), isFalse);
  });

  testWidgets('退场期间面板不再响应点击，避免重复提交', (tester) async {
    late BuildContext source;
    await tester.pumpWidget(_app(el.desktopComponents, (c) => source = c));
    var taps = 0;
    await _open(
      tester,
      el.dialog.show(
        source,
        child: Builder(
          builder: (context) => ElButton(
            onPressed: () {
              taps++;
              Navigator.pop(context);
            },
            child: '提交',
          ),
        ),
      ),
      [],
    );
    await tester.tap(_button('提交'));
    await tester.pump(Duration(milliseconds: 50));
    await tester.tap(_button('提交'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('打开时 popUntil 直接移除弹层，不陷入出栈循环', (tester) async {
    late BuildContext source;
    await tester.pumpWidget(_app(el.desktopComponents, (c) => source = c));
    final results = <Object?>[];
    await _open(tester, el.dialog.show(source, child: '内容'), results);
    await _open(tester, el.drawer.show(source, child: Text('抽屉')), results);

    Navigator.of(source).popUntil((route) => route.isFirst);
    await tester.pump();
    expect(results, [null, null]);
    await tester.pumpAndSettle();
    expect(find.byType(ElDialog), findsNothing);
    expect(find.byType(ElDrawer), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('抽屉内的确认框返回后立即关闭抽屉，两层都退场并交付结果', (tester) async {
    late BuildContext source;
    await tester.pumpWidget(_app(el.desktopComponents, (c) => source = c));
    final results = <Object?>[];
    await _open(
      tester,
      el.drawer.show<String>(
        source,
        title: '编辑资料',
        child: Builder(
          builder: (context) => ElButton(
            onPressed: () async {
              if (await el.dialog.confirm(context, content: '保存修改？') && context.mounted) {
                Navigator.of(context).pop('已保存');
              }
            },
            child: '保存资料',
          ),
        ),
      ),
      results,
    );
    await tester.tap(_button('保存资料'));
    await tester.pumpAndSettle();
    await tester.tap(_button('确定'));
    // 两层的退场同时进行，一个退场时长后都已移除。
    await tester.pump();
    await tester.pump(Duration(milliseconds: 310));
    await tester.pump();
    expect(find.byType(ElDialog), findsNothing);
    expect(find.byType(ElDrawer), findsNothing);
    expect(results, ['已保存']);
  });

  testWidgets('桌面对话框居中，确认框 420 宽、普通对话框 520 宽，取消在确认左侧', (tester) async {
    late BuildContext source;
    await tester.pumpWidget(_app(el.desktopComponents, (c) => source = c));
    await _open(tester, el.dialog.show(source, title: '详情', showClose: true, child: '正文'), []);
    final panel = tester.getRect(_panel(ElDialog));
    expect(panel.width, 520);
    expect(panel.center, Offset(400, 300));
    await tester.tap(find.bySemanticsLabel('关闭'));
    await tester.pumpAndSettle();
    expect(find.byType(ElDialog), findsNothing);

    await _open(tester, el.dialog.confirm(source, content: '继续？'), []);
    expect(tester.getRect(_panel(ElDialog)).width, 420);
    expect(tester.getCenter(_button('取消')).dx, lessThan(tester.getCenter(_button('确定')).dx));
    expect(tester.getRect(_button('确定')).right, moreOrLessEquals(tester.getRect(_panel(ElDialog)).right - 16));
  });

  testWidgets('桌面对话框停靠底部时贴底并保留边距，进场从下方升起', (tester) async {
    late BuildContext source;
    await tester.pumpWidget(_app(el.desktopComponents, (c) => source = c));
    el.dialog.show(source, placement: .bottom, child: '底部');
    await tester.pump();
    await tester.pump(Duration(milliseconds: 100));
    final entering = tester.getRect(_panel(ElDialog)).bottom;
    await tester.pumpAndSettle();
    final settled = tester.getRect(_panel(ElDialog));
    expect(settled.bottom, 600 - 16);
    expect(entering, greaterThan(settled.bottom));
  });

  testWidgets('桌面抽屉默认占视口 30% 且不小于 280，四向贴边，size 覆写尺寸', (tester) async {
    late BuildContext source;
    await tester.pumpWidget(_app(el.desktopComponents, (c) => source = c));
    for (final (placement, size, expected) in [
      (ElPopupPlacement.right, null, Rect.fromLTWH(520, 0, 280, 600)),
      (ElPopupPlacement.left, null, Rect.fromLTWH(0, 0, 280, 600)),
      (ElPopupPlacement.top, null, Rect.fromLTWH(0, 0, 800, 280)),
      (ElPopupPlacement.bottom, 200.0, Rect.fromLTWH(0, 400, 800, 200)),
      (ElPopupPlacement.right, 400.0, Rect.fromLTWH(400, 0, 400, 600)),
      (ElPopupPlacement.right, 1200.0, Rect.fromLTWH(0, 0, 800, 600)),
    ]) {
      await _open(tester, el.drawer.show(source, placement: placement, size: size, child: Text('抽屉')), []);
      expect(tester.getRect(_panel(ElDrawer)), expected, reason: '$placement $size');
      await tester.tap(find.bySemanticsLabel('关闭'));
      await tester.pumpAndSettle();
      expect(find.byType(ElDrawer), findsNothing);
    }
  });

  testWidgets('桌面抽屉从对应边缘整体滑入，遮罩随进度淡入', (tester) async {
    late BuildContext source;
    await tester.pumpWidget(_app(el.desktopComponents, (c) => source = c));
    el.drawer.show(source, title: '筛选', child: Text('条件'));
    await tester.pump();
    await tester.pump(Duration(milliseconds: 150));
    final layer = tester.widget<ModalLayer>(find.byType(ModalLayer));
    expect(layer.animation.value, inExclusiveRange(0, 1));
    expect(tester.getRect(_panel(ElDrawer)).left, greaterThan(520));
    await tester.pumpAndSettle();
    expect(tester.getRect(_panel(ElDrawer)).left, 520);

    await tester.tapAt(Offset(100, 300));
    await tester.pumpAndSettle();
    expect(find.byType(ElDrawer), findsNothing);
  });

  testWidgets('直接放在页面中的 ElDialog 与 ElDrawer 只渲染面板，不带遮罩和进退场', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ElComponentProvider(
          components: el.desktopComponents,
          child: Scaffold(
            body: Column(
              children: [
                ElDialog(title: '内嵌对话框', child: '说明'),
                SizedBox(
                  height: 200,
                  child: ElDrawer(title: '内嵌抽屉', child: Text('内容')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.byType(ModalLayer), findsNothing);
    expect(_copy('内嵌对话框'), findsOneWidget);
    expect(find.bySemanticsLabel('关闭'), findsNothing);
    expect(tester.getRect(_panel(ElDialog)).top, 0);
    expect(tester.getRect(_panel(ElDrawer)).height, 200);
  });

  testWidgets('弹层沿用调用处的局部品牌覆写，语义名称取 semanticLabel', (tester) async {
    final handle = tester.ensureSemantics();
    late BuildContext source;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => ElComponentProvider(components: el.desktopComponents, child: child!),
        home: Scaffold(
          body: ElComponentProvider(
            components: ElComponents(
              dialog: (context, c) => Center(
                child: GestureDetector(onTap: c.onClose, child: Text('自定义：${c.child}')),
              ),
            ),
            child: Builder(
              builder: (context) {
                source = context;
                return SizedBox.expand();
              },
            ),
          ),
        ),
      ),
    );
    final results = <Object?>[];
    await _open(tester, el.dialog.show(source, child: '内容', semanticLabel: '偏好设置'), results);
    expect(find.text('自定义：内容'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('偏好设置')), findsOneWidget);
    await tester.tap(find.text('自定义：内容'));
    await tester.pumpAndSettle();
    expect(results, [null]);
    expect(find.text('自定义：内容'), findsNothing);
    handle.dispose();
  });
}
