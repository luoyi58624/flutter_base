import 'package:flutter_base/dart.dart';

import '../support/serializers.dart' as serializers;

part '../generates/models/boundaries.g.dart';

/// 转义后的 JSON 键。
const escapedKey = "user's\\key\$id\n下一行";

/// 转义后的字符串默认值。
const escapedDefault = "It's \\ready\n\$value";

/// 用于验证带参数的枚举序列化注解。
enum BoundaryStatus { ready, done }

/// 转义、默认值和自定义序列化的编译及运行样例。
@ElModelGenerator.all(generateProps: false)
class BoundaryModel implements ElSerializeModel<BoundaryModel> {
  /// 创建包含默认值的模型。
  const BoundaryModel({
    this.value = '',
    this.labels = const [],
    this.mapping = const {},
    this.status = BoundaryStatus.ready,
    this.duration = Duration.zero,
    this.statuses = const [],
  });

  /// 使用含特殊字符的键与默认值。
  @ElFieldGenerator(jsonKey: escapedKey, defaultValue: escapedDefault)
  final String value;

  /// 集合中的字符串默认值也需要转义。
  @ElFieldGenerator(defaultValue: [escapedDefault])
  final List<String> labels;

  /// Map 默认值的键和值都需要转义。
  @ElFieldGenerator(defaultValue: {escapedKey: escapedDefault})
  final Map<String, String> mapping;

  /// 枚举序列化器必须保留 values 参数。
  @ElEnumSerialize(BoundaryStatus.values)
  final BoundaryStatus status;

  /// 序列化器必须保留导入前缀和命名构造参数。
  @serializers.DurationUnits.units(scale: 10)
  final Duration duration;

  /// 可空集合元素保留反序列化失败的 null。
  @ElEnumSerialize(BoundaryStatus.values)
  final List<BoundaryStatus?> statuses;

  @override
  BoundaryModel fromJson(Map<String, dynamic>? json) =>
      BoundaryModelExt.fromJson(json);

  @override
  Map<String, dynamic> toJson() => _toJson();
}

/// 无名构造位于其他构造之后，生成器仍应正确选择。
@ElModelGenerator.all(generateProps: false)
class BoundaryLeaf implements ElSerializeModel<BoundaryLeaf> {
  /// 排在前面的命名构造。
  const BoundaryLeaf.other({int ignored = 0}) : name = '';

  /// 用于重建模型的无名构造。
  // 特意使用同名初始化参数，验证生成器不只识别 this.name。
  // ignore: prefer_initializing_formals
  const BoundaryLeaf({String name = ''}) : name = name;

  /// 叶子模型的名称。
  final String name;

  @override
  BoundaryLeaf fromJson(Map<String, dynamic>? json) =>
      BoundaryLeafExt.fromJson(json);

  @override
  Map<String, dynamic> toJson() => _toJson();
}

/// 验证多层集合、可空元素、模型和序列化器的递归编解码。
@ElModelGenerator.all(generateProps: false)
class NestedBoundaryModel implements ElSerializeModel<NestedBoundaryModel> {
  /// 创建嵌套集合模型。
  const NestedBoundaryModel({
    this.matrix = const {},
    this.rows = const [],
    this.leaves = const {},
    this.sets = const {},
    this.optionalRows,
    this.times = const {},
    this.strictTimes = const [],
  });

  /// Map 的 value 本身仍为 Map。
  final Map<String, Map<String, int>> matrix;

  /// 多层集合中保留叶子值的可空性。
  final List<Map<String, List<int?>>> rows;

  /// 嵌套模型与可空模型元素。
  final Map<String, List<BoundaryLeaf?>> leaves;

  /// Set 在 JSON 中应转换为数组。
  final Map<String, Set<int>> sets;

  /// 外层集合与内层集合均可为空。
  final List<List<int>?>? optionalRows;

  /// 自定义序列化器逐层应用于叶子值。
  @serializers.DurationUnits.units(scale: 10)
  final Map<String, List<Duration?>> times;

  /// 非空叶子类型跳过无法反序列化的值。
  @serializers.DurationUnits.units(scale: 10)
  final List<Map<String, Duration>> strictTimes;

  @override
  NestedBoundaryModel fromJson(Map<String, dynamic>? json) =>
      NestedBoundaryModelExt.fromJson(json);

  @override
  Map<String, dynamic> toJson() => _toJson();
}
