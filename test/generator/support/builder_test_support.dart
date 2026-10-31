import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:test/test.dart';

final _packageSources = _loadPackageSources();

/// 在 Flutter 测试中改用同一 SDK 的 Dart VM 执行生成器测试。
bool runGeneratorTestsInDartVm(String testPath) {
  if (!Platform.resolvedExecutable.contains('flutter_tester')) return false;

  test('Dart VM 生成器测试：$testPath', () async {
    // build_runner 的解析器和 SDK summary 都需要普通 Dart isolate 的包配置。
    final configFile = File('.dart_tool/package_config.json').absolute;
    final config = jsonDecode(await configFile.readAsString()) as Map;
    final flutter = (config['packages'] as List).singleWhere(
      (package) => package['name'] == 'flutter',
    );
    final flutterPackage = Directory.fromUri(
      configFile.uri.resolve(flutter['rootUri'] as String),
    );
    final dart = File.fromUri(
      flutterPackage.parent.parent.uri.resolve(
        'bin/cache/dart-sdk/bin/dart${Platform.isWindows ? '.exe' : ''}',
      ),
    );
    final process = await Process.start(dart.path, [
      'test',
      testPath,
      '--concurrency=1',
      '--reporter=expanded',
    ]);
    final output = process.stdout.transform(utf8.decoder).join();
    final errors = process.stderr.transform(utf8.decoder).join();
    final exitCode = await process.exitCode.timeout(
      Duration(minutes: 2),
      onTimeout: () {
        process.kill();
        throw TimeoutException('Dart VM 生成器测试超过两分钟：$testPath');
      },
    );
    expect(exitCode, 0, reason: '${await output}\n${await errors}');
  }, timeout: Timeout(Duration(minutes: 3)));
  return true;
}

/// 复用真实依赖源码，并隔离测试包以免构建仓库内的其他模型。
Future<TestReaderWriter> createGeneratorReaderWriter() async {
  final readerWriter = TestReaderWriter(
    rootPackage: 'generator_test',
    flattenOutput: true,
  );
  (await _packageSources).forEach(readerWriter.testing.writeBytes);
  return readerWriter;
}

Future<Map<AssetId, List<int>>> _loadPackageSources() async {
  final readerWriter = TestReaderWriter();
  await readerWriter.testing.loadIsolateSources();
  return {
    for (final asset in readerWriter.testing.assets)
      asset: readerWriter.testing.readBytes(asset),
  };
}
