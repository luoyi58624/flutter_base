// GENERATED CODE - DO NOT MODIFY BY HAND

part of '../../models/comprehensive.dart';

// **************************************************************************
// ElModelGenerator
// **************************************************************************

extension AllFeaturesModelExt on AllFeaturesModel {
  static const AllFeaturesModel defaultModel = AllFeaturesModel(
    withJsonKey: '',
    withDefault: 42,
    nullableWithDefault: "fallback",
    normalString: '',
    normalInt: 0,
    normalDouble: 0.0,
    normalBool: false,
    stringList: [],
    intSet: {},
    normalMap: {},
  );

  static AllFeaturesModel fromJsonAllFeaturesModel(Map<String, dynamic>? json) {
    if (json == null) return defaultModel;
    return AllFeaturesModel(
      withJsonKey: $ElJsonUtil.$string(json, "custom_key", "custom_key") ?? '',
      withDefault: $ElJsonUtil.$int(json, "withDefault", "with_default") ?? 42,
      nullableWithDefault:
          $ElJsonUtil.$string(json, "nullable_key", "nullable_key") ??
          "fallback",
      normalString:
          $ElJsonUtil.$string(json, "normalString", "normal_string") ?? '',
      normalInt: $ElJsonUtil.$int(json, "normalInt", "normal_int") ?? 0,
      normalDouble:
          $ElJsonUtil.$double(json, "normalDouble", "normal_double") ?? 0.0,
      normalBool: $ElJsonUtil.$bool(json, "normalBool", "normal_bool") ?? false,
      stringList:
          $ElJsonUtil.$list<String>(json, "stringList", null, "string_list") ??
          [],
      intSet: $ElJsonUtil.$set<int>(json, "intSet", null, "int_set") ?? {},
      normalMap:
          $ElJsonUtil.$map<dynamic>(json, "normalMap", null, "normal_map") ??
          {},
    );
  }

  Map<String, dynamic> _toJson() {
    return {
      "custom_key": withJsonKey,
      "with_default": withDefault,
      "nullable_key": nullableWithDefault,
      "normal_string": normalString,
      "normal_int": normalInt,
      "normal_double": normalDouble,
      "normal_bool": normalBool,
      "string_list": stringList,
      "int_set": intSet.toList(),
      "normal_map": normalMap,
    };
  }

  AllFeaturesModel copyWith({
    Object? withJsonKey,
    Object? withDefault,
    Object? nullableWithDefault = $elAbsent,
    Object? normalString,
    Object? normalInt,
    Object? normalDouble,
    Object? normalBool,
    Object? stringList,
    Object? intSet,
    Object? normalMap,
  }) {
    return AllFeaturesModel(
      withJsonKey: withJsonKey == null
          ? this.withJsonKey
          : withJsonKey as String,
      withDefault: withDefault == null ? this.withDefault : withDefault as int,
      nullableWithDefault: identical(nullableWithDefault, $elAbsent)
          ? this.nullableWithDefault
          : nullableWithDefault as String?,
      normalString: normalString == null
          ? this.normalString
          : normalString as String,
      normalInt: normalInt == null ? this.normalInt : normalInt as int,
      normalDouble: normalDouble == null
          ? this.normalDouble
          : normalDouble as double,
      normalBool: normalBool == null ? this.normalBool : normalBool as bool,
      stringList: stringList == null
          ? this.stringList
          : stringList as List<String>,
      intSet: intSet == null ? this.intSet : intSet as Set<int>,
      normalMap: normalMap == null
          ? this.normalMap
          : normalMap as Map<String, dynamic>,
    );
  }

  AllFeaturesModel merge([AllFeaturesModel? other]) {
    if (other == null) return this;
    return AllFeaturesModel(
      withJsonKey: other.withJsonKey,
      withDefault: other.withDefault,
      nullableWithDefault: other.nullableWithDefault ?? nullableWithDefault,
      normalString: other.normalString,
      normalInt: other.normalInt,
      normalDouble: other.normalDouble,
      normalBool: other.normalBool,
      stringList: other.stringList,
      intSet: other.intSet,
      normalMap: other.normalMap,
    );
  }

