import 'package:flutter_base/ui.dart';
import 'package:flutter_test/flutter_test.dart';

/// ElFpsCounter 纯逻辑单测：整秒落桶结算口径 + 历史 bug 回归。
void main() {
  const us = 1000000;

  /// 生成从 [startUs] 开始、间隔 [intervalUs] 的 n 个时间戳。
  List<int> frames(int startUs, int intervalUs, int n) => [for (var i = 0; i < n; i++) startUs + i * intervalUs];

  group('ElFpsCounter', () {
    test('165Hz 跨过整秒结算 165（锚定帧不计数，无 fencepost 偏差）', () {
      final counter = ElFpsCounter();
      final interval = us ~/ 165;
      // 167 帧：第 167 帧跨过 1 秒边界，触发结算
      final rate = counter.addBatch(frames(0, interval, 167));
      expect(rate, 165);
    });

    test('60Hz → 60', () {
      final counter = ElFpsCounter();
      final rate = counter.addBatch(frames(0, us ~/ 60, 62));
      expect(rate, 60);
    });

    test('桶内累计阶段返回 null（数字每秒只跳一次）', () {
      final counter = ElFpsCounter();
      final interval = us ~/ 165;
      expect(counter.addBatch(frames(0, interval, 100)), isNull); // 0.6 秒
      expect(counter.addBatch(frames(100 * interval, interval, 50)), isNull); // 0.9 秒
    });

    test('攒批投递不影响数值（时间戳落桶，回归：165Hz 显示 170）', () {
      final a = ElFpsCounter();
      final b = ElFpsCounter();
      final interval = us ~/ 165;
      final all = frames(0, interval, 167);
      // 一次性投递 vs 模拟延迟攒批逐段投递，结果必须一致
      final rateA = a.addBatch(all);
      int? rateB;
      for (var i = 0; i < all.length; i += 16) {
        final r = b.addBatch(all.sublist(i, (i + 16).clamp(0, all.length)));
        if (r != null) rateB = r;
      }
      expect(rateA, 165);
      expect(rateB, 165);
    });

    test('连续多秒每秒结算一次，掉帧的秒如实反映', () {
      final counter = ElFpsCounter();
      final interval = us ~/ 165;
      counter.addBatch(frames(0, interval, 166)); // 第 1 秒桶内
      // 第 2 秒帧率减半（间隔翻倍）
      final start2 = 166 * interval;
      final r1 = counter.addBatch([start2]); // 跨界帧，结算第 1 秒
      expect(r1, 165);
      final r2 = counter.addBatch(frames(start2 + interval * 2, interval * 2, 90));
      expect(r2, closeTo(82, 2)); // 第 2 秒 ~82 帧
    });

    test('长间隙断流后从当前帧重新锚定，不与旧流混算', () {
      final counter = ElFpsCounter();
      final interval = us ~/ 165;
      counter.addBatch(frames(0, interval, 100));
      // 3 秒后新动画：跨过 ≥2 个空桶 → 重新锚定，之后正常整秒结算
      final restart = 100 * interval + 3 * us;
      counter.addBatch([restart]);
      final rate = counter.addBatch(frames(restart + us ~/ 60, us ~/ 60, 61));
      expect(rate, 60);
    });

    test('乱序/重复时间戳防御', () {
      final counter = ElFpsCounter();
      final interval = us ~/ 60;
      final ts = frames(0, interval, 62);
      // 混入重复帧与乱序帧，不得多计
      final polluted = [...ts.take(30), ts[29], ts[10], ...ts.skip(30)];
      expect(counter.addBatch(polluted), 60);
    });

    test('reset 后重新锚定，从零开始', () {
      final counter = ElFpsCounter();
      counter.addBatch(frames(0, us ~/ 60, 30));
      counter.reset();
      // reset 后旧桶作废；喂满新一秒才再次出值
      expect(counter.addBatch(frames(us * 5, us ~/ 60, 30)), isNull);
      expect(counter.addBatch(frames(us * 5 + 30 * (us ~/ 60), us ~/ 60, 32)), 60);
    });

    test('2fps 慢动画如实结算 2', () {
      final counter = ElFpsCounter();
      // 间隔 500ms：第 3 帧（t=1s）跨界结算，桶内 2 个间隔
      final rate = counter.addBatch(frames(0, us ~/ 2, 4));
      expect(rate, 2);
    });
  });
}
