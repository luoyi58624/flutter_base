import 'dart:ui' show Locale, SemanticsRole, TextDirection;

import 'package:flutter_base/dart.dart';
import 'package:flutter/foundation.dart' show VoidCallback, immutable;
import 'package:flutter/semantics.dart' show SemanticsProperties;

part 'semantics.g.dart';

/// ElView 的语义属性与语义树边界策略。
@ElModelGenerator.copy(generateProps: false)
@immutable
final class ElSemantics {
  /// 创建视图语义声明。
  ///
  /// 便利参数（`label`、`button`、`onTap` 等）是 [properties] 的简写形态，
  /// 两者**互斥**：简单场景用便利参数，完整能力直接传 [SemanticsProperties]。
  /// 便利构造参与 `==` 的逐字段结构比较——build 内联 `ElSemantics(label: ...)`
  /// 每次 rebuild 都是新实例，靠结构等值挡住 render 侧无谓的语义树失效。
  ElSemantics({
    this.container = false,
    this.explicitChildNodes = false,
    this.exclude = false,
    this.mergeDescendants = false,
    this.blockUserActions = false,
    this.blockPreviousSemantics = false,
    this.indexInParent,
    this.localeForSubtree,
    SemanticsProperties? properties,
    String? label,
    String? hint,
    String? value,
    SemanticsRole? role,
    bool? button,
    bool? link,
    Uri? linkUrl,
    bool? image,
    bool? header,
    bool? enabled,
    bool? selected,
    bool? checked,
    bool? toggled,
    bool? expanded,
    TextDirection? textDirection,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
  }) : assert(
         properties == null ||
             (label == null &&
                 hint == null &&
                 value == null &&
                 role == null &&
                 button == null &&
                 link == null &&
                 linkUrl == null &&
                 image == null &&
                 header == null &&
                 enabled == null &&
                 selected == null &&
                 checked == null &&
                 toggled == null &&
                 expanded == null &&
                 textDirection == null &&
                 onTap == null &&
                 onLongPress == null),
         'properties 与便利参数互斥：完整能力用 properties，简单场景用便利参数。',
       ),
       properties =
           properties ??
           SemanticsProperties(
             label: label,
             hint: hint,
             value: value,
             role: role,
             button: button,
             link: link,
             linkUrl: linkUrl,
             image: image,
             header: header,
             enabled: enabled,
             selected: selected,
             checked: checked,
             toggled: toggled,
             expanded: expanded,
             textDirection: textDirection,
             onTap: onTap,
             onLongPress: onLongPress,
           ) {
    _propertyKey = properties == null ? _keyOf(this.properties) : null;
  }

  /// 建立独立语义节点；ElView 的容器边界覆盖可见盒，不包含外边距。
  final bool container;

  /// 要求后代使用自己的语义节点。
  final bool explicitChildNodes;

  /// 从语义树中排除当前节点及后代。
  final bool exclude;

  /// 将后代语义合并到当前独立语义节点。
  final bool mergeDescendants;

  /// 屏蔽子树内与指针相关的语义操作。
  final bool blockUserActions;

  /// 屏蔽同一边界内先绘制的兄弟语义。
  final bool blockPreviousSemantics;

  /// 当前节点在父语义子节点中的顺序。
  final int? indexInParent;

  /// 覆写子树的语言环境。
  final Locale? localeForSubtree;

  /// Flutter 的完整节点语义属性。
  final SemanticsProperties properties;

  // 构造结束前派生便利比较键，和完整 properties 的哈希共用一份字段定义。
  late final Object? _propertyKey;

  Object get _strategyKey => (
    container,
    explicitChildNodes,
    exclude,
    mergeDescendants,
    blockUserActions,
    blockPreviousSemantics,
    indexInParent,
    localeForSubtree,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ElSemantics &&
          _strategyKey == other._strategyKey &&
          (identical(properties, other.properties) || (_propertyKey != null && _propertyKey == other._propertyKey));

  @override
  int get hashCode => Object.hash(_strategyKey, _propertyKey ?? _keyOf(properties));

  // 完整声明也使用同一组字段生成哈希，兼容复用便利声明的 properties 对象。
  static Object _keyOf(SemanticsProperties p) => (
    p.label,
    p.hint,
    p.value,
    p.role,
    p.button,
    p.link,
    p.linkUrl,
    p.image,
    p.header,
    p.enabled,
    p.selected,
    p.checked,
    p.toggled,
    p.expanded,
    p.textDirection,
    p.onTap,
    p.onLongPress,
  );
}
