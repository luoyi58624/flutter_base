import 'dart:async' show scheduleMicrotask;

import 'package:flutter_base/flutter_base.dart' hide ElIcon;
import 'package:flutter/foundation.dart' show ValueNotifier, listEquals;
import 'package:flutter/scheduler.dart' show SchedulerPhase;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../others/app/index.dart';
import '../icon/index.dart';
import '../../extensions/el.dart';
import '../../extensions/content.dart';
import '../input/metrics.dart';

class _InputTagDelimiterSegment {
  const _InputTagDelimiterSegment(this.text, this.start);

  final String text;
  final int start;
}

class _InputTagDelimiterSplit {
  const _InputTagDelimiterSplit(this.segments, this.remainder);

  final List<_InputTagDelimiterSegment> segments;
  final String remainder;
}

class _InputTagDragSession {
  const _InputTagDragSession({required this.index, required this.value, required this.snapshot, required this.epoch});

  final int index;
  final String value;
  final List<String> snapshot;
  final int epoch;
}

/// 基于 [ElInput] 草稿编辑与 [ElTag] 标签呈现的字符串标签输入框。
///
/// 值通道支持受控 [value]、双向 [modelValue] 与 [ElFormItem] 的 `prop`
/// 绑定。草稿文本、IME、选区、粘贴和 Unicode 字素边界全部由内部唯一的
/// [ElInput] → [ElEditableView] 通道处理；禁用态不挂载 Editable。
///
/// Element 标签输入框主题实现：只服务 [ElementPlusThemeData]，由 barrel 挡住、不经 `element_plus.dart` 导出。
class InputTag extends ElFormModelValue<List<String>> {
  InputTag(this.component, {super.key})
    : super(
        value: component.value ?? (component.modelValue == null ? const <String>[] : null),
        modelValue: component.modelValue,
        onChanged: null,
      );

  final ElInputTag component;

  ElInputTagController? get controller => component.controller;
  ElInputTagTrigger get trigger => component.trigger;
  Pattern? get delimiter => component.delimiter;
  bool get saveOnBlur => component.saveOnBlur;
  bool? get addOnBlur => component.addOnBlur;
  int? get minLength => component.minLength;
  int? get max => component.max;
  bool get clearable => component.clearable;
  bool get disabled => component.disabled;
  bool get readOnly => component.readOnly;
  String? get placeholder => component.placeholder;
  ElInputTagDuplicatePolicy get duplicatePolicy => component.duplicatePolicy;
  String? Function(String value, List<String> current)? get validate => component.validate;
  void Function(String value, String reason)? get onInvalid => component.onInvalid;
  ValueChanged<String>? get onInput => component.onInput;
  ValueChanged<String>? get onAdd => component.onAdd;
  void Function(String value, int index)? get onRemove => component.onRemove;
  VoidCallback? get onClear => component.onClear;
  void Function(int oldIndex, int newIndex, String value)? get onDragTag => component.onDragTag;
  bool get autofocus => component.autofocus;
  FocusNode? get focusNode => component.focusNode;
  FocusOnKeyEventCallback? get onKeyEvent => component.onKeyEvent;
  VoidCallback? get onFocus => component.onFocus;
  VoidCallback? get onBlur => component.onBlur;
  int? get maxLength => component.maxLength;
  Object? get prefix => component.prefix;
  Object? get suffix => component.suffix;
  Widget Function(BuildContext context, String value, int index, bool selected)? get tagBuilder => component.tagBuilder;
  IconData get clearIcon => component.clearIcon ?? ElIcons.circleClose;
  bool get collapseTags => component.collapseTags;
  int get maxCollapseTags => component.maxCollapseTags;
  bool get collapseTagsTooltip => component.collapseTagsTooltip;
  bool get draggable => component.draggable;
  ElThemeType get tagType => component.tagType;
  ElTagEffect get tagEffect => component.tagEffect;
  ElStyle? get style => component.style;
  ElStyle? get tagStyle => component.tagStyle;
  String? get semanticLabel => component.semanticLabel;
  ValueChanged<List<String>>? get _onChanged => component.onChanged;

  bool get _effectiveSaveOnBlur => addOnBlur ?? saveOnBlur;

  @override
  List<String>? coerceFormValue(Object? raw) {
    if (raw is List<String>) return raw;
    if (raw is Iterable && raw.every((value) => value is String)) {
      return List<String>.unmodifiable(raw.cast<String>());
    }
    return null;
  }

  @override
  Widget obsBuilder(BuildContext context) {
    void updateTags(List<String> next) {
      if (listEquals($obs.value, next)) return;
      final immutable = List<String>.unmodifiable(next);
      $obs.value = immutable;
      _onChanged?.call(immutable);
    }

    return ObsBuilder(
      builder: (context) {
        final form = $formState;
        final prop = $formProp;
        final hasError = form != null && prop != null && form.errorMessages.containsKey(prop);
        return _InputTagBody(
          config: this,
          tags: $obs.value,
          hasError: hasError,
          onTagsChanged: updateTags,
          onBlur: () {
            $formBlurValidate();
            onBlur?.call();
          },
        );
      },
    );
  }
}

