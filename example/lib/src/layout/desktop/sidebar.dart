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
            child: ElNavMenu<WidgetBuilder>(value: current, onChanged: onChanged, children: AppLayout.menus),
          ),
        ],
      ),
    );
  }
}
