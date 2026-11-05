import 'package:example/src/state/index.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('错误类型、未知滚动模式和菜单之外的压力倍率回到默认设置', () {
    final binding = GestureBinding.instance;
    final originalResampling = binding.resamplingEnabled;
    addTearDown(() => binding.resamplingEnabled = originalResampling);
    binding.resamplingEnabled = true;
    final storage = Obs.localStorage;
    final invalid = <String, Object>{
      'example.settings.isDark': 'true',
      'example.settings.showPerformanceOverlay': 1,
      'example.settings.debugShowCheckedModeBanner': <Object>[],
      'example.settings.excludeSemantics': <String, Object>{},
      'example.settings.docScrollMode': 'removedMode',
      'example.settings.docRepeatCount': 7,
      'example.settings.resamplingEnabled': 'false',
    };
    for (final entry in invalid.entries) {
      storage.setItem(entry.key, entry.value);
    }

    GlobalState.restoreSettings();
    expect(GlobalState.isDark.value, isFalse);
    expect(GlobalState.showPerformanceOverlay.value, isFalse);
    expect(GlobalState.debugShowCheckedModeBanner.value, isTrue);
    expect(GlobalState.excludeSemantics.value, isFalse);
    expect(GlobalState.docScrollMode.value, DocScrollMode.elScrollView);
    expect(GlobalState.docRepeatCount.value, 1);
    expect(GlobalState.resamplingEnabled.value, isTrue);
    expect(binding.resamplingEnabled, isTrue);
    final defaults = <String, Object>{
      'example.settings.isDark': false,
      'example.settings.showPerformanceOverlay': false,
      'example.settings.debugShowCheckedModeBanner': true,
      'example.settings.excludeSemantics': false,
      'example.settings.docScrollMode': 'elScrollView',
      'example.settings.docRepeatCount': 1,
      'example.settings.resamplingEnabled': true,
    };
    for (final entry in defaults.entries) {
      expect(storage.getItem<Object>(entry.key), entry.value, reason: entry.key);
    }
  });
}