class _InputTagBody extends StatefulWidget {
  const _InputTagBody({
    required this.config,
    required this.tags,
    required this.hasError,
    required this.onTagsChanged,
    required this.onBlur,
  });

  final InputTag config;
  final List<String> tags;
  final bool hasError;
  final ValueChanged<List<String>> onTagsChanged;
  final VoidCallback onBlur;

  @override
  State<_InputTagBody> createState() => _InputTagBodyState();
}

class _InputTagBodyState extends State<_InputTagBody> {
  final GlobalKey _fieldKey = GlobalKey(debugLabel: 'ElInputTag field');
  final ElInputController _fieldControl = ElInputController();
  final ElPortalController _collapsePortal = ElPortalController();
  final ValueNotifier<int> _collapseTooltipRevision = ValueNotifier<int>(0);
  late final FocusNode _ownFocusNode;
  String _draft = '';
  int? _selectedTag;
  bool _focusReported = false;
  bool _preservePointerFocus = false;
  bool _preserveSelectionForNextTags = false;
  bool _collapseTooltipInvalidationScheduled = false;
  bool _retainCollapsePortalAnchor = false;
  int _tagsEpoch = 0;
  int _focusBindingGeneration = 0;

  FocusNode get _focusNode => widget.config.focusNode ?? _ownFocusNode;

  bool get _canMutate => !widget.config.disabled && !widget.config.readOnly;

  bool get _canRequestFocus =>
      mounted && !widget.config.disabled && _focusNode.context != null && _focusNode.canRequestFocus;

  @override
  void initState() {
    super.initState();
    _ownFocusNode = FocusNode(debugLabel: 'ElInputTag');
    widget.config.controller?.attach(owner: this, focus: _requestDraftFocus, blur: _blurDraft);
  }

  @override
  void didUpdateWidget(_InputTagBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldFocusNode = oldWidget.config.focusNode ?? _ownFocusNode;
    final nextFocusNode = _focusNode;
    if (widget.config.controller != oldWidget.config.controller) {
      oldWidget.config.controller?.detach(this);
      widget.config.controller?.attach(owner: this, focus: _requestDraftFocus, blur: _blurDraft);
    }
    final tagsChanged = !listEquals(oldWidget.tags, widget.tags);
    if (tagsChanged) {
      _tagsEpoch++;
      if (_selectedTag != null) {
        if (!_preserveSelectionForNextTags || _selectedTag! >= widget.tags.length) {
          _selectedTag = null;
        }
      }
      _preserveSelectionForNextTags = false;
    }
    if (_shouldCloseCollapsePortal(oldWidget, tagsChanged: tagsChanged)) {
      _closeCollapsePortal(retainAnchor: _collapsePortal.isOpen && !_willRenderCollapseTag());
    }
    if (!identical(oldFocusNode, nextFocusNode)) {
      _preservePointerFocus = false;
      final generation = ++_focusBindingGeneration;
      if (!widget.config.disabled) {
        _settleFocusReplacementLater(
          generation,
          nextFocusNode,
          oldWidget.config,
          oldWidget.onBlur,
          tags: oldWidget.tags,
          onTagsChanged: oldWidget.onTagsChanged,
        );
        _handleFocusForNodeLater(nextFocusNode);
      }
    }
    if (widget.config.disabled && !oldWidget.config.disabled) {
      _selectedTag = null;
      _preservePointerFocus = false;
      _completeReportedBlur(
        oldWidget.config,
        oldWidget.onBlur,
        tags: oldWidget.tags,
        onTagsChanged: oldWidget.onTagsChanged,
        deferred: true,
      );
      oldFocusNode.unfocus();
    }
  }

  @override
  void dispose() {
    if (_ownFocusNode.hasFocus) _ownFocusNode.unfocus();
    widget.config.controller?.detach(this);
    _closeCollapsePortal();
    _collapseTooltipRevision.dispose();
    _collapsePortal.dispose();
    _fieldControl.dispose();
    _ownFocusNode.dispose();
    super.dispose();
  }

  @override
  void deactivate() {
    widget.config.controller?.detach(this);
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    widget.config.controller?.attach(owner: this, focus: _requestDraftFocus, blur: _blurDraft);
  }

  void _handleFocus() {
    if (_focusReported) return;
    _focusReported = true;
    widget.config.onFocus?.call();
  }

  void _completeReportedBlur(
    InputTag config,
    VoidCallback onBlur, {
    List<String>? tags,
    ValueChanged<List<String>>? onTagsChanged,
    bool deferred = false,
  }) {
    if (!_focusReported) return;
    _focusReported = false;
    final targetTags = tags ?? widget.tags;
    final targetOnTagsChanged = onTagsChanged ?? widget.onTagsChanged;
    if (deferred) {
      // 父级 didUpdate 早于后代 Editable 结算 composing；第一层微任务让
      // scheduler-safe pending flush 先入队，第二层再读取最终草稿。
      scheduleMicrotask(() {
        scheduleMicrotask(() {
          if (!mounted) return;
          _settleBlur(config, onBlur, tags: targetTags, onTagsChanged: targetOnTagsChanged, draft: _draft);
        });
      });
      return;
    }
    _settleBlur(config, onBlur, tags: targetTags, onTagsChanged: targetOnTagsChanged, draft: _draft);
  }

