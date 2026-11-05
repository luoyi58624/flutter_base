import 'dart:convert';

import 'package:example/src/pages/frame_recording.dart';
import 'package:example/src/pages/settings.dart';
import 'package:example/src/state/index.dart';
import 'package:example/src/utils/frame_timing_recorder.dart';
import 'package:example/src/widgets/frame_recording_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _open(WidgetTester tester, Widget page) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(390, 1400);
  tester.view.display.refreshRate = 120;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.display.resetRefreshRate);
  await tester.pumpWidget(
    FrameRecordingScope(
      child: ElComponentProvider(
        components: el.mobileComponents,
        child: MaterialApp(home: page),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _choose(WidgetTester tester, String row, String label) async {
  await tester.tap(find.byKey(ValueKey(row)));
  await tester.pumpAndSettle();
  final option = find.byWidgetPredicate(
    (widget) => (widget is Text && widget.data == label) || (widget is ElView && widget.child == label),
  );
  await tester.tap(option.last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('设置页提供帧记录入口，进入后可配置并复制完整JSON', (tester) async {
    String? clipboard;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') clipboard = (call.arguments as Map)['text'] as String;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await _open(tester, SettingPage());
    await tester.tap(find.byKey(ValueKey('settings-frame-recording')));
    await tester.pumpAndSettle();
    expect(find.byType(FrameRecordingPage), findsOneWidget);
    await _choose(tester, 'frame-recording-page', '复杂卡片面板');
    await _choose(tester, 'frame-recording-container', 'ListView');
    await _choose(tester, 'frame-recording-stage', 'E 静止');
    await _choose(tester, 'frame-recording-delay', '5');
    await _choose(tester, 'frame-recording-duration', '2');
    await tester.enterText(find.byKey(ValueKey('frame-recording-device')), '测试手机 / Android 17');
    final recorder = FrameRecordingScope.of(tester.element(find.byType(FrameRecordingPage)));
    await tester.tap(find.byKey(ValueKey('frame-recording-start')));
    await tester.pump();
    expect(recorder.phase, FrameRecordingPhase.waiting);
    expect(tester.widget<FilledButton>(find.byKey(ValueKey('frame-recording-start'))).onPressed, isNull);
    expect(tester.widget<ElListTile<String>>(find.byKey(ValueKey('frame-recording-page'))).disabled, isTrue);
    await tester.pump(Duration(seconds: 5));
    expect(recorder.phase, FrameRecordingPhase.recording);
    await tester.pump(Duration(seconds: 2));
    expect(recorder.phase, FrameRecordingPhase.draining);
    await tester.pump(Duration(milliseconds: 1100));
    expect(recorder.phase, FrameRecordingPhase.complete);
    await tester.tap(find.byKey(ValueKey('frame-recording-copy')));
    await tester.pump();
    expect(clipboard, isNotNull);
    final report = jsonDecode(clipboard!) as Map<String, dynamic>;
    final metadata = report['metadata'] as Map<String, dynamic>;
    expect(metadata['page'], '复杂卡片面板');
    expect(metadata['container'], 'ListView');
    expect(metadata['stage'], 'E 静止');
    expect(metadata['device_and_os'], '测试手机 / Android 17');
    expect(metadata['exclude_semantics'], GlobalState.excludeSemantics.rawValue);
    expect(metadata['resampling_enabled'], GlobalState.resamplingEnabled.rawValue);
    expect(metadata['performance_overlay'], GlobalState.showPerformanceOverlay.rawValue);
    expect(metadata['doc_repeat_count'], GlobalState.docRepeatCount.rawValue);
    expect(metadata['commit'], isNotEmpty);
    expect(metadata['build_mode'], 'debug');
    expect(report['window']['refresh_rate_hz'], 120);
    expect(report['window']['duration_ms'], 2000);
    expect(report['stationary_frame_count'], 0);
    expect(report['is_screen_presentation_timing'], isFalse);
    expect(find.text('已复制 JSON'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('离开记录页不会停止任务，卸载应用Scope立即解除订阅', (tester) async {
    await _open(tester, SettingPage());
    await tester.tap(find.byKey(ValueKey('settings-frame-recording')));
    await tester.pumpAndSettle();
    final recorder = FrameRecordingScope.of(tester.element(find.byType(FrameRecordingPage)));
    await tester.tap(find.byKey(ValueKey('frame-recording-start')));
    await tester.pump();
    Navigator.of(tester.element(find.byType(FrameRecordingPage))).pop();
    await tester.pumpAndSettle();
    expect(find.byType(FrameRecordingPage), findsNothing);
    expect(recorder.isActive, isTrue);
    await tester.pump(Duration(seconds: 10));
    expect(recorder.isSubscribed, isTrue);
    await tester.pumpWidget(SizedBox());
    expect(recorder.isSubscribed, isFalse);
    await tester.pump(Duration(seconds: 11));
    expect(tester.takeException(), isNull);
  });

  testWidgets('准备期提前结束不会启动后续采样，页面可再次开始', (tester) async {
    await _open(tester, FrameRecordingPage());
    final recorder = FrameRecordingScope.of(tester.element(find.byType(FrameRecordingPage)));
    await tester.tap(find.byKey(ValueKey('frame-recording-start')));
    await tester.pump();
    await tester.tap(find.byKey(ValueKey('frame-recording-stop')));
    await tester.pump();
    expect(recorder.phase, FrameRecordingPhase.idle);
    expect(recorder.isSubscribed, isFalse);
    expect(tester.widget<FilledButton>(find.byKey(ValueKey('frame-recording-start'))).onPressed, isNotNull);
    await tester.pump(Duration(seconds: 11));
    expect(recorder.isSubscribed, isFalse);
    await tester.pumpWidget(SizedBox());
  });
}
