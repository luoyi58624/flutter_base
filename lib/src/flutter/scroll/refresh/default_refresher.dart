import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;

import 'android_refresher.dart';
import 'ios_refresher.dart';
import 'refresher.dart';

/// 按平台选择内置刷新器，供普通与 Sliver 刷新入口共用。
ElRefresher resolveDefaultRefresher() => switch (defaultTargetPlatform) {
  TargetPlatform.android || TargetPlatform.fuchsia => const ElAndroidRefresher(),
  TargetPlatform.iOS ||
  TargetPlatform.macOS ||
  TargetPlatform.windows ||
  TargetPlatform.linux => const ElIosRefresher(),
};
