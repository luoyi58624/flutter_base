import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('事件运行时仅依赖 Flutter、既有识别器与具体 Render 宿主', () {
    final root = Directory('lib/src/ui/cores/event').absolute.uri;
    final files = Directory.fromUri(root)
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));
    for (final file in files) {
      final unit = parseString(content: file.readAsStringSync()).unit;
      for (final directive in unit.directives.whereType<UriBasedDirective>()) {
        for (final target in _targets(directive)) {
          if (target.startsWith('dart:') ||
              target.startsWith('package:flutter/') ||
              target == 'package:equatable/equatable.dart' ||
              target == 'package:meta/meta.dart' ||
              (file.absolute.uri == root.resolve('index.dart') &&
                  const {
                    '../view/render/index.dart',
                    '../view/style/index.dart',
                  }.contains(target)) ||
              (file.absolute.uri == root.resolve('dispatcher.dart') &&
                  target == '../view/render/index.dart') ||
              target == 'package:flutter_base/src/dart/gen/index.dart') {
            continue;
          }
          expect(Uri.parse(target).hasScheme, isFalse, reason: file.path);
          expect(
            file.absolute.uri
                .resolve(target)
                .toString()
                .startsWith(root.toString()),
            isTrue,
            reason: '${file.path} 不应导入模块外文件 $target',
          );
        }
      }
    }
  });

  test('公共事件入口保留 Widget 与事件配置且不导出内部实现', () {
    final entry = File('lib/src/ui/cores/event/index.dart').readAsStringSync();
    expect(entry, contains('ElEventView'));
    expect(entry, contains('ElEventState'));
    expect(entry, contains('ElEventCallback'));
    expect(entry, contains('ElDragProxy'));
    final exports = parseString(content: entry).unit.directives
        .whereType<ExportDirective>()
        .expand(_targets);
    expect(exports, isNot(contains('render.dart')));
    expect(exports, isNot(contains('dispatcher.dart')));
    expect(exports.any((target) => target.contains('resampling/')), isFalse);
    final sources = Directory('lib/src/ui/cores/event')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .map(
          (file) =>
              parseString(content: file.readAsStringSync()).unit.toSource(),
        )
        .join('\n');
    expect(
      sources,
      isNot(
        matches(
          r'ElStyleContext|LayerProjectionBoundary|PointerFocusArbiter|'
          r'ElFocusReason|FocusNode|ElDragPointerLock|boundaryHandoff',
        ),
      ),
    );
  });

  test('Dispatcher 仅接受 Render 与事件配置且复用既有手势路由', () {
    final unit = parseString(
      content: File('lib/src/ui/cores/event/dispatcher.dart')
          .readAsStringSync(),
    ).unit;
    const allowedImports = {
      'dart:async',
      'package:flutter/foundation.dart',
      'package:flutter/gestures.dart',
      'package:flutter/painting.dart',
      'package:flutter/services.dart',
      'package:flutter/rendering.dart',
      '../view/render/index.dart',
      'event.dart',
      'recognizers/index.dart',
    };
    for (final target in unit.directives.whereType<UriBasedDirective>().expand(
      _targets,
    )) {
      expect(
        allowedImports,
        contains(target),
        reason: 'Dispatcher 只允许依赖具体 Render 与现有识别器：$target',
      );
    }
    final dispatcher = unit.declarations
        .whereType<ClassDeclaration>()
        .singleWhere(
          (declaration) =>
              declaration.namePart.typeName.lexeme == 'ElEventDispatcher',
        );
    final constructors = dispatcher.body.members
        .whereType<ConstructorDeclaration>()
        .toList();
    expect(constructors, hasLength(1));
    final parameters = constructors.single.parameters.parameters;
    expect(parameters, hasLength(2));
    expect(
      parameters.every((parameter) => parameter.isRequiredPositional),
      isTrue,
    );
    expect(File('lib/src/ui/cores/event/render.dart').existsSync(), isFalse);
    // AST 的源码不含注释，架构说明提及宿主类型不应被当作实际依赖。
    final source = unit.toSource();
    expect(
      source,
      isNot(
        matches(
          r'\b(?:Widget|BuildContext|ElRenderEvent|ElView|ElStyle|StyleEngine)\b',
        ),
      ),
    );
    expect(source, isNot(matches(r'\b(?:pointerRouter|gestureArena)\b')));
    expect(
      source,
      isNot(
        matches(
          r'\b(?:extends|implements|with)\s+\w*(?:GestureRecognizer|GestureArenaMember)\b',
        ),
      ),
    );
    expect(
      unit.declarations.whereType<EnumDeclaration>(),
      isEmpty,
      reason: '手势阶段与状态机由现有识别器负责',
    );
  });
}

Iterable<String> _targets(UriBasedDirective directive) sync* {
  yield directive.uri.stringValue!;
  if (directive is NamespaceDirective) {
    for (final configuration in directive.configurations) {
      yield configuration.uri.stringValue!;
    }
  }
}
