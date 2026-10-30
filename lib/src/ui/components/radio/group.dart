import 'package:flutter/foundation.dart' show internal;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../../flutter/views/view/semantics/semantics.dart';
import '../../../flutter/views/view/style/style.dart';
import '../../../flutter/views/view/view.dart';
import '../../../flutter/widgets/form/index.dart';

/// 跨库登记单选项所需的最小信息，不依赖具体外观组件。
@internal
abstract interface class ElRadioGroupOption implements Widget {
  /// 选项的稳定业务值。
  Object? get value;

  /// 选项是否禁用。
  bool get disabled;

  /// 是否为不参与分组的独立开关。
  bool get isToggle;
}

/// 通用单选分组，共用值绑定、布局、方向键导航和单一 Tab 入口。
class ElRadioGroup<T> extends ElFormModelValue<T?> {
  /// 创建单选分组，未选中时 value 可为空。
  ElRadioGroup({
    super.key,
    super.value,
    super.modelValue,
    ValueChanged<T>? onChanged,
    required this.children,
    this.disabled = false,
    this.direction = Axis.horizontal,
    this.spacing = 0,
    this.runSpacing = 8,
    this.style,
    this.semanticLabel,
  }) : super(
         onChanged: (value) {
           if (value != null || null is T) onChanged?.call(value as T);
         },
       );

  /// 读取最近的单选分组上下文并订阅变化，组外返回 null。
  static ElRadioGroupScope? maybeOf(BuildContext context) => _RadioGroupItem.maybeOf(context);

  /// 分组内容，支持经过布局 Widget 包装的单选框。
  final List<Widget> children;

  /// 禁用整组交互。
  final bool disabled;

  /// 排布方向。
  final Axis direction;

  /// 相邻子项间距。
  final double spacing;

  /// 换行间距。
  final double runSpacing;

  /// 通用布局样式，品牌变量可由此下发。
  final ElStyle? style;

  /// 辅助技术读取的组名称。
  final String? semanticLabel;

  @override
  T? get value => $formBound ? coerceFormValue($formState!.formData[$formProp]) : super.value;

  @override
  Widget obsBuilder(BuildContext context) => _RadioGroup(
    value: $obs.value,
    select: (value) => $obs.value = value as T?,
    disabled: disabled,
    direction: direction,
    spacing: spacing,
    runSpacing: runSpacing,
    style: style,
    semanticLabel: semanticLabel,
    children: children,
  );
}

class _RadioGroup extends StatefulWidget {
  const _RadioGroup({
    required this.value,
    required this.select,
    required this.disabled,
    required this.direction,
    required this.spacing,
    required this.runSpacing,
    required this.style,
    required this.semanticLabel,
    required this.children,
  });

  final Object? value;
  final ValueChanged<Object?> select;
  final bool disabled;
  final Axis direction;
  final double spacing;
  final double runSpacing;
  final ElStyle? style;
  final String? semanticLabel;
  final List<Widget> children;

  @override
  State<_RadioGroup> createState() => _RadioGroupState();
}

class _RadioEntry {
  _RadioEntry(this.component, this.index);

  ElRadioGroupOption component;
  int index;
}

class _RadioGroupState extends State<_RadioGroup> {
  late Object? _selection;

  Object? get value => _selection;

  @override
  void initState() {
    super.initState();
    _selection = widget.value;
  }

  @override
  void didUpdateWidget(_RadioGroup oldWidget) {
    super.didUpdateWidget(oldWidget);
    _selection = widget.value;
  }

  final Map<Object, _RadioEntry> _entries = {};
  final Map<Object?, FocusNode> _nodes = {};
  bool _scheduled = false;
  bool _disposed = false;

