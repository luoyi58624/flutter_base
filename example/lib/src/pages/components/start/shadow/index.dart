import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_base/mobile.dart';

/// 独立调节算法输入并对照五档阴影，不改变应用主题或组件默认样式。
class ShadowPage extends HookWidget {
  /// 创建阴影游乐场。
  const ShadowPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Scaffold 会移除 body 的底部 viewInsets，键盘高度在外层读取。
    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;
    final mode = useState(Theme.of(context).brightness);
    final level = useState(ElLevelType.md);
    final surfaceOverride = useState<Color?>(null);
    final backgroundOverride = useState<Color?>(null);
    final sameColor = useState(true);
    final width = useState(180.0), height = useState(120.0), radius = useState(26.0);
    final strength = useState(1.0), softness = useState(1.0);
    final vars = mode.value == Brightness.light ? ElMobileTheme.lightVars : ElMobileTheme.darkVars;
    final surface = surfaceOverride.value ?? vars[ElTokens.$cardColor] as Color;
    final background = sameColor.value
        ? surface.withValues(alpha: 1)
        : backgroundOverride.value ?? vars[ElTokens.$bgColor] as Color;
    final size = Size(width.value, height.value);
    final actualRadius = radius.value.clamp(0.0, size.shortestSide / 2);
    final borderRadius = BorderRadius.circular(actualRadius);
    List<BoxShadow> resolve(ElLevelType value) => ElShadow.resolve(
      level: value,
      brightness: mode.value,
      surfaceColor: surface,
      backgroundColor: background,
      borderRadius: borderRadius,
      size: size,
      strength: strength.value,
      softness: softness.value,
    );
    final shadows = resolve(level.value);
    final code =
        '''final shadows = ElShadow.resolve(
  level: ElLevelType.${level.value.name},
  brightness: Brightness.${mode.value.name},
  surfaceColor: ${_colorCode(surface)},
  backgroundColor: ${_colorCode(background)},
  borderRadius: BorderRadius.circular(${_number(actualRadius)}),
  size: Size(${_number(size.width)}, ${_number(size.height)}),
  strength: ${_number(strength.value)},
  softness: ${_number(softness.value)},
);

// 应用到相同尺寸与圆角的组件。
ElStyle(
  width: ${_number(size.width)},
  height: ${_number(size.height)},
  backgroundColor: ${_colorCode(surface)},
  borderRadius: BorderRadius.circular(${_number(actualRadius)}),
  boxShadow: shadows,
);''';

    void reset() {
      mode.value = Theme.of(context).brightness;
      level.value = ElLevelType.md;
      surfaceOverride.value = backgroundOverride.value = null;
      sameColor.value = true;
      width.value = 180;
      height.value = 120;
      radius.value = 26;
      strength.value = softness.value = 1;
    }

