import 'package:flutter/widgets.dart';

import '../../../../../flutter.dart';
import '../../../desktop/components/select/index.dart' as core;
import '../../commons/icons.dart';

/// 选择器复用候选、焦点和弹层机制，输入外观由移动预设提供。
Widget selectBuilder<T>(BuildContext context, ElSelect<T> c) => core.Select<T>(
  c,
  defaultTrailingIcon: ElView(style: const ElStyle(iconSize: 16), child: ElMobileIcons.chevronsUpDown),
  themeStyle: ElStyle(
    width: '100%',
    height: 44,
    fontSize: 14,
    borderRadius: .circular(12),
    backgroundColor: context.elTheme.fill,
  ),
);
