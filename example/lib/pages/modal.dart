import 'package:example/global.dart';
import 'package:flutter/material.dart';

class ModalPage extends HookWidget {
  const ModalPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Modal测试'),
      ),
      body: ColumnWidget(
        center: false,
        children: [
          buildCardWidget(context, title: '基础提示框', children: [
            buildCellWidget(context, title: '显示提示框', onTap: () {
              DialogWidget.show(title: '提示', content: '这是一段文字');
            }),
            buildCellWidget(context, title: '显示提示框，不包含标题', onTap: () {
              DialogWidget.show(content: '这是一段文字');
            }),
            buildCellWidget(context, title: '显示提示框，点击遮罩禁止关闭', onTap: () {
              DialogWidget.show(content: '这是一段文字', clickOutsideClose: false);
            }),
            buildCellWidget(context, title: '显示提示框，自定义事件', onTap: () {
              DialogWidget.show(
                title: '提示',
                content: '这是一段文字',
                onConfirm: () async {
                  i('点击了确定');
                  await 1.delay();
                  return false;
                },
                onCancel: () async {
                  i('点击了取消');
                  return false;
                },
              );
            }),
            buildCellWidget(context, title: '显示提示框，执行异步任务', onTap: () {
              DialogWidget.show(
                title: '提示',
                content: '这是一段文字',
                onConfirm: () async {
                  await 2.delay();
                  return true;
                },
                onCancel: () async {
                  await 2.delay();
                  return true;
                },
              );
            }),
            buildCellWidget(context, title: '显示提示框，圆形按钮', onTap: () {
              DialogWidget.show(content: '这是一段文字', roundButton: true);
            }),
            buildCellWidget(context, title: '显示提示框，圆形按钮，自定义颜色', onTap: () {
              DialogWidget.show(
                content: '这是一段文字',
                roundButton: true,
                confirmColor: context.appTheme.success,
                onConfirm: () async {
                  await 2.delay();
                  return true;
                },
              );
            }),
            buildCellWidget(context, title: '显示提示框，隐藏遮罩层', onTap: () {
              DialogWidget.show(content: '这是一段文字', modalColor: Colors.transparent);
            }),
            buildCellWidget(context, title: '显示提示框，自定义内容', onTap: () {
              DialogWidget.show(
                titleWidget: const Text(
                  '自定义标题',
                  style: TextStyle(fontSize: 24),
                ),
                contentWidget: const Text(
                  '自定义内容',
                  style: TextStyle(fontSize: 16),
                ),
              );
            }),
          ]),
        ],
      ),
    );
  }
}
