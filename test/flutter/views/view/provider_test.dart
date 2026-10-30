import 'package:flutter_base/src/flutter/views/selection/common/selection_core.dart';
import 'package:flutter_base/ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('未配置时按平台回退 el_ui 内置实现', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    late ElScrollbar scrollbar;
    late ElRefresher refresher;
    late SelectionControls controls;
    ElSmoothScroll? smoothScroll;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Builder(
          builder: (context) {
            scrollbar = ElViewProvider.scrollbarOf(context);
            refresher = ElViewProvider.refresherOf(context);
            controls = SelectionControlsScope.of(context);
            smoothScroll = ElViewProvider.smoothScrollOf(context);
            return const SizedBox();
          },
        ),
      ),
    );

    debugDefaultTargetPlatformOverride = null;
    expect(scrollbar, isA<ElAndroidScrollBar>());
    expect(refresher, isA<ElAndroidRefresher>());
    expect(controls, isA<AndroidSelectionControls>());
    expect(smoothScroll, isNull);
  });

  testWidgets('builder 覆写当前子树，返回 null 时继续继承祖先', (tester) async {
    late ElScrollbar inheritedFromBuilderContext;
    late ElScrollbar innerResolved;
    late ElScrollbar nullResolved;
    late ElScrollbar siblingResolved;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ElViewProvider(
          scrollbarBuilder: (_) => const ElNoScrollBar(),
          child: Column(
            children: [
              ElViewProvider(
                scrollbarBuilder: (context) {
                  inheritedFromBuilderContext = ElViewProvider.scrollbarOf(context);
                  return const ElWindowScrollBar();
                },
                child: Builder(
                  builder: (context) {
                    innerResolved = ElViewProvider.scrollbarOf(context);
                    return const SizedBox();
                  },
                ),
              ),
              ElViewProvider(
                scrollbarBuilder: (_) => null,
                child: Builder(
                  builder: (context) {
                    nullResolved = ElViewProvider.scrollbarOf(context);
                    return const SizedBox();
                  },
                ),
              ),
              Builder(
                builder: (context) {
                  siblingResolved = ElViewProvider.scrollbarOf(context);
                  return const SizedBox();
                },
              ),
            ],
          ),
        ),
      ),
    );

    expect(inheritedFromBuilderContext, isA<ElNoScrollBar>());
    expect(innerResolved, isA<ElWindowScrollBar>());
    expect(nullResolved, isA<ElNoScrollBar>());
    expect(siblingResolved, isA<ElNoScrollBar>());
  });

  testWidgets('builder 从具体值切回 null 不会重挂子树', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    var override = true;
    late StateSetter setHostState;

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          setHostState = setState;
          return Directionality(
            textDirection: TextDirection.ltr,
            child: ElViewProvider(
              scrollbarBuilder: (_) => override ? const ElNoScrollBar() : null,
              child: const _MountProbe(),
            ),
          );
        },
      ),
    );

    final before = tester.state(find.byType(_MountProbe));
    setHostState(() => override = false);
    await tester.pump();
    final after = tester.state(find.byType(_MountProbe));

    debugDefaultTargetPlatformOverride = null;
    expect(identical(after, before), isTrue);
  });

  testWidgets('InheritedModel 只通知发生变化的 aspect', (tester) async {
    var useWindowsScrollbar = false;
    var selectionBuildCount = 0;
    late StateSetter setHostState;
    final selectionProbe = _RefresherAspectProbe(onBuild: () => selectionBuildCount++);

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          setHostState = setState;
          return Directionality(
            textDirection: TextDirection.ltr,
            child: ElViewProvider(
              scrollbarBuilder: (_) => useWindowsScrollbar ? const ElWindowScrollBar() : const ElNoScrollBar(),
              child: selectionProbe,
            ),
          );
        },
      ),
    );

    expect(selectionBuildCount, 1);
    setHostState(() => useWindowsScrollbar = true);
    await tester.pump();
    expect(selectionBuildCount, 1);
  });

  testWidgets('三类滚动环境实现均支持局部覆写', (tester) async {
    late ElScrollbar scrollbar;
    late ElRefresher refresher;
    late ElSmoothScroll? smoothScroll;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ElViewProvider(
          scrollbarBuilder: (_) => const ElNoScrollBar(),
          refresherBuilder: (_) => const ElNoRefresher(),
          smoothScrollBuilder: (_) => const ElNoSmoothScroll(),
          child: Builder(
            builder: (context) {
              scrollbar = ElViewProvider.scrollbarOf(context);
              refresher = ElViewProvider.refresherOf(context);
              smoothScroll = ElViewProvider.smoothScrollOf(context);
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    expect(scrollbar, isA<ElNoScrollBar>());
    expect(refresher, isA<ElNoRefresher>());
    expect(smoothScroll, isA<ElNoSmoothScroll>());
  });
}

class _RefresherAspectProbe extends StatelessWidget {
  const _RefresherAspectProbe({required this.onBuild});

  final VoidCallback onBuild;

  @override
  Widget build(BuildContext context) {
    ElViewProvider.refresherOf(context);
    onBuild();
    return const SizedBox();
  }
}

class _MountProbe extends StatefulWidget {
  const _MountProbe();

  @override
  State<_MountProbe> createState() => _MountProbeState();
}

class _MountProbeState extends State<_MountProbe> {
  @override
  Widget build(BuildContext context) => const SizedBox();
}
