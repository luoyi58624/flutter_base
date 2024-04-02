part of flutter_base;

/// 包含name-icon结构的简单数据模型
class IconModel {
  final String name;
  final IconData icon;

  IconModel(this.name, this.icon);
}

/// 通用的导航页面模型，由导航标题、跳转的页面、可选图标组成
class NavPageModel {
  final String title;
  final Widget page;
  final IconData? icon;

  const NavPageModel(this.title, this.page, [this.icon]);
}

/// 根页面模型
class RootPageModel extends NavPageModel {
  /// 跳转地址
  final String path;

  const RootPageModel(super.title, this.path, super.page, [super.icon]);
}