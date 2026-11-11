import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_base/src/ui/testing/ui_test_api.dart';
import 'package:flutter_test/flutter_test.dart';

final _textKey = ValueKey('relayout-selection-text');
final _toolbarKey = ValueKey('relayout-selection-toolbar');

class _ToolbarControls extends SelectionControls {
  _ToolbarControls(this.onTap)
    : super(
        longPressDelay: Duration(milliseconds: 10),
        longPressSelection: LongPressSelection.word,
        showHandles: true,
        showMagnifier: false,
        showToolbar: true,
      );

  final VoidCallback onTap;

  @override
  Widget buildToolbar(BuildContext context, SelectionToolbarDetails details) => ElView(
    key: _toolbarKey,
    style: .new(width: 140, height: 32, backgroundColor: Colors.blue),
    event: ElEvent(onTap: (_) => onTap()),
    child: '复制',
  );
}

// 模拟宿主仍保留在树中，但其所在分支暂不参与布局和绘制。
class _WithheldLayout extends SingleChildRenderObjectWidget {
  // ignore: prefer_const_constructors_in_immutables
  _WithheldLayout({required this.layoutChild, required super.child});

  final bool layoutChild;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderWithheldLayout(layoutChild);

  @override
  void updateRenderObject(BuildContext context, covariant _RenderWithheldLayout renderObject) {
    renderObject.layoutChild = layoutChild;
  }
}

class _RenderWithheldLayout extends RenderProxyBox {
  _RenderWithheldLayout(this._layoutChild);

  bool _layoutChild;

  set layoutChild(bool value) {
    if (_layoutChild == value) return;
    _layoutChild = value;
    markNeedsLayout();
    markNeedsSemanticsUpdate();
  }

  @override
  void performLayout() {
    if (_layoutChild) {
      super.performLayout();
    } else {
      size = constraints.biggest;
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_layoutChild) super.paint(context, offset);
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    if (_layoutChild) super.visitChildrenForSemantics(visitor);
  }
}

