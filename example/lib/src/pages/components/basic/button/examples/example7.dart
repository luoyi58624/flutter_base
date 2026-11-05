import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

/// 各按钮独立进入加载状态，并在两秒后恢复。
class Example7 extends StatelessWidget {
  const Example7({super.key});

  @override
  Widget build(BuildContext context) {
    final circle = ElStyle(borderRadius: .circular(999));
    final variants = <(ElButtonVariant, ElStyle?)>[
      (.solid, null),
      (.outline, null),
      (.outline, ElStyle(backgroundColor: Colors.transparent)),
      (.text, null),
    ];

    return Column(
      crossAxisAlignment: .start,
      mainAxisSize: .min,
      spacing: 8,
      children: [
        for (final (variant, style) in variants)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _LoadingButton(variant: variant, style: style, child: 'loading'),
              _LoadingButton(type: .primary, variant: variant, style: style, child: 'loading'),
              ElView(
                style: ElStyle(vars: {ElTokens.$primary: Colors.teal}),
                child: _LoadingButton(
                  type: .primary,
                  variant: variant,
                  style: style,
                  icon: Icons.search,
                  child: 'loading',
                ),
              ),
            ],
          ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _LoadingButton(style: circle, semanticLabel: '编辑', child: Icons.edit),
            _LoadingButton(type: .primary, style: circle, semanticLabel: '上传', child: Icons.upload),
            ElView(
              style: ElStyle(vars: {ElTokens.$primary: Colors.teal}),
              child: _LoadingButton(type: .primary, style: circle, semanticLabel: '搜索', child: Icons.search),
            ),
          ],
        ),
      ],
    );
  }
}

class _LoadingButton extends HookWidget {
  const _LoadingButton({
    this.type,
    this.variant = .solid,
    this.style,
    this.icon,
    this.semanticLabel,
    required this.child,
  });

  final ElThemeType? type;
  final ElButtonVariant variant;
  final ElStyle? style;
  final IconData? icon;
  final String? semanticLabel;
  final Object child;

  @override
  Widget build(BuildContext context) {
    final loading = useState(false);
    return ElButton(
      type: type,
      variant: variant,
      style: style,
      icon: icon,
      semanticLabel: semanticLabel,
      loading: loading.value,
      onPressed: () async {
        if (loading.value) return;
        loading.value = true;
        await Future<void>.delayed(Duration(seconds: 2));
        if (context.mounted) loading.value = false;
      },
      child: child,
    );
  }
}
