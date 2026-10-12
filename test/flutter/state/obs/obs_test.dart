import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Obs notify() 边缘行为', () {
    test('回调执行期间自移除不应抛异常', () {
      final obs = Obs(0);

      late VoidCallback cb;
      cb = () {
        // 模拟回调执行期间解绑自己（例如触发卸载/清理）
        obs.obsBuilders.remove(cb);
      };

      obs.obsBuilders.add(cb);
      obs.notify();

      expect(obs.obsBuilders.length, 0);
    });

    test('回调执行期间新增回调不应影响本轮遍历且不抛异常', () {
      final obs = Obs(0);
      final calls = <String>[];

      late VoidCallback cb1;
      late VoidCallback cb2;

      cb2 = () => calls.add('cb2');
      cb1 = () {
        calls.add('cb1');
        obs.obsBuilders.add(cb2);
      };

      obs.obsBuilders.add(cb1);
      obs.notify();
      expect(calls, ['cb1']); // 本轮快照不会执行新增的 cb2

      calls.clear();
      obs.notify();
      expect(calls.toSet(), {'cb1', 'cb2'});
    });
  });

  group('Obs keepAliveTime setter', () {
    test('setter 应该反映到 getter', () {
      final obs = Obs(0);

      obs.keepAliveTime = null;
      expect(obs.keepAliveTime, null);
    });
  });
}
