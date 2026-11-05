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
  static final isDark = Obs(false, cacheKey: 'example.settings.isDark');

  /// 是否显示 Flutter 性能图层。
  static final showPerformanceOverlay = Obs(false, cacheKey: 'example.settings.showPerformanceOverlay');

  /// 是否显示调试横幅。
  static final debugShowCheckedModeBanner = Obs(true, cacheKey: 'example.settings.debugShowCheckedModeBanner');

  /// 是否屏蔽整个示例应用的辅助技术语义。
  static final excludeSemantics = Obs(false, cacheKey: 'example.settings.excludeSemantics');

  /// 所有通用文档页使用的滚动实现。
  static final docScrollMode = Obs(
    DocScrollMode.elScrollView,
    cacheKey: 'example.settings.docScrollMode',
    serialize: ElEnumSerialize<DocScrollMode>(DocScrollMode.values),
  );

  /// 所有通用文档页正文小节的重复倍数。
  static final docRepeatCount = _createRepeatCountSetting();

  /// 是否启用当前应用绑定实际配置的触摸重采样。
  static final resamplingEnabled = _createResamplingSetting();

  /// 在存储初始化后恢复全部设置，并通知监听器立即应用系统配置。
  static void restoreSettings() {
    for (final setting in [
      isDark,
      showPerformanceOverlay,
      debugShowCheckedModeBanner,
      excludeSemantics,
      docScrollMode,
      docRepeatCount,
      resamplingEnabled,
    ]) {
      setting.notify();
    }
  }
}

Obs<int> _createRepeatCountSetting() {
  final setting = Obs(1, cacheKey: 'example.settings.docRepeatCount');
  if (![1, 2, 5, 10, 20].contains(setting.rawValue)) {
    // 旧缓存只允许恢复设置菜单实际提供的倍率，避免异常值放大整页工作量。
    setting.storage.removeItem(setting.cacheKey!);
    setting.rawValue = 1;
  }
  return setting;
}

Obs<bool> _createResamplingSetting() {
  final binding = GestureBinding.instance;
  // 开启时恢复原采样路径，避免切换设置时无意改用另一套采样实现。
  final originalOfficialResampling = binding.resamplingEnabled;
  final originalTouchResamplingEnabled = binding is ElWidgetsFlutterBinding ? binding.touchResamplingEnabled : false;
  final originalResamplingEnabled = originalTouchResamplingEnabled || originalOfficialResampling;
  final setting = Obs<bool>(originalResamplingEnabled, cacheKey: 'example.settings.resamplingEnabled');
  void apply() {
    final enabled = setting.rawValue;
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
  }

  setting.addListener(apply);
  // Obs 已同步恢复缓存，启动时就应用真实输入开关，不等用户重新打开设置页。
  apply();
  return setting;
}
