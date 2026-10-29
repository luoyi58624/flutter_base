import 'dart:convert';
import 'dart:io';

import 'package:flutter_base/src/ui/cores/image/image_disk_cache_io.dart';
import 'package:flutter_test/flutter_test.dart';

/// 磁盘 HTTP 缓存的浏览器语义回归：本地 HttpServer 数请求。
void main() {
  late HttpServer server;
  late Directory cacheDir;
  late ImageDiskCache cache;
  var requestCount = 0;
  var send304 = false;
  String cacheControl = 'max-age=3600';

  setUp(() async {
    requestCount = 0;
    send304 = false;
    cacheControl = 'max-age=3600';
    cacheDir = Directory.systemTemp.createTempSync('el_img_cache_test');
    cache = ImageDiskCache.instance..debugReset(dir: cacheDir);
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) {
      requestCount++;
      final response = request.response;
      if (send304 && request.headers.value(HttpHeaders.ifNoneMatchHeader) == '"v1"') {
        response.statusCode = HttpStatus.notModified;
        response.close();
        return;
      }
      response.statusCode = HttpStatus.ok;
      response.headers.set(HttpHeaders.cacheControlHeader, cacheControl);
      response.headers.set(HttpHeaders.etagHeader, '"v1"');
      response.add(utf8.encode('IMAGE_BYTES'));
      response.close();
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

  test('新鲜期直读磁盘：第二次 load 零网络请求', () async {
    final a = await cache.load(url('/a.png'));
    expect(utf8.decode(a), 'IMAGE_BYTES');
    expect(requestCount, 1);
    final b = await cache.load(url('/a.png'));
    expect(utf8.decode(b), 'IMAGE_BYTES');
    expect(requestCount, 1, reason: 'max-age 内直读磁盘，不发请求');
  });

  test('过期后条件请求：304 续用磁盘字节', () async {
    cacheControl = 'max-age=0'; // 立即过期
    await cache.load(url('/b.png'));
    expect(requestCount, 1);
    send304 = true;
    final again = await cache.load(url('/b.png'));
    expect(utf8.decode(again), 'IMAGE_BYTES');
    expect(requestCount, 2, reason: '过期后发条件请求（If-None-Match），304 续用');
  });

  test('no-store 不落盘：每次都真实请求', () async {
    cacheControl = 'no-store';
    await cache.load(url('/c.png'));
    await cache.load(url('/c.png'));
    expect(requestCount, 2, reason: 'no-store 禁止缓存');
  });

  test('网络失败回退 stale 缓存（浏览器离线行为）', () async {
    cacheControl = 'max-age=0';
    await cache.load(url('/d.png'));
    expect(requestCount, 1);
    final port = server.port;
    final host = server.address.host;
    await server.close(force: true);
    final stale = await cache.load('http://$host:$port/d.png');
    expect(utf8.decode(stale), 'IMAGE_BYTES', reason: '服务器不可达时返回 stale 缓存');
    // tearDown 会再 close 一次，重建避免报错。
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  });
}
