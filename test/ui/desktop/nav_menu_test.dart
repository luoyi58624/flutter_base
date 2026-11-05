import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/desktop.dart';
import 'package:flutter_test/flutter_test.dart';

Finder _label(String value) => find.byWidgetPredicate((w) => w is ElView && w.child == value);
Finder _row(String value) => find
    .ancestor(of: _label(value), matching: find.byWidgetPredicate((w) => w is ElView && w.event?.onTap != null))
    .first;

Future<void> _host(WidgetTester tester, ElNavMenu<void> menu, {Brightness brightness = Brightness.light}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: ElView(
        themeMode: ElThemeMode(brightness: brightness, duration: Duration.zero),
        child: ElComponentProvider(
          components: el.desktopComponents,
          child: Align(
            alignment: .topLeft,
            child: SizedBox(width: 260, height: 580, child: menu),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _MenuRouter extends RouterDelegate<RouteInformation> with ChangeNotifier {
  _MenuRouter(String path) : currentConfiguration = RouteInformation(uri: Uri.parse(path));

  @override
  RouteInformation currentConfiguration;

  @override
  Widget build(BuildContext context) => SizedBox.shrink();

  @override
  Future<bool> popRoute() async => false;

  @override
  Future<void> setNewRoutePath(RouteInformation configuration) async {
    currentConfiguration = configuration;
    notifyListeners();
  }
}

void main() {
  test('分组只是模型标识，可省略 key，普通菜单项仍须提供 key', () {
    final group = ElMenuModel<void>(group: true, title: '开始使用');
    expect(group.group, isTrue);
    expect(group.key, isEmpty);
    expect(() => ElMenuModel<void>(title: '缺少 key'), throwsAssertionError);
    expect(group, isNot(ElMenuModel<void>(key: '', title: '开始使用')));
  });

  test('完整路径穿透任意层分组并保留数据、图标和标识', () {
    final icon = ElIcon(Icons.home_outlined);
    final items = [
      ElMenuModel<int>(
        key: 'view',
        title: '视图',
        children: [
          ElMenuModel<int>(
            group: true,
            title: '基本',
            children: [ElMenuModel<int>(key: 'box', title: '盒子', icon: icon, data: 7)],
          ),
        ],
      ),
    ];
    final result = items.toFullPath(parentPath: '/docs');
    final group = result.first.children.first;
    expect(result.first.key, '/docs/view');
    expect(group.group, isTrue);
    expect(group.key, isEmpty);
    expect(group.children.first.key, '/docs/view/box');
    expect(group.children.first.icon, same(icon));
    expect(group.children.first.data, 7);
    expect(items.first.key, 'view');
  });

  testWidgets('分组只显示标题，子项同级排列；点击标题不选择也不折叠', (tester) async {
    final value = ValueNotifier('first'), changes = <String>[];
    await _host(
      tester,
      ElNavMenu<void>(
        modelValue: value,
        onChanged: changes.add,
        children: [
          ElMenuModel<void>(
            group: true,
            title: '开始使用',
            children: [ElMenuModel<void>(key: 'first', title: '快速开始')],
          ),
          ElMenuModel<void>(key: 'outside', title: '普通项'),
          ElMenuModel<void>(
            group: true,
            title: '基础组件',
            children: [ElMenuModel<void>(key: 'second', title: '按钮')],
          ),
        ],
      ),
    );
    expect(tester.getTopLeft(_label('快速开始')).dx, tester.getTopLeft(_label('普通项')).dx);
    expect(tester.getTopLeft(_label('按钮')).dx, tester.getTopLeft(_label('普通项')).dx);
    expect(tester.widget<ElView>(_label('开始使用')).event, isNull);
    await tester.tapAt(tester.getCenter(_label('开始使用')));
    await tester.pumpAndSettle();
    expect(changes, isEmpty);
    expect(value.value, 'first');
    expect(_row('快速开始').hitTestable(), findsOneWidget);
    await tester.tap(_row('按钮'));
    await tester.pump(Duration(milliseconds: 250));
    await tester.pumpAndSettle();
    expect(value.value, 'second');
    expect(changes, ['second']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('默认选择穿透分组与子菜单找到首个真实叶子，子菜单仍能折叠', (tester) async {
    final menu = ElNavMenu<void>(
      children: [
        ElMenuModel<void>(
          group: true,
          title: '示例',
          children: [
            ElMenuModel<void>(
              key: 'view',
              title: '视图',
              children: [
                ElMenuModel<void>(
                  group: true,
                  title: '内容',
                  children: [ElMenuModel<void>(key: 'box', title: '盒子')],
                ),
              ],
            ),
          ],
        ),
      ],
    );
    expect(menu.value, 'box');
    await _host(tester, menu);
    expect(_row('盒子').hitTestable(), findsOneWidget);
    expect(tester.getTopLeft(_label('盒子')).dx - tester.getTopLeft(_label('视图')).dx, menu.nestGap);
    await tester.tap(_row('视图'));
    await tester.pumpAndSettle();
    expect(_row('盒子').hitTestable(), findsNothing);
    await tester.tap(_row('视图'));
    await tester.pumpAndSettle();
    expect(_row('盒子').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('路由高亮穿透分组，点击仅通知真实菜单路径', (tester) async {
    final delegate = _MenuRouter('/docs/box'), changes = <String>[];
    final items = [
      ElMenuModel<void>(
        group: true,
        title: '基础组件',
        children: [
          ElMenuModel<void>(key: 'box', title: '盒子'),
          ElMenuModel<void>(key: 'text', title: '文本'),
        ],
      ),
    ].toFullPath(parentPath: '/docs');
    await _host(
      tester,
      ElNavMenu<void>.router(
        router: RouterConfig<RouteInformation>(routerDelegate: delegate),
        children: items,
        onChanged: changes.add,
      ),
    );
    final primary = el.desktopComponents.style!.vars![ElTokens.$primary];
    expect(tester.widget<ElView>(_row('盒子')).style!.color, primary);
    await delegate.setNewRoutePath(RouteInformation(uri: Uri.parse('/docs/text')));
    await tester.pumpAndSettle();
    expect(tester.widget<ElView>(_row('文本')).style!.color, primary);
    expect(tester.widget<ElView>(_row('盒子')).style!.color, isNot(primary));
    await tester.tap(_row('盒子'));
    await tester.pumpAndSettle();
    expect(changes, ['/docs/box']);
    expect(delegate.currentConfiguration.uri.path, '/docs/text');
    await tester.pumpWidget(SizedBox.shrink());
    delegate.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets('多层子菜单逐级缩进，分组与菜单行上下连续，折叠后也不留空隙', (tester) async {
    await _host(
      tester,
      ElNavMenu<void>(
        children: [
          ElMenuModel<void>(
            group: true,
            title: '基础组件',
            children: [
              ElMenuModel<void>(
                key: 'catalogue',
                title: '组件目录',
                children: [
                  ElMenuModel<void>(
                    group: true,
                    title: '内容分组',
                    children: [
                      ElMenuModel<void>(
                        key: 'container',
                        title: '内容容器',
                        children: [
                          ElMenuModel<void>(key: 'card', title: '卡片'),
                          ElMenuModel<void>(key: 'list', title: '列表'),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          ElMenuModel<void>(key: 'settings', title: '设置'),
        ],
      ),
    );
    void adjacent(Finder above, Finder below) {
      expect(tester.getRect(below).top, closeTo(tester.getRect(above).bottom, .001));
    }

    expect(tester.getTopLeft(_label('内容容器')).dx - tester.getTopLeft(_label('组件目录')).dx, 20);
    expect(tester.getTopLeft(_label('卡片')).dx - tester.getTopLeft(_label('内容容器')).dx, 20);
    adjacent(_label('基础组件'), _row('组件目录'));
    adjacent(_row('组件目录'), _label('内容分组'));
    adjacent(_label('内容分组'), _row('内容容器'));
    adjacent(_row('内容容器'), _row('卡片'));
    adjacent(_row('卡片'), _row('列表'));
    adjacent(_row('列表'), _row('设置'));
    await tester.tap(_row('内容容器'));
    await tester.pumpAndSettle();
    expect(_row('卡片').hitTestable(), findsNothing);
    adjacent(_row('内容容器'), _row('设置'));
    await tester.tap(_row('组件目录'));
    await tester.pumpAndSettle();
    expect(_row('内容容器').hitTestable(), findsNothing);
    adjacent(_row('组件目录'), _row('设置'));
    expect(tester.takeException(), isNull);
  });

  for (final brightness in Brightness.values) {
    testWidgets('保留圆角浅色选中态，悬停不改变选中与普通项的背景：$brightness', (tester) async {
      await _host(
        tester,
        ElNavMenu<void>(
          value: 'leaf',
          children: [
            ElMenuModel<void>(
              group: true,
              title: '开始使用',
              children: [
                ElMenuModel<void>(key: 'leaf', title: '主题设计'),
                ElMenuModel<void>(key: 'other', title: '阴影设计'),
              ],
            ),
          ],
        ),
        brightness: brightness,
      );
      final vars = {
        ...el.desktopComponents.style!.vars!,
        if (brightness == Brightness.dark) ...el.desktopComponents.style!.onDark!.vars!,
      };
      final row = tester.widget<ElView>(_row('主题设计')).style!;
      expect(row.height, 40);
      expect(row.borderRadius, BorderRadius.circular(8));
      expect(row.color, vars[ElTokens.$primary]);
      expect(
        row.backgroundColor,
        Color.lerp(
          vars[ElTokens.$cardColor] as Color,
          vars[ElTokens.$primary] as Color,
          brightness == Brightness.dark ? .16 : .09,
        ),
      );
      expect(tester.widget<ElView>(_label('开始使用')).style!.fontSize, 12);
      expect(tester.widget<ElView>(_label('开始使用')).style!.backgroundColor, isNull);
      final selected = tester.renderObject<ElRenderView>(_row('主题设计'));
      final ordinary = tester.renderObject<ElRenderView>(_row('阴影设计'));
      final selectedBackground = selected.committedResolvedStyle.box.backgroundColor;
      final ordinaryBackground = ordinary.committedResolvedStyle.box.backgroundColor;
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset(700, 500));
      await mouse.moveTo(tester.getCenter(_row('主题设计')));
      await tester.pumpAndSettle();
      expect(selected.committedResolvedStyle.box.backgroundColor, selectedBackground);
      await mouse.moveTo(tester.getCenter(_row('阴影设计')));
      await tester.pumpAndSettle();
      expect(ordinary.committedResolvedStyle.box.backgroundColor, ordinaryBackground);
      await mouse.removePointer();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('显式样式覆盖默认菜单外观', (tester) async {
    await _host(
      tester,
      ElNavMenu<void>(
        value: 'leaf',
        style: ElStyle(
          height: 48,
          color: Colors.purple,
          iconColor: Colors.green,
          borderRadius: .circular(16),
          onHover: ElStyle(backgroundColor: Colors.orange),
        ),
        children: [ElMenuModel<void>(key: 'leaf', title: '自定义')],
      ),
    );
    final row = tester.widget<ElView>(_row('自定义')).style!;
    expect(row.height, 48);
    expect(row.borderRadius, BorderRadius.circular(16));
    expect(row.color, Colors.purple);
    expect(row.iconColor, Colors.green);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset(700, 500));
    await mouse.moveTo(tester.getCenter(_row('自定义')));
    await tester.pumpAndSettle();
    expect(tester.renderObject<ElRenderView>(_row('自定义')).committedResolvedStyle.box.backgroundColor, Colors.orange);
    await mouse.removePointer();
  });
}
