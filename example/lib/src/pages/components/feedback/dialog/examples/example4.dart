import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';

/// placement 为 bottom 时即底部面板，移动端可从面板或遮罩向下拖动关闭；top 停靠顶部。
class Example4 extends StatelessWidget {
  /// 创建弹出位置示例。
  Example4({super.key});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        ElButton(
          onPressed: () async {
            final target = await el.dialog.show<String>(
              context,
              placement: .bottom,
              title: '分享到',
              showClose: true,
              child: Builder(
                builder: (context) => Column(
                  mainAxisSize: .min,
                  crossAxisAlignment: .stretch,
                  children: [
                    for (final target in ['微信好友', '邮件', '复制链接'])
                      ElListTile(title: target, onTap: () => Navigator.pop(context, target)),
                  ],
                ),
              ),
            );
            if (target != null && context.mounted) el.message.show('已分享到$target', context: context, type: .success);
          },
          child: '底部面板',
        ),
        ElButton(
          onPressed: () => el.dialog.show(
            context,
            placement: .top,
            title: '系统维护通知',
            showClose: true,
            child: '今晚 23:00 至次日 01:00 进行系统维护，期间部分功能暂不可用。',
          ),
          child: '顶部',
        ),
      ],
    );
  }
}
