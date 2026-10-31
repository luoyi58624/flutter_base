import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_base/mobile.dart';
import 'package:example/state.dart';

import '../pages/index.dart';

import 'package:flutter/material.dart'
    show
        MaterialApp,
        MaterialPageRoute,
        ThemeData,
        Scaffold,
        ScaffoldMessengerState,
        SnackBar;
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter/widgets.dart';
import 'package:path_drawing/path_drawing.dart';

part 'data.dart';
part 'icon_paths.dart';
part 'typography.dart';
part 'home.dart';
part 'category.dart';
part 'messages.dart';
part 'profile.dart';
part 'pages.dart';
part 'navigation.dart';

const _primary = Color(0xff2454c6);
const _background = Color(0xfff2f3f5);
const _surface = Color(0xffffffff);
const _divider = Color(0xffededed);
const _text = Color(0xff222222);
const _secondary = Color(0xff666666);
const _tertiary = Color(0xff999999);
const _tabs = ['推荐', '分类', '消息', '我的'];
const _desktopBreakpoint = 768.0;
final _messenger = GlobalKey<ScaffoldMessengerState>();
const _systemBars = SystemUiOverlayStyle(
  statusBarColor: Color(0x00000000),
  statusBarIconBrightness: Brightness.dark,
  statusBarBrightness: Brightness.light,
  systemNavigationBarColor: Color(0x00000000),
  systemNavigationBarIconBrightness: Brightness.dark,
  systemNavigationBarContrastEnforced: false,
);

/// 使用移动端主题，按可用宽度切换桌面与移动布局的示例应用。
class ElExampleApp extends StatelessWidget {
  /// 创建示例，可注入请求延时用于无头验证。
  const ElExampleApp({
    super.key,
    this.systemWght,
    this.networkDelay = const Duration(milliseconds: 800),
    this.replyDelay = const Duration(milliseconds: 900),
    this.pageContentBuilder,
  });

  /// 字重插件返回的系统常规字重，空值保留字体原始档位。
  final double? systemWght;

  /// 原生示例使用的分页延时，允许测试替换。
  final Duration networkDelay;

  /// 原生示例使用的自动回复延时，允许测试替换。
  final Duration replyDelay;

  /// 可替换帮助与关于页的内容，参数为页面资源名。
  final Widget Function(String asset)? pageContentBuilder;

  @override
  Widget build(BuildContext context) {
    final typography = _Typography();
    return ObsBuilder(
      builder: (context) => MaterialApp(
        showPerformanceOverlay: GlobalState.showPerformanceOverlay.value,
        scaffoldMessengerKey: _messenger,
        title: 'Flutter 示例',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: false, brightness: .light),
        builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
          value: _systemBars,
          child: MyTheme(
            brightness: Brightness.light,
            data: MyThemeData(fontWeight: systemWght),
            child: Scaffold(resizeToAvoidBottomInset: false, body: child),
          ),
        ),
        home: _Shell(typography, this),
      ),
    );
  }
}

class _Shell extends HookWidget {
  const _Shell(this.typography, this.options);
  final _Typography typography;
  final ElExampleApp options;