  void _notify() {
    if (_disposed || _scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (mounted && !_disposed) {
        _validate(_entries.values.map((entry) => entry.component));
        setState(() {});
      }
    });
  }

  void _validate(Iterable<ElRadioGroupOption> radios) {
    final labels = <Object?>{};
    for (final radio in radios) {
      if (!radio.isToggle && !labels.add(radio.value)) {
        throw FlutterError('ElRadioGroup 子项 value ${radio.value} 重复。');
      }
    }
  }

  void register(Object owner, ElRadioGroupOption component, int index) {
    final previous = _entries[owner];
    if (previous != null &&
        previous.component.value == component.value &&
        previous.component.disabled == component.disabled &&
        previous.index == index) {
      return;
    }
    _entries[owner] = _RadioEntry(component, index);
    _notify();
  }

  void unregister(Object owner) {
    if (_entries.remove(owner) != null) _notify();
  }

  List<ElRadioGroupOption> get _radios {
    // 直接子项在首帧即可决定唯一 Tab 入口，包装过的后代由实际挂载登记补齐。
    final result = <ElRadioGroupOption>[];
    for (var index = 0; index < widget.children.length; index++) {
      final direct = widget.children[index];
      if (direct is ElRadioGroupOption && !direct.isToggle) {
        result.add(direct);
        continue;
      }
      result.addAll(_entries.values.where((entry) => entry.index == index).map((entry) => entry.component));
    }
    return result.where((radio) => !radio.disabled).toList();
  }

  FocusNode _node(ElRadioGroupOption component) => _nodes.putIfAbsent(
    component.value,
    () => FocusNode(debugLabel: 'ElRadio ${component.value}', onKeyEvent: _handleKey),
  );

  void select(Object? label) {
    if (widget.disabled || label == value || !_radios.any((radio) => radio.value == label)) {
      return;
    }
    setState(() => _selection = label);
    widget.select(label);
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (widget.disabled || (event is! KeyDownEvent && event is! KeyRepeatEvent)) {
      return .ignored;
    }
    final delta = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowLeft || LogicalKeyboardKey.arrowUp => -1,
      LogicalKeyboardKey.arrowRight || LogicalKeyboardKey.arrowDown => 1,
      _ => 0,
    };
    if (delta == 0) return .ignored;
    final radios = _radios;
    final index = radios.indexWhere((radio) => _node(radio).hasFocus);
    if (index < 0 || radios.isEmpty) return .ignored;
    final target = radios[(index + delta) % radios.length];
    _node(target).requestFocus();
    select(target.value);
    return .handled;
  }

  FocusNode focusFor(ElRadioGroupOption component) {
    final enabled = _radios;
    final selected = enabled.any((radio) => radio.value == value);
    final tabStop = selected ? component.value == value : enabled.isNotEmpty && component.value == enabled.first.value;
    // 组内唯一的 Tab 入口随选中项移动，遍历开关在每次构建时同步。
    final node = _node(component)..skipTraversal = !tabStop;
    return node;
  }

  @override
  void dispose() {
    _disposed = true;
    for (final node in _nodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _validate(widget.children.whereType<ElRadioGroupOption>());
    return ElView(
      style: widget.style,
      semantics: ElSemantics(container: true, label: widget.semanticLabel),
      child: Wrap(
        direction: widget.direction,
        spacing: widget.spacing,
        runSpacing: widget.runSpacing,
        crossAxisAlignment: .center,
        children: [
          for (var i = 0; i < widget.children.length; i++)
            _RadioGroupItem(
              key: widget.children[i].key == null ? null : ValueKey(widget.children[i].key),
              group: this,
              index: i,
              isLast: i == widget.children.length - 1,
              revision: Object(),
              child: widget.children[i],
            ),
        ],
      ),
    );
  }
}

/// 单选分组向后代提供的只读状态与已登记选项的选择操作。
abstract interface class ElRadioGroupScope {
  /// 当前选中值，未选中时为 null。
  Object? get value;

  /// 整组是否禁用。
  bool get disabled;

  /// 当前后代是否位于分组最后一个直接布局项内。
  bool get isLast;

  /// 选中已登记且启用的选项；整组禁用、值无效或未变化时不操作。
  void select(Object? value);

  /// 内部分组的稳定身份，避免上下文重建触发选项反复注销。
  @internal
  Object get groupIdentity;

  /// 内部选项在构建时登记身份与状态，顺序沿用所属的直接布局项。
  @internal
  void register(Object owner, ElRadioGroupOption option);

  /// 内部选项卸载或切换分组时注销原登记。
  @internal
  void unregister(Object owner);

  /// 内部选项读取组管理的焦点节点，不得自行销毁。
  @internal
  FocusNode focusFor(ElRadioGroupOption option);
}

class _RadioGroupItem extends InheritedWidget implements ElRadioGroupScope {
  const _RadioGroupItem({
    super.key,
    required this.group,
    required this.index,
    required this.isLast,
    required this.revision,
    required super.child,
  });

  final _RadioGroupState group;
  final int index;

  @override
  Object? get value => group.value;

  @override
  bool get disabled => group.widget.disabled;
  @override
  final bool isLast;
  final Object revision;

  @override
  void select(Object? value) => group.select(value);

  @override
  Object get groupIdentity => group;

  @override
  void register(Object owner, ElRadioGroupOption option) => group.register(owner, option, index);

  @override
  void unregister(Object owner) => group.unregister(owner);

  @override
  FocusNode focusFor(ElRadioGroupOption option) => group.focusFor(option);

  static _RadioGroupItem? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_RadioGroupItem>();

  @override
  bool updateShouldNotify(_RadioGroupItem oldWidget) => revision != oldWidget.revision;
}
