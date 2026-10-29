import 'dart:convert';

import 'package:flutter_base/ui.dart';
import 'package:flutter_base/src/ui/cores/image/render/render_image_view.dart';
import 'package:flutter_base/src/ui/cores/selection/common/selection_core.dart';
import 'package:flutter_base/src/ui/cores/selection/docs/selection_view.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(
  home: Align(
    alignment: .topLeft,
    child: SizedBox(width: 320, height: 180, child: child),
  ),
);

final _imageBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAACklEQVR4AWMAAQAABQABDQottAAAAABJRU5ErkJggg==',
);

class _CountingContent extends LeafRenderObjectWidget {
  const _CountingContent(this.onRead);

  final VoidCallback onRead;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _CountingRender(onRead)..selectionParticipant.bindSelectionRegistrar(SelectionContainer.maybeOf(context));
  }

  @override
  void updateRenderObject(BuildContext context, _CountingRender renderObject) {
    renderObject.selectionParticipant.bindSelectionRegistrar(SelectionContainer.maybeOf(context));
  }
}

class _CountingRender extends RenderBox implements SelectionParticipantHost {
  _CountingRender(VoidCallback onRead) {
    final content = AtomicSelectionContent(
      selectionContentKind: SelectionContentKind.text,
      sizeOf: () => size,
      plainTextOf: () {
        onRead();
        return 'content';
      },
    );
    selectionParticipant = BoundSelectionParticipant(box: this, contentOf: () => content);
  }

  @override
  late final BoundSelectionParticipant selectionParticipant;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    selectionParticipant.reattachSelectionRoot();
  }

  @override
  void detach() {
    selectionParticipant.detachFromSelectionRoot();
    super.detach();
  }

  @override
  void dispose() {
    selectionParticipant.dispose();
    super.dispose();
  }

  @override
  void performLayout() {
    size = constraints.constrain(Size(120, 30));
    selectionParticipant.updateSelectionGeometry();
  }

  @override
  bool hitTestSelf(Offset position) => true;
}

void main() {
  testWidgets('已选图片同尺寸更新替代文本会主动通知控制器与回调', (tester) async {
    final controller = ElSelectionController();
    addTearDown(controller.dispose);
    final changes = <String?>[];
    var notifications = 0;
    controller.addListener(() => notifications++);
    await tester.pumpWidget(
      _host(
        ElSelectionView(
          controller: controller,
          onSelectionChanged: changes.add,
          child: ElImageView.memory(_imageBytes, width: 24, height: 24, alt: 'before'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    controller.selectAll();
    await tester.pump();
    expect(changes.last, 'before');
    notifications = 0;

    final image = tester.allRenderObjects.whereType<RenderImageView>().toSet().single;
    final size = image.size;
    image.alt = 'after';
    await tester.pump();
    expect(changes.last, 'after', reason: '通知必须主动发生，不能靠读取 controller.text 刷新');
    expect(notifications, 1);
    expect(image.size, size);
    expect(image.currentSelectionRange, TextRange(start: 0, end: 1));

    image.alt = '';
    await tester.pump();
    expect(changes.last, '');
    expect(controller.hasSelection, isTrue);
  });

  testWidgets('图片缺少替代文本时源地址更新也会刷新选择文本', (tester) async {
    final controller = ElSelectionController();
    addTearDown(controller.dispose);
    final changes = <String?>[];
    await tester.pumpWidget(
      _host(
        ElSelectionView(
          controller: controller,
          onSelectionChanged: changes.add,
          child: ElImageView.memory(_imageBytes, width: 24, height: 24, src: 'before.png'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    controller.selectAll();
    await tester.pump();
    final image = tester.allRenderObjects.whereType<RenderImageView>().toSet().single;
    expect(changes.last, 'before.png');
    image.src = 'after.png';
    await tester.pump();
    expect(changes.last, 'after.png');

    image.alt = 'caption';
    await tester.pump();
    final count = changes.length;
    image.src = 'unused.png';
    await tester.pump();
    expect(changes.length, count, reason: '源地址变化不应重复通知相同的有效选择文本');
  });

  testWidgets('无订阅的鼠标拖选和结束不提取文本，getter与复制按需读取', (tester) async {
    final controller = ElSelectionController();
    addTearDown(controller.dispose);
    var reads = 0;
    String? clipboard;
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') clipboard = (call.arguments as Map)['text'] as String?;
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.pumpWidget(_host(ElSelectionView(controller: controller, child: _CountingContent(() => reads++))));
    await tester.pumpAndSettle();
    reads = 0;

    final pointer = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await pointer.down(Offset(5, 15));
    await tester.pump();
    await pointer.moveTo(Offset(300, 15));
    await tester.pump();
    await pointer.up();
    await pointer.removePointer();
    await tester.pump();
    final root = tester.allRenderObjects.whereType<RenderSelectionView>().toSet().single;
    expect(root.document.value.status, SelectionStatus.uncollapsed);
    expect(reads, 0, reason: '没有选择文本消费者时只维护官方范围和几何');

    final end = root.endpoints!.end.globalBottom;
    root.beginHandleDrag(SelectionHandleSide.end, end);
    root.updateHandleDrag(end - Offset(20, 0));
    await tester.pump();
    root.endHandleDrag();
    expect(reads, 0, reason: '句柄结束同样不能为未订阅文档提取文本');

    expect(controller.text, 'content');
    expect(reads, greaterThan(0));
    reads = 0;
    await controller.copy();
    expect(clipboard, 'content');
    expect(reads, greaterThan(0));
  });
}
