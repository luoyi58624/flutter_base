import 'package:flutter_base/src/ui/testing/ui_test_api.dart';
import 'package:flutter_test/flutter_test.dart';

class _DamageHost extends ElRenderView {
  int layouts = 0;
  int paints = 0;

  @override
  void markNeedsLayout() {
    layouts++;
    super.markNeedsLayout();
  }

  @override
  void markNeedsPaint() {
    paints++;
    super.markNeedsPaint();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('字段行为与实际 damage 路由', () {
    for (final (field, layouts, paints, inherited) in <(ElTransitionField, int, int, bool)>[
      (.color, 0, 1, true),
      (.fontSize, 1, 0, true),
      (.cursor, 0, 0, true),
      (.width, 1, 0, false),
      (.bgColor, 0, 1, false),
      (.overflow, 1, 1, false),
    ]) {
      test('${field.name} 的布局、绘制和继承相互独立', () {
        final spec = fieldSpecOf(field);
        expect(spec.affectsLayout, layouts != 0);
        expect(spec.affectsPaint, paints != 0);
        expect(spec.isInherited, inherited);
        final host = _DamageHost();
        addTearDown(host.dispose);
        host.layouts = host.paints = 0;
        DamageRouter.route(host: host, changedMask: fieldsMask([field]), inheritableHost: host);
        expect(host.layouts, layouts);
        expect(host.paints, paints);
      });
    }

    test('空变化不会触发布局或绘制', () {
      final host = _DamageHost();
      addTearDown(host.dispose);
      host.layouts = host.paints = 0;
      DamageRouter.route(host: host, changedMask: fieldsMask([]), inheritableHost: host);
      expect(host.layouts, 0);
      expect(host.paints, 0);
    });
  });
}
