import 'package:flutter/widgets.dart';
import 'package:flutter_base/desktop.dart';

/// 选中值绑定的分组菜单示例。
class NavMenuExample extends HookWidget {
  /// 创建分组菜单示例。
  const NavMenuExample({super.key});

  @override
  Widget build(BuildContext context) {
    final selection = useState('overview');
    return SizedBox(
      width: 220,
      height: 170,
      child: ElNavMenu<void>(
        modelValue: selection,
        children: [
          ElMenuModel(
            group: true,
            title: '工作区',
            children: [
              ElMenuModel(key: 'overview', title: '概览'),
              ElMenuModel(key: 'projects', title: '项目'),
            ],
          ),
        ],
      ),
    );
  }
}
