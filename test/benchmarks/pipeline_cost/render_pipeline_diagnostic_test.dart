import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// 只测 CPU 排版与绘制指令录制；不经过 Widget，也不声称是设备 UI 帧或 GPU 耗时。
const _enabled = bool.fromEnvironment('PIPELINE_DIAGNOSTIC');
final _fontPath = Platform.environment['PIPELINE_CJK_FONT'] ?? 'C:/Windows/Fonts/msyh.ttc';
final _fontFamily = 'PipelineDiagnosticCjk';
final _cardConstraints = BoxConstraints.tight(Size(400, 600));
final _paragraphCount = 48;
final _samples = 20;

enum _Scenario { clean, parentDirty, changedText, paintOnly, textPainterChanged }

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final skip = !_enabled
      ? '通过 --dart-define=PIPELINE_DIAGNOSTIC=true 启用短时诊断。'
      : !File(_fontPath).existsSync()
      ? '缺少真实中文字体：$_fontPath；不能用 Ahem 代替中文排版。'
      : false;

  test('纯 RenderObject 的换字、布局和绘制录制阶段成本', skip: skip, () async {
    final fontBytes = await File(_fontPath).readAsBytes();
    await (FontLoader(_fontFamily)..addFont(Future.value(ByteData.sublistView(fontBytes)))).load();
    final cards = {
      for (final scenario in _Scenario.values)
        if (scenario != .textPainterChanged) scenario: _Card(_payload(10000 + scenario.index)),
    };
    final painters = _PainterCard(_payload(13700));
    final samples = {for (final scenario in _Scenario.values) scenario: <Map<String, double>>[]};
    try {
      // 先走过每种路径；每轮轮转执行顺序，降低 JIT 和执行顺序偏差。
      for (var sample = -3; sample < _samples; sample++) {
        for (var position = 0; position < _Scenario.values.length; position++) {
          final scenario = _Scenario.values[(position + sample + _Scenario.values.length) % _Scenario.values.length];
          if (scenario == .textPainterChanged) {
            // 店号与 RenderParagraph 组等长且相差 37 的整倍数，价格、字数与结构不变。
            final payload = _payload(23700 + (sample + 3) * 100 + _Scenario.changedText.index);
            final result = painters.measure(payload);
            if (sample >= 0) samples[scenario]!.add(result);
            continue;
          }
          final card = cards[scenario]!;
          final payload = _payload(20000 + (sample + 3) * 100 + scenario.index);
          final beforeTextLayouts = card.textLayoutCalls;
          final beforeLeafLayoutUs = card.textLayoutUs;
          final beforeRootLayouts = card.root.layoutCalls;
          final updateUs = _measure(() {
            switch (scenario) {
              case .changedText:
                card.replaceText(payload);
              case .parentDirty:
                card.root.markNeedsLayout();
              case .paintOnly:
                card.root.markNeedsPaint();
              case .clean:
                break;
              case .textPainterChanged:
                throw StateError('TextPainter 对照不经过 RenderObject。');
            }
          });
          final layoutUs = _measure(() {
            if (scenario == .clean) {
              card.root.layout(_cardConstraints);
            } else {
              card.owner.flushLayout();
            }
          });
          // 合成状态维护不计入文字布局或 CPU paint，当前树没有独立合成子层。
          card.owner.flushCompositingBits();
          var paintUs = 0.0;
          if (scenario != .clean) {
            final recording = _Recording();
            try {
              paintUs = _measure(() {
                recording.context.paintChild(card.root, Offset.zero);
                recording.context.finish();
              });
              expect(recording.hasPicture, isTrue, reason: '必须经过真实 PictureRecorder，而非假画布。');
            } finally {
              recording.dispose();
            }
          }

          final textLayouts = card.textLayoutCalls - beforeTextLayouts;
          final leafLayoutUs = card.textLayoutUs - beforeLeafLayoutUs;
          if (scenario == .changedText) {
            expect(textLayouts, _paragraphCount);
            expect(card.paragraphs.first.text.toPlainText(), payload.first.toPlainText());
          } else {
            expect(textLayouts, 0, reason: '同约束且文字不变时，不能误把 layout 调用数当成实际重排。');
          }
          expect(card.root.layoutCalls - beforeRootLayouts, scenario == .parentDirty ? 1 : 0);
          if (sample >= 0) {
            samples[scenario]!.add({
              'update_us': updateUs,
              'layout_us': layoutUs,
              'leaf_perform_layout_us': leafLayoutUs,
              'layout_outside_leaf_us': layoutUs - leafLayoutUs,
              'paint_record_us': paintUs,
              'stages_total_us': updateUs + layoutUs + paintUs,
            });
          }
        }
      }
      for (final scenario in _Scenario.values) {
        final rows = samples[scenario]!;
        debugPrintSynchronously(
          'RENDER_PIPELINE_RESULT ${jsonEncode({
            'scenario': scenario.name,
            'scope': 'flutter_tester debug CPU; no Widget/ElView/Sliver; excludes GPU/raster/presentation',
            'paragraphs_per_card': _paragraphCount,
            'samples': rows.length,
            'font_path': _fontPath,
            'font_bytes': fontBytes.length,
            'font_family': _fontFamily,
            'card_size': [400, 600],
            'text_constraints': {'min_width': 100, 'max_width': 100, 'render_box_height': 50},
            'text_config': {'font_size': 13, 'height': 1.3, 'max_lines': 'first column 2; other columns 1', 'ellipsis': '…'},
            'debug_flags': _debugFlags(),
            'comparison': 'textPainterChanged uses the same payload template and store id +3700; equal length and price modulus, disjoint namespace',
            'layout_probe': 'leaf_perform_layout_us includes RenderParagraph.performLayout only; per-leaf Stopwatch adds small diagnostic overhead',
            'paint_policy': 'clean: no paint; other scenarios: rerecord entire card without repaint boundaries',
            'clip_policy': 'RenderParagraph ellipsis clips on visual overflow; TextPainter control applies equivalent 100x50 clip for exceeded max lines or bounds',
            'excluded': ['payload construction', 'initial tree creation', 'compositing bits', 'assertions', 'disposal'],
            'stages': {for (final key in rows.first.keys) key: _summary(rows.map((row) => row[key]!).toList())},
          })}',
        );
      }
    } finally {
      for (final card in cards.values) {
        card.dispose();
      }
      painters.dispose();
    }
  }, timeout: Timeout(Duration(seconds: 30)));
}

