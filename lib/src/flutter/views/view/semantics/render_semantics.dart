import 'dart:ui' show TextDirection;

import 'package:flutter/rendering.dart' show RenderSemanticsAnnotations, SemanticsConfiguration;

import 'semantics.dart';

// 只缓存实际使用的显式声明；适配对象不加入渲染树，动作始终绑定原 properties。
final _annotations = Expando<RenderSemanticsAnnotations>('ElView semantics');

/// 排除语义时，同时停止读取自身文本和遍历后代。
bool shouldExcludeViewSemanticsChildren(ElSemantics? semantics) => semantics?.exclude ?? false;

/// 复用官方属性与动作映射，在内容语义上叠加焦点和语义树策略。
void applyViewSemanticsConfiguration(
  SemanticsConfiguration config, {
  required ElSemantics? semantics,
  required TextDirection? textDirection,
  required bool includeFocusSemantics,
  required bool focusableForSemantics,
  required bool focusedForSemantics,
}) {
  if (shouldExcludeViewSemanticsChildren(semantics)) return;
  final props = semantics?.properties;
  if (semantics != null && props != null) {
    final annotation = _annotations[semantics] ??= RenderSemanticsAnnotations(
      properties: props,
      explicitChildNodes: semantics.explicitChildNodes,
      blockUserActions: semantics.blockUserActions,
      localeForSubtree: semantics.localeForSubtree,
    );
    // 共享声明可用于方向不同的视图；方向随当前宿主，动作仍读取不可变的原声明。
    final hasText =
        props.label != null ||
        props.attributedLabel != null ||
        props.value != null ||
        props.attributedValue != null ||
        props.increasedValue != null ||
        props.attributedIncreasedValue != null ||
        props.decreasedValue != null ||
        props.attributedDecreasedValue != null ||
        props.hint != null ||
        props.attributedHint != null ||
        props.tooltip != null;
    annotation.textDirection = props.textDirection ?? (hasText ? textDirection ?? TextDirection.ltr : null);
    annotation.describeSemanticsConfiguration(config);
    if (semantics.blockPreviousSemantics) config.isBlockingSemanticsOfPreviouslyPaintedNodes = true;
    if (semantics.indexInParent case final index?) config.indexInParent = index;
  }
  // 内容已写入自身语义，显式声明由官方适配器覆盖；焦点仅补齐缺省值。
  if (props?.focused == null && includeFocusSemantics) {
    config.isFocused = focusableForSemantics ? focusedForSemantics : null;
  }
  final needsBoundary =
      (semantics?.container ?? false) ||
      (semantics?.mergeDescendants ?? false) ||
      includeFocusSemantics ||
      config.hasBeenAnnotated;
  if (needsBoundary) config.isSemanticBoundary = true;
  if (semantics?.mergeDescendants ?? false) config.isMergingSemanticsOfDescendants = true;
}
