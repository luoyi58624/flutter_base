import 'package:flutter/widgets.dart';

import '../../../../flutter/components/radio/index.dart';
import '../../../widgets/choice_visual.dart';

/// 为公共单选声明提供移动端外观，导航和分组选择仍由官方 RawRadio 负责。
Widget radioBuilder<T>(BuildContext context, ElRadio<T> component, ElRadioState state) =>
    ElChoiceVisual(checked: state.checked, disabled: state.disabled, mobile: true, radio: true, label: component.label);
