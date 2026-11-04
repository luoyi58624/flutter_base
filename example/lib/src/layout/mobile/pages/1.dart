import 'package:example/state.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

/// 首页内容，提供应用明暗主题切换。
class HomePage extends StatelessWidget {
  /// 创建首页。
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.brightness == .dark ? colors.surface : Color(0xFFF0F1F3),
      appBar: AppBar(
        title: const Text('首页'),
        actions: [
          ObsBuilder(
            builder: (context) {
              final isDark = GlobalState.isDark.value;
              return IconButton(
                tooltip: isDark ? '切换到浅色模式' : '切换到暗黑模式',
                icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
                onPressed: () => GlobalState.isDark.value = !isDark,
              );
            },
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: .symmetric(horizontal: 20, vertical: 24),
          child: ConstrainedBox(
            constraints: .new(maxWidth: 1400),
            child: Column(
              mainAxisSize: .min,
              children: [
                HookBuilder(
                  builder: (context) {
                    final count = useState(0);
                    return ElButtonView(
                      onPressed: () {
                        count.value++;
                      },
                      style: ElStyle(
                        minWidth: 64,
                        height: 40,
                        backgroundColor: Colors.blue,
                        color: Colors.white,
                        fontWeight: .w500,
                        fontSize: 15,
                        alignment: .center,
                        borderRadius: .circular(6),
                        padding: .symmetric(horizontal: 16, vertical: 6),
                      ).withTapScale(scale: 0.9),
                      child: 'count: ${count.value}',
                    );
                  },
                ),
                SizedBox(height: 24),
                _ShortcutCards(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ShortcutCards extends StatelessWidget {
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
        final surface = ElStyle(
          width: width,
          padding: .all(wide ? 22 : 16),
          backgroundColor: bgColor,
          borderRadius: .circular(wide ? 24 : 20),
          transition: [.field(.backgroundColor, Duration(milliseconds: 100), Curves.easeOut)],
          onTap: .new(backgroundColor: bgColor.deepen(10)),
        ).withTapScale(scale: 0.9);
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final (icon, title, description) in cards)
              ElButtonView(
                semanticLabel: title,
                onPressed: () {},
                style: surface,
                child: Column(
                  mainAxisAlignment: .spaceBetween,
                  crossAxisAlignment: .start,
                  spacing: 20,
                  children: [
                    Icon(icon, size: 22, color: colors.onSurface),
                    Column(
                      mainAxisSize: .min,
                      crossAxisAlignment: .start,
                      children: [
                        ElView(
                          style: .new(color: colors.onSurface, fontSize: 16, fontWeight: .w500),
                          child: title,
                        ),
                        SizedBox(height: 6),
                        ElView(
                          style: .new(color: colors.onSurfaceVariant, fontSize: 13),
                          child: description,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
