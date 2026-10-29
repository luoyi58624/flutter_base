import '../../support/overlay.dart';
import '../../support/portal.dart';

import 'package:flutter_base/src/ui/testing/ui_test_api.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _pageTopKey = ValueKey('page-top');
const _pageBottomKey = ValueKey('page-bottom');
const _dialogTextKey = ValueKey('dialog-text');
const _popoverTextKey = ValueKey('popover-text');
const _islandTextKey = ValueKey('island-text');
const _popoverTailKey = ValueKey('popover-tail');
const _mutableFirstKey = ValueKey('mutable-first');
const _mutableMiddleKey = ValueKey('mutable-middle');
const _mutableLastKey = ValueKey('mutable-last');
const _richPopoverKey = ValueKey('rich-popover');
const _richAtomKey = ValueKey('rich-atom');
const _editableHeadKey = ValueKey('editable-head');
const _editableFrameKey = ValueKey('editable-frame');
ValueKey<String> _virtualRowKey(int index) => ValueKey<String>('nested-virtual-row-$index');

Widget _app(ElSelectionController pageController) {
  return MaterialApp(
    home: ElTestOverlay(
      child: ElTestPortal(
        child: ElSelectionView(
          controller: pageController,
          child: const ElView(
            style: ElStyle(width: 520, height: 420, alignment: .topLeft),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ElView(key: _pageTopKey, child: 'page alpha'),
                ElView(style: ElStyle(height: 260)),
                ElView(key: _pageBottomKey, child: 'page omega'),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

ElPortalController _showDialog(WidgetTester tester) {
  final context = tester.element(find.byKey(_pageTopKey));
  return ElTestPortal.of(context).show(
    align: Alignment.topLeft,
    offset: const Offset(24, 24),
    builder: (_) => ElSelectionView(
      child: const ElView(
        style: ElStyle(width: 360, height: 260, alignment: .topLeft),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ElView(key: _dialogTextKey, child: 'dialog alpha'),
            ElView(style: ElStyle(height: 200)),
          ],
        ),
      ),
    ),
  );
}

ElPortalController _showPopover(WidgetTester tester) {
  final context = tester.element(find.byKey(_dialogTextKey));
  return ElTestPortal.of(context).show(
    align: Alignment.topLeft,
    offset: const Offset(56, 72),
    builder: (_) => ElSelectionView(
      child: ElView(
        style: const ElStyle(width: 280, height: 150, alignment: .topLeft),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ElView(key: _popoverTextKey, child: 'popover plain'),
            const SelectionIsland(
              child: ElView(key: _islandTextKey, child: 'editable content'),
            ),
            const ElView(key: _popoverTailKey, child: 'popover tail'),
          ],
        ),
      ),
    ),
  );
}

ElPortalController _showDynamicPopover(
  WidgetTester tester, {
  required GlobalKey<_DynamicPopoverContentState> key,
  required ElSelectionController popoverController,
  required bool initiallyIslandEnabled,
}) {
  final context = tester.element(find.byKey(_dialogTextKey));
  return ElTestPortal.of(context).show(
    align: Alignment.topLeft,
    offset: const Offset(56, 72),
    builder: (_) => _DynamicPopoverContent(
      key: key,
      popoverController: popoverController,
      initiallyIslandEnabled: initiallyIslandEnabled,
    ),
  );
}

class _DynamicPopoverContent extends StatefulWidget {
  const _DynamicPopoverContent({super.key, required this.popoverController, required this.initiallyIslandEnabled});

  final ElSelectionController popoverController;
  final bool initiallyIslandEnabled;

  @override
  State<_DynamicPopoverContent> createState() => _DynamicPopoverContentState();
}

class _DynamicPopoverContentState extends State<_DynamicPopoverContent> {
  late bool islandEnabled;

  @override
  void initState() {
    super.initState();
    islandEnabled = widget.initiallyIslandEnabled;
  }

  void setIslandEnabled(bool value) => setState(() => islandEnabled = value);

  @override
  Widget build(BuildContext context) {
    return ElSelectionView(
      controller: widget.popoverController,
      child: ElView(
        style: const ElStyle(width: 280, height: 150, alignment: .topLeft),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ElView(key: _popoverTextKey, child: 'popover plain'),
            SelectionIsland(
              enabled: islandEnabled,
              child: const ElView(key: _islandTextKey, child: 'editable content'),
            ),
            const ElView(key: _popoverTailKey, child: 'popover tail'),
          ],
        ),
      ),
    );
  }
}

