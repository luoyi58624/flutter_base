import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show FocusNode, KeyEventResult;
import '../editable_controller.dart';
import '../editing/editable_ops.dart';
import 'input_action.dart';

/// 普通输入框的固定平台键位；代码命令、用户键位和 chord 在 el_editor 中实现。
class EditableKeyHandler {
  EditableKeyHandler({
    required this.controller,
    required this.ops,
    required this.readOnly,
    required this.undo,
    required this.redo,
    required this.allowClipboard,
    required this.allowTextSelection,
    required this.obscureText,
  });
  final EditableController controller;
  final EditableOps ops;
  final bool Function() readOnly, allowClipboard, allowTextSelection, obscureText;
  final VoidCallback undo, redo;

  KeyEventResult handle(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final keys = HardwareKeyboard.instance;
    final apple = defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.iOS;
    final key = _logicalKey(event.logicalKey, keys.isShiftPressed);
    for (final binding in _bindings) {
      if (binding.key != key && binding.key != event.logicalKey) continue;
      if (binding.apple != null && binding.apple != apple) continue;
      if (binding.ctrl != null && binding.ctrl != keys.isControlPressed) continue;
      if (binding.meta != null && binding.meta != keys.isMetaPressed) continue;
      if (binding.alt != null && binding.alt != keys.isAltPressed) continue;
      if (binding.shift != null && binding.shift != keys.isShiftPressed) continue;
      if (binding.nonNumpadDelete && event.logicalKey == LogicalKeyboardKey.numpadDecimal) continue;
      if (executeAction(binding.action)) return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  bool executeAction(InputAction action) {
    final select = action.name.endsWith('Select');
    if (!allowTextSelection() &&
        (select || action == InputAction.selectAll || action == InputAction.copy || action == InputAction.cut)) {
      return false;
    }
    switch (action) {
      case InputAction.cursorLeft:
        _move(CaretMotion.charLeft, extend: false);
      case InputAction.cursorRight:
        _move(CaretMotion.charRight, extend: false);
      case InputAction.cursorWordLeft:
        _move(CaretMotion.wordLeft, extend: false);
      case InputAction.cursorWordRight:
        _move(CaretMotion.wordRight, extend: false);
      case InputAction.cursorLineStart:
        _move(CaretMotion.lineStart, extend: false);
      case InputAction.cursorLineEnd:
        _move(CaretMotion.lineEnd, extend: false);
      case InputAction.cursorDocumentStart:
        _move(CaretMotion.docStart, extend: false);
      case InputAction.cursorDocumentEnd:
        _move(CaretMotion.docEnd, extend: false);
      case InputAction.cursorUp:
        _move(CaretMotion.up, extend: false);
      case InputAction.cursorDown:
        _move(CaretMotion.down, extend: false);
      case InputAction.cursorPageUp:
        _move(CaretMotion.pageUp, extend: false);
      case InputAction.cursorPageDown:
        _move(CaretMotion.pageDown, extend: false);
      case InputAction.cursorLeftSelect:
        _move(CaretMotion.charLeft, extend: true);
      case InputAction.cursorRightSelect:
        _move(CaretMotion.charRight, extend: true);
      case InputAction.cursorWordLeftSelect:
        _move(CaretMotion.wordLeft, extend: true);
      case InputAction.cursorWordRightSelect:
        _move(CaretMotion.wordRight, extend: true);
      case InputAction.cursorLineStartSelect:
        _move(CaretMotion.lineStart, extend: true);
      case InputAction.cursorLineEndSelect:
        _move(CaretMotion.lineEnd, extend: true);
      case InputAction.cursorDocumentStartSelect:
        _move(CaretMotion.docStart, extend: true);
      case InputAction.cursorDocumentEndSelect:
        _move(CaretMotion.docEnd, extend: true);
      case InputAction.cursorUpSelect:
        _move(CaretMotion.up, extend: true);
      case InputAction.cursorDownSelect:
        _move(CaretMotion.down, extend: true);
      case InputAction.cursorPageUpSelect:
        _move(CaretMotion.pageUp, extend: true);
      case InputAction.cursorPageDownSelect:
        _move(CaretMotion.pageDown, extend: true);
      case InputAction.deleteLeft:
        if (!readOnly()) ops.deleteBackward(obscureText: obscureText());
      case InputAction.deleteRight:
        if (!readOnly()) ops.deleteForward(obscureText: obscureText());
      case InputAction.deleteWordLeft:
        if (!readOnly()) {
          if (obscureText()) {
            ops.deleteToDocumentBoundary(forward: false);
          } else {
            ops.deleteBackward(word: true);
          }
        }
      case InputAction.deleteWordRight:
        if (!readOnly()) {
          if (obscureText()) {
            ops.deleteToDocumentBoundary(forward: true);
          } else {
            ops.deleteForward(word: true);
          }
        }
      case InputAction.deleteToLineStart:
        if (!readOnly()) ops.deleteToLineBreak(forward: false, obscureText: obscureText());
      case InputAction.deleteToLineEnd:
        if (!readOnly()) ops.deleteToLineBreak(forward: true, obscureText: obscureText());
      case InputAction.transposeCharacters:
        if (!readOnly()) ops.transposeCharacters();
      case InputAction.selectAll:
        ops.selectAll();
      case InputAction.copy:
        if (allowClipboard()) _clipboard(ops.copy());
      case InputAction.cut:
        if (!readOnly() && allowClipboard()) _clipboard(ops.cut());
      case InputAction.paste:
        if (!readOnly()) _clipboard(ops.paste());
      case InputAction.undo:
        if (!readOnly()) undo();
      case InputAction.redo:
        if (!readOnly()) redo();
      case InputAction.escape:
        if (controller.selection.isCollapsed) return false;
        controller.collapseTo(controller.selection.extentOffset);
    }
    return true;
  }

  void _clipboard(Future<void> operation) => unawaited(
    operation.catchError((Object error, StackTrace stack) {
      FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stack, library: 'el_ui editable'));
    }),
  );

