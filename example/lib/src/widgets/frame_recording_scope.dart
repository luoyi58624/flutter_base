import 'package:flutter/widgets.dart';

import '../utils/frame_timing_recorder.dart';

/// 让采样跨页面继续执行，并在应用子树卸载时释放订阅与计时器。
class FrameRecordingScope extends StatefulWidget {
  /// 为示例应用创建一份记录器。
  // ignore: prefer_const_constructors_in_immutables
  FrameRecordingScope({super.key, required this.child});

  /// 共享采样任务的页面子树。
  final Widget child;

  /// 读取应用级记录器；页面自行监听它以展示任务结果。
  static FrameTimingRecorder of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_RecordingScope>();
    assert(scope != null, '帧采样页面需要放在 FrameRecordingScope 中');
    return scope!.recorder;
  }

  @override
  State<FrameRecordingScope> createState() => _FrameRecordingScopeState();
}

class _FrameRecordingScopeState extends State<FrameRecordingScope> {
  final _recorder = FrameTimingRecorder();

  @override
  void dispose() {
    _recorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _RecordingScope(recorder: _recorder, child: widget.child);
}

class _RecordingScope extends InheritedWidget {
  const _RecordingScope({required this.recorder, required super.child});

  final FrameTimingRecorder recorder;

  @override
  bool updateShouldNotify(_RecordingScope oldWidget) => oldWidget.recorder != recorder;
}