ElPortalController _showMutablePopover(
  WidgetTester tester, {
  required GlobalKey<_MutablePopoverContentState> key,
  required ElSelectionController controller,
}) {
  final context = tester.element(find.byKey(_dialogTextKey));
  return ElTestPortal.of(context).show(
    align: Alignment.topLeft,
    offset: const Offset(56, 72),
    builder: (_) => _MutablePopoverContent(key: key, controller: controller),
  );
}

class _MutablePopoverContent extends StatefulWidget {
  const _MutablePopoverContent({super.key, required this.controller});

  final ElSelectionController controller;

  @override
  State<_MutablePopoverContent> createState() => _MutablePopoverContentState();
}

class _MutablePopoverContentState extends State<_MutablePopoverContent> {
  bool showMiddle = true;

  void setMiddleVisible(bool value) => setState(() => showMiddle = value);

  @override
  Widget build(BuildContext context) {
    return ElSelectionView(
      controller: widget.controller,
      child: ElView(
        style: const ElStyle(width: 280, height: 150, alignment: .topLeft),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ElView(key: _mutableFirstKey, child: 'alpha item'),
            if (showMiddle) const ElView(key: _mutableMiddleKey, child: 'bravo item'),
            const ElView(key: _mutableLastKey, child: 'charlie item'),
          ],
        ),
      ),
    );
  }
}

ElPortalController _showRichPopover(WidgetTester tester, ElSelectionController controller) {
  final context = tester.element(find.byKey(_dialogTextKey));
  return ElTestPortal.of(context).show(
    align: Alignment.topLeft,
    offset: const Offset(56, 72),
    builder: (_) => ElSelectionView(
      controller: controller,
      child: const ElView(
        key: _richPopoverKey,
        style: ElStyle(width: 300, height: 80, alignment: .topLeft, fontSize: 14, lineHeight: 1.5),
        child: [
          'rich ',
          TextSpan(
            text: 'inline',
            style: TextStyle(color: Color(0xff0066cc)),
          ),
          ' ',
          TextSpan(
            children: [
              TextSpan(text: 'span '),
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: SizedBox(key: _richAtomKey, width: 8, height: 8),
              ),
              TextSpan(text: ' atom'),
            ],
          ),
        ],
      ),
    ),
  );
}

