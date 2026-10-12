import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_base/dart.dart';
import 'package:flutter_test/flutter_test.dart';

import 'storage_test_support.dart';

void main() {
  final context = StorageTestContext();

  setUp(context.setUp);

  tearDown(context.tearDown);

  test('group codec 会编码本地快照并支持重新打开', () async {
    final codecGroup = ElStorageGroup(
      storagePath: context.root.path,
      key: 'codec_group',
      codec: _Base64Codec(),
    );
    addTearDown(codecGroup.closeAll);

    final storage = await codecGroup.open('secret', debounceTime: 0);
    storage.setItem('token', 'abc');

    final text = context.fileOfKey('secret', codecGroup).readAsStringSync();
    expect(text.contains('abc'), isFalse);
    expect((jsonDecode(text) as Map).containsKey('payload'), isTrue);

    codecGroup.close('secret');
    final reopened = await codecGroup.open('secret', debounceTime: 0);
    expect(reopened.getItem<String>('token'), 'abc');
  });

  test('storage codec 可以显式使用明文覆盖 group codec', () async {
    final codecGroup = ElStorageGroup(
      storagePath: context.root.path,
      key: 'codec_override',
      codec: _Base64Codec(),
    );
    addTearDown(codecGroup.closeAll);

    final storage = await codecGroup.open(
      'plain',
      debounceTime: 0,
      codec: ElCodec(),
    );
    storage.setItem('token', 'abc');

    expect(storage.codec.runtimeType, ElCodec);
    expect(context.readSnapshotData('plain', codecGroup), {'token': 'abc'});
  });

  test('打开编码快照时需要匹配的 codec', () async {
    final codecGroup = ElStorageGroup(
      storagePath: context.root.path,
      key: 'codec_error',
      codec: _Base64Codec(),
    );

    final storage = await codecGroup.open('secret', debounceTime: 0);
    storage.setItem('token', 'abc');
    codecGroup.closeAll();

    final wrongGroup = ElStorageGroup(
      storagePath: context.root.path,
      key: 'codec_error',
    );
    addTearDown(wrongGroup.closeAll);

    expect(
      wrongGroup.open('secret', debounceTime: 0),
      throwsA(isA<ElCodecException>()),
    );
  });
}

class _Base64Codec extends ElCodec {
  @override
  String encode(Uint8List bytes) => base64UrlEncode(bytes);

  @override
  Uint8List decode(String text) => base64Url.decode(text);
}
