import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

import 'example_page.dart';

const _pressScale = 0.9;
const _pressDuration = Duration(milliseconds: 100);
const _pressCurve = Curves.easeOut;

/// 首页内容，提供组件实现和明暗主题切换。
class HomePage extends HookWidget {
  /// 创建首页。
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final useFlutter = useState(false);
    return ExamplePage(
      title: '首页',
      backgroundColor: colors.brightness == .dark ? colors.surface : Color(0xFFF0F1F3),
      actions: [
        Text('Flutter 官方'),
        Semantics(
          label: '使用 Flutter 官方组件',
          child: Switch(value: useFlutter.value, onChanged: (value) => useFlutter.value = value),
        ),
      ],
      child: Center(
        child: SingleChildScrollView(
          padding: .symmetric(horizontal: 20, vertical: 24),
          child: ConstrainedBox(
            constraints: .new(maxWidth: 1400),
            child: Column(
              mainAxisSize: .min,
              spacing: 20,
              children: [
                ElButton(child: 'hello'),
                RepaintBoundary(
                  child: HookBuilder(
                    builder: (context) {
                      final count = useState(0);
                      final label = 'count: ${count.value}';
                      void increment() => count.value++;

                      final padding = EdgeInsets.symmetric(horizontal: 16, vertical: 6);
                      final radius = BorderRadius.circular(6);
                      if (useFlutter.value) {
                        return _FlutterPressButton(
                          onPressed: increment,
                          semanticLabel: label,
                          constraints: BoxConstraints(minWidth: 64, minHeight: 40, maxHeight: 40),
                          padding: padding,
                          radius: radius,
                          color: Colors.blue,
                          child: Center(
                            widthFactor: 1,
                            child: Text(label, style: _labelStyle(Colors.white, 15, .w500)),
                          ),
                        );
                      }
                      return ElButtonView(
                        onPressed: increment,
                        style: ElStyle(
                          minWidth: 64,
                          height: 40,
                          backgroundColor: Colors.blue,
                          color: Colors.white,
                          fontWeight: .w500,
                          fontSize: 15,
                          alignment: .center,
                          borderRadius: radius,
                          padding: padding,
                        ).withTapScale(scale: _pressScale),
                        child: label,
                      );
                    },
                  ),
                ),
                SizedBox(height: 24),
                _ShortcutCards(useFlutter: useFlutter.value),
                ...ElView(child: 'item') * 100,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ShortcutCards extends StatelessWidget {
  const _ShortcutCards({required this.useFlutter});

  final bool useFlutter;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = colors.brightness == .dark;
    final cards = [
      (CupertinoIcons.tray, '清理存储', '36.8 GB / 128 GB'),
      (CupertinoIcons.checkmark_shield, '安全检查', '设备状态良好'),
      (CupertinoIcons.sparkles, '运行状态', '让日常使用更轻快'),
      (CupertinoIcons.square_grid_2x2, '应用管理', '查看全部应用'),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720;
        final columns = wide ? 4 : (constraints.maxWidth >= 280 ? 2 : 1);
        final gap = wide ? 16.0 : 12.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        final bgColor = isDark ? Colors.grey.shade800 : Colors.white;
        final padding = EdgeInsets.all(wide ? 22 : 16);
        final radius = BorderRadius.circular(wide ? 24 : 20);
        final pressedColor = bgColor.deepen(10);
        final surface = useFlutter
            ? null
            : ElStyle(
                width: width,
                padding: padding,
                backgroundColor: bgColor,
                borderRadius: radius,
                transition: [.field(.backgroundColor, _pressDuration, _pressCurve)],
                onTap: .new(backgroundColor: pressedColor),
              ).withTapScale(scale: _pressScale);

        Widget label(String text, Color color, double size, [FontWeight? weight]) => useFlutter
            ? Text(text, style: _labelStyle(color, size, weight))
            : ElView(
                style: ElStyle(color: color, fontSize: size, fontWeight: weight),
                child: text,
              );

        Widget card(IconData icon, String title, String description) {
          final content = Column(
            mainAxisAlignment: .spaceBetween,
            crossAxisAlignment: .start,
            spacing: 20,
            children: [
              Icon(icon, size: 22, color: colors.onSurface),
              Column(
                mainAxisSize: .min,
                crossAxisAlignment: .start,
                children: [
                  label(title, colors.onSurface, 16, .w500),
                  SizedBox(height: 6),
                  label(description, colors.onSurfaceVariant, 13),
                ],
              ),
            ],
          );
          if (useFlutter) {
            return _FlutterPressButton(
              semanticLabel: title,
              onPressed: () {},
              constraints: BoxConstraints.tightFor(width: width),
              padding: padding,
              radius: radius,
              color: bgColor,
              pressedColor: pressedColor,
              child: content,
            );
          }
          return ElButtonView(semanticLabel: title, onPressed: () {}, style: surface, child: content);
        }

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final (icon, title, description) in cards) card(icon, title, description)],
        );
      },
    );
  }
}

// 对齐 ElView 的默认行高与行距分布，避免切换实现时文字撑高卡片。
TextStyle _labelStyle(Color color, double size, FontWeight? weight) => TextStyle(
  inherit: false,
  color: color,
  fontSize: size,
  fontWeight: weight,
  height: 1.2,
  leadingDistribution: .even,
);

class _FlutterPressButton extends HookWidget {
  const _FlutterPressButton({
    required this.semanticLabel,
    required this.onPressed,
    required this.constraints,
    required this.padding,
    required this.radius,
    required this.color,
    this.pressedColor,
    required this.child,
  });

  final String semanticLabel;
  final VoidCallback onPressed;
  final BoxConstraints constraints;
  final EdgeInsets padding;
  final BorderRadius radius;
  final Color color;
  final Color? pressedColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final pressed = useState(false);
    final scale = pressed.value ? _pressScale : 1.0;
    return AnimatedContainer(
      duration: _pressDuration,
      curve: _pressCurve,
      constraints: constraints,
      transform: Matrix4.diagonal3Values(scale, scale, 1),
      transformAlignment: .center,
      decoration: BoxDecoration(color: pressed.value ? pressedColor ?? color : color, borderRadius: radius),
      child: Semantics(
        button: true,
        label: semanticLabel,
        child: InkWell(
          onTap: onPressed,
          onHighlightChanged: (value) => pressed.value = value,
          splashFactory: NoSplash.splashFactory,
          overlayColor: WidgetStatePropertyAll(Colors.transparent),
          enableFeedback: false,
          child: ExcludeSemantics(
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}
