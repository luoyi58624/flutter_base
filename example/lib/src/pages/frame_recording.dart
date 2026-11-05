import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_base/mobile.dart';

import '../state/index.dart';
import '../utils/frame_timing_recorder.dart';
import '../widgets/frame_recording_scope.dart';
import 'example_page.dart';

/// 配置一段跨页面的性能采样并复制原始数据与统计结果。
class FrameRecordingPage extends StatefulWidget {
  /// 创建帧耗时记录页面。
  // ignore: prefer_const_constructors_in_immutables
  FrameRecordingPage({super.key});

  @override
  State<FrameRecordingPage> createState() => _FrameRecordingPageState();
}

class _FrameRecordingPageState extends State<FrameRecordingPage> {
  final _page = Obs('万条纯文本列表');
  final _container = Obs('RecyclerView');
  final _stage = Obs('A 首次滚动');
  final _delay = Obs(10);
  final _duration = Obs(10);
  final _device = TextEditingController();
  bool _copied = false;

  @override
  void dispose() {
    _page.dispose();
    _container.dispose();
    _stage.dispose();
    _delay.dispose();
    _duration.dispose();
    _device.dispose();
    super.dispose();
  }

  void _start(FrameTimingRecorder recorder) {
    final displayRate = View.of(context).display.refreshRate;
    final refreshRate = displayRate.isFinite && displayRate > 0 ? displayRate : 60.0;
    _copied = false;
    recorder.start(
      refreshRate: refreshRate,
      delay: Duration(seconds: _delay.rawValue),
      duration: Duration(seconds: _duration.rawValue),
      metadata: {
        'page': _page.rawValue,
        'container': _container.rawValue,
        'stage': _stage.rawValue,
        'device_and_os': _device.text.trim().isEmpty ? 'unknown' : _device.text.trim(),
        'platform': defaultTargetPlatform.name,
        'build_mode': kProfileMode ? 'profile' : (kReleaseMode ? 'release' : 'debug'),
        'commit': String.fromEnvironment('GIT_COMMIT', defaultValue: 'unknown'),
        'refresh_rate_source': displayRate.isFinite && displayRate > 0 ? 'FlutterView.display' : 'fallback_60Hz',
        'configured_delay_seconds': _delay.rawValue,
        'exclude_semantics': GlobalState.excludeSemantics.rawValue,
        'resampling_enabled': GlobalState.resamplingEnabled.rawValue,
        'performance_overlay': GlobalState.showPerformanceOverlay.rawValue,
        'doc_scroll_mode': GlobalState.docScrollMode.rawValue.name,
        'doc_repeat_count': GlobalState.docRepeatCount.rawValue,
        'window_kind': _stage.rawValue.startsWith('E ') ? 'stationary' : 'active',
        'captured_at': DateTime.now().toIso8601String(),
      },
    );
  }

  Future<void> _copy(Map<String, Object?> report) async {
    await Clipboard.setData(ClipboardData(text: JsonEncoder.withIndent('  ').convert(report)));
    if (mounted) setState(() => _copied = true);
  }

  ElListTile<T> _popup<T>(String key, String title, Obs<T> model, List<T> options, {required bool disabled}) =>
      ElListTile<T>.popup(
        key: ValueKey(key),
        title: title,
        modelValue: model,
        disabled: disabled,
        options: [for (final option in options) ElLabelModel('$option', option)],
      );

