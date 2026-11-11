import 'dart:typed_data';

import 'package:flutter_base/ui.dart';
import 'package:flutter_base/src/flutter/widgets/image/image_provider_resolver_stub.dart' as stub;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('web/stub 图片来源解析', () {
    test('asset 解析为 AssetImage provider', () {
      final provider = stub.imageProviderForSource('asset://assets/windows/icon.png');

      expect(provider, isA<AssetImage>());
      expect((provider as AssetImage).assetName, 'assets/windows/icon.png');
    });

    test('网络与本地样式路径继续回退浏览器 provider 管线', () {
      final network = stub.imageProviderForSource('https://example.com/image.png', headers: {'x-token': '1'});
      final local = stub.imageProviderForSource('images/local.png');

      expect(network, isA<NetworkImage>());
      expect((network as NetworkImage).url, 'https://example.com/image.png');
      expect(network.headers, {'x-token': '1'});
      expect(local, isA<NetworkImage>());
      expect((local as NetworkImage).url, 'images/local.png');
    });

    test('内存图片使用内存 provider', () {
      final bytes = Uint8List.fromList(<int>[1, 2, 3]);
      final view = ElImage.memory(bytes);

      expect(view.image, isA<MemoryImage>());
    });
  });
}