void main() {
  testWidgets('已显示工具栏遇到预测返回式祖先 Transform 重建，取消后恢复位置与点击', (tester) async {
    final controller = ElSelectionController();
    final stage = GlobalKey();
    var generation = 0;
    var taps = 0;
    late StateSetter rebuild;
    final controls = _ToolbarControls(() => taps++);
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
    addTearDown(() => messenger.setMockMethodCallHandler(SystemChannels.platform, null));
    addTearDown(controller.dispose);
    addTearDown(() => tester.pumpWidget(SizedBox()));

    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: .topLeft,
          child: Padding(
            padding: .only(left: 80, top: 120),
            child: SizedBox(
              width: 320,
              height: 180,
              child: StatefulBuilder(
                builder: (context, setState) {
                  rebuild = setState;
                  final content = SelectionChromeSlotHost(
                    key: stage,
                    child: Padding(
                      padding: .only(top: 56),
                      child: SelectionView(
                        controller: controller,
                        controls: controls,
                        child: ElView(
                          key: _textKey,
                          style: .new(padding: .all(16), fontSize: 18),
                          child: 'alpha beta gamma delta',
                        ),
                      ),
                    ),
                  );
                  if (generation == 0) return content;
                  return Transform(
                    key: ValueKey(generation),
                    alignment: .center,
                    transform: Matrix4.identity()
                      ..translateByDouble(48, 20, 0, 1)
                      ..scaleByDouble(.9, .9, 1, 1),
                    child: content,
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    final gesture = await tester.createGesture(kind: PointerDeviceKind.touch);
    addTearDown(gesture.removePointer);
    await gesture.down(tester.getTopLeft(find.byKey(_textKey)) + Offset(28, 25));
    await tester.pump(Duration(milliseconds: 10));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(controller.text, 'alpha');
    expect(find.byKey(_toolbarKey), findsOneWidget);
    expect(find.byKey(_toolbarKey).hitTestable(), findsOneWidget);
    final before = tester.getRect(find.byKey(_toolbarKey));

    for (final value in [1, 2, 0]) {
      rebuild(() => generation = value);
      await tester.pump();
      expect(tester.takeException(), isNull, reason: '旧宿主已有 size，新 Transform 尚未布局时不可读取祖先坐标');
      await tester.pumpAndSettle();
      expect(controller.text, 'alpha');
      expect(find.byKey(_toolbarKey).hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    }

    final restored = tester.getRect(find.byKey(_toolbarKey));
    expect(restored.left, closeTo(before.left, .01));
    expect(restored.top, closeTo(before.top, .01));
    expect(restored.size, before.size);
    await tester.tap(find.byKey(_toolbarKey));
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(controller.text, 'alpha');
  });

  testWidgets('一直未布局的宿主不自行逐帧重试，恢复布局后发布有效坐标', (tester) async {
    var layoutChild = false;
    var builds = 0;
    Offset? position;
    late StateSetter rebuild;
    late SelectionChromeMountHost host;
    late BuildContext source;
    addTearDown(() => tester.pumpWidget(SizedBox()));

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox.expand(
          child: StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return _WithheldLayout(
                layoutChild: layoutChild,
                child: Transform.translate(
                  offset: Offset(30, 20),
                  child: SelectionChromeSlotHost(
                    child: Builder(
                      builder: (context) {
                        source = context;
                        host = SelectionChromeSlot.maybeOf(context)!;
                        return SizedBox.expand();
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    final handle = host.mount(
      source,
      builder: (context) {
        builds++;
        position = host.globalToLocal(Offset(50, 40));
        return SizedBox.expand();
      },
    );
    addTearDown(handle.close);
    await tester.pumpAndSettle(Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, Duration(seconds: 1));
    expect(position, isNull);
    final suspendedBuilds = builds;
    await tester.pump();
    expect(builds, suspendedBuilds);
    expect(tester.binding.hasScheduledFrame, isFalse);

    rebuild(() => layoutChild = true);
    await tester.pumpAndSettle(Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, Duration(seconds: 1));
    expect(position, Offset(20, 20));
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('单个文本移出活动文档立即注销，换文档及真正销毁不保留旧选区', (tester) async {
    final left = ElSelectionController(), right = ElSelectionController();
    final textKey = GlobalKey();
    var moveRight = false;
    var observedRemoval = false;
    SelectionRegistrar? removedRegistrar;
    TextRange? removedRange;
    SelectionParticipant? participant;
    late StateSetter rebuild;
    addTearDown(left.dispose);
    addTearDown(right.dispose);
    addTearDown(() => tester.pumpWidget(SizedBox()));

    Widget text() => ElView(key: textKey, child: 'moving text');
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return Column(
              children: [
                SizedBox(
                  width: 320,
                  height: 80,
                  child: ElSelectionView(controller: left, child: moveRight ? SizedBox() : text()),
                ),
                Builder(
                  builder: (context) {
                    if (moveRight) {
                      observedRemoval = true;
                      removedRegistrar = participant!.registrar;
                      removedRange = participant.currentSelectionRange;
                    }
                    return SizedBox(
                      width: 320,
                      height: 80,
                      child: ElSelectionView(controller: right, child: moveRight ? text() : SizedBox()),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    left.selectAll();
    await tester.pumpAndSettle();
    expect(left.text, 'moving text');
    participant = selectionParticipantOf(tester.renderObject<ElRenderView>(find.byKey(textKey)))!;
    final oldRegistrar = participant.registrar;

    rebuild(() => moveRight = true);
    await tester.pumpAndSettle();
    expect(observedRemoval, isTrue);
    expect(removedRegistrar, isNull, reason: '旧文档仍在树上，单个文本移出必须在同一 build 内注销');
    expect(removedRange, isNull);
    expect(selectionParticipantOf(tester.renderObject<ElRenderView>(find.byKey(textKey))), same(participant));
    expect(participant.registrar, isNot(same(oldRegistrar)));
    expect(left.text, isNull);
    expect(right.text, isNull, reason: '同一正文换到另一文档不得带入旧范围');

    right.selectAll();
    await tester.pumpAndSettle();
    expect(right.text, 'moving text');
    await tester.pumpWidget(SizedBox());
    expect(participant.registrar, isNull);
    expect(right.text, isNull);
    await tester.pump();
    expect(tester.takeException(), isNull, reason: '真正销毁后的帧末复核不能访问已释放的参与者');
  });
}
