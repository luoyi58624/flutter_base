part of flutter_base;

/// 包含name-icon结构的简单数据模型
class IconModel {
  IconModel(this.name, this.icon);

  final String name;
  final IconData icon;
}

/// 导航模型抽象类
class NavModel {
  NavModel(this.title, {this.icon});

  /// 导航的标题名字
  late String title;

  /// 导航图标，可选
  IconData? icon;

  NavModel.fromJson(Map<String, dynamic> json) {
    title = json['title']!;
    icon = IconSerializable.fromJson(json['icon']);
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['title'] = title;
    data['icon'] = IconSerializable.toJson(icon);
    return data;
  }
}

/// 命令式导航页面模型
class PageNavModel extends NavModel {
  PageNavModel(super.title, this.page, {super.icon});

  Widget page;
}

/// 声明式导航页面模型
class UrlNavModel extends NavModel {
  UrlNavModel(super.title, this.path, {super.icon});

  late String path;

  UrlNavModel.fromJson(Map<String, dynamic> json) : super.fromJson(json) {
    path = json['path'] ?? '';
  }

  @override
  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['title'] = title;
    data['path'] = path;
    data['icon'] = IconSerializable.toJson(icon);
    return data;
  }
}