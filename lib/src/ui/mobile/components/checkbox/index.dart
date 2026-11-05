import 'package:flutter/widgets.dart';

import '../../../../flutter/components/checkbox/index.dart';
import '../../../widgets/choice_visual.dart';

/// 为公共复选声明提供移动端外观，保留公共层的事件、分组与语义。
Widget checkboxBuilder(BuildContext context, ElCheckbox component, ElCheckboxState state) => ElChoiceVisual(
  checked: state.checked,
  disabled: state.disabled,
  mobile: true,
  indeterminate: component.indeterminate,
  label: component.label,
);
