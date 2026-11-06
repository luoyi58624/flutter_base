import 'dart:convert';

import 'package:example/src/pages/examples/recycler_view/cards.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_base/recycler_view.dart' as rv;
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final type in [0, 1]) {
    testWidgets('真实复杂卡片类型 $type 分离描述创建、完整挂载与保留结构更新成本', (tester) async {
      final warmContent = ValueNotifier<Widget>(SizedBox());
      final coldContent = ValueNotifier<Widget>(SizedBox());
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(390, 1200);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        ElComponentProvider(
          components: el.mobileComponents,
          child: MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  // 原页面只负责真实适配器与模型生命周期，不在计时区间建立业务数据。
                  Offstage(child: RecyclerCardsPage()),
                  Align(
                    alignment: .topLeft,
                    child: Column(children: [_slot(warmContent), _slot(coldContent)]),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final list = tester.widget<rv.RecyclerView>(find.byType(rv.RecyclerView, skipOffstage: false));
      final adapter = list.getAdapter()!;
      final positions = [
        for (var position = 0; position < adapter.getItemCount(); position++)
          if (adapter.getItemViewType(position) == type) position,
      ].take(17).toList();
      expect(positions, hasLength(17));
      final warm = adapter.createViewHolder(list, type);
      adapter.bindViewHolder(warm, positions.first);
      warmContent.value = warm.itemView;
      await tester.pumpAndSettle();
      // 使用真实 ResizeImage provider 预解码，两个测量通道都命中相同照片缓存。
      final images = _inside(warm, find.byType(Image)).evaluate().toList();
      await tester.runAsync(() async {
        await Future.wait([for (final element in images) precacheImage((element.widget as Image).image, element)]);
      });
      await tester.pumpAndSettle();
      final initial = _Tree.capture(warm);
      expect(initial.elements.length, greaterThan(100), reason: '必须测量真实复杂卡片，而不是空壳 holder');
      expect(initial.states, isNotEmpty);
      expect(initial.renders, isNotEmpty);
      final firstTitle = _title(tester, warm);
      final samples = <Map<String, int>>[];
      final measuredIds = <int>{};
      final totals = _Changes();
      _Tree? previousCold;

      Future<void> update(int position, Map<String, int> sample) async {
        final clock = Stopwatch()..start();
        final bindClock = Stopwatch()..start();
        adapter.bindViewHolder(warm, position);
        bindClock.stop();
        await tester.pump(Duration(milliseconds: 8));
        clock.stop();
        sample['update_bind_callback_us'] = bindClock.elapsedMicroseconds;
        sample['update_bind_and_pump_us'] = clock.elapsedMicroseconds;

        // 身份遍历与断言放在计时之外，避免把检测本身算成更新成本。
        final after = _Tree.capture(warm);
        final changes = _Changes.between(initial, after);
        expect(changes.addedElements, 0);
        expect(changes.removedElements, 0);
        expect(changes.addedStates, 0);
        expect(changes.removedStates, 0);
        expect(changes.addedRenders, 0);
        expect(changes.removedRenders, 0);
        expect(initial.states.every((state) => state.mounted), isTrue);
        expect(initial.renders.every((render) => render.attached && render.debugDisposed == false), isTrue);
        expect(warm.getItemId(), adapter.getItemId(position));
        expect(_title(tester, warm), contains('观测 #${(position + 1).toString().padLeft(5, '0')}'));
        sample['retained_elements'] = after.elements.length;
      }

      Future<void> create(int position, Map<String, int> sample) async {
        final clock = Stopwatch()..start();
        final factoryClock = Stopwatch()..start();
        final holder = adapter.createViewHolder(list, type);
        factoryClock.stop();
        final bindClock = Stopwatch()..start();
        adapter.bindViewHolder(holder, position);
        bindClock.stop();
        coldContent.value = holder.itemView;
        await tester.pump(Duration(milliseconds: 8));
        clock.stop();
        sample['create_description_callback_us'] = factoryClock.elapsedMicroseconds;
        sample['create_initial_bind_callback_us'] = bindClock.elapsedMicroseconds;
        sample['create_bind_mount_and_pump_us'] = clock.elapsedMicroseconds;

        final created = _Tree.capture(holder);
        expect(created.elements.length, initial.elements.length);
        expect(created.states.length, initial.states.length);
        expect(created.renders.length, initial.renders.length);
        expect(created.elements.intersection(initial.elements), isEmpty);
        expect(created.states.intersection(initial.states), isEmpty);
        expect(created.renders.intersection(initial.renders), isEmpty);
        final previous = previousCold;
        if (previous != null) {
          expect(created.elements.intersection(previous.elements), isEmpty, reason: '正对照必须真的重新挂载');
          expect(created.states.intersection(previous.states), isEmpty);
          expect(created.renders.intersection(previous.renders), isEmpty);
        }
        expect(holder.getItemId(), adapter.getItemId(position));
        expect(_title(tester, holder), contains('观测 #${(position + 1).toString().padLeft(5, '0')}'));

        final unmountClock = Stopwatch()..start();
        coldContent.value = SizedBox();
        await tester.pump(Duration(milliseconds: 8));
        unmountClock.stop();
        sample['unmount_and_pump_us'] = unmountClock.elapsedMicroseconds;
        expect(created.elements.every((element) => !element.mounted), isTrue);
        expect(created.states.every((state) => !state.mounted), isTrue);
        expect(created.renders.every((render) => render.debugDisposed == true && !render.attached), isTrue);
        sample['created_elements'] = created.elements.length;
        sample['disposed_states'] = created.states.length;
        sample['disposed_render_objects'] = created.renders.length;
        previousCold = created;
      }

      for (var round = 0; round < 16; round++) {
        final position = positions[round + 1];
        final sample = <String, int>{'round': round, 'position': position, 'create_first': round.isOdd ? 1 : 0};
        if (round.isEven) {
          await update(position, sample);
          await create(position, sample);
        } else {
          // 在同一个进程中交替顺序，避免始终让保留结构通道享受后一轮预热。
          await create(position, sample);
          await update(position, sample);
        }
        expect(tester.takeException(), isNull);
        if (round >= 4) {
          samples.add(sample);
          measuredIds.add(warm.getItemId());
        }
      }
      expect(samples, hasLength(12));
      expect(measuredIds, hasLength(12));
      expect(_title(tester, warm), isNot(firstTitle));
      final finalTree = _Tree.capture(warm);
      totals.add(_Changes.between(initial, finalTree));
      totals.expectNoChanges();
      final fields = [
        'create_description_callback_us',
        'create_initial_bind_callback_us',
        'create_bind_mount_and_pump_us',
        'update_bind_callback_us',
        'update_bind_and_pump_us',
        'unmount_and_pump_us',
      ];
      debugPrint(
        'RECYCLER_ACTUAL_CARD_CREATE_UPDATE ${jsonEncode({
          'view_type': type,
          'source': 'actual RecyclerCardsPage Adapter and complete card row',
          'environment': 'flutter_test/debug; host wall time; predecoded photos; no GPU/device FrameTiming',
          'sample_count': samples.length,
          'warmup_samples': 4,
          'different_measured_ids': measuredIds.length,
          'tree': {'elements': initial.elements.length, 'states': initial.states.length, 'render_objects': initial.renders.length},
          'retained_update_changes': totals.toJson(),
          'create_control': {'new_elements': samples.fold(0, (sum, sample) => sum + sample['created_elements']!), 'disposed_states': samples.fold(0, (sum, sample) => sum + sample['disposed_states']!), 'disposed_render_objects': samples.fold(0, (sum, sample) => sum + sample['disposed_render_objects']!)},
          'timings': {for (final field in fields) field: _timings(samples.map((sample) => sample[field]!).toList())},
          'raw_samples_us': samples,
        })}',
      );
      await tester.pumpWidget(SizedBox());
      expect(initial.states.every((state) => !state.mounted), isTrue);
      warmContent.dispose();
      coldContent.dispose();
    });
  }
}