  List<Object?> get _props => [
    withJsonKey,
    withDefault,
    nullableWithDefault,
    normalString,
    normalInt,
    normalDouble,
    normalBool,
    stringList,
    intSet,
    normalMap,
  ];
}

extension JsonOnlyModelExt on JsonOnlyModel {
  static const JsonOnlyModel defaultModel = JsonOnlyModel(name: '', age: 0);

  static JsonOnlyModel fromJson(Map<String, dynamic>? json) {
    if (json == null) return defaultModel;
    return JsonOnlyModel(
      name: $ElJsonUtil.$string(json, "name", "name") ?? '',
      age: $ElJsonUtil.$int(json, "age", "age") ?? 0,
    );
  }

  Map<String, dynamic> _toJson() {
    return {"name": name, "age": age};
  }

  List<Object?> get _props => [name, age];
}

extension CopyOnlyModelExt on CopyOnlyModel {
  CopyOnlyModel copyWith({Object? name, Object? age}) {
    return CopyOnlyModel(
      name: name == null ? this.name : name as String,
      age: age == null ? this.age : age as int,
    );
  }

  CopyOnlyModel merge([CopyOnlyModel? other]) {
    if (other == null) return this;
    return CopyOnlyModel(name: other.name, age: other.age);
  }

  List<Object?> get _props => [name, age];
}

extension MergeForcesCopyWithModelExt on MergeForcesCopyWithModel {
  static const MergeForcesCopyWithModel defaultModel = MergeForcesCopyWithModel(
    title: '',
  );

  static MergeForcesCopyWithModel fromJson(Map<String, dynamic>? json) {
    if (json == null) return defaultModel;
    return MergeForcesCopyWithModel(
      title: $ElJsonUtil.$string(json, "title", "title") ?? '',
    );
  }

  Map<String, dynamic> _toJson() {
    return {"title": title};
  }

  MergeForcesCopyWithModel copyWith({Object? title}) {
    return MergeForcesCopyWithModel(
      title: title == null ? this.title : title as String,
    );
  }

  MergeForcesCopyWithModel merge([MergeForcesCopyWithModel? other]) {
    if (other == null) return this;
    return MergeForcesCopyWithModel(title: other.title);
  }

  List<Object?> get _props => [title];
}

extension NoPropsModelExt on NoPropsModel {
  static const NoPropsModel defaultModel = NoPropsModel(value: '');

  static NoPropsModel fromJson(Map<String, dynamic>? json) {
    if (json == null) return defaultModel;
    return NoPropsModel(
      value: $ElJsonUtil.$string(json, "value", "value") ?? '',
    );
  }

  Map<String, dynamic> _toJson() {
    return {"value": value};
  }

  NoPropsModel copyWith({Object? value}) {
    return NoPropsModel(value: value == null ? this.value : value as String);
  }

  NoPropsModel merge([NoPropsModel? other]) {
    if (other == null) return this;
    return NoPropsModel(value: other.value);
  }
}

extension CustomSerializeModelExt on CustomSerializeModel {
  static const CustomSerializeModel defaultModel = CustomSerializeModel(
    name: '',
  );

  static CustomSerializeModel fromJson(Map<String, dynamic>? json) {
    if (json == null) return defaultModel;
    return CustomSerializeModel(
      dateField: $ElJsonUtil.$custom<DateTime?>(
        json,
        "dateField",
        (const ElDateTimeSerialize()),
        "date_field",
      ),
      durationField: $ElJsonUtil.$custom<Duration?>(
        json,
        "durationField",
        (const ElDurationSerialize()),
        "duration_field",
      ),
      dateList: $ElJsonUtil.$listCustom<DateTime>(
        json,
        "dateList",
        (const ElDateTimeSerialize()),
        "date_list",
      ),
      timeout:
          $ElJsonUtil.$custom<Duration>(
            json,
            "timeout",
            (const ElDurationSerialize()),
            "timeout",
          ) ??
          const Duration(seconds: 3),
      name: $ElJsonUtil.$string(json, "name", "name") ?? '',
    );
  }

