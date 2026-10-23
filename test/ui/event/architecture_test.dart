import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('事件模块仅依赖 Dart、Flutter 和自身目录', () {
    final root = Directory('lib/src/ui/event').absolute.uri;
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
              target.startsWith('package:flutter/')) {
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
    final entry = File('lib/src/ui/event/index.dart').readAsStringSync();
    expect(entry, contains('ElEventView'));
    expect(entry, contains('ElEventState'));
    expect(entry, contains('ElEventCallback'));
    expect(entry, contains('ElDragProxy'));
    expect(entry, isNot(contains('dispatcher.dart')));
    expect(entry, isNot(contains('resampling/')));
    final sources = Directory('lib/src/ui/event')
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
