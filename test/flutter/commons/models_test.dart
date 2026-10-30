import 'package:flutter_base/dart.dart';
import 'package:flutter_base/ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Model 测试', () {
    _modelTest();
  });
}

final class _MenuModel extends ElNestModel<_MenuModel> {
  _MenuModel({required super.key, super.children = const []});
}

void _modelTest() {
  test('ElNestModel 嵌套模型测试', () {
    var models = [
      _MenuModel(key: 'A'),
      _MenuModel(
        key: 'B',
        children: [
          _MenuModel(key: 'D', children: []),
          _MenuModel(key: 'E', children: []),
        ],
      ),
      _MenuModel(key: 'H'),
      _MenuModel(
        key: 'C',
        children: [
          _MenuModel(
            key: 'F',
            children: [_MenuModel(key: 'G', children: [])],
          ),
        ],
      ),
      _MenuModel(key: 'M'),
    ];

    List<String> findKey(String key) {
      return ElNestModel.findKeyPath(models, key).map((e) => e.key.toString()).toList();
    }

    expect(findKey('A').eq(['A']), true);
    expect(findKey('B').eq(['B']), true);
    expect(findKey('D').eq(['B', 'D']), true);
    expect(findKey('E').eq(['B', 'E']), true);
    expect(findKey('F').eq(['C', 'F']), true);
    expect(findKey('G').eq(['C', 'F', 'G']), true);
    expect(findKey('H').eq(['H']), true);
    expect(findKey('M').eq(['M']), true);

    List<String> findKey2(String key) {
      return ElNestModel.findKeyPath(models, key, inherit: true).map((e) => e.key.toString()).toList();
    }

    expect(findKey2('A').eq(['A']), true);
    expect(findKey2('B').eq(['B']), true);
    expect(findKey2('BD').eq(['B', 'D']), true);
    expect(findKey2('BE').eq(['B', 'E']), true);
    expect(findKey2('CF').eq(['C', 'F']), true);
    expect(findKey2('CFG').eq(['C', 'F', 'G']), true);
    expect(findKey2('H').eq(['H']), true);
    expect(findKey2('M').eq(['M']), true);

    List<String> findKey3(String key) {
      return ElNestModel.findKeyPath(models, key, inherit: true, splitChar: '/').map((e) => e.key.toString()).toList();
    }

    expect(findKey3('A').eq(['A']), true);
    expect(findKey3('B').eq(['B']), true);
    expect(findKey3('B/D').eq(['B', 'D']), true);
    expect(findKey3('B/E').eq(['B', 'E']), true);
    expect(findKey3('C/F').eq(['C', 'F']), true);
    expect(findKey3('C/F/G').eq(['C', 'F', 'G']), true);
    expect(findKey3('H').eq(['H']), true);
    expect(findKey3('M').eq(['M']), true);

    List<String> findKey4(String key) {
      return ElNestModel.findKeyPath(
        models,
        key,
        inherit: true,
        splitChar: ' -> ',
      ).map((e) => e.key.toString()).toList();
    }

    expect(findKey4('A').eq(['A']), true);
    expect(findKey4('B').eq(['B']), true);
    expect(findKey4('B -> D').eq(['B', 'D']), true);
    expect(findKey4('B -> E').eq(['B', 'E']), true);
    expect(findKey4('C -> F').eq(['C', 'F']), true);
    expect(findKey4('C -> F -> G').eq(['C', 'F', 'G']), true);
    expect(findKey4('H').eq(['H']), true);
    expect(findKey4('M').eq(['M']), true);
  });

  test('ElNestModel 地址模型拼接测试', () {
    var models = [
      _MenuModel(
        key: '/nest',
        children: [
          _MenuModel(key: '1'),
          _MenuModel(
            key: '2',
            children: [
              _MenuModel(key: '2-1'),
              _MenuModel(
                key: '2-2',
                children: [
                  _MenuModel(key: '2-2-1'),
                  _MenuModel(key: '2-2-2'),
                ],
              ),
            ],
          ),
        ],
      ),
    ];

    List<String> findKey(String key) {
      return ElNestModel.findKeyPath(models, key, inherit: true, splitChar: '/').map((e) => e.key.toString()).toList();
    }

    expect(findKey('/nest/1').eq(['/nest', '1']), true);
    expect(findKey('/nest/2').eq(['/nest', '2']), true);
    expect(findKey('/nest/2/2-1').eq(['/nest', '2', '2-1']), true);
    expect(findKey('/nest/2/2-2').eq(['/nest', '2', '2-2']), true);
    expect(findKey('/nest/2/2-2/2-2-1').eq(['/nest', '2', '2-2', '2-2-1']), true);
    expect(findKey('/nest/2/2-2/2-2-2').eq(['/nest', '2', '2-2', '2-2-2']), true);
  });
}