  Map<String, dynamic> _toJson() {
    return {
      "dateField": (const ElDateTimeSerialize()).serialize(dateField),
      "durationField": (const ElDurationSerialize()).serialize(durationField),
      "dateList": dateList
          ?.map((e) => (const ElDateTimeSerialize()).serialize(e))
          .toList(),
      "timeout": (const ElDurationSerialize()).serialize(timeout),
      "name": name,
    };
  }

  CustomSerializeModel copyWith({
    Object? dateField = $elAbsent,
    Object? durationField = $elAbsent,
    Object? dateList = $elAbsent,
    Object? timeout,
    Object? name,
  }) {
    return CustomSerializeModel(
      dateField: identical(dateField, $elAbsent)
          ? this.dateField
          : dateField as DateTime?,
      durationField: identical(durationField, $elAbsent)
          ? this.durationField
          : durationField as Duration?,
      dateList: identical(dateList, $elAbsent)
          ? this.dateList
          : dateList as List<DateTime>?,
      timeout: timeout == null ? this.timeout : timeout as Duration,
      name: name == null ? this.name : name as String,
    );
  }

  CustomSerializeModel merge([CustomSerializeModel? other]) {
    if (other == null) return this;
    return CustomSerializeModel(
      dateField: other.dateField ?? dateField,
      durationField: other.durationField ?? durationField,
      dateList: other.dateList ?? dateList,
      timeout: other.timeout,
      name: other.name,
    );
  }

  List<Object?> get _props => [
    dateField,
    durationField,
    dateList,
    timeout,
    name,
  ];
}

extension MergeTargetModelExt on MergeTargetModel {
  MergeTargetModel copyWith({Object? label, Object? count}) {
    return MergeTargetModel(
      label: label == null ? this.label : label as String,
      count: count == null ? this.count : count as int,
    );
  }

  MergeTargetModel merge([MergeTargetModel? other]) {
    if (other == null) return this;
    return MergeTargetModel(label: other.label, count: other.count);
  }

  List<Object?> get _props => [label, count];
}

extension MergeHostModelExt on MergeHostModel {
  static const MergeHostModel defaultModel = MergeHostModel(
    forceMergeField: null,
    autoDetectMergeField: null,
    noMergeField: null,
    name: '',
  );

  static MergeHostModel fromJson(Map<String, dynamic>? json) {
    if (json == null) return defaultModel;
    return MergeHostModel(
      forceMergeField: json["forceMergeField"],
      autoDetectMergeField: json["autoDetectMergeField"],
      noMergeField: json["noMergeField"],
      name: $ElJsonUtil.$string(json, "name", "name") ?? '',
    );
  }

  Map<String, dynamic> _toJson() {
    return {
      "forceMergeField": forceMergeField,
      "autoDetectMergeField": autoDetectMergeField,
      "noMergeField": noMergeField,
      "name": name,
    };
  }

  MergeHostModel copyWith({
    Object? forceMergeField = $elAbsent,
    Object? autoDetectMergeField = $elAbsent,
    Object? noMergeField = $elAbsent,
    Object? name,
  }) {
    return MergeHostModel(
      forceMergeField: identical(forceMergeField, $elAbsent)
          ? this.forceMergeField
          : (forceMergeField == null
                ? null
                : (this.forceMergeField == null
                      ? forceMergeField as MergeTargetModel
                      : this.forceMergeField!.merge(
                          forceMergeField as MergeTargetModel,
                        ))),
      autoDetectMergeField: identical(autoDetectMergeField, $elAbsent)
          ? this.autoDetectMergeField
          : (autoDetectMergeField == null
                ? null
                : (this.autoDetectMergeField == null
                      ? autoDetectMergeField as MergeTargetModel
                      : this.autoDetectMergeField!.merge(
                          autoDetectMergeField as MergeTargetModel,
                        ))),
      noMergeField: identical(noMergeField, $elAbsent)
          ? this.noMergeField
          : noMergeField as MergeTargetModel?,
      name: name == null ? this.name : name as String,
    );
  }