Widget _slot(ValueNotifier<Widget> content) => SizedBox(
  width: 390,
  height: 540,
  child: RepaintBoundary(
    child: ValueListenableBuilder(valueListenable: content, builder: (context, child, _) => child),
  ),
);

Finder _inside(rv.ViewHolder holder, Finder matching) =>
    find.descendant(of: find.byWidget(holder.itemView), matching: matching, matchRoot: true);

String _title(WidgetTester tester, rv.ViewHolder holder) =>
    tester.widget<Text>(_inside(holder, find.byKey(ValueKey('cards-title')))).data!;

Map<String, num> _timings(List<int> values) {
  final sorted = [...values]..sort();
  num percentile(double fraction) => sorted[(sorted.length * fraction).ceil() - 1] / 1000;
  return {'p50_ms': percentile(.5), 'p95_ms': percentile(.95), 'max_ms': percentile(1)};
}

class _Tree {
  _Tree(this.elements, this.states, this.renders);

  factory _Tree.capture(rv.ViewHolder holder) {
    final elements = <Element>{};
    void visit(Element element) {
      elements.add(element);
      element.visitChildren(visit);
    }

    visit(find.byWidget(holder.itemView).evaluate().single);
    return _Tree(
      elements,
      elements.whereType<StatefulElement>().map((element) => element.state).toSet(),
      elements.whereType<RenderObjectElement>().map((element) => element.renderObject).toSet(),
    );
  }

  final Set<Element> elements;
  final Set<State> states;
  final Set<RenderObject> renders;
}

class _Changes {
  int addedElements = 0;
  int removedElements = 0;
  int addedStates = 0;
  int removedStates = 0;
  int addedRenders = 0;
  int removedRenders = 0;

  _Changes();

  factory _Changes.between(_Tree before, _Tree after) => _Changes()
    ..addedElements = after.elements.difference(before.elements).length
    ..removedElements = before.elements.difference(after.elements).length
    ..addedStates = after.states.difference(before.states).length
    ..removedStates = before.states.difference(after.states).length
    ..addedRenders = after.renders.difference(before.renders).length
    ..removedRenders = before.renders.difference(after.renders).length;

  void add(_Changes value) {
    addedElements += value.addedElements;
    removedElements += value.removedElements;
    addedStates += value.addedStates;
    removedStates += value.removedStates;
    addedRenders += value.addedRenders;
    removedRenders += value.removedRenders;
  }

  void expectNoChanges() {
    expect(addedElements, 0);
    expect(removedElements, 0);
    expect(addedStates, 0);
    expect(removedStates, 0);
    expect(addedRenders, 0);
    expect(removedRenders, 0);
  }

  Map<String, int> toJson() => {
    'added_elements': addedElements,
    'removed_elements': removedElements,
    'added_states': addedStates,
    'removed_states': removedStates,
    'added_render_objects': addedRenders,
    'removed_render_objects': removedRenders,
  };
}
