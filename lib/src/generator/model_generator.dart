import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:meta/meta.dart';

import '../dart/extensions/index.dart';

import 'package:source_gen/source_gen.dart';

import '../dart/gen/index.dart';

import 'config.dart';
import 'utils.dart';

@immutable
class ElModelGenerator extends GeneratorForAnnotation<ElModelGenerator> {
  @override
  generateForAnnotatedElement(element, annotation, buildStep) {
    final classInfo = element as ClassElement;
    final className = classInfo.name!;
    final isConstConstructor = MirrorUtils.getDefaultConstructor(classInfo)
        .isConst;
    final fields = MirrorUtils.getFieldsByConstructor(
      classInfo,
      visitSuper: true,
    );

    return '''
extension $className${ModelTemplateConfig.instance.extSuffix} on $className {
  ${_generateFromJson(classInfo, className, isConstConstructor, fields, annotation)}
  ${_generateToJson(classInfo, fields, annotation)}
  ${_generateCopyWith(classInfo, className, fields, annotation)}
  ${_generateMerge(classInfo, className, fields, annotation)}
  ${_generateProps(classInfo, annotation)}
}
''';
  }

  String _generateFromJson(
    ClassElement classInfo,
    String className,
    bool isConstConstructor,
    List<FieldElement> fields,
    ConstantReader annotation,
  ) {
    if (!annotation.read('formJson').boolValue) return '';

    final fromJsonDiff = annotation.read('fromJsonDiff').boolValue;
    final content = StringBuffer();
    final defaultModelContent = StringBuffer();

    for (final fieldInfo in fields) {
      final field = fieldInfo.name!;
      final fieldType = fieldInfo.type.toString();

      final fieldAnnotation = _tryGetFieldAnnotation(fieldInfo);
      final jsonKey =
          fieldAnnotation?.getField('jsonKey')?.toStringValue() ?? field;
      final defaultValue = fieldAnnotation != null
          ? _extractDefaultValue(fieldAnnotation, fieldInfo)
          : null;

      // 编译期算好驼峰 key 对应的下划线 key 直接写入生成代码，运行时不再做字符串转换
      final underlineArg = ", '${jsonKey.toUnderline}'";

      String valueContent;
      String? defaultModelValueContent;

      if (fieldType == 'String' || fieldType == 'String?') {
        valueContent = "\$ElJsonUtil.\$string(json, '$jsonKey'$underlineArg)";
        if (defaultValue != null) {
          valueContent = '$valueContent ?? $defaultValue';
          defaultModelValueContent = '$defaultValue';
        } else {
          if (fieldType == 'String') {
            valueContent = "$valueContent ?? ''";
            defaultModelValueContent = "''";
          }
        }
      } else if (fieldType == 'num' || fieldType == 'num?') {
        valueContent = "\$ElJsonUtil.\$num(json, '$jsonKey'$underlineArg)";
        if (defaultValue != null) {
          valueContent = '$valueContent ?? $defaultValue';
          defaultModelValueContent = '$defaultValue';
        } else {
          if (fieldType == 'num') {
            valueContent = '$valueContent ?? 0.0';
            defaultModelValueContent = '0.0';
          }
        }
      } else if (fieldType == 'int' || fieldType == 'int?') {
        valueContent = "\$ElJsonUtil.\$int(json, '$jsonKey'$underlineArg)";
        if (defaultValue != null) {
          valueContent = '$valueContent ?? $defaultValue';
          defaultModelValueContent = '$defaultValue';
        } else {
          if (fieldType == 'int') {
            valueContent = '$valueContent ?? 0';
            defaultModelValueContent = '0';
          }
        }
      } else if (fieldType == 'double' || fieldType == 'double?') {
        valueContent = "\$ElJsonUtil.\$double(json, '$jsonKey'$underlineArg)";
        if (defaultValue != null) {
          valueContent = '$valueContent ?? $defaultValue';
          defaultModelValueContent = '$defaultValue';
        } else {
          if (fieldType == 'double') {
            valueContent = '$valueContent ?? 0.0';
            defaultModelValueContent = '0.0';
          }
        }
      } else if (fieldType == 'bool' || fieldType == 'bool?') {
        valueContent = "\$ElJsonUtil.\$bool(json, '$jsonKey'$underlineArg)";
        if (defaultValue != null) {
          valueContent = '$valueContent ?? $defaultValue';
          defaultModelValueContent = '$defaultValue';
        } else {
          if (fieldType == 'bool') {
            valueContent = '$valueContent ?? false';
            defaultModelValueContent = 'false';
          }
        }
      } else if (fieldInfo.type.isDartCoreList) {
        final itemType = _firstTypeArgument(fieldInfo);
        final defaultModel = _serializeModelDefaultForType(itemType);
        final serializeName = defaultModel == null
            ? _getCustomSerialize(fieldInfo)
            : null;
        if (serializeName != null) {
          // 元素级自定义序列化，例如 @ElDateTimeSerialize() List<DateTime>
          valueContent =
              "\$ElJsonUtil.\$listCustom<${fieldType.getGenericType}>(json, '$jsonKey', const $serializeName()$underlineArg)";
        } else {
          final defaultModelArg = defaultModel == null
              ? ', null'
              : ', $defaultModel';
          valueContent =
              "\$ElJsonUtil.\$list<${fieldType.getGenericType}>(json, '$jsonKey'$defaultModelArg$underlineArg)";
        }
        if (defaultValue != null) {
          valueContent = '$valueContent ?? $defaultValue';
          defaultModelValueContent = '$defaultValue';
        } else {
          if (fieldType.endsWith('?') == false) {
            valueContent = '$valueContent ?? []';
            defaultModelValueContent = '[]';
          }
        }
      } else if (fieldInfo.type.isDartCoreSet) {
        final itemType = _firstTypeArgument(fieldInfo);
        final defaultModel = _serializeModelDefaultForType(itemType);
        final serializeName = defaultModel == null
            ? _getCustomSerialize(fieldInfo)
            : null;
        if (serializeName != null) {
          valueContent =
              "\$ElJsonUtil.\$setCustom<${fieldType.getGenericType}>(json, '$jsonKey', const $serializeName()$underlineArg)";
        } else {
          final defaultModelArg = defaultModel == null
              ? ', null'
              : ', $defaultModel';
          valueContent =
              "\$ElJsonUtil.\$set<${fieldType.getGenericType}>(json, '$jsonKey'$defaultModelArg$underlineArg)";
        }
        if (defaultValue != null) {
          valueContent = '$valueContent ?? $defaultValue';
          defaultModelValueContent = '$defaultValue';
        } else {
          if (fieldType.endsWith('?') == false) {
            valueContent = '$valueContent ?? {}';
            defaultModelValueContent = '{}';
          }
        }
      } else if (fieldInfo.type.isDartCoreMap) {
        final valueType = _mapValueTypeArgument(fieldInfo);
        final defaultModel = _serializeModelDefaultForType(valueType);
        final serializeName = defaultModel == null
            ? _getCustomSerialize(fieldInfo)
            : null;
        if (serializeName != null) {
          valueContent =
              "\$ElJsonUtil.\$mapCustom<${fieldType.getMapGenericType?.value}>(json, '$jsonKey', const $serializeName()$underlineArg)";
        } else {
          final defaultModelArg = defaultModel == null
              ? ', null'
              : ', $defaultModel';
          valueContent =
              "\$ElJsonUtil.\$map<${fieldType.getMapGenericType?.value}>(json, '$jsonKey'$defaultModelArg$underlineArg)";
        }
        if (defaultValue != null) {
          valueContent = '$valueContent ?? $defaultValue';
          defaultModelValueContent = '$defaultValue';
        } else {
          if (fieldType.endsWith('?') == false) {
            valueContent = '$valueContent ?? {}';
            defaultModelValueContent = '{}';
          }
        }
      } else if (MirrorUtils.hasSerializeModel(fieldInfo.type.element)) {
        final fieldClassName = fieldType.replaceAll(
          MirrorUtils.genericsRegExp,
          '',
        );
        final defaultModel =
            '$fieldClassName${ModelTemplateConfig.instance.extSuffix}.defaultModel';
        valueContent =
            "\$ElJsonUtil.\$model<$fieldType>(json, '$jsonKey', $defaultModel$underlineArg)";

        if (defaultValue != null) {
          valueContent = '$valueContent ?? $defaultValue';
          defaultModelValueContent = '$defaultValue';
        } else {
          if (fieldType.endsWith('?') == false) {
            valueContent = "$valueContent ?? $defaultModel";
            defaultModelValueContent = defaultModel;
          }
        }
      } else {
        final serializeName = _getCustomSerialize(fieldInfo);
        if (serializeName == null) {
          valueContent = "json['$jsonKey']";
          defaultModelContent.write('$field: null,');
        } else {
          valueContent =
              "\$ElJsonUtil.\$custom<$fieldType>(json, '$jsonKey', const $serializeName()$underlineArg)";
          if (fieldType.endsWith('?') == false) {
            // 非空自定义序列化字段：用构造函数参数的默认值兜底（defaultValue 注解无法
            // 还原 DateTime/Duration 等非核心类型的 const 对象，构造默认值是编译期现成的源码）
            final ctorDefault = _constructorDefaultCode(classInfo, field);
            if (ctorDefault == null) {
              throw ArgumentError(
                'fromJson Error: $fieldType $field 为自定义序列化类型，'
                '你必须添加可为空符号 ? 或为构造函数参数指定默认值',
              );
            }
            valueContent = '$valueContent ?? $ctorDefault';
            // defaultModel 省略该字段，由构造函数默认值填充
          }
        }
      }

      content.write('$field: $valueContent,\n');
      if (defaultModelValueContent != null) {
        defaultModelContent.write('$field: $defaultModelValueContent,\n');
      }
    }

    return '''
  static ${isConstConstructor ? 'const' : 'final'} $className defaultModel = $className(
    $defaultModelContent
  );

  static $className fromJson${fromJsonDiff ? className : ''}(Map<String, dynamic>? json) {
    if(json == null) return defaultModel;
    return $className(
      $content
    );
  }
''';
  }