Map<String, bool> _debugFlags() => {
  'debugCheckIntrinsicSizes': debugCheckIntrinsicSizes,
  'debugProfileLayoutsEnabled': debugProfileLayoutsEnabled,
  'debugProfilePaintsEnabled': debugProfilePaintsEnabled,
  'debugPaintSizeEnabled': debugPaintSizeEnabled,
  'debugPaintBaselinesEnabled': debugPaintBaselinesEnabled,
  'debugPaintLayerBordersEnabled': debugPaintLayerBordersEnabled,
  'debugRepaintRainbowEnabled': debugRepaintRainbowEnabled,
  'debugRepaintTextRainbowEnabled': debugRepaintTextRainbowEnabled,
};

double _measure(void Function() work) {
  final stopwatch = Stopwatch()..start();
  work();
  stopwatch.stop();
  return stopwatch.elapsedTicks * 1000000 / stopwatch.frequency;
}

Map<String, double> _summary(List<double> values) {
  values.sort();
  double percentile(double ratio) => values[((values.length - 1) * ratio).round()];
  return {
    'p50': percentile(.5),
    'p90': percentile(.9),
    'max': values.last,
    'mean': values.reduce((a, b) => a + b) / values.length,
  };
}

List<TextSpan> _payload(int store) => [
  for (var i = 0; i < _paragraphCount; i++)
    TextSpan(
      text: switch (i % 4) {
        0 => '田叔豆浆现磨豆浆套餐门店$store商品$i',
        1 => '¥${store % 37 + i}.8 优惠价',
        2 => '月售${store + i}份 · 好评98%',
        _ => '鲜香现做送到家 商家$store',
      },
      style: TextStyle(fontFamily: _fontFamily, fontSize: 13, height: 1.3, color: Color(0xff222222)),
    ),
];

class _Card {
  _Card(List<TextSpan> payload) {
    for (var row = 0; row < 12; row++) {
      final cells = <RenderBox>[];
      for (var column = 0; column < 4; column++) {
        final index = row * 4 + column;
        final paragraph = _Paragraph(payload[index], index % 4 == 0 ? 2 : 1);
        paragraphs.add(paragraph);
        cells.add(RenderConstrainedBox(additionalConstraints: BoxConstraints.tight(Size(100, 50)), child: paragraph));
      }
      root.add(RenderFlex(direction: .horizontal, textDirection: .ltr, children: cells));
    }
    owner.rootNode = root;
    root.layout(_cardConstraints);
    owner.flushCompositingBits();
    for (final paragraph in paragraphs) {
      expect(paragraph.size, Size(100, 50));
      expect((paragraph.text as TextSpan).style!.fontFamily, _fontFamily);
    }
  }

