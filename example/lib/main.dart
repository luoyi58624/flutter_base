import 'package:flutter/material.dart';
import 'package:flutter_base/ui.dart';

void main() {
  runApp(ElViewExampleApp());
}

/// 在滚动列表中展示 ElView 的尺寸与颜色过渡。
class ElViewExampleApp extends StatelessWidget {
  /// 创建视图示例应用。
  const ElViewExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ElView · 滚动与交互',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Color(0xff4263eb),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: Color(0xfff5f6fa),
        useMaterial3: true,
      ),
      home: _ViewExamplesPage(),
    );
  }
}

class _ViewExamplesPage extends StatefulWidget {
  @override
  State<_ViewExamplesPage> createState() => _ViewExamplesPageState();
}

class _ViewExamplesPageState extends State<_ViewExamplesPage> {
  static const _itemCount = 30;
  static const _colors = [
    Color(0xff4263eb),
    Color(0xff087f5b),
    Color(0xff7048e8),
    Color(0xffc2410c),
  ];
  static const _transitions = [
    ElTransition.all(Duration(milliseconds: 420), Curves.easeInOutCubic),
    ElTransition.field(
      ElTransitionField.backgroundColor,
      Duration(milliseconds: 280),
      Curves.linear,
    ),
  ];

  final _scrollController = ScrollController();
  // 状态由页面保存，滚出视口后再返回也能保持各项的选择。
  final _expanded = List<bool>.filled(_itemCount, false);
  final _colored = List<bool>.filled(_itemCount, false);

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _toggleAll(List<bool> values) => setState(() {
    values.fillRange(0, values.length, !values.every((value) => value));
  });

  void _toggle(int index) => setState(() {
    _expanded[index] = !_expanded[index];
    _colored[index] = !_colored[index];
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('ElView · 滚动与交互'),
        actions: [
          IconButton(
            tooltip: '恢复初始状态',
            icon: Icon(Icons.restart_alt),
            onPressed: () => setState(() {
              _expanded.fillRange(0, _itemCount, false);
              _colored.fillRange(0, _itemCount, false);
            }),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('上下滚动，点击色块切换尺寸和颜色。可连续点击观察动画衔接。'),
                      SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          FilledButton.tonalIcon(
                            onPressed: () => _toggleAll(_expanded),
                            icon: Icon(Icons.open_in_full, size: 18),
                            label: Text('全部切换尺寸'),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: () => _toggleAll(_colored),
                            icon: Icon(Icons.palette_outlined, size: 18),
                            label: Text('全部切换颜色'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Scrollbar(
                    controller: _scrollController,
                    thumbVisibility: true,
                    interactive: true,
                    child: ListView.separated(
                      controller: _scrollController,
                      padding: EdgeInsets.fromLTRB(20, 8, 20, 32),
                      itemCount: _itemCount,
                      separatorBuilder: (_, _) => SizedBox(height: 20),
                      itemBuilder: (_, index) => _buildItem(index),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItem(int index) {
    final expanded = _expanded[index];
    final colored = _colored[index];
    final percentage = index.isOdd;
    final Object width = percentage
        ? (expanded ? '100%' : '55%')
        : (expanded ? 280.0 : 160.0);
    final height = expanded ? 144.0 : 88.0;
    final number = (index + 1).toString().padLeft(2, '0');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$number · ${percentage ? '百分比宽度 55% ↔ 100%' : '固定宽度 160 ↔ 280'}',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        SizedBox(height: 8),
        // 交互由官方组件承接，ElView 只接收目标样式与 child。
        Semantics(
          button: true,
          label: '切换第 ${index + 1} 项的尺寸和颜色',
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => _toggle(index),
              child: ElView(
                key: ValueKey('view-$index'),
                style: ElStyle(
                  width: width,
                  height: height,
                  backgroundColor: colored
                      ? _colors[index % _colors.length]
                      : Color(0xffe5eaf2),
                  padding: EdgeInsets.all(expanded ? 20 : 14),
                  margin: EdgeInsets.only(bottom: expanded ? 8 : 0),
                  transitions: _transitions,
                ),
                child: Center(
                  child: Text(
                    'ElView $number\n${percentage ? width : (width as double).toInt()} × ${height.toInt()}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colored ? Colors.white : Color(0xff344054),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
