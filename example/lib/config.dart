import 'dart:ui';

import 'package:flutter_base/flutter_base.dart';

class MobileAppConfigData extends FlutterConfigData {
  int borderRadius;

  MobileAppConfigData({
    super.title,
    super.fontFamily,
    super.defaultFontWeight,
    super.headerHeight,
    super.useMaterial3,
    super.radius,
    super.centerTitle,
    super.enableRipple,
    super.translucenceStatusBar,
    super.showPerformanceOverlay,
    super.hoverScale,
    super.tapScale,
    this.borderRadius = 4,
  });

  @override
  MobileAppConfigData copyWith({
    String? title,
    String? fontFamily,
    FontWeight? defaultFontWeight,
    double? headerHeight,
    bool? useMaterial3,
    double? radius,
    bool? centerTitle,
    bool? enableRipple,
    bool? translucenceStatusBar,
    bool? showPerformanceOverlay,
    int? hoverScale,
    int? tapScale,
    int? borderRadius,
  }) {
    return MobileAppConfigData(
      title: title ?? this.title,
      fontFamily: fontFamily ?? this.fontFamily,
      defaultFontWeight: defaultFontWeight ?? this.defaultFontWeight,
      headerHeight: headerHeight ?? this.headerHeight,
      useMaterial3: useMaterial3 ?? this.useMaterial3,
      radius: radius ?? this.radius,
      centerTitle: centerTitle ?? this.centerTitle,
      enableRipple: enableRipple ?? this.enableRipple,
      translucenceStatusBar: translucenceStatusBar ?? this.translucenceStatusBar,
      showPerformanceOverlay: showPerformanceOverlay ?? this.showPerformanceOverlay,
      hoverScale: hoverScale ?? this.hoverScale,
      tapScale: tapScale ?? this.tapScale,
      borderRadius: borderRadius ?? this.borderRadius,
    );
  }
}
