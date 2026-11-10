import 'dart:async' show unawaited;
import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter/widgets.dart';

import '../../../../dart.dart' show ElStorage, ElStorageGroup, $absent;
import '../../components/index.dart' show ElComponentProvider;
import '../../utils/internal/benchmark_probe.dart' show MountTrace, elMountTraceEnabled;
import '../../utils/internal/gutter.dart' show OrdinalGutterHost, RenderOrdinalGutter;
import '../../scroll/dual_axis_scroll.dart' show DualAxisScroll;
import '../../scroll/scroll.dart' show ElScroll;
import '../../slivers/recycler/sliver_recycler.dart' show ElSliverRecyclerController, ElSliverRecyclerList;
import '../button/button_view.dart';
import '../layout/stack/stack_view.dart';
import '../view/event/event.dart';
import '../view/render/render_view.dart';
import '../view/semantics/semantics.dart';
import '../view/style/resolved/resolved_style.dart';
import '../view/style/style.dart';
import '../view/text/text_style_adapter.dart' show inheritedTextToTextStyle, elStyleToTextStyle;
import '../view/view.dart';
import 'table_column.dart';

export 'table_column.dart';

part 'table_cache.dart';
part 'table_controller.dart';
part 'table_event.dart';
part 'table_style.dart';
part 'table_view.dart';
part 'render_table_view.dart';
part 'table_grid.dart';

// ---------------------------------------------------------------------------
// 包内载体：只在本库内部使用，公共 barrel 不导出它们。
//
// 为什么不放在 `table_column.dart`：那个文件被 barrel **整文件导出**，
// 出现在那里的公开声明就等于对外公开。本文件（以及它的 part）只对 barrel 暴露
// `show` 清单里的三个名字（ElTable / ElTableStyle / ElTableController），
// 所以载体集中放在这里才是安全的。

/// 从业务行和列配置中读取单元格原始值；不声明时按 column.prop 从 Map 点路径读取。
typedef ElTableColumnBuilder = Object? Function(ElTableRow row, ElTableColumn column);

/// 序号列自定义值生成器，适合分页偏移或业务序号。
typedef ElTableIndexBuilder = Object? Function(ElTableCell cell);

typedef _IndexTextEnvironment = ({TextStyle style, TextScaler scaler, TextDirection direction, Locale? locale});

/// 多选列的语义控件状态，上层组件库负责把它画成具体 checkbox。
@immutable
class ElTableSelectionControl {
  /// 创建多选语义控件状态。
  const ElTableSelectionControl({required this.state, required this.disabled, this.row, this.rowKey, this.rowIndex});

  /// 当前选择状态，表头可能是 [ElTableSelectionState.partial]。
  final ElTableSelectionState state;

  /// 是否禁用交互。
  final bool disabled;

  /// 行控件对应的原始业务行；null 表示这是表头控件。
  final ElTableRow? row;

  /// 行控件对应的稳定行身份；表头控件为 null。
  final Object? rowKey;

  /// 行控件对应的展示序行号；表头控件为 null。
  final int? rowIndex;

  /// true 表示表头全选控件。
  bool get isHeader => row == null;

  /// 是否处于选中态。
  bool get checked => state == ElTableSelectionState.all;

  /// 是否处于半选态。
  bool get indeterminate => state == ElTableSelectionState.partial;
}

/// 展开列的语义控件状态，上层组件库负责把它画成具体展开按钮。
@immutable
class ElTableExpansionControl {
  /// 创建展开语义控件状态。
  const ElTableExpansionControl({
    required this.expanded,
    required this.disabled,
    required this.row,
    required this.rowKey,
    required this.rowIndex,
  });

  /// 当前行是否已展开。
  final bool expanded;

  /// 是否禁用交互。
  final bool disabled;

  /// 当前原始业务行。
  final ElTableRow row;

  /// 当前行稳定身份。
  final Object rowKey;

  /// 当前展示序行号。
  final int rowIndex;
}
