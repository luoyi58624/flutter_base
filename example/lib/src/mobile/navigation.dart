part of 'app.dart';

/// 示例自身的导航组合，不向组件库添加端专属接口。
class _Navigation extends StatelessWidget {
  const _Navigation(this.typography, this.selected, this.onSelected, {this.desktop = false});

  final _Typography typography;
  final int selected;
  final ValueChanged<int> onSelected;
  final bool desktop;

  @override
  Widget build(BuildContext context) {
    final items = [
      for (var i = 0; i < _tabs.length; i++)
        _NavigationItem(typography, i, selected == i, () => onSelected(i), desktop: desktop),
    ];
    if (!desktop) {
      return ExamplePanel(
        key: ValueKey('bottom-nav'),
        semanticLabel: '底部导航',
        style: ElStyle(height: 56, backgroundColor: _surface),
        child: Row(children: [for (final item in items) Expanded(child: item)]),
      );
    }
    return ExamplePanel(
      key: ValueKey('desktop-nav'),
      semanticLabel: '桌面导航',
      style: ElStyle(width: 208, backgroundColor: _surface),
      child: Column(
        children: [
          SizedBox(
            height: 64,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Align(
                alignment: .centerLeft,
                child: _Label('Flutter Base', typography, size: 20, weight: .w700, color: _primary, maxLines: 1),
              ),
            ),
          ),
          _line(),
          Expanded(
            child: ElScroll(
              padding: EdgeInsets.all(12),
              children: [Column(spacing: 8, children: items)],
            ),
          ),
          _line(),
          Padding(
            padding: EdgeInsets.all(12),
            child: ElButtonView(
              key: ValueKey('desktop-demos'),
              semanticLabel: '组件示例',
              onPressed: () => _push(context, HomePage()),
              style: ElStyle(
                height: 44,
                padding: .symmetric(horizontal: 12),
                borderRadius: .circular(8),
                onHover: ElStyle(backgroundColor: _background),
              ),
              child: Row(
                children: [_Icon('info', size: 20), SizedBox(width: 12), _Label('组件示例', typography, size: 14)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavigationItem extends StatelessWidget {
  const _NavigationItem(this.typography, this.index, this.selected, this.onPressed, {required this.desktop});

  final _Typography typography;
  final int index;
  final bool selected, desktop;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final color = selected ? _primary : (desktop ? _secondary : _tertiary);
    final icon = _Icon('tab_${['home', 'category', 'message', 'profile'][index]}', color: color);
    final label = _Label(
      _tabs[index],
      typography,
      size: desktop ? 14 : 12,
      color: color,
      letterSpacing: desktop ? null : 0.4,
    );
    return ElButtonView(
      key: ValueKey('tab-${_tabs[index]}'),
      semanticLabel: _tabs[index],
      selected: selected,
      onPressed: onPressed,
      style: ElStyle(
        height: desktop ? 44 : 56,
        alignment: .center,
        padding: desktop ? EdgeInsets.symmetric(horizontal: 12) : EdgeInsets.zero,
        borderRadius: desktop ? BorderRadius.circular(8) : null,
        backgroundColor: desktop && selected ? _primary.withValues(alpha: 0.08) : null,
        onHover: desktop ? ElStyle(backgroundColor: _primary.withValues(alpha: 0.05)) : null,
      ),
      child: desktop
          ? Row(children: [icon, SizedBox(width: 12), label])
          : Column(mainAxisAlignment: .center, children: [icon, SizedBox(height: 2), label]),
    );
  }
}
