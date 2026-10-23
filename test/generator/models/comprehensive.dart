import 'package:equatable/equatable.dart';
import 'package:flutter_base/dart.dart';

part '../generates/models/comprehensive.g.dart';

// ========================================================================
// 1. @all 全部功能 + fromJsonDiff/toJsonUnderline + 所有字段注解
// ========================================================================

@ElModelGenerator.all(fromJsonDiff: true, toJsonUnderline: true)
class AllFeaturesModel
    with Equatable
    implements ElSerializeModel<AllFeaturesModel> {
  @ElFieldGenerator(jsonKey: 'custom_key')
  final String withJsonKey;

  @ElFieldGenerator(defaultValue: 42)
  final int withDefault;

  @ElFieldGenerator(jsonKey: 'nullable_key', defaultValue: 'fallback')
  final String? nullableWithDefault;

  final String normalString;
  final int normalInt;
  final double normalDouble;
  final bool normalBool;
  final List<String> stringList;
  final Set<int> intSet;
  final Map<String, dynamic> normalMap;

  const AllFeaturesModel({
    required this.withJsonKey,
    required this.withDefault,
    this.nullableWithDefault,
    required this.normalString,
    required this.normalInt,
    required this.normalDouble,
    required this.normalBool,
    required this.stringList,
    required this.intSet,
    required this.normalMap,
  });

  @override
  AllFeaturesModel fromJson(Map<String, dynamic>? json) =>
      AllFeaturesModelExt.fromJsonAllFeaturesModel(json);

  @override
  Map<String, dynamic> toJson() => _toJson();

  @override
  List<Object?> get props => _props;
}

// ========================================================================
// 2. @json 预设 — 仅生成 fromJson + toJson + props，无 copyWith/merge
// ========================================================================

@ElModelGenerator.json()
class JsonOnlyModel with Equatable implements ElSerializeModel<JsonOnlyModel> {
  final String name;
  final int age;

  const JsonOnlyModel({required this.name, required this.age});

  @override
  JsonOnlyModel fromJson(Map<String, dynamic>? json) =>
      JsonOnlyModelExt.fromJson(json);

  @override
  Map<String, dynamic> toJson() => _toJson();

  @override
  List<Object?> get props => _props;
}

// ========================================================================
// 3. @copy 预设 — 仅生成 copyWith + merge + props，无 fromJson/toJson
// ========================================================================

@ElModelGenerator.copy()
class CopyOnlyModel with Equatable {
  final String name;
  final int age;

  const CopyOnlyModel({required this.name, required this.age});

  @override
  List<Object?> get props => _props;
}

// ========================================================================
// 4. 自定义组合 — fromJson + toJson + merge (merge 强制 copyWith=true)
// ========================================================================

@ElModelGenerator(
  formJson: true,
  toJson: true,
  merge: true,
  generateProps: true,
)
class MergeForcesCopyWithModel
    with Equatable
    implements ElSerializeModel<MergeForcesCopyWithModel> {
  final String title;

  const MergeForcesCopyWithModel({required this.title});

  @override
  MergeForcesCopyWithModel fromJson(Map<String, dynamic>? json) =>
      MergeForcesCopyWithModelExt.fromJson(json);

  @override
  Map<String, dynamic> toJson() => _toJson();

  @override
  List<Object?> get props => _props;
}

// ========================================================================
// 5. generateProps: false — 不生成 _props
// ========================================================================

@ElModelGenerator.all(generateProps: false)
class NoPropsModel implements ElSerializeModel<NoPropsModel> {
  final String value;

  const NoPropsModel({required this.value});

  @override
  NoPropsModel fromJson(Map<String, dynamic>? json) =>
      NoPropsModelExt.fromJson(json);

  @override
  Map<String, dynamic> toJson() => _toJson();
}

// ========================================================================
// 6. Custom 序列化类型 (ElDateTimeSerialize / ElDurationSerialize)
// ========================================================================

