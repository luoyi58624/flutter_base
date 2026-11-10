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

    late ElRefresher refresher;
    late SelectionControls controls;
    ElSmoothScroll? smoothScroll;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Builder(
          builder: (context) {
            refresher = ElViewProvider.refresherOf(context);
            controls = SelectionControlsScope.of(context);
            smoothScroll = ElViewProvider.smoothScrollOf(context);
            return SizedBox();
          },
        ),
      ),
    );

    debugDefaultTargetPlatformOverride = null;
    expect(refresher, isA<ElAndroidRefresher>());
    expect(controls, isA<AndroidSelectionControls>());
    expect(smoothScroll, isNull);
  });

  testWidgets('builder 覆写当前子树，返回 null 时继续继承祖先', (tester) async {
    late ElRefresher inheritedFromBuilderContext;
    late ElRefresher innerResolved;
    late ElRefresher nullResolved;
    late ElRefresher siblingResolved;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ElViewProvider(
          refresherBuilder: (_) => ElNoRefresher(),
          child: Column(
            children: [
              ElViewProvider(
                refresherBuilder: (context) {
                  inheritedFromBuilderContext = ElViewProvider.refresherOf(context);
                  return ElIosRefresher();
                },
                child: Builder(
                  builder: (context) {
                    innerResolved = ElViewProvider.refresherOf(context);
                    return SizedBox();
                  },
                ),
              ),
              ElViewProvider(
                refresherBuilder: (_) => null,
                child: Builder(
                  builder: (context) {
                    nullResolved = ElViewProvider.refresherOf(context);
                    return SizedBox();
                  },
                ),
              ),
              Builder(
                builder: (context) {
                  siblingResolved = ElViewProvider.refresherOf(context);
                  return SizedBox();
                },
              ),
            ],
          ),
        ),
      ),
    );

    expect(inheritedFromBuilderContext, isA<ElNoRefresher>());
    expect(innerResolved, isA<ElIosRefresher>());
    expect(nullResolved, isA<ElNoRefresher>());
    expect(siblingResolved, isA<ElNoRefresher>());
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
            child: ElViewProvider(refresherBuilder: (_) => override ? ElNoRefresher() : null, child: _MountProbe()),
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
    var smooth = false;
    var refresherBuildCount = 0;
    late StateSetter setHostState;
    final refresherProbe = _RefresherAspectProbe(onBuild: () => refresherBuildCount++);

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          setHostState = setState;
          return Directionality(
            textDirection: TextDirection.ltr,
            child: ElViewProvider(
              smoothScrollBuilder: (_) => smooth ? ElChromiumSmoothScroll() : null,
              child: refresherProbe,
            ),
          );
        },
      ),
    );

    expect(refresherBuildCount, 1);
    setHostState(() => smooth = true);
    await tester.pump();
    expect(refresherBuildCount, 1);
  });

  testWidgets('刷新器与平滑滚动均支持局部覆写', (tester) async {
    late ElRefresher refresher;
    late ElSmoothScroll? smoothScroll;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ElViewProvider(
          refresherBuilder: (_) => ElNoRefresher(),
          smoothScrollBuilder: (_) => null,
          child: Builder(
            builder: (context) {
              refresher = ElViewProvider.refresherOf(context);
              smoothScroll = ElViewProvider.smoothScrollOf(context);
              return SizedBox();
            },
          ),
        ),
      ),
    );

    expect(refresher, isA<ElNoRefresher>());
    expect(smoothScroll, isNull);
  });
}

class _RefresherAspectProbe extends StatelessWidget {
  const _RefresherAspectProbe({required this.onBuild});

  final VoidCallback onBuild;

  @override
  Widget build(BuildContext context) {
    ElViewProvider.refresherOf(context);
    onBuild();
    return SizedBox();
  }
}

class _MountProbe extends StatefulWidget {
  const _MountProbe();

  @override
  State<_MountProbe> createState() => _MountProbeState();
}

class _MountProbeState extends State<_MountProbe> {
  @override
  Widget build(BuildContext context) => SizedBox();
}
