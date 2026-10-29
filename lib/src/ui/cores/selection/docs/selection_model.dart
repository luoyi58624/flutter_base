part of 'selection_view.dart';

/// 当前文档唯一的官方注册中心，不合并其他显式文档根。
class SelectionDocument extends StaticSelectionContainerDelegate {
  VoidCallback? onMembersChanged;

  Iterable<Selectable> get members => selectables;

  @override
  SelectionResult dispatchSelectionEvent(SelectionEvent event) {
    final position = switch (event) {
      SelectWordSelectionEvent() => event.globalPosition,
      SelectParagraphSelectionEvent() => event.globalPosition,
      _ => null,
    };
    final target = position == null ? null : selectableAt(position);
    final scope = target is SelectionParticipant ? target.userSelectAllScopeRoot : null;
    if (scope != null) {
      final group = selectables.whereType<SelectionParticipant>().where(
        (member) => identical(member.userSelectAllScopeRoot, scope),
      );
      if (group.isNotEmpty) {
        final start = _participantPosition(group.first, end: false);
        final end = _participantPosition(group.last, end: true);
        super.dispatchSelectionEvent(const ClearSelectionEvent());
        super.dispatchSelectionEvent(SelectionEdgeUpdateEvent.forStart(globalPosition: start));
        return super.dispatchSelectionEvent(SelectionEdgeUpdateEvent.forEnd(globalPosition: end));
      }
    }
    return super.dispatchSelectionEvent(event);
  }

  Offset _participantPosition(SelectionParticipant member, {required bool end}) {
    final caret = member.selectionCaretGeometryAt(end ? member.contentLength : 0);
    if (caret != null) return member.localToGlobal(caret.position + Offset(0, caret.lineHeight / 2));
    final bounds = member.selectionHitTestBounds ?? (Offset.zero & member.size);
    final right = end != (member.selectionTextDirection == TextDirection.rtl);
    return member.localToGlobal(Offset(right ? bounds.right - .001 : bounds.left + .001, bounds.center.dy));
  }

  @override
  void didChangeSelectables() {
    super.didChangeSelectables();
    onMembersChanged?.call();
  }

  @override
  SelectedContent? getSelectedContent() {
    final selected = <String>[];
    var hasSelection = false;
    for (final member in selectables) {
      if (member.value.status != SelectionStatus.uncollapsed) continue;
      final text = member.getSelectedContent()?.plainText;
      if (text == null) continue;
      hasSelection = true;
      if (text.isNotEmpty) selected.add(text);
    }
    return hasSelection ? SelectedContent(plainText: selected.join('\n')) : null;
  }

  /// 官方状态中的真实端点，手势、句柄和复制共享同一份范围。
  SelectionDocumentEdge? edge({required bool end, bool ordered = true}) {
    final start = currentSelectionStartIndex;
    final finish = currentSelectionEndIndex;
    final index = ordered ? (end ? math.max(start, finish) : math.min(start, finish)) : (end ? finish : start);
    if (index < 0 || index >= selectables.length) return null;
    final member = selectables[index];
    final range = member.getSelection();
    if (range == null) return null;
    final useEnd = ordered ? end == (range.endOffset >= range.startOffset) : end;
    final point = useEnd ? member.value.endSelectionPoint : member.value.startSelectionPoint;
    return point == null
        ? null
        : (selectable: member, point: point, offset: useEnd ? range.endOffset : range.startOffset);
  }

  /// 取行内点向官方协议回放，避免 caret 恰落在相邻块边界。
  Offset positionOf(SelectionDocumentEdge edge) {
    var position = edge.point.localPosition - Offset(0, edge.point.lineHeight / 2);
    if (edge.selectable.boundingBoxes case final boxes when boxes.isNotEmpty) {
      final bounds = boxes.reduce((a, b) => a.expandToInclude(b));
      if (bounds.width > .002 && bounds.height > .002) {
        position = Offset(
          position.dx.clamp(bounds.left + .001, bounds.right - .001),
          position.dy.clamp(bounds.top + .001, bounds.bottom - .001),
        );
      }
    }
    return MatrixUtils.transformPoint(edge.selectable.getTransformTo(null), position);
  }

  /// 只在当前官方成员中判断起手内容，不遍历其他文档或整棵渲染树。
  Selectable? selectableAt(Offset global) {
    for (final member in selectables.reversed) {
      final inverse = Matrix4.copy(member.getTransformTo(null));
      if (inverse.invert() == 0) continue;
      final local = MatrixUtils.transformPoint(inverse, global);
      if (member.boundingBoxes.any((bounds) => bounds.contains(local))) return member;
    }
    return null;
  }
}

typedef SelectionDocumentEdge = ({Selectable selectable, SelectionPoint point, int offset});
