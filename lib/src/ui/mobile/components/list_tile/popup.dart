part of 'index.dart';

Widget _popupPanel<T>(BuildContext context, ElListTile<T> component, VoidCallback close) {
  final selectedIndex = component.options.indexWhere((option) => option.value == component.currentValue);
  void choose(ElLabelModel<T> option) {
    component.currentValue = option.value as T;
    if (component.closeOnSelect) close();
  }

  return ElView(
    style: ElStyle(
      width: 240,
      heightFactor: 1,
      maxHeight: component.popupMaxHeight,
      backgroundColor: context.elTheme.cardColor,
      borderRadius: .circular(16),
      clipBehavior: .hardEdge,
      boxShadow: context.elTheme.shadowMd,
    ).merge(component.popupStyle),
    semantics: ElSemantics(container: true, label: component.popupLabel),
    child: RadioGroup<Object?>(
      groupValue: component.currentValue,
      // 菜单方向键只移动焦点，确认键由行提交，避免导航时立即关闭。
      onChanged: (_) {},
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: .min,
          children: [
            for (var i = 0; i < component.options.length; i++)
              ElChildIndex(
                index: i,
                end: component.options.length - 1,
                child: _ListTile<T>(
                  ElListTile<T>(
                    value: component.options[i].value,
                    title: component.options[i].label ?? '',
                    style: component.optionStyle,
                  ),
                  selectionMode: .single,
                  selected: component.options[i].value == component.currentValue,
                  autofocus: i == (selectedIndex < 0 ? 0 : selectedIndex),
                  selectionLeading: false,
                  onSelect: () => choose(component.options[i]),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
