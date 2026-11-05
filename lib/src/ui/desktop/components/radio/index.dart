import 'package:flutter/widgets.dart';

import '../../../../flutter/components/radio/index.dart';
import '../../../widgets/choice_visual.dart';

/// 为公共单选声明提供桌面外观，键盘导航继续由公共 RawRadio 处理。
Widget radioBuilder<T>(BuildContext context, ElRadio<T> component, ElRadioState state) => ElChoiceVisual(
  checked: state.checked,
  disabled: state.disabled,
  mobile: false,
  radio: true,
  label: component.label,
);