    final sample = _stage(
      level.value.name,
      size,
      borderRadius,
      surface,
      background,
      shadows,
      sampleKey: 'shadow-preview',
    );
    final comparison = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        spacing: 16,
        children: [
          for (final value in ElLevelType.types)
            SizedBox(
              width: size.width + 96,
              child: _stage(value.name, size, borderRadius, surface, background, resolve(value)),
            ),
        ],
      ),
    );
    final result = ExpansionTile(
      key: ValueKey('shadow-result'),
      title: Text('计算结果与 Dart 用法'),
      childrenPadding: .all(16),
      expandedCrossAxisAlignment: .stretch,
      children: [
        for (final (index, shadow) in shadows.indexed)
          Padding(
            padding: .only(bottom: 12),
            child: Text(
              '${index == 0 ? '近层' : '远层'}：'
              '浓度 ${_number(shadow.color.a * 100)}% · '
              '偏移 ${_number(shadow.offset.dy)} · 模糊 ${_number(shadow.blurRadius)} · '
              '扩张 ${_number(shadow.spreadRadius)}',
            ),
          ),
        SelectableText(code),
      ],
    );
    final preview = Column(
      crossAxisAlignment: .stretch,
      spacing: 16,
      children: [
        Text('阴影游乐场', style: Theme.of(context).textTheme.titleLarge),
        Text('调整颜色、尺寸与圆角，在相同条件下比较五档阴影。'),
        sample,
        Text('五档对照 · 横向滑动查看'),
        comparison,
        result,
      ],
    );
    final controls = ElCardView(
      style: ElStyle(backgroundColor: context.elTheme.cardColor, borderRadius: .circular(16), padding: .all(16)),
      child: Column(
        crossAxisAlignment: .stretch,
        spacing: 16,
        children: [
          Text('外观与层级', style: Theme.of(context).textTheme.titleMedium),
          _choices('预览主题', mode.value, [(Brightness.light, '浅色'), (Brightness.dark, '暗色')], (v) => mode.value = v),
          _choices('阴影级别', level.value, [for (final v in ElLevelType.types) (v, v.name)], (v) => level.value = v),
          SwitchListTile.adaptive(
            key: ValueKey('shadow-same-color'),
            contentPadding: .zero,
            title: Text('背景与组件同色'),
            value: sameColor.value,
            onChanged: (v) => sameColor.value = v,
          ),
          _ColorField(
            label: '组件颜色',
            fieldKey: 'shadow-surface',
            value: surface,
            onChanged: (v) => surfaceOverride.value = v,
          ),
          _ColorField(
            label: '背景颜色',
            fieldKey: 'shadow-background',
            value: background,
            enabled: !sameColor.value,
            opaque: true,
            onChanged: (v) => backgroundOverride.value = v,
          ),
          Divider(),
          Text('尺寸与圆角', style: Theme.of(context).textTheme.titleMedium),
          _slider('宽度', 'shadow-width', width.value, 80, 280, (v) => width.value = v),
          _slider('高度', 'shadow-height', height.value, 48, 240, (v) => height.value = v),
          _slider('圆角', 'shadow-radius', actualRadius, 0, size.shortestSide / 2, (v) => radius.value = v),
          Wrap(
            spacing: 8,
            children: [
              for (final (name, value) in [('直角', 0.0), ('圆角', 20.0), ('胶囊', size.shortestSide / 2)])
                ActionChip(label: Text(name), onPressed: () => radius.value = value),
            ],
          ),
          Divider(),
          Text('风格微调', style: Theme.of(context).textTheme.titleMedium),
          _slider('强度', 'shadow-strength', strength.value, 0, 2, (v) => strength.value = v, step: .05),
          _slider('柔和程度', 'shadow-softness', softness.value, .5, 2, (v) => softness.value = v, step: .05),
          Text('这里只调节预览。现有主题阴影保持原样。'),
        ],
      ),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text('阴影'),
        actions: [
          IconButton(tooltip: '恢复默认', onPressed: reset, icon: Icon(Icons.restart_alt)),
          IconButton(
            tooltip: '复制 Dart 用法',
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: code));
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已复制 Dart 用法')));
            },
            icon: Icon(Icons.copy),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final legacy = ExpansionTile(
            title: Text('旧版八档阴影 · 默认第 4 档'),
            childrenPadding: .symmetric(vertical: 40),
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  spacing: 16,
                  children: [
                    for (var e = 1; e <= _legacyBlurRadiusList.length; e++)
                      SizedBox(
                        width: size.width + 96,
                        child: _stage('$e', size, borderRadius, surface, background, _legacyShadow(e)),
                      ),
                  ],
                ),
              ),
            ],
          );
          if (constraints.maxWidth >= 900) {
            return ElScrollView(
              padding: .all(16),
              children: [
                Row(
                  crossAxisAlignment: .start,
                  spacing: 24,
                  children: [
                    Expanded(child: preview),
                    SizedBox(width: 340, child: controls),
                  ],
                ),
                legacy,
              ],
            );
          }
          final inputs = [controls, Text('五档对照 · 横向滑动查看'), comparison, result, legacy];
          // 用键盘弹出前的高度选布局，避免切换父级导致输入框失焦。
          if (constraints.maxHeight + keyboardHeight < 600) {
            return ElScrollView(padding: .all(16), gap: 16, children: [sample, ...inputs]);
          }
          return Column(
            crossAxisAlignment: .stretch,
            children: [
              Offstage(
                offstage: keyboardHeight > 0,
                child: Padding(padding: .all(16), child: sample),
              ),
              Expanded(
                child: ElScrollView(padding: .all(16), gap: 16, children: inputs),
              ),
            ],
          );
        },
      ),
    );
  }
}

