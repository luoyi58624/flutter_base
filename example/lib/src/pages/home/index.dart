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

const _anchorInset = 20.0;

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
    final controller = useScrollController(keepScrollOffset: false);
    final listController = useMemoized(ElSliverRecyclerController.new);

    final navigation = useRef(0);
    final current = useMemoized(() => ValueNotifier(''));
    final anchors = useMemoized(() => <String, GlobalKey>{});
    final indexes = useMemoized(() => <String, int>{});
    final mountedRows = useMemoized(() => <BuildContext, String>{});
    useEffect(() => current.dispose, []);
    useEffect(() => listController.cancel, []);
    void sync() {
      if (!context.mounted || !controller.hasClients) return;
      var selected = '';
      var nearest = double.negativeInfinity;
      for (final row in mountedRows.entries) {
        if (!row.key.mounted) continue;
        final render = row.key.findRenderObject();
        if (render == null || !showcaseIsLaidOut(render)) continue;
        final offset = RenderAbstractViewport.of(render).getOffsetToReveal(render, 0).offset;
        if (offset <= controller.offset + 48 && offset > nearest) {
          nearest = offset;
          selected = row.value;
        }
      }
      current.value = selected;
    }

    Future<void> navigate(String id) async {
      if (!controller.hasClients) return;
      final index = id == 'top' ? 0 : indexes[id];
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
          : RenderAbstractViewport.of(render).getOffsetToReveal(render, 0).offset - _anchorInset;
      if (target == null) return;
      final offset = target.clamp(0.0, controller.position.maxScrollExtent);
      if (MediaQuery.disableAnimationsOf(context)) {
        controller.jumpTo(offset);
      } else {
        await controller.animateTo(offset, duration: Duration(milliseconds: 340), curve: Curves.easeOutCubic);
      }
      if (context.mounted && request == navigation.value) sync();
    }

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
          builder: (context, constraints) => HookBuilder(
            builder: (context) {
              final width = constraints.maxWidth;
              final mobile = width <= 760;
              final contentWidth = (width - (width * .07).clamp(32, 96)).clamp(0.0, 1200.0);
              final inset = (width - contentWidth) / 2;
              final chapterGap = (width * .07).clamp(52.0, 90.0);
              // 宽度不变时复用滚动配置，键盘只改变视口高度。
              final slivers = useMemoized(() {
                final items = <(String, ShowcaseItem)>[
                  (
                    '',
                    ShowcaseItem(
                      (_) => ShowcaseHero(onExplore: () => navigate('actions'), onTakeaway: () => navigate('takeaway')),
                      gap: mobile ? 28 : 46,
                    ),
                  ),
                  for (final item in buttonShowcaseItems(width)) ('actions', item),
                  for (final item in controlShowcaseItems(mobile)) ('controls', item),
                  for (final item in surfaceShowcaseItems(mobile)) ('surfaces', item),
                  for (final item in feedbackShowcaseItems(mobile)) ('feedback', item),
                  for (final item in scenarioShowcaseItems(mobile)) ('scenarios', item),
                  (
                    'scenarios',
                    ShowcaseItem(
                      (context) => ElView(
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
                    ),
                  ),
                ];
                indexes
                  ..clear()
                  ..addEntries([
                    for (final (index, row) in items.indexed)
                      for (final id in row.$2.anchors) MapEntry(id, index),
                  ]);
                for (final id in indexes.keys) {
                  anchors.putIfAbsent(id, () => GlobalKey(debugLabel: id));
                }
                return [
                  SliverPadding(
                    padding: .fromLTRB(inset, mobile ? 16 : 24, inset, 0),
                    sliver: ElSliverList.recycler(
                      key: ValueKey((mobile, width >= 1060)),
                      controller: listController,
                      itemCount: items.length,
                      // 每项只有自己的身份，离开视口后直接卸载。
                      itemType: (index) => index,
                      maxRecycledItems: 0,
                      itemBuilder: (context, binding) {
                        final index = binding.value;
                        final (chapter, item) = items[index];
                        final next = index + 1 < items.length ? items[index + 1] : null;
                        final gap = next == null
                            ? 0.0
                            : index == items.length - 2
                            ? mobile
                                  ? 36.0
                                  : 56.0
                            : chapter.isNotEmpty && chapter != next.$1
                            ? chapterGap
                            : item.gap;
                        final nextInset = next != null && next.$2.anchors.isNotEmpty ? _anchorInset : 0.0;
                        return HookBuilder(
                          builder: (context) {
                            useEffect(() {
                              mountedRows[context] = chapter;
                              return () => mountedRows.remove(context);
                            }, [chapter]);
                            return Padding(
                              padding: .only(
                                // 留白属于目标项，远跳无需先测它前面的示例。
                                top: item.anchors.isEmpty ? 0 : _anchorInset,
                                bottom: (gap - nextInset).clamp(0, double.infinity),
                              ),
                              child: item.build(context),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ];
              }, [width]);
              final scroll = ElScrollView.sliver(
                key: ValueKey('showcase-scroll'),
                controller: controller,
                scrollCacheExtent: ScrollCacheExtent.pixels(0),
                slivers: slivers,
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
