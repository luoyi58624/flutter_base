import 'package:flutter_base/src/ui/cores/common/bit_mask.dart';
import '../resolved/resolved_style.dart';

/// 继承传播目标的抽象接口。
///
/// 解耦：让 `InheritancePropagator` 不依赖具体 `ElRenderView` 类型，方便测试
/// 和后续扩展。`ElRenderView` 实现此接口。
abstract class InheritableNode {
  /// 当前 commit 的 [ResolvedStyle]（含 cascade 输出）。
  ResolvedStyle? get committedResolvedStyle;

  /// 当前节点向后代暴露的 effective dark。
  bool get effectiveDarkForInheritance;

  /// 当前层显式声明的继承字段，用于传播剪枝。
  FieldMask get explicitlySetMask;

  /// 遍历直接的 [InheritableNode] 后代。
  ///
  /// 实现应跳过非 ElRenderView 类型的 child，继续递归找到下一层 ElRenderView。
  void visitInheritableChildren(void Function(InheritableNode child) visitor);

  /// 重新 cascade 自身（祖先 inherited 字段变化触发）。
  FieldMask reresolveFromInheritance(
    ResolvedStyle? newParentResolved,
    FieldMask changedMask, {
    FieldMask inheritedThemeAnimationMask = FieldMask.empty,
  });

  /// 祖先 effective dark 变化时同步到本节点。
  ///
  /// 返回 false 表示本节点有显式 dark override，后代继承在此截断。
  bool inheritDarkFromAncestor(bool dark);

  /// 本节点向后代暴露的响应式状态位（xs..xl，位 9..13）。
  int get responsiveBitsForInheritance {
    // 该 default 只覆盖抽象接口不落到 render 的边界（测试 mock 用），
    // 实机透明节点在自己 override 里 walk parent。
    return 0;
  }

  /// 祖先响应式位变化时同步到本节点。
  bool inheritResponsiveFromAncestor(int bits) => true;
}
