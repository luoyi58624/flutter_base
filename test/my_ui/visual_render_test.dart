/// 默认字体下的无头栅格化，允许文本随字体度量自然换行。
library;

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_base/src/ui/mobile/components/button/index.dart' as skin;
import 'package:flutter_base/src/ui/mobile/components/tag/index.dart' as skin;
import 'package:flutter_base/src/ui/mobile/components/switch/index.dart' as skin;
import 'package:flutter_base/src/ui/mobile/components/card/index.dart' as skin;
import 'package:flutter_base/src/ui/mobile/components/loading/index.dart' as skin;
import 'package:flutter_base/src/ui/mobile/components/progress/index.dart' as skin;
import 'package:flutter_base/src/ui/mobile/components/skeleton/index.dart' as skin;
import 'package:flutter_base/src/ui/mobile/components/others/divider/index.dart' as skin;

final _output = Directory(Platform.environment['MY_UI_VISUAL_OUT'] ?? '.claude/plan/my-ui-visual');
final _metrics = <String, Object?>{};
final _keys = <String, GlobalKey>{};
var _labelColor = Color(0xff626874);
Widget _record(String id, Widget child) => KeyedSubtree(key: _keys.putIfAbsent(id, () => GlobalKey()), child: child);
Widget _row(String name, List<Widget> children, {double height = 92}) => ConstrainedBox(
  constraints: BoxConstraints(minHeight: height),
  child: Column(
    mainAxisSize: .min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        name,
        style: TextStyle(fontSize: 12, height: 16 / 12, color: _labelColor),
      ),
      SizedBox(height: 8),
      if (children.any((child) => child is Flexible))
        Row(crossAxisAlignment: .start, spacing: 12, children: children)
      else
        Wrap(spacing: 12, runSpacing: 12, children: children),
    ],
  ),
);
Widget _wide(String id, Widget child) => Expanded(child: _record(id, child));
List<Widget> _samples(String id) => switch (id) {
  'button' => [
    _row('primary / outline / text', [
      _record('primary', skin.Button(child: 'Save 保存')),
      _record('outline', skin.Button(variant: skin.ButtonVariant.outline, child: 'Cancel')),
      skin.Button(variant: skin.ButtonVariant.text, child: 'More'),
    ]),
    _row('icons / selected / round', [
      skin.Button(variant: skin.ButtonVariant.icon, icon: 'heart', selected: true, label: 'Favorite'),
      skin.Button(variant: skin.ButtonVariant.bare, icon: 'sun', label: 'Theme'),
      skin.Button(variant: skin.ButtonVariant.round, icon: 'arrow-right', label: 'Next'),
    ]),
    _row('disabled', [
      skin.Button(disabled: true, child: 'Disabled'),
      skin.Button(disabled: true, variant: skin.ButtonVariant.outline, child: 'Disabled'),
    ]),
    _row('loading', [
      skin.Button(loading: true, child: 'Saving'),
      skin.Button(loading: true, variant: skin.ButtonVariant.outline, child: 'Saving'),
    ]),
  ],
  'tag' => [
    _row('display tones: blue / green / orange', [
      _record('blue', skin.Tag(child: 'Blue 蓝')),
      skin.Tag(tone: skin.TagTone.green, child: 'Green'),
      skin.Tag(tone: skin.TagTone.orange, child: 'Orange'),
    ]),
    _row('display tones: red / gray', [
      skin.Tag(tone: skin.TagTone.red, child: 'Red'),
      skin.Tag(tone: skin.TagTone.gray, child: 'Gray'),
    ]),
    _row('selectable: off / on', [
      _record('off', skin.Tag(value: false, child: 'Option')),
      _record('on', skin.Tag(value: true, child: 'Selected')),
    ]),
    _row('disabled: off / on', [
      skin.Tag(value: false, disabled: true, child: 'Option'),
      skin.Tag(value: true, disabled: true, child: 'Selected'),
    ]),
  ],
  'switch' => [
    _row('off / on', [
      _record('off', skin.Switch(value: false, label: 'Off')),
      _record('on', skin.Switch(value: true, label: 'On')),
    ]),
    _row('disabled: off / on', [
      skin.Switch(value: false, label: 'Off', disabled: true),
      skin.Switch(value: true, label: 'On', disabled: true),
    ]),
  ],
  'card' => [
    _row('default card', [
      _wide(
        'default',
        skin.Card(
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
        skin.Card(
          title: 'Open',
          interactive: true,
          child: SizedBox(height: 48, child: Text('Open card')),
        ),
      ),
    ], height: 180),
  ],
  'divider' => [
    _row('solid', [_wide('solid', skin.Divider())], height: 100),
    _row('center label', [_wide('center', skin.Divider(child: 'Divider 分割'))], height: 100),
    _row('start dashed', [
      _wide('dashed', skin.Divider(align: skin.DividerAlign.start, dashed: true, child: 'Start')),
    ], height: 100),
    _row('end label', [_wide('end', skin.Divider(align: skin.DividerAlign.end, child: 'End'))], height: 100),
    _row('vertical', [Text('Left'), skin.Divider(vertical: true), Text('Right')], height: 80),
  ],
  'loading' => [
    _row('small 16 / medium 24 / large 32', [
      _record('small', skin.Loading(size: skin.LoadingSize.small)),
      _record('medium', skin.Loading()),
      _record('large', skin.Loading(size: skin.LoadingSize.large)),
    ]),
    _row('with label', [_record('label', skin.Loading(child: 'Loading 加载中'))]),
  ],
  'progress' => [
    _row('line 40 / buffer 70', [_wide('line', skin.Progress(value: 40, buffer: 70))], height: 76),
    _row('line success', [
      _wide('success', skin.Progress(value: 100, status: skin.ProgressStatus.success)),
    ], height: 76),
    _row('line warning', [_wide('warning', skin.Progress(value: 60, status: skin.ProgressStatus.warning))], height: 76),
    _row('line error', [_wide('error', skin.Progress(value: 30, status: skin.ProgressStatus.error))], height: 76),
    _row('line indeterminate', [_wide('indeterminate', skin.Progress())], height: 76),
    _row('circle 40 / success / error', [
      _record('circle', skin.Progress(value: 40, type: skin.ProgressType.circle, buffer: 70)),
      skin.Progress(value: 100, type: skin.ProgressType.circle, status: skin.ProgressStatus.success),
      skin.Progress(value: 30, type: skin.ProgressType.circle, status: skin.ProgressStatus.error),
    ], height: 148),
    _row('circle indeterminate / hidden readout', [
      skin.Progress(type: skin.ProgressType.circle),
      skin.Progress(value: 60, type: skin.ProgressType.circle, showText: false),
    ], height: 148),
  ],
  'progress-sizes' => [
    for (final size in [40.0, 64.0, 96.0, 128.0])
      _row('circle size ${size.toInt()} / success / error', [
        for (final status in [skin.ProgressStatus.success, skin.ProgressStatus.error])
          _record(
            '${size.toInt()}-${status.name}',
            Builder(
              builder: (context) => ElMobileTheme(
                style: ElStyle(vars: {skin.Progress.$size: size}),
                child: skin.Progress(value: 100, type: skin.ProgressType.circle, status: status),
              ),
            ),
          ),
      ], height: 176),
  ],
  'skeleton' => [
    _row('default: 3 rows', [_wide('default', skin.Skeleton())], height: 176),
    _row('avatar: 3 rows', [_wide('avatar', skin.Skeleton(avatar: true))], height: 176),
    _row('2 rows', [_wide('two', skin.Skeleton(rows: 2))], height: 152),
    _row('loaded content', [_wide('loaded', skin.Skeleton(loading: false, child: Text('Loaded 内容已就绪')))], height: 80),
  ],
  _ => throw ArgumentError(id),
};
Future<void> _save(WidgetTester tester, RenderRepaintBoundary boundary, String name) async {
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await _output.create(recursive: true);
    await File('${_output.path}/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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
          final data = {...ElMobileTheme.lightVars, if (brightness == Brightness.dark) ...ElMobileTheme.darkVars};
          _labelColor = (data[ElTheme.$textSecondary] as Color);
          await tester.pumpWidget(
            MaterialApp(
              // 沿用官方宿主的默认字体，不额外加载或指定字体。
              builder: (context, child) => Material(type: MaterialType.transparency, child: child),
              theme: ThemeData(platform: TargetPlatform.windows),
              home: MediaQuery(
                data: MediaQueryData(
                  size: Size(width, 900),
                  devicePixelRatio: 1,
                  disableAnimations: true,
                  platformBrightness: brightness,
                ),
                child: ElMobileTheme(
                  brightness: brightness,
                  child: RepaintBoundary(
                    key: boundaryKey,
                    child: ColoredBox(
                      color: (data[ElTheme.$bgColor] as Color),
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
                                    style: TextStyle(fontSize: 20, height: 1.6, fontWeight: FontWeight.w600),
                                  ),
                                ),
                                SizedBox(
                                  height: 16,
                                  child: Text(
                                    '${brightness.name} / ${width.toInt()} logical px / DPR 1',
                                    style: TextStyle(
                                      fontSize: 12,
                                      height: 16 / 12,
                                      color: (data[ElTheme.$textSecondary] as Color),
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
            positions[entry.key] = {'x': r.left, 'y': r.top, 'width': r.width, 'height': r.height};
          }
          _metrics[key] = {
            'viewport': [width, 900],
            'dpr': 1,
            'fontFamily': DefaultTextStyle.of(_keys.values.first.currentContext!).style.fontFamily,
            'fontFamilyFallback': (data[ElTheme.$fontFamilyFallback] as List<String>),
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
            'texts': find.byWidgetPredicate((w) => w is ElView && w.child is String).evaluate().map((element) {
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
                'baseline': point.dy + (engine?.computeDistanceToActualBaseline(TextBaseline.alphabetic) ?? 0),
                'paintY': point.dy + (engine?.textPaintOrigin.dy ?? 0),
              };
            }).toList(),
            'glyphs': find.byWidgetPredicate((w) => w.runtimeType.toString() == 'Glyph').evaluate().map((element) {
              final box = element.renderObject! as RenderBox;
              final point = box.localToGlobal(Offset.zero);
              return {'x': point.dx, 'y': point.dy, 'width': box.size.width, 'height': box.size.height};
            }).toList(),
          };
          final boundary = boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;

          await _save(tester, boundary, 'flutter-$key');
          if ((width == 390 && brightness == Brightness.light) || (width == 1440 && brightness == Brightness.dark)) {
            final target = switch (id) {
              'button' => 'primary',
              'tag' || 'switch' => 'off',
              'card' => 'interactive',
              _ => null,
            };
            if (target != null) {
              final targetFinder = find.byKey(_keys[target]!);
              List<Object> appearance() => tester
                  .renderObjectList<ElRenderView>(find.descendant(of: targetFinder, matching: find.byType(ElView)))
                  .map((render) => render.committedResolvedStyle)
                  .toList();
              final initial = appearance();
              final focusHost = find
                  .descendant(
                    of: targetFinder,
                    matching: find.byWidgetPredicate((w) => w is ElView && w.focusNode != null),
                  )
                  .first;
              final node = tester.widget<ElView>(focusHost).focusNode!;
              // 保留真实键盘聚焦，手机默认外观不附带焦点环。
              await tester.sendKeyDownEvent(LogicalKeyboardKey.tab);
              node.requestFocus();
              await tester.pump();
              await tester.sendKeyUpEvent(LogicalKeyboardKey.tab);
              await tester.pumpAndSettle();
              expect(node.hasPrimaryFocus, isTrue);
              expect(appearance(), initial);
              await _save(tester, boundary, 'flutter-state-$key-focus');
              node.unfocus();
              final mouse = await tester.createGesture(kind: ui.PointerDeviceKind.mouse);
              await mouse.addPointer(location: Offset(2, 2));
              final point = tester.getCenter(focusHost);
              await mouse.moveTo(point);
              await tester.pumpAndSettle();
              expect(appearance(), initial);
              await _save(tester, boundary, 'flutter-state-$key-hover');
              await mouse.removePointer();
              final touch = await tester.startGesture(point, kind: ui.PointerDeviceKind.touch);
              await tester.pump(Duration(milliseconds: 300));
              await _save(tester, boundary, 'flutter-state-$key-pressed');
              await touch.up();
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
            }
          }
          await tester.pumpWidget(SizedBox());
          await tester.pumpAndSettle();
        }
        await tester.runAsync(
          () =>
              File('${_output.path}/flutter-metrics.json')
                  .writeAsString(JsonEncoder.withIndent('  ').convert(_metrics)),
        );
      });
    }
  }
}
