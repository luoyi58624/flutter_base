import 'dart:convert';
import 'dart:io';

import 'package:flutter_base/src/flutter/views/image/image_disk_cache_io.dart';
import 'package:flutter_test/flutter_test.dart';

/// 磁盘缓存回归：本地 HttpServer 统计请求数。
void main() {
  late HttpServer server;
  late Directory cacheDir;
  late ImageDiskCache cache;
  var requestCount = 0;
  var cacheControl = '';

  setUp(() async {
    requestCount = 0;
    cacheControl = '';
    cacheDir = Directory.systemTemp.createTempSync('el_img_cache_test');
    cache = ImageDiskCache.instance..debugReset(dir: cacheDir);
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      requestCount++;
      final response = request.response;
      response.statusCode = HttpStatus.ok;
      if (cacheControl.isNotEmpty) response.headers.set(HttpHeaders.cacheControlHeader, cacheControl);
      response.add(utf8.encode('IMAGE_BYTES'));
      await response.close();
    });
  });

  tearDown(() async {
    await server.close(force: true);
    cache.debugReset();
    try {
      cacheDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  String url(String path) => 'http://${server.address.host}:${server.port}$path';

  /// 落盘是异步且不阻塞返回，等文件出现。
  Future<File?> waitForCached() async {
    for (var i = 0; i < 40; i++) {
      final files = cacheDir.listSync().whereType<File>().where((f) => f.path.endsWith('.bin')).toList();
      if (files.isNotEmpty) return files.single;
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
    return null;
  }

  test('有效期内直读磁盘：第二次 load 零网络请求', () async {
    final a = await cache.load(url('/a.png'));
    expect(a.length, 11);
    await waitForCached();
    final b = await cache.load(url('/a.png'));
    expect(b.length, 11);
    expect(requestCount, 1);
  });

  test('过期后重新下载', () async {
    await cache.load(url('/b.png'));
    final file = await waitForCached();
    file!.setLastModifiedSync(DateTime.now().subtract(ImageDiskCache.ttl + const Duration(hours: 1)));
    await cache.load(url('/b.png'));
    expect(requestCount, 2);
  });

  test('同 URL 并发请求共用一次下载', () async {
    final buffers = await Future.wait([
      cache.load(url('/c.png')),
      cache.load(url('/c.png')),
      cache.load(url('/c.png')),
    ]);
    expect(buffers.every((b) => b.length == 11), isTrue);
    expect(requestCount, 1);
  });

  test('no-store 不落盘', () async {
    cacheControl = 'no-store';
    await cache.load(url('/d.png'));
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(cacheDir.listSync().whereType<File>(), isEmpty);
  });

  test('网络失败回退过期缓存，没有缓存时抛错', () async {
    final target = url('/e.png');
    await cache.load(target);
    final file = await waitForCached();
    file!.setLastModifiedSync(DateTime.now().subtract(ImageDiskCache.ttl + const Duration(hours: 1)));
    await server.close(force: true);
    expect((await cache.load(target)).length, 11);
    await expectLater(cache.load(target.replaceFirst('/e.png', '/none.png')), throwsA(anything));
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  });
}
