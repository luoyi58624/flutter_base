import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// 只测无头进程中的文字 CPU 管线，不把录制耗时当作光栅化或设备帧耗时。
const _enabled = bool.fromEnvironment('PIPELINE_DIAGNOSTIC');
final _fontPath = Platform.environment['PIPELINE_CJK_FONT'] ?? 'C:/Windows/Fonts/msyh.ttc';
final _fontFamily = 'PipelineDiagnosticCjk';
final _paragraphsPerCard = 48;
final _rounds = 3;
final _samplesPerRound = 8;
final _warmupPerRound = 2;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final fontFile = File(_fontPath);

  test(
    '真实中文字体：直接 Paragraph 与 TextPainter 的分阶段 CPU 成本',
    () async {
      final fontBytes = await fontFile.readAsBytes();
      await (FontLoader(_fontFamily)..addFont(Future.value(ByteData.sublistView(fontBytes)))).load();

      final probes = <_Probe>[
        _Probe('paragraph_unique', _Backend.paragraph, _Content.unique, 100000),
        _Probe('paragraph_two_card_cycle', _Backend.paragraph, _Content.twoCardCycle, 110000),
        _Probe('text_painter_new_unique', _Backend.newPainter, _Content.unique, 120000),
        _Probe('text_painter_new_two_card_cycle', _Backend.newPainter, _Content.twoCardCycle, 130000),
        _Probe('text_painter_rebind_unique', _Backend.reusedPainter, _Content.unique, 140000),
        _Probe('text_painter_rebind_two_card_cycle', _Backend.reusedPainter, _Content.twoCardCycle, 150000),
        _Probe('text_painter_unchanged_same_span', _Backend.reusedPainter, _Content.sameSpan, 160000),
        _Probe('text_painter_unchanged_equal_span', _Backend.reusedPainter, _Content.equalSpan, 170000),
        _Probe('paragraph_unique_no_ellipsis', _Backend.paragraph, _Content.unique, 180000, ellipsis: false),
      ];
      addTearDown(() {
        for (final probe in probes) {
          probe.dispose();
        }
      });

      debugPrintSynchronously(
        'PIPELINE_TEXT_METADATA ${jsonEncode({'scope': 'headless_cpu_microbenchmark_not_device_frame_or_raster', 'mode': kDebugMode ? 'debug' : (kProfileMode ? 'profile' : 'release'), 'os': Platform.operatingSystem, 'dart': Platform.version, 'font_path': fontFile.absolute.path, 'font_family': _fontFamily, 'font_bytes': fontBytes.length, 'paragraphs_per_card': _paragraphsPerCard, 'single_line_paragraphs': 44, 'two_line_paragraphs': 4, 'ellipsis': 'per_case', 'samples_per_case': _rounds * _samplesPerRound, 'warmup_per_case': _rounds * _warmupPerRound, 'dataset_and_text_spans_prebuilt': true, 'record_includes_picture_end_recording': true, 'record_excludes_raster_gpu_scene_semantics_and_images': true, 'two_card_cycle_is_cache_opportunity_not_verified_engine_cache_hit': true, 'one_card_is_all_48_texts_changed_in_rebind_cases': true})}',
      );

      // 每轮轮换场景顺序，组内连续采样保留重复文本可命中引擎缓存的机会。
      for (var round = 0; round < _rounds; round++) {
        for (var position = 0; position < probes.length; position++) {
          final probe = probes[(position + round * 3) % probes.length];
          for (var i = 0; i < _warmupPerRound; i++) {
            probe.run(measure: false);
          }
          for (var i = 0; i < _samplesPerRound; i++) {
            probe.run(measure: true);
          }
        }
      }

      for (final probe in probes) {
        expect(probe.samples.length, _rounds * _samplesPerRound);
        expect(probe.positiveParagraphs, greaterThan(0), reason: '必须实际排版中文字形，不能只构造空对象。');
        expect(probe.pictureBytes, greaterThan(0), reason: '每轮必须完成非空绘制指令录制。');
        expect(probe.overflowParagraphs, greaterThan(0), reason: '省略号对照必须实际触发超长文本，不能只修改未使用的配置。');
        if (probe.content == _Content.unique || probe.content == _Content.twoCardCycle) {
          expect(probe.changedParagraphs, _paragraphsPerCard * (probe.runs - 1));
        } else {
          expect(probe.changedParagraphs, 0);
        }
        debugPrintSynchronously('PIPELINE_TEXT_RESULT ${jsonEncode(probe.result)}');
      }
    },
    skip: !_enabled
        ? '按需运行：--dart-define=PIPELINE_DIAGNOSTIC=true。'
        : fontFile.existsSync()
        ? false
        : '缺少真实中文字体：设置 PIPELINE_CJK_FONT 后再运行，禁止回退 Ahem。',
    timeout: Timeout(Duration(seconds: 45)),
  );
}

enum _Backend { paragraph, newPainter, reusedPainter }

