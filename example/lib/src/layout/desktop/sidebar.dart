part of 'index.dart';

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.current, required this.onChanged});

  final String current;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return ElView(
      style: .new(
        width: 260,
        height: '100%',
        backgroundColor: context.elTheme.cardColor,
        border: ElBorder.only(borderRight: ElBorderSide(borderColor: context.elTheme.dividerColor, borderWidth: .5)),
      ),
      child: Column(
        crossAxisAlignment: .stretch,
        children: [
          ElView(
            style: ElStyle(
              padding: .fromLTRB(24, 24, 24, 12),
              fontSize: 18,
              fontWeight: .w600,
              color: context.elTheme.textColor,
              iconColor: context.elTheme.primary,
              iconSize: 22,
            ),
            child: Row(spacing: 10, children: [ElIcon(Icons.layers_outlined), ElText('El UI')]),
          ),
          Expanded(
            child: ElNavMenu<String>(
              value: current,
              onChanged: onChanged,
              children: [
                ElMenuModel<String>(
                  group: true,
                  title: '开始使用',
                  children: [ElMenuModel<String>(key: 'home', title: '首页', icon: ElIcon(Icons.home_outlined))],
                ),
                ElMenuModel<String>(
                  group: true,
                  title: '基础组件',
                  children: [
                    ElMenuModel<String>(
                      key: 'components',
                      title: '组件目录',
                      icon: ElIcon(Icons.widgets_outlined),
                      children: [
                        ElMenuModel<String>(
                          key: 'component-overview',
                          title: '组件概览',
                          icon: ElIcon(Icons.dashboard_outlined),
                        ),
                      ],
                    ),
                  ],
                ),
                ElMenuModel<String>(
                  group: true,
                  title: '示例',
                  children: [
                    ElMenuModel<String>(
                      key: 'examples',
                      title: '示例概览',
                      icon: ElIcon(Icons.grid_view_outlined),
                      children: [
                        ElMenuModel<String>(key: 'view', title: '视图', icon: ElIcon(Icons.web_outlined)),
                        ElMenuModel<String>(key: 'gestures', title: '手势', icon: ElIcon(Icons.touch_app_outlined)),
                        ElMenuModel<String>(key: 'base', title: '基础', icon: ElIcon(Icons.layers_outlined)),
                      ],
                    ),
                  ],
                ),
                ElMenuModel<String>(
                  group: true,
                  title: '偏好设置',
                  children: [ElMenuModel<String>(key: 'settings', title: '设置', icon: ElIcon(Icons.settings_outlined))],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