  void _settleBlur(
    InputTag config,
    VoidCallback onBlur, {
    required List<String> tags,
    required ValueChanged<List<String>> onTagsChanged,
    required String draft,
  }) {
    if (config._effectiveSaveOnBlur) {
      _attemptAdd(config: config, tags: tags, onTagsChanged: onTagsChanged, draftValue: draft);
    }
    onBlur();
  }

  void _handleFocusForNodeLater(FocusNode node) {
    scheduleMicrotask(() {
      if (!mounted || widget.config.disabled || !identical(_focusNode, node) || !node.hasFocus) {
        return;
      }
      _handleFocus();
    });
  }

  void _settleFocusReplacementLater(
    int generation,
    FocusNode node,
    InputTag config,
    VoidCallback onBlur, {
    required List<String> tags,
    required ValueChanged<List<String>> onTagsChanged,
  }) {
    scheduleMicrotask(() {
      if (!mounted || generation != _focusBindingGeneration || !identical(_focusNode, node)) {
        return;
      }
      if (!widget.config.disabled && node.hasFocus) return;
      _completeReportedBlur(config, onBlur, tags: tags, onTagsChanged: onTagsChanged, deferred: true);
    });
  }

  void _handleBlur() {
    if (_preservePointerFocus) {
      scheduleMicrotask(() {
        if (_canRequestFocus) _focusNode.requestFocus();
      });
      return;
    }
    final config = widget.config;
    final onBlur = widget.onBlur;
    scheduleMicrotask(() {
      if (!mounted || _focusNode.hasFocus || !_focusReported) return;
      _completeReportedBlur(config, onBlur);
    });
  }

  void _markInternalPointer() {
    _preservePointerFocus = true;
  }