Widget _stage(
  String label,
  Size size,
  BorderRadius radius,
  Color surface,
  Color background,
  List<BoxShadow> shadows, {
  String? sampleKey,
}) => LayoutBuilder(
  builder: (context, constraints) {
    final stageWidth = constraints.maxWidth < size.width + 96 ? size.width + 96 : constraints.maxWidth;
    return ColoredBox(
      key: sampleKey == null ? null : ValueKey('$sampleKey-stage'),
      color: background,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: stageWidth,
          height: size.height + 128,
          child: Center(
            child: ElCardView(
              key: sampleKey == null ? null : ValueKey(sampleKey),
              style: ElStyle(
                width: size.width,
                height: size.height,
                backgroundColor: surface,
                borderRadius: radius,
                boxShadow: shadows,
              ),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 24,
                    color: Color.alphaBlend(surface, background).computeLuminance() > .4 ? Colors.black : Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  },
);

Widget _choices<T>(String label, T selected, List<(T, String)> options, ValueChanged<T> onChanged) => Column(
  crossAxisAlignment: .start,
  spacing: 8,
  children: [
    Text(label),
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (value, text) in options)
          ChoiceChip(label: Text(text), selected: value == selected, onSelected: (_) => onChanged(value)),
      ],
    ),
  ],
);

Widget _slider(
  String label,
  String key,
  double value,
  double min,
  double max,
  ValueChanged<double> onChanged, {
  double step = 1,
}) => Column(
  crossAxisAlignment: .stretch,
  children: [
    Text('$label · ${_number(value)}'),
    Slider(
      key: ValueKey(key),
      label: _number(value),
      value: value,
      min: min,
      max: max,
      divisions: ((max - min) / step).round(),
      onChanged: onChanged,
    ),
  ],
);

class _ColorField extends HookWidget {
  const _ColorField({
    required this.label,
    required this.fieldKey,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.opaque = false,
  });

  final String label, fieldKey;
  final Color value;
  final ValueChanged<Color> onChanged;
  final bool enabled, opaque;

  @override
  Widget build(BuildContext context) {
    final controller = useTextEditingController(text: _hex(value));
    final invalid = useState(false);
    useEffect(() {
      if (_parseColor(controller.text) != value) controller.text = _hex(value);
      invalid.value = false;
      return null;
    }, [value]);
    return Column(
      crossAxisAlignment: .stretch,
      spacing: 8,
      children: [
        TextField(
          key: ValueKey(fieldKey),
          controller: controller,
          enabled: enabled,
          decoration: InputDecoration(
            labelText: label,
            helperText: opaque ? '#RRGGBB' : '#RRGGBB 或 #AARRGGBB',
            errorText: invalid.value ? '请输入有效${opaque ? '且不透明' : ''}的颜色' : null,
            border: OutlineInputBorder(),
          ),
          onChanged: (text) {
            final color = _parseColor(text);
            invalid.value = color == null || opaque && color.a != 1;
            if (!invalid.value) onChanged(color!);
          },
        ),
        Wrap(
          spacing: 8,
          children: [
            for (final (name, color) in [
              ('白', Colors.white),
              ('灰', Color(0xffeeeeee)),
              ('暗', Color(0xff252931)),
              ('蓝', Color(0xff2454c6)),
            ])
              ActionChip(
                label: Text(name),
                avatar: CircleAvatar(backgroundColor: color, radius: 8),
                onPressed: enabled ? () => onChanged(color) : null,
              ),
          ],
        ),
      ],
    );
  }
}

Color? _parseColor(String text) {
  final hex = text.trim().replaceFirst(RegExp(r'^#'), '');
  if (!RegExp(r'^(?:[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$').hasMatch(hex)) return null;
  return Color(int.parse(hex.length == 6 ? 'ff$hex' : hex, radix: 16));
}

String _hex(Color color) => '#${color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';
String _colorCode(Color color) => 'Color(0x${color.toARGB32().toRadixString(16).padLeft(8, '0')})';
String _number(double value) => value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');

// 保留旧项目的三层透明度和八档模糊半径，用相同卡片隔离阴影本身的差异。
final _legacyColorOpacityList = [.16, .12, .08];
final _legacyBlurRadiusList = [
  [.1, .2, 1.0],
  [.8, 1.0, 2.0],
  [1.0, 1.6, 4.0],
  [1.6, 3.0, 6.0],
  [2.4, 4.0, 8.0],
  [4.0, 6.0, 10.0],
  [5.0, 8.0, 12.0],
  [6.0, 10.0, 16.0],
];

List<BoxShadow> _legacyShadow(int elevation) => [
  for (final (index, blurRadius) in _legacyBlurRadiusList[elevation - 1].indexed)
    BoxShadow(
      blurStyle: .normal,
      offset: .zero,
      blurRadius: blurRadius,
      spreadRadius: 0,
      color: Colors.black.withValues(alpha: _legacyColorOpacityList[index]),
    ),
];
