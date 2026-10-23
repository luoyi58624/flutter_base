import 'dart:convert';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';

import '../dart/gen/index.dart';

import 'package:source_gen/source_gen.dart';

/// 把 `@ElSourceGenerator` 标记类的原始声明生成为同步字符串 getter。
class ElSourceTextGenerator extends GeneratorForAnnotation<ElSourceGenerator> {
  @override
  Future<String> generate(LibraryReader library, BuildStep buildStep) async {
    final annotations = library.annotatedWith(typeChecker).toList();
    final names = <String>{};
    for (final annotated in annotations) {
      final name = annotated.annotation.read('name').stringValue;
      if (!_isValidIdentifier(name)) {
        throw InvalidGenerationSourceError(
          '`$name` 不是合法的 Dart 标识符。',
          element: annotated.element,
          todo: '请为 @ElSourceGenerator 提供合法且未重复的 getter 名称。',
        );
      }
      if (!names.add(name)) {
        throw InvalidGenerationSourceError(
          '同一 library 内重复生成了 `$name`。',
          element: annotated.element,
          todo: '请为每个 @ElSourceGenerator 使用不同的 getter 名称。',
        );
      }
    }
    return await super.generate(library, buildStep);
  }

  @override
  Future<String> generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) async {
    if (element is! ClassElement) {
      throw InvalidGenerationSourceError(
        '@ElSourceGenerator 只能标记类声明。',
        element: element,
      );
    }

    final node = await buildStep.resolver.astNodeFor(element.firstFragment);
    if (node is! ClassDeclaration) {
      throw InvalidGenerationSourceError(
        '无法读取 `${element.name}` 的类声明源码。',
        element: element,
      );
    }

    final asset = await buildStep.resolver.assetIdForElement(element);
    final contents = await buildStep.readAsString(asset);
    final start = node.firstTokenAfterCommentAndMetadata.offset;
    final source = contents.substring(start, node.end);
    final name = annotation.read('name').stringValue;
    return 'String get $name => ${_dartString(source)};';
  }
}

bool _isValidIdentifier(String name) {
  if (name.isEmpty) return false;
  final result = parseString(
    content: 'String get $name => "";',
    throwIfDiagnostics: false,
  );
  if (result.errors.isNotEmpty || result.unit.declarations.length != 1) {
    return false;
  }
  final declaration = result.unit.declarations.single;
  return declaration is FunctionDeclaration &&
      declaration.isGetter &&
      declaration.name.lexeme == name;
}

String _dartString(String value) => jsonEncode(value).replaceAll(r'$', r'\$');
