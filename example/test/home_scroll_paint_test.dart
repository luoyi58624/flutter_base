// ignore_for_file: avoid_relative_lib_imports
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_test/flutter_test.dart';

import 'home_showcase_test.dart' as fixture;
import '../lib/src/pages/home/showcase/panel.dart';

void main() {
  testWidgets('首页按需挂载章节，稳态滚动复用静态内容', (tester) async {
    await fixture.host(tester);
    final scroll = tester.widget<ElScrollView>(find.byKey(ValueKey('showcase-scroll'))).controller!;
    final viewport = tester.getRect(find.byKey(ValueKey('showcase-scroll')));
    final chapters = <RenderObject, String>{};
    final paintedChapters = <RenderBox>{};
    final previous = debugOnProfilePaint;
    var paints = 0, outside = 0;
    debugOnProfilePaint = (object) {
      paints++;
      if (object is RenderBox && chapters.containsKey(object)) paintedChapters.add(object);
      if (object is RenderBox && object.hasSize && object.attached) {
        final rect = MatrixUtils.transformRect(object.getTransformTo(null), object.paintBounds);
        if (!rect.overlaps(viewport)) outside++;
      }
      previous?.call(object);
    };
    final results = <Map<String, Object>>[];
    try {
      for (final id in ['control-fields', 'control-dates', 'surface-cards', 'feedback-prompts', 'feedback-progress']) {
        paints = outside = 0;
        paintedChapters.clear();
        await fixture.reveal(tester, id);
        final entryPaints = paints, entryOutside = outside;
        chapters
          ..clear()
          ..addEntries(
            find
                .byType(ShowcaseSection, skipOffstage: false)
                .evaluate()
                .map((element) => MapEntry(element.renderObject!, (element.widget as ShowcaseSection).id)),
          );
        await tester.pump(Duration(milliseconds: 500));
        var maxPaints = 0, maxOutside = 0;
        for (var frame = 0; frame < 6; frame++) {
          paints = outside = 0;
          paintedChapters.clear();
          scroll.jumpTo(scroll.offset + 12);
          await tester.pump(Duration(milliseconds: 16));
          // 只检查本帧实际绘制的已挂载章节，不要求未访问章节提前创建。
          for (final chapter in paintedChapters) {
            final rect = MatrixUtils.transformRect(chapter.getTransformTo(null), chapter.paintBounds);
            expect(rect.overlaps(viewport), isTrue, reason: '${chapters[chapter]} 应在视口内');
          }
          maxPaints = math.max(maxPaints, paints);
          maxOutside = math.max(maxOutside, outside);
        }
        results.add({
          'section': id,
          'entryPaints': entryPaints,
          'entryOutside': entryOutside,
          'maxPaints': maxPaints,
          'maxOutside': maxOutside,
        });
        expect(tester.takeException(), isNull);
      }
    } finally {
      debugOnProfilePaint = previous;
    }
    final json = JsonEncoder.withIndent('  ').convert(results);
    debugPrint(json);
    final report = Platform.environment['HOME_PAINT_REPORT'];
    if (report != null) File(report).writeAsStringSync(json);
    await tester.pumpWidget(SizedBox());
    await tester.pump(Duration(seconds: 4));
    for (final result in results) {
      expect(result['maxPaints'], lessThan(400), reason: '${result['section']} 稳态滚动复用静态内容');
      expect(result['maxOutside'], lessThan(200), reason: '${result['section']} 不应重复绘制整段屏外内容');
    }
  });

  testWidgets('逐卡挂载，离屏卸载后恢复初始值', (tester) async {
    await tester.runAsync(fixture.loadShowcaseFonts);
    await fixture.host(tester);
    final nickname = find.byWidgetPredicate(
      (widget) => widget is ElInput && widget.semanticLabel == '昵称',
      skipOffstage: false,
    );
    final upload = find.byWidgetPredicate(
      (widget) => widget is ShowcasePanel && widget.title.contains('上传'),
      skipOffstage: false,
    );
    await fixture.reveal(tester, 'control-nickname');
    expect(upload, findsNothing, reason: '同章远处的上传示例不参与构建');
    final element = tester.element(nickname);
    tester.widget<ElInput>(nickname).modelValue!.value = '临时昵称';
    await tester.pump();

    await fixture.reveal(tester, 'feedback-progress');
    expect(element.mounted, isFalse);
    expect(nickname, findsNothing);
    final progress = find.byWidgetPredicate(
      (widget) => widget is ShowcasePanel && widget.title == '任务进度',
      skipOffstage: false,
    );
    final progressElement = tester.element(progress);
    await fixture.reveal(tester, 'control-nickname');
    expect(progressElement.mounted, isFalse);
    expect(progress, findsNothing);
    expect(tester.element(nickname), isNot(same(element)));
    expect(tester.widget<ElInput>(nickname).modelValue!.value, '小蓝同学');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox());
    await tester.pump(Duration(seconds: 4));
  });
}
