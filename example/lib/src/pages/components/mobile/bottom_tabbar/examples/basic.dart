import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';

/// 底部导航栏切换选中标签的示例。
class BottomTabbarExample extends HookWidget {
  /// 创建底部导航栏示例。
  const BottomTabbarExample({super.key});

  @override
  Widget build(BuildContext context) {
    final index = useState(0);
    return ElBottomTabbar(
      selectedIndex: index.value,
      onDestinationSelected: (value) => index.value = value,
      destinations: [
        NavigationDestination(icon: Icon(Icons.home_outlined), label: '首页'),
        NavigationDestination(icon: Icon(Icons.search), label: '发现'),
        NavigationDestination(icon: Icon(Icons.person_outline), label: '我的'),
      ],
    );
  }
}
