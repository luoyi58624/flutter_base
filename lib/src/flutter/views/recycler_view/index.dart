/// 按 AndroidX RecyclerView 契约组织的 Dart 视图回收、线性、网格与瀑布流布局内核。
library;

import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart' show HardwareKeyboard, LogicalKeyboardKey;
import 'package:flutter/widgets.dart';

import '../../utils/internal/reuse_animation.dart';
import 'test_clock.dart';
import 'work_probe.dart';
import '../scroll/smooth_scroll/smooth_pointer_scroll.dart';
import '../scroll/smooth_scroll/smooth_scroll.dart';
import '../view/provider.dart';

part 'adapter.dart';
part 'pool.dart';
part 'layout_manager.dart';
part 'grid_layout_manager.dart';
part 'grid_geometry.dart';
part 'grid_viewport.dart';
part 'pointer_scroll.dart';
part 'recycler_view.dart';
part 'viewport.dart';

final _clock = Stopwatch()..start();

int get _nowUs {
  var value = _clock.elapsedMicroseconds;
  assert(() {
    // ignore: invalid_use_of_visible_for_testing_member
    value = RecyclerTestClock.nowMicroseconds?.call() ?? value;
    return true;
  }());
  return value;
}
