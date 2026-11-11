import 'package:flutter/widgets.dart';

import '../../../../../flutter.dart';
import '../../../desktop/components/autocomplete/index.dart' as core;

/// 移动补全沿用异步防抖、过期结果丢弃与现有 ElPortal 候选层。
Widget autocompleteBuilder<T>(BuildContext context, ElAutocomplete<T> c) => core.Autocomplete<T>(
  c,
  themeStyle: ElStyle(
    width: '100%',
    height: 46,
    fontSize: 14,
    borderRadius: .circular(13),
    backgroundColor: context.elTheme.fill,
  ),
);