  @override
  Widget build(BuildContext context) {
    final selected = useState(0);
    final unread = useState({
      for (var i = 0; i < _messages.length; i++)
        if (_messages[i].unread) i,
    });
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final desktop = constraints.maxWidth >= _desktopBreakpoint;
          return Row(
            children: [
              if (desktop)
                _Navigation(
                  typography,
                  selected.value,
                  (i) => selected.value = i,
                  desktop: true,
                ),
              // 保持内容分支的身份，插入侧栏时不重建页面及其 Hook 状态。
              Expanded(
                key: ValueKey('shell-content'),
                child: Column(
                  children: [
                    _TitleBar(
                      _tabs[selected.value],
                      typography,
                      desktop: desktop,
                      centered: !desktop && selected.value == 3,
                      action: selected.value == 3
                          ? null
                          : switch (selected.value) {
                              0 => '搜索内容',
                              1 => '搜索分类',
                              _ => '全部已读',
                            },
                      search: selected.value < 2,
                      onAction: selected.value != 2
                          ? null
                          : () {
                              _toast(
                                unread.value.isEmpty ? '没有未读消息' : '已全部标记为已读',
                              );
                              unread.value = {};
                            },
                    ),
                    Expanded(
                      child: ColoredBox(
                        color: _background,
                        child: Center(
                          child: SizedBox(
                            width: desktop
                                ? (selected.value < 2 ? 1120 : 840)
                                : double.infinity,
                            height: double.infinity,
                            child: Padding(
                              padding: desktop
                                  ? EdgeInsets.all(24)
                                  : EdgeInsets.zero,
                              child: IndexedStack(
                                index: selected.value,
                                children: [
                                  _Home(
                                    typography,
                                    options.networkDelay,
                                    desktop: desktop,
                                  ),
                                  _CategoryPage(typography, desktop: desktop),
                                  _MessagesPage(typography, unread.value, (
                                    index,
                                  ) {
                                    unread.value = {...unread.value}
                                      ..remove(index);
                                    _push(
                                      context,
                                      _ChatPage(
                                        _messages[index].title,
                                        typography,
                                        options.replyDelay,
                                      ),
                                    );
                                  }),
                                  _ProfilePage(typography, options),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (!desktop) ...[
                      _line(),
                      _Navigation(
                        typography,
                        selected.value,
                        (i) => selected.value = i,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

Widget _line({double indent = 0, bool visible = true}) => ElView(
  style: ElStyle(
    height: 0.5,
    width: '100%',
    margin: EdgeInsets.only(left: indent),
    backgroundColor: visible ? _divider : Color(0x00000000),
  ),
);

void _push(BuildContext context, Widget page) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

Future<void> _toast(String text) async {
  _messenger.currentState
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

class _TitleBar extends StatelessWidget {
  const _TitleBar(
    this.title,
    this.typography, {
    this.centered = false,
    this.back = false,
    this.action,
    this.search = false,
    this.onAction,
    this.desktop = false,
  });
  final String title;
  final _Typography typography;
  final bool centered, back, search, desktop;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: .min,
    children: [
      ElCardView(
        key: ValueKey('title-bar'),
        style: ElStyle(height: desktop ? 64 : 44, backgroundColor: _surface),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Align(
              alignment: centered || (back && !desktop)
                  ? Alignment.center
                  : Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(
                  left: desktop ? (back ? 56 : 24) : 12,
                  right: 12,
                ),
                child: _Label(
                  title,
                  typography,
                  key: ValueKey('page-title'),
                  size: desktop ? 20 : 17,
                  weight: .w700,
                  color: _text,
                  maxLines: 1,
                ),
              ),
            ),
            if (back)
              Align(
                alignment: .centerLeft,
                child: ElButtonView(
                  semanticLabel: '返回',
                  key: ValueKey('back'),
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElStyle(
                    width: 44,
                    height: desktop ? 64 : 44,
                    alignment: .center,
                  ),
                  child: _Icon('arrow_back', size: 22, color: _text),
                ),
              ),
            if (action != null)
              Align(
                alignment: .centerRight,
                child: Padding(
                  padding: EdgeInsets.only(right: desktop ? 24 : 12),
                  child: ElButtonView(
                    semanticLabel: action,
                    onPressed: onAction,
                    style: ElStyle(
                      minWidth: desktop && search ? 200 : null,
                      padding: EdgeInsets.symmetric(
                        horizontal: search ? 12 : 8,
                        vertical: search ? 5 : 6,
                      ),
                      backgroundColor: search ? Color(0xfff2f3f5) : null,
                      borderRadius: .circular(14),
                    ),
                    child: _Label(
                      action!,
                      typography,
                      size: 12,
                      color: search ? _tertiary : _primary,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      _line(),
    ],
  );
}

class _Page extends StatelessWidget {
  const _Page(
    this.title,
    this.typography,
    this.child, {
    this.color = _background,
  });
  final String title;
  final _Typography typography;
  final Widget child;
  final Color color;
  @override
  Widget build(BuildContext context) => ElCardView(
    style: ElStyle(backgroundColor: _surface),
    child: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final desktop = constraints.maxWidth >= _desktopBreakpoint;
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              children: [
                _TitleBar(title, typography, back: true, desktop: desktop),
                Expanded(
                  child: ColoredBox(
                    color: color,
                    child: Center(
                      child: SizedBox(
                        width: desktop ? 960 : double.infinity,
                        height: double.infinity,
                        child: Padding(
                          padding: desktop
                              ? EdgeInsets.all(24)
                              : EdgeInsets.zero,
                          child: child,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
}

class _Icon extends StatelessWidget {
  const _Icon(this.name, {this.size = 24, this.color = _secondary});
  final String name;
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _IconPainter(name, color)),
    ),
  );
}

class _IconPainter extends CustomPainter {
  _IconPainter(this.name, this.color);
  final String name;
  final Color color;
  static final _paths = <String, Path>{};
  @override
  void paint(Canvas canvas, Size size) {
    final path = _paths.putIfAbsent(
      name,
      () => parseSvgPathData(_iconPaths[name]!),
    );
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    canvas.drawPath(path, Paint()..color = color);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_IconPainter oldDelegate) =>
      oldDelegate.name != name || oldDelegate.color != color;
}
