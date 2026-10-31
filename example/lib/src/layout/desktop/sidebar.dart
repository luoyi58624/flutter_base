part of 'index.dart';

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.current, required this.onChanged});

  final String current;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return ElView(
      style: .new(
        width: 250,
        height: '100%',
        backgroundColor: ElThemeData.of(context).bgColor,
      ),
      child: ElNavMenu<String>(
        value: current,
        onChanged: onChanged,
        children: [
          ElMenuModel<String>(key: 'home', title: '首页', icon: Icon(Icons.home)),
          ElMenuModel<String>(
            key: 'components',
            title: '组件',
            icon: Icon(Icons.widgets),
            children: [
              ElMenuModel<String>(
                key: 'component-overview',
                title: '组件概览',
                icon: Icon(Icons.dashboard),
              ),
            ],
          ),
          ElMenuModel<String>(
            key: 'examples',
            title: '示例',
            icon: Icon(Icons.grid_view),
            children: [
              ElMenuModel<String>(
                key: 'view',
                title: '视图',
                icon: Icon(Icons.web),
              ),
              ElMenuModel<String>(
                key: 'gestures',
                title: '手势',
                icon: Icon(Icons.touch_app),
              ),
              ElMenuModel<String>(
                key: 'base',
                title: '基础',
                icon: Icon(Icons.layers),
              ),
            ],
          ),
          ElMenuModel<String>(
            key: 'settings',
            title: '设置',
            icon: Icon(Icons.settings),
          ),
        ],
      ),
    );
  }
}
