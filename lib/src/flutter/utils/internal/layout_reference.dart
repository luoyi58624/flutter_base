import 'package:flutter/foundation.dart' show protected;
import 'package:flutter/rendering.dart';

/// 布局参照系统 v1：让"尺寸进场即知"（tight 约束 / sizedByParent / 显式声明）
/// 的 render 节点在布局 children 之前把自己的 content box 尺寸写进实例字段，
/// 后代遇到无界约束时沿 parent 链爬到最近提供者读参照——CSS containing block
/// 链在 Flutter 硬约束系统里的等价物。
///
/// **v1 严格边界**：只服务于显式百分比（width/height/minWidth/maxWidth/
/// minHeight/maxHeight 的 percent/calc 解析）与嵌套滚动视口（`_viewportSizeFor`
/// 的无界轴兜底）。**不服务**文本换行、auto 宽 fill——那是 v2，需要区分
/// 生长轴/参照轴。
///
/// **契约**：
/// - 值语义 = content box 尺寸（已减 padding），双轴独立；该轴尺寸不可知
///   （shrink-wrap）时传 null 表示不提供该轴参照。
/// - 提供者仅在 performLayout 排 children 之前登记；dry layout / intrinsic
///   遍历读到的是**上一真实布局帧**的值，不做登记，不影响正确性（percent
///   在 intrinsic 通道本就退化为 undefined）。
mixin LayoutReferenceBox on RenderBox {
  double? _referenceWidth;
  double? _referenceHeight;

  /// 参照登记入口。**只写值不唤醒**：返回 bool 表示两轴合并是否变化，
  /// 唤醒责任移交给调用方按具体场景判断（约束等价性可能已经天然触发重排，
  /// 唤醒往往冗余，见下）。
  ///
  /// **为什么把唤醒踢给调用方**：参照变化 ⇔ 是否需要唤醒后代 之间没有 1:1
  /// 关系——
  /// - ElRenderView：提供者资格 = tight 约束或显式尺寸；Flex 等夹层仍可能
  ///   给后代传入不变的无界约束，因此参照变化需要唤醒后代；首次布局没有
  ///   历史几何时可跳过这次遍历；
  /// - 无界约束的夹层：child 约束不随参照变化，参照变化**必须**唤醒
  ///   （Flutter `layout()` 的 `!_needsLayout && constraints == _constraints`
  ///   短路会冻结子树）。
  ///
  /// 精确判据为「参照变化 && childConstraints 与上次一致」；
  /// 消费者登记式唤醒留作 v2 优化。
  @protected
  bool setLayoutReference(double? width, double? height) {
    if (_referenceWidth == width && _referenceHeight == height) return false;
    _referenceWidth = width;
    _referenceHeight = height;
    return true;
  }

  /// 递归对整棵子树 `markNeedsLayout`——调用方在判定参照变化需要唤醒时用。
  ///
  /// **必须走 [invokeLayoutCallback]**：Flutter 在 performLayout 期间对
  /// `markNeedsLayout` 做 `_debugCanPerformMutations` 检查，非
  /// `_doingThisLayoutWithCallback` 上下文里 mutate 子树会 assert 失败。
  /// invokeLayoutCallback 把标志位置起来，允许我们在 layout 阶段合法 mark
  /// 后代——child 尚未 layout，mark 只是置位，冒泡到 relayoutBoundary 后
  /// 进入 owner 列表，Flutter 会在本次 flushLayout 内继续处理。
  @protected
  void markSubtreeNeedsLayoutForReference() {
    invokeLayoutCallback<Constraints>((_) {
      visitChildren(_markSubtreeNeedsLayout);
    });
  }

  static void _markSubtreeNeedsLayout(RenderObject node) {
    node.markNeedsLayout();
    node.visitChildren(_markSubtreeNeedsLayout);
  }

  /// 沿 parent 链爬到最近提供**宽度参照**的祖先——按轴独立（width 与 height
  /// 参照可来自不同提供者）。到根仍无提供者则返回 null（后代退回 auto，
  /// 兜底不变）。
  static double? ancestorReferenceWidth(RenderObject? node) {
    for (var n = node?.parent; n != null; n = n.parent) {
      if (n is LayoutReferenceBox) {
        final w = n._referenceWidth;
        if (w != null) return w;
      }
    }
    return null;
  }

  /// 沿 parent 链爬到最近提供**高度参照**的祖先。
  static double? ancestorReferenceHeight(RenderObject? node) {
    for (var n = node?.parent; n != null; n = n.parent) {
      if (n is LayoutReferenceBox) {
        final h = n._referenceHeight;
        if (h != null) return h;
      }
    }
    return null;
  }
}
