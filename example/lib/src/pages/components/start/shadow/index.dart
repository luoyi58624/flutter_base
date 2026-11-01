import 'package:flutter/material.dart';
import 'package:flutter_base/desktop.dart';

/// 对比当前主题五档阴影与旧版八档均匀扩散阴影。
class ShadowPage extends StatelessWidget {
  const ShadowPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('阴影')),
      body: ElScrollView(
        padding: .all(40),
        children: [
          Text('当前主题 · 五档阴影'),
          SizedBox(height: 24),
          ElGridView(
            gap: 40,
            itemWidth: 120,
            children: [
              ...ElLevelType.types.map(
                (e) => ElCard(
                  shadowLevel: e,
                  child: Center(child: ElView(child: e.name)),
                ),
              ),
            ],
          ),
          SizedBox(height: 48),
          Text('旧版 · 八档阴影（默认第 4 档）'),
          SizedBox(height: 24),
          ElGridView(
            gap: 40,
            itemWidth: 120,
            children: [
              for (var elevation = 1; elevation <= _legacyBlurRadiusList.length; elevation++)
                ElCard(
                  style: ElStyle(boxShadow: _legacyShadow(elevation)),
                  child: Center(child: ElView(child: '$elevation')),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

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
