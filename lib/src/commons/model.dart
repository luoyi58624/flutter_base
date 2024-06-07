part of '../../flutter_base.dart';

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
}

/// 包含 label-value 结构的简单数据模型
class LabelModel {
  final String label;
  final String value;

  LabelModel(this.label, this.value);

  @override
  String toString() {
    return 'LabelModel{label: $label, value: $value}';
  }
}

/// 数据模型序列化，一般用于本地持久化缓存
/// ```dart
/// class UserModel extends ModelSerialize {
///   UserModel({this.name, this.age});
///
///   String? name;
///   int? age;
///
///   factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
///         name: json['name'],
///         age: DartUtil.safeInt(json['age']),
///       );
///
///   @override
///   UserModel fromJson(Map<String, dynamic> json) => UserModel.fromJson(json);
///
///   @override
///   Map<String, dynamic> toJson() => {'name': name, 'age': age};
/// }
/// ```
abstract class ModelSerialize {
  ModelSerialize fromJson(Map<String, dynamic> json);

  Map<String, dynamic> toJson();
}