enum _Content { unique, twoCardCycle, sameSpan, equalSpan }

class _Cell {
  _Cell(this.text, this.width, this.fontSize, this.maxLines, this.bold)
    : span = TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: _fontFamily,
          fontSize: fontSize,
          fontWeight: bold ? .w700 : .w400,
          height: 1.3,
          color: Color(0xff282420),
        ),
      ),
      paragraphStyle = ui.ParagraphStyle(
        textDirection: .ltr,
        fontFamily: _fontFamily,
        fontSize: fontSize,
        fontWeight: bold ? .w700 : .w400,
        height: 1.3,
        maxLines: maxLines,
        ellipsis: '…',
      ),
      clipParagraphStyle = ui.ParagraphStyle(
        textDirection: .ltr,
        fontFamily: _fontFamily,
        fontSize: fontSize,
        fontWeight: bold ? .w700 : .w400,
        height: 1.3,
        maxLines: maxLines,
      ),
      textStyle = ui.TextStyle(
        fontFamily: _fontFamily,
        fontSize: fontSize,
        fontWeight: bold ? .w700 : .w400,
        height: 1.3,
        color: Color(0xff282420),
      );

  final String text;
  final double width;
  final double fontSize;
  final int maxLines;
  final bool bold;
  final TextSpan span;
  final ui.ParagraphStyle paragraphStyle;
  final ui.ParagraphStyle clipParagraphStyle;
  final ui.TextStyle textStyle;
}

List<_Cell> _card(int id) => [
  _Cell('邻里饭桌·现炒盖饭（科技园$id店）', 230, 17, 1, true),
  _Cell('月售${id + 2341}+ 好评${id + 985}条', 220, 12, 1, false),
  _Cell('配送${id + 23}分钟', 100, 12, 1, false),
  _Cell('距离${id + 18}米', 100, 11, 1, false),
  _Cell('每日清晨采购新鲜食材，坚持现点现做，菜品编号$id，米饭选用东北当季大米，荤素搭配。', 330, 13, 2, false),
  _Cell('附近居民都爱吃的家常味道，第$id份订单正在准备，热乎现炒，配菜每天更新。', 330, 12, 2, false),
  _Cell('店铺红包$id元', 110, 11, 1, false),
  _Cell('满$id减8', 90, 11, 1, false),
  _Cell('第$id单免配送费', 100, 11, 1, false),
  _Cell('欢迎光临$id号店', 140, 11, 1, false),
  _Cell('用户评价$id：分量充足，送到还是热的，包装也很用心，下次还会继续点。', 320, 12, 2, false),
  _Cell('门店$id：明厨亮灶，独立封签，放心选购，食材每日新鲜采购。', 320, 11, 2, false),
  for (var dish = 0; dish < 12; dish++) ...[
    _Cell('秘制红烧肉双拼套餐${id + dish}', 104, 12, 1, true),
    _Cell('当季新品·月售${id * 13 + dish}', 104, 10, 1, false),
    _Cell('¥${id + dish}.80', 75, 15, 1, true),
  ],
];

class _Measurement {
  _Measurement(this.prepare, this.layout, this.record, this.dispose, this.total);
  final int prepare;
  final int layout;
  final int record;
  final int dispose;
  final int total;
}

class _Probe {
  _Probe(this.name, this.backend, this.content, int base, {this.ellipsis = true})
    : cards = switch (content) {
        _Content.unique => [for (var i = 0; i < _rounds * (_samplesPerRound + _warmupPerRound); i++) _card(base + i)],
        _Content.twoCardCycle => [_card(base), _card(base + 1)],
        _Content.sameSpan => [_card(base)],
        // 内容相同但 TextSpan 实例不同，用来验证深比较后的布局缓存路径。
        _Content.equalSpan => [_card(base), _card(base)],
      };

  final String name;
  final _Backend backend;
  final _Content content;
  final bool ellipsis;
  final List<List<_Cell>> cards;
  final samples = <_Measurement>[];
  List<TextPainter>? _retained;
  List<_Cell>? _previous;
  var runs = 0;
  var changedParagraphs = 0;
  var positiveParagraphs = 0;
  var pictureBytes = 0;
  var overflowParagraphs = 0;

  void run({required bool measure}) {
    final cells = cards[runs % cards.length];
    if (_previous case final previous?) {
      for (var i = 0; i < cells.length; i++) {
        if (cells[i].text != previous[i].text) changedParagraphs++;
      }
    }
    _previous = cells;
    runs++;
    final sample = backend == _Backend.paragraph ? _runParagraph(cells) : _runPainter(cells);
    if (measure) samples.add(sample);
  }

