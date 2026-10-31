import 'package:flutter/widgets.dart';
import 'package:flutter_base/ui.dart';

/// 工具栏的公共声明入口。
class ElToolbar extends StatelessWidget {
  /// 创建工具栏声明，沿用当前源组件的空参数契约。
  const ElToolbar({super.key});

  @override
  Widget build(BuildContext context) =>
      ElComponentProvider.of(context).toolbarBuilder!(context, this);
}
