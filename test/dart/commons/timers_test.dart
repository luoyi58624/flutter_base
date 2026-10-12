import 'package:fake_async/fake_async.dart';
import 'package:flutter_base/dart.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('定时器可取消且周期调用按时间推进', () {
    fakeAsync((time) {
      var calls = 0;
      setTimeout(() => calls++, 10).cancel();
      final interval = setInterval(() => calls++, 10);
      time.elapse(Duration(milliseconds: 35));
      expect(calls, 3);
      interval.cancel();
      time.elapse(Duration(milliseconds: 20));
      expect(calls, 3);
    });
  });

  test('零延迟定时器异步执行且只执行一次', () {
    fakeAsync((time) {
      var calls = 0;
      setTimeout(() => calls++, 0);
      expect(calls, 0);
      time.elapse(Duration.zero);
      expect(calls, 1);
      time.elapse(Duration(seconds: 1));
      expect(calls, 1);
    });
  });
}
