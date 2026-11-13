import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../../../../flutter/components/button/index.dart';
import '../../../../flutter/components/card/index.dart';
import '../../../../flutter/components/input/index.dart';
import '../../../../flutter/views/view/event/event.dart';
import '../../../../flutter/views/view/style/style.dart';

/// 将聊天草稿、发送动作和可扩展工具放在同一块底部面板。
class ElChatComposer extends HookWidget {
  /// 创建支持多行输入的聊天面板。
  const ElChatComposer({
    super.key,
    required this.onSend,
    this.modelValue,
    this.placeholder,
    this.focusNode,
    this.actions = const [],
    this.panel,
    this.disabled = false,
    this.style,
    this.event,
  });

  /// 提交去除首尾空白的正文，返回 `true` 时清除本次提交且未再编辑的草稿。
  final FutureOr<bool> Function(String text) onSend;

  /// 由调用方管理的草稿，省略时由面板管理。
  final ValueNotifier<String>? modelValue;

  /// 输入为空时的提示文字。
  final String? placeholder;

  /// 由调用方管理的输入焦点。
  final FocusNode? focusNode;

  /// 放在输入框旁的工具按钮。
  final List<Widget> actions;

  /// 放在输入栏下方的展开区。
  final Widget? panel;

  /// 是否禁用输入、发送和工具操作。
  final bool disabled;

  /// 在面板默认样式之后合并的外观。
  final ElStyle? style;

  /// 面板根节点的交互事件。
  final ElEvent? event;

  @override
  Widget build(BuildContext context) {
    final localDraft = useState('');
    final draft = modelValue ?? localDraft;
    final input = useMemoized(ElInputController.new);
    useEffect(() => input.dispose, [input]);
    final sending = useState(false);
    final draftRevision = useRef(0);
    final activeDraft = useRef(draft)..value = draft;
    useEffect(() {
      void onEdit() => draftRevision.value++;
      draft.addListener(onEdit);
      return () => draft.removeListener(onEdit);
    }, [draft]);

    bool isComposing() {
      final range = input.controller?.composing;
      return range != null && range.isValid && !range.isCollapsed;
    }

    Future<void> send() async {
      if (disabled || sending.value || isComposing()) return;
      final editable = input.controller;
      final text = (editable?.text ?? draft.value).trim();
      if (text.isEmpty) return;
      final revision = draftRevision.value;
      final documentRevision = editable?.docRevision;
      sending.value = true;
      try {
        final accepted = await onSend(text);
        if (accepted &&
            context.mounted &&
            identical(draft, activeDraft.value) &&
            revision == draftRevision.value &&
            documentRevision == input.controller?.docRevision) {
          draft.value = '';
        }
      } catch (error, stack) {
        FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stack, library: 'ElChatComposer'));
      } finally {
        if (context.mounted) sending.value = false;
      }
    }

    final desktop = switch (defaultTargetPlatform) {
      .linux || .macOS || .windows => true,
      _ => false,
    };

    return ElCard(
      style: const ElStyle(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)).merge(style),
      event: event,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: .min,
          crossAxisAlignment: .stretch,
          spacing: 8,
          children: [
            Row(
              crossAxisAlignment: .end,
              spacing: 8,
              children: [
                if (actions.isNotEmpty)
                  _ComposerTools(
                    disabled: disabled,
                    child: Row(mainAxisSize: .min, spacing: 4, children: actions),
                  ),
                Expanded(
                  child: ElInput(
                    modelValue: draft,
                    control: input,
                    focusNode: focusNode,
                    placeholder: placeholder ?? '输入消息',
                    textarea: true,
                    minLine: 1,
                    maxLine: 5,
                    disabled: disabled,
                    onKeyEvent: desktop
                        ? (_, event) {
                            final key = event.logicalKey;
                            if (key != LogicalKeyboardKey.enter && key != LogicalKeyboardKey.numpadEnter) {
                              return .ignored;
                            }
                            if (isComposing()) return .ignored;
                            if (event is KeyDownEvent || event is KeyRepeatEvent) {
                              if (HardwareKeyboard.instance.isShiftPressed) {
                                input.controller?.insertText('\n');
                              } else if (event is KeyDownEvent) {
                                unawaited(send());
                              }
                            }
                            return .handled;
                          }
                        : null,
                  ),
                ),
                ValueListenableBuilder(
                  valueListenable: draft,
                  builder: (context, value, _) => ElButton(
                    onPressed: () => unawaited(send()),
                    disabled: disabled || value.trim().isEmpty,
                    loading: sending.value,
                    semanticLabel: '发送',
                    child: '发送',
                  ),
                ),
              ],
            ),
            if (panel case final child?) _ComposerTools(disabled: disabled, child: child),
          ],
        ),
      ),
    );
  }
}

class _ComposerTools extends StatelessWidget {
  const _ComposerTools({required this.disabled, required this.child});

  final bool disabled;
  final Widget child;

  @override
  Widget build(BuildContext context) => ExcludeFocus(
    excluding: disabled,
    child: IgnorePointer(ignoring: disabled, child: child),
  );
}
