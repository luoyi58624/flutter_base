import 'package:flutter/widgets.dart';

import '../render/render_view.dart';

/// 为按需内容模块提供 Flutter 子树操作，模块自行持有专属子项和依赖。
abstract interface class ContentElementHost {
  /// 当前内容所在的构建上下文。
  BuildContext get context;

  /// 当前内容所在的盒模型宿主。
  ElRenderView get renderView;

  /// 更新模块持有的单个子元素。
  Element? updateContentChild(Element? child, Widget? widget, Object? slot);

  /// 更新模块持有的有序子元素，并保留 Flutter 的键复用规则。
  List<Element> updateContentChildren(List<Element> children, List<Widget> widgets, Set<Element>? forgottenChildren);
}

/// 内容模块按需创建的元素绑定，负责自己的子树与环境依赖。
abstract interface class ContentElementBinding {
  /// 同步当前内容的子树与环境。
  void update();

  /// 访问模块当前仍持有的子元素。
  void visitChildren(ElementVisitor visitor);

  /// 移除被 Flutter 迁走的子元素，返回是否属于当前模块。
  bool forgetChild(Element child);

  /// 退出内容模式时撤下子树；整体卸载时仅清除已经卸载的引用。
  void dispose({bool unmounting = false});
}
