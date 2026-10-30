/// 首批组件真实无头栅格化；画布、插槽和状态与视觉参照fixture.js一致。
library;

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_base/src/my_ui/index.dart';
import 'package:flutter_base/ui.dart';

final _output = Directory(
  Platform.environment['MY_UI_VISUAL_OUT'] ?? '.claude/plan/my-ui-visual',
);
final _metrics = <String, Object?>{};
final _keys = <String, GlobalKey>{};
var _labelColor = Color(0xff626874);
Widget _record(String id, Widget child) =>
    KeyedSubtree(key: _keys.putIfAbsent(id, () => GlobalKey()), child: child);
Widget _row(String name, List<Widget> children, {double height = 92}) =>
    SizedBox(
      height: height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: TextStyle(
              fontFamily: 'Arial',
              fontSize: 12,
              height: 16 / 12,
              color: _labelColor,
            ),
          ),
          SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 12,
            children: children,
          ),
        ],
      ),
    );
Widget _wide(String id, Widget child) => Expanded(child: _record(id, child));
List<Widget> _samples(String id) => switch (id) {
  'button' => [
    _row('primary / outline / text', [
      _record('primary', MyButton(child: 'Save 保存')),
      _record(
        'outline',
        MyButton(variant: MyButtonVariant.outline, child: 'Cancel'),
      ),
      MyButton(variant: MyButtonVariant.text, child: 'More'),
    ]),
    _row('icons / selected / round', [
      MyButton(
        variant: MyButtonVariant.icon,
        icon: 'heart',
        selected: true,
        label: 'Favorite',
      ),
      MyButton(variant: MyButtonVariant.bare, icon: 'sun', label: 'Theme'),
      MyButton(
        variant: MyButtonVariant.round,
        icon: 'arrow-right',
        label: 'Next',
      ),
    ]),
    _row('disabled', [
      MyButton(disabled: true, child: 'Disabled'),
      MyButton(
        disabled: true,
        variant: MyButtonVariant.outline,
        child: 'Disabled',
      ),
    ]),
    _row('loading', [
      MyButton(loading: true, child: 'Saving'),
      MyButton(
        loading: true,
        variant: MyButtonVariant.outline,
        child: 'Saving',
      ),
    ]),
  ],
  'tag' => [
    _row('display tones: blue / green / orange', [
      _record('blue', MyTag(child: 'Blue 蓝')),
      MyTag(tone: MyTagTone.green, child: 'Green'),
      MyTag(tone: MyTagTone.orange, child: 'Orange'),
    ]),
    _row('display tones: red / gray', [
      MyTag(tone: MyTagTone.red, child: 'Red'),
      MyTag(tone: MyTagTone.gray, child: 'Gray'),
    ]),
    _row('selectable: off / on', [
      _record('off', MyTag(value: false, child: 'Option')),
      _record('on', MyTag(value: true, child: 'Selected')),
    ]),
    _row('disabled: off / on', [
      MyTag(value: false, disabled: true, child: 'Option'),
      MyTag(value: true, disabled: true, child: 'Selected'),
    ]),
  ],
  'switch' => [
    _row('off / on', [
      _record('off', MySwitch(value: false, label: 'Off')),
      _record('on', MySwitch(value: true, label: 'On')),
    ]),
    _row('disabled: off / on', [
      MySwitch(value: false, label: 'Off', disabled: true),
      MySwitch(value: true, label: 'On', disabled: true),
    ]),
  ],
  'card' => [
    _row('default card', [
      _wide(
        'default',
        MyCard(
          title: 'Card 标题',
          description: 'Description / 说明',
          sample: '01',
          child: SizedBox(height: 48, child: Text('Body 内容')),
        ),
      ),
    ], height: 242),
    _row('interactive card', [
      _wide(
        'interactive',
        MyCard(
          title: 'Open',
          interactive: true,
          child: SizedBox(height: 48, child: Text('Open card')),
        ),
      ),
    ], height: 180),
  ],
  'divider' => [
    _row('solid', [_wide('solid', MyDivider())], height: 100),
    _row('center label', [
      _wide('center', MyDivider(child: 'Divider 分割')),
    ], height: 100),
    _row('start dashed', [
      _wide(
        'dashed',
        MyDivider(align: MyDividerAlign.start, dashed: true, child: 'Start'),
      ),
    ], height: 100),
    _row('end label', [
      _wide('end', MyDivider(align: MyDividerAlign.end, child: 'End')),
    ], height: 100),
    _row('vertical', [
      Text('Left'),
      MyDivider(vertical: true),
      Text('Right'),
    ], height: 80),
  ],
  'loading' => [
    _row('small 16 / medium 24 / large 32', [
      _record('small', MyLoading(size: MyLoadingSize.small)),
      _record('medium', MyLoading()),
      _record('large', MyLoading(size: MyLoadingSize.large)),
    ]),
    _row('with label', [_record('label', MyLoading(child: 'Loading 加载中'))]),
  ],
  'progress' => [
    _row('line 40 / buffer 70', [
      _wide('line', MyProgress(value: 40, buffer: 70)),
    ], height: 76),
    _row('line success', [
      _wide(
        'success',
        MyProgress(value: 100, status: MyProgressStatus.success),
      ),
    ], height: 76),
    _row('line warning', [
      _wide('warning', MyProgress(value: 60, status: MyProgressStatus.warning)),
    ], height: 76),
    _row('line error', [
      _wide('error', MyProgress(value: 30, status: MyProgressStatus.error)),
    ], height: 76),
    _row('line indeterminate', [
      _wide('indeterminate', MyProgress()),
    ], height: 76),
    _row('circle 40 / success / error', [
      _record(
        'circle',
        MyProgress(value: 40, type: MyProgressType.circle, buffer: 70),
      ),
      MyProgress(
        value: 100,
        type: MyProgressType.circle,
        status: MyProgressStatus.success,
      ),
      MyProgress(
        value: 30,
        type: MyProgressType.circle,
        status: MyProgressStatus.error,
      ),
    ], height: 148),
    _row('circle indeterminate / hidden readout', [
      MyProgress(type: MyProgressType.circle),
      MyProgress(value: 60, type: MyProgressType.circle, showText: false),
    ], height: 148),
  ],
  'progress-sizes' => [
    for (final size in [40.0, 64.0, 96.0, 128.0])
      _row('circle size ${size.toInt()} / success / error', [
        for (final status in [MyProgressStatus.success, MyProgressStatus.error])
          _record(
            '${size.toInt()}-${status.name}',
            Builder(
              builder: (context) => MyTheme(
                data: MyTheme.of(context).copyWith(progressSize: size),
                child: MyProgress(
                  value: 100,
                  type: MyProgressType.circle,
                  status: status,
                ),
              ),
            ),
          ),
      ], height: 176),
  ],
  'skeleton' => [
    _row('default: 3 rows', [_wide('default', MySkeleton())], height: 176),
    _row('avatar: 3 rows', [
      _wide('avatar', MySkeleton(avatar: true)),
    ], height: 176),
    _row('2 rows', [_wide('two', MySkeleton(rows: 2))], height: 152),
    _row('loaded content', [
      _wide('loaded', MySkeleton(loading: false, child: Text('Loaded 内容已就绪'))),
    ], height: 80),
  ],
  _ => throw ArgumentError(id),
};
Future<void> _loadFonts() async {
  final sdk = Platform.environment['MY_UI_SDK'] ?? 'D:/app/fvm/versions/stable';
  for (final entry in <String, List<String>>{
    'Arial': ['C:/Windows/Fonts/arial.ttf', 'C:/Windows/Fonts/arialbd.ttf'],
    'Times New Roman': [
      'C:/Windows/Fonts/times.ttf',
      'C:/Windows/Fonts/timesbd.ttf',
      'C:/Windows/Fonts/timesi.ttf',
      'C:/Windows/Fonts/timesbi.ttf',
    ],
    'SimSun': ['C:/Windows/Fonts/simsun.ttc'],
    'Microsoft YaHei': [
      'C:/Windows/Fonts/msyh.ttc',
      'C:/Windows/Fonts/msyhbd.ttc',
    ],
    'Roboto': [
      '$sdk/bin/cache/artifacts/material_fonts/roboto-regular.ttf',
      '$sdk/bin/cache/artifacts/material_fonts/roboto-medium.ttf',
      '$sdk/bin/cache/artifacts/material_fonts/roboto-bold.ttf',
    ],
  }.entries) {
    final loader = FontLoader(entry.key);
    for (final file in entry.value) {
      final bytes = await File(file).readAsBytes();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }
}

Future<void> _save(
  WidgetTester tester,
  RenderRepaintBoundary boundary,
  String name,
) async {
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await _output.create(recursive: true);
    await File('${_output.path}/$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadFonts);
  for (final width in [390.0, 1440.0]) {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      testWidgets('真实渲染 ${width.toInt()} ${brightness.name}', (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 900);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        for (final id in [
          'button',
          'tag',
          'switch',
          'card',
          'divider',
          'loading',
          'progress',
          'progress-sizes',
          'skeleton',
        ]) {
          _keys.clear();
          final boundaryKey = GlobalKey();
          final data = MyThemeData(brightness: brightness);
          _labelColor = data.textSecondary;
          await tester.pumpWidget(
            MaterialApp(
              // 仅提供Material宿主；字体由MyTheme建立，避免宿主覆盖复验契约。
              builder: (context, child) =>
                  Material(type: MaterialType.transparency, child: child),
              theme: ThemeData(
                platform: TargetPlatform.windows,
                fontFamilyFallback: ['Microsoft YaHei'],
              ),
              home: MediaQuery(
                data: MediaQueryData(
                  size: Size(width, 900),
                  devicePixelRatio: 1,
                  disableAnimations: true,
                  platformBrightness: brightness,
                ),
                child: MyTheme(
                  brightness: brightness,
                  child: RepaintBoundary(
                    key: boundaryKey,
                    child: ColoredBox(
                      color: data.background,
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: SizedBox(
                            width: 720,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  height: 32,
                                  child: Text(
                                    '${id[0].toUpperCase()}${id.substring(1)}',
                                    style: TextStyle(
                                      fontFamily: 'Arial',
                                      fontSize: 20,
                                      height: 1.6,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  height: 16,
                                  child: Text(
                                    '${brightness.name} / ${width.toInt()} logical px / DPR 1',
                                    style: TextStyle(
                                      fontFamily: 'Arial',
                                      fontSize: 12,
                                      height: 16 / 12,
                                      color: data.textSecondary,
                                    ),
                                  ),
                                ),
                                SizedBox(height: 24),
                                ..._samples(id),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '$id 布局与绘制应无异常');
          final key = '$id-${width.toInt()}-${brightness.name}';
          final positions = <String, Object?>{};
          for (final entry in _keys.entries) {
            final r = tester.getRect(find.byKey(entry.value));
            positions[entry.key] = {
              'x': r.left,
              'y': r.top,
              'width': r.width,
              'height': r.height,
            };
          }
          _metrics[key] = {
            'viewport': [width, 900],
            'dpr': 1,
            'fontFamily': DefaultTextStyle.of(
              _keys.values.first.currentContext!,
            ).style.fontFamily,
            'fontFamilyFallback': data.fontFamilyFallback,
            'positions': positions,
            'officialTexts': find.byType(RichText).evaluate().map((element) {
              final box = element.renderObject! as RenderParagraph;
              final point = box.localToGlobal(Offset.zero);
              return {
                'text': box.text.toPlainText(),
                'x': point.dx,
                'y': point.dy,
                'width': box.size.width,
                'height': box.size.height,
                'fontFamily': box.text.style?.fontFamily,
                'lineHeight': box.text.style?.height,
              };
            }).toList(),
            'texts': find
                .byWidgetPredicate((w) => w is ElView && w.child is String)
                .evaluate()
                .map((element) {
                  final box = element.renderObject! as ElRenderView;
                  final engine = box.textEngineForTest;
                  final text = box.committedResolvedStyle.inheritedText;
                  final point = box.localToGlobal(Offset.zero);
                  return {
                    'text': (element.widget as ElView).child,
                    'x': point.dx,
                    'y': point.dy,
                    'width': box.size.width,
                    'height': box.size.height,
                    'fontFamily': text.fontFamily,
                    'fontFamilyFallback': text.fontFamilyFallback,
                    'fontSize': text.fontSize,
                    'fontWeight': text.fontWeight?.value,
                    'lineHeight': text.lineHeight,
                    'baseline':
                        point.dy +
                        (engine?.computeDistanceToActualBaseline(
                              TextBaseline.alphabetic,
                            ) ??
                            0),
                    'paintY': point.dy + (engine?.textPaintOrigin.dy ?? 0),
                  };
                })
                .toList(),
            'glyphs': find
                .byWidgetPredicate((w) => w.runtimeType.toString() == 'MyGlyph')
                .evaluate()
                .map((element) {
                  final box = element.renderObject! as RenderBox;
                  final point = box.localToGlobal(Offset.zero);
                  return {
                    'x': point.dx,
                    'y': point.dy,
                    'width': box.size.width,
                    'height': box.size.height,
                  };
                })
                .toList(),
          };
          final boundary =
              boundaryKey.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;

          await _save(tester, boundary, 'flutter-$key');
          if ((width == 390 && brightness == Brightness.light) ||
              (width == 1440 && brightness == Brightness.dark)) {
            final target = switch (id) {
              'button' => 'primary',
              'tag' || 'switch' => 'off',
              'card' => 'interactive',
              _ => null,
            };
            if (target != null) {
              final targetFinder = find.byKey(_keys[target]!);
              final focusHost = find
                  .descendant(
                    of: targetFinder,
                    matching: find.byWidgetPredicate(
                      (w) => w is ElView && w.focusNode != null,
                    ),
                  )
                  .first;
              final node = tester.widget<ElView>(focusHost).focusNode!;
              // 焦点环识别本次Tab换焦，不能用程序化requestFocus冒充键盘导航。
              await tester.sendKeyDownEvent(LogicalKeyboardKey.tab);
              node.requestFocus();
              await tester.pump();
              await tester.sendKeyUpEvent(LogicalKeyboardKey.tab);
              await tester.pumpAndSettle();
              expect(node.hasPrimaryFocus, isTrue);
              await _save(tester, boundary, 'flutter-state-$key-focus');
              node.unfocus();
              final mouse = await tester.createGesture(
                kind: ui.PointerDeviceKind.mouse,
              );
              await mouse.addPointer(location: Offset(2, 2));
              final point = tester.getCenter(targetFinder);
              await mouse.moveTo(point);
              await tester.pumpAndSettle();
              await _save(tester, boundary, 'flutter-state-$key-hover');
              await mouse.down(point);
              await tester.pump(Duration(milliseconds: 300));
              await _save(tester, boundary, 'flutter-state-$key-pressed');
              await mouse.up();
              await mouse.removePointer();
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
            }
          }
          await tester.pumpWidget(SizedBox());
          await tester.pumpAndSettle();
        }
        await tester.runAsync(
          () => File('${_output.path}/flutter-metrics.json')
              .writeAsString(JsonEncoder.withIndent('  ').convert(_metrics)),
        );
      });
    }
  }
}