  String _generateToJson(
    ClassElement classInfo,
    List<FieldElement> fields,
    ConstantReader annotation,
  ) {
    if (!annotation.read('toJson').boolValue) return '';

    final toJsonUnderline = annotation.read('toJsonUnderline').boolValue;
    final content = StringBuffer();

    for (final fieldInfo in fields) {
      final field = fieldInfo.name!;
      final fieldType = fieldInfo.type.toString();
      final jsonKey = _getJsonKey(fieldInfo);

      final key =
          "'${jsonKey ?? (toJsonUnderline ? field.toUnderline : field)}'";
      late String value;
      if (MirrorUtils.hasSerializeModel(fieldInfo.type.element)) {
        final suffix = fieldType.endsWith('?') ? '?' : '';
        value = '$field$suffix.toJson()';
      } else if (fieldInfo.type.isDartCoreList) {
        final itemType = _firstTypeArgument(fieldInfo);
        final suffix = fieldType.endsWith('?') ? '?' : '';
        if (_serializeModelDefaultForType(itemType) != null) {
          value = '$field$suffix.map((e) => e.toJson()).toList()';
        } else {
          final serializeName = _getCustomSerialize(fieldInfo);
          if (serializeName == null) {
            value = field;
          } else {
            // 自定义序列化作用于元素而不是整个集合
            value =
                '$field$suffix.map((e) => const $serializeName().serialize(e)).toList()';
          }
        }
      } else if (fieldInfo.type.isDartCoreSet) {
        final itemType = _firstTypeArgument(fieldInfo);
        final suffix = fieldType.endsWith('?') ? '?' : '';
        if (_serializeModelDefaultForType(itemType) != null) {
          value = '$field$suffix.map((e) => e.toJson()).toList()';
        } else {
          final serializeName = _getCustomSerialize(fieldInfo);
          if (serializeName == null) {
            // Set 不是 JSON 可编码类型，必须转 List，否则 jsonEncode 直接抛异常
            value = '$field$suffix.toList()';
          } else {
            value =
                '$field$suffix.map((e) => const $serializeName().serialize(e)).toList()';
          }
        }
      } else if (fieldInfo.type.isDartCoreMap) {
        final valueType = _mapValueTypeArgument(fieldInfo);
        final suffix = fieldType.endsWith('?') ? '?' : '';
        if (_serializeModelDefaultForType(valueType) != null) {
          value =
              '$field$suffix.map((key, value) => MapEntry(key, value.toJson()))';
        } else {
          final serializeName = _getCustomSerialize(fieldInfo);
          if (serializeName == null) {
            value = field;
          } else {
            value =
                '$field$suffix.map((key, value) => MapEntry(key, const $serializeName().serialize(value)))';
          }
        }
      } else {
        final serializeName = _getCustomSerialize(fieldInfo);
        if (serializeName == null) {
          value = field;
        } else {
          value = "const $serializeName().serialize($field)";
        }
      }
      content.write('$key: $value,\n');
    }

    return '''
  Map<String, dynamic> _toJson() {
    return {
      $content
    };
  }
''';
  }

