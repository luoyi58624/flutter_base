import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_base/mobile.dart';

/// 调节算法输入并展示当前级别的单个阴影，不改变应用主题或组件默认样式。
class ShadowPage extends HookWidget {
  /// 创建阴影游乐场。
  const ShadowPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Scaffold 会移除 body 的底部 viewInsets，键盘高度在外层读取。
    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;
    final copied = useState(false);
    final mode = useState(Theme.of(context).brightness);
    final level = useState(ElLevelType.md);
    final surfaceOverride = useState<Color?>(null);
    final backgroundOverride = useState<Color?>(null);
    final sameColor = useState(true);
    final width = useState(180.0), height = useState(120.0), radius = useState(26.0);
    final strength = useState(1.0), softness = useState(1.0);
    final vars = mode.value == Brightness.light
        ? el.mobileComponents.token!.vars!
        : el.mobileComponents.token!.onDark!.vars!;
    final surface = surfaceOverride.value ?? vars[ElTokens.$cardColor] as Color;
    final background = sameColor.value
        ? surface.withValues(alpha: 1)
        : backgroundOverride.value ?? vars[ElTokens.$bgColor] as Color;
    final size = Size(width.value, height.value);
    final actualRadius = radius.value.clamp(0.0, size.shortestSide / 2);
    final borderRadius = BorderRadius.circular(actualRadius);
    // 仅参数变化时计算当前结果，复制反馈和键盘布局变化复用同一组阴影。
    final shadows = useMemoized(
      () => ElShadow.resolve(
        level: level.value,
        brightness: mode.value,
        surfaceColor: surface,
        backgroundColor: background,
        borderRadius: borderRadius,
        size: size,
        strength: strength.value,
        softness: softness.value,
      ),
      [level.value, mode.value, surface, background, borderRadius, size, strength.value, softness.value],
    );
    String code() =>
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

    useEffect(() {
      copied.value = false;
      return null;
    }, [shadows]);

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