  void _move(CaretMotion motion, {required bool extend}) {
    if (!obscureText()) {
      ops.move(motion, extend: extend);
      return;
    }
    switch (motion) {
      case CaretMotion.charLeft:
        ops.moveSemanticsCursor(
          forward: false,
          byWord: false,
          extend: extend,
          preserveSecondary: true,
          obscureText: true,
        );
        return;
      case CaretMotion.charRight:
        ops.moveSemanticsCursor(
          forward: true,
          byWord: false,
          extend: extend,
          preserveSecondary: true,
          obscureText: true,
        );
        return;
      case CaretMotion.wordLeft:
        if (extend) {
          ops.moveSemanticsCursor(
            forward: false,
            byWord: true,
            extend: true,
            preserveSecondary: true,
            obscureText: true,
          );
        } else {
          ops.move(CaretMotion.docStart);
        }
        return;
      case CaretMotion.wordRight:
        if (extend) {
          ops.moveSemanticsCursor(
            forward: true,
            byWord: true,
            extend: true,
            preserveSecondary: true,
            obscureText: true,
          );
        } else {
          ops.move(CaretMotion.docEnd);
        }
        return;
      case CaretMotion.lineStart:
        ops.moveLineBreak(forward: false, extend: extend, obscureText: true);
        return;
      case CaretMotion.lineEnd:
        ops.moveLineBreak(forward: true, extend: extend, obscureText: true);
        return;
      case CaretMotion.docStart ||
          CaretMotion.docEnd ||
          CaretMotion.up ||
          CaretMotion.down ||
          CaretMotion.pageUp ||
          CaretMotion.pageDown:
        ops.move(motion, extend: extend);
        return;
    }
  }
}

