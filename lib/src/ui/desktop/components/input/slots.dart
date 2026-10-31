part of 'index.dart';

Color _placeholderColor(BuildContext c) =>
    c.isDark ? const Color(0xff8d9095) : const Color(0xffa8abb2);

/// placeholder：垫底层（editable 盖其上接管命中），空文档才挂载。
class _InputPlaceholder extends StatelessWidget {
  const _InputPlaceholder(
    this.text, {
    required this.textarea,
    required this.textStyle,
    required this.textAlign,
    required this.textDirection,
    this.style,
  });

  final String text;
  final bool textarea;
  final TextStyle textStyle;
  final TextAlign textAlign;
  final TextDirection textDirection;
  final ElStyle? style;

  @override
  Widget build(BuildContext context) {
    return ElView(
      key: const ValueKey<String>('el-input-placeholder'),
      style: ((c) => ElStyle(
        color: _placeholderColor(c),
        padding: _inputProjectionPadding(textarea),
        textAlign: textAlign,
        direction: textDirection,
        userSelect: ElUserSelect.none,
        iconColor: _placeholderColor(c),
      ).merge(_resolveInputStyle(c, style)))(context),
      child: TextSpan(text: text, style: textStyle),
    );
  }
}

/// nowrap editable 会在物理右侧预留 `caretWidth + 2`，投影层必须使用
/// 同一排版宽度；textarea 的 wrap 行不预留该空间。
EdgeInsetsGeometry _inputProjectionPadding(bool textarea) =>
    textarea ? EdgeInsets.zero : EdgeInsets.only(right: 3.5);

/// 前后缀宽容输入：内容始终被固定正方形槽约束并裁剪，任意 Widget 都不能
/// 把单行 Row 撑高；IconData 升格为当前尺寸档图标。
class _InputAffix extends StatelessWidget {
  const _InputAffix(
    this.content, {
    required this.slotKey,
    required this.iconSize,
    required this.extent,
    this.style,
  });

  final ElStyle? style;
  final Object? content;
  final Key slotKey;
  final double iconSize;
  final double extent;

  @override
  Widget build(BuildContext context) {
    final Widget child;
    if (content is IconData) {
      child = ElIcon(content as IconData, size: iconSize);
    } else if (content is Widget) {
      child = content as Widget;
    } else {
      child = ElView(child: content);
    }
    return ElView(
      key: slotKey,
      style: ((c) => ElStyle(
        width: extent,
        height: extent,
        alignment: .center,
        clipBehavior: Clip.hardEdge,
        iconColor: ElThemeData.of(c).textColorLg,
      ).merge(_resolveInputStyle(c, style)))(context),
      child: child,
    );
  }
}

/// 条件动作的稳定占位；显隐只替换槽内 child，不改变正文可用宽度。
class _InputActionSlot extends StatelessWidget {
  const _InputActionSlot({
    required this.slotKey,
    required this.extent,
    required this.child,
  });

  final Key slotKey;
  final double extent;
  final Widget? child;

  @override
  Widget build(BuildContext context) => ElView(
    key: slotKey,
    style: ElStyle(
      width: extent,
      height: extent,
      alignment: .center,
      clipBehavior: Clip.hardEdge,
    ),
    child: child,
  );
}

/// 可点动作图标（clear / 密码眼睛）：hover 变 clear-hover 色，active（明文
/// 可见态）用主题色表达；tap 阻断冒泡防抢 editable 焦点/caret。
class _InputActionIcon extends StatelessWidget {
  const _InputActionIcon({
    required this.icon,
    required this.size,
    required this.extent,
    required this.onTap,
    this.active = false,
    this.style,
  });

  final IconData icon;
  final double size;
  final double extent;
  final VoidCallback onTap;
  final bool active;
  final ElStyle? style;

  @override
  Widget build(BuildContext context) {
    return ElView(
      style: ((c) => ElStyle(
        width: extent,
        height: extent,
        alignment: .center,
        cursor: SystemMouseCursors.click,
        color: active
            ? ElThemeData.of(c).primary
            : ElThemeData.of(c).textColorLg,
        onHover: ElStyle(
          color: ElThemeData.of(c).textColorMd,
          iconColor: ElThemeData.of(c).textColorMd,
        ),
        iconColor: active
            ? ElThemeData.of(c).primary
            : ElThemeData.of(c).textColorLg,
      ).merge(_resolveInputStyle(c, style)))(context),
      event: ElEvent(
        onPointerDown: (e) {
          e.preserveFocus();
          e.stopPropagation();
        },
        onTapDown: (e) => e.stopPropagation(),
        onTap: (e) {
          e.stopPropagation();
          onTap();
        },
      ),
      child: ElIcon(icon, size: size),
    );
  }
}

/// 字数计数：`当前/上限`，12px info 色。
class _InputCount extends StatelessWidget {
  const _InputCount({required this.length, required this.maxLength});

  final int length;
  final int maxLength;

  @override
  Widget build(BuildContext context) {
    return ElView(
      style: ElStyle(
        fontSize: 12,
        color: ElThemeData.of(context).info,
        userSelect: .none,
        iconColor: ElThemeData.of(context).info,
      ),
      child: '$length/$maxLength',
    );
  }
}
