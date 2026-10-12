import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // 通知器会访问帧调度，独立运行时也需要初始化测试绑定。
  TestWidgetsFlutterBinding.ensureInitialized();

  test('通知对象可解绑并在释放前发送一次通知', () {
    var calls = 0;
    void listener() => calls++;
    final notify = ElNotify()..addListener(listener);
    notify.notifyListeners();
    expect(calls, 1);
    notify.removeListener(listener);
    notify.notifyListeners();
    expect(calls, 1);
    notify.dispose();
    final dispose = ElDisposeNotify()..addListener(listener);
    dispose.dispose();
    expect(calls, 2);
    dispose.dispose();
    expect(calls, 2);
  });
}
