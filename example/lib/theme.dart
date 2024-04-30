import 'dart:ui';

import 'package:flutter_base/flutter_base.dart';

class MobileThemeData extends FlutterThemeData {
  Color customColor;

  MobileThemeData({
    super.primary,
    super.success,
    super.info,
    super.warning,
    super.error,
    super.bgColor,
    super.bgColor2,
    super.bgColor3,
    super.headerColor,
    super.textColor,
    super.iconColor,
    this.customColor = const Color.fromARGB(255, 16, 185, 129),
  });

  MobileThemeData.dark({
    super.primary,
    super.success,
    super.info,
    super.warning,
    super.error,
    super.bgColor,
    super.bgColor2,
    super.bgColor3,
    super.headerColor,
    super.textColor,
    super.iconColor,
    this.customColor = const Color(0xff181818),
  }) : super.dark();

  @override
  MobileThemeData copyWith({
    Color? primary,
    Color? success,
    Color? info,
    Color? warning,
    Color? error,
    Color? bgColor,
    Color? bgColor2,
    Color? bgColor3,
    Color? headerColor,
    Color? textColor,
    Color? iconColor,
    Color? customColor,
  }) {
    return MobileThemeData(
      primary: primary ?? this.primary,
      success: success ?? this.success,
      info: info ?? this.info,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      bgColor: bgColor ?? this.bgColor,
      bgColor2: bgColor2 ?? this.bgColor2,
      bgColor3: bgColor3 ?? this.bgColor3,
      headerColor: headerColor ?? this.headerColor,
      textColor: textColor ?? this.textColor,
      iconColor: iconColor ?? this.iconColor,
      customColor: customColor ?? this.customColor,
    );
  }
}
