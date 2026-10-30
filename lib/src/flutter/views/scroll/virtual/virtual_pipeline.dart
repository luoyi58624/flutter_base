// 统一滚动管线：普通成员常驻，List/Grid View 按各自构造接入 SegmentPlan。
// 挂载、度量、Mixin、成员能力与选区在同一真实视口生命周期内协作。
// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/physics.dart' show FrictionSimulation, SpringSimulation;
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter/widgets.dart';

import 'package:flutter_base/src/flutter/views/view/provider.dart';

import '../common/physics/bouncing_scroll_physics.dart';
import '../common/physics/browser_scroll_physics.dart';
import '../common/physics/platform_scroll_physics.dart';
import '../refresh/refresher.dart';
import '../refresh/refresh_host.dart';
import '../common/nested/nested_scroll.dart';
import '../common/nested/scroll_delta_interceptor.dart';
import '../common/viewport/scroll_position_binding.dart';
import '../common/viewport/scroll_engine_position.dart';
import '../common/pointer/scroll_input_transaction.dart';
import '../common/pointer/scroll_input_step.dart';
import '../common/pointer/scroll_pointer_motion.dart';
import '../../view/event/event.dart';
import '../../view/view.dart';
import '../../view/style/style.dart';
import '../../selection/common/selection_core.dart';
import 'virtual_scroll_geometry.dart';
import '../scrollbar/scrollbar_base.dart';
import '../scrollbar/scrollbar_controller.dart';
import '../smooth_scroll/smooth_scroll.dart';
import '../common/render/scroll_viewport_base.dart';
import '../plan/segment_extent_index.dart';
import '../../layout/layout_view.dart';
import '../scroll_view.dart';
import '../scroll_state.dart';
import '../plan/segment_diff.dart';
import '../plan/segment_plan.dart';
import '../spec/segment_resolver.dart';
import '../spec/segment_spec.dart';

part 'item/flat_segment_item_list.dart';

part 'item/scroll_item_scope.dart';

part 'testing/scroll_debug_counters.dart';

part 'testing/scroll_mixin_client_probe.dart';

part '../effects/scroll_mixin.dart';
part '../effects/scroll_effect_track.dart';
part 'motion/scroll_motion_coordinator.dart';
part 'motion/scroll_pointer_motion.dart';
part 'motion/scroll_session.dart';

part '../effects/sticky_mixin.dart';
part '../effects/scroll_collapse_mixin.dart';
part '../effects/scroll_collapse_layout.dart';
part '../effects/large_title_navbar_mixin.dart';
part '../effects/large_title_navbar_layout.dart';
part '../effects/scroll_item_effects.dart';
part '../effects/scroll_stretch.dart';

part '../effects/nested_scroll_mixin.dart';

part 'input/scroll_input_router.dart';
part 'input/scroll_input_route.dart';

part 'host/scroll_view_state.dart';

part 'widget/scroll_viewport_widget.dart';

part 'mount/scroll_mount.dart';

part 'mount/virtual_slot_records.dart';

part 'render/render_virtual_viewport.dart';

/// Upper bound for rows mounted by one conservative fill expansion.
const int _maxConservativeFillCount = 256;

/// builder 构建缓存上限；超限仅淘汰最早的一项。
const int _builderChildMemoLimit = 512;