  final owner = PipelineOwner();
  final root = _Root();
  final paragraphs = <_Paragraph>[];
  int get textLayoutCalls => paragraphs.fold(0, (sum, item) => sum + item.layoutCalls);
  double get textLayoutUs => paragraphs.fold(0, (sum, item) => sum + item.layoutUs);

  void replaceText(List<TextSpan> payload) {
    for (var i = 0; i < paragraphs.length; i++) {
      paragraphs[i].text = payload[i];
    }
  }

  void dispose() {
    owner.rootNode = null;
    _disposeTree(root);
    owner.dispose();
  }
}

class _Root extends RenderFlex {
  _Root() : super(direction: .vertical, crossAxisAlignment: .start, textDirection: .ltr);
  int layoutCalls = 0;

  @override
  void performLayout() {
    layoutCalls++;
    super.performLayout();
  }
}

class _Paragraph extends RenderParagraph {
  _Paragraph(super.text, int lines) : super(textDirection: .ltr, maxLines: lines, overflow: .ellipsis);
  int layoutCalls = 0;
  final _layoutWatch = Stopwatch();
  int _layoutTicks = 0;
  double get layoutUs => _layoutTicks * 1000000 / _layoutWatch.frequency;

  @override
  void performLayout() {
    layoutCalls++;
    _layoutWatch
      ..reset()
      ..start();
    try {
      super.performLayout();
    } finally {
      _layoutWatch.stop();
      _layoutTicks += _layoutWatch.elapsedTicks;
    }
  }
}

class _PainterCard {
  _PainterCard(List<TextSpan> payload) {
    for (var i = 0; i < payload.length; i++) {
      painters.add(
        TextPainter(text: payload[i], textDirection: .ltr, maxLines: i % 4 == 0 ? 2 : 1, ellipsis: '…')
          ..layout(minWidth: 100, maxWidth: 100),
      );
    }
  }

  final painters = <TextPainter>[];

  Map<String, double> measure(List<TextSpan> payload) {
    final oldText = painters.first.text!.toPlainText();
    final updateUs = _measure(() {
      for (var i = 0; i < painters.length; i++) {
        painters[i].text = payload[i];
      }
    });
    final layoutUs = _measure(() {
      for (final painter in painters) {
        painter.layout(minWidth: 100, maxWidth: 100);
      }
    });
    final recording = _Recording();
    late final double paintUs;
    try {
      paintUs = _measure(() {
        final canvas = recording.context.canvas;
        for (var i = 0; i < painters.length; i++) {
          final painter = painters[i];
          final offset = Offset((i % 4) * 100, (i ~/ 4) * 50);
          final clipped = painter.didExceedMaxLines || painter.height > 50 || painter.width > 100;
          if (clipped) {
            canvas.save();
            canvas.clipRect(offset & Size(100, 50));
          }
          painter.paint(canvas, offset);
          if (clipped) canvas.restore();
        }
        recording.context.finish();
      });
      expect(recording.hasPicture, isTrue);
    } finally {
      recording.dispose();
    }
    expect(painters.first.text!.toPlainText(), payload.first.toPlainText());
    expect(painters.first.text!.toPlainText(), isNot(oldText));
    for (final painter in painters) {
      expect(painter.width, 100);
      expect(painter.height, greaterThan(0));
    }
    return {
      'update_us': updateUs,
      'layout_us': layoutUs,
      'paint_record_us': paintUs,
      'stages_total_us': updateUs + layoutUs + paintUs,
    };
  }

  void dispose() {
    for (final painter in painters) {
      painter.dispose();
    }
  }
}

class _Recording {
  _Recording() {
    context = _Context(layer.layer!, Rect.fromLTWH(0, 0, 400, 600));
  }
  final layer = LayerHandle<ContainerLayer>(ContainerLayer());
  late final _Context context;
  bool get hasPicture {
    var child = layer.layer!.firstChild;
    while (child != null) {
      if (child is PictureLayer && child.picture != null) return true;
      child = child.nextSibling;
    }
    return false;
  }

  void dispose() => layer.layer = null;
}

class _Context extends PaintingContext {
  _Context(super.containerLayer, super.estimatedBounds);
  void finish() => stopRecordingIfNeeded();
}

void _disposeTree(RenderObject object) {
  final children = <RenderObject>[];
  object.visitChildren(children.add);
  if (object is RenderFlex) object.removeAll();
  if (object is RenderConstrainedBox) object.child = null;
  for (final child in children) {
    _disposeTree(child);
  }
  object.dispose();
}
