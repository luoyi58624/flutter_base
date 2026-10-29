import 'dart:math' as math;

import 'package:flutter_base/ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child) {
  return Directionality(
    textDirection: .ltr,
    child: Align(alignment: .topLeft, child: child),
  );
}

Widget _target(String tag, List<String> log, {ElPointerEvents? pointerEvents}) {
  return ElView(
    key: ValueKey(tag),
    style: ElStyle(width: 40, height: 40, pointerEvents: pointerEvents),
    event: ElEvent(onTap: (_) => log.add(tag)),
  );
}

Widget _officialOverflowBranch(
  Widget child, {
  Offset offset = const Offset(80, 80),
  HitTestBehavior behavior = .deferToChild,
  void Function()? onPointerDown,
}) {
  return SizedBox(
    width: 100,
    height: 100,
    child: Listener(
      behavior: behavior,
      onPointerDown: onPointerDown == null ? null : (_) => onPointerDown(),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          Row(
            children: [Transform.translate(offset: offset, child: child)],
          ),
        ],
      ),
    ),
  );
}

class _TriangleClipper extends CustomClipper<Path> {
  const _TriangleClipper();

  @override
  Path getClip(Size size) => Path()
    ..moveTo(size.width / 2, 0)
    ..lineTo(size.width, size.height)
    ..lineTo(0, size.height)
    ..close();

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _CircleRRectClipper extends CustomClipper<RRect> {
  const _CircleRRectClipper();

  @override
  RRect getClip(Size size) => RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(size.shortestSide / 2));

  @override
  bool shouldReclip(covariant CustomClipper<RRect> oldClipper) => false;
}

class _TransformFixture extends StatefulWidget {
  const _TransformFixture({required this.log, super.key});

  final List<String> log;

  @override
  State<_TransformFixture> createState() => _TransformFixtureState();
}

class _TransformFixtureState extends State<_TransformFixture> {
  Offset offset = const Offset(80, 80);

  void updateOffset(Offset value) => setState(() => offset = value);

  @override
  Widget build(BuildContext context) {
    return ElStackView(children: [_officialOverflowBranch(_target('target', widget.log), offset: offset)]);
  }
}

class _ReorderFixture extends StatefulWidget {
  const _ReorderFixture({required this.log, super.key});

  final List<String> log;

  @override
  State<_ReorderFixture> createState() => _ReorderFixtureState();
}

class _ReorderFixtureState extends State<_ReorderFixture> {
  bool reversed = false;

  void reverseChildren() => setState(() => reversed = !reversed);

  @override
  Widget build(BuildContext context) {
    final tags = reversed ? const <String>['top', 'bottom'] : const <String>['bottom', 'top'];
    return ElStackView(
      children: <Widget>[
        Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            for (final tag in tags)
              KeyedSubtree(
                key: ValueKey<String>('branch-$tag'),
                child: _officialOverflowBranch(_target(tag, widget.log)),
              ),
          ],
        ),
      ],
    );
  }
}

