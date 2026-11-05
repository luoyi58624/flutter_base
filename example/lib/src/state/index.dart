import 'package:flutter_base/flutter.dart';

/// 示例应用共用的主题与调试开关。
class GlobalState {
  const GlobalState._();

  /// 是否使用暗色主题。
  static final isDark = Obs(false);

  /// 是否显示 Flutter 性能图层。
  static final showPerformanceOverlay = Obs(false);

  /// 是否显示调试横幅。
  static final debugShowCheckedModeBanner = Obs(true);
}
