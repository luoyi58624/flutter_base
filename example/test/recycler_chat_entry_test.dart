import 'dart:convert';

import 'package:example/src/pages/examples/recycler_view/cards.dart';
import 'package:example/src/pages/examples/recycler_view/chat.dart';
import 'package:example/src/pages/examples/recycler_view/selection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_base/recycler_view.dart' as rv;
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final scenario in ['selection', 'chat', 'cards']) {
    testWidgets('真实 $scenario 页面进入时分开记录 State 初始化、首帧与后续布局工作', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      // 先准备公共应用外壳，避免把 MaterialApp 的首次初始化混进某个页面。
      await tester.pumpWidget(_host(SizedBox()));
      await tester.pumpAndSettle();

      var stateCreationUs = 0;
      void onCreated(int durationUs) => stateCreationUs += durationUs;
      final Widget page = switch (scenario) {
        'selection' => _TimedSelectionPage(onCreated),
        'chat' => _TimedChatPage(onCreated),
        _ => _TimedCardsPage(onCreated),
      };
      final capture = _RowCapture();
      late Map<String, Object?> firstFrame;
      late Map<String, Object?> settled;
      late int firstPumpUs;
      late int settleUs;
      late int settleFrames;
      late rv.RecyclerView list;
      try {
        final firstClock = Stopwatch()..start();
        await tester.pumpWidget(_host(page));
        firstPumpUs = (firstClock..stop()).elapsedMicroseconds;
        list = tester.widget<rv.RecyclerView>(find.byType(rv.RecyclerView));
        firstFrame = {..._snapshot(list), ...capture.snapshot()};

        final settleClock = Stopwatch()..start();
        settleFrames = await tester.pumpAndSettle(Duration(milliseconds: 16));
        settleUs = (settleClock..stop()).elapsedMicroseconds;
        settled = {..._snapshot(list), ...capture.snapshot()};
      } finally {
        capture.dispose();
      }

      expect(list.getAdapter()!.getItemCount(), 10000);
      expect(capture.rows, isNotEmpty, reason: '诊断必须覆盖真实行，不能让空采样通过');
      expect(capture.dataAssignments, greaterThan(0));
      expect(capture.rows.length, lessThan(100), reason: '进入页面只能挂载视口附近真实行，不能创建整张列表');
      final layout = list.getLayoutManager()! as rv.LinearLayoutManager;
      if (scenario == 'chat') {
        expect(layout.findLastVisibleItemPosition(), 9999);
        expect(find.textContaining('消息 #10000：').hitTestable(), findsOneWidget);
        expect(list.controller!.position.extentAfter, lessThan(.1));
        expect(firstFrame['minimum_row_id_observed'], firstFrame['visible_first'], reason: '从末尾进入不能先绑定最终视口之外的旧消息');
        expect(firstFrame['different_row_ids_observed'], firstFrame['visible_holders']);
        expect(firstFrame['data_assignments_observed'], firstFrame['visible_holders'], reason: '首屏每条实际消息只绑定一次');
      } else {
        expect(layout.findFirstVisibleItemPosition(), 0);
      }
      expect(tester.takeException(), isNull);
      debugPrint(
        'RECYCLER_ENTRY_PERF ${jsonEncode({'page': scenario, 'state_create_ms': stateCreationUs / 1000, 'first_pump_ms': firstPumpUs / 1000, 'first_pump_excluding_state_ms': (firstPumpUs - stateCreationUs) / 1000, 'settle_ms': settleUs / 1000, 'settle_frames': settleFrames, 'first_frame': firstFrame, 'settled': settled, 'environment': 'flutter_test/debug; warmed common app shell; host wall time, not device FrameTiming/FPS'})}',
      );
      await tester.pumpWidget(SizedBox());
    });
  }
}

Widget _host(Widget page) => ElComponentProvider(
  components: el.mobileComponents,
  child: MaterialApp(home: page),
);

Map<String, Object?> _snapshot(rv.RecyclerView list) {
  final layout = list.getLayoutManager()! as rv.LinearLayoutManager;
  final position = list.controller!.position;
  return {
    'visible_first': layout.findFirstVisibleItemPosition(),
    'visible_last': layout.findLastVisibleItemPosition(),
    'visible_holders': layout.getChildCount(),
    'pixels': position.pixels,
    'max_scroll_extent': position.maxScrollExtent,
    'extent_after': position.extentAfter,
  };
}

class _TimedChatPage extends RecyclerChatPage {
  _TimedChatPage(this.onCreated);
  final ValueChanged<int> onCreated;

  @override
  State<RecyclerChatPage> createState() {
    final clock = Stopwatch()..start();
    final state = super.createState();
    onCreated((clock..stop()).elapsedMicroseconds);
    return state;
  }
}

class _TimedSelectionPage extends RecyclerSelectionPage {
  _TimedSelectionPage(this.onCreated);
  final ValueChanged<int> onCreated;

  @override
  State<RecyclerSelectionPage> createState() {
    final clock = Stopwatch()..start();
    final state = super.createState();
    onCreated((clock..stop()).elapsedMicroseconds);
    return state;
  }
}

class _TimedCardsPage extends RecyclerCardsPage {
  _TimedCardsPage(this.onCreated);
  final ValueChanged<int> onCreated;

  @override
  State<RecyclerCardsPage> createState() {
    final clock = Stopwatch()..start();
    final state = super.createState();
    onCreated((clock..stop()).elapsedMicroseconds);
    return state;
  }
}

class _RowCapture {
  _RowCapture() : previous = debugOnRebuildDirtyWidget {
    debugOnRebuildDirtyWidget = (element, builtOnce) {
      previous?.call(element, builtOnce);
      final type = element.widget.runtimeType.toString();
      if (type != '_ChatRow' && type != '_SelectionRow' && type != '_ObservationRow') return;
      buildCalls++;
      if (!rows.add(element)) return;
      // 仅诊断真实页面已有行，不改 Adapter，也不用自造测试行代替真实首屏。
      final dynamic row = element.widget;
      final ValueListenable<dynamic> data = switch (type) {
        '_ChatRow' => row.message as ValueListenable<dynamic>,
        '_SelectionRow' => row.model.item as ValueListenable<dynamic>,
        _ => row.model.record as ValueListenable<dynamic>,
      };
      void record() {
        final dynamic value = data.value;
        if (value == null) return;
        ids.add(value.id as int);
        dataAssignments++;
      }

      record();
      data.addListener(record);
      releases.add(() => data.removeListener(record));
    };
  }

  final RebuildDirtyWidgetCallback? previous;
  final rows = <Element>{};
  final ids = <int>{};
  final releases = <VoidCallback>[];
  int buildCalls = 0;
  int dataAssignments = 0;

  Map<String, Object?> snapshot() => {
    'row_elements_created': rows.length,
    'row_build_calls': buildCalls,
    'data_assignments_observed': dataAssignments,
    'different_row_ids_observed': ids.length,
    'minimum_row_id_observed': ids.isEmpty ? null : ids.reduce((a, b) => a < b ? a : b),
    'maximum_row_id_observed': ids.isEmpty ? null : ids.reduce((a, b) => a > b ? a : b),
  };

  void dispose() {
    debugOnRebuildDirtyWidget = previous;
    for (final release in releases) {
      release();
    }
  }
}