ElPortalController _showEditablePopover(
  WidgetTester tester, {
  required ElSelectionController popoverController,
  required EditableController editableController,
}) {
  final context = tester.element(find.byKey(_dialogTextKey));
  return ElTestPortal.of(context).show(
    align: Alignment.topLeft,
    offset: const Offset(56, 72),
    builder: (_) => ElSelectionView(
      controller: popoverController,
      child: ElView(
        style: const ElStyle(width: 300, height: 110, alignment: .topLeft),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ElView(key: _editableHeadKey, child: 'edit head'),
            ElView(
              key: _editableFrameKey,
              style: const ElStyle(width: 280, height: 42),
              child: EditableView(
                controller: editableController,
                style: EditableConfiguration(
                  textStyle: const TextStyle(fontSize: 10, height: 1.0, color: Color(0xff000000)),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

ElPortalController _showVirtualPopover(
  WidgetTester tester, {
  required ElSelectionController popoverController,
  required ScrollController scrollController,
}) {
  final context = tester.element(find.byKey(_dialogTextKey));
  return ElTestPortal.of(context).show(
    align: Alignment.topLeft,
    offset: const Offset(56, 72),
    builder: (_) => SizedBox(
      width: 300,
      height: 120,
      child: ElSelectionView(
        controller: popoverController,
        child: ElScrollView(
          controller: scrollController,
          cacheExtent: 0,
          physics: const ClampingScrollPhysics(),
          children: [
            ElListView.builder(
              itemCount: 40,
              itemBuilder: (context, index) => ElView(
                key: _virtualRowKey(index),
                style: const ElStyle(width: 260, height: 32),
                child: 'virtual row $index',
              ),
              fixedSize: true,
            ),
          ],
        ),
      ),
    ),
  );
}

SelectionParticipant _participant(WidgetTester tester, Key key) {
  return selectionParticipantOf(tester.renderObject(find.byKey(key)))!;
}

RenderSelectionView _rootOf(WidgetTester tester, Key key) {
  return _participant(tester, key).selectionAppearance! as RenderSelectionView;
}

TextRange? _rangeOf(WidgetTester tester, Key key) {
  return _participant(tester, key).currentSelectionRange;
}

Future<void> _mouseDrag(WidgetTester tester, Offset from, Offset to) async {
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  addTearDown(gesture.removePointer);
  await gesture.down(from);
  await tester.pump(const Duration(milliseconds: 16));
  await gesture.moveTo(to);
  await tester.pump(const Duration(milliseconds: 16));
  await gesture.up();
  await tester.pump(const Duration(milliseconds: 16));
}

Future<void> _buildFourLayerCase(WidgetTester tester, {required ElSelectionController pageController}) async {
  await tester.pumpWidget(_app(pageController));
  _showDialog(tester);
  await tester.pump();
  await tester.pump();
  _showPopover(tester);
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('四层嵌套：popover 顺向拖选贯穿选区岛，不下溢到 dialog/page', (tester) async {
    final pageController = ElSelectionController();
    addTearDown(pageController.dispose);
    await _buildFourLayerCase(tester, pageController: pageController);

    final popoverRoot = _rootOf(tester, _popoverTextKey);
    final dialogRoot = _rootOf(tester, _dialogTextKey);
    final pageRoot = _rootOf(tester, _pageTopKey);
    expect(popoverRoot, isNot(same(dialogRoot)));
    expect(dialogRoot, isNot(same(pageRoot)));

    final from = tester.getRect(find.byKey(_popoverTextKey)).centerLeft + const Offset(1, 0);
    final to = tester.getRect(find.byKey(_popoverTailKey)).centerRight - const Offset(1, 0);
    await _mouseDrag(tester, from, to);

    expect(popoverRoot.selectionInfo, 'popover plain\neditable content\npopover tail');
    expect(_rangeOf(tester, _popoverTextKey), const TextRange(start: 0, end: 13));
    expect(_rangeOf(tester, _islandTextKey), const TextRange(start: 0, end: 16));
    expect(_rangeOf(tester, _popoverTailKey), const TextRange(start: 0, end: 12));
    expect(_rangeOf(tester, _dialogTextKey), isNull);
    expect(pageController.text, isNull);
  });

  testWidgets('四层嵌套：popover 反向拖选同样贯穿选区岛', (tester) async {
    final pageController = ElSelectionController();
    addTearDown(pageController.dispose);
    await _buildFourLayerCase(tester, pageController: pageController);

    final popoverRoot = _rootOf(tester, _popoverTailKey);
    final from = tester.getRect(find.byKey(_popoverTailKey)).centerRight - const Offset(1, 0);
    final to = tester.getRect(find.byKey(_popoverTextKey)).centerLeft + const Offset(1, 0);
    await _mouseDrag(tester, from, to);

    expect(popoverRoot.selectionInfo, 'popover plain\neditable content\npopover tail');
    expect(_rangeOf(tester, _popoverTailKey), const TextRange(start: 0, end: 12));
    expect(_rangeOf(tester, _islandTextKey), const TextRange(start: 0, end: 16));
    expect(_rangeOf(tester, _popoverTextKey), const TextRange(start: 0, end: 13));
    expect(_rangeOf(tester, _dialogTextKey), isNull);
    expect(pageController.text, isNull);
  });

  testWidgets('四层嵌套：关闭 dialog owner 递归清理 popover 选区，不恢复到底层', (tester) async {
    final pageController = ElSelectionController();
    addTearDown(pageController.dispose);
    await tester.pumpWidget(_app(pageController));
    final dialogEntry = _showDialog(tester);
    await tester.pump();
    await tester.pump();
    _showPopover(tester);
    await tester.pump();
    await tester.pump();

    final popoverRoot = _rootOf(tester, _popoverTextKey);
    final from = tester.getRect(find.byKey(_popoverTextKey)).centerLeft + const Offset(1, 0);
    final to = tester.getRect(find.byKey(_popoverTailKey)).centerRight - const Offset(1, 0);
    await _mouseDrag(tester, from, to);
    expect(popoverRoot.selectionInfo, 'popover plain\neditable content\npopover tail');
    expect(pageController.text, isNull);

    dialogEntry.close();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.byKey(_dialogTextKey), findsNothing);
    expect(find.byKey(_popoverTextKey), findsNothing);
    expect(find.byKey(_islandTextKey), findsNothing);
    expect(find.byKey(_popoverTailKey), findsNothing);
    expect(pageController.text, isNull);
  });

  testWidgets('四层嵌套：SelectionIsland.enabled 动态切换只改变内部起手权', (tester) async {
    final pageController = ElSelectionController();
    final popoverController = ElSelectionController();
    final dynamicKey = GlobalKey<_DynamicPopoverContentState>();
    addTearDown(pageController.dispose);
    addTearDown(popoverController.dispose);
    await tester.pumpWidget(_app(pageController));
    _showDialog(tester);
    await tester.pump();
    await tester.pump();
    _showDynamicPopover(tester, key: dynamicKey, popoverController: popoverController, initiallyIslandEnabled: true);
    await tester.pump();
    await tester.pump();

    final popoverRoot = _rootOf(tester, _popoverTextKey);
    expect(_rootOf(tester, _islandTextKey), same(popoverRoot));
    final islandStart = tester.getRect(find.byKey(_islandTextKey)).centerLeft + const Offset(1, 0);
    final islandEnd = tester.getRect(find.byKey(_islandTextKey)).centerRight - const Offset(1, 0);
    final popoverTailEnd = tester.getRect(find.byKey(_popoverTailKey)).centerRight - const Offset(1, 0);
    await _mouseDrag(tester, islandStart, popoverTailEnd);
    expect(popoverController.text, isNull, reason: '选区岛内起手时 popover 外层必须弃权');

    dynamicKey.currentState!.setIslandEnabled(false);
    await tester.pump();
    expect(_rootOf(tester, _islandTextKey), same(popoverRoot));
    await _mouseDrag(tester, islandStart, popoverTailEnd);
    expect(popoverController.text, 'editable content\npopover tail');
    expect(popoverRoot.selectionInfo, 'editable content\npopover tail');
    expect(_rangeOf(tester, _islandTextKey), const TextRange(start: 0, end: 16));
    expect(_rangeOf(tester, _popoverTailKey), const TextRange(start: 0, end: 12));
    expect(pageController.text, isNull);

    popoverRoot.clearSelection();
    dynamicKey.currentState!.setIslandEnabled(true);
    await tester.pump();
    expect(_rootOf(tester, _islandTextKey), same(popoverRoot));
    final popoverStart = tester.getRect(find.byKey(_popoverTextKey)).centerLeft + const Offset(1, 0);
    await _mouseDrag(tester, popoverStart, popoverTailEnd);
    expect(popoverRoot.selectionInfo, 'popover plain\neditable content\npopover tail');
    expect(_rangeOf(tester, _popoverTextKey), const TextRange(start: 0, end: 13));
    expect(_rangeOf(tester, _islandTextKey), const TextRange(start: 0, end: 16));
    expect(_rangeOf(tester, _popoverTailKey), const TextRange(start: 0, end: 12));
    popoverRoot.clearSelection();

    await _mouseDrag(tester, islandStart, islandEnd);
    expect(popoverController.text, isNull);
    expect(_rangeOf(tester, _popoverTextKey), isNull);
    expect(_rangeOf(tester, _islandTextKey), isNull);
    expect(_rangeOf(tester, _dialogTextKey), isNull);
    expect(pageController.text, isNull);
  });

  testWidgets(
    '四层嵌套：selection 中删除/插入 participant 后范围按现存文档序更新',
    (tester) async {
      final pageController = ElSelectionController();
      final popoverController = ElSelectionController();
      final mutableKey = GlobalKey<_MutablePopoverContentState>();
      addTearDown(pageController.dispose);
      addTearDown(popoverController.dispose);
      await tester.pumpWidget(_app(pageController));
      _showDialog(tester);
      await tester.pump();
      await tester.pump();
      _showMutablePopover(tester, key: mutableKey, controller: popoverController);
      await tester.pump();
      await tester.pump();

      final root = _rootOf(tester, _mutableFirstKey);
      final from = tester.getRect(find.byKey(_mutableFirstKey)).centerLeft + const Offset(1, 0);
      final to = tester.getRect(find.byKey(_mutableLastKey)).centerRight - const Offset(1, 0);
      await _mouseDrag(tester, from, to);
      expect(popoverController.text, 'alpha item\nbravo item\ncharlie item');
      expect(root.selectionInfo, 'alpha item\nbravo item\ncharlie item');
      expect(_rangeOf(tester, _mutableFirstKey), const TextRange(start: 0, end: 10));
      expect(_rangeOf(tester, _mutableMiddleKey), const TextRange(start: 0, end: 10));
      expect(_rangeOf(tester, _mutableLastKey), const TextRange(start: 0, end: 12));
      expect(pageController.text, isNull);

      mutableKey.currentState!.setMiddleVisible(false);
      await tester.pump();
      expect(find.byKey(_mutableMiddleKey), findsNothing);
      expect(popoverController.text, 'alpha item\ncharlie item');
      expect(root.selectionInfo, 'alpha item\ncharlie item');
      expect(_rangeOf(tester, _mutableFirstKey), const TextRange(start: 0, end: 10));
      expect(_rangeOf(tester, _mutableLastKey), const TextRange(start: 0, end: 12));
      expect(_rangeOf(tester, _dialogTextKey), isNull);
      expect(pageController.text, isNull);

      mutableKey.currentState!.setMiddleVisible(true);
      await tester.pump();
      await tester.pump();
      expect(_rootOf(tester, _mutableMiddleKey), same(root));
      expect(popoverController.text, 'alpha item\nbravo item\ncharlie item');
      expect(root.selectionInfo, 'alpha item\nbravo item\ncharlie item');
      expect(_rangeOf(tester, _mutableFirstKey), const TextRange(start: 0, end: 10));
      expect(_rangeOf(tester, _mutableMiddleKey), const TextRange(start: 0, end: 10));
      expect(_rangeOf(tester, _mutableLastKey), const TextRange(start: 0, end: 12));
      expect(pageController.text, isNull);
    },
  );

  testWidgets('四层嵌套：popover 富文本 inline/atomic 只写入自身 root', (tester) async {
    final pageController = ElSelectionController();
    final popoverController = ElSelectionController();
    addTearDown(pageController.dispose);
    addTearDown(popoverController.dispose);
    await tester.pumpWidget(_app(pageController));
    _showDialog(tester);
    await tester.pump();
    await tester.pump();
    _showRichPopover(tester, popoverController);
    await tester.pump();
    await tester.pump();

    final root = _rootOf(tester, _richPopoverKey);
    final render = tester.renderObject<ElRenderView>(find.byKey(_richPopoverKey));
    final engine = render.textEngineForTest!;
    final text = engine.painterForTest.text!.toPlainText();
    expect(text, 'rich inline span ￼ atom');

    expect(engine.structure.spans, hasLength(1));
    expect(find.byKey(_richAtomKey), findsOneWidget);

    final firstBox = render.textEngineForTest!.getBoxesForSelectionForTest(0, 1).first.toRect();
    final atomEnd = text.indexOf('atom') + 'atom'.length;
    final lastBox = render.textEngineForTest!.getBoxesForSelectionForTest(atomEnd - 1, atomEnd).last.toRect();
    await _mouseDrag(
      tester,
      render.localToGlobal(render.contentOrigin + firstBox.centerLeft + const Offset(1, 0)),
      render.localToGlobal(render.contentOrigin + lastBox.centerRight - const Offset(1, 0)),
    );
    expect(popoverController.text, 'rich inline span  atom');
    expect(root.selectionInfo, 'rich inline span  atom');
    expect(_rangeOf(tester, _richPopoverKey), const TextRange(start: 0, end: 23));
    expect(_rangeOf(tester, _dialogTextKey), isNull);
    expect(pageController.text, isNull);
  });

  testWidgets('四层嵌套：popover 外层拖入 editable 行只写入自身 root', (tester) async {
    final pageController = ElSelectionController();
    final popoverController = ElSelectionController();
    final editableController = EditableController(text: 'first editable\nsecond editable');
    addTearDown(pageController.dispose);
    addTearDown(popoverController.dispose);
    addTearDown(editableController.dispose);
    await tester.pumpWidget(_app(pageController));
    _showDialog(tester);
    await tester.pump();
    await tester.pump();
    _showEditablePopover(tester, popoverController: popoverController, editableController: editableController);
    await tester.pump();
    await tester.pump();

    final root = _rootOf(tester, _editableHeadKey);
    final line = tester.renderObject<RenderEditableLine>(find.byType(EditableLineView).first);
    expect(line.selectionParticipant!.selectionAppearance!, same(root));

    final from = tester.getRect(find.byKey(_editableHeadKey)).centerLeft + const Offset(1, 0);
    final editor = tester.getRect(find.byKey(_editableFrameKey));
    await _mouseDrag(tester, from, editor.topLeft + const Offset(145, 5));
    expect(popoverController.text, 'edit head\nfirst editable');
    expect(root.selectionInfo, 'edit head\nfirst editable');
    expect(_rangeOf(tester, _editableHeadKey), const TextRange(start: 0, end: 9));
    expect(line.selectionParticipant!.currentSelectionRange, const TextRange(start: 0, end: 14));
    expect(_rangeOf(tester, _dialogTextKey), isNull);
    expect(pageController.text, isNull);
  });

  testWidgets('四层嵌套：popover 当前虚拟行可重新拖选且不下溢', (tester) async {
    final pageController = ElSelectionController();
    final popoverController = ElSelectionController();
    final scrollController = ScrollController();
    addTearDown(pageController.dispose);
    addTearDown(popoverController.dispose);
    addTearDown(scrollController.dispose);
    await tester.pumpWidget(_app(pageController));
    _showDialog(tester);
    await tester.pump();
    await tester.pump();
    _showVirtualPopover(tester, popoverController: popoverController, scrollController: scrollController);
    await tester.pump();
    await tester.pump();

    final root = _rootOf(tester, _virtualRowKey(1));
    final first = _participant(tester, _virtualRowKey(1));
    expect(first.selectionAppearance!, same(root));

    scrollController.jumpTo(640);
    await tester.pump();
    expect(find.byKey(_virtualRowKey(1)), findsNothing);
    expect(find.byKey(_virtualRowKey(2)), findsNothing);
    expect(_rangeOf(tester, _dialogTextKey), isNull);
    expect(pageController.text, isNull);

    scrollController.jumpTo(0);
    await tester.pump();
    final remounted = _participant(tester, _virtualRowKey(1));
    expect(remounted, isNot(same(first)), reason: '销毁后新节点按普通挂载重新参与');
    expect(remounted.selectionAppearance!, same(root));

    final from = tester.getRect(find.byKey(_virtualRowKey(1))).centerLeft + const Offset(1, 0);
    final to = tester.getRect(find.byKey(_virtualRowKey(2))).centerRight - const Offset(1, 0);
    await _mouseDrag(tester, from, to);
    expect(popoverController.text, 'virtual row 1\nvirtual row 2');
    expect(_rangeOf(tester, _virtualRowKey(1)), const TextRange(start: 0, end: 13));
    expect(_rangeOf(tester, _virtualRowKey(2)), const TextRange(start: 0, end: 13));
    expect(_rangeOf(tester, _dialogTextKey), isNull);
    expect(pageController.text, isNull);
  });

  testWidgets('四层嵌套：选区岛内起手拖向同层或祖先均不写入任何选区', (tester) async {
    final pageController = ElSelectionController();
    addTearDown(pageController.dispose);
    await _buildFourLayerCase(tester, pageController: pageController);

    final popoverRoot = _rootOf(tester, _popoverTextKey);
    final blockRect = tester.getRect(find.byKey(_islandTextKey));
    await _mouseDrag(
      tester,
      blockRect.centerLeft + const Offset(1, 0),
      tester.getRect(find.byKey(_dialogTextKey)).centerRight - const Offset(1, 0),
    );
    expect(popoverRoot.selectionInfo, isNull);
    expect(_rangeOf(tester, _dialogTextKey), isNull);
    expect(pageController.text, isNull);

    await _mouseDrag(
      tester,
      blockRect.centerRight - const Offset(1, 0),
      tester.getRect(find.byKey(_popoverTextKey)).centerLeft + const Offset(1, 0),
    );
    expect(popoverRoot.selectionInfo, isNull);
    expect(_rangeOf(tester, _popoverTextKey), isNull);
    expect(_rangeOf(tester, _popoverTailKey), isNull);
    expect(_rangeOf(tester, _dialogTextKey), isNull);
    expect(_rangeOf(tester, _pageTopKey), isNull);
    expect(pageController.text, isNull);
  });
}
