import 'package:flutter/gestures.dart';
import 'package:flutter_base/flutter_base.dart';

/// 通用文档页使用的滚动实现。
enum DocScrollMode {
  /// 使用 SingleChildScrollView 和 Column 一次布局全部内容。
  official('官方普通滚动'),

  /// 使用 ListView.builder 按需创建文档条目。
  officialVirtual('官方虚拟列表'),

  /// 使用 ElScrollView 的虚拟滚动管线。
  elScrollView('ElScrollView'),

  /// 使用可按模板回收复用条目的 Dart RecyclerView。
  recyclerView('RecyclerView');

  /// 创建滚动实现及其在设置中显示的名称。
  const DocScrollMode(this.label);

  /// 设置列表和选项菜单中显示的名称。
  final String label;
}

/// 示例应用共用的主题、系统开关与文档滚动设置。
class GlobalState {
  const GlobalState._();

  /// 是否使用暗色主题。
  static final isDark = Obs(false);

  /// 是否显示 Flutter 性能图层。
  static final showPerformanceOverlay = Obs(false);

  /// 是否显示调试横幅。
  static final debugShowCheckedModeBanner = Obs(true);

  /// 是否屏蔽整个示例应用的辅助技术语义。
  static final excludeSemantics = Obs(false);

  /// 所有通用文档页使用的滚动实现。
  static final docScrollMode = Obs(DocScrollMode.elScrollView);

  /// 所有通用文档页正文小节的重复倍数。
  static final docRepeatCount = Obs(1);

  /// 是否启用当前应用绑定实际配置的触摸重采样。
  static final resamplingEnabled = _createResamplingSetting();
}

Obs<bool> _createResamplingSetting() {
  final binding = GestureBinding.instance;
  // 开启时恢复原采样路径，避免切换设置时无意改用另一套采样实现。
  final originalOfficialResampling = binding.resamplingEnabled;
  final originalTouchResamplingEnabled = binding is ElWidgetsFlutterBinding ? binding.touchResamplingEnabled : false;
  final originalResamplingEnabled = originalTouchResamplingEnabled || originalOfficialResampling;
  final setting = Obs<bool>(originalResamplingEnabled);
  setting.addListener(() {
    final enabled = setting.value;
    if (binding is ElWidgetsFlutterBinding) {
      if (enabled) {
        binding.touchResamplingEnabled = originalResamplingEnabled ? originalTouchResamplingEnabled : true;
        binding.resamplingEnabled = originalOfficialResampling;
      } else {
        binding.resamplingEnabled = false;
        binding.touchResamplingEnabled = false;
      }
    } else {
      binding.resamplingEnabled = enabled;
    }
  });
  return setting;
}