  String _generateCopyWith(
    ClassElement classInfo,
    String className,
    List<FieldElement> fields,
    ConstantReader annotation,
  ) {
    if (!(annotation.read('copyWith').boolValue ||
        annotation.read('merge').boolValue)) {
      return '';
    }

    final copyWithArg = StringBuffer();
    final copyWithBody = StringBuffer();

    for (final fieldInfo in fields) {
      final fieldTypeStr = fieldInfo.type.toString();
      final field = fieldInfo.name!;

      final isDynamic = fieldTypeStr == 'dynamic';
      final isNullable = isDynamic || fieldTypeStr.endsWith('?');
      // 只剥离尾部的 ?，replaceAll 会误伤嵌套泛型的可空标记（List<int?> -> List<int>）
      final fieldTypeBase = fieldTypeStr.endsWith('?')
          ? fieldTypeStr.substring(0, fieldTypeStr.length - 1)
          : fieldTypeStr;

      // freezed 式三态哨兵：可空字段默认 $elAbsent，让 null 腾出来做合法负载
      // （显式传 null = 置空）；非空字段 null 本就不是合法值，直接兜哨兵位
      // （可选参数默认值即 null，显式写出会触发 avoid_init_to_null）。
      copyWithArg.write(
        isNullable ? 'Object? $field = \$elAbsent,\n' : 'Object? $field,\n',
      );

      // 参数退化为 Object? 后在消费点还原静态类型；dynamic 与 Object 系字段
      // 无需 cast（参数本就是 Object?，判空/哨兵分支后类型已就位，写出触发
      // unnecessary_cast）。
      // 可 merge 分支的 cast 均在 `$field == null` 判空之后，$field 已提升为
      // 非空 Object，cast 到非空类型不触发 cast_nullable_to_non_nullable。
      final keep = isNullable
          ? 'identical($field, \$elAbsent)'
          : '$field == null';
      final noCast = isDynamic || fieldTypeBase == 'Object';
      final castFull = noCast ? field : '$field as $fieldTypeStr';
      final castBase = noCast ? field : '$field as $fieldTypeBase';

      final mergeStyle = _resolveMergeStyle(fieldInfo);
      switch (mergeStyle) {
        case _MergeStyle.none:
          // 非空 + 无 cast(Object/dynamic):null 判定两臂就是裸名与 this.，
          // 归约成 ??(三元触发 prefer_if_null_operators)。
          if (!isNullable && noCast) {
            copyWithBody.write('$field: $field ?? this.$field,\n');
          } else {
            copyWithBody.write('$field: $keep ? this.$field : $castFull,\n');
          }
        case _MergeStyle.instance:
          if (isNullable) {
            copyWithBody.write(
              '$field: $keep ? this.$field : '
              '($field == null ? null : '
              '(this.$field == null ? $castBase : this.$field!.merge($castBase))),',
            );
          } else {
            copyWithBody.write(
              '$field: $keep ? this.$field : this.$field.merge($castBase),',
            );
          }
        case _MergeStyle.static:
          if (isNullable) {
            copyWithBody.write(
              '$field: $keep ? this.$field : '
              '($field == null ? null : '
              '(this.$field == null ? $castBase : $fieldTypeBase.merge(this.$field!, $castBase))),',
            );
          } else {
            copyWithBody.write(
              '$field: $keep ? this.$field : $fieldTypeBase.merge(this.$field, $castBase),',
            );
          }
        case _MergeStyle.mapUnion:
        case _MergeStyle.mapDeep:
          final helperArgs = mergeStyle == _MergeStyle.mapUnion
              ? ''
              : ', ${_mapDeepCallback(fieldInfo)}';
          final helper = mergeStyle == _MergeStyle.mapUnion
              ? r'$elMergeMap'
              : r'$elMergeMapDeep';
          if (isNullable) {
            copyWithBody.write(
              '$field: $keep ? this.$field : '
              '($field == null ? null : '
              '(this.$field == null ? $castBase : $helper(this.$field!, $castBase$helperArgs))),',
            );
          } else {
            copyWithBody.write(
              '$field: $keep ? this.$field : $helper(this.$field, $castBase$helperArgs),',
            );
          }
      }
    }

    return '''
  $className copyWith({
    $copyWithArg
  }) {
    return $className(
      $copyWithBody
    );
  }
''';
  }

