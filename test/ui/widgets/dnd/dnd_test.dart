import '../../support/overlay.dart';
import 'package:flutter_base/src/ui/cores/selection/docs/selection_view.dart';
import 'package:flutter_base/ui.dart';
import 'package:flutter_base/src/ui/widgets/dnd/drag_session.dart' show DndSession;
import 'package:flutter_base/src/ui/cores/scroll/common/render/scroll_viewport_base.dart';
import 'package:flutter_base/src/ui/widgets/dnd/ghost_follower.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// DnD 数据拖放：ElDraggable / ElDropTarget / ghost 预览。
///
/// 不变量：
/// 1. 基础投放：enter → candidate(accepted) → drop 收 data+details → onDragEnded(true)。
/// 2. canAccept false：candidate.accepted false、drop 不派发、onDragEnded(false)。
/// 3. 泛型不匹配的 target 无感知。
/// 4. 拖离 target → onLeave + candidate 清空。
/// 5. 嵌套 target 最深者优先。
/// 6. ghost：跟手移动、pointerEvents none 不挡命中、松手消失。
void main() {
  const dragKey = ValueKey('drag');
  const targetKey = ValueKey('target');
  const ghostKey = ValueKey('ghost');

  /// 左侧拖拽源 + 右侧投放区的标准棋盘。
  Widget board<T extends Object>({
    required T data,
    bool Function(T)? canAccept,
    void Function(T, ElDropDetails)? onDrop,
    void Function(T)? onEnter,
    void Function(T)? onLeave,
    void Function(T, Offset)? onMove,
    VoidCallback? onDragStarted,
    void Function(bool)? onDragEnded,
    WidgetBuilder? ghostBuilder,
    List<ElDropCandidate<T>?>? candidateLog,
    Widget? targetChild,
    Widget? extraTarget,
    bool selection = false,
  }) {
    final overlay = ElTestOverlay(
      child: Stack(
        children: [
          Positioned(
            left: 20,
            top: 20,
            child: ElDraggable<T>(
              data: data,
              ghostBuilder: ghostBuilder,
              onDragStarted: onDragStarted,
              onDragEnded: onDragEnded,
              child: const ElView(
                key: dragKey,
                style: ElStyle(width: 60, height: 60, bgColor: Color(0xFF2266AA)),
              ),
            ),
          ),
          Positioned(
            left: 300,
            top: 20,
            child: ElDropTarget<T>(
              canAccept: canAccept,
              onDrop: onDrop,
              onEnter: onEnter,
              onLeave: onLeave,
              onMove: onMove,
              builder: (c, candidate) {
                candidateLog?.add(candidate);
                return ElView(
                  key: targetKey,
                  style: ElStyle(
                    width: 120,
                    height: 120,
                    bgColor: candidate == null
                        ? const Color(0xFF333333)
                        : candidate.accepted
                        ? const Color(0xFF22AA66)
                        : const Color(0xFFAA2222),
                  ),
                  child: targetChild,
                );
              },
            ),
          ),
          ?extraTarget,
        ],
      ),
    );
    return MaterialApp(
      home: ElView(child: selection ? ElSelectionView(child: overlay) : overlay),
    );
  }

  testWidgets('DnD eager 认领早于会话副作用', (tester) async {
    addTearDown(DndSession.instance.cancel);
    final activeDuringAncestorCancel = <bool>[];
    await tester.pumpWidget(
      MaterialApp(
        home: ElTestOverlay(
          child: ElView(
            event: ElEvent(
              onTap: (_) {},
              onTapCancel: (_) => activeDuringAncestorCancel.add(DndSession.instance.isActive),
            ),
            child: Align(
              alignment: Alignment.topLeft,
              child: ElDraggable<String>(
                data: 'ordering',
                child: const ElView(key: dragKey, style: ElStyle(width: 60, height: 60)),
              ),
            ),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(tester.getCenter(find.byKey(dragKey)));
    await gesture.moveBy(const Offset(50, 0));
    await tester.pump();

    expect(activeDuringAncestorCancel, <bool>[false], reason: 'loser 的取消回调必须先于 DnD session/ghost 副作用');
    expect(DndSession.instance.isActive, isTrue);
    await gesture.cancel();
  });

  group('数据语义', () {
    testWidgets('基础投放全链路', (tester) async {
      String? dropped;
      ElDropDetails? details;
      var entered = 0;
      bool? ended;
      final log = <ElDropCandidate<String>?>[];
      await tester.pumpWidget(
        board<String>(
          data: 'card-1',
          onDrop: (d, det) {
            dropped = d;
            details = det;
          },
          onEnter: (_) => entered++,
          onDragEnded: (a) => ended = a,
          candidateLog: log,
        ),
      );
      final gesture = await tester.startGesture(tester.getCenter(find.byKey(dragKey)));
      await gesture.moveBy(const Offset(50, 0)); // 过 slop 激活
      await tester.pump();
      // 移到 target 中心。
      await gesture.moveTo(tester.getCenter(find.byKey(targetKey)));
      await tester.pump();
      expect(entered, 1);
      expect(log.last?.data, 'card-1');
      expect(log.last?.accepted, isTrue);
      await gesture.up();
      await tester.pump();
      expect(dropped, 'card-1');
      expect(details!.localPosition, const Offset(60, 60)); // target 中心的本地坐标
      expect(ended, isTrue);
      expect(log.last, isNull); // drop 后 candidate 清空
    });

    testWidgets('canAccept false：拒收', (tester) async {
      String? dropped;
      bool? ended;
      final log = <ElDropCandidate<String>?>[];
      await tester.pumpWidget(
        board<String>(
          data: 'locked',
          canAccept: (d) => d != 'locked',
          onDrop: (d, _) => dropped = d,
          onDragEnded: (a) => ended = a,
          candidateLog: log,
        ),
      );
      final gesture = await tester.startGesture(tester.getCenter(find.byKey(dragKey)));
      await gesture.moveBy(const Offset(50, 0));
      await gesture.moveTo(tester.getCenter(find.byKey(targetKey)));
      await tester.pump();
      expect(log.last?.accepted, isFalse);
      await gesture.up();
      await tester.pump();
      expect(dropped, isNull);
      expect(ended, isFalse);
    });

    testWidgets('泛型不匹配的 target 无感知', (tester) async {
      var entered = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: ElView(
            child: ElTestOverlay(
              child: Stack(
                children: [
                  Positioned(
                    left: 20,
                    top: 20,
                    child: ElDraggable<String>(
                      data: 's',
                      child: const ElView(key: dragKey, style: ElStyle(width: 60, height: 60)),
                    ),
                  ),
                  Positioned(
                    left: 300,
                    top: 20,
                    child: ElDropTarget<int>(
                      onEnter: (_) => entered++,
                      builder: (c, candidate) => const ElView(
                        key: targetKey,
                        style: ElStyle(width: 120, height: 120, bgColor: Color(0xFF333333)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      final gesture = await tester.startGesture(tester.getCenter(find.byKey(dragKey)));
      await gesture.moveBy(const Offset(50, 0));
      await gesture.moveTo(tester.getCenter(find.byKey(targetKey)));
      await tester.pump();
      expect(entered, 0);
      await gesture.up();
    });

    testWidgets('拖离 target：onLeave + candidate 清空', (tester) async {
      var left = 0;
      final log = <ElDropCandidate<String>?>[];
      await tester.pumpWidget(board<String>(data: 'x', onLeave: (_) => left++, candidateLog: log));
      final gesture = await tester.startGesture(tester.getCenter(find.byKey(dragKey)));
      await gesture.moveBy(const Offset(50, 0));
      await gesture.moveTo(tester.getCenter(find.byKey(targetKey)));
      await tester.pump();
      expect(log.last, isNotNull);
      await gesture.moveTo(const Offset(200, 400)); // 移出
      await tester.pump();
      expect(left, 1);
      expect(log.last, isNull);
      await gesture.up();
    });

    testWidgets('嵌套 target：最深者优先', (tester) async {
      var outerEntered = 0, innerEntered = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: ElView(
            child: ElTestOverlay(
              child: Stack(
                children: [
                  Positioned(
                    left: 20,
                    top: 20,
                    child: ElDraggable<String>(
                      data: 'x',
                      child: const ElView(key: dragKey, style: ElStyle(width: 60, height: 60)),
                    ),
                  ),
                  Positioned(
                    left: 300,
                    top: 20,
                    child: ElDropTarget<String>(
                      onEnter: (_) => outerEntered++,
                      builder: (c, _) => ElView(
                        style: const ElStyle(width: 200, height: 200, bgColor: Color(0xFF333333), alignment: .center),
                        child: ElDropTarget<String>(
                          onEnter: (_) => innerEntered++,
                          builder: (c, _) => const ElView(
                            key: targetKey,
                            style: ElStyle(width: 80, height: 80, bgColor: Color(0xFF555555)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      final gesture = await tester.startGesture(tester.getCenter(find.byKey(dragKey)));
      await gesture.moveBy(const Offset(50, 0));
      await gesture.moveTo(tester.getCenter(find.byKey(targetKey))); // 内层中心
      await tester.pump();
      expect(innerEntered, 1);
      expect(outerEntered, 0);
      await gesture.up();
    });
  });

  group('terminal 重入', () {
    testWidgets('P12-A1: onDrop 同步 cancel 仍按 accepted=true 且 terminal exactly once', (tester) async {
      addTearDown(DndSession.instance.cancel);
      var drops = 0;
      var leaves = 0;
      final ended = <bool>[];
      await tester.pumpWidget(
        board<String>(
          data: 'reentrant-drop',
          ghostBuilder: (_) => const ElView(key: ghostKey, style: ElStyle(width: 40, height: 40)),
          onDrop: (_, _) {
            drops++;
            DndSession.instance.cancel();
          },
          onLeave: (_) => leaves++,
          onDragEnded: ended.add,
        ),
      );

      final gesture = await tester.startGesture(tester.getCenter(find.byKey(dragKey)));
      await gesture.moveBy(const Offset(50, 0));
      await gesture.moveTo(tester.getCenter(find.byKey(targetKey)));
      await tester.pump();
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      expect(drops, 1);
      expect(leaves, 1);
      expect(ended, <bool>[true]);
      expect(DndSession.instance.isActive, isFalse);
      expect(find.byKey(ghostKey), findsNothing);
    });

    testWidgets('P12-A2: onEnter/onLeave 内 cancel 不递归且不继续 stale move', (tester) async {
      addTearDown(DndSession.instance.cancel);
      var cancelOnEnter = true;
      var cancelOnLeave = false;
      var enters = 0;
      var leaves = 0;
      var moves = 0;
      final ended = <bool>[];
      final lifecycle = <String>[];
      await tester.pumpWidget(
        board<String>(
          data: 'reentrant-hover',
          onEnter: (_) {
            enters++;
            if (cancelOnEnter) DndSession.instance.cancel();
          },
          onLeave: (_) {
            leaves++;
            if (cancelOnLeave) DndSession.instance.cancel();
          },
          onMove: (_, _) => moves++,
          onDragStarted: () => lifecycle.add('started'),
          onDragEnded: (accepted) {
            ended.add(accepted);
            lifecycle.add('ended:$accepted');
          },
        ),
      );

      final first = await tester.startGesture(tester.getCenter(find.byKey(dragKey)));
      await first.moveBy(const Offset(50, 0));
      await first.moveTo(tester.getCenter(find.byKey(targetKey)));
      await tester.pump();
      final enterException = tester.takeException();
      await first.up();

      expect(enters, 1);
      expect(leaves, 1);
      expect(moves, 0, reason: 'onEnter 已取消后不得继续派发本轮 onMove');
      expect(enterException, isNull);
      expect(ended, <bool>[false]);
      expect(lifecycle, <String>['started', 'ended:false']);

      cancelOnEnter = false;
      cancelOnLeave = true;
      enters = 0;
      leaves = 0;
      moves = 0;
      final second = await tester.startGesture(tester.getCenter(find.byKey(dragKey)));
      await second.moveBy(const Offset(50, 0));
      await second.moveTo(tester.getCenter(find.byKey(targetKey)));
      await tester.pump();
      await second.moveTo(const Offset(200, 400));
      await tester.pump();
      final leaveException = tester.takeException();
      await second.up();

      expect(enters, 1);
      expect(leaves, 1);
      expect(leaveException, isNull);
      expect(ended, <bool>[false, false]);
      expect(lifecycle, <String>['started', 'ended:false', 'started', 'ended:false']);
      expect(DndSession.instance.isActive, isFalse);
    });

    testWidgets('P12-A3: onDrop 抛错后清 ghost/auto-scroll 并允许下一手 start', (tester) async {
      addTearDown(DndSession.instance.cancel);
      var starts = 0;
      final ended = <bool>[];
      await tester.pumpWidget(
        board<String>(
          data: 'throwing-drop',
          onDragStarted: () => starts++,
          onDragEnded: ended.add,
          onDrop: (_, _) => throw StateError('drop boom'),
          ghostBuilder: (_) => const ElView(key: ghostKey, style: ElStyle(width: 40, height: 40)),
          targetChild: ElScrollView(
            children: [for (var i = 0; i < 40; i++) ElView(style: const ElStyle(width: 100, height: 40), child: 'row')],
          ),
        ),
      );
      final viewport = tester.allRenderObjects.whereType<RenderVirtualScrollView>().firstWhere(
        (v) => v.size.width == 120,
      );
      final targetRect = tester.getRect(find.byKey(targetKey));

      final first = await tester.startGesture(tester.getCenter(find.byKey(dragKey)));
      await first.moveBy(const Offset(50, 0));
      await tester.pump();
      await first.moveTo(Offset(targetRect.center.dx, targetRect.bottom - 10));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      expect(viewport.position.pixels, greaterThan(0), reason: '前置条件：drop 前 auto-scroll ticker 已启动');
      await first.up();
      await tester.pump(const Duration(milliseconds: 20));
      expect(tester.takeException(), isA<StateError>());
      await tester.pumpAndSettle();

      final stoppedAt = viewport.position.pixels;
      expect(DndSession.instance.isActive, isFalse);
      expect(find.byKey(ghostKey), findsNothing);
      expect(ended, <bool>[false]);
      await tester.pump(const Duration(milliseconds: 200));
      expect(viewport.position.pixels, stoppedAt, reason: '异常 terminal 后 auto-scroll ticker 必须停止');

      final second = await tester.startGesture(tester.getCenter(find.byKey(dragKey)));
      await second.moveBy(const Offset(50, 0));
      await tester.pump();
      expect(starts, 2);
      expect(find.byKey(ghostKey), findsOneWidget);
      await second.cancel();
      await tester.pump(const Duration(milliseconds: 20));
      expect(ended, <bool>[false, false]);
    });

    testWidgets('P12-A4: old drop/leave terminal callbacks block singleton restart until completion', (tester) async {
      addTearDown(DndSession.instance.cancel);
      late BuildContext sessionContext;
      final attemptedDuringTerminal = <bool>[];
      final nestedEnded = <bool>[];
      final sourceEnded = <bool>[];

      bool tryNestedStart() {
        return DndSession.instance.start(
          data: 'nested',
          context: sessionContext,
          globalPosition: const Offset(700, 500),
          onEnded: nestedEnded.add,
        );
      }

      await tester.pumpWidget(
        board<String>(
          data: 'outer',
          onDrop: (_, _) => attemptedDuringTerminal.add(tryNestedStart()),
          onLeave: (_) => attemptedDuringTerminal.add(tryNestedStart()),
          onDragEnded: sourceEnded.add,
        ),
      );
      sessionContext = tester.element(find.byKey(targetKey));

      final gesture = await tester.startGesture(tester.getCenter(find.byKey(dragKey)));
      await gesture.moveBy(const Offset(50, 0));
      await gesture.moveTo(tester.getCenter(find.byKey(targetKey)));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(attemptedDuringTerminal, <bool>[false, false]);
      expect(sourceEnded, <bool>[true]);
      expect(DndSession.instance.isActive, isFalse);

      expect(tryNestedStart(), isTrue, reason: '旧 terminal callbacks 全部返回后 singleton 必须允许下一手');
      DndSession.instance.cancel();
      expect(nestedEnded, <bool>[false]);
    });
  });

  group('ghost 预览', () {
    testWidgets('官方 Overlay 幽灵保留源文字和明暗级联并响应更新', (tester) async {
      late BuildContext source;
      late StateSetter update;
      var dark = true;
      var color = Colors.red;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return ElView(
                themeMode: ElThemeMode(brightness: dark ? .dark : .light),
                style: ElStyle(fontSize: 24, color: color),
                child: Builder(
                  builder: (context) {
                    source = context;
                    return SizedBox();
                  },
                ),
              );
            },
          ),
        ),
      );
      DndSession.instance.start(
        context: source,
        data: 'styled',
        globalPosition: Offset(100, 100),
        ghostBuilder: (_) => ElView(key: ghostKey, child: 'Styled ghost'),
      );
      await tester.pump();
      await tester.pump();
      ElRenderView ghost() => tester.renderObject<ElRenderView>(find.byKey(ghostKey));
      expect(ghost().effectiveThemeMode?.brightness, Brightness.dark);
      expect(ghost().committedResolvedStyle.inheritedText.fontSize, 24);
      expect(ghost().committedResolvedStyle.inheritedText.color, Colors.red);
      update(() {
        dark = false;
        color = Colors.blue;
      });
      await tester.pump();
      await tester.pump();
      expect(ghost().effectiveThemeMode?.brightness, Brightness.light);
      expect(ghost().committedResolvedStyle.inheritedText.color, Colors.blue);
      DndSession.instance.cancel();
      await tester.pump();
    });

    testWidgets('未提供 ghostBuilder 时默认显示源快照并保留原位拖拽态', (tester) async {
      final overlayKey = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: ElTestOverlay(
            key: overlayKey,
            child: Align(
              alignment: Alignment.topLeft,
              child: ElDraggable<String>(
                data: 'default-ghost',
                child: const ElView(
                  key: dragKey,
                  style: ElStyle(width: 60, height: 60, bgColor: Color(0xff2266aa)),
                ),
              ),
            ),
          ),
        ),
      );

      final gesture = await tester.startGesture(tester.getCenter(find.byKey(dragKey)));
      await gesture.moveBy(const Offset(50, 0));
      await tester.pump();
      await tester.pump();

      expect(find.byType(GhostFollower), findsOneWidget);
      final dragShell = tester.widget<ElView>(
        find.descendant(
          of: find.byType(ElDraggable<String>),
          matching: find.byWidgetPredicate((widget) => widget is ElView && widget.event?.onDragStart != null),
        ),
      );
      expect(dragShell.style?.cursor, isNull, reason: '拖拽源不能覆盖外层已有光标。');

      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.byType(GhostFollower), findsNothing);
      expect(dragShell.style?.cursor, isNull);
    });

    testWidgets('跟手移动、不挡命中、松手消失', (tester) async {
      var entered = 0;
      await tester.pumpWidget(
        board<String>(
          data: 'g',
          onEnter: (_) => entered++,
          selection: true,
          ghostBuilder: (c) => const ElView(
            key: ghostKey,
            style: ElStyle(width: 40, height: 40, bgColor: Color(0x882266AA)),
          ),
        ),
      );
      final gesture = await tester.startGesture(tester.getCenter(find.byKey(dragKey)));
      await gesture.moveBy(const Offset(50, 0));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(ghostKey), findsOneWidget);
      expect(tester.allRenderObjects.whereType<RenderSelectionView>().toSet(), hasLength(1));
      final p1 = tester.getTopLeft(find.byKey(ghostKey));

      await gesture.moveTo(tester.getCenter(find.byKey(targetKey)));
      await tester.pump();
      await tester.pump();
      final p2 = tester.getTopLeft(find.byKey(ghostKey));
      expect((p2 - p1).distance, greaterThan(100)); // 跟手位移
      // ghost 正悬在指针/target 上方，但 pointerEvents none 不挡命中：
      expect(entered, 1);

      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      expect(find.byKey(ghostKey), findsNothing);
    });

    for (final rootOverlay in [false, true]) {
      testWidgets('官方 Overlay rootOverlay=$rootOverlay 幽灵归属、跟手与立即清理', (tester) async {
        final nestedKey = GlobalKey<OverlayState>();
        late BuildContext source;
        await tester.pumpWidget(
          MaterialApp(
            home: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: EdgeInsets.only(left: 100, top: 100),
                child: SizedBox(
                  width: 180,
                  height: 180,
                  child: ClipRect(
                    child: Overlay(
                      key: nestedKey,
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
                ),
              ),
            ),
          ),
        );
        final position = Offset(250, 250);
        DndSession.instance.start(
          context: source,
          data: 'official',
          globalPosition: position,
          rootOverlay: rootOverlay,
          ghostBuilder: (_) => SizedBox(key: ghostKey, width: 40, height: 40),
        );
        await tester.pump();
        await tester.pump();
        final ghostContext = tester.element(find.byKey(ghostKey));
        final owner = ghostContext.findAncestorStateOfType<OverlayState>();
        expect(owner, same(Overlay.of(source, rootOverlay: rootOverlay)));
        expect(identical(owner, nestedKey.currentState), !rootOverlay);
        expect(tester.getTopLeft(find.byKey(ghostKey)), position);
        DndSession.instance.update(Offset(420, 420));
        await tester.pump();
        expect(tester.getTopLeft(find.byKey(ghostKey)), Offset(420, 420));
        DndSession.instance.cancel();
        await tester.pump();
        expect(find.byKey(ghostKey), findsNothing);
        expect(DndSession.instance.isActive, isFalse);
      });
    }
  });
}
