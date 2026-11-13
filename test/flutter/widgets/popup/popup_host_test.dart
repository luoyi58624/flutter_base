// ignore_for_file: deprecated_member_use

import 'dart:ui' show Scene, SemanticsUpdate, ViewFocusDirection, ViewFocusEvent, ViewFocusState;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_base/flutter.dart';
import 'package:flutter_base/src/flutter/widgets/popup/host.dart' show popupHostOf;
import 'package:flutter_base/src/flutter/widgets/popup/notice.dart';
import 'package:flutter_base/src/flutter/widgets/popup/session.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pumpFrames(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

PopupSession<T> showPanel<T>(BuildContext source, Widget panel) => popupHostOf(source)!.showPanel<T>(
  source,
  builder: (_, _) => Center(child: SizedBox(width: 260, height: 100, child: panel)),
)!;

Widget window(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: ElPopupHost(child: child),
);

class _TestView extends TestFlutterView {
  _TestView(TestFlutterView source)
    : super(view: source, platformDispatcher: source.platformDispatcher, display: source.display);

  @override
  int get viewId => 101;

  @override
  void render(Scene scene, {Size? size}) {}

  @override
  void updateSemantics(SemanticsUpdate update) {}
}

void main() {
  testWidgets('替换 Navigator 后保留面板 State、主题和结果，关闭后才摘除', (tester) async {
    final navigator = GlobalKey<NavigatorState>();
    final observer = _NavigationCount();
    final themeKey = Object();
    late BuildContext page;
    late BuildContext panelContext;
    final draft = TextEditingController();
    addTearDown(draft.dispose);
    Widget app(Widget child) => MaterialApp(builder: (_, _) => ElPopupHost(child: child));

    await tester.pumpWidget(
      app(
        Navigator(
          key: navigator,
          observers: [observer],
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (_) => ElView(
              style: ElStyle(vars: {themeKey: '来源主题'}),
              child: Builder(
                builder: (context) {
                  page = context;
                  return SizedBox.expand();
                },
              ),
            ),
          ),
        ),
      ),
    );

    final panel = showPanel<String>(
      page,
      Material(
        child: Column(
          children: [
            TextField(controller: draft),
            Builder(
              builder: (context) {
                panelContext = context;
                return Text(ElView.of(context).getVar<String>(themeKey)!);
              },
            ),
          ],
        ),
      ),
    );
    await pumpFrames(tester);
    expect(observer.pushes, 1);
    expect(navigator.currentState!.canPop(), isFalse);
    await tester.enterText(find.byType(TextField), '草稿');
    final state = tester.state(find.byType(TextField));

    await tester.pumpWidget(app(Text('新页面')));
    expect(page.mounted, isFalse);
    expect(navigator.currentState, isNull);
    expect(tester.state(find.byType(TextField)), same(state));
    expect(find.text('草稿'), findsOneWidget);
    expect(find.text('来源主题'), findsOneWidget);
    expect(panel.close(page, '错误来源'), isFalse);
    expect(panel.close(panelContext, '确认'), isTrue);
    expect(panel.close(panelContext, '重复确认'), isFalse);
    expect(await panel.result, '确认');

    var removed = false;
    panel.removed.then((_) => removed = true);
    await tester.pump();
    expect(removed, isFalse);
    panel.remove();
    await tester.pump();
    expect(removed, isTrue);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('根 Overlay 的轻提示绕过内层 Overlay 并在首帧前卸载时结清', (tester) async {
    final root = GlobalKey<OverlayState>();
    final local = GlobalKey<OverlayState>();
    late BuildContext source;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Overlay(
          key: root,
          initialEntries: [
            OverlayEntry(
              builder: (_) => Overlay(
                key: local,
                initialEntries: [
                  OverlayEntry(
                    builder: (context) {
                      source = context;
                      return SizedBox.expand();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    late OverlayState target;
    final removed = showPopupNotice(
      source,
      duration: Duration(seconds: 1),
      child: Builder(
        builder: (context) {
          target = Overlay.of(context);
          return Text('提示');
        },
      ),
    );
    await tester.pump();
    expect(Overlay.of(source), local.currentState);
    expect(target, root.currentState);
    expect(ElPopupHost.handleBack(source), isFalse);
    await tester.pump(Duration(seconds: 1));
    await removed;
    expect(find.text('提示'), findsNothing);

    final beforeFirstFrame = showPopupNotice(source, duration: Duration(seconds: 30), child: Text('未显示'));
    await tester.pumpWidget(SizedBox());
    await beforeFirstFrame;
    expect(tester.takeException(), isNull);
  });

  testWidgets('系统返回先处理独立面板，预测手势只提交原接收者', (tester) async {
    final navigator = GlobalKey<NavigatorState>();
    late BuildContext page;
    final back = ElPopupBackObserver((_) => page);
    tester.binding.addObserver(back);
    addTearDown(() => tester.binding.removeObserver(back));
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        builder: (_, child) => ElPopupHost(child: child!),
        home: ElPopupBackScope(
          child: Builder(
            builder: (context) {
              page = context;
              return Text('首页');
            },
          ),
        ),
      ),
    );
    final first = showPanel<int>(page, Text('第一层'));
    await tester.pump();
    expect(ModalRoute.of(page)!.popDisposition, RoutePopDisposition.doNotPop);
    expect(await tester.binding.handlePopRoute(), isTrue);
    expect(first.open.value, isFalse);
    expect(await first.result, isNull);
    first.remove();
    await tester.pump();
    expect(ModalRoute.of(page)!.popDisposition, RoutePopDisposition.bubble);

    Future<void> gesture(String method, [Object? arguments]) async {
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'flutter/backgesture',
        StandardMethodCodec().encodeMethodCall(MethodCall(method, arguments)),
        (_) {},
      );
    }

    Future<void> start() => gesture('startBackGesture', {
      'touchOffset': [5.0, 300.0],
      'progress': 0.0,
      'swipeEdge': 0,
    });

    final second = showPanel<void>(page, Text('第二层'));
    await tester.pump();
    await start();
    await gesture('cancelBackGesture');
    expect(second.open.value, isTrue);
    await start();
    final third = showPanel<void>(page, Text('第三层'));
    await gesture('commitBackGesture');
    expect(second.open.value && third.open.value, isTrue);
    await start();
    await gesture('commitBackGesture');
    expect(third.open.value, isFalse);
    expect(second.open.value, isTrue);
    third.remove();
    second.remove();
    await tester.pump();
    expect(navigator.currentState!.canPop(), isFalse);
  });

  testWidgets('两个视图的面板、菜单和输入事件各自分发', (tester) async {
    final otherView = _TestView(tester.view);
    final contexts = <int, BuildContext>{};
    final first = ElPortalController();
    final second = ElPortalController();
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    final focusA = FocusNode();
    final focusB = FocusNode();
    addTearDown(focusA.dispose);
    addTearDown(focusB.dispose);

    Widget scene(int id, ElPortalController portal, FocusNode focus) => window(
      Focus(
        focusNode: focus,
        child: Builder(
          builder: (context) {
            contexts[id] = context;
            return Center(
              child: ElPortal(
                controller: portal,
                closeOnOutsidePointerDown: true,
                panel: SizedBox(width: 100, height: 48),
                child: SizedBox(width: 80, height: 30),
              ),
            );
          },
        ),
      ),
    );

    final idA = tester.view.viewId;
    final idB = otherView.viewId;
    await tester.pumpWidget(
      ViewCollection(
        views: [
          View(view: tester.view, child: scene(idA, first, focusA)),
          View(view: otherView, child: scene(idB, second, focusB)),
        ],
      ),
      wrapWithView: false,
    );
    first.open();
    second.open();
    await pumpFrames(tester);
    await tester.tapAt(Offset(24, 24), view: tester.view);
    expect(first.isOpen, isFalse);
    expect(second.isOpen, isTrue);
    await pumpFrames(tester);
    first.open();
    await pumpFrames(tester);
    focusA.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    expect(first.isOpen, isFalse);
    expect(second.isOpen, isTrue);
    second.close();
    await pumpFrames(tester);

    final panelA = showPanel<void>(contexts[idA]!, Text('甲窗口'));
    final panelB = showPanel<void>(contexts[idB]!, Text('乙窗口'));
    await tester.pump();
    expect(panelA.close(contexts[idB]!), isFalse);
    final back = ElPopupBackObserver((id) => contexts[id]);
    back.didChangeViewFocus(
      ViewFocusEvent(viewId: idA, state: ViewFocusState.focused, direction: ViewFocusDirection.undefined),
    );
    expect(await back.didPopRoute(), isTrue);
    expect(panelA.open.value, isFalse);
    expect(panelB.open.value, isTrue);
    panelA.remove();
    panelB.remove();
    await tester.pump();
  });

  testWidgets('面板内锚定菜单先处理返回，轻提示放行', (tester) async {
    final menu = ElPortalController();
    addTearDown(menu.dispose);
    late BuildContext page;
    late BuildContext panelContext;
    var submenu = true;
    await tester.pumpWidget(
      window(
        Builder(
          builder: (context) {
            page = context;
            return SizedBox.expand();
          },
        ),
      ),
    );
    final panel = showPanel<void>(
      page,
      Builder(
        builder: (context) {
          panelContext = context;
          return ElPortal(
            controller: menu,
            closeOnBack: true,
            onBack: () {
              if (submenu) {
                submenu = false;
              } else {
                menu.close();
              }
            },
            panel: Text('菜单'),
            child: Text('触发器'),
          );
        },
      ),
    );
    await pumpFrames(tester);
    menu.open();
    final notice = showPopupNotice(panelContext, duration: Duration(seconds: 10), child: Text('轻提示'));
    await pumpFrames(tester);
    expect(menu.isOpen, isTrue);
    expect(ElPopupHost.handleBack(page), isTrue);
    expect(submenu, isFalse);
    expect(menu.isOpen, isTrue);
    expect(ElPopupHost.handleBack(page), isTrue);
    expect(menu.isOpen, isFalse);
    expect(panel.open.value, isTrue);
    expect(ElPopupHost.handleBack(page), isTrue);
    expect(panel.open.value, isFalse);
    expect(ElPopupHost.handleBack(page), isFalse);
    expect(find.text('轻提示'), findsOneWidget);
    panel.remove();
    await tester.pumpWidget(SizedBox());
    await notice;
  });

  testWidgets('同一窗口的根和局部 Overlay 共用一次外点的关闭顺序', (tester) async {
    final root = ElPortalController();
    final local = ElPortalController();
    addTearDown(root.dispose);
    addTearDown(local.dispose);
    await tester.pumpWidget(
      window(
        Stack(
          children: [
            Positioned(
              top: 20,
              left: 20,
              child: ElPortal(
                controller: root,
                closeOnOutsidePointerDown: true,
                panel: Text('根菜单'),
                child: SizedBox(width: 80, height: 30),
              ),
            ),
            Positioned.fill(
              child: Overlay(
                initialEntries: [
                  OverlayEntry(
                    builder: (_) => Align(
                      alignment: Alignment.center,
                      child: ElPortal(
                        controller: local,
                        closeOnOutsidePointerDown: true,
                        panel: Text('局部菜单'),
                        child: SizedBox(width: 80, height: 30),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    root.open();
    local.open();
    await pumpFrames(tester);
    expect(root.isOpen && local.isOpen, isTrue);
    await tester.tapAt(Offset(560, 400));
    expect(local.isOpen, isFalse);
    expect(root.isOpen, isTrue);
    await tester.tapAt(Offset(560, 400));
    expect(root.isOpen, isFalse);
    await pumpFrames(tester);
  });

  testWidgets('裸宿主的弹层返回能力同步给 Android', (tester) async {
    final published = <bool>[];
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'SystemNavigator.setFrameworkHandlesBack') {
        published.add(call.arguments as bool);
      }
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(SystemChannels.platform, null));

    BuildContext? page;
    final back = ElPopupBackObserver((_) => page);
    addTearDown(back.dispose);
    await tester.pumpWidget(
      window(
        Builder(
          builder: (context) {
            page = context;
            return SizedBox.expand();
          },
        ),
      ),
    );
    back.updatePlatform(page!);
    final panel = showPanel<void>(page!, Text('弹层'));
    final notice = showPopupNotice(page!, duration: Duration(seconds: 5), child: Text('提示'));
    await tester.pump();
    expect(published, [false, true]);
    expect(await back.didPopRoute(), isTrue);
    await tester.pump();
    expect(published, [false, true, false]);
    expect(await back.didPopRoute(), isFalse);
    panel.remove();
    await tester.pumpWidget(SizedBox());
    await notice;
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}

class _NavigationCount extends NavigatorObserver {
  int pushes = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushes++;
  }
}