  String _generateMerge(
    ClassElement classInfo,
    String className,
    List<FieldElement> fields,
    ConstantReader annotation,
  ) {
    if (!annotation.read('merge').boolValue) return '';

    // merge 不再经 copyWith 转发：copyWith 已改为三态哨兵语义（显式 null 置空），
    // 若继续转发 other 的 null 字段会被当成"置空"把声明合并链清场。此处独立
    // 生成直接构造调用，保持声明合并口径——other 侧 null = 未声明、保留本侧。
    final content = StringBuffer();
    for (final fieldInfo in fields) {
      final field = fieldInfo.name!;
      final fieldTypeStr = fieldInfo.type.toString();
      final isNullable =
          fieldTypeStr == 'dynamic' || fieldTypeStr.endsWith('?');
      final fieldTypeBase = fieldTypeStr.endsWith('?')
          ? fieldTypeStr.substring(0, fieldTypeStr.length - 1)
          : fieldTypeStr;

      final mergeStyle = _resolveMergeStyle(fieldInfo);
      // merge 体内无同名参数遮蔽，裸名即字段（this. 触发 unnecessary_this）；
      // 唯独字段名恰为 other 时与 merge 入参撞名，保留 this. 消歧。
      final self = field == 'other' ? 'this.$field' : field;
      switch (mergeStyle) {
        case _MergeStyle.none:
          // 非空字段 other 侧必有值直取，?? 是死代码（dead_null_aware_expression）
          content.write(
            isNullable
                ? '$field: other.$field ?? $self,\n'
                : '$field: other.$field,\n',
          );
        case _MergeStyle.instance:
          if (isNullable) {
            content.write(
              '$field: $self == null ? other.$field : $self!.merge(other.$field),\n',
            );
          } else {
            content.write('$field: $self.merge(other.$field),\n');
          }
        case _MergeStyle.static:
          if (isNullable) {
            content.write(
              '$field: $self == null '
              '? other.$field '
              ': (other.$field == null ? $self : $fieldTypeBase.merge($self!, other.$field!)),\n',
            );
          } else {
            content.write(
              '$field: $fieldTypeBase.merge($self, other.$field),\n',
            );
          }
        case _MergeStyle.mapUnion:
        case _MergeStyle.mapDeep:
          final helperArgs = mergeStyle == _MergeStyle.mapUnion
              ? ''
              : ', ${_mapDeepCallback(fieldInfo)}';
          final helper = mergeStyle == _MergeStyle.mapUnion
              ? r'$elMergeMap'
              : r'$elMergeMapDeep';
          if (isNullable) {
            content.write(
              '$field: $self == null '
              '? other.$field '
              ': (other.$field == null ? $self : $helper($self!, other.$field!$helperArgs)),\n',
            );
          } else {
            content.write('$field: $helper($self, other.$field$helperArgs),\n');
          }
      }
    }

    return '''
  $className merge([$className? other]) {
    if (other == null) return this;
    return $className(
      $content
    );
  }
''';
  }