  void _releaseInternalPointer() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _preservePointerFocus = false;
    });
  }

  void _focusDraftAfterTap() {
    // 外壳 tap 已完成时焦点节点通常已经挂载，直接聚焦可避开空白区没有后代
    // editable 命中而遗留的死区；首帧尚未挂载时再回退到下一帧。
    if (_requestDraftFocus()) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestDraftFocus();
    });
  }

  bool _requestDraftFocus() {
    if (!_canRequestFocus) return false;
    _focusNode.requestFocus();
    return true;
  }

  bool _blurDraft() {
    if (!_focusNode.hasFocus) return false;
    _focusNode.unfocus();
    return true;
  }

  bool _canMutateWith(InputTag config) => !config.disabled && !config.readOnly;

  bool _shouldCloseCollapsePortal(_InputTagBody oldWidget, {required bool tagsChanged}) {
    final previous = oldWidget.config;
    final current = widget.config;
    return tagsChanged ||
        current.disabled ||
        previous.disabled != current.disabled ||
        previous.readOnly != current.readOnly ||
        previous.collapseTags != current.collapseTags ||
        previous.collapseTagsTooltip != current.collapseTagsTooltip ||
        previous.maxCollapseTags != current.maxCollapseTags;
  }

  void _closeCollapsePortal({bool retainAnchor = false}) {
    if (retainAnchor && !_retainCollapsePortalAnchor) {
      _retainCollapsePortalAnchor = true;
      _collapsePortal.closed.whenComplete(() {
        if (!mounted || !_retainCollapsePortalAnchor) return;
        setState(() => _retainCollapsePortalAnchor = false);
      });
    }
    _invalidateCollapseTooltip();
    _collapsePortal.close();
  }

  void _invalidateCollapseTooltip() {
    final phase = WidgetsBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle || phase == SchedulerPhase.postFrameCallbacks) {
      _collapseTooltipRevision.value++;
      return;
    }
    if (_collapseTooltipInvalidationScheduled) return;
    _collapseTooltipInvalidationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _collapseTooltipInvalidationScheduled = false;
      _collapseTooltipRevision.value++;
    });
  }

  void _setDraft(String value, {String? rawEditableText}) {
    final changed = _draft != value;
    if (!changed && _selectedTag == null) {
      if (rawEditableText != null && rawEditableText != value) {
        _syncDraftControllerLater(expectedText: rawEditableText, targetText: value);
      }
      return;
    }
    setState(() {
      _draft = value;
      _selectedTag = null;
    });
    if (changed) widget.config.onInput?.call(value);
    if (rawEditableText != null && rawEditableText != value) {
      _syncDraftControllerLater(expectedText: rawEditableText, targetText: value);
    }
  }

  void _syncDraftControllerLater({required String expectedText, required String targetText}) {
    final controller = _fieldController();
    if (controller == null || controller.text == targetText || controller.text != expectedText) {
      return;
    }
    final revision = controller.docRevision;
    scheduleMicrotask(() {
      if (!mounted) return;
      final current = _fieldController();
      if (!identical(current, controller)) return;
      if (controller.docRevision != revision || controller.text != expectedText) {
        return;
      }
      controller.replaceRange(
        0,
        controller.length,
        targetText,
        selection: TextSelection.collapsed(offset: targetText.length),
        addToHistory: false,
      );
    });
  }

  void _handleDraftChanged(String value) {
    if (_draft == value) return;
    if (_handleDelimitedDraft(value)) return;
    if (widget.config.trigger == ElInputTagTrigger.space && value.endsWith(' ')) {
      _setDraft(value.substring(0, value.length - 1));
      _attemptAdd(rawEditableText: value);
      return;
    }
    _setDraft(value);
  }

  bool _handleDelimitedDraft(String value) {
    final split = _splitByDelimiter(value, widget.config.delimiter);
    if (split == null) return false;

    final next = <String>[...widget.tags];
    final added = <String>[];
    for (final segment in split.segments) {
      final candidate = segment.text.trim();
      if (candidate.isEmpty) continue;
      final rejection = _candidateRejection(candidate, next);
      if (rejection != null) {
        if (added.isNotEmpty) _commitTags(next, added);
        _reject(candidate, rejection);
        _setDraft(value.substring(segment.start), rawEditableText: value);
        return true;
      }
      next.add(candidate);
      added.add(candidate);
    }

    if (added.isNotEmpty) _commitTags(next, added);
    _setDraft(split.remainder, rawEditableText: value);
    return true;
  }

  _InputTagDelimiterSplit? _splitByDelimiter(String value, Pattern? delimiter) {
    if (delimiter == null || value.isEmpty) return null;
    final segments = <_InputTagDelimiterSegment>[];
    var start = 0;
    for (final match in delimiter.allMatches(value)) {
      if (match.start == match.end) continue;
      segments.add(_InputTagDelimiterSegment(value.substring(start, match.start), start));
      start = match.end;
    }
    if (segments.isEmpty) return null;
    return _InputTagDelimiterSplit(segments, value.substring(start));
  }

  bool _attemptAdd({
    InputTag? config,
    List<String>? tags,
    ValueChanged<List<String>>? onTagsChanged,
    String? draftValue,
    String? rawEditableText,
  }) {
    final effectiveConfig = config ?? widget.config;
    if (!_canMutateWith(effectiveConfig)) return false;
    final sourceDraft = draftValue ?? _draft;
    final value = sourceDraft.trim();
    if (value.isEmpty) {
      if (draftValue == null || _draft == draftValue) {
        _setDraft('', rawEditableText: rawEditableText);
      }
      return false;
    }
    final currentTags = tags ?? widget.tags;
    final rejection = _candidateRejection(value, currentTags, config: effectiveConfig);
    if (rejection != null) {
      _reject(value, rejection, config: effectiveConfig);
      return false;
    }

    final next = <String>[...currentTags, value];
    if (draftValue == null || _draft == draftValue) {
      _setDraft('', rawEditableText: rawEditableText);
    }
    _commitTags(next, [value], config: effectiveConfig, tags: currentTags, onTagsChanged: onTagsChanged);
    return true;
  }

  String? _candidateRejection(String value, List<String> current, {InputTag? config}) {
    final effectiveConfig = config ?? widget.config;
    final minLength = effectiveConfig.minLength;
    if (minLength != null && value.characters.length < minLength) {
      return '至少需要 $minLength 个字符';
    }
    if (effectiveConfig.duplicatePolicy == ElInputTagDuplicatePolicy.reject && current.contains(value)) {
      return '标签不能重复';
    }
    final max = effectiveConfig.max;
    if (max != null && current.length >= max) {
      return '最多只能添加 $max 个标签';
    }
    return effectiveConfig.validate?.call(value, List<String>.unmodifiable(current));
  }

  void _commitTags(
    List<String> next,
    List<String> added, {
    InputTag? config,
    List<String>? tags,
    ValueChanged<List<String>>? onTagsChanged,
  }) {
    final currentTags = tags ?? widget.tags;
    if (listEquals(currentTags, next)) return;
    final effectiveConfig = config ?? widget.config;
    (onTagsChanged ?? widget.onTagsChanged)(next);
    for (final value in added) {
      effectiveConfig.onAdd?.call(value);
    }
  }

  void _reject(String value, String reason, {InputTag? config}) {
    if (_selectedTag != null) setState(() => _selectedTag = null);
    (config ?? widget.config).onInvalid?.call(value, reason);
  }

  void _removeTag(int index) {
    if (!_canMutate || index < 0 || index >= widget.tags.length) return;
    final removed = widget.tags[index];
    final next = <String>[...widget.tags]..removeAt(index);
    setState(() => _selectedTag = null);
    widget.onTagsChanged(next);
    widget.config.onRemove?.call(removed, index);
  }

  void _clear() {
    if (!_canMutate || (widget.tags.isEmpty && _draft.isEmpty)) return;
    final hadTags = widget.tags.isNotEmpty;
    _setDraft('', rawEditableText: _fieldController()?.text);
    if (hadTags) widget.onTagsChanged(const <String>[]);
    widget.config.onClear?.call();
  }

  int _finalDragIndex(int oldIndex, int targetIndex) {
    final maxIndex = widget.tags.length - 1;
    if (maxIndex < 0) return 0;
    return targetIndex.clamp(0, maxIndex);
  }

  bool _canDropTag(_InputTagDragSession session, int targetIndex) {
    if (!_canMutate || !widget.config.draggable) return false;
    final oldIndex = session.index;
    if (session.epoch != _tagsEpoch || !listEquals(session.snapshot, widget.tags)) {
      return false;
    }
    if (oldIndex < 0 || oldIndex >= widget.tags.length || widget.tags[oldIndex] != session.value) {
      return false;
    }
    return _finalDragIndex(oldIndex, targetIndex) != oldIndex;
  }

  void _moveTag(_InputTagDragSession session, int targetIndex) {
    if (!_canDropTag(session, targetIndex)) return;
    final oldIndex = session.index;
    final next = <String>[...widget.tags];
    final value = next.removeAt(oldIndex);
    final newIndex = targetIndex.clamp(0, next.length);
    next.insert(newIndex, value);
    setState(() {
      _selectedTag = newIndex;
      _preserveSelectionForNextTags = true;
    });
    widget.onTagsChanged(next);
    widget.config.onDragTag?.call(oldIndex, newIndex, value);
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    final intercepted = widget.config.onKeyEvent?.call(node, event);
    if (intercepted != null && intercepted != KeyEventResult.ignored) {
      return intercepted;
    }
    final controller = _fieldController();
    if (controller?.hasActiveImeComposition ?? false) {
      return KeyEventResult.ignored;
    }
    if (event is KeyUpEvent) return KeyEventResult.ignored;

    final key = event.logicalKey;
    final isBusinessKey =
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.backspace ||
        key == LogicalKeyboardKey.escape;
    if (!isBusinessKey) return KeyEventResult.ignored;
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isControlPressed || keyboard.isMetaPressed || keyboard.isAltPressed || keyboard.isShiftPressed) {
      return KeyEventResult.ignored;
    }
    final isTrigger = switch (widget.config.trigger) {
      ElInputTagTrigger.enter => key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter,
      ElInputTagTrigger.space => key == LogicalKeyboardKey.space,
    };
    if (!_canMutate) {
      if (key == LogicalKeyboardKey.escape && _selectedTag != null) {
        setState(() => _selectedTag = null);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (isTrigger) {
      if (event is! KeyRepeatEvent) _attemptAdd();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      if (_selectedTag == null) return KeyEventResult.ignored;
      setState(() => _selectedTag = null);
      return KeyEventResult.handled;
    }
    if (_draft.isNotEmpty) return KeyEventResult.ignored;
    if (key == LogicalKeyboardKey.arrowLeft) {
      if (widget.tags.isEmpty) return KeyEventResult.ignored;
      setState(
        () => _selectedTag = _selectedTag == null
            ? widget.tags.length - 1
            : (_selectedTag! - 1).clamp(0, widget.tags.length - 1),
      );
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight && _selectedTag != null) {
      setState(() {
        final next = _selectedTag! + 1;
        _selectedTag = next < widget.tags.length ? next : null;
      });
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.backspace) {
      if (widget.tags.isEmpty) return KeyEventResult.ignored;
      if (_selectedTag == null) {
        setState(() => _selectedTag = widget.tags.length - 1);
      } else if (event is! KeyRepeatEvent) {
        _removeTag(_selectedTag!);
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  ElEditableController? _fieldController() => _fieldControl.controller;

  Widget _withDropTarget({required int targetIndex, required double inlineExtent, required Widget child}) {
    if (!_canMutate || !widget.config.draggable) return child;
    return ElDropTarget<_InputTagDragSession>(
      canAccept: (source) => _canDropTag(source, targetIndex),
      onDrop: (source, _) => _moveTag(source, targetIndex),
      builder: (context, candidate) => _inputTagInline(
        ElView(style: _inputTagDropStyle(context, candidate?.accepted == true), child: child),
        height: inlineExtent,
      ),
    );
  }

  Widget _buildTag(BuildContext context, int index, bool compact, double inlineExtent) {
    final value = widget.tags[index];
    final selected = _selectedTag == index;
    Widget tag = ElView(
      event: ElEvent(
        onPointerDown: (_) => _markInternalPointer(),
        onPointerUp: (_) => _releaseInternalPointer(),
        onPointerCancel: (_) => _releaseInternalPointer(),
      ),
      child: ElTag(
        key: ValueKey<(String, int)>(('el-input-tag', index)),
        child: widget.config.tagBuilder?.call(context, value, index, selected) ?? value,
        type: widget.config.tagType,
        effect: widget.config.tagEffect,
        hit: selected,
        closable: _canMutate,
        onClose: () => _removeTag(index),
        style: _inputTagStyle(compact, widget.config.tagStyle),
        semanticLabel: '标签：$value',
        closeSemanticLabel: '移除标签：$value',
        event: widget.config.disabled ? null : ElEvent(onTap: (_) => setState(() => _selectedTag = index)),
      ),
    );
    tag = _inputTagInline(tag, height: inlineExtent);
    if (_canMutate && widget.config.draggable) {
      tag = ElDraggable<_InputTagDragSession>(
        data: _InputTagDragSession(
          index: index,
          value: value,
          snapshot: List<String>.unmodifiable(widget.tags),
          epoch: _tagsEpoch,
        ),
        draggingOpacity: 0.45,
        ghostBuilder: (context) => _InputTagDragGhost(
          value: value,
          type: widget.config.tagType,
          effect: widget.config.tagEffect,
          compact: compact,
          style: widget.config.tagStyle,
        ),
        onDragStarted: _markInternalPointer,
        onDragEnded: (_) => _releaseInternalPointer(),
        child: tag,
      );
    }
    return _withDropTarget(targetIndex: index, inlineExtent: inlineExtent, child: tag);
  }

  Widget _buildCollapseTag(BuildContext context, List<String> hidden, bool compact, double inlineExtent) {
    final trigger = _inputTagInline(
      ElTag(
        key: const ValueKey<String>('el-input-tag-collapse'),
        child: '+${hidden.length}',
        type: widget.config.tagType,
        effect: widget.config.tagEffect,
        style: _inputTagStyle(compact, widget.config.tagStyle),
        semanticLabel: '还有 ${hidden.length} 个标签',
      ),
      height: inlineExtent,
    );
    if (Overlay.maybeOf(context) == null) return trigger;
    final tooltipEnabled = widget.config.collapseTagsTooltip && !widget.config.disabled;
    return ElPortal(
      controller: _collapsePortal,
      anchor: const ElOverlayAnchor(placement: .top, offset: 6),
      hoverIntent: tooltipEnabled
          ? const ElHoverIntent(openDelay: Duration(milliseconds: 120), closeDelay: Duration(milliseconds: 80))
          : null,
      overlayBuilder: _buildCollapseTooltipOverlay,
      captureFocus: false,
      restoreFocus: false,
      hideWhenUnlinked: true,
      child: trigger,
    );
  }

  Widget _buildCollapsePortalAnchor() {
    if (Overlay.maybeOf(context) == null) return const SizedBox.shrink();
    return ElPortal(
      controller: _collapsePortal,
      anchor: const ElOverlayAnchor(placement: .top, offset: 6),
      overlayBuilder: _buildCollapseTooltipOverlay,
      captureFocus: false,
      restoreFocus: false,
      hideWhenUnlinked: true,
      child: const ElView(style: ElStyle(width: 0, height: 0)),
    );
  }

  int _visibleCollapseCount() {
    final config = widget.config;
    return config.collapseTags && widget.tags.length > config.maxCollapseTags
        ? config.maxCollapseTags
        : widget.tags.length;
  }

  bool _willRenderCollapseTag() => widget.config.collapseTags && widget.tags.length > widget.config.maxCollapseTags;

  List<String> _hiddenCollapseTags() {
    final visibleCount = _visibleCollapseCount();
    return widget.config.collapseTags && visibleCount < widget.tags.length
        ? widget.tags.sublist(visibleCount)
        : const <String>[];
  }

  Widget _buildCollapseTooltipOverlay(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: _collapseTooltipRevision,
      builder: (context, _, _) {
        final hidden = _hiddenCollapseTags();
        final config = widget.config;
        if (!config.collapseTags || !config.collapseTagsTooltip || config.disabled || hidden.isEmpty) {
          return const ElView(style: ElStyle(width: 0, height: 0));
        }
        final compact = context.elComponentCompact(config.style);
        return _InputTagCollapseTooltip(
          values: hidden,
          type: config.tagType,
          effect: config.tagEffect,
          compact: compact,
          tagStyle: config.tagStyle,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    final compact = context.elComponentCompact(config.style);
    final tagHeight = _inputTagHeight(compact, config.tagStyle);
    final fontSize = config.style?.fontSize ?? elInputDefaultFontSize(compact);
    final iconSize = config.style?.iconSize ?? elInputDefaultIconSize(compact);
    final lineBoxHeight = elInputLineBoxHeight(fontSize);
    final inlineExtent = tagHeight > lineBoxHeight ? tagHeight : lineBoxHeight;
    final showClear = config.clearable && _canMutate && (widget.tags.isNotEmpty || _draft.isNotEmpty);
    final visibleCount = _visibleCollapseCount();
    final hiddenTags = _hiddenCollapseTags();
    final input = _withDropTarget(
      targetIndex: widget.tags.length,
      inlineExtent: inlineExtent,
      child: ElView(
        style: ElStyle(width: widget.tags.isEmpty ? 220 : 140),
        child: _InputTagField(
          key: _fieldKey,
          control: _fieldControl,
          value: _draft,
          onChanged: _handleDraftChanged,
          placeholder: widget.tags.isEmpty ? config.placeholder : null,
          disabled: config.disabled,
          readOnly: config.readOnly,
          autofocus: config.autofocus,
          focusNode: _focusNode,
          onKeyEvent: _handleKeyEvent,
          onFocus: _handleFocus,
          onBlur: _handleBlur,
          onSubmitted: config.trigger == ElInputTagTrigger.enter ? (_) => _attemptAdd() : null,
          maxLength: config.maxLength,
          style: _inputTagDraftStyle(lineBoxHeight).copyWith(fontSize: fontSize, iconSize: iconSize),
          semanticLabel: config.semanticLabel ?? config.placeholder ?? '标签输入',
        ),
      ),
    );

    return ElView(
      key: const ValueKey<String>('el-input-tag-shell'),

      style: _inputTagShellStyle(
        context,
        disabled: config.disabled,
        readOnly: config.readOnly,
        hasError: widget.hasError,
        compact: compact,
      ).merge(config.style),
      event: ElEvent(disabled: config.disabled, onTap: (_) => _focusDraftAfterTap()),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        crossAxisAlignment: .center,
        children: [
          if (config.prefix != null)
            _InputTagAffix(
              slotKey: const ValueKey<String>('el-input-tag-prefix-slot'),
              content: config.prefix!,
              extent: inlineExtent,
              iconSize: iconSize,
            ),
          for (var index = 0; index < visibleCount; index++) _buildTag(context, index, compact, inlineExtent),
          if (hiddenTags.isNotEmpty) _buildCollapseTag(context, hiddenTags, compact, inlineExtent),
          if (hiddenTags.isEmpty && _retainCollapsePortalAnchor) _buildCollapsePortalAnchor(),
          _inputTagInline(input, key: const ValueKey<String>('el-input-tag-draft-inline'), height: inlineExtent),
          if (config.suffix != null)
            _InputTagAffix(
              slotKey: const ValueKey<String>('el-input-tag-suffix-slot'),
              content: config.suffix!,
              extent: inlineExtent,
              iconSize: iconSize,
            ),
          if (config.clearable)
            _InputTagClearSlot(
              extent: inlineExtent,
              child: showClear
                  ? _InputTagClearButton(
                      icon: config.clearIcon,
                      extent: inlineExtent,
                      iconSize: iconSize,
                      onPointerDown: _markInternalPointer,
                      onPointerEnd: _releaseInternalPointer,
                      onPressed: _clear,
                    )
                  : null,
            ),
        ],
      ),
    );
  }
}

class _InputTagField extends ElInput {
  const _InputTagField({
    super.key,
    super.control,
    required super.value,
    required super.onChanged,
    super.placeholder,
    super.disabled,
    super.readOnly,
    super.autofocus,
    super.focusNode,
    super.onKeyEvent,
    super.onFocus,
    super.onBlur,
    super.onSubmitted,
    super.maxLength,
    super.style,
    super.semanticLabel,
  });

  @override
  bool get formBindable => false;
}

class _InputTagAffix extends StatelessWidget {
  const _InputTagAffix({required this.slotKey, required this.content, required this.extent, required this.iconSize});

  final Key slotKey;
  final Object content;
  final double extent;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final Widget child;
    if (content is IconData) {
      child = ElIcon(content as IconData, size: iconSize);
    } else if (content is Icon) {
      child = elContent(content, iconSize: iconSize) as Widget;
    } else if (content is Widget) {
      child = content as Widget;
    } else {
      child = ElView(
        style: ElStyle(color: context.elTheme.textSecondary, fontSize: 13, iconColor: context.elTheme.textSecondary),
        child: content,
      );
    }
    return ElView(
      key: slotKey,
      style: ElStyle(width: extent, height: extent, alignment: .center, clipBehavior: Clip.hardEdge),
      child: child,
    );
  }
}

class _InputTagClearButton extends StatelessWidget {
  const _InputTagClearButton({
    required this.icon,
    required this.extent,
    required this.iconSize,
    required this.onPointerDown,
    required this.onPointerEnd,
    required this.onPressed,
  });

  final IconData icon;
  final double extent;
  final double iconSize;
  final VoidCallback onPointerDown;
  final VoidCallback onPointerEnd;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElButtonView(
      key: const ValueKey<String>('el-input-tag-clear'),
      onPressed: onPressed,
      semanticLabel: '清空标签',
      event: ElEvent(
        onPointerDown: (_) => onPointerDown(),
        onPointerUp: (_) => onPointerEnd(),
        onPointerCancel: (_) => onPointerEnd(),
      ),
      style: ElStyle(
        width: extent,
        height: extent,
        alignment: .center,
        cursor: SystemMouseCursors.click,
        color: context.elTheme.textPlaceholder,
        borderRadius: const BorderRadius.all(Radius.circular(9999)),
        onHover: ElStyle(color: context.elTheme.textSecondary, iconColor: context.elTheme.textSecondary),
        onFocusVisible: ElStyle(
          outline: ElOutline(outlineWidth: 2, outlineColor: context.elTheme.primary, outlineOffset: 1),
        ),
        iconColor: context.elTheme.textPlaceholder,
      ),
      child: ElIcon(icon, size: iconSize),
    );
  }
}

class _InputTagClearSlot extends StatelessWidget {
  const _InputTagClearSlot({required this.extent, required this.child});

  final double extent;
  final Widget? child;

  @override
  Widget build(BuildContext context) => ElView(
    key: const ValueKey<String>('el-input-tag-clear-slot'),
    style: ElStyle(width: extent, height: extent, alignment: .center, clipBehavior: Clip.hardEdge),
    child: child,
  );
}

class _InputTagDragGhost extends StatelessWidget {
  const _InputTagDragGhost({
    required this.value,
    required this.type,
    required this.effect,
    required this.compact,
    required this.style,
  });

  final String value;
  final ElThemeType type;
  final ElTagEffect effect;
  final bool compact;
  final ElStyle? style;

  @override
  Widget build(BuildContext context) {
    return ElView(
      style: const ElStyle(opacity: 0.94, boxShadow: [BoxShadow(color: Color(0x26000000), blurRadius: 10)]),
      child: _inputTagInline(
        ElTag(type: type, effect: effect, style: _inputTagStyle(compact, style), child: value),
        height: _inputTagHeight(compact, style),
      ),
    );
  }
}

class _InputTagCollapseTooltip extends StatelessWidget {
  const _InputTagCollapseTooltip({
    required this.values,
    required this.type,
    required this.effect,
    required this.compact,
    required this.tagStyle,
  });

  final List<String> values;
  final ElThemeType type;
  final ElTagEffect effect;
  final bool compact;
  final ElStyle? tagStyle;

  @override
  Widget build(BuildContext context) {
    return ElView(
      key: const ValueKey<String>('el-input-tag-collapse-tooltip'),
      style: ElStyle(
        maxWidth: 260,
        padding: const .all(8),
        backgroundColor: context.elTheme.bgColor,
        border: ElBorder.all(borderColor: context.elTheme.borderColorLighter),
        borderRadius: .all(Radius.circular(6)),
        boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 16, offset: Offset(0, 6))],
      ),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final value in values)
            _inputTagInline(
              ElTag(type: type, effect: effect, style: _inputTagStyle(compact, tagStyle), child: value),
              height: _inputTagHeight(compact, tagStyle),
            ),
        ],
      ),
    );
  }
}

