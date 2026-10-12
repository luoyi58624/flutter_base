import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('帧回调按是否主动请求帧执行', (tester) async {
    final calls = <String>[];
    safeCallback(() => calls.add('safe'));
    expect(calls, ['safe']);
    nextTick(() => calls.add('tick'));
    nextFrame(() => calls.add('frame'));
    await tester.pump();
    expect(calls, ['safe', 'frame', 'tick']);
  });
}
