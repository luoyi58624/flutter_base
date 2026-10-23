import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('事件运行时仅依赖 Flutter、自身目录与模型生成声明', () {
    final root = Directory('lib/src/ui/cores/event').absolute.uri;
    final directives = RegExp(r'''(?:import|export|part)\s+(?!of\b)[^;]+;''');
    final strings = RegExp(r'''['"]([^'"]+)['"]''');
    final files = Directory.fromUri(root)
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));
    for (final file in files) {
      for (final directive in directives.allMatches(file.readAsStringSync())) {
        for (final match in strings.allMatches(directive.group(0)!)) {
          final target = match.group(1)!;
          if (target.startsWith('dart:') ||
              target.startsWith('package:flutter/') ||
              target == 'package:equatable/equatable.dart' ||
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

  test('公共事件入口仅导出使用者所需的 Widget 和事件配置', () {
    final entry = File('lib/src/ui/cores/event/index.dart').readAsStringSync();
    expect(entry, contains('ElEventView'));
    expect(entry, contains('ElEventState'));
    expect(entry, contains('ElEventCallback'));
    expect(entry, contains('ElDragProxy'));
    expect(entry, isNot(contains('render.dart')));
    expect(entry, isNot(contains('resampling/')));
    final sources = Directory('lib/src/ui/cores/event')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .map((file) => file.readAsStringSync())
        .join('\n');
    expect(
      sources,
      isNot(
        matches(
          r'ElStyle|ElView|LayerProjectionBoundary|PointerFocusArbiter|'
          r'ElFocusReason|FocusNode|ElDragPointerLock|boundaryHandoff',
        ),
      ),
    );
  });
}
