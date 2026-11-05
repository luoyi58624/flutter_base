import '../../support/overlay.dart';
import '../../support/portal.dart';

import 'package:flutter_base/ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _a(BuildContext context, ElButton button, Obs<bool> model) => ElView(child: 'A');
Widget _b(BuildContext context, ElButton button, Obs<bool> model) => ElView(child: 'B');

Widget _host(Widget child) => Directionality(
  textDirection: .ltr,
  child: ElView(child: child),
);

void main() {
  testWidgets('全局仅注入一个继承节点，没有隐式局部主题', (tester) async {
    final data = ElComponents(button: _a);
    await tester.pumpWidget(
      _host(
        ElComponentProvider(
          components: data,
          child: Builder(
            builder: (context) {
              expect(ElComponentProvider.of(context), data);
              expect(ElComponentProvider.of(context).button, data.button);
              return ElButton();
            },
          ),
        ),
      ),
    );
    // ElView 会提供样式继承节点，组件主题仍必须只注册一个。
    expect(find.byWidgetPredicate((widget) => widget is InheritedTheme), findsNWidgets(2));
    expect(find.byType(ElComponentProvider), findsOneWidget);
    expect(find.byWidgetPredicate((widget) => widget is ElView && widget.child == 'A'), findsOneWidget);
  });

  testWidgets('相等配置不通知按钮，更新全局配置重新分派实现', (tester) async {
    var calls = 0;
    Widget count(BuildContext context, ElButton button, Obs<bool> model) {
      calls++;
      return _a(context, button, model);
    }

    final button = ElButton();
    Widget tree(Widget Function(BuildContext, ElButton, Obs<bool>) builder) => _host(
      ElComponentProvider(
        components: ElComponents(button: builder),
        child: button,
      ),
    );
    await tester.pumpWidget(tree(count));
    await tester.pumpWidget(tree(count));
    expect(calls, 1);
    await tester.pumpWidget(tree(_b));
    expect(find.byWidgetPredicate((widget) => widget is ElView && widget.child == 'B'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('捕获全局快照不与新宿主重新 merge，也不创建局部节点', (tester) async {
    late BuildContext source;
    late CapturedThemes captured;
    await tester.pumpWidget(
      _host(
        ElComponentProvider(
          components: ElComponents(button: _a),
          child: Builder(
            builder: (context) {
              source = context;
              return ElView();
            },
          ),
        ),
      ),
    );
    captured = InheritedTheme.capture(from: source, to: null);
    await tester.pumpWidget(
      _host(
        ElComponentProvider(
          components: ElComponents(button: _b),
          child: captured.wrap(
            Builder(
              builder: (context) {
                expect(ElComponentProvider.of(context).button, _a);
                return ElView();
              },
            ),
          ),
        ),
      ),
    );
  });
  test('登记表支持替换、清空、非空合并和函数等值', () {
    final global = ElComponents(button: _a);
    expect(global.copyWith(button: _b).button, _b);
    expect(global.merge(null), same(global));
    expect(global.merge(ElComponents()), global);
    expect(global.copyWith(), global);
    expect(global.copyWith(button: null).button, isNull);
    expect(global.hashCode, ElComponents(button: _a).hashCode);
  });

  testWidgets('缺少主题由 of 断言，缺少实现时报出组件名', (tester) async {
    await tester.pumpWidget(_host(ElButton()));
    expect(
      tester.takeException(),
      isA<AssertionError>().having((e) => e.message, 'message', contains('ElComponentProvider')),
    );
    await tester.pumpWidget(_host(ElComponentProvider(components: ElComponents(), child: ElView())));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(_host(ElComponentProvider(components: ElComponents(), child: ElButton())));
    expect(tester.takeException(), isA<FlutterError>().having((e) => e.message, 'message', contains('ElButton')));
  });

  testWidgets('内层配置与祖先合并，未传的项沿用外层', (tester) async {
    final parent = ElComponents(button: _a);
    for (final (data, expected) in [(ElComponents(), _a), (ElComponents(button: _b), _b)]) {
      await tester.pumpWidget(
        _host(
          ElComponentProvider(
            components: parent,
            child: ElComponentProvider(
              components: data,
              child: Builder(
                builder: (context) {
                  expect(ElComponentProvider.of(context).button, expected);
                  return ElView();
                },
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('兄弟子树主题隔离，组件直接读取最近的全局配置', (tester) async {
    Widget Function(BuildContext, ElButton, Obs<bool>)? resolved;
    await tester.pumpWidget(
      _host(
        Row(
          children: [
            ElComponentProvider(
              components: ElComponents(button: _a),
              child: ElButton(),
            ),
            ElComponentProvider(
              components: ElComponents(button: _a),
              child: ElComponentProvider(
                components: ElComponents(button: _b),
                child: Builder(
                  builder: (context) {
                    resolved = ElComponentProvider.of(context).button;
                    return ElButton();
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
    expect(resolved, _b);
    expect(find.byWidgetPredicate((w) => w is ElView && w.child == 'A'), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is ElView && w.child == 'B'), findsOneWidget);
  });

  testWidgets('固定 child 下相等主题不通知，切换 builder 只重建依赖者', (tester) async {
    var calls = 0;
    Widget count(BuildContext context, ElButton button, Obs<bool> model) {
      calls++;
      return _a(context, button, model);
    }

    final button = ElButton(key: GlobalKey(), child: '原始声明');
    Widget tree(Widget Function(BuildContext, ElButton, Obs<bool>) builder) => _host(
      ElComponentProvider(
        components: ElComponents(button: builder),
        child: button,
      ),
    );
    await tester.pumpWidget(tree(count));
    expect(calls, 1);
    await tester.pumpWidget(tree(count));
    expect(calls, 1);
    await tester.pumpWidget(tree(_b));
    expect(find.byWidgetPredicate((w) => w is ElView && w.child == 'B'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('分派传入原始声明，GlobalKey 只挂载一次', (tester) async {
    final button = ElButton(key: GlobalKey(), loading: true, child: '原始内容');
    ElButton? received;
    await tester.pumpWidget(
      _host(
        ElComponentProvider(
          components: ElComponents(
            button: (context, component, model) {
              received = component;
              return _a(context, component, model);
            },
          ),
          child: button,
        ),
      ),
    );
    expect(received, same(button));
    expect(tester.takeException(), isNull);
  });

  testWidgets('弹层捕获组件主题快照，重开取新值，嵌套弹层继承快照', (tester) async {
    late BuildContext source;
    late BuildContext popup;
    final sourceWidget = Builder(
      builder: (context) {
        source = context;
        return ElView();
      },
    );
    Widget tree(Widget Function(BuildContext, ElButton, Obs<bool>) builder) => _host(
      ElComponentProvider(
        components: ElComponents(button: _a),
        child: ElTestOverlay(
          child: ElTestPortal(
            child: ElComponentProvider(
              components: ElComponents(button: builder),
              child: sourceWidget,
            ),
          ),
        ),
      ),
    );
    await tester.pumpWidget(tree(_b));
    final captured = InheritedTheme.capture(from: source, to: Overlay.of(source).context);
    final entry = ElTestPortal.of(source).show(
      builder: (_) => captured.wrap(
        Builder(
          builder: (context) {
            popup = context;
            return ElButton();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(ElComponentProvider.of(popup).button, _b);
    await tester.pumpWidget(tree(_a));
    expect(ElComponentProvider.of(popup).button, _b);
    final nested = ElTestPortal.of(popup).show(
      builder: (_) => captured.wrap(
        Builder(
          builder: (context) {
            expect(ElComponentProvider.of(context).button, _b);
            return ElButton();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    nested.close();
    entry.close();
    await tester.pumpAndSettle();
    ElTestPortal.of(source).show(
      builder: (context) {
        expect(ElComponentProvider.of(context).button, _a);
        return ElButton();
      },
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('未捕获的宿主祖先主题可继续更新已打开弹层', (tester) async {
    late BuildContext source;
    late BuildContext popup;
    final content = ElTestOverlay(
      child: ElTestPortal(
        child: Builder(
          builder: (context) {
            source = context;
            return ElView();
          },
        ),
      ),
    );
    Widget tree(Widget Function(BuildContext, ElButton, Obs<bool>) builder) => _host(
      ElComponentProvider(
        components: ElComponents(button: builder),
        child: content,
      ),
    );
    await tester.pumpWidget(tree(_a));
    ElTestPortal.of(source).show(
      builder: (context) {
        popup = context;
        return ElButton();
      },
    );
    await tester.pumpAndSettle();
    expect(ElComponentProvider.of(popup).button, _a);
    await tester.pumpWidget(tree(_b));
    expect(ElComponentProvider.of(popup).button, _b);
  });
}
