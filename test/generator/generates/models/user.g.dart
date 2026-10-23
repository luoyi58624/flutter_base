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
    Object? username = $elAbsent,
    Object? age = $elAbsent,
    Object? count = $elAbsent,
    Object? child = $elAbsent,
    Object? children = $elAbsent,
    Object? animalMap = $elAbsent,
    Object? mapField = $elAbsent,
    Object? startDate = $elAbsent,
    Object? endDate = $elAbsent,
    Object? childName = $elAbsent,
  }) {
    return UserModel(
      username: identical(username, $elAbsent)
          ? this.username
          : username as String?,
      age: identical(age, $elAbsent) ? this.age : age as int?,
      count: identical(count, $elAbsent) ? this.count : count as int?,
      child: identical(child, $elAbsent)
          ? this.child
          : (child == null
                ? null
                : (this.child == null
                      ? child as UserModel
                      : this.child!.merge(child as UserModel))),
      children: identical(children, $elAbsent)
          ? this.children
          : children as List<UserModel>?,
      animalMap: identical(animalMap, $elAbsent)
          ? this.animalMap
          : animalMap as Map<String, AnimalModel>?,
      mapField: identical(mapField, $elAbsent)
          ? this.mapField
          : mapField as Map<dynamic, dynamic>?,
      startDate: identical(startDate, $elAbsent)
          ? this.startDate
          : startDate as DateTime?,
      endDate: identical(endDate, $elAbsent)
          ? this.endDate
          : endDate as DateTime?,
      childName: identical(childName, $elAbsent)
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
