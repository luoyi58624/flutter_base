import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:build/build.dart';
import 'package:meta/meta.dart';

import '../dart/extensions/index.dart';

import 'package:source_gen/source_gen.dart';

import '../dart/gen/index.dart' as annotations;

import 'config.dart';
import 'utils.dart';

/// 按模型注解生成序列化、复制和合并扩展。
@immutable
class ElModelGenerator
    extends GeneratorForAnnotation<annotations.ElModelGenerator> {
  /// 每个构建器独立持有配置，避免多个 target 的后缀相互覆盖。
  const ElModelGenerator(this.config) : super(inPackage: 'flutter_base');

  /// 当前构建器独立持有的生成配置。
  final ModelTemplateConfig config;

  @override
  String generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) {
    if (element is! ClassElement) {
      throw InvalidGenerationSourceError(
        '@ElModelGenerator 只能标记类声明。',
        element: element,
      );
    }
    final classInfo = element;
    _validateModel(classInfo, annotation);
    final className = classInfo.name!;
    final isConstConstructor = MirrorUtils.getDefaultConstructor(classInfo)
        .isConst;
    final fields = MirrorUtils.getFieldsByConstructor(
      classInfo,
      visitSuper: true,
    );

    return '''
extension $className${config.extSuffix} on $className {
  ${_generateFromJson(classInfo, className, isConstConstructor, fields, annotation)}
  ${_generateToJson(classInfo, fields, annotation)}
  ${_generateCopyWith(classInfo, className, fields, annotation)}
  ${_generateMerge(classInfo, className, fields, annotation)}
  ${_generateProps(classInfo, annotation)}
}
''';
  }

  void _validateModel(ClassElement element, ConstantReader annotation) {
    if (element.isAbstract) {
      throw InvalidGenerationSourceError('抽象类不能直接构造模型实例。', element: element);
    }
    if (element.typeParameters.isNotEmpty) {
      throw InvalidGenerationSourceError(
        '暂不支持泛型模型，请为具体数据类型定义模型。',
        element: element,
      );
    }
    final constructor = MirrorUtils.getDefaultConstructor(element);
    final reconstruct =
        annotation.read('formJson').boolValue ||
        annotation.read('copyWith').boolValue ||
        annotation.read('merge').boolValue;
    for (final parameter in constructor.formalParameters) {
      if (reconstruct && parameter.isPositional) {
        throw InvalidGenerationSourceError(
          '模型重建暂不支持位置参数，请使用命名参数。',
          element: parameter,
        );
      }
      final field = MirrorUtils.getField(element, parameter, visitSuper: true);
      if (reconstruct && field == null) {
        throw InvalidGenerationSourceError(
          '构造参数 `${parameter.name}` 没有同名字段，无法重建模型。',
          element: parameter,
        );
      }
      if (field != null &&
          (annotation.read('formJson').boolValue ||
              annotation.read('toJson').boolValue)) {
        _validateJsonType(field.type, field);
      }
    }
  }

  void _validateJsonType(DartType type, FieldElement field) {
    if (type is! InterfaceType) return;
    if (type.isDartCoreMap) {
      final keyType = type.typeArguments.first;
      if (!(keyType is DynamicType || keyType.isDartCoreString) ||
          keyType.nullabilitySuffix == NullabilitySuffix.question) {
        throw InvalidGenerationSourceError(
          'JSON Map 的键必须是 String 或 dynamic，当前是 `${keyType.getDisplayString()}`。',
          element: field,
        );
      }
    }
    if (_isCollection(type)) {
      _validateJsonType(type.typeArguments.last, field);
    }
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
      final keyCode = dartStringLiteral(jsonKey);
      final underlineArg = ', ${dartStringLiteral(jsonKey.toUnderline)}';

      String valueContent;
      String? defaultModelValueContent;

      if (fieldType == 'String' || fieldType == 'String?') {
        valueContent = "\$ElJsonUtil.\$string(json, $keyCode$underlineArg)";
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
        valueContent = "\$ElJsonUtil.\$num(json, $keyCode$underlineArg)";
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
        valueContent = "\$ElJsonUtil.\$int(json, $keyCode$underlineArg)";
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
        valueContent = "\$ElJsonUtil.\$double(json, $keyCode$underlineArg)";
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
        valueContent = "\$ElJsonUtil.\$bool(json, $keyCode$underlineArg)";
        if (defaultValue != null) {
          valueContent = '$valueContent ?? $defaultValue';
          defaultModelValueContent = '$defaultValue';
        } else {
          if (fieldType == 'bool') {
            valueContent = '$valueContent ?? false';
            defaultModelValueContent = 'false';
          }
        }
      } else if (_hasNestedCollection(fieldInfo.type)) {
        final decoder = _decodeNestedValue(
          fieldInfo.type,
          'value',
          _getCustomSerialize(fieldInfo),
          config,
          checked: true,
        );
        final inputType = fieldInfo.type.isDartCoreMap
            ? 'Map'
            : (fieldInfo.type.isDartCoreList ? 'List' : 'Iterable');
        valueContent =
            '\$ElJsonUtil.\$decode<$fieldType>(json, $keyCode, '
            '(value) => value is $inputType ? $decoder : null$underlineArg)';
        if (defaultValue != null) {
          valueContent = '$valueContent ?? $defaultValue';
          defaultModelValueContent = '$defaultValue';
        } else if (!_isNullable(fieldInfo.type)) {
          final empty = fieldInfo.type.isDartCoreList ? '[]' : '{}';
          valueContent = '$valueContent ?? $empty';
          defaultModelValueContent = empty;
        }
      } else if (fieldInfo.type.isDartCoreList) {
        final itemType = _firstTypeArgument(fieldInfo);
        final defaultModel = _serializeModelDefaultForType(itemType, config);
        final serializeName = defaultModel == null
            ? _getCustomSerialize(fieldInfo)
            : null;
        if (serializeName != null) {
          // 元素级自定义序列化，例如 @ElDateTimeSerialize() List<DateTime>
          valueContent =
              "\$ElJsonUtil.\$listCustom<${itemType!.getDisplayString()}>(json, $keyCode, ($serializeName)$underlineArg)";
        } else {
          final defaultModelArg = defaultModel == null
              ? ', null'
              : ', $defaultModel';
          valueContent =
              "\$ElJsonUtil.\$list<${itemType!.getDisplayString()}>(json, $keyCode$defaultModelArg$underlineArg)";
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
        final defaultModel = _serializeModelDefaultForType(itemType, config);
        final serializeName = defaultModel == null
            ? _getCustomSerialize(fieldInfo)
            : null;
        if (serializeName != null) {
          valueContent =
              "\$ElJsonUtil.\$setCustom<${itemType!.getDisplayString()}>(json, $keyCode, ($serializeName)$underlineArg)";
        } else {
          final defaultModelArg = defaultModel == null
              ? ', null'
              : ', $defaultModel';
          valueContent =
              "\$ElJsonUtil.\$set<${itemType!.getDisplayString()}>(json, $keyCode$defaultModelArg$underlineArg)";
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
        final defaultModel = _serializeModelDefaultForType(valueType, config);
        final serializeName = defaultModel == null
            ? _getCustomSerialize(fieldInfo)
            : null;
        if (serializeName != null) {
          valueContent =
              "\$ElJsonUtil.\$mapCustom<${valueType!.getDisplayString()}>(json, $keyCode, ($serializeName)$underlineArg)";
        } else {
          final defaultModelArg = defaultModel == null
              ? ', null'
              : ', $defaultModel';
          valueContent =
              "\$ElJsonUtil.\$map<${valueType!.getDisplayString()}>(json, $keyCode$defaultModelArg$underlineArg)";
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
        final fieldClassName = (fieldInfo.type as InterfaceType).element.name!;
        final defaultModel = '$fieldClassName${config.extSuffix}.defaultModel';
        valueContent =
            "\$ElJsonUtil.\$model<$fieldType>(json, $keyCode, $defaultModel$underlineArg)";

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
          valueContent = "json[$keyCode]";
          defaultModelContent.write('$field: null,');
        } else {
          valueContent =
              "\$ElJsonUtil.\$custom<$fieldType>(json, $keyCode, ($serializeName)$underlineArg)";
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

      final key = dartStringLiteral(
        jsonKey ?? (toJsonUnderline ? field.toUnderline : field),
      );
      late String value;
      if (MirrorUtils.hasSerializeModel(fieldInfo.type.element)) {
        final suffix = fieldType.endsWith('?') ? '?' : '';
        value = '$field$suffix.toJson()';
      } else if (_hasNestedCollection(fieldInfo.type)) {
        value = _encodeNestedValue(
          fieldInfo.type,
          field,
          _getCustomSerialize(fieldInfo),
        );
      } else if (fieldInfo.type.isDartCoreList) {
        final itemType = _firstTypeArgument(fieldInfo);
        final suffix = fieldType.endsWith('?') ? '?' : '';
        if (_serializeModelDefaultForType(itemType, config) != null) {
          value = '$field$suffix.map((e) => e.toJson()).toList()';
        } else {
          final serializeName = _getCustomSerialize(fieldInfo);
          if (serializeName == null) {
            value = field;
          } else {
            // 自定义序列化作用于元素而不是整个集合
            value =
                '$field$suffix.map((e) => ($serializeName).serialize(e)).toList()';
          }
        }
      } else if (fieldInfo.type.isDartCoreSet) {
        final itemType = _firstTypeArgument(fieldInfo);
        final suffix = fieldType.endsWith('?') ? '?' : '';
        if (_serializeModelDefaultForType(itemType, config) != null) {
          value = '$field$suffix.map((e) => e.toJson()).toList()';
        } else {
          final serializeName = _getCustomSerialize(fieldInfo);
          if (serializeName == null) {
            // Set 不是 JSON 可编码类型，必须转 List，否则 jsonEncode 直接抛异常
            value = '$field$suffix.toList()';
          } else {
            value =
                '$field$suffix.map((e) => ($serializeName).serialize(e)).toList()';
          }
        }
      } else if (fieldInfo.type.isDartCoreMap) {
        final valueType = _mapValueTypeArgument(fieldInfo);
        final suffix = fieldType.endsWith('?') ? '?' : '';
        if (_serializeModelDefaultForType(valueType, config) != null) {
          value =
              '$field$suffix.map((key, value) => MapEntry(key, value.toJson()))';
        } else {
          final serializeName = _getCustomSerialize(fieldInfo);
          if (serializeName == null) {
            value = field;
          } else {
            value =
                '$field$suffix.map((key, value) => MapEntry(key, ($serializeName).serialize(value)))';
          }
        }
      } else {
        final serializeName = _getCustomSerialize(fieldInfo);
        if (serializeName == null) {
          value = field;
        } else {
          value = "($serializeName).serialize($field)";
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
String? _serializeModelDefaultForType(
  DartType? type,
  ModelTemplateConfig config,
) {
  if (type == null || !MirrorUtils.hasSerializeModel(type.element)) return null;
  final className = (type as InterfaceType).element.name!;
  return '$className${config.extSuffix}.defaultModel';
}

/// 保留序列化注解的完整构造表达式，包括参数、命名构造和导入前缀。
String? _getCustomSerialize(FieldElement fieldInfo) {
  for (final annotation in fieldInfo.metadata.annotations) {
    final type = annotation.computeConstantValue()?.type;
    if (type == null || !serializeChecker.isAssignableFromType(type)) continue;
    final source = annotation.toSource();
    final expression = source.startsWith('@') ? source.substring(1) : source;
    return annotation.element is ConstructorElement
        ? 'const $expression'
        : expression;
  }
  return null;
}

/// 类型判断使用 analyzer 的结构；字符串仅用于最终源码输出。
bool _isCollection(DartType type) =>
    type.isDartCoreList || type.isDartCoreSet || type.isDartCoreMap;

bool _isNullable(DartType type) =>
    type is DynamicType || type.nullabilitySuffix == NullabilitySuffix.question;

bool _hasNestedCollection(DartType type) =>
    type is InterfaceType &&
    _isCollection(type) &&
    _isCollection(type.typeArguments.last);

bool _usesCustomSerializer(DartType type, String? serializer) =>
    serializer != null &&
    !_isCollection(type) &&
    !MirrorUtils.hasSerializeModel(type.element);

/// 仅移除输出类型名最外层的可空标记，不破坏内层泛型的可空性。
String _nonNullableTypeCode(DartType type) {
  final code = type.getDisplayString();
  return code.endsWith('?') ? code.substring(0, code.length - 1) : code;
}

/// 嵌套集合按声明的类型逐层转换，避免 List.from/Map.from 只检查最外层。
String _decodeNestedValue(
  DartType type,
  String value,
  String? serializer,
  ModelTemplateConfig config, {
  bool checked = false,
}) {
  if (_usesCustomSerializer(type, serializer)) {
    return '\$ElJsonUtil.\$customValue(($serializer), $value)';
  }
  late String decoded;
  if (type is InterfaceType && _isCollection(type)) {
    final itemType = type.typeArguments.last;
    final itemCode = itemType.getDisplayString();
    final item = _decodeNestedValue(itemType, 'item', serializer, config);
    final custom = _usesCustomSerializer(itemType, serializer);
    if (type.isDartCoreMap) {
      final input = checked ? value : '($value as Map)';
      if (custom) {
        final entry = _decodeNestedValue(
          itemType,
          'entry.value',
          serializer,
          config,
        );
        decoded =
            '''
(() {
  final result = <String, $itemCode>{};
  for (final entry in $input.entries) {
    final decoded = $entry;
    if (decoded is $itemCode) {
      result[entry.key as String] = decoded;
    }
  }
  return result;
})()
''';
      } else {
        decoded =
            '$input.map<String, $itemCode>('
            '(key, item) => MapEntry(key as String, $item))';
      }
    } else {
      final input = type.isDartCoreList ? 'List' : 'Iterable';
      final receiver = checked ? value : '($value as $input)';
      final finish = type.isDartCoreList ? 'toList' : 'toSet';
      decoded = custom
          ? '$receiver.map((item) => $item).whereType<$itemCode>().$finish()'
          : '$receiver.map<$itemCode>((item) => $item).$finish()';
    }
  } else {
    final model = _serializeModelDefaultForType(type, config);
    if (model != null) {
      decoded =
          '$model.fromJson($value is Map '
          '? Map<String, dynamic>.from($value) : null)';
    } else {
      decoded = type is DynamicType
          ? value
          : '$value as ${_nonNullableTypeCode(type)}';
    }
  }
  return !checked && _isNullable(type)
      ? '($value == null ? null : $decoded)'
      : decoded;
}

/// 嵌套集合中的模型、自定义类型和 Set 也必须逐层转成 JSON 可编码值。
String _encodeNestedValue(DartType type, String value, String? serializer) {
  if (_usesCustomSerializer(type, serializer)) {
    return '($serializer).serialize($value)';
  }
  final receiver = _isNullable(type) ? '$value?' : value;
  if (type is InterfaceType && _isCollection(type)) {
    final item = _encodeNestedValue(
      type.typeArguments.last,
      'item',
      serializer,
    );
    return type.isDartCoreMap
        ? '$receiver.map((key, item) => MapEntry(key, $item))'
        : '$receiver.map((item) => $item).toList()';
  } else if (MirrorUtils.hasSerializeModel(type.element)) {
    return '$receiver.toJson()';
  } else {
    return value;
  }
}