class _InputBinding {
  const _InputBinding(
    this.key,
    this.action, {
    this.ctrl = false,
    this.meta = false,
    this.alt = false,
    this.shift = false,
    this.apple,
    this.nonNumpadDelete = false,
  });
  final LogicalKeyboardKey key;
  final InputAction action;
  final bool? ctrl, meta, alt, shift, apple;
  final bool nonNumpadDelete;
}

List<_InputBinding> get _bindings => const [
  _InputBinding(
    LogicalKeyboardKey.keyA,
    InputAction.cursorLineStart,
    ctrl: true,
    meta: false,
    alt: false,
    shift: false,
    apple: true,
  ),
  _InputBinding(
    LogicalKeyboardKey.keyE,
    InputAction.cursorLineEnd,
    ctrl: true,
    meta: false,
    alt: false,
    shift: false,
    apple: true,
  ),
  _InputBinding(
    LogicalKeyboardKey.keyB,
    InputAction.cursorLeft,
    ctrl: true,
    meta: false,
    alt: false,
    shift: false,
    apple: true,
  ),
  _InputBinding(
    LogicalKeyboardKey.keyF,
    InputAction.cursorRight,
    ctrl: true,
    meta: false,
    alt: false,
    shift: false,
    apple: true,
  ),
  _InputBinding(
    LogicalKeyboardKey.keyN,
    InputAction.cursorDown,
    ctrl: true,
    meta: false,
    alt: false,
    shift: false,
    apple: true,
  ),
  _InputBinding(
    LogicalKeyboardKey.keyP,
    InputAction.cursorUp,
    ctrl: true,
    meta: false,
    alt: false,
    shift: false,
    apple: true,
  ),
  _InputBinding(
    LogicalKeyboardKey.keyT,
    InputAction.transposeCharacters,
    ctrl: true,
    meta: false,
    alt: false,
    shift: false,
    apple: true,
  ),
  _InputBinding(
    LogicalKeyboardKey.arrowLeft,
    InputAction.cursorLineStart,
    ctrl: null,
    meta: true,
    alt: null,
    apple: true,
  ),
  _InputBinding(
    LogicalKeyboardKey.arrowLeft,
    InputAction.cursorLineStartSelect,
    ctrl: null,
    meta: true,
    alt: null,
    shift: true,
    apple: true,
  ),
  _InputBinding(
    LogicalKeyboardKey.arrowRight,
    InputAction.cursorLineEnd,
    ctrl: null,
    meta: true,
    alt: null,
    apple: true,
  ),
  _InputBinding(
    LogicalKeyboardKey.arrowRight,
    InputAction.cursorLineEndSelect,
    ctrl: null,
    meta: true,
    alt: null,
    shift: true,
    apple: true,
  ),
  _InputBinding(
    LogicalKeyboardKey.arrowLeft,
    InputAction.cursorWordLeft,
    ctrl: null,
    meta: false,
    alt: true,
    apple: true,
  ),
  _InputBinding(
    LogicalKeyboardKey.arrowLeft,
    InputAction.cursorWordLeftSelect,
    ctrl: null,
    meta: false,
    alt: true,
    shift: true,
    apple: true,
  ),
  _InputBinding(
    LogicalKeyboardKey.arrowRight,
    InputAction.cursorWordRight,
    ctrl: null,
    meta: false,
    alt: true,
    apple: true,
  ),
  _InputBinding(
    LogicalKeyboardKey.arrowRight,
    InputAction.cursorWordRightSelect,
    ctrl: null,
    meta: false,
    alt: true,
    shift: true,
    apple: true,
  ),
  _InputBinding(
    LogicalKeyboardKey.arrowLeft,
    InputAction.cursorWordLeft,
    ctrl: true,
    meta: null,
    alt: null,
    apple: false,
  ),
  _InputBinding(
    LogicalKeyboardKey.arrowLeft,
    InputAction.cursorWordLeftSelect,
    ctrl: true,
    meta: null,
    alt: null,
    shift: true,
    apple: false,
  ),
  _InputBinding(
    LogicalKeyboardKey.arrowRight,
    InputAction.cursorWordRight,
    ctrl: true,
    meta: null,
    alt: null,
    apple: false,
  ),
  _InputBinding(
    LogicalKeyboardKey.arrowRight,
    InputAction.cursorWordRightSelect,
    ctrl: true,
    meta: null,
    alt: null,
    shift: true,
    apple: false,
  ),
  _InputBinding(LogicalKeyboardKey.arrowLeft, InputAction.cursorLeft, ctrl: null, meta: false, alt: false, apple: true),
  _InputBinding(
    LogicalKeyboardKey.arrowLeft,
    InputAction.cursorLeftSelect,
    ctrl: null,
    meta: false,
    alt: false,
    shift: true,
    apple: true,
  ),
  _InputBinding(
    LogicalKeyboardKey.arrowRight,
    InputAction.cursorRight,
    ctrl: null,
    meta: false,
    alt: false,
    apple: true,
  ),
  _InputBinding(
    LogicalKeyboardKey.arrowRight,
    InputAction.cursorRightSelect,
    ctrl: null,
    meta: false,
    alt: false,
    shift: true,
    apple: true,
  ),
  _InputBinding(LogicalKeyboardKey.arrowLeft, InputAction.cursorLeft, ctrl: false, meta: null, alt: null, apple: false),
  _InputBinding(
    LogicalKeyboardKey.arrowLeft,
    InputAction.cursorLeftSelect,
    ctrl: false,
    meta: null,
    alt: null,
    shift: true,
    apple: false,
  ),
  _InputBinding(
    LogicalKeyboardKey.arrowRight,
    InputAction.cursorRight,
    ctrl: false,
    meta: null,
    alt: null,
    apple: false,
  ),
  _InputBinding(
    LogicalKeyboardKey.arrowRight,
    InputAction.cursorRightSelect,
    ctrl: false,
    meta: null,
    alt: null,
    shift: true,
    apple: false,
  ),
  _InputBinding(
    LogicalKeyboardKey.arrowUp,
    InputAction.cursorDocumentStart,
    ctrl: null,
    meta: true,
    alt: false,
    apple: true,
  ),
  _InputBinding(
    LogicalKeyboardKey.arrowUp,
    InputAction.cursorDocumentStartSelect,
    ctrl: null,
    meta: true,
    alt: false,
    shift: true,
    apple: true,
  ),
  _InputBinding(
    LogicalKeyboardKey.arrowDown,
    InputAction.cursorDocumentEnd,
    ctrl: null,
    meta: true,
    alt: false,
    apple: true,
  ),
  _InputBinding(
    LogicalKeyboardKey.arrowDown,
    InputAction.cursorDocumentEndSelect,
    ctrl: null,
    meta: true,
    alt: false,
    shift: true,
    apple: true,
  ),
  _InputBinding(LogicalKeyboardKey.arrowUp, InputAction.cursorUp, ctrl: null, meta: null, alt: false),
  _InputBinding(
    LogicalKeyboardKey.arrowUp,
    InputAction.cursorUpSelect,
    ctrl: null,
    meta: null,
    alt: false,
    shift: true,
  ),
  _InputBinding(LogicalKeyboardKey.arrowDown, InputAction.cursorDown, ctrl: null, meta: null, alt: false),
  _InputBinding(
    LogicalKeyboardKey.arrowDown,
    InputAction.cursorDownSelect,
    ctrl: null,
    meta: null,
    alt: false,
    shift: true,
  ),
  _InputBinding(
    LogicalKeyboardKey.home,
    InputAction.cursorDocumentStart,
    ctrl: true,
    meta: null,
    alt: null,
    apple: false,
  ),
  _InputBinding(
    LogicalKeyboardKey.home,
    InputAction.cursorDocumentStartSelect,
    ctrl: true,
    meta: null,
    alt: null,
    shift: true,
    apple: false,
  ),
  _InputBinding(LogicalKeyboardKey.end, InputAction.cursorDocumentEnd, ctrl: true, meta: null, alt: null, apple: false),
  _InputBinding(
    LogicalKeyboardKey.end,
    InputAction.cursorDocumentEndSelect,
    ctrl: true,
    meta: null,
    alt: null,
    shift: true,
    apple: false,
  ),
  _InputBinding(LogicalKeyboardKey.home, InputAction.cursorLineStart, ctrl: null, meta: null, alt: null),
  _InputBinding(
    LogicalKeyboardKey.home,
    InputAction.cursorLineStartSelect,
    ctrl: null,
    meta: null,
    alt: null,
    shift: true,
  ),
  _InputBinding(LogicalKeyboardKey.end, InputAction.cursorLineEnd, ctrl: null, meta: null, alt: null),
  _InputBinding(
    LogicalKeyboardKey.end,
    InputAction.cursorLineEndSelect,
    ctrl: null,
    meta: null,
    alt: null,
    shift: true,
  ),
  _InputBinding(LogicalKeyboardKey.pageUp, InputAction.cursorPageUp, ctrl: null, meta: null, alt: null),
  _InputBinding(
    LogicalKeyboardKey.pageUp,
    InputAction.cursorPageUpSelect,
    ctrl: null,
    meta: null,
    alt: null,
    shift: true,
  ),
  _InputBinding(LogicalKeyboardKey.pageDown, InputAction.cursorPageDown, ctrl: null, meta: null, alt: null),
  _InputBinding(
    LogicalKeyboardKey.pageDown,
    InputAction.cursorPageDownSelect,
    ctrl: null,
    meta: null,
    alt: null,
    shift: true,
  ),
  _InputBinding(
    LogicalKeyboardKey.delete,
    InputAction.cut,
    ctrl: false,
    meta: false,
    alt: false,
    shift: true,
    apple: false,
    nonNumpadDelete: true,
  ),
  _InputBinding(
    LogicalKeyboardKey.backspace,
    InputAction.deleteToLineStart,
    ctrl: null,
    meta: true,
    alt: false,
    shift: null,
    apple: true,
  ),
  _InputBinding(
    LogicalKeyboardKey.delete,
    InputAction.deleteToLineEnd,
    ctrl: null,
    meta: true,
    alt: false,
    shift: null,
    apple: true,
  ),
  _InputBinding(
    LogicalKeyboardKey.backspace,
    InputAction.deleteWordLeft,
    ctrl: null,
    meta: null,
    alt: true,
    shift: null,
    apple: true,
  ),
  _InputBinding(
    LogicalKeyboardKey.delete,
    InputAction.deleteWordRight,
    ctrl: null,
    meta: null,
    alt: true,
    shift: null,
    apple: true,
  ),
  _InputBinding(
    LogicalKeyboardKey.backspace,
    InputAction.deleteWordLeft,
    ctrl: true,
    meta: null,
    alt: null,
    shift: null,
    apple: false,
  ),
  _InputBinding(
    LogicalKeyboardKey.delete,
    InputAction.deleteWordRight,
    ctrl: true,
    meta: null,
    alt: null,
    shift: null,
    apple: false,
  ),
  _InputBinding(LogicalKeyboardKey.backspace, InputAction.deleteLeft, ctrl: null, meta: null, alt: null, shift: null),
  _InputBinding(LogicalKeyboardKey.delete, InputAction.deleteRight, ctrl: null, meta: null, alt: null, shift: null),
  _InputBinding(
    LogicalKeyboardKey.keyA,
    InputAction.selectAll,
    ctrl: false,
    meta: true,
    alt: false,
    shift: false,
    apple: true,
  ),
  _InputBinding(
    LogicalKeyboardKey.keyC,
    InputAction.copy,
    ctrl: false,
    meta: true,
    alt: false,
    shift: false,
    apple: true,
  ),
  _InputBinding(
    LogicalKeyboardKey.keyX,
    InputAction.cut,
    ctrl: false,
    meta: true,
    alt: false,
    shift: false,
    apple: true,
  ),
  _InputBinding(
    LogicalKeyboardKey.keyV,
    InputAction.paste,
    ctrl: false,
    meta: true,
    alt: false,
    shift: false,
    apple: true,
  ),
  _InputBinding(
    LogicalKeyboardKey.keyZ,
    InputAction.undo,
    ctrl: false,
    meta: true,
    alt: false,
    shift: false,
    apple: true,
  ),
  _InputBinding(
    LogicalKeyboardKey.keyZ,
    InputAction.redo,
    ctrl: false,
    meta: true,
    alt: false,
    shift: true,
    apple: true,
  ),
  _InputBinding(
    LogicalKeyboardKey.keyA,
    InputAction.selectAll,
    ctrl: true,
    meta: false,
    alt: false,
    shift: false,
    apple: false,
  ),
  _InputBinding(
    LogicalKeyboardKey.keyC,
    InputAction.copy,
    ctrl: true,
    meta: false,
    alt: false,
    shift: false,
    apple: false,
  ),
  _InputBinding(
    LogicalKeyboardKey.keyX,
    InputAction.cut,
    ctrl: true,
    meta: false,
    alt: false,
    shift: false,
    apple: false,
  ),
  _InputBinding(
    LogicalKeyboardKey.keyV,
    InputAction.paste,
    ctrl: true,
    meta: false,
    alt: false,
    shift: false,
    apple: false,
  ),
  _InputBinding(
    LogicalKeyboardKey.keyZ,
    InputAction.undo,
    ctrl: true,
    meta: false,
    alt: false,
    shift: false,
    apple: false,
  ),
  _InputBinding(
    LogicalKeyboardKey.keyZ,
    InputAction.redo,
    ctrl: true,
    meta: false,
    alt: false,
    shift: true,
    apple: false,
  ),
  _InputBinding(
    LogicalKeyboardKey.keyY,
    InputAction.redo,
    ctrl: true,
    meta: false,
    alt: false,
    shift: false,
    apple: false,
  ),
  _InputBinding(
    LogicalKeyboardKey.insert,
    InputAction.copy,
    ctrl: true,
    meta: false,
    alt: false,
    shift: false,
    apple: false,
  ),
  _InputBinding(
    LogicalKeyboardKey.insert,
    InputAction.paste,
    ctrl: false,
    meta: false,
    alt: false,
    shift: true,
    apple: false,
  ),
  _InputBinding(LogicalKeyboardKey.escape, InputAction.escape, ctrl: null, meta: null, alt: null, shift: null),
];

LogicalKeyboardKey _logicalKey(LogicalKeyboardKey key, bool shift) {
  if (defaultTargetPlatform != TargetPlatform.windows && defaultTargetPlatform != TargetPlatform.linux) return key;
  final numLock = HardwareKeyboard.instance.lockModesEnabled.contains(KeyboardLockMode.numLock);
  if (numLock == !shift) return key;
  return switch (key) {
    LogicalKeyboardKey.numpad1 => LogicalKeyboardKey.end,
    LogicalKeyboardKey.numpad2 => LogicalKeyboardKey.arrowDown,
    LogicalKeyboardKey.numpad3 => LogicalKeyboardKey.pageDown,
    LogicalKeyboardKey.numpad4 => LogicalKeyboardKey.arrowLeft,
    LogicalKeyboardKey.numpad6 => LogicalKeyboardKey.arrowRight,
    LogicalKeyboardKey.numpad7 => LogicalKeyboardKey.home,
    LogicalKeyboardKey.numpad8 => LogicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.numpad9 => LogicalKeyboardKey.pageUp,
    LogicalKeyboardKey.numpadDecimal => LogicalKeyboardKey.delete,
    _ => key,
  };
}
