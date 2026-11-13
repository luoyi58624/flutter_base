import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderAbstractViewport;
import 'package:flutter_base/mobile.dart';

import '../../layout/example_page.dart';
import '../../layout/page_scope.dart';
import 'showcase/header.dart';
import 'showcase/buttons.dart';
import 'showcase/controls.dart';
import 'showcase/feedback.dart';
import 'showcase/hero.dart';
import 'showcase/panel.dart';
import 'showcase/scenarios.dart';
import 'showcase/surfaces.dart';

final _chapters = {'actions': '基础组件', 'controls': '交互控制', 'surfaces': '内容容器', 'feedback': '状态反馈', 'scenarios': '完整示例'};

/// 对照 Vue 完整展示页，章节定位与应用导航分别保留各自职责。
class HomePage extends HookWidget {
  /// 创建移动组件综合展示首页。
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = useScrollController();
    final current = useMemoized(() => ValueNotifier(''));
    // 键盘会改变外层导航壳的高度；章节由自身状态和宽度环境更新，不随高度重建。
    final sections = useMemoized(
      () => <String, Widget>{
        'actions': ButtonShowcase(),
        'controls': ControlsShowcase(),
        'surfaces': SurfacesShowcase(),
        'feedback': FeedbackShowcase(),
        'scenarios': ScenariosShowcase(),
      },
    );
    final anchors = useMemoized(
      () => {
        for (final id in [
          ..._chapters.keys,
          'control-fields',
          'control-pickers',
          'control-dates',
          'control-upload',
          'surface-cards',
          'surface-images',
          'surface-navigation',
          'feedback-state',
          'feedback-prompts',
          'feedback-progress',
          'feedback-overlays',
          'scenario-form',
          'scenario-feed',
          'scenario-tabs',
          'scenario-inputs',
          'takeaway',
        ])
          id: GlobalKey(debugLabel: id),
      },
    );
    useEffect(() => current.dispose, []);
    void navigate(String id) {
      if (!controller.hasClients) return;
      final render = anchors[id]?.currentContext?.findRenderObject();
      final target = id == 'top'
          ? 0.0
          : render == null
          ? null
          : RenderAbstractViewport.of(render).getOffsetToReveal(render, 0).offset - 20;
      if (target == null) return;
      controller.animateTo(
        target.clamp(0, controller.position.maxScrollExtent),
        duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : Duration(milliseconds: 340),
        curve: Curves.easeOutCubic,
      );
    }

    final hero = useMemoized(
      () => ShowcaseHero(onExplore: () => navigate('actions'), onTakeaway: () => navigate('takeaway')),
    );
    useEffect(() {
      void sync() {
        if (!controller.hasClients) return;
        var selected = '';
        for (final id in _chapters.keys) {
          final render = anchors[id]?.currentContext?.findRenderObject();
          if (render != null &&
              render.attached &&
              RenderAbstractViewport.of(render).getOffsetToReveal(render, 0).offset <= controller.offset + 48) {
            selected = id;
          }
        }
        current.value = selected;
      }

      controller.addListener(sync);
      return () => controller.removeListener(sync);
    }, [controller]);
    return ElComponentProvider(
      components: el.mobileComponents,
      style: _pageStyle(),
      child: Builder(
        builder: (context) => LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final mobile = width <= 760;
            final contentWidth = (width - (width * .07).clamp(32, 96)).clamp(0.0, 1200.0);
            final inset = (width - contentWidth) / 2;
            final ownNavbar =
                MediaQuery.sizeOf(context).width <= ElBreakpoint.defaultSm || !DesktopPageScope.exists(context);
            final header = ShowcaseHeader(
              chapters: _chapters,
              width: width,
              inset: inset,
              current: current,
              onNavigate: navigate,
            );
            final scroll = ElScrollView(
              key: PageStorageKey('showcase-scroll'),
              controller: controller,
              padding: .fromLTRB(inset, mobile ? 16 : 24, inset, 0),
              children: [
                hero,
                SizedBox(height: mobile ? 28 : 46),
                for (final entry in sections.entries) ...[
                  entry.value,
                  if (entry.key != 'scenarios') SizedBox(height: (width * .07).clamp(52, 90)),
                ],
                SizedBox(height: mobile ? 36 : 56),
                ElView(
                  style: ElStyle(
                    padding: .only(top: 14, bottom: 22),
                    border: ElBorder.only(borderTop: ElBorderSide(borderColor: context.elTheme.borderColor)),
                  ),
                  child: Wrap(
                    alignment: .spaceBetween,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      demoHint(context, 'my-ui · 简洁、自然的移动组件'),
                      ElButton(variant: .link, child: '回到顶部 ↑', onPressed: () => navigate('top')),
                    ],
                  ),
                ),
              ],
            );
            return ShowcaseScope(
              width: width,
              anchors: anchors,
              onNavigate: navigate,
              scrollController: controller,
              child: DefaultTextStyle(
                style: TextStyle(fontSize: 14, height: 1.5, color: context.elTheme.textColor),
                child: ExamplePage(
                  title: '首页',
                  navigationBar: header,
                  backgroundColor: context.elTheme.bgColor,
                  child: ownNavbar
                      ? scroll
                      : Column(
                          children: [
                            header,
                            Expanded(child: scroll),
                          ],
                        ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

ElStyle _pageStyle() => ElStyle(
  fontFamily: 'Roboto',
  vars: {
    ElTokens.$bgColor: Color(0xfff2f3f5),
    ElTokens.$primary: Color(0xff2454c6),
    ElTokens.$info: Color(0xff2454c6),
    ElTokens.$success: Color(0xff176b3c),
    ElTokens.$warning: Color(0xff805500),
    ElTokens.$error: Color(0xffb5283c),
    ElTokens.$shadowXs: 1,
    ElTokens.$shadowSm: 2,
    ElTokens.$shadowMd: 3,
    ElTokens.$shadowLg: 12,
    ElTokens.$shadowXl: 24,
  },
);
