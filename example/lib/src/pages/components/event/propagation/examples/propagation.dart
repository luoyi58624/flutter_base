import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

/// 对照点击冒泡与内层停止传播的效果。
class ElEventPropagationExample extends StatelessWidget {
  /// 创建点击传播示例。
  // ignore: prefer_const_constructors_in_immutables
  ElEventPropagationExample({super.key});

  @override
  Widget build(BuildContext context) => Column(
    spacing: 12,
    crossAxisAlignment: .stretch,
    children: [_PropagationCase(stop: false), _PropagationCase(stop: true)],
  );
}

class _PropagationCase extends HookWidget {
  // ignore: prefer_const_constructors_in_immutables
  _PropagationCase({required this.stop});

  final bool stop;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final order = useState(<String>[]);
    final innerIndex = order.value.indexOf('内层');
    final outerIndex = order.value.indexOf('外层');

    return ElView(
      style: .new(backgroundColor: colors.secondaryContainer, padding: .all(12)),
      event: ElEvent(onTapDown: (_) => order.value = [], onTap: (_) => order.value = [...order.value, '外层']),
      child: Column(
        spacing: 8,
        crossAxisAlignment: .stretch,
        children: [
          Text(stop ? '阻止冒泡' : '默认冒泡', style: TextStyle(color: colors.onSecondaryContainer)),
          Text(
            key: ValueKey(('event-propagation-outer', stop)),
            outerIndex < 0 ? '外层等待点击' : '${outerIndex + 1}. 外层 onTap',
            style: TextStyle(color: colors.onSecondaryContainer),
          ),
          ElView(
            key: ValueKey(('event-propagation-inner', stop)),
            style: .new(backgroundColor: colors.primaryContainer, alignment: .center, height: 56),
            event: ElEvent(
              onTap: (event) {
                order.value = [...order.value, '内层'];
                if (stop) event.stopPropagation();
              },
            ),
            child: Text(
              innerIndex < 0 ? '点击内层' : '${innerIndex + 1}. 内层 onTap',
              style: TextStyle(color: colors.onPrimaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}
