part of 'index.dart';

@Target({TargetKind.classType})
class ElModelGenerator {
  /// 生成通用的操作数据模型方法：json序列化、copyWith对象克隆等...
  ///
  /// 根据无名构造函数的命名参数收集字段，支持 this、super 和同名字段的初始化参数。
  /// 重建模型时不支持位置参数；泛型模型、抽象类和缺少无名构造的模型会在生成阶段报错。
  ///
  /// 提示：[fromJson] 是 [formJson]（历史拼写错误）的正确拼写，二者等价，推荐使用 [fromJson]
  const ElModelGenerator({
    bool? fromJson,
    bool formJson = false,
    this.toJson = false,
    this.copyWith = false,
    this.merge = false,
    this.generateProps = false,
    this.fromJsonDiff = false,
    this.toJsonUnderline = false,
  }) : formJson = fromJson ?? formJson;

  /// 默认开启所有功能
  const ElModelGenerator.all({
    this.formJson = true,
    this.toJson = true,
    this.copyWith = true,
    this.merge = true,
    this.generateProps = true,
    this.fromJsonDiff = false,
    this.toJsonUnderline = false,
  });

  /// 生成 formJson、toJson、equals、hashCode 方法
  const ElModelGenerator.json({
    this.formJson = true,
    this.toJson = true,
    this.copyWith = false,
    this.merge = false,
    this.generateProps = true,
    this.fromJsonDiff = false,
    this.toJsonUnderline = false,
  });

  /// 生成 copyWith、merge、equals、hashCode 方法
  const ElModelGenerator.copy({
    this.formJson = false,
    this.toJson = false,
    this.copyWith = true,
    this.merge = true,
    this.generateProps = true,
    this.fromJsonDiff = false,
    this.toJsonUnderline = false,
  });

  /// 生成 formJson 方法
  /// ```dart
  /// @override
  /// TestModel fromJson(Map<String, dynamic>? json) => _fromJson(json);
  /// ```
  final bool formJson;

  /// 生成 toJson 方法
  /// ```dart
  /// @override
  /// Map<String, dynamic> toJson() => _toJson();
  /// ```
  ///
  /// 提示：序列化类需要继承 [ElSerializeModel] 序列号模型接口，所以不能直接生成 toJson 而是生成 _toJson
  final bool toJson;

  /// 生成 copyWith 方法。
  ///
  /// 三态语义(freezed 式,哨兵见 `$absent`):不传参 = 保留原值;
  /// 显式传 null = 置空(非空字段除外,null 兜哨兵位等于不传);传值 = 覆盖
  /// (可 merge 的嵌套类型仍走深合并)。
  final bool copyWith;

  /// 生成 merge 方法，如果该属性为true，则[copyWith]强制为true。
  ///
  /// merge 是声明合并语义:other 侧字段为 null 表示"未声明、保留本侧",
  /// 与 copyWith 的显式 null 置空解耦(生成体不再经 copyWith 转发)。
  final bool merge;

  /// 是否生成 _props 集合，该属性需要配合 [Equatable] 混入类，
  /// 此类由 equatable 第三方包提供，其作用是用于比较两个对象的相等性。
  ///
  /// 注意：生成 _props 集合仅限当前类的字段，不生成 super 父类的字段，
  /// 你可以自行考虑是否合并 props 数组。
  final bool generateProps;

  /// 是否对生成的 fromJson 进行命名区分，
  /// 如果为 false，则直接生成 _fromJson 函数，
  /// 如果为 true，则会在后尾添加类名做区分。
  ///
  /// 如果你的一个文件有多个模型对象，那么请将此属性设置为 true，防止命名冲突
  final bool fromJsonDiff;

  /// 将对象转成 json 时，是否将驼峰命名的字段转成下划线，此属性默认为 false
  final bool toJsonUnderline;
}

@Target({TargetKind.field})
class ElFieldGenerator {
  /// 模型字段注解
  const ElFieldGenerator({this.jsonKey, this.defaultValue, this.useMerge});

  /// 序列化、反序列化时指定映射的 json key
  final String? jsonKey;

  /// 指定默认值，当反序列化时如果 json 没有目标参数、或者目标类型转换失败时将使用此默认值
  final dynamic defaultValue;

  /// 在生成 copyWith / merge 方法时，是否对目标字段应用 merge：
  ///
  /// - 对象字段：默认反射检测到类型提供 merge 方法时就自动应用，此开关用于强制开/关
  /// - Map 字段：标 true 后按集合语义合并——value 类型可 merge 时逐 key 深合并，
  ///   否则 key 并集（后表同名 key 覆前表，CSS custom properties 口径）；
  ///   默认（不标）整体替换
  /// - List / Set 字段：不支持（CSS 单条声明语义即整体替换），标 true 编译期报错
  final bool? useMerge;
}
