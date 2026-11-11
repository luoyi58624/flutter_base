import 'package:flutter/widgets.dart';

import '../../../../../flutter.dart';
import '../../../desktop/components/select/index.dart' as core;

/// 选择器复用候选、焦点和弹层机制，输入外观由移动预设提供。
Widget selectBuilder<T>(BuildContext context, ElSelect<T> c) => core.Select<T>(
  c,
  themeStyle: ElStyle(
    width: '100%',
    height: 46,
    fontSize: 14,
    borderRadius: .circular(13),
    backgroundColor: context.elTheme.fill,
  ),
);
