part of flutter_base;

/// 包含name-icon结构的简单数据模型
class IconModel {
  final String name;
  final IconData icon;

  IconModel(this.name, this.icon);
}

/// 导航模型抽象类
class NavModel {
  /// 导航的标题名字
  final String title;

  /// 导航图标，可选
  final IconData? icon;

  const NavModel(this.title, {this.icon});
}

/// 命令式导航页面模型
class PageNavModel extends NavModel {
  final Widget page;

  const PageNavModel(super.title, this.page, {super.icon});
}

/// 声明式导航页面模型
class UrlNavModel extends NavModel {
  final String path;

  const UrlNavModel(super.title, this.path, {super.icon});
}

/// 路由模型
class RouterModel extends NavModel {
  /// 路由跳转地址
  final String path;

  /// 路由对应的页面组件
  final Widget page;

  /// 子路由
  List<RouterModel>? children;

  RouterModel(
    super.title,
    this.path,
    this.page, {
    super.icon,
    this.children,
  }) {
    children = children ?? [];
  }
}
