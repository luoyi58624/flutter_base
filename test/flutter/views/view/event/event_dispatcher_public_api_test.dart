import 'package:flutter_base/src/flutter/views/view/event/event.dart';
import 'package:flutter_base/src/flutter/views/view/event/dispatcher.dart' show EventDispatcher;
import 'package:flutter/rendering.dart' show RenderConstrainedBox;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart' hide EventDispatcher;

void main() {
  test('内部宿主可独立使用 EventDispatcher', () {
    final render = RenderConstrainedBox(additionalConstraints: BoxConstraints.tight(Size(1, 1)));
    final dispatcher = EventDispatcher(render);
    addTearDown(dispatcher.dispose);
    expect(EventDispatcher.of(render), same(dispatcher));
  });

}
