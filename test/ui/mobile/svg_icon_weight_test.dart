import 'dart:io';
import 'dart:ui' show ImageByteFormat;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_base/desktop.dart' show ElDesktopIcons;
import 'package:flutter_base/mobile.dart';
import 'package:flutter_test/flutter_test.dart';

Future<List<double>> _inkCoverage(WidgetTester tester, GlobalKey boundaryKey, int count) async {
  return (await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(boundaryKey));
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final bytes = (await image.toByteData(format: ImageByteFormat.rawRgba))!;
      final coverage = List<double>.filled(count, 0);
      // 透明背景上的 alpha 总量是实际笔画覆盖面积，不依赖截图基准文件。
      for (var y = 0; y < image.height; y++) {
        for (var x = 0; x < image.width; x++) {
          final index = (y ~/ 64) * 7 + x ~/ 64;
          if (index < count) coverage[index] += bytes.getUint8((y * image.width + x) * 4 + 3) / 255;
        }
      }
      return coverage;
    } finally {
      image.dispose();
    }
  }))!;
}

void main() {
  test('两端图标集合覆盖全部公开图标声明', () {
    final source = File('lib/src/ui/mobile/commons/icons.dart').readAsStringSync();
    final names = RegExp(r'static const Widget (\w+)\b').allMatches(source).map((match) => match[1]!);
    expect(ElMobileIcons.values.keys, unorderedEquals(names));
    final desktopSource = File('lib/src/ui/desktop/commons/icons.dart').readAsStringSync();
    final desktopNames = RegExp(r'static const IconData (\w+)\b').allMatches(desktopSource).map((match) => match[1]!);
    expect(ElDesktopIcons.values.keys, unorderedEquals(desktopNames));
  });

  testWidgets('祖先 wght 改变全部 SVG 的实际像素覆盖，动态清除后回退 fontWeight 且局部轴优先', (tester) async {
    final boundaryKey = GlobalKey();
    final entries = ElMobileIcons.values.entries.toList();
    final count = entries.length + 1;
    var builds = 0;
    double? weight = 400;
    late StateSetter update;
    final shelf = RepaintBoundary(
      key: boundaryKey,
      child: Builder(
        builder: (_) {
          builds++;
          return SizedBox(
            width: 7 * 64,
            height: ((count + 6) ~/ 7) * 64,
            child: Wrap(
              children: [
                for (final entry in entries) SizedBox.square(dimension: 64, child: Center(child: entry.value)),
                SizedBox.square(
                  dimension: 64,
                  child: Center(
                    child: ElView(
                      style: ElStyle(fontVariationSettings: [FontVariation('wght', 350)]),
                      child: ElMobileIcons.add,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
    await tester.pumpWidget(
      Directionality(
        textDirection: .ltr,
        child: Center(
          child: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return ElView(
                style: ElStyle(
                  iconSize: 48,
                  iconColor: Color(0xff000000),
                  fontVariationSettings: weight == null ? null : [FontVariation('wght', weight!)],
                ),
                child: ElView(
                  style: ElStyle(fontWeight: .w600),
                  child: shelf,
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final normal = await _inkCoverage(tester, boundaryKey, count);
    final glyph = tester.renderObject(find.byWidget(ElMobileIcons.add).first);

    update(() => weight = 600);
    await tester.pumpAndSettle();
    final heavy = await _inkCoverage(tester, boundaryKey, count);
    for (var index = 0; index < entries.length; index++) {
      expect(normal[index], greaterThan(0), reason: entries[index].key);
      expect(heavy[index], greaterThan(normal[index]), reason: '${entries[index].key} 应有更多实际笔画覆盖');
    }
    expect(heavy.last, normal.last, reason: '局部 wght=350 不受祖先变化影响');
    expect(tester.renderObject(find.byWidget(ElMobileIcons.add).first), same(glyph));
    expect(tester.getSize(find.byWidget(ElMobileIcons.add).first), Size.square(48));
    expect(builds, 1);

    update(() => weight = null);
    await tester.pumpAndSettle();
    expect(await _inkCoverage(tester, boundaryKey, count), heavy, reason: '清除 wght 后回退到中间祖先的 fontWeight.w600');
    update(() => weight = 400);
    await tester.pumpAndSettle();
    expect(await _inkCoverage(tester, boundaryKey, count), normal, reason: '恢复 wght=400 后像素覆盖应完全恢复');
    expect(builds, 1);
    expect(tester.takeException(), isNull);

    final ratios = [for (var index = 0; index < entries.length; index++) heavy[index] / normal[index]];
    final smallest = ratios.reduce((a, b) => a < b ? a : b);
    final largest = ratios.reduce((a, b) => a > b ? a : b);
    debugPrint(
      '${entries.length} 个 SVG：wght 400→600，实际笔画覆盖为 ${smallest.toStringAsFixed(3)}～${largest.toStringAsFixed(3)} 倍',
    );
  });
}