  _Measurement _runParagraph(List<_Cell> cells) {
    final paragraphs = <ui.Paragraph>[];
    final clock = Stopwatch()..start();
    for (final cell in cells) {
      final builder = ui.ParagraphBuilder(ellipsis ? cell.paragraphStyle : cell.clipParagraphStyle)
        ..pushStyle(cell.textStyle);
      builder.addText(cell.text);
      paragraphs.add(builder.build());
    }
    final prepared = clock.elapsedMicroseconds;
    for (var i = 0; i < cells.length; i++) {
      paragraphs[i].layout(ui.ParagraphConstraints(width: cells[i].width));
    }
    final laidOut = clock.elapsedMicroseconds;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    for (var i = 0; i < paragraphs.length; i++) {
      canvas.drawParagraph(paragraphs[i], ui.Offset((i % 6) * 360, (i ~/ 6) * 80));
    }
    final picture = recorder.endRecording();
    final recorded = clock.elapsedMicroseconds;
    final bytes = picture.approximateBytesUsed;
    final positives = paragraphs.where((paragraph) => paragraph.height > 0 && paragraph.longestLine > 0).length;
    final overflow = paragraphs.where((paragraph) => paragraph.didExceedMaxLines).length;
    final disposalStart = clock.elapsedMicroseconds;
    picture.dispose();
    for (final paragraph in paragraphs) {
      paragraph.dispose();
    }
    final disposed = clock.elapsedMicroseconds;
    clock.stop();
    pictureBytes += bytes;
    positiveParagraphs += positives;
    overflowParagraphs += overflow;
    final disposal = disposed - disposalStart;
    return _Measurement(prepared, laidOut - prepared, recorded - laidOut, disposal, recorded + disposal);
  }

  _Measurement _runPainter(List<_Cell> cells) {
    final clock = Stopwatch()..start();
    final painters =
        _retained ??
        [
          for (final cell in cells)
            TextPainter(text: cell.span, textDirection: .ltr, maxLines: cell.maxLines, ellipsis: ellipsis ? '…' : null),
        ];
    if (_retained != null) {
      for (var i = 0; i < cells.length; i++) {
        painters[i].text = cells[i].span;
      }
    }
    if (backend == _Backend.reusedPainter) _retained = painters;
    final prepared = clock.elapsedMicroseconds;
    for (var i = 0; i < cells.length; i++) {
      painters[i].layout(minWidth: cells[i].width, maxWidth: cells[i].width);
    }
    final laidOut = clock.elapsedMicroseconds;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    for (var i = 0; i < painters.length; i++) {
      painters[i].paint(canvas, ui.Offset((i % 6) * 360, (i ~/ 6) * 80));
    }
    final picture = recorder.endRecording();
    final recorded = clock.elapsedMicroseconds;
    final bytes = picture.approximateBytesUsed;
    final positives = painters.where((painter) => painter.height > 0 && painter.width > 0).length;
    final overflow = painters.where((painter) => painter.didExceedMaxLines).length;
    final disposalStart = clock.elapsedMicroseconds;
    picture.dispose();
    if (backend == _Backend.newPainter) {
      for (final painter in painters) {
        painter.dispose();
      }
    }
    final disposed = clock.elapsedMicroseconds;
    clock.stop();
    pictureBytes += bytes;
    positiveParagraphs += positives;
    overflowParagraphs += overflow;
    final disposal = disposed - disposalStart;
    return _Measurement(prepared, laidOut - prepared, recorded - laidOut, disposal, recorded + disposal);
  }

  Map<String, Object> get result => {
    'case': name,
    'backend': backend.name,
    'content': content.name,
    'ellipsis': ellipsis,
    'paragraphs_per_card': _paragraphsPerCard,
    'samples': samples.length,
    'unit': 'microseconds_per_48_paragraph_card',
    'prepare_kind': backend == _Backend.paragraph ? 'native_paragraph_builder_and_build' : 'painter_create_or_set_text',
    'layout_kind': backend == _Backend.paragraph
        ? 'native_paragraph_layout'
        : 'text_painter_layout_including_native_build',
    'prepare_us': _distribution(samples.map((sample) => sample.prepare)),
    'layout_us': _distribution(samples.map((sample) => sample.layout)),
    'record_us': _distribution(samples.map((sample) => sample.record)),
    'dispose_us': _distribution(samples.map((sample) => sample.dispose)),
    'total_us': _distribution(samples.map((sample) => sample.total)),
    'changed_paragraphs_including_warmup': changedParagraphs,
    'overflow_paragraphs_including_warmup': overflowParagraphs,
  };

  void dispose() {
    for (final painter in _retained ?? <TextPainter>[]) {
      painter.dispose();
    }
    _retained = null;
  }
}

Map<String, num> _distribution(Iterable<int> values) {
  final sorted = values.toList()..sort();
  int percentile(double p) => sorted[((sorted.length * p).ceil() - 1).clamp(0, sorted.length - 1)];
  return {
    'p50': percentile(.5),
    'p90': percentile(.9),
    'min': sorted.first,
    'max': sorted.last,
    'mean': sorted.fold<int>(0, (sum, value) => sum + value) / sorted.length,
  };
}