  MergeHostModel merge([MergeHostModel? other]) {
    if (other == null) return this;
    return MergeHostModel(
      forceMergeField: forceMergeField == null
          ? other.forceMergeField
          : forceMergeField!.merge(other.forceMergeField),
      autoDetectMergeField: autoDetectMergeField == null
          ? other.autoDetectMergeField
          : autoDetectMergeField!.merge(other.autoDetectMergeField),
      noMergeField: other.noMergeField ?? noMergeField,
      name: other.name,
    );
  }

  List<Object?> get _props => [
    forceMergeField,
    autoDetectMergeField,
    noMergeField,
    name,
  ];
}

extension StaticMergeHostModelExt on StaticMergeHostModel {
  StaticMergeHostModel copyWith({
    Object? optional = $elAbsent,
    Object? required$,
  }) {
    return StaticMergeHostModel(
      optional: identical(optional, $elAbsent)
          ? this.optional
          : (optional == null
                ? null
                : (this.optional == null
                      ? optional as StaticMergeBox
                      : StaticMergeBox.merge(
                          this.optional!,
                          optional as StaticMergeBox,
                        ))),
      required$: required$ == null
          ? this.required$
          : StaticMergeBox.merge(this.required$, required$ as StaticMergeBox),
    );
  }

  StaticMergeHostModel merge([StaticMergeHostModel? other]) {
    if (other == null) return this;
    return StaticMergeHostModel(
      optional: optional == null
          ? other.optional
          : (other.optional == null
                ? optional
                : StaticMergeBox.merge(optional!, other.optional!)),
      required$: StaticMergeBox.merge(required$, other.required$),
    );
  }

  List<Object?> get _props => [optional, required$];
}

extension PropsParentModelExt on PropsParentModel {
  PropsParentModel copyWith({Object? parentField}) {
    return PropsParentModel(
      parentField: parentField == null
          ? this.parentField
          : parentField as String,
    );
  }

  PropsParentModel merge([PropsParentModel? other]) {
    if (other == null) return this;
    return PropsParentModel(parentField: other.parentField);
  }

  List<Object?> get _props => [parentField];
}

extension PropsChildModelExt on PropsChildModel {
  PropsChildModel copyWith({Object? childField, Object? parentField}) {
    return PropsChildModel(
      childField: childField == null ? this.childField : childField as String,
      parentField: parentField == null
          ? this.parentField
          : parentField as String,
    );
  }

  PropsChildModel merge([PropsChildModel? other]) {
    if (other == null) return this;
    return PropsChildModel(
      childField: other.childField,
      parentField: other.parentField,
    );
  }

  List<Object?> get _props => [childField];
}

extension NestedModelExt on NestedModel {
  static const NestedModel defaultModel = NestedModel(label: '');

  static NestedModel fromJson(Map<String, dynamic>? json) {
    if (json == null) return defaultModel;
    return NestedModel(
      label: $ElJsonUtil.$string(json, "label", "label") ?? '',
      child: $ElJsonUtil.$model<NestedModel?>(
        json,
        "child",
        NestedModelExt.defaultModel,
        "child",
      ),
    );
  }

  Map<String, dynamic> _toJson() {
    return {"label": label, "child": child?.toJson()};
  }

  NestedModel copyWith({Object? label, Object? child = $elAbsent}) {
    return NestedModel(
      label: label == null ? this.label : label as String,
      child: identical(child, $elAbsent)
          ? this.child
          : (child == null
                ? null
                : (this.child == null
                      ? child as NestedModel
                      : this.child!.merge(child as NestedModel))),
    );
  }

  NestedModel merge([NestedModel? other]) {
    if (other == null) return this;
    return NestedModel(
      label: other.label,
      child: child == null ? other.child : child!.merge(other.child),
    );
  }

  List<Object?> get _props => [label, child];
}
