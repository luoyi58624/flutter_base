import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderAbstractViewport, ScrollCacheExtent;
import 'package:flutter_base/mobile.dart';

import '../../layout/example_page.dart';
import 'showcase/buttons.dart';
import 'showcase/controls.dart';
import 'showcase/feedback.dart';
import 'showcase/hero.dart';
import 'showcase/panel.dart';
import 'showcase/scenarios.dart';
import 'showcase/surfaces.dart';

final _chapters = {'actions': '基础组件', 'controls': '交互控制', 'surfaces': '内容容器', 'feedback': '状态反馈', 'scenarios': '完整示例'};

// 子锚点先定位所属章节，未访问过的章节不需要提前构建来取得坐标。
final _anchorSections = {
  'actions': 1,
  'controls': 2,
  'control-fields': 2,
  'control-pickers': 2,
  'control-dates': 2,
  'control-upload': 2,
  'surfaces': 3,
  'surface-cards': 3,
  'surface-images': 3,
  'surface-navigation': 3,
  'feedback': 4,
  'feedback-state': 4,
  'feedback-prompts': 4,
  'feedback-progress': 4,
  'feedback-overlays': 4,
  'scenarios': 5,
  'scenario-form': 5,
  'scenario-feed': 5,
  'scenario-tabs': 5,
  'scenario-inputs': 5,
  'takeaway': 5,
};

RenderObject? _laidOutAnchor(GlobalKey? key) {
  final render = key?.currentContext?.findRenderObject();
  return render != null && showcaseIsLaidOut(render) ? render : null;
}

/// 对照 Vue 完整展示页，章节定位与应用导航分别保留各自职责。
class HomePage extends HookWidget {
  /// 创建移动组件综合展示首页。
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = useScrollController();
    final listController = useMemoized(ElSliverRecyclerController.new);
    final sectionStorage = useMemoized(PageStorageBucket.new);
    final navigation = useRef(0);
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
    final anchors = useMemoized(() => {for (final id in _anchorSections.keys) id: GlobalKey(debugLabel: id)});
    useEffect(() => current.dispose, []);
    useEffect(() => listController.cancel, []);
    void sync() {
      if (!context.mounted || !controller.hasClients) return;
      var selected = '';
      for (final id in _chapters.keys) {
        final render = _laidOutAnchor(anchors[id]);
        if (render != null &&
            RenderAbstractViewport.of(render).getOffsetToReveal(render, 0).offset <= controller.offset + 48) {
          selected = id;
        }
      }
      current.value = selected;
    }

    Future<void> navigate(String id) async {
      if (!controller.hasClients) return;
      final index = id == 'top' ? 0 : _anchorSections[id];
      if (index == null) return;
      final request = ++navigation.value;
      listController.cancel();
      if (id == 'top' || _laidOutAnchor(anchors[id]) == null) {
        if (!await listController.jumpToIndex(index)) return;
        if (!context.mounted || request != navigation.value || !controller.hasClients) return;
      }
      final render = _laidOutAnchor(anchors[id]);
      final target = id == 'top'
          ? 0.0
          : render == null
          ? null
          : RenderAbstractViewport.of(render).getOffsetToReveal(render, 0).offset - 20;
      if (target == null) return;
      final offset = target.clamp(0.0, controller.position.maxScrollExtent);
      if (MediaQuery.disableAnimationsOf(context)) {
        controller.jumpTo(offset);
      } else {
        await controller.animateTo(offset, duration: Duration(milliseconds: 340), curve: Curves.easeOutCubic);
      }
      if (context.mounted && request == navigation.value) sync();
    }

    final hero = useMemoized(
      () => ShowcaseHero(onExplore: () => navigate('actions'), onTakeaway: () => navigate('takeaway')),
    );
    useEffect(() {
      var pending = false;
      void scheduleSync() {
        if (pending) return;
        pending = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          pending = false;
          sync();
        });
      }

      controller.addListener(scheduleSync);
      scheduleSync();
      return () {
        controller.removeListener(scheduleSync);
      };
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
            final scroll = ElScrollView.sliver(
              key: PageStorageKey('showcase-scroll'),
              controller: controller,
              // 每个条目都是完整章节，避免远跳时预取尚未测量的相邻大章节。
              scrollCacheExtent: ScrollCacheExtent.pixels(0),
              slivers: [
                // 后挂载的横向滚动示例不能继承首页纵向滚动的 PageStorageKey。
                PageStorage(
                  bucket: sectionStorage,
                  child: SliverPadding(
                    padding: .fromLTRB(inset, mobile ? 16 : 24, inset, 0),
                    sliver: ElSliverList.recycler(
                      controller: listController,
                      itemCount: sections.length + 2,
                      // 每章独立停放，避免换绑时丢失输入、购物车等演示状态。
                      itemType: (index) => index,
                      maxRecycledItems: sections.length + 2,
                      itemBuilder: (context, index) {
                        if (index.value == 0) {
                          return Padding(
                            padding: .only(bottom: (mobile ? 28 : 46) - 20),
                            child: hero,
                          );
                        }
                        if (index.value <= sections.length) {
                          return Padding(
                            padding: .only(
                              // 定位留白放在章节内部，远跳后不必反向进入尚未构建的前一章。
                              top: 20,
                              bottom: index.value == sections.length
                                  ? mobile
                                        ? 36
                                        : 56
                                  : (width * .07).clamp(52, 90) - 20,
                            ),
                            child: sections.values.elementAt(index.value - 1),
                          );
                        }
                        return ElView(
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
                        );
                      },
                    ),
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
                  showThemeToggle: true,
                  actions: [
                    ValueListenableBuilder<String>(
                      valueListenable: current,
                      builder: (context, selected, _) => PopupMenuButton<String>(
                        key: ValueKey('showcase-chapters'),
                        tooltip: '章节目录',
                        initialValue: selected.isEmpty ? 'top' : selected,
                        icon: Icon(Icons.toc),
                        onSelected: navigate,
                        itemBuilder: (context) => [
                          PopupMenuItem(value: 'top', child: Text('回到顶部')),
                          for (final chapter in _chapters.entries)
                            PopupMenuItem(value: chapter.key, child: Text(chapter.value)),
                        ],
                      ),
                    ),
                  ],
                  backgroundColor: context.elTheme.bgColor,
                  child: scroll,
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