  @override
  Widget build(BuildContext context) {
    final recorder = FrameRecordingScope.of(context);
    return ExamplePage(
      title: '帧耗时记录',
      child: ListenableBuilder(
        listenable: recorder,
        builder: (context, _) {
          final active = recorder.isActive;
          final report = recorder.report;
          return ElScrollView(
            padding: .all(20),
            gap: 20,
            children: [
              ElCardView(
                style: ElStyle(padding: .all(16)),
                child: Column(
                  crossAxisAlignment: .start,
                  spacing: 8,
                  children: [
                    Text('先选好场景与列表容器，开始后在准备时间内返回目标页面。采样不会自动切换页面或容器。'),
                    Text('建议使用 Profile 模式并关闭性能浮层。静止场景应收起键盘、取消输入焦点，避开加载动画与光标闪烁。'),
                    Text('这里记录 Flutter 管线耗时与 vsync 间隔，不能代替屏幕实际呈现时间；低耗时仍抖动时还需要 Android FrameTimeline。'),
                  ],
                ),
              ),
              ElListGroup(
                title: '采样配置',
                children: [
                  _popup<String>('frame-recording-page', '页面', _page, [
                    '万条纯文本列表',
                    '万条复选列表',
                    '聊天长列表',
                    '复杂卡片面板',
                    '文档页 1 倍',
                    '文档页 20 倍',
                  ], disabled: active),
                  _popup<String>('frame-recording-container', '容器', _container, [
                    'ListView',
                    'ElScrollView',
                    'RecyclerView',
                    '官方普通滚动',
                  ], disabled: active),
                  _popup<String>('frame-recording-stage', '阶段', _stage, [
                    'A 首次滚动',
                    'B 稳定滚动',
                    'C 更新中滚动',
                    'D 远跳后反向',
                    'E 静止',
                  ], disabled: active),
                  _popup<int>('frame-recording-delay', '准备秒数', _delay, [5, 10, 20], disabled: active),
                  _popup<int>('frame-recording-duration', '采样秒数', _duration, [2, 10, 20, 30], disabled: active),
                ],
              ),
              ElCardView(
                style: ElStyle(padding: .all(16)),
                child: Column(
                  crossAxisAlignment: .stretch,
                  spacing: 12,
                  children: [
                    TextField(
                      key: ValueKey('frame-recording-device'),
                      controller: _device,
                      enabled: !active,
                      decoration: InputDecoration(labelText: '设备与系统（选填）', hintText: '例如 OPPO / Android 17'),
                    ),
                    Text(switch (recorder.phase) {
                      .idle => '尚未开始采样',
                      .waiting || .recording => '已安排采样，请返回目标页面操作；结束后再回来查看报告。',
                      .draining => '采样窗口已结束，正在接收最后一批帧。',
                      .complete => '采样完成，共 ${report?['frame_count'] ?? 0} 帧。',
                    }, key: ValueKey('frame-recording-status')),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        FilledButton(
                          key: ValueKey('frame-recording-start'),
                          onPressed: active
                              ? null
                              : () {
                                  FocusScope.of(context).unfocus();
                                  _start(recorder);
                                },
                          child: Text('开始记录'),
                        ),
                        OutlinedButton(
                          key: ValueKey('frame-recording-stop'),
                          onPressed: recorder.phase == .waiting || recorder.phase == .recording ? recorder.stop : null,
                          child: Text('提前结束'),
                        ),
                        OutlinedButton(
                          key: ValueKey('frame-recording-copy'),
                          onPressed: report == null ? null : () => _copy(report),
                          child: Text(_copied ? '已复制 JSON' : '复制 JSON'),
                        ),
                      ],
                    ),
                    if (report != null) ...[
                      Text('UI：${_metricLine(report, 'ui')}'),
                      Text('Raster：${_metricLine(report, 'raster')}'),
                      Text('Vsync 等待：${_metricLine(report, 'vsync_overhead')}'),
                      Text('Vsync 间隔：${_metricLine(report, 'vsync_interval')}'),
                      Text('超过 100ms 的窗口内间隔全部保留在报告中。JSON 包含每帧原始时间和当前设置快照。'),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _metricLine(Map<String, Object?> report, String key) {
    final metric = report[key]! as Map<String, Object?>;
    String fixed(String field) => (metric[field]! as num).toStringAsFixed(2);
    return 'P50 ${fixed('p50_ms')} / P99 ${fixed('p99_ms')} / 最大 ${fixed('max_ms')} ms';
  }
}
