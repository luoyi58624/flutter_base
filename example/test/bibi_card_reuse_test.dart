import 'package:example/src/pages/examples/bibi/cards/feed.dart';
import 'package:example/src/widgets/panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_test/flutter_test.dart';

const _firstTitle = '职业选手的极限反打，第一视角复盘';
const _badgeTitle = '从头再看一遍，才发现这五处伏笔';
const _refreshTitle = '画了一个月，把童年的夏天做成动画';

Finder _card() => find.byKey(ValueKey('video-card-host'));
Finder _inside(Finder matching) => find.descendant(of: _card(), matching: matching);
Finder _text(String value) => _inside(find.text(value));
Finder _more() => _inside(find.byType(ElButtonView));
Finder _menuItem(String label) => find.byWidgetPredicate((widget) => widget is ElView && widget.child == label);

Future<_CardHostState> _open(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(390, 800);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  // 预热真实离线图集，图片异步解码不混入换绑身份断言。
  final imageContext = GlobalKey();
  await tester.pumpWidget(MaterialApp(home: SizedBox(key: imageContext)));
  Object? imageError;
  await tester.runAsync(
    () => precacheImage(
      AssetImage('assets/recycler_cards/bili_home.webp'),
      imageContext.currentContext!,
      onError: (error, _) => imageError = error,
    ).timeout(Duration(seconds: 10)),
  );
  expect(imageError, isNull);
  final key = GlobalKey<_CardHostState>();
  await tester.pumpWidget(_CardHost(key: key));
  await tester.pumpAndSettle();
  return key.currentState!;
}

