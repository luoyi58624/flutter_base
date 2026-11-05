import 'dart:typed_data';

import 'package:flutter_base/ui.dart';
import 'package:flutter_base/src/flutter/views/image/image_byte_source.dart';
import 'package:flutter_base/src/flutter/views/image/image_provider_resolver_stub.dart' as stub;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('web/stub 图片来源解析', () {
    test('asset 保留 AssetImage provider，但不进入两段式字节解码管线', () {
      final provider = stub.imageProviderForSource('asset://assets/windows/icon.png');

      expect(provider, isA<AssetImage>());
      expect((provider as AssetImage).assetName, 'assets/windows/icon.png');
      expect(stub.byteSourceForSource('asset://assets/windows/icon.png'), isNull);
      expect(stub.byteSourceForSource('assets/windows/icon.png'), isNull);
    });

    test('网络与本地样式路径继续回退浏览器 provider 管线', () {
      final network = stub.imageProviderForSource('https://example.com/image.png', headers: {'x-token': '1'});
      final local = stub.imageProviderForSource('images/local.png');

      expect(network, isA<NetworkImage>());
      expect((network as NetworkImage).url, 'https://example.com/image.png');
      expect(network.headers, {'x-token': '1'});
      expect(local, isA<NetworkImage>());
      expect((local as NetworkImage).url, 'images/local.png');
      expect(stub.byteSourceForSource('https://example.com/image.png'), isNull);
      expect(stub.byteSourceForSource('images/local.png'), isNull);
    });

    test('内存图片继续使用内存 provider 与字节源', () {
      final bytes = Uint8List.fromList(<int>[1, 2, 3]);
      final view = ElImageView.memory(bytes);

      expect(view.image, isA<MemoryImage>());
      expect(view.byteSource, isA<MemoryByteSource>());
    });
  });
}