  String _generateProps(ClassElement classInfo, ConstantReader annotation) {
    if (!annotation.read('generateProps').boolValue) return '';
    final fields = MirrorUtils.getFieldsByConstructor(classInfo);
    return '''
  List<Object?> get _props => [${fields.map((e) => e.name).join(',')}];
''';
  }
}

/// 获取构造函数参数声明的默认值源码，例如 `this.timeout = const Duration(seconds: 3)`
/// 返回 `const Duration(seconds: 3)`，找不到时返回 null
String? _constructorDefaultCode(ClassElement classInfo, String fieldName) {
  try {
    for (final param in MirrorUtils.getDefaultConstructor(
      classInfo,
    ).formalParameters) {
      if (param.name == fieldName) return param.defaultValueCode;
    }
  } catch (_) {}
  return null;
}

DartObject? _tryGetFieldAnnotation(FieldElement fieldInfo) {
  try {
    return MirrorUtils.getElFieldAnnotation(fieldChecker, fieldInfo);
  } catch (_) {
    return null;
  }
}

dynamic _extractDefaultValue(DartObject annotation, FieldElement fieldInfo) {
  try {
    final value = annotation.getField('defaultValue');
    if (value == null || value.isNull) return null;
    return MirrorUtils.deepGetFieldValue(
      ConstantReader(value),
      fieldInfo.type.element,
      true,
    );
  } catch (_) {
    return null;
  }
}

