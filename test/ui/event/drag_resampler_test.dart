import 'package:flutter_base/src/ui/event/drag/resampling/resampler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('帧采样在相邻真实样本间插值，并限制外推为半个采样间隔', (tester) async {
    final base = await _primeFrameClock(tester);
    final positions = <Offset>[];
    final sampler = DragResampler(
      onSample: (_, position, _) => positions.add(position),
      samplingOffset: const Duration(milliseconds: -5),
      adaptive: false,
      seedTime: base,
      seedPosition: Offset.zero,
    );
    try {
      sampler.push(
        base + const Duration(milliseconds: 10),
        const Offset(10, 0),
      );

      await tester.pump(const Duration(milliseconds: 10));
      expect(sampler.lastSampleTime, base + const Duration(milliseconds: 5));
      expect(positions.last.dx, closeTo(5, 0.001));
      await tester.pump(const Duration(milliseconds: 10));
      expect(positions.last.dx, closeTo(15, 0.001));
      await tester.pump(const Duration(milliseconds: 100));
      expect(positions.last.dx, closeTo(15, 0.001), reason: '没有新输入时外推不能继续累积');
    } finally {
      sampler.dispose();
    }
  });

  for (final interval in [1, 25]) {
    testWidgets('采样间隔 ${interval}ms 不在有效速度窗口时停在最新真实样本', (tester) async {
      final base = await _primeFrameClock(tester);
      final sampler = DragResampler(
        onSample: (_, _, _) {},
        samplingOffset: Duration.zero,
        adaptive: false,
        seedTime: base,
        seedPosition: Offset.zero,
      );
      try {
        sampler.push(
          base + Duration(milliseconds: interval),
          const Offset(10, 0),
        );
        await tester.pump(const Duration(milliseconds: 40));
        expect(sampler.lastSampledPosition, const Offset(10, 0));
      } finally {
        sampler.dispose();
      }
    });
  }

  testWidgets('自适应尾随按真实触点节奏加深时间偏移且采样时刻不回退', (tester) async {
    final base = await _primeFrameClock(tester);
    final times = <Duration>[];
    final sampler = DragResampler(
      onSample: (sampler, _, _) => times.add(sampler.lastSampleTime!),
      samplingOffset: const Duration(milliseconds: -5),
      adaptive: true,
      seedTime: base,
      seedPosition: Offset.zero,
    );
    try {
      sampler.push(base + const Duration(milliseconds: 4), const Offset(4, 0));
      await tester.pump(const Duration(milliseconds: 12));
      final firstTime = sampler.lastSampleTime!;
      sampler.push(
        base + const Duration(milliseconds: 24),
        const Offset(24, 0),
      );
      await tester.pump(const Duration(milliseconds: 1));
      expect(sampler.lastSampleTime, greaterThanOrEqualTo(firstTime));
      await tester.pump(const Duration(milliseconds: 20));
      expect(times, orderedEquals(times.toList()..sort()));
      expect(
        sampler.lastSampleTime!,
        lessThan(
          tester.binding.currentSystemFrameTimeStamp -
              const Duration(milliseconds: 5),
        ),
      );
    } finally {
      sampler.dispose();
    }
  });

  testWidgets('外推后不倒退偿还尾差，真实反向超过阈值才恢复反向 delta', (tester) async {
    final base = await _primeFrameClock(tester);
    final deltas = <Offset>[];
    final sampler = DragResampler(
      onSample: (_, _, delta) => deltas.add(delta),
      samplingOffset: Duration.zero,
      adaptive: false,
      seedTime: base,
      seedPosition: Offset.zero,
    );
    try {
      sampler.push(
        base + const Duration(milliseconds: 10),
        const Offset(10, 0),
      );
      await tester.pump(const Duration(milliseconds: 16));
      expect(sampler.lastSampledPosition.dx, 15);
      expect(sampler.isOvershootPayback(const Offset(-1, 0)), isTrue);

      sampler.push(
        base + const Duration(milliseconds: 20),
        const Offset(12, 0),
      );
      await tester.pump(const Duration(milliseconds: 16));
      sampler.push(
        base + const Duration(milliseconds: 30),
        const Offset(11, 0),
      );
      await tester.pump(const Duration(milliseconds: 16));
      expect(deltas.every((delta) => delta.dx >= 0), isTrue);

      sampler.push(base + const Duration(milliseconds: 40), const Offset(8, 0));
      await tester.pump(const Duration(milliseconds: 16));
      expect(deltas.last.dx, lessThan(0));
    } finally {
      sampler.dispose();
    }
  });

  testWidgets('dispose 取消帧任务并拒绝后续输入', (tester) async {
    final base = await _primeFrameClock(tester);
    var callbacks = 0;
    final sampler = DragResampler(
      onSample: (_, _, _) => callbacks++,
      samplingOffset: Duration.zero,
      adaptive: false,
      seedTime: base,
      seedPosition: Offset.zero,
    );
    sampler.push(base + const Duration(milliseconds: 10), const Offset(10, 0));
    sampler.dispose();
    sampler.dispose();
    sampler.push(base + const Duration(milliseconds: 20), const Offset(20, 0));
    await tester.pump(const Duration(milliseconds: 30));
    expect(callbacks, 0);
    expect(sampler.lastSampledPosition, Offset.zero);
  });
}

/// 对齐测试假时钟与帧时戳，防止上一用例残留的时间影响采样。
Future<Duration> _primeFrameClock(WidgetTester tester) async {
  tester.binding.scheduleFrame();
  await tester.pump();
  return tester.binding.currentSystemFrameTimeStamp;
}
