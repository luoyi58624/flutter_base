// GENERATED CODE - DO NOT MODIFY BY HAND

part of '../../models/user.dart';

// **************************************************************************
// ElModelGenerator
// **************************************************************************

extension UserModelExt on UserModel {
  static const UserModel defaultModel = UserModel();

  static UserModel fromJson(Map<String, dynamic>? json) {
    if (json == null) return defaultModel;
    return UserModel(
      username: $ElJsonUtil.$string(json, "username", "username"),
      age: $ElJsonUtil.$int(json, "age", "age"),
      count: $ElJsonUtil.$int(json, "count", "count"),
      child: $ElJsonUtil.$model<UserModel?>(
        json,
        "child",
        UserModelExt.defaultModel,
        "child",
      ),
      children: $ElJsonUtil.$list<UserModel>(
        json,
        "children",
        UserModelExt.defaultModel,
        "children",
      ),
      animalMap: $ElJsonUtil.$map<AnimalModel>(
        json,
        "animalMap",
        AnimalModelExt.defaultModel,
        "animal_map",
      ),
      mapField: $ElJsonUtil.$map<dynamic>(json, "mapField", null, "map_field"),
      startDate: $ElJsonUtil.$custom<DateTime?>(
        json,
        "startDate",
        (const ElDateTimeSerialize()),
        "start_date",
      ),
      endDate: $ElJsonUtil.$custom<DateTime?>(
        json,
        "endDate",
        (const ElDateTimeSerialize()),
        "end_date",
      ),
      childName: $ElJsonUtil.$string(json, "childName", "child_name"),
    );
  }

  Map<String, dynamic> _toJson() {
    return {
      "username": username,
      "age": age,
      "count": count,
      "child": child?.toJson(),
      "children": children?.map((e) => e.toJson()).toList(),
      "animalMap": animalMap?.map(
        (key, value) => MapEntry(key, value.toJson()),
      ),
      "mapField": mapField,
      "startDate": (const ElDateTimeSerialize()).serialize(startDate),
      "endDate": (const ElDateTimeSerialize()).serialize(endDate),
      "childName": childName,
    };
  }

  UserModel copyWith({
    Object? username = $absent,
    Object? age = $absent,
    Object? count = $absent,
    Object? child = $absent,
    Object? children = $absent,
    Object? animalMap = $absent,
    Object? mapField = $absent,
    Object? startDate = $absent,
    Object? endDate = $absent,
    Object? childName = $absent,
  }) {
    return UserModel(
      username: identical(username, $absent)
          ? this.username
          : username as String?,
      age: identical(age, $absent) ? this.age : age as int?,
      count: identical(count, $absent) ? this.count : count as int?,
      child: identical(child, $absent)
          ? this.child
          : (child == null
                ? null
                : (this.child == null
                      ? child as UserModel
                      : this.child!.merge(child as UserModel))),
      children: identical(children, $absent)
          ? this.children
          : children as List<UserModel>?,
      animalMap: identical(animalMap, $absent)
          ? this.animalMap
          : animalMap as Map<String, AnimalModel>?,
      mapField: identical(mapField, $absent)
          ? this.mapField
          : mapField as Map<dynamic, dynamic>?,
      startDate: identical(startDate, $absent)
          ? this.startDate
          : startDate as DateTime?,
      endDate: identical(endDate, $absent)
          ? this.endDate
          : endDate as DateTime?,
      childName: identical(childName, $absent)
          ? this.childName
          : childName as String?,
    );
  }

  UserModel merge([UserModel? other]) {
    if (other == null) return this;
    return UserModel(
      username: other.username ?? username,
      age: other.age ?? age,
      count: other.count ?? count,
      child: child == null ? other.child : child!.merge(other.child),
      children: other.children ?? children,
      animalMap: other.animalMap ?? animalMap,
      mapField: other.mapField ?? mapField,
      startDate: other.startDate ?? startDate,
      endDate: other.endDate ?? endDate,
      childName: other.childName ?? childName,
    );
  }

  List<Object?> get _props => [
    username,
    age,
    count,
    child,
    children,
    animalMap,
    mapField,
    startDate,
    endDate,
  ];
}