Widget _inputTagInline(Widget child, {required double height, Key? key}) => ElView(
  key: key,
  style: ElStyle(widthFactor: 1, height: height, alignment: .center, clipBehavior: Clip.hardEdge),
  child: Row(mainAxisSize: .min, crossAxisAlignment: .center, children: [child]),
);

double _inputTagHeight(bool compact, ElStyle? style) {
  final height = style?.height;
  return height is num ? height.toDouble() : (compact ? 20 : 24);
}

ElStyle _inputTagDropStyle(BuildContext context, bool active) => ElStyle(
  border: active ? ElBorder.all(borderColor: context.elTheme.primary) : null,
  borderRadius: .all(Radius.circular(4)),
  outline: active ? ElOutline(outlineWidth: 1, outlineColor: context.elTheme.primary, outlineOffset: 1) : null,
);

ElStyle _inputTagDraftStyle(double height) => ElStyle(
  width: '100%',
  height: height,
  padding: const EdgeInsets.symmetric(horizontal: 2),
  backgroundColor: const Color(0x00000000),
  borderRadius: const BorderRadius.all(Radius.circular(0)),
  boxShadow: const <BoxShadow>[],
  onHover: const ElStyle(boxShadow: <BoxShadow>[]),
  onFocusWithin: const ElStyle(boxShadow: <BoxShadow>[]),
);

