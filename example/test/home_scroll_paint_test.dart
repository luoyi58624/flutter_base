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
    final scroll = tester.widget<ElScrollView>(find.byKey(PageStorageKey('showcase-scroll'))).controller!;
    final viewport = tester.getRect(find.byKey(PageStorageKey('showcase-scroll')));
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

  testWidgets('跨断点保留输入实例，离屏反馈示例暂停动画', (tester) async {
    await tester.runAsync(fixture.loadShowcaseFonts);
    await fixture.host(tester);
    expect(tester.takeException(), isNull, reason: '首次挂载');
    await fixture.reveal(tester, 'control-fields');
    final nickname = find.byWidgetPredicate(
      (widget) => widget is ElInput && widget.semanticLabel == '昵称',
      skipOffstage: false,
    );
    final element = tester.element(nickname);
    final model = tester.widget<ElInput>(nickname).modelValue!;
    model.value = '保留的昵称';
    await tester.pump();
    tester.view.physicalSize = Size(1440, 900);
    await tester.pump();
    await tester.pump(Duration(milliseconds: 500));
    expect(tester.takeException(), isNull, reason: '切换宽屏');
    expect(tester.element(nickname), same(element));
    expect(tester.widget<ElInput>(nickname).modelValue!.value, '保留的昵称');
    tester.view.physicalSize = Size(390, 900);
    await tester.pump();
    await tester.pump(Duration(milliseconds: 500));
    expect(tester.takeException(), isNull, reason: '切回手机');
    expect(tester.element(nickname), same(element));
    await fixture.reveal(tester, 'feedback-state');
    final indefinite = find.byWidgetPredicate(
      (widget) => widget is ElProgress && widget.semanticLabel == '等待服务器响应',
      skipOffstage: false,
    );
    bool running() => TickerMode.valuesOf(tester.element(indefinite)).enabled;
    expect(running(), isFalse);
    final scroll = tester.widget<ElScrollView>(find.byKey(PageStorageKey('showcase-scroll'))).controller!;
    Future<void> showPanel(String title) async {
      final panel = find.byWidgetPredicate(
        (widget) => widget is ShowcasePanel && widget.title == title,
        skipOffstage: false,
      );
      final target = tester.renderObject(panel);
      scroll.jumpTo(RenderAbstractViewport.of(target).getOffsetToReveal(target, 0).offset - 20);
      await tester.pump();
      await tester.pump(Duration(milliseconds: 500));
      await tester.pump();
    }

    final progress = tester.renderObject(indefinite);
    scroll.jumpTo(RenderAbstractViewport.of(progress).getOffsetToReveal(progress, 0).offset - 20);
    await tester.pump();
    await tester.pump(Duration(milliseconds: 500));
    await tester.pump();
    expect(running(), isTrue);
    await showPanel('提示箭头');
    expect(running(), isFalse);
    expect(tester.binding.transientCallbackCount, 0);
    await fixture.reveal(tester, 'control-fields');
    expect(tester.element(nickname), same(element), reason: '章节进入回收池再返回仍保留输入实例');
    expect(tester.widget<ElInput>(nickname).modelValue!.value, '保留的昵称');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox());
    await tester.pump(Duration(seconds: 4));
  });
}
