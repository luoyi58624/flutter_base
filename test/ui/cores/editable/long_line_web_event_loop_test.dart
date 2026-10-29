import 'package:flutter_base/src/ui/cores/editable/render/bidi/long_line_web_event_loop.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('MessageChannel cooperative yield 会在 Web 下一 task 结清', () async {
    await yieldLongLineWebEventLoop().timeout(const Duration(seconds: 2));
  }, skip: !kIsWeb);
}
