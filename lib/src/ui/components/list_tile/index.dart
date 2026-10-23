import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/flutter.dart';
import 'package:flutter_base/ui.dart';

part 'group.dart';

/// 根据最近事件状态显示按压与悬停反馈的列表条目。
class MyListTile extends StatelessWidget {
  /// 创建列表条目。
  const MyListTile({super.key, required this.title, this.icon, this.onPressed});

  /// 条目标题。
  final String title;

  /// 标题前的可选图标。
  final Widget? icon;

  /// 点击条目时执行。
  final VoidCallback? onPressed;

  /// 图标区域的逻辑宽度。
  double get iconWidth => 56;

  @override
  Widget build(BuildContext context) {
    final isEnd = ElChildIndex.of(context).isEnd;
    Widget result = ElEventView(
      event: ElEvent(
        onTap: (e) => onPressed?.call(),
        config: ElEventConfig(delayTouchDown: Duration.zero, delayTouchUp: Duration(milliseconds: 100)),
      ),
      // 读取宿主下的 context，避免订阅到条目外层的事件状态。
      child: Builder(
        builder: (context) => ElView(
          style: .new(
            padding: .symmetric(vertical: 16),
            backgroundColor: context.hasTap
                ? Colors.grey.shade300
                : context.hasHover
                ? Colors.grey.shade100
                : null,
            transitions: [.all()],
          ),
          child: Row(
            children: [
              icon == null
                  ? ElView(style: .new(width: 16))
                  : ElView(
                      style: .new(width: iconWidth),
                      child: Center(child: icon),
                    ),
              Expanded(
                child: ElView(
                  style: .new(),
                  child: Text(
                    title,
                    style: TextStyle(fontWeight: .w500, fontSize: 15, color: Colors.black),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (!isEnd) {
      result = Stack(
        children: [
          result,
          Positioned(
            left: icon == null ? 16 : iconWidth,
            right: 16,
            bottom: 0,
            child: ColoredBox(color: Colors.grey.shade300, child: SizedBox(height: 0.5)),
          ),
        ],
      );
    }
    return result;
  }
}
