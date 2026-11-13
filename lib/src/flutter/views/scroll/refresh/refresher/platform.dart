import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/widgets.dart';

import 'android.dart' show ElAndroidRefresher, buildAndroidRefreshSpinner;
import 'index.dart' show ElRefresher;
import 'ios.dart' show ElIosRefresher, buildIosRefreshSpinner;

bool get _usesAndroidRefresher =>
    defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.fuchsia;

/// 当前平台的默认下拉刷新器。
ElRefresher get platformRefresher => _usesAndroidRefresher ? const ElAndroidRefresher() : const ElIosRefresher();

/// 构建与默认下拉刷新器同平台的加载指示器。
Widget buildPlatformRefreshSpinner() => _usesAndroidRefresher ? buildAndroidRefreshSpinner() : buildIosRefreshSpinner();
