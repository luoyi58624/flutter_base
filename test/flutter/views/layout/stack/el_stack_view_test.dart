import 'package:flutter/semantics.dart' show SemanticsNode;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_base/ui.dart';

/// 命中探针：记录自己是否被点到。
class _HitProbe extends StatelessWidget {
  const _HitProbe({required this.tag, required this.log});

  final String tag;
  final List<String> log;

  @override
  Widget build(BuildContext context) {
    return ElView(
      style: const ElStyle(width: 40, height: 40, backgroundColor: Color(0xFF000000)),
      event: ElEvent(onTap: (_) => log.add(tag)),
    );
  }
}

Widget _app(Widget child) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Align(alignment: Alignment.topLeft, child: child),
  );
}

void main() {
  group('ElStackView 布局', () {
    testWidgets('非定位子决定尺寸，按 alignment 落位', (tester) async {
      await tester.pumpWidget(
        _app(const ElStackView(children: [SizedBox(width: 100, height: 50), SizedBox(width: 60, height: 80)])),
      );
      final render = tester.renderObject<RenderStackView>(find.byType(ElStackView));
      expect(render.size, const Size(100, 80));
    });

    testWidgets('StackFit.expand 撑满非定位子', (tester) async {
      await tester.pumpWidget(
        _app(
          const SizedBox(
            width: 200,
            height: 120,
            child: ElStackView(fit: StackFit.expand, children: [SizedBox(width: 10, height: 10)]),
          ),
        ),
      );
      final child = tester.renderObject<RenderBox>(find.byType(SizedBox).last);
      expect(child.size, const Size(200, 120));
    });

    testWidgets('无非定位子时取最大约束', (tester) async {
      await tester.pumpWidget(
        _app(
          const SizedBox(
            width: 200,
            height: 120,
            child: ElStackView(children: [ElPositioned(left: 10, top: 10, width: 20, height: 20, child: SizedBox())]),
          ),
        ),
      );
      final render = tester.renderObject<RenderStackView>(find.byType(ElStackView));
      expect(render.size, const Size(200, 120));
    });

    testWidgets('left+right 同写时拉伸宽度', (tester) async {
      await tester.pumpWidget(
        _app(
          const SizedBox(
            width: 200,
            height: 100,
            child: ElStackView(children: [ElPositioned(left: 20, right: 30, top: 0, child: SizedBox(height: 10))]),
          ),
        ),
      );
      final child = tester.renderObject<RenderBox>(find.byType(SizedBox).last);
      expect(child.size.width, 150.0);
    });
  });

  group('百分比定位（ElDimension）', () {
    testWidgets("top: '100%' 贴在宿主正下方（下拉菜单口径）", (tester) async {
      await tester.pumpWidget(
        _app(
          const SizedBox(
            width: 200,
            height: 80,
            child: ElStackView(
              children: [ElPositioned(left: 0, top: '100%', child: SizedBox(width: 50, height: 30))],
            ),
          ),
        ),
      );
      final child = tester.renderObject<RenderBox>(find.byType(SizedBox).last);
      final pd = child.parentData! as ElStackParentData;
      expect(pd.offset, const Offset(0, 80), reason: "top:'100%' = 宿主高度，即紧贴底边下方");
    });

    testWidgets('水平百分比对宽度、垂直百分比对高度（CSS 参考轴）', (tester) async {
      await tester.pumpWidget(
        _app(
          const SizedBox(
            width: 200,
            height: 100,
            child: ElStackView(
              children: [ElPositioned(left: '50%', top: '50%', child: SizedBox(width: 10, height: 10))],
            ),
          ),
        ),
      );
      final child = tester.renderObject<RenderBox>(find.byType(SizedBox).last);
      final pd = child.parentData! as ElStackParentData;
      expect(pd.offset, const Offset(100, 50), reason: 'left 走宽度 200→100，top 走高度 100→50');
    });

    testWidgets('百分比 width 按宿主宽度折算', (tester) async {
      await tester.pumpWidget(
        _app(
          const SizedBox(
            width: 300,
            height: 100,
            child: ElStackView(
              children: [ElPositioned(left: 0, top: 0, width: '50%', height: '25%', child: SizedBox())],
            ),
          ),
        ),
      );
      final child = tester.renderObject<RenderBox>(find.byType(SizedBox).last);
      expect(child.size, const Size(150, 25));
    });

    testWidgets('百分比 right/bottom 从对边折算', (tester) async {
      await tester.pumpWidget(
        _app(
          const SizedBox(
            width: 200,
            height: 200,
            child: ElStackView(
              children: [ElPositioned(right: '10%', bottom: '10%', child: SizedBox(width: 40, height: 40))],
            ),
          ),
        ),
      );
      final child = tester.renderObject<RenderBox>(find.byType(SizedBox).last);
      final pd = child.parentData! as ElStackParentData;
      // right 20 → x = 200 - 20 - 40 = 140；bottom 同理。
      expect(pd.offset, const Offset(140, 140));
    });

    testWidgets('像素与百分比可混写，且 num 形态行为不变', (tester) async {
      await tester.pumpWidget(
        _app(
          const SizedBox(
            width: 200,
            height: 100,
            child: ElStackView(
              children: [ElPositioned(left: 25, top: '50%', child: SizedBox(width: 10, height: 10))],
            ),
          ),
        ),
      );
      final child = tester.renderObject<RenderBox>(find.byType(SizedBox).last);
      final pd = child.parentData! as ElStackParentData;
      expect(pd.offset, const Offset(25, 50));
    });

    testWidgets('纯百分比声明也算定位子（不参与定尺）', (tester) async {
      // 不能套 SizedBox：那是 tight 约束，会把 stack 撑成父尺寸，测不出"非定位子
      // 定尺"。直接挂在 Align 下拿 loose 约束。
      await tester.pumpWidget(
        _app(
          const ElStackView(
            children: [
              SizedBox(width: 30, height: 20),
              ElPositioned(left: '50%', child: SizedBox(width: 500, height: 500)),
            ],
          ),
        ),
      );
      final render = tester.renderObject<RenderStackView>(find.byType(ElStackView));
      // 尺寸只由非定位子 30x20 决定；500x500 的定位子不参与。
      expect(render.size, const Size(30, 20));
      // 且百分比是对折算后的宿主尺寸取的：50% × 30 = 15。
      final positioned = tester.renderObject<RenderBox>(find.byType(SizedBox).last);
      expect((positioned.parentData! as ElStackParentData).offset.dx, 15.0);
    });

    testWidgets('宿主尺寸变化后百分比重折算', (tester) async {
      Widget build(double hostWidth) {
        return _app(
          SizedBox(
            width: hostWidth,
            height: 100,
            child: const ElStackView(
              children: [ElPositioned(left: '50%', top: 0, child: SizedBox(width: 10, height: 10))],
            ),
          ),
        );
      }

      await tester.pumpWidget(build(200));
      var pd = tester.renderObject<RenderBox>(find.byType(SizedBox).last).parentData! as ElStackParentData;
      expect(pd.offset.dx, 100.0);

      await tester.pumpWidget(build(400));
      pd = tester.renderObject<RenderBox>(find.byType(SizedBox).last).parentData! as ElStackParentData;
      expect(pd.offset.dx, 200.0, reason: '百分比在 performLayout 折算，宿主变宽要跟着变');
    });
  });

  group('官方 Positioned 兼容', () {
    testWidgets('官方 Positioned 在 ElStackView 里正常定位', (tester) async {
      await tester.pumpWidget(
        _app(
          const SizedBox(
            width: 200,
            height: 200,
            child: ElStackView(children: [Positioned(left: 30, top: 40, width: 50, height: 60, child: SizedBox())]),
          ),
        ),
      );
      final child = tester.renderObject<RenderBox>(find.byType(SizedBox).last);
      expect(child.size, const Size(50, 60));
      final pd = child.parentData! as ElStackParentData;
      expect(pd.offset, const Offset(30, 40));
      // 官方 Positioned 不写 zIndex，保持默认 0。
      expect(pd.zIndex, 0);
    });

    testWidgets('官方 Positioned.fill 铺满', (tester) async {
      await tester.pumpWidget(
        _app(
          const SizedBox(
            width: 200,
            height: 150,
            child: ElStackView(children: [Positioned.fill(child: SizedBox())]),
          ),
        ),
      );
      final child = tester.renderObject<RenderBox>(find.byType(SizedBox).last);
      expect(child.size, const Size(200, 150));
    });

    testWidgets('官方 Positioned 与 ElPositioned 可混用，zIndex 仍生效', (tester) async {
      final log = <String>[];
      await tester.pumpWidget(
        _app(
          SizedBox(
            width: 200,
            height: 200,
            child: ElStackView(
              children: [
                // 官方 Positioned：zIndex 恒 0，但数组在后 → 默认压在上面。
                Positioned(
                  left: 0,
                  top: 0,
                  child: _HitProbe(tag: 'official', log: log),
                ),
                // ElPositioned 给正 zIndex → 压过数组在前的官方 Positioned。
                ElPositioned(
                  left: 0,
                  top: 0,
                  zIndex: 1,
                  child: _HitProbe(tag: 'el', log: log),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.tapAt(const Offset(20, 20));
      expect(log, ['el']);
    });
  });

  group('zIndex 绘制与命中顺序', () {
    testWidgets('高 zIndex 盖住数组在后的子，并优先命中', (tester) async {
      final log = <String>[];
      await tester.pumpWidget(
        _app(
          SizedBox(
            width: 200,
            height: 200,
            child: ElStackView(
              children: [
                ElPositioned(
                  left: 0,
                  top: 0,
                  zIndex: 10,
                  child: _HitProbe(tag: 'high', log: log),
                ),
                ElPositioned(
                  left: 0,
                  top: 0,
                  child: _HitProbe(tag: 'low', log: log),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.tapAt(const Offset(20, 20));
      expect(log, ['high'], reason: 'zIndex 高者盖住并优先命中，与数组顺序无关');
    });

    testWidgets('同 zIndex 保持数组顺序（不依赖 sort 稳定性）', (tester) async {
      final log = <String>[];
      await tester.pumpWidget(
        _app(
          SizedBox(
            width: 200,
            height: 200,
            child: ElStackView(
              children: [
                for (var i = 0; i < 12; i++)
                  ElPositioned(
                    left: 0,
                    top: 0,
                    zIndex: 5,
                    child: _HitProbe(tag: '$i', log: log),
                  ),
              ],
            ),
          ),
        ),
      );
      await tester.tapAt(const Offset(20, 20));
      expect(log, ['11'], reason: '同 zIndex 时数组最后一个在最上层');
    });

    testWidgets('zIndex 变化只重排序不重排版', (tester) async {
      Widget build(int z) {
        return _app(
          SizedBox(
            width: 200,
            height: 200,
            child: ElStackView(
              children: [
                ElPositioned(left: 0, top: 0, zIndex: z, child: const SizedBox(width: 40, height: 40)),
                const ElPositioned(left: 0, top: 0, child: SizedBox(width: 40, height: 40)),
              ],
            ),
          ),
        );
      }

      await tester.pumpWidget(build(0));
      final render = tester.renderObject<RenderStackView>(find.byType(ElStackView));
      expect(render.debugNeedsLayout, isFalse);

      await tester.pumpWidget(build(3));
      // zIndex 走 markNeedsPaintOrder，不该触发 layout。
      expect(render.debugNeedsLayout, isFalse);
    });

    testWidgets('负 zIndex 不参与命中', (tester) async {
      final log = <String>[];
      await tester.pumpWidget(
        _app(
          SizedBox(
            width: 200,
            height: 200,
            child: ElStackView(
              children: [
                ElPositioned(
                  left: 0,
                  top: 0,
                  child: _HitProbe(tag: 'normal', log: log),
                ),
                ElPositioned(
                  left: 0,
                  top: 0,
                  zIndex: -5,
                  child: _HitProbe(tag: 'sunk', log: log),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.tapAt(const Offset(20, 20));
      expect(log, ['normal']);
    });
  });

  group('zIndex 语义顺序', () {
    /// 语义树的兄弟次序即遮挡次序：靠后者视为上层。树序靠前但 zIndex 拉到最上
    /// 的浮动子（贴顶导航压在全屏内容上），若语义仍按挂载序输出，会被那个全屏
    /// 兄弟整体判为遮挡而从平台命中中剔除——屏幕阅读器读不到、截图工具框选不中。
    testWidgets('高 zIndex 的浮动子在语义树中排到全屏兄弟之后', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          const SizedBox(
            width: 200,
            height: 200,
            child: ElStackView(
              children: [
                // 树序最前、zIndex 最高：绘制在最上的贴顶浮动条
                ElPositioned(
                  left: 0,
                  top: 0,
                  zIndex: 10,
                  child: ElView(style: ElStyle(width: 200, height: 40), child: 'floating'),
                ),
                // 树序其次、zIndex 0：铺满整个 stack 的内容层
                ElPositioned.fill(child: ElView(child: 'fullscreen')),
              ],
            ),
          ),
        ),
      );

      final labels = <String>[];
      void collect(SemanticsNode node) {
        if (node.label.isNotEmpty) labels.add(node.label);
        node.visitChildren((child) {
          collect(child);
          return true;
        });
      }

      // 测试环境语义树挂在 pipelineOwner（rootPipelineOwner 无渲染树，
      // Flutter 框架自身测试亦如此用法，无等价替代）。
      // ignore: deprecated_member_use
      collect(tester.binding.pipelineOwner.semanticsOwner!.rootSemanticsNode!);
      expect(labels, ['fullscreen', 'floating'], reason: '语义序须等于绘制序：zIndex 高的 floating 排在全屏兄弟之后才不被判为遮挡');
      handle.dispose();
    });

    testWidgets('zIndex 变化刷新语义序', (tester) async {
      final handle = tester.ensureSemantics();
      Widget build(int z) {
        return _app(
          SizedBox(
            width: 200,
            height: 200,
            child: ElStackView(
              children: [
                ElPositioned(
                  left: 0,
                  top: 0,
                  zIndex: z,
                  child: const ElView(style: ElStyle(width: 200, height: 40), child: 'floating'),
                ),
                const ElPositioned.fill(child: ElView(child: 'fullscreen')),
              ],
            ),
          ),
        );
      }

      List<String> labels() {
        final out = <String>[];
        void collect(SemanticsNode node) {
          if (node.label.isNotEmpty) out.add(node.label);
          node.visitChildren((child) {
            collect(child);
            return true;
          });
        }

        // 同上：测试环境语义树入口无 rootPipelineOwner 等价替代
        // ignore: deprecated_member_use
        collect(tester.binding.pipelineOwner.semanticsOwner!.rootSemanticsNode!);
        return out;
      }

      await tester.pumpWidget(build(0));
      expect(labels(), ['floating', 'fullscreen'], reason: '全 0 时语义序退化为挂载序');

      await tester.pumpWidget(build(10));
      expect(labels(), ['fullscreen', 'floating'], reason: 'zIndex 提升后语义序须立即跟着重排');
      handle.dispose();
    });
  });

  group('事件裁剪：溢出命中', () {
    testWidgets('clipBehavior none 时溢出子仍可命中', (tester) async {
      final log = <String>[];
      await tester.pumpWidget(
        _app(
          // 定尺父级必须用 ElView：官方 SizedBox 按 size 剪枝且不外传子溢出，
          // 是溢出命中协议的链断点，会在事件到达 stack 之前就掐掉。
          ElView(
            style: const ElStyle(width: 100, height: 100),
            child: ElStackView(
              children: [
                // 子右下角溢出父盒 40px。
                ElPositioned(
                  left: 80,
                  top: 80,
                  child: _HitProbe(tag: 'overflow', log: log),
                ),
              ],
            ),
          ),
        ),
      );
      // 子占 [80,120)×[80,120)：(110,110) 在父盒 100×100 之外、子可见区之内。
      // 注意别取 (120,120)——Rect.contains 对 right/bottom 排他，正好差一像素。
      await tester.tapAt(const Offset(110, 110));
      expect(log, ['overflow'], reason: 'overflow visible 下画得出即点得到');
    });

    testWidgets('clipBehavior hardEdge 时溢出子不可命中（裁剪即封口）', (tester) async {
      final log = <String>[];
      await tester.pumpWidget(
        _app(
          // 父级用 ElView：否则官方 SizedBox 自己就把外部命中剪掉了，
          // 测不出"封口"究竟是 stack 做的还是父级做的。
          ElView(
            style: const ElStyle(width: 100, height: 100),
            child: ElStackView(
              clipBehavior: Clip.hardEdge,
              children: [
                ElPositioned(
                  left: 80,
                  top: 80,
                  child: _HitProbe(tag: 'clipped', log: log),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.tapAt(const Offset(110, 110));
      expect(log, isEmpty, reason: '裁剪后画不出来，就不该点得到');
      // 盒内部分仍可命中。
      await tester.tapAt(const Offset(90, 90));
      expect(log, ['clipped']);
    });

    testWidgets('hitTestBounds 外传给祖先，祖先剪枝不误杀', (tester) async {
      final log = <String>[];
      await tester.pumpWidget(
        _app(
          // 外层 ElView 比内层 stack 小，靠协议聚合拿到溢出边界。
          ElView(
            style: const ElStyle(width: 60, height: 60),
            child: ElStackView(
              children: [
                ElPositioned(
                  left: 50,
                  top: 50,
                  child: _HitProbe(tag: 'deep', log: log),
                ),
              ],
            ),
          ),
        ),
      );
      final render = tester.renderObject<RenderStackView>(find.byType(ElStackView));
      expect(render.hasHitBoundsOverflow, isTrue);
      expect(render.hitTestBounds.right, greaterThan(60));

      await tester.tapAt(const Offset(80, 80));
      expect(log, ['deep'], reason: '溢出边界经协议上传，祖先不按 size 误剪');
    });

    testWidgets('无溢出时零额外开销（hasHitBoundsOverflow == false）', (tester) async {
      await tester.pumpWidget(
        _app(
          const SizedBox(
            width: 200,
            height: 200,
            child: ElStackView(children: [ElPositioned(left: 10, top: 10, width: 20, height: 20, child: SizedBox())]),
          ),
        ),
      );
      final render = tester.renderObject<RenderStackView>(find.byType(ElStackView));
      expect(render.hasHitBoundsOverflow, isFalse);
    });

    testWidgets('命中顺序按 zIndex 逆序，溢出区同样成立', (tester) async {
      final log = <String>[];
      await tester.pumpWidget(
        _app(
          ElView(
            style: const ElStyle(width: 100, height: 100),
            child: ElStackView(
              children: [
                ElPositioned(
                  left: 80,
                  top: 80,
                  zIndex: 9,
                  child: _HitProbe(tag: 'top', log: log),
                ),
                ElPositioned(
                  left: 80,
                  top: 80,
                  child: _HitProbe(tag: 'bottom', log: log),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.tapAt(const Offset(110, 110));
      expect(log, ['top'], reason: '溢出区的命中同样走 zIndex 逆序');
    });

    testWidgets('布局变化后命中边界失效重算', (tester) async {
      Widget build(double left) {
        return _app(
          SizedBox(
            width: 100,
            height: 100,
            child: ElStackView(
              children: [ElPositioned(left: left, top: 10, child: const SizedBox(width: 40, height: 40))],
            ),
          ),
        );
      }

      await tester.pumpWidget(build(10));
      final render = tester.renderObject<RenderStackView>(find.byType(ElStackView));
      expect(render.hasHitBoundsOverflow, isFalse);

      await tester.pumpWidget(build(90));
      expect(render.hasHitBoundsOverflow, isTrue, reason: 'performLayout 必须标脏命中边界');
      expect(render.hitBoundsPre.right, 130.0);
    });
  });
}