@ElModelGenerator.all()
class CustomSerializeModel
    with Equatable
    implements ElSerializeModel<CustomSerializeModel> {
  @ElDateTimeSerialize()
  final DateTime? dateField;

  @ElDurationSerialize()
  final Duration? durationField;

  /// 集合元素级自定义序列化
  @ElDateTimeSerialize()
  final List<DateTime>? dateList;

  /// 非空自定义序列化字段：构造函数默认值会被生成器用作 fromJson 兜底
  @ElDurationSerialize()
  final Duration timeout;

  final String name;

  const CustomSerializeModel({
    this.dateField,
    this.durationField,
    this.dateList,
    this.timeout = const Duration(seconds: 3),
    required this.name,
  });

  @override
  CustomSerializeModel fromJson(Map<String, dynamic>? json) =>
      CustomSerializeModelExt.fromJson(json);

  @override
  Map<String, dynamic> toJson() => _toJson();

  @override
  List<Object?> get props => _props;
}

// ========================================================================
// 7. useMerge 控制 — 测试 ElFieldGenerator.useMerge
// ========================================================================

@ElModelGenerator.copy()
class MergeTargetModel with Equatable {
  final String label;
  final int count;

  const MergeTargetModel({required this.label, required this.count});

  @override
  List<Object?> get props => _props;
}

@ElModelGenerator.all()
class MergeHostModel
    with Equatable
    implements ElSerializeModel<MergeHostModel> {
  @ElFieldGenerator(useMerge: true)
  final MergeTargetModel? forceMergeField;

  /// 没有显式 useMerge，会通过反射检测 MergeTargetModel 是否有 merge 方法
  final MergeTargetModel? autoDetectMergeField;

  @ElFieldGenerator(useMerge: false)
  final MergeTargetModel? noMergeField;

  final String name;

  const MergeHostModel({
    this.forceMergeField,
    this.autoDetectMergeField,
    this.noMergeField,
    required this.name,
  });

  @override
  MergeHostModel fromJson(Map<String, dynamic>? json) =>
      MergeHostModelExt.fromJson(json);

  @override
  Map<String, dynamic> toJson() => _toJson();

  @override
  List<Object?> get props => _props;
}

// ========================================================================
// 7b. static merge 范式 — 仿 Flutter Border.merge(a, b) 静态合并
// ========================================================================

/// 仿 [Border.merge] 静态合并范式：`static T merge(T, T)`。
/// generator 应识别为 [static] 并生成 `T.merge(a, b)` 调用。
class StaticMergeBox {
  const StaticMergeBox({required this.tag, required this.weight});

  final String tag;
  final int weight;

  /// 静态合并：tag 取后者，weight 相加。
  static StaticMergeBox merge(StaticMergeBox a, StaticMergeBox b) {
    return StaticMergeBox(tag: b.tag, weight: a.weight + b.weight);
  }
}

@ElModelGenerator.copy()
class StaticMergeHostModel with Equatable {
  /// 可空：copyWith 时双向 null 守卫 + 静态合并。
  final StaticMergeBox? optional;

  /// 非空：copyWith 时直接 `T.merge(a, b)`。
  final StaticMergeBox required$;

  const StaticMergeHostModel({this.optional, required this.required$});

  @override
  List<Object?> get props => _props;
}

// ========================================================================
// 8. 继承链 — 验证子类 _props 不包含父类字段
// ========================================================================

@ElModelGenerator.copy(generateProps: true)
class PropsParentModel with Equatable {
  final String parentField;

  const PropsParentModel({required this.parentField});

  @override
  List<Object?> get props => _props;
}

@ElModelGenerator.copy(generateProps: true)
class PropsChildModel extends PropsParentModel {
  final String childField;

  const PropsChildModel({required this.childField, required super.parentField});

  @override
  List<Object?> get props => [...super.props, ..._props];
}

// ========================================================================
// 9. 嵌套序列化模型 fromJson / toJson
// ========================================================================

@ElModelGenerator.all()
class NestedModel with Equatable implements ElSerializeModel<NestedModel> {
  final String label;
  final NestedModel? child;

  const NestedModel({required this.label, this.child});

  @override
  NestedModel fromJson(Map<String, dynamic>? json) =>
      NestedModelExt.fromJson(json);

  @override
  Map<String, dynamic> toJson() => _toJson();

  @override
  List<Object?> get props => _props;
}
