import 'dart:convert';

import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:source_gen/source_gen.dart';

import '../dart/gen/index.dart';

const TypeChecker modelChecker = TypeChecker.typeNamed(
  ElModelGenerator,
  inPackage: 'flutter_base',
);
const TypeChecker fieldChecker = TypeChecker.typeNamed(
  ElFieldGenerator,
  inPackage: 'flutter_base',
);
const TypeChecker serializeModelChecker = TypeChecker.typeNamed(
  ElSerializeModel,
  inPackage: 'flutter_base',
);
const TypeChecker serializeChecker = TypeChecker.typeNamed(
  ElSerialize,
  inPackage: 'flutter_base',
);

/// 输出合法的 Dart 字符串字面量，避免引号、换行与插值字符改变生成代码。
String dartStringLiteral(String value) =>
    jsonEncode(value).replaceAll(r'$', r'\$');

/// 反射工具类
class MirrorUtils {
  MirrorUtils._();

  /// 获取元素上声明的注解对象
  static DartObject? getElFieldAnnotation(
    TypeChecker checker,
    Element element,
  ) {
    try {
      return checker.firstAnnotationOfExact(element, throwOnUnresolved: false);
    } catch (_) {
      return null;
    }
  }

  /// 获取 class 默认的构造方法
  static ConstructorElement getDefaultConstructor(ClassElement classElement) {
    final constructor = classElement.unnamedConstructor;
    if (constructor == null) {
      throw InvalidGenerationSourceError(
        '`${classElement.name}` 缺少无名构造，无法生成模型重建代码。',
        element: classElement,
      );
    }
    return constructor;
  }

  /// 获取 ClassElement 默认构造函数所包含的字段集合
  static List<FieldElement> getFieldsByConstructor(
    ClassElement classElement, {
    bool visitSuper = false, // 是否收集 super 父类的字段
  }) {
    List<FieldElement> result = [];
    final fields = MirrorUtils.getDefaultConstructor(classElement)
        .formalParameters;
    for (int i = 0; i < fields.length; i++) {
      final field = getField(classElement, fields[i], visitSuper: visitSuper);
      if (field != null) result.add(field);
    }
    return result;
  }

  /// 通过 ClassElement 访问字段信息
  static FieldElement? getField(
    ClassElement classElement,
    VariableElement varElement, {
    bool visitSuper = false, // 是否收集 super 父类的字段
  }) {
    if (varElement is FieldFormalParameterElement) {
      return classElement.getField(varElement.name!);
    } else {
      if (visitSuper) {
        if (varElement is SuperFormalParameterElement) {
          for (var s in classElement.allSupertypes) {
            final superClass = s.element as ClassElement;
            final field = superClass.getField(varElement.name!);
            if (field != null) return field;
          }
        }
      }
    }
    return classElement.getField(varElement.name!);
  }

  /// 字段过滤，实体类需要生成的字段代码不需要关心以下修饰符
  static bool _fieldFilter(FieldElement fieldInfo) {
    return !fieldInfo.isStatic &&
        !fieldInfo.isLate &&
        !fieldInfo.isConst &&
        (fieldInfo.isOriginDeclaration ||
            fieldInfo.isOriginDeclaringFormalParameter);
  }

  /// 过滤掉实体类中不需要生成的字段
  static List<FieldElement> filterFields(ClassElement classInfo) {
    return classInfo.fields.where((e) => MirrorUtils._fieldFilter(e)).toList();
  }

  /// 判断元素是否实现了 [ElSerializeModel] 序列化模型
  static bool hasSerializeModel(Element? element) {
    return element != null && serializeModelChecker.isAssignableFrom(element);
  }

  /// 使用递归深度遍历元素字段默认值
  static dynamic deepGetFieldValue(
    ConstantReader reader, [
    Element? element,
    bool? requireConst,
  ]) {
    if (reader.isNull) return null;

    if (element != null && hasSerializeModel(element)) {
      final classInfo = element as ClassElement;
      final fields = MirrorUtils.filterFields(classInfo);
      String content = '';
      for (var field in fields) {
        content +=
            "${field.name}: ${deepGetFieldValue(reader.read(field.name!), field.type.element, false)},";
      }
      content = "${classInfo.name}($content)";
      if (requireConst == true) {
        content = "const $content";
      }
      return content;
    }
    if (reader.isString) {
      return dartStringLiteral(reader.stringValue);
    }
    if (reader.isDouble || reader.isInt || reader.isBool) {
      return reader.literalValue;
    }
    if (reader.isList) {
      return (reader.listValue)
          .map(
            (e) => deepGetFieldValue(
              ConstantReader(e),
              e.type?.element,
              requireConst ?? true,
            ),
          )
          .toList();
    }
    if (reader.isSet) {
      return (reader.setValue)
          .map(
            (e) => deepGetFieldValue(
              ConstantReader(e),
              e.type?.element,
              requireConst ?? true,
            ),
          )
          .toSet();
    }
    if (reader.isMap) {
      return (reader.mapValue).map(
        (k, v) => MapEntry(
          deepGetFieldValue(ConstantReader(k), k?.type?.element),
          deepGetFieldValue(
            ConstantReader(v),
            v?.type?.element,
            requireConst ?? true,
          ),
        ),
      );
    }
    return null;
  }
}