/// 获取当前字段配置的 jsonKey，如果为空则表示用户没有指定 jsonKey
String? _getJsonKey(FieldElement fieldInfo) {
  try {
    final annotation = MirrorUtils.getElFieldAnnotation(
      fieldChecker,
      fieldInfo,
    );
    if (annotation == null) return null;
    return annotation.getField('jsonKey')?.toStringValue();
  } catch (_) {
    return null;
  }
}

/// 字段类型的 merge 方法范式。
enum _MergeStyle {
  /// 没有 merge 或被 `useMerge: false` 显式禁用 —— 走 `field ?? this.field`。
  none,

  /// 实例方法 `a.merge(b)`，包括自定义类型和生成模型的合并方法。
  instance,

  /// 静态方法 `T.merge(a, b)` —— Flutter 标准类（[Border] / [BorderSide] 等）范式。
  static,

  /// Map + `useMerge: true`，value 无 merge 能力 —— 逐 key 并集（后表同名 key 覆前表）。
  mapUnion,

  /// Map + `useMerge: true`，value 可 merge —— key 并集 + 同 key 值深合并。
  mapDeep,
}

/// 通过反射判断字段类型应使用哪种 merge 调用方式。
///
/// 判定顺序：
/// 1. Map 字段：`useMerge: true` → 按 value 类型分派 [mapUnion] / [mapDeep]，
///    否则 [none]（整体替换）
/// 2. List / Set 字段：`useMerge: true` → 编译期报错（CSS 单条声明语义即整体
///    替换，不给拼接语义留口子）；此判定在 try 之外，不许被 catch 吞成 none
/// 3. `@ElFieldGenerator(useMerge: false)` → 强制 [none]
/// 4. 对象字段按 [_resolveMergeStyleForType] 反射类能力
/// 5. `@ElFieldGenerator(useMerge: true)` 但反射不到任何 merge → 信用户声明，回退 [instance]
_MergeStyle _resolveMergeStyle(FieldElement fieldInfo) {
  final useMerge = _tryGetFieldAnnotation(fieldInfo)
      ?.getField('useMerge')
      ?.toBoolValue();

  if (fieldInfo.type.isDartCoreMap) {
    if (useMerge != true) return _MergeStyle.none;
    return _resolveMergeStyleForType(
              _mapValueTypeArgument(fieldInfo)?.element,
            ) ==
            _MergeStyle.none
        ? _MergeStyle.mapUnion
        : _MergeStyle.mapDeep;
  }
  if ((fieldInfo.type.isDartCoreList || fieldInfo.type.isDartCoreSet) &&
      useMerge == true) {
    throw ArgumentError(
      '${fieldInfo.name}: List/Set 字段不支持 useMerge——集合按 CSS 单条声明语义整体替换，请移除该注解',
    );
  }

  try {
    if (useMerge == false) return _MergeStyle.none;
    final style = _resolveMergeStyleForType(fieldInfo.type.element);
    if (style == _MergeStyle.none) {
      return useMerge == true ? _MergeStyle.instance : _MergeStyle.none;
    }
    return style;
  } catch (_) {
    return _MergeStyle.none;
  }
}

