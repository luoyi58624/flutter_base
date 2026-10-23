// GENERATED CODE - DO NOT MODIFY BY HAND

part of '../../models/class_extended.dart';

// **************************************************************************
// ElModelGenerator
// **************************************************************************

extension RootModelExt on RootModel {
  RootModel copyWith({Object? rootName = $absent}) {
    return RootModel(
      rootName: identical(rootName, $absent)
          ? this.rootName
          : rootName as String?,
    );
  }

  RootModel merge([RootModel? other]) {
    if (other == null) return this;
    return RootModel(rootName: other.rootName ?? rootName);
  }
}

extension ParentModelExt on ParentModel {
  ParentModel copyWith({
    Object? parentName = $absent,
    Object? rootName = $absent,
  }) {
    return ParentModel(
      parentName: identical(parentName, $absent)
          ? this.parentName
          : parentName as String?,
      rootName: identical(rootName, $absent)
          ? this.rootName
          : rootName as String?,
    );
  }

  ParentModel merge([ParentModel? other]) {
    if (other == null) return this;
    return ParentModel(
      parentName: other.parentName ?? parentName,
      rootName: other.rootName ?? rootName,
    );
  }

  List<Object?> get _props => [parentName];
}

extension ChildModelExt on ChildModel {
  ChildModel copyWith({
    Object? childName,
    Object? parentName = $absent,
    Object? rootName = $absent,
  }) {
    return ChildModel(
      childName: childName == null ? this.childName : childName as String,
      parentName: identical(parentName, $absent)
          ? this.parentName
          : parentName as String?,
      rootName: identical(rootName, $absent)
          ? this.rootName
          : rootName as String?,
    );
  }

  ChildModel merge([ChildModel? other]) {
    if (other == null) return this;
    return ChildModel(
      childName: other.childName,
      parentName: other.parentName ?? parentName,
      rootName: other.rootName ?? rootName,
    );
  }

  List<Object?> get _props => [childName];
}

extension ChildModel2Ext on ChildModel2 {
  ChildModel2 copyWith({Object? childName = $absent}) {
    return ChildModel2(
      childName: identical(childName, $absent)
          ? this.childName
          : childName as String?,
    );
  }

  ChildModel2 merge([ChildModel2? other]) {
    if (other == null) return this;
    return ChildModel2(childName: other.childName ?? childName);
  }
}
