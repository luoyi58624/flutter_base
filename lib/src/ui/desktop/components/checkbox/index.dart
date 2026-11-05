import 'package:flutter/widgets.dart';

import '../../../../flutter/components/checkbox/index.dart';
import '../../../widgets/choice_visual.dart';

/// 为公共复选声明提供桌面外观，不重复创建交互和焦点宿主。
Widget checkboxBuilder(BuildContext context, ElCheckbox component, ElCheckboxState state) => ElChoiceVisual(
  checked: state.checked,
  disabled: state.disabled,
  mobile: false,
  indeterminate: component.indeterminate,
  label: component.label,
);
