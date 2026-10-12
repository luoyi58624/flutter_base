import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('默认入口导出独立的工具与日志 API', () {
    expect(ElDartUtil.safeInt('12'), 12);
    expect(ElLog.i, isA<ElLogFunction>());
    expect(ElLogConfig.info, 2000);
  });
}