ElStyle _inputTagShellStyle(
  BuildContext context, {
  required bool disabled,
  required bool readOnly,
  required bool hasError,
  required bool compact,
}) {
  final height = elInputControlHeight(compact);
  final radius = BorderRadius.circular(context.elTheme.radiusSm);
  List<BoxShadow> ring(Color color) => <BoxShadow>[ElBoxShadow(color: color, spreadRadius: 1, inset: true)];
  if (disabled) {
    return ElStyle(
      width: '100%',
      heightFactor: 1,
      minHeight: height,
      padding: const EdgeInsets.all(4),
      alignment: .centerLeft,
      backgroundColor: context.elTheme.disabledBgColor,
      borderRadius: radius,
      boxShadow: ring(context.elTheme.disabledBorderColor),
      cursor: SystemMouseCursors.forbidden,
      iconColor: context.elTheme.textPlaceholder,
    );
  }

  final danger = hasError ? context.elTheme.error : null;
  final base = danger ?? context.elTheme.borderColor;
  final hover = danger ?? context.elTheme.borderColorHover;
  final focus = danger ?? context.elTheme.primary;
  return ElStyle(
    width: '100%',
    // 保留 alignment 居中，同时按标签换行后的自然高度收缩。
    heightFactor: 1,
    minHeight: height,
    padding: const EdgeInsets.all(4),
    alignment: .centerLeft,
    backgroundColor: context.elTheme.bgColor,
    borderRadius: radius,
    boxShadow: ring(base),
    cursor: readOnly ? SystemMouseCursors.basic : SystemMouseCursors.text,
    iconColor: context.elTheme.textPlaceholder,
    transition: const [
      ElTransition.field(ElTransitionField.boxShadow, Duration(milliseconds: 200), Cubic(0.645, 0.045, 0.355, 1)),
    ],
    onHover: ElStyle(boxShadow: ring(hover)),
    onFocusWithin: ElStyle(boxShadow: ring(focus)),
  );
}

// 输入框中的标签跟随壳密度，个别外观仍由 tagStyle 覆写。
ElStyle _inputTagStyle(bool compact, ElStyle? override) =>
    ElStyle(height: compact ? 20 : 24, fontSize: 12, padding: .symmetric(horizontal: 8)).merge(override);
