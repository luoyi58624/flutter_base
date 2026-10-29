import 'package:equatable/equatable.dart';
import 'package:flutter_base/dart.dart';
import 'package:flutter/material.dart';

/// 跨组件库共享的语义色类型，具体色值由各风格的 token 映射决定。
enum ElThemeType implements ElSerialize<ElThemeType> {
  /// 主要操作。
  primary,

  /// 成功状态。
  success,

  /// 普通信息。
  info,

  /// 警告状态。
  warning,

  /// 错误状态。
  error;

  /// 不含主要操作的状态类型。
  static const List<ElThemeType> statusTypes = [success, info, warning, error];

  /// 全部语义类型，顺序与枚举声明一致。
  static const List<ElThemeType> types = [primary, ...statusTypes];

  @override
  ElThemeType? deserialize(String? str) => str == null ? null : values.asNameMap()[str];

  @override
  String? serialize(ElThemeType? obj) => obj?.name;
}

class ElLabelModel<T> with Equatable {
  final String? label;
  final T? value;

  ElLabelModel(this.label, [this.value]);

  @override
  bool? get stringify => true;

  @override
  List<Object?> get props => [label, value];
}

/// 通用五级档位
enum ElLevelType implements ElSerialize<ElLevelType> {
  xs,
  sm,
  md,
  lg,
  xl;

  static const List<ElLevelType> types = [xs, sm, md, lg, xl];

  @override
  ElLevelType? deserialize(String? str) => str == null ? null : values.asNameMap()[str];

  @override
  String? serialize(ElLevelType? obj) => obj?.name;
}

/// 嵌套数据模型
abstract base class ElNestModel<T extends ElNestModel<T>> with Equatable {
  const ElNestModel({required this.key, required this.children});

  /// 唯一 key
  final String key;

  /// 嵌套模型
  final List<T> children;

  @override
  bool? get stringify => true;

  @override
  List<Object?> get props => [key, children];

  /// 计算目标 key 在嵌套模型的完整路径
  /// * list 嵌套数据集合
  /// * targetKey 寻找的目标 key
  /// * inherit 子级 key 是否要继承父级 key
  /// * splitChar 自定义拼接字符
  static List<T> findKeyPath<T extends ElNestModel<T>>(
      List<T> list,
      String targetKey, {
        bool inherit = false,
        String splitChar = '',
      }) {
    if (list.isEmpty) return [];

    // 用于记录每个节点的父节点，以及收集所有节点
    final parentMap = <T, T?>{};
    final allNodes = <T>[];

    // 递归遍历：收集所有节点，并建立 parent 关系
    void traverse(T node, T? parent) {
      allNodes.add(node);
      parentMap[node] = parent;
      for (final child in node.children) {
        traverse(child, node);
      }
    }

    // 从每个根节点开始遍历
    for (final rootNode in list) {
      traverse(rootNode, null);
    }

    // 遍历所有节点，查找匹配的 key
    for (final node in allNodes) {
      String keyToMatch;

      if (inherit) {
        // 构造从根到当前节点的完整 key，例如 "A/B/C"
        final keys = <String>[];
        T? current = node;

        while (current != null) {
          keys.add(current.key);
          current = parentMap[current];
        }

        keyToMatch = keys.reversed.toList().join(splitChar);
      } else {
        keyToMatch = node.key;
      }

      // 判断是否匹配目标 key
      if (keyToMatch == targetKey) {
        final path = <T>[];
        T? current = node;

        while (current != null) {
          path.add(current);
          current = parentMap[current];
        }

        // 反转路径：从根 -> ... -> 目标节点
        return path.reversed.toList();
      }
    }

    // 没找到匹配的 key
    return [];
  }
}


/// 菜单模型类
final class ElMenuModel<T> extends ElNestModel<ElMenuModel<T>> {
  const ElMenuModel({required super.key, required this.title, this.icon, this.data, super.children = const []});

  /// 菜单名字
  final String title;

  /// 菜单图标
  final Widget? icon;

  /// 自定义额外数据
  final T? data;

  @override
  List<Object?> get props => [...super.props, title, icon, data];

  @override
  String toString() {
    return 'ElMenuModel{key: $key, title: $title}';
  }
}

extension ElMenuModelExt<T> on List<ElMenuModel<T>> {
  /// 转换 [List] 菜单集合，此函数通常用于路由中，它会将嵌套子菜单的 key 转换成完整路径（拼接父级 key 地址）
  List<ElMenuModel<T>> toFullPath({String? parentPath}) {
    List<ElMenuModel<T>> buildNestPaths(List<ElMenuModel<T>> menus, String? parentPath) {
      return menus.map((menu) {
        final currentPath = _buildFullPath(parentPath, menu.key);
        final newMenu = ElMenuModel<T>(
          key: currentPath,
          title: menu.title,
          data: menu.data,
          children: menu.children.isNotEmpty ? buildNestPaths(menu.children, currentPath) : [],
        );

        return newMenu;
      }).toList();
    }

    return buildNestPaths(this, parentPath);
  }

  String _buildFullPath(String? parentPath, String currentKey) {
    if (parentPath == null) return currentKey;
    return '$parentPath/$currentKey'.replaceAll('//', '/');
  }
}

/// 创建默认的滚动控制器所支持的参数模型
class ElScrollControllerAttrModel {
  const ElScrollControllerAttrModel({
    this.initialScrollOffset,
    this.keepScrollOffset,
    this.onAttach,
    this.onDetach,
    this.debugLabel,
  });

  final double? initialScrollOffset;
  final bool? keepScrollOffset;
  final ScrollControllerCallback? onAttach;
  final ScrollControllerCallback? onDetach;
  final String? debugLabel;
}
