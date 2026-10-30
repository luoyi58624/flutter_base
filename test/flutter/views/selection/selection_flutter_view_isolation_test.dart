import '../../../ui/support/overlay.dart';
import '../../../ui/support/portal.dart';
import 'package:flutter_base/src/ui/testing/ui_test_api.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const _firstPageKey = ValueKey<String>('view-a-page');
const _secondPageKey = ValueKey<String>('view-b-page');
const _firstOverlayKey = ValueKey<String>('view-a-overlay');
const _secondOverlayKey = ValueKey<String>('view-b-overlay');

class _SecondaryFlutterView extends TestFlutterView {
  _SecondaryFlutterView({
    required super.view,
    required super.platformDispatcher,
    required super.display,
    required this.id,
  });

  final int id;

  @override
  int get viewId => id;
}

Widget _viewBody({required Key pageKey, required String text, required ElSelectionController controller}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: MediaQuery(
      data: const MediaQueryData(size: Size(800, 600)),
      child: ElTestOverlay(
        child: ElTestPortal(
          child: ElSelectionView(
            controller: controller,
            child: ElView(
              key: pageKey,
              style: const ElStyle(width: 400, height: 300, alignment: .topLeft),
              child: text,
            ),
          ),
        ),
      ),
    ),
  );
}

Widget _views({
  required FlutterView firstView,
  required FlutterView secondView,
  required ElSelectionController firstController,
  required ElSelectionController secondController,
  required bool includeSecond,
}) {
  return ViewCollection(
    views: [
      View(
        key: const ValueKey<String>('view-a'),
        view: firstView,
        child: _viewBody(pageKey: _firstPageKey, text: 'alpha view', controller: firstController),
      ),
      if (includeSecond)
        View(
          key: const ValueKey<String>('view-b'),
          view: secondView,
          child: _viewBody(pageKey: _secondPageKey, text: 'bravo view', controller: secondController),
        ),
    ],
  );
}

RenderSelectionView _rootOf(WidgetTester tester, Key key) {
  final participant = selectionParticipantOf(tester.renderObject(find.byKey(key)))!;
  return participant.selectionAppearance! as RenderSelectionView;
}

ElPortalController _insert(WidgetTester tester, Key sourceKey, Key overlayKey, String text) {
  final source = tester.element(find.byKey(sourceKey));
  return ElTestPortal.of(source).show(
    builder: (_) => ElSelectionView(
      child: ElView(key: overlayKey, style: const ElStyle(width: 180, height: 80), child: text),
    ),
  );
}

Future<void> _clickInView(WidgetTester tester, Finder target, FlutterView view, int pointer) async {
  final testPointer = TestPointer(pointer, PointerDeviceKind.mouse);
  final position = tester.getCenter(target);
  await tester.sendEventToBinding(testPointer.down(position, view: view));
  await tester.sendEventToBinding(testPointer.up(view: view));
  await tester.pump();
}

void main() {
  testWidgets('两个 Flutter View 使用显式局部选区，关闭一侧不影响另一侧', (tester) async {
    final firstController = ElSelectionController();
    final secondController = ElSelectionController();
    final secondaryView = _SecondaryFlutterView(
      view: tester.view,
      platformDispatcher: tester.platformDispatcher,
      display: tester.view.display,
      id: tester.view.viewId + 1,
    );
    addTearDown(firstController.dispose);
    addTearDown(secondController.dispose);
    await tester.pumpWidget(
      _views(
        firstView: tester.view,
        secondView: secondaryView,
        firstController: firstController,
        secondController: secondController,
        includeSecond: true,
      ),
      wrapWithView: false,
    );

    firstController.selectAll();
    secondController.selectAll();
    await tester.pump();
    expect(firstController.text, 'alpha view');
    expect(secondController.text, 'bravo view');

    final firstEntry = _insert(tester, _firstPageKey, _firstOverlayKey, 'first overlay');
    final secondEntry = _insert(tester, _secondPageKey, _secondOverlayKey, 'second overlay');
    await tester.pump();
    await tester.pump();

    await _clickInView(tester, find.byKey(_firstOverlayKey), tester.view, 41);

    await _clickInView(tester, find.byKey(_secondOverlayKey), secondaryView, 42);

    expect(firstController.text, 'alpha view');
    expect(secondController.text, 'bravo view');

    secondEntry.close();
    await tester.pump();

    expect(firstEntry.isOpen, isTrue);
  });

  testWidgets('移除并重建第二 Flutter View 不改变第一侧 identity、range 与 entry', (tester) async {
    final firstController = ElSelectionController();
    final secondController = ElSelectionController();
    final secondaryView = _SecondaryFlutterView(
      view: tester.view,
      platformDispatcher: tester.platformDispatcher,
      display: tester.view.display,
      id: tester.view.viewId + 1,
    );
    addTearDown(firstController.dispose);
    addTearDown(secondController.dispose);
    await tester.pumpWidget(
      _views(
        firstView: tester.view,
        secondView: secondaryView,
        firstController: firstController,
        secondController: secondController,
        includeSecond: true,
      ),
      wrapWithView: false,
    );
    final oldSecondPageRoot = _rootOf(tester, _secondPageKey);
    final firstPageRoot = _rootOf(tester, _firstPageKey);
    firstController.selectAll();
    secondController.selectAll();
    final firstEntry = _insert(tester, _firstPageKey, _firstOverlayKey, 'first overlay');
    await tester.pump();
    await tester.pump();
    final firstParticipant = selectionParticipantOf(tester.renderObject(find.byKey(_firstPageKey)));
    final firstOverlayRoot = _rootOf(tester, _firstOverlayKey);

    await tester.pumpWidget(
      _views(
        firstView: tester.view,
        secondView: secondaryView,
        firstController: firstController,
        secondController: secondController,
        includeSecond: false,
      ),
      wrapWithView: false,
    );
    expect(_rootOf(tester, _firstPageKey), same(firstPageRoot));
    expect(_rootOf(tester, _firstOverlayKey), same(firstOverlayRoot));
    expect(selectionParticipantOf(tester.renderObject(find.byKey(_firstPageKey))), same(firstParticipant));
    expect(firstEntry.isOpen, isTrue);
    expect(firstController.text, 'alpha view');
    expect(oldSecondPageRoot.attached, isFalse);
    expect(secondController.text, isNull);

    await tester.pumpWidget(
      _views(
        firstView: tester.view,
        secondView: secondaryView,
        firstController: firstController,
        secondController: secondController,
        includeSecond: true,
      ),
      wrapWithView: false,
    );
    final rebuiltSecondRoot = _rootOf(tester, _secondPageKey);
    expect(rebuiltSecondRoot, isNot(same(oldSecondPageRoot)));

    expect(rebuiltSecondRoot.attached, isTrue);
    expect(secondController.text, isNull, reason: '重建 View 不得继承已销毁 coordinator 的旧 range');
    expect(_rootOf(tester, _firstPageKey), same(firstPageRoot));
    expect(_rootOf(tester, _firstOverlayKey), same(firstOverlayRoot));
    expect(firstEntry.isOpen, isTrue);
    expect(firstController.text, 'alpha view');
  });
}
