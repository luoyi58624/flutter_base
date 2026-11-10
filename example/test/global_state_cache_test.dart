import 'package:example/src/state/index.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('全部系统设置从缓存恢复，修改后写入快照且关闭重开后仍可恢复', () async {
    final binding = GestureBinding.instance;
    final originalResampling = binding.resamplingEnabled;
    addTearDown(() => binding.resamplingEnabled = originalResampling);
    binding.resamplingEnabled = true;
    final storage = Obs.localStorage;
    final cached = <String, Object>{
      'example.settings.isDark': true,
      'example.settings.showPerformanceOverlay': true,
      'example.settings.debugShowCheckedModeBanner': false,
      'example.settings.excludeSemantics': true,
      'example.settings.docScrollMode': 'recyclerView',
      'example.settings.docRepeatCount': 20,
      'example.settings.resamplingEnabled': false,
    };
    for (final entry in cached.entries) {
      storage.setItem(entry.key, entry.value);
    }

    GlobalState.restoreSettings();
    expect(GlobalState.isDark.value, isTrue);
    expect(GlobalState.showPerformanceOverlay.value, isTrue);
    expect(GlobalState.debugShowCheckedModeBanner.value, isFalse);
    expect(GlobalState.excludeSemantics.value, isTrue);
    expect(GlobalState.docScrollMode.value, DocScrollMode.sliverList);
    expect(storage.getItem<Object>('example.settings.docScrollMode'), 'sliverList');
    expect(GlobalState.docRepeatCount.value, 20);
    expect(GlobalState.resamplingEnabled.value, isFalse);
    expect(binding.resamplingEnabled, isFalse, reason: '缓存恢复时就要应用实际输入开关');

    GlobalState.isDark.value = false;
    GlobalState.showPerformanceOverlay.value = false;
    GlobalState.debugShowCheckedModeBanner.value = true;
    GlobalState.excludeSemantics.value = false;
    GlobalState.docScrollMode.value = DocScrollMode.sliverList;
    GlobalState.docRepeatCount.value = 5;
    GlobalState.resamplingEnabled.value = true;
    expect(binding.resamplingEnabled, isTrue);

    final expected = <String, Object>{
      'example.settings.isDark': false,
      'example.settings.showPerformanceOverlay': false,
      'example.settings.debugShowCheckedModeBanner': true,
      'example.settings.excludeSemantics': false,
      'example.settings.docScrollMode': 'sliverList',
      'example.settings.docRepeatCount': 5,
      'example.settings.resamplingEnabled': true,
    };
    final group = storage.group;
    group.close(storage.key);
    final reopened = await group.open(storage.key, debounceTime: 0);
    Obs.localStorage = reopened;
    expect(identical(reopened, storage), isFalse);
    for (final entry in expected.entries) {
      expect(reopened.getItem<Object>(entry.key), entry.value, reason: entry.key);
    }

    final booleans = [
      GlobalState.isDark,
      GlobalState.showPerformanceOverlay,
      GlobalState.debugShowCheckedModeBanner,
      GlobalState.excludeSemantics,
      GlobalState.resamplingEnabled,
    ];
    for (final model in booleans) {
      final restored = Obs(!model.rawValue, cacheKey: model.cacheKey);
      expect(restored.value, model.value, reason: model.cacheKey);
      restored.dispose();
    }
    final mode = Obs(
      DocScrollMode.elScroll,
      cacheKey: GlobalState.docScrollMode.cacheKey,
      serialize: GlobalState.docScrollMode.serialize,
    );
    final pressure = Obs(1, cacheKey: GlobalState.docRepeatCount.cacheKey);
    expect(mode.value, DocScrollMode.sliverList);
    expect(pressure.value, 5);
    mode.dispose();
    pressure.dispose();
  });
}
