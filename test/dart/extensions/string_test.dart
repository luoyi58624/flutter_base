import 'package:flutter_base/dart.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('字符串扩展', () {
    test('首字母大小写与首尾字符删除保持其余字符', () {
      expect('hello'.firstUpperCase, 'Hello');
      expect('Hello'.firstLowerCase, 'hello');
      expect('A'.firstLowerCase, 'a');
      expect('abc'.removeFirstChar(), 'bc');
      expect('abc'.removeLastChar(), 'ab');
      expect('a'.removeFirstChar(), '');
      expect('a'.removeLastChar(), '');
      expect(''.removeFirstChar(), '');
      expect(''.removeLastChar(), '');
    });

    test('驼峰转换和首尾空白清理保持内部内容', () {
      expect('userName'.toUnderline, 'user_name');
      expect('userID'.toUnderline, 'user_id');
      expect('\t\n a  b \r\n'.clearFrontBackBlank, 'a  b');
      expect('\u00a0value\u00a0'.clearFrontBackBlank, 'value');
      expect(''.clearFrontBackBlank, '');
    });

    test('类型名称扩展保留简单泛型结构并识别无泛型名称', () {
      expect('List<int>?'.excludeGeneric, 'List');
      expect('UserModel<T>?'.excludeGeneric, 'UserModel');
      expect('List<List<int>>'.getGenericType, 'List<int>');
      expect('int'.getGenericType, isNull);
      expect('Map<String, int>'.getMapGenericType, (
        key: 'String',
        value: 'int',
      ));
      expect('Map<String>'.getMapGenericType, isNull);
      expect('Map'.getMapGenericType, isNull);
    });

    test('中文识别和插空格按 Unicode 码点处理代理对', () {
      expect('你好'.isTwoChineseCharacters, isTrue);
      expect('𠀀好'.isTwoChineseCharacters, isTrue);
      expect('你a'.isTwoChineseCharacters, isFalse);
      expect('你好呀'.isTwoChineseCharacters, isFalse);
      expect(''.isTwoChineseCharacters, isFalse);
      expect('𠀀好'.autoInsertSpace, '𠀀 好');
      expect('abc'.autoInsertSpace, 'abc');
      expect('A😀B'.insertSpaceBetweenChars, 'A 😀 B');
      expect(''.insertSpaceBetweenChars, '');
    });
  });
}