void main() {
  testWidgets('同一卡片宿主跨索引和推荐批次换绑，固定结构与图集配置保持复用', (tester) async {
    final host = await _open(tester);
    final panel = tester.widget(_inside(find.byType(ExamplePanel)));
    final column = tester.widget(_inside(find.byType(Column)).first);
    final aspect = tester.widget(_inside(find.byType(AspectRatio)));
    final image = tester.widget(_inside(find.byType(Image)));
    final imageElement = tester.element(_inside(find.byType(Image)));
    final more = tester.widget(_more());
    final up = tester.widget(_text('UP'));

    for (final (index, generation, title, creator, badge) in [
      (4, 0, _badgeTitle, '放映室第七排', '影视拆解'),
      (0, 1, _refreshTitle, '未完待续动画社', null),
      (0, 0, _firstTitle, '阿洛赛事手记', null),
    ]) {
      host.bind(index, generation);
      await tester.pump();
      expect(_text(title), findsOneWidget);
      expect(_text(creator), findsOneWidget);
      expect(tester.widget(_inside(find.byType(ExamplePanel))), same(panel));
      expect(tester.widget(_inside(find.byType(Column)).first), same(column));
      expect(tester.widget(_inside(find.byType(AspectRatio))), same(aspect));
      expect(tester.widget(_inside(find.byType(Image))), same(image));
      expect(tester.element(_inside(find.byType(Image))), same(imageElement));
      expect(tester.widget(_more()), same(more));
      expect(tester.widget(_text('UP')), same(up));
      final row = tester.widget<Row>(find.ancestor(of: _more(), matching: find.byType(Row)));
      expect(row.spacing, 4);
      expect(row.children.length, badge == null ? 3 : 4, reason: '没有徽标时不能留下额外占位和间距。');
      expect(_text('影视拆解'), badge == null ? findsNothing : findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('只有播放数变化时保留其他文字，相同字段再次换绑不更新叶子配置', (tester) async {
    final host = await _open(tester);
    final unchanged = {
      for (final value in [_firstTitle, '阿洛赛事手记', '17:30', 'UP']) value: tester.widget(_text(value)),
    };
    final oldPlays = tester.widget(_text('4039'));
    final crop = tester.widget(find.ancestor(of: _inside(find.byType(Image)), matching: find.byType(Positioned)));

    // 换一批推荐但保持相同 source，只有播放数随批次更新。
    host.bind(343, 1);
    await tester.pump();
    expect(_text('4039'), findsNothing);
    expect(_text('1.2万'), findsOneWidget);
    expect(tester.widget(_text('1.2万')), isNot(same(oldPlays)));
    for (final entry in unchanged.entries) {
      expect(tester.widget(_text(entry.key)), same(entry.value));
    }
    expect(
      tester.widget(find.ancestor(of: _inside(find.byType(Image)), matching: find.byType(Positioned))),
      same(crop),
    );

    final texts = tester.widgetList<Text>(_inside(find.byType(Text))).toList();
    host.bind(703, 1);
    await tester.pump();
    final rebound = tester.widgetList<Text>(_inside(find.byType(Text))).toList();
    expect(rebound.length, texts.length);
    for (var index = 0; index < texts.length; index++) {
      expect(rebound[index], same(texts[index]));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('卡片点击读取新记录，打开的菜单保持当时的详情与复制目标', (tester) async {
    final host = await _open(tester);
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

    host.bind(4, 0);
    await tester.pump();
    await tester.tap(_text(_badgeTitle));
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byType(AlertDialog), matching: find.text(_badgeTitle)), findsOneWidget);
    await tester.tap(find.text('关闭'));
    await tester.pumpAndSettle();

    host.bind(0, 0);
    await tester.pump();
    await tester.tap(_more());
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing, reason: '更多按钮不能冒泡触发卡片详情。');
    host.bind(4, 0);
    await tester.pump();
    await tester.tap(_menuItem('视频详情'));
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byType(AlertDialog), matching: find.text(_firstTitle)), findsOneWidget);
    await tester.tap(find.text('关闭'));
    await tester.pumpAndSettle();

    await tester.tap(_more());
    await tester.pumpAndSettle();
    host.bind(0, 1);
    await tester.pump();
    await tester.tap(_menuItem('复制标题'));
    await tester.pumpAndSettle();
    expect(copied, _badgeTitle);
    expect(_text(_refreshTitle), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('固定配置仍响应主题字体与文字缩放，标题预留高度同步更新', (tester) async {
    final host = await _open(tester);
    final title = tester.widget(_text(_firstTitle));
    final panel = tester.widget(_inside(find.byType(ExamplePanel)));
    final image = tester.widget(_inside(find.byType(Image)));
    final before = tester.getSize(_card()).height;

    host.changeEnvironment();
    await tester.pumpAndSettle();
    final titleContext = tester.element(_text(_firstTitle));
    final richText = tester.widget<RichText>(find.descendant(of: _text(_firstTitle), matching: find.byType(RichText)));
    final titleBox = tester.widget<SizedBox>(
      find.ancestor(
        of: _text(_firstTitle),
        matching: find.byWidgetPredicate((widget) => widget is SizedBox && widget.height != null),
      ),
    );
    expect(Theme.of(titleContext).brightness, Brightness.dark);
    expect(richText.text.style!.fontFamily, 'serif');
    expect(richText.textScaler.scale(14), 21);
    expect(titleBox.height, closeTo(21 * 2.8, .001));
    expect(tester.getSize(_card()).height, greaterThan(before));
    expect(tester.widget(_text(_firstTitle)), same(title));
    expect(tester.widget(_inside(find.byType(ExamplePanel))), same(panel));
    expect(tester.widget(_inside(find.byType(Image))), same(image));
    expect(tester.takeException(), isNull);
  });
}

class _CardHost extends StatefulWidget {
  // ignore: prefer_const_constructors_in_immutables
  _CardHost({super.key});

  @override
  State<_CardHost> createState() => _CardHostState();
}

class _CardHostState extends State<_CardHost> {
  var _index = 0;
  var _generation = 0;
  var _scale = 1.0;
  var _dark = false;

  void bind(int index, int generation) => setState(() {
    _index = index;
    _generation = generation;
  });

  void changeEnvironment() => setState(() {
    _scale = 1.5;
    _dark = true;
  });

  @override
  Widget build(BuildContext context) => ElComponentProvider(
    components: el.mobileComponents,
    child: MaterialApp(
      navigatorKey: el.navigatorKey,
      theme: ThemeData(platform: .android, brightness: _dark ? .dark : .light, fontFamily: _dark ? 'serif' : 'sans'),
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(size: Size(390, 800), textScaler: TextScaler.linear(_scale)),
          child: Align(
            alignment: .topCenter,
            child: SizedBox(
              key: ValueKey('video-card-host'),
              width: 240,
              child: buildBibiVideoCard(_index, _generation),
            ),
          ),
        ),
      ),
    ),
  );
}
