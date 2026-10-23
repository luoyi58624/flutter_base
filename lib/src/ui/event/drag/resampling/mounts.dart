import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, internal, kIsWeb;
import 'package:flutter/gestures.dart';

import 'resampler.dart';
import 'test_environment_stub.dart'
    if (dart.library.io) 'test_environment_io.dart';

/// 拖拽重采样全局策略与门控。
@internal
abstract final class DragResamplingPolicy {
  static bool enabled = true;

  static Duration? Function(double fps) samplingBuilder = (double fps) {
    if (!fps.isFinite || fps <= 0) return null;
    return const Duration(milliseconds: -5);
  };

  static Duration? samplingOffsetOverride;
  static int debugEngageCount = 0;

  /// 测试探针：非 null 时采样门控按该平台判定；@internal 供 dispatcher 转发给外部测试。
  @internal
  static TargetPlatform? debugPlatformOverride;

  @internal
  static double? debugRefreshRateOverride;

  static bool get yieldsToOfficialResampling =>
      GestureBinding.instance.resamplingEnabled;

  static TargetPlatform? get hostPlatform {
    final override = debugPlatformOverride;
    if (override != null) return override;
    if (kIsWeb || isFlutterTest) return null;
    final platform = defaultTargetPlatform;
    return platform == TargetPlatform.android ||
            platform == TargetPlatform.windows
        ? platform
        : null;
  }

  static bool allowsGlobalGate() => enabled && !kIsWeb && hostPlatform != null;
}

@internal
final class DragResamplingContext {
  const DragResamplingContext({
    required this.refreshRate,
    required this.seedTime,
    required this.seedPosition,
    required this.onSample,
  });

  final double? refreshRate;
  final Duration seedTime;
  final Offset seedPosition;
  final void Function(DragResampler sampler, Offset position, Offset delta)
  onSample;
}

/// Android 触屏：touch 拖拽。
@internal
bool dragResamplingMatchesAndroid(
  TargetPlatform platform,
  PointerDeviceKind kind,
) {
  return platform == TargetPlatform.android && kind == PointerDeviceKind.touch;
}

/// Windows 桌面：touch + mouse（拖拽状态机的全局坐标）。
@internal
bool dragResamplingMatchesWindowsPointer(
  TargetPlatform platform,
  PointerDeviceKind kind,
) {
  return platform == TargetPlatform.windows &&
      (kind == PointerDeviceKind.touch || kind == PointerDeviceKind.mouse);
}

@internal
bool dragResamplingAllowsKind({
  required TargetPlatform platform,
  required PointerDeviceKind kind,
}) {
  if (dragResamplingMatchesAndroid(platform, kind)) return true;
  if (dragResamplingMatchesWindowsPointer(platform, kind)) return true;
  return false;
}

@internal
DragResampler? createDragResampler(DragResamplingContext context) {
  if (DragResamplingPolicy.yieldsToOfficialResampling) return null;
  final override = DragResamplingPolicy.samplingOffsetOverride;
  var samplingOffset = override;
  if (samplingOffset == null) {
    final fps = context.refreshRate;
    if (fps == null) return null;
    samplingOffset = DragResamplingPolicy.samplingBuilder(fps);
    if (samplingOffset == null) return null;
  }
  DragResamplingPolicy.debugEngageCount++;
  return DragResampler(
    onSample: context.onSample,
    samplingOffset: samplingOffset,
    adaptive: override == null,
    seedTime: context.seedTime,
    seedPosition: context.seedPosition,
  );
}