void main() {
  testWidgets('官方 SizedBox/Row/Column/Transform 夹层不截断溢出命中路径', (tester) async {
    for (final behavior in HitTestBehavior.values) {
      final log = <String>[];
      await tester.pumpWidget(
        _app(
          ElStackView(
            children: [
              _officialOverflowBranch(
                _target('target', log),
                behavior: behavior,
                onPointerDown: () => log.add('listener'),
              ),
            ],
          ),
        ),
      );

      await tester.tapAt(const Offset(110, 110));
      expect(log, ['listener', 'target'], reason: '$behavior 下深层 target 与官方 Listener 都必须留在真实 hit path 中');
    }
  });

  testWidgets('translate/scale/rotate 复合后代理命中真实视觉中心', (tester) async {
    final log = <String>[];
    await tester.pumpWidget(
      _app(
        ElStackView(
          children: [
            _officialOverflowBranch(
              Transform.rotate(
                angle: math.pi / 4,
                alignment: .topLeft,
                child: Transform.scale(scale: 1.5, alignment: .topLeft, child: _target('transformed', log)),
              ),
            ),
          ],
        ),
      ),
    );

    await tester.tapAt(tester.getCenter(find.byKey(const ValueKey('transformed'))));
    expect(log, ['transformed']);
  });

  testWidgets('纯 El 直连且无溢出时不注册代理', (tester) async {
    await tester.pumpWidget(
      _app(ElStackView(children: [ElPositioned(left: 10, top: 10, child: _target('normal', <String>[]))])),
    );
    final stack = tester.renderObject<RenderStackView>(find.byType(ElStackView));
    expect(stack.debugOverflowHitProxyCount, 0);
  });

  testWidgets('动态 transform 后下一次命中使用新 geometry', (tester) async {
    final key = GlobalKey<_TransformFixtureState>();
    final log = <String>[];
    await tester.pumpWidget(_app(_TransformFixture(key: key, log: log)));
    final stack = tester.renderObject<RenderStackView>(find.byType(ElStackView));
    final geometryVersion = stack.debugOverflowHitGeometryVersion;

    await tester.tapAt(const Offset(110, 110));
    expect(log, ['target']);
    log.clear();

    key.currentState!.updateOffset(const Offset(20, 20));
    await tester.pump();
    expect(stack.debugOverflowHitGeometryVersion, geometryVersion, reason: 'paint 只标记待验证，不得抢跑遍历深层代理');
    await tester.tapAt(const Offset(110, 110));
    expect(log, isEmpty, reason: '旧代理边界必须立即失效');
    expect(stack.debugOverflowHitGeometryVersion, greaterThan(geometryVersion), reason: '下一次真正读取代理前必须刷新官方 transform');
    await tester.tapAt(const Offset(30, 30));
    expect(log, ['target']);
  });

  testWidgets('官方多子节点原地重排后代理命中顺序同步翻转', (tester) async {
    final key = GlobalKey<_ReorderFixtureState>();
    final log = <String>[];
    await tester.pumpWidget(_app(_ReorderFixture(key: key, log: log)));
    final bottomBefore = tester.renderObject(find.byKey(const ValueKey<String>('bottom')));
    final topBefore = tester.renderObject(find.byKey(const ValueKey<String>('top')));
    await tester.tapAt(const Offset(110, 110));
    expect(log, ['top']);
    log.clear();

    key.currentState!.reverseChildren();
    await tester.pump();
    expect(tester.renderObject(find.byKey(const ValueKey<String>('bottom'))), same(bottomBefore));
    expect(tester.renderObject(find.byKey(const ValueKey<String>('top'))), same(topBefore));
    await tester.tapAt(const Offset(110, 110));
    expect(log, ['bottom'], reason: 'route 未变化时也必须检测官方 parent 的 paint-order 变化');
  });

  testWidgets('ClipRect 封口后代理不可命中裁剪外内容', (tester) async {
    final log = <String>[];
    await tester.pumpWidget(
      _app(
        SizedBox(
          width: 140,
          height: 140,
          child: ElStackView(
            children: [
              ElPositioned.fill(child: _target('underlay', log)),
              ElPositioned(
                left: 0,
                top: 0,
                width: 100,
                height: 100,
                zIndex: 1,
                child: ClipRect(child: _officialOverflowBranch(_target('clipped', log))),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(110, 110));
    expect(log, ['underlay']);
  });

  testWidgets('ClipRRect 与 ClipPath 的精确形状不会被代理绕过', (tester) async {
    Future<void> verify(Widget Function(Widget child) clip) async {
      final log = <String>[];
      await tester.pumpWidget(
        _app(
          SizedBox(
            width: 100,
            height: 100,
            child: ElStackView(
              children: [
                ElPositioned.fill(child: _target('underlay', log)),
                ElPositioned.fill(
                  zIndex: 1,
                  child: clip(
                    SizedBox(
                      width: 100,
                      height: 100,
                      child: ElView(
                        style: const ElStyle(width: 100, height: 100),
                        event: ElEvent(onTap: (_) => log.add('clipped')),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.tapAt(const Offset(2, 2));
      expect(log, ['underlay']);
    }

    await verify((child) => ClipRRect(clipper: const _CircleRRectClipper(), child: child));
    await verify((child) => ClipPath(clipper: const _TriangleClipper(), child: child));
  });

  testWidgets('高 zIndex 的溢出代理优先于低层正常 child', (tester) async {
    final log = <String>[];
    await tester.pumpWidget(
      _app(
        SizedBox(
          width: 140,
          height: 140,
          child: ElStackView(
            children: [
              ElPositioned.fill(child: _target('underlay', log)),
              ElPositioned(left: 0, top: 0, zIndex: 5, child: _officialOverflowBranch(_target('top', log))),
            ],
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(110, 110));
    expect(log, ['top']);
  });

  testWidgets('pointerEvents none 的溢出代理穿透到低层', (tester) async {
    final log = <String>[];
    await tester.pumpWidget(
      _app(
        SizedBox(
          width: 140,
          height: 140,
          child: ElStackView(
            children: [
              ElPositioned.fill(child: _target('underlay', log)),
              ElPositioned(
                left: 0,
                top: 0,
                zIndex: 5,
                child: _officialOverflowBranch(_target('ghost', log, pointerEvents: .none)),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(110, 110));
    expect(log, ['underlay']);
  });

  testWidgets('不可逆 transform 不崩溃也不误命中', (tester) async {
    final log = <String>[];
    await tester.pumpWidget(
      _app(
        SizedBox(
          width: 140,
          height: 140,
          child: ElStackView(
            children: [
              ElPositioned.fill(child: _target('underlay', log)),
              ElPositioned(
                left: 0,
                top: 0,
                zIndex: 5,
                child: _officialOverflowBranch(Transform.scale(scale: 0, child: _target('collapsed', log))),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(110, 110));
    expect(log, ['underlay']);
    expect(tester.takeException(), isNull);
  });
}
