import 'package:flutter/foundation.dart' show internal;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../scroll/scrollbar/scrollbar_base.dart';
import '../selection/common/selection_core.dart';
import '../view/style/style.dart';

/// 可编辑视图的组合样式与编辑配置，文字外观统一由 view 级联。
///
/// 未声明的文字字段继承祖先 ElView；不持有第二套 Flutter TextStyle。
@immutable
class ElEditableStyle {
  /// 创建编辑配置；view 的 padding 属于外壳，contentPadding 随正文滚动。
  const ElEditableStyle({
    this.view,
    this.softWrap = true,
    this.contentPadding = EdgeInsets.zero,
    this.readOnly = false,
    this.autofocus = false,
    this.obscureText = false,
    this.obscuringCharacter = '•',
    this.caretColor,
    this.caretWidth = 1.5,
    this.caretAnimationDuration = const Duration(milliseconds: 80),
    this.selectionColor,
    this.selectionTextColor,
    this.retainSelectionOnBlur = false,
    this.selectAllRevealsCaret = true,
    this.composingUnderline = true,
    this.fixedLineHeight = false,
    this.scrollPhysics,
    this.scrollbar,
    this.cacheExtent = 500,
    this.inputConfiguration,
    @internal this.selectionControls,
    this.enableInteractiveSelection = true,
    this.enabledSelectionHandles = true,
    this.enabledMagnifier = true,
    this.enabledSelectionToolbar = true,
    this.enabledContextMenu = true,
    this.tabSize = 4,
    this.semanticLabel,
  });

  /// 编辑器外壳及文字声明，支持变量、状态变体与过渡。
  final ElStyle? view;

  /// 是否按视口宽度换行。
  final bool softWrap;

  /// 可编辑内容内边距。
  final EdgeInsets contentPadding;

  /// 是否只读。
  final bool readOnly;

  /// 首次挂载时是否请求焦点。
  final bool autofocus;

  /// 是否隐藏明文。
  final bool obscureText;

  /// 密码掩码字符。
  final String obscuringCharacter;

  /// 光标颜色。
  final Color? caretColor;

  /// 光标宽度。
  final double caretWidth;

  /// 光标移动动画时长。
  final Duration caretAnimationDuration;

  /// 选区底色。
  final Color? selectionColor;

  /// 选中文字颜色。
  final Color? selectionTextColor;

  /// 失焦后是否保留选区显示。
  final bool retainSelectionOnBlur;

  /// 全选后是否滚动到光标。
  final bool selectAllRevealsCaret;

  /// 是否显示组合输入下划线。
  final bool composingUnderline;

  /// 是否使用基础字体的固定行高；启用行内组件时始终固定。
  final bool fixedLineHeight;

  /// 滚动物理规则。
  final ScrollPhysics? scrollPhysics;

  /// 滚动条样式。
  final ElScrollbar? scrollbar;

  /// 视口外预排版距离。
  final double cacheExtent;

  /// 平台键盘和自动填充配置。
  final TextInputConfiguration? inputConfiguration;

  /// 平台选区操作样式。
  @internal
  final SelectionControls? selectionControls;

  /// 是否允许交互选中。
  final bool enableInteractiveSelection;

  /// 是否显示移动端选区句柄。
  final bool enabledSelectionHandles;

  /// 是否显示移动端放大镜。
  final bool enabledMagnifier;

  /// 是否显示选区工具条。
  final bool enabledSelectionToolbar;

  /// 是否显示右键编辑菜单。
  final bool enabledContextMenu;

  /// 无障碍文本框标签。
  final String? semanticLabel;

  /// 制表符的显示宽度。
  final int tabSize;
}