    final sample = RepaintBoundary(
      child: _stage(level.value.name, size, borderRadius, surface, background, shadows, sampleKey: 'shadow-preview'),
    );
    final result = _Fold(
      key: ValueKey('shadow-result'),
      title: '计算结果与 Dart 用法',
      builder: (context) => Column(
        crossAxisAlignment: .stretch,
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
          ElView(
            style: ElStyle(userSelect: .text),
            child: code(),
          ),
        ],
      ),
    );
    final preview = Column(
      crossAxisAlignment: .stretch,
      spacing: 16,
      children: [
        Text('阴影游乐场', style: Theme.of(context).textTheme.titleLarge),
        Text('调整颜色、尺寸、圆角与级别，查看当前阴影。'),
        sample,
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
          Row(
            children: [
              Expanded(child: Text('背景与组件同色')),
              ElSwitch(
                key: ValueKey('shadow-same-color'),
                value: sameColor.value,
                onChanged: (v) => sameColor.value = v,
              ),
            ],
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
          ElDivider(color: context.elTheme.dividerColor),
          Text('尺寸与圆角', style: Theme.of(context).textTheme.titleMedium),
          _slider('宽度', 'shadow-width', width.value, 80, 280, (v) => width.value = v),
          _slider('高度', 'shadow-height', height.value, 48, 240, (v) => height.value = v),
          _slider('圆角', 'shadow-radius', actualRadius, 0, size.shortestSide / 2, (v) => radius.value = v),
          Wrap(
            spacing: 8,
            children: [
              for (final (name, value) in [('直角', 0.0), ('圆角', 20.0), ('胶囊', size.shortestSide / 2)])
                ElButton(variant: .outline, child: name, onPressed: () => radius.value = value),
            ],
          ),
          ElDivider(color: context.elTheme.dividerColor),
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
          ElButton(
            key: ValueKey('shadow-reset'),
            variant: .text,
            child: Icons.restart_alt,
            semanticLabel: '恢复默认',
            onPressed: reset,
          ),
          ElButton(
            key: ValueKey('shadow-copy'),
            variant: .text,
            icon: Icons.copy,
            child: copied.value ? '已复制' : '复制',
            semanticLabel: '复制 Dart 用法',
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: code()));
              if (context.mounted) copied.value = true;
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 900) {
            // 两栏各自占满可用高度，参数区滚动不再带走预览。
            return Padding(
              padding: .all(16),
              child: Row(
                crossAxisAlignment: .stretch,
                spacing: 24,
                children: [
                  Expanded(
                    child: ElScrollView(key: ValueKey('shadow-preview-scroll'), children: [preview]),
                  ),
                  SizedBox(
                    width: 340,
                    child: ElScrollView(key: ValueKey('shadow-controls-scroll'), children: [controls]),
                  ),
                ],
              ),
            );
          }
          final inputs = [controls, result];
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
          ElTag.toggle(
            value: value == selected,
            child: text,
            semanticLabel: '$label：$text',
            // 单选标签不能取消当前项，指针、键盘和辅助技术共用默认动作入口。
            event: ElEvent(
              onTap: (event) {
                if (value == selected) event.preventDefault();
              },
            ),
            onChanged: (active) {
              if (active) onChanged(value);
            },
          ),
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
}) => ElSlider<double>(
  key: ValueKey(key),
  label: label,
  value: value,
  min: min,
  max: max,
  step: step,
  startLabel: null,
  endLabel: null,
  unit: '',
  onChanged: onChanged,
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
    final controller = useMemoized(() => ElEditableController(text: _hex(value), singleLine: true));
    final focus = useFocusNode();
    final invalid = useState(false);
    final syncing = useRef(false);
    useEffect(() => controller.dispose, [controller]);
    useEffect(() {
      // 主题与预设回灌不再次触发用户输入，避免旧监听闭包在 build 中写回父级。
      syncing.value = true;
      if (_parseColor(controller.text) != value) controller.text = _hex(value);
      syncing.value = false;
      invalid.value = false;
      return null;
    }, [value]);
    useEffect(() {
      void changed() {
        if (!enabled || syncing.value) return;
        final color = _parseColor(controller.text);
        invalid.value = color == null || opaque && color.a != 1;
        if (!invalid.value && color != value) onChanged(color!);
      }

      controller.addListener(changed);
      return () => controller.removeListener(changed);
    }, [controller, value, enabled, opaque, onChanged]);
    return Column(
      crossAxisAlignment: .stretch,
      spacing: 8,
      children: [
        Text(label),
        ExcludeFocus(
          excluding: !enabled,
          child: IgnorePointer(
            ignoring: !enabled,
            child: ElEditableView(
              key: ValueKey(fieldKey),
              controller: controller,
              focusNode: focus,
              style: ElEditableStyle(
                semanticLabel: label,
                softWrap: false,
                readOnly: !enabled,
                view: ElStyle(
                  height: 44,
                  padding: .symmetric(horizontal: 12, vertical: 10),
                  borderRadius: .circular(8),
                  border: ElBorder.all(
                    borderColor: invalid.value ? context.elTheme.error : context.elTheme.borderColor,
                  ),
                  opacity: enabled ? 1 : .5,
                ),
                inputConfiguration: TextInputConfiguration(autocorrect: false, enableSuggestions: false),
              ),
            ),
          ),
        ),
        Text(
          invalid.value
              ? '请输入有效${opaque ? '且不透明' : ''}的颜色'
              : opaque
              ? '#RRGGBB'
              : '#RRGGBB 或 #AARRGGBB',
          style: TextStyle(color: invalid.value ? context.elTheme.error : context.elTheme.textSecondary, fontSize: 12),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (name, color) in [
              ('白', Colors.white),
              ('灰', Color(0xffeeeeee)),
              ('暗', Color(0xff252931)),
              ('蓝', Color(0xff2454c6)),
            ])
              ElButton(
                variant: .outline,
                disabled: !enabled,
                child: Row(
                  mainAxisSize: .min,
                  spacing: 6,
                  children: [
                    ElView(
                      style: ElStyle(width: 12, height: 12, backgroundColor: color, borderRadius: .circular(6)),
                    ),
                    Text(name),
                  ],
                ),
                onPressed: () => onChanged(color),
              ),
          ],
        ),
      ],
    );
  }
}

class _Fold extends HookWidget {
  const _Fold({super.key, required this.title, required this.builder});
  final String title;
  final WidgetBuilder builder;
  @override
  Widget build(BuildContext context) {
    final open = useState(false);
    return Column(
      crossAxisAlignment: .stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) => ElButton(
            variant: .text,
            style: ElStyle(width: '100%', padding: .all(12)),
            onPressed: () => open.value = !open.value,
            child: SizedBox(
              width: (constraints.maxWidth - 24).clamp(0, double.infinity),
              child: Row(
                children: [
                  Expanded(child: Text(title)),
                  ElView(child: open.value ? Icons.expand_less : Icons.expand_more),
                ],
              ),
            ),
          ),
        ),
        if (open.value) Padding(padding: .all(16), child: builder(context)),
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
