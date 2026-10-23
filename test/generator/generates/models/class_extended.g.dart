// GENERATED CODE - DO NOT MODIFY BY HAND

part of '../../models/class_extended.dart';

// **************************************************************************
// ElModelGenerator
// **************************************************************************

extension RootModelExt on RootModel {
  RootModel copyWith({Object? rootName = $elAbsent}) {
    return RootModel(
      rootName: identical(rootName, $elAbsent)
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
    Object? parentName = $elAbsent,
    Object? rootName = $elAbsent,
  }) {
    return ParentModel(
      parentName: identical(parentName, $elAbsent)
          ? this.parentName
          : parentName as String?,
      rootName: identical(rootName, $elAbsent)
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
    Object? parentName = $elAbsent,
    Object? rootName = $elAbsent,
  }) {
    return ChildModel(
      childName: childName == null ? this.childName : childName as String,
      parentName: identical(parentName, $elAbsent)
          ? this.parentName
          : parentName as String?,
      rootName: identical(rootName, $elAbsent)
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
  ChildModel2 copyWith({Object? childName = $elAbsent}) {
    return ChildModel2(
      childName: identical(childName, $elAbsent)
          ? this.childName
          : childName as String?,
    );
  }

  ChildModel2 merge([ChildModel2? other]) {
    if (other == null) return this;
    return ChildModel2(childName: other.childName ?? childName);
  }
}