/// 反射类元素自身的 merge 能力（与字段注解无关）：
///
/// 1. 类带 `@ElModelGenerator(merge: true)` → [_MergeStyle.instance]（generator 必生成实例 merge）
/// 2. 类上存在非静态 merge 方法 → [_MergeStyle.instance]
/// 3. 类上仅存在 `static T merge(T, T)` 形态的静态方法 → [_MergeStyle.static]
/// 4. 都不满足 → [_MergeStyle.none]
_MergeStyle _resolveMergeStyleForType(Element? classElement) {
  try {
    if (classElement is! ClassElement) return _MergeStyle.none;

    final classAnnotation = MirrorUtils.getElFieldAnnotation(
      modelChecker,
      classElement,
    );
    if (classAnnotation?.getField('merge')?.toBoolValue() == true) {
      return _MergeStyle.instance;
    }

    final mergeMethods = classElement.methods
        .where((m) => m.name == 'merge')
        .toList();
    if (mergeMethods.isEmpty) return _MergeStyle.none;

    if (mergeMethods.any((m) => !m.isStatic)) {
      return _MergeStyle.instance;
    }

    // 仅剩静态方法：要求 `static T merge(T, T)` 两参签名才认。
    if (mergeMethods.any((m) => m.isStatic && m.formalParameters.length == 2)) {
      return _MergeStyle.static;
    }

    return _MergeStyle.none;
  } catch (_) {
    return _MergeStyle.none;
  }
}

/// [_MergeStyle.mapDeep] 的 value 合并回调源码：value 类型带实例 merge 用
/// 闭包，仅有静态 merge 用 `T.merge` tear-off。
String _mapDeepCallback(FieldElement fieldInfo) {
  final valueType = _mapValueTypeArgument(fieldInfo);
  if (_resolveMergeStyleForType(valueType?.element) == _MergeStyle.static) {
    final typeStr = valueType.toString();
    return typeStr.endsWith('?')
        ? '${typeStr.substring(0, typeStr.length - 1)}.merge'
        : '$typeStr.merge';
  }
  return '(a, b) => a.merge(b)';
}

/// 获取 List/Set 的元素类型。
DartType? _firstTypeArgument(FieldElement fieldInfo) {
  final type = fieldInfo.type;
  if (type is InterfaceType && type.typeArguments.isNotEmpty) {
    return type.typeArguments.first;
  }
  return null;
}

/// 获取 Map 的 value 类型。
DartType? _mapValueTypeArgument(FieldElement fieldInfo) {
  final type = fieldInfo.type;
  if (type is InterfaceType && type.typeArguments.length >= 2) {
    return type.typeArguments[1];
  }
  return null;
}

/// 如果类型实现了 ElSerializeModel，返回其生成扩展上的 defaultModel 引用。
String? _serializeModelDefaultForType(DartType? type) {
  if (type == null || !MirrorUtils.hasSerializeModel(type.element)) return null;
  final className = type.toString().replaceAll(MirrorUtils.genericsRegExp, '');
  return '$className${ModelTemplateConfig.instance.extSuffix}.defaultModel';
}

/// 获取自定义序列化的注解名字
String? _getCustomSerialize(FieldElement fieldInfo) {
  if (fieldInfo.metadata.annotations.isEmpty) return null;

  for (final meta in fieldInfo.metadata.annotations) {
    final element = meta.element;
    if (element is ConstructorElement) {
      final flag = element.enclosingElement.allSupertypes.any(
        (e) => e.toString().contains(
          '$ElSerialize'.replaceAll(MirrorUtils.genericsRegExp, ''),
        ),
      );
      if (flag) return element.displayName;
    }
  }
  return null;
}
