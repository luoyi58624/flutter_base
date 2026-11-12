import 'dart:async' show scheduleMicrotask;
import 'dart:math' as math;

import 'package:flutter/scheduler.dart' show SchedulerPhase;
import 'package:flutter/semantics.dart' show SemanticsProperties;
import 'package:flutter/services.dart'
    show
        TextInputConfiguration,
        AutofillConfiguration,
        SmartDashesType,
        SmartQuotesType,
        TextInputAction,
        TextInputType,
        TextSelection;
import 'package:flutter/widgets.dart';

import '../../internal.dart';
import 'metrics.dart';

part 'shell.dart';
part 'slots.dart';

ElStyle? _resolveInputStyle(BuildContext context, ElStyle? style) => style;

double? _resolveInputDoubleSlot(BuildContext context, double? value) => value;
Color? _resolveInputColorSlot(BuildContext context, Color? value) => value;
Object? _resolveInputObjectSlot(BuildContext context, Object? value) => value;

/// 正文、placeholder 与禁用投影的唯一排版源。
///
/// 完整声明排版，避免 ElView 与 editable 的 TextPainter 默认值分叉；
/// 正文、placeholder 和禁用色交给 ElStyle 级联，不得各自拼字号或行高。
TextStyle _inputTextStyle(BuildContext context, {required double fontSize, ElStyle? style}) {
  final declared = style == null
      ? const TextStyle()
      : TextStyle(
          fontSize: _resolveInputDoubleSlot(context, style.fontSize),
          fontWeight: style.fontWeight,
          fontStyle: style.fontStyle,
          fontFamily: _resolveInputObjectSlot(context, style.fontFamily) as String?,
          fontFamilyFallback: _resolveInputObjectSlot(context, style.fontFamilyFallback) as List<String>?,
          height: _resolveInputDoubleSlot(context, style.lineHeight),
          leadingDistribution: style.textOptions?.leadingDistribution,
          letterSpacing: _resolveInputDoubleSlot(context, style.letterSpacing),
          wordSpacing: _resolveInputDoubleSlot(context, style.wordSpacing),
          textBaseline: style.textOptions?.textBaseline,
          fontFeatures: style.fontFeatureSettings,
          fontVariations: style.fontVariationSettings,
          decoration: style.textDecorationLine,
          decorationColor: _resolveInputColorSlot(context, style.textDecorationColor),
          decorationStyle: style.textDecorationStyle,
          decorationThickness: _resolveInputDoubleSlot(context, style.textDecorationThickness),
          backgroundColor: _resolveInputColorSlot(context, style.textBackgroundColor),
          shadows: _resolveInputObjectSlot(context, style.textShadow) as List<Shadow>?,
        );
  return const TextStyle(
        inherit: false,
        fontWeight: FontWeight.normal,
        fontStyle: FontStyle.normal,
        fontFamilyFallback: <String>[],
        fontFeatures: <FontFeature>[],
        fontVariations: <FontVariation>[],
        height: elInputLineHeightFactor,
        leadingDistribution: TextLeadingDistribution.even,
        letterSpacing: 0,
        wordSpacing: 0,
        textBaseline: TextBaseline.alphabetic,
      )
      .copyWith(
        fontSize: fontSize,
        fontFamily: declared.fontFamily,
        fontFamilyFallback: declared.fontFamilyFallback ?? const [],
      )
      .merge(declared);
}

final _controllerKey = UniqueKey();
final _focusNodeKey = UniqueKey();
final _hoverKey = UniqueKey();
final _focusedKey = UniqueKey();
final _pwdVisibleKey = UniqueKey();
final _bindingKey = UniqueKey();
final _controlOwnerKey = UniqueKey();
final _controlBridgeKey = UniqueKey();

/// 桌面预设使用的 Element 输入框实现。
class Input extends ElInputModelValue<String> {
  Input(
    this.component,
    this.themeStyle, {
    super.key,
    this.affixGap = 0,
    this.clearIcon,
    this.passwordIcon,
    this.passwordVisibleIcon,
  }) : super(value: component.value, modelValue: component.modelValue, onChanged: component.onChanged);

  final ElInput component;
  final ElStyle? themeStyle;

  /// 品牌可调整前后缀留白，编辑和值绑定保持一致。
  final double affixGap;

  /// 品牌提供的清空图标。
  final Widget? clearIcon;

  /// 品牌提供的密码隐藏图标。
  final Widget? passwordIcon;

  /// 品牌提供的密码明文图标。
  final Widget? passwordVisibleIcon;
  ElStyle? get _style => (themeStyle ?? const ElStyle()).merge(component.style);

  @override
  bool get formBindable => component.formBindable;

  /// 解析当前输入框的紧凑模式，样式变量优先于祖先。
  bool _compact(BuildContext context) => context.elComponentCompact(_style);

  @override
  Widget build(BuildContext context) {
    final result = super.build(context);

    final binding = $set(_bindingKey, useMemoized(_InputBinding.new));
    binding
      ..obs = $obs
      ..form = $formState
      ..prop = $formProp
      ..onFocusCb = component.onFocus
      ..onBlurCb = component.onBlur
      ..onSubmitted = component.onSubmitted
      ..onClear = component.onClear;

    final controller = $set(
      _controllerKey,
      useMemoized(
        () => ElEditableController(
          text: binding.sourceText,
          singleLine: !component.textarea,
          maxLength: component.maxLength,
          inputFormatters: component.inputFormatters,
        ),
        const [],
      ),
    );
    controller.configure(
      singleLine: !component.textarea,
      maxLength: component.maxLength,
      inputFormatters: component.inputFormatters,
    );
    useEffect(() => controller.dispose, [controller]);

    final ownFocus = useMemoized(() => component.focusNode == null ? FocusNode(debugLabel: 'ElInput') : null, [
      component.focusNode == null,
    ]);
    useEffect(() => ownFocus?.dispose, [ownFocus]);
    final node = $set<FocusNode>(_focusNodeKey, component.focusNode ?? ownFocus!);
    final controlOwner = $set<Object>(_controlOwnerKey, useMemoized(Object.new, const []));
    final controlBridge = $set<_InputControlBridge>(_controlBridgeKey, useMemoized(_InputControlBridge.new, const []))
      ..update(
        control: component.control,
        owner: controlOwner,
        controller: controller,
        focusNode: node,
        enabled: !component.disabled,
      );

    $set(_hoverKey, useState(false));
    final focused = $set(_focusedKey, useState(false));
    $set(_pwdVisibleKey, useState(false));
    final visualRev = useState(0);

    // editable → 数据源：composing 激活期挂起（IME 组合中间态不污染 model），
    // composing 清空后统一 flush
    useEffect(() {
      final generation = binding.attachController(controller);
      var alive = true;
      var visualRebuildScheduled = false;
      var renderedCommittedLength = controller.committedTextLength;
      var renderedEmpty = (controller.length == 0);

      void rebuildVisualState() {
        if (WidgetsBinding.instance.schedulerPhase != SchedulerPhase.persistentCallbacks) {
          visualRev.value++;
          return;
        }
        if (visualRebuildScheduled) return;
        visualRebuildScheduled = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          visualRebuildScheduled = false;
          if (alive) visualRev.value++;
        });
      }

      void handleDoc() {
        binding.handleControllerDocumentChange(controller, generation);
      }

      void handleVisual() {
        // 组字文本也会占据输入区，component.placeholder/清空按钮跟实际空值，计数跟已确认字数；
        // 普通 caret/selection 移动不改变这两项，不重建外壳。
        final nextCommittedLength = controller.committedTextLength;
        final nextEmpty = (controller.length == 0);
        if (nextCommittedLength != renderedCommittedLength || nextEmpty != renderedEmpty) {
          renderedCommittedLength = nextCommittedLength;
          renderedEmpty = nextEmpty;
          rebuildVisualState();
        }
        binding.handleControllerVisualChange(controller, generation);
      }

      controller.textChanges.addListener(handleDoc);
      controller.addListener(handleVisual);
      return () {
        alive = false;
        controller.textChanges.removeListener(handleDoc);
        controller.removeListener(handleVisual);
        binding.detachController(controller, generation);
      };
    }, [controller]);

    // 数据源 → editable：最小 diff 替换保光标；表单接入由 ElFormModelValue
    // 基类把 formData 同步进 $obs，这里恒只收敛 $obs 单通道
    final Listenable source = $obs;
    useEffect(() {
      var alive = true;
      void syncIn() => binding.syncIn(controller);
      source.addListener(syncIn);
      Future.microtask(() {
        if (alive) binding.syncIn(controller);
      });
      return () {
        alive = false;
        source.removeListener(syncIn);
      };
    }, [controller, source]);

    // 焦点：状态驱动 component.clearable 显隐 + 表单 blur 校验
    useEffect(() {
      void handleFocus() {
        focused.value = node.hasFocus;
        if (node.hasFocus) {
          binding.onFocusCb?.call();
        } else {
          binding.onBlurCb?.call();
          binding.blurValidate();
        }
      }

      node.addListener(handleFocus);
      return () => node.removeListener(handleFocus);
    }, [node]);

    useEffect(() {
      controlBridge.activate();
      return () => controlBridge.deactivate(component.control, controlOwner);
    }, [controlBridge, component.control, controlOwner]);

    return result;
  }

  @override
  Widget obsBuilder(BuildContext context) {
    final controller = $get<ElEditableController>(_controllerKey);
    final node = $get<FocusNode>(_focusNodeKey);
    final hovered = $get<ValueNotifier<bool>>(_hoverKey);
    final focused = $get<ValueNotifier<bool>>(_focusedKey);
    final pwdVisible = $get<ValueNotifier<bool>>(_pwdVisibleKey);
    final binding = $get<_InputBinding>(_bindingKey);
    final controlBridge = $get<_InputControlBridge>(_controlBridgeKey);

    // ObsBuilder 收集 errorMessages 依赖：表单错误态（danger 环）自动跟随
    return ObsBuilder(
      builder: (context) =>
          _buildShell(context, controller, node, controlBridge, hovered, focused, pwdVisible, binding),
    );
  }

  Widget _buildShell(
    BuildContext context,
    ElEditableController controller,
    FocusNode node,
    _InputControlBridge controlBridge,
    ValueNotifier<bool> hovered,
    ValueNotifier<bool> focused,
    ValueNotifier<bool> pwdVisible,
    _InputBinding binding,
  ) {
    final form = $formState;
    final effProp = $formProp;
    final isDisabled = component.disabled;
    final hasError = form != null && effProp != null && form.errorMessages.containsKey(effProp);

    final compact = _compact(context);
    // 字号与行高决定编辑器和槽位几何，必须在构建布局时解析；颜色仍走样式级联。
    final declaredStyle = _style;
    final style = declaredStyle;
    final fontSize = elInputDefaultFontSize(compact);
    final iconSize = _resolveInputDoubleSlot(context, style?.iconSize) ?? elInputDefaultIconSize(compact);
    final padding = EdgeInsets.symmetric(vertical: component.textarea ? 5 : 1, horizontal: compact ? 9 : 11);
    final valueTextStyle = _inputTextStyle(context, fontSize: fontSize, style: style);
    final effectiveFontSize = valueTextStyle.fontSize ?? fontSize;
    final lineHeight = effectiveFontSize * (valueTextStyle.height ?? elInputLineHeightFactor);
    final slotExtent = math.max(lineHeight, iconSize);
    final resolvedTextAlign = component.textAlign ?? style?.textAlign ?? TextAlign.start;
    final resolvedTextDirection = style?.direction ?? Directionality.maybeOf(context) ?? TextDirection.ltr;

    final doc = controller;
    final committedTextLength = controller.committedTextLength;
    final empty = doc.length == 0;
    final masked = component.showPassword && !pwdVisible.value;

    // component.textarea 自动增高：内容行数夹在 [component.minLine, component.maxLine]，超出内滚动
    final visibleLines = component.textarea ? doc.lineCount.clamp(component.minLine, component.maxLine ?? 1 << 30) : 1;

    final showClear =
        component.clearable && !isDisabled && !component.readOnly && !empty && (focused.value || hovered.value);
    final showPwd = component.showPassword && !isDisabled && !empty && !component.textarea;
    final showCount =
        component.showWordLimit &&
        component.maxLength != null &&
        !isDisabled &&
        !component.readOnly &&
        !component.showPassword;

    Widget editArea;
    if (isDisabled) {
      // 禁用态不挂 editable：不可聚焦（Tab 链自动跳过）、无 IME、纯文本呈现
      final text = empty ? (component.placeholder ?? '') : (masked ? '•' * doc.length : controller.text);
      editArea = ElView(
        key: const ValueKey<String>('el-input-edit-area'),
        semantics: ElSemantics(exclude: true),
        style: ((BuildContext c) => ElStyle(
          color: c.elTheme.textPlaceholder,
          height: component.textarea ? visibleLines * lineHeight : lineHeight,
          padding: _inputProjectionPadding(component.textarea),
          textAlign: resolvedTextAlign,
          textOptions: style?.textOptions,
          direction: resolvedTextDirection,
          userSelect: ElUserSelect.none,
          iconColor: c.elTheme.textPlaceholder,
        ))(context),
        child: TextSpan(text: text, style: valueTextStyle.copyWith(inherit: true)),
      );
    } else {
      editArea = ElView(
        key: const ValueKey<String>('el-input-edit-area'),
        style: ((BuildContext c) {
          final declared = _style;
          final resolved = declared;
          return ElStyle(
            height: component.textarea ? visibleLines * lineHeight : lineHeight,
            color: _resolveInputColorSlot(c, resolved?.color) ?? c.elTheme.textRegular,
            onSelection: ElStyle(backgroundColor: c.elTheme.primary.withValues(alpha: 0.25)),
            iconColor: _resolveInputColorSlot(c, resolved?.color) ?? c.elTheme.textRegular,
          ).merge(resolved?.onSelection == null ? null : ElStyle(onSelection: resolved!.onSelection));
        })(context),
        child: ElStack(
          fit: .expand,
          children: [
            if (empty && component.placeholder != null)
              _InputPlaceholder(
                component.placeholder!,
                textarea: component.textarea,
                textStyle: valueTextStyle.copyWith(inherit: true),
                textAlign: resolvedTextAlign,
                textDirection: resolvedTextDirection,
                style: ElStyle(textOptions: style?.textOptions).merge(component.placeholderStyle),
              ),
            Directionality(
              textDirection: resolvedTextDirection,
              child: ElEditableView(
                key: controlBridge.editableKey,
                controller: controller,
                focusNode: node,
                onViewChanged: controlBridge.onStateChanged,
                onKeyEvent: component.onKeyEvent,
                onAction: (action) {
                  component.onAction?.call(action);
                  if (!component.textarea) {
                    binding.onSubmitted?.call(controller.text);
                  }
                },
                onConnectionClosed: component.onConnectionClosed,
                onPrivateCommand: component.onPrivateCommand,
                onFloatingCursor: component.onFloatingCursor,
                onAutocorrectionPromptRect: component.onAutocorrectionPromptRect,
                onShowToolbar: component.onShowToolbar,
                onTextPlaceholderChanged: component.onTextPlaceholderChanged,
                onSelector: component.onSelector,
                onUnhandledContent: component.onUnhandledContent,
                onInputControlChanged: component.onInputControlChanged,
                style: ElEditableStyle(
                  view: ElStyle(
                    textAlign: resolvedTextAlign,
                    textOptions: const ElTextOptions(
                      leadingDistribution: .even,
                      textBaseline: .alphabetic,
                    ).merge(style?.textOptions),
                  ),
                  fixedLineHeight: true,
                  caretColor: component.caretColor,
                  softWrap: component.textarea,
                  readOnly: component.readOnly,
                  autofocus: component.autofocus,
                  obscureText: masked,
                  semanticLabel: component.semanticLabel ?? component.placeholder,
                  enableInteractiveSelection: component.enableInteractiveSelection,
                  scrollbars: component.textarea,
                  inputConfiguration: TextInputConfiguration(
                    inputAction:
                        (component.textInputAction ?? (component.textarea ? null : TextInputAction.done)) ??
                        (component.textarea ? TextInputAction.newline : TextInputAction.done),
                    inputType:
                        (component.keyboardType ?? (component.textarea ? null : TextInputType.text)) ??
                        (component.textarea ? TextInputType.multiline : TextInputType.text),
                    actionLabel: component.actionLabel,
                    keyboardAppearance: component.keyboardAppearance,
                    textCapitalization: component.textCapitalization,
                    smartDashesType: component.showPassword ? SmartDashesType.disabled : component.smartDashesType,
                    smartQuotesType: component.showPassword ? SmartQuotesType.disabled : component.smartQuotesType,
                    autocorrect: component.autocorrect && !component.showPassword,
                    enableSuggestions: component.enableSuggestions && !component.showPassword,
                    enableIMEPersonalizedLearning: component.enableIMEPersonalizedLearning && !component.showPassword,
                    allowedMimeTypes: component.allowedMimeTypes,
                    hintLocales: component.hintLocales,
                    enableInlinePrediction: component.showPassword ? false : component.enableInlinePrediction,
                    autofillConfiguration: component.autofillHints == null
                        ? AutofillConfiguration.disabled
                        : AutofillConfiguration(
                            uniqueIdentifier: controller.hashCode.toString(),
                            autofillHints: component.autofillHints!.toList(),
                            currentEditingValue: TextEditingValue(
                              text: controller.text,
                              selection: controller.selection,
                            ),
                            hintText: component.placeholder,
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final Widget body;
    if (component.textarea) {
      body = Column(
        crossAxisAlignment: .stretch,
        children: [
          Row(
            crossAxisAlignment: .start,
            children: [
              Expanded(child: editArea),
              if (component.clearable)
                _InputActionSlot(
                  slotKey: const ValueKey<String>('el-input-clear-slot'),
                  extent: slotExtent,
                  child: showClear
                      ? _InputActionIcon(
                          style: component.actionStyle,
                          icon: clearIcon ?? ElDesktopIcons.circleClose,
                          size: iconSize,
                          extent: slotExtent,
                          onTap: () {
                            controller.replaceRange(0, controller.length, '');
                            node.requestFocus();
                            binding.onClear?.call();
                          },
                        )
                      : null,
                ),
            ],
          ),
          if (showCount)
            ElView(
              style: const ElStyle(alignment: .centerRight),
              child: _InputCount(length: committedTextLength, maxLength: component.maxLength!),
            ),
        ],
      );
    } else {
      body = Row(
        crossAxisAlignment: .center,
        children: [
          if (component.prefix != null)
            _InputAffix(
              component.prefix,
              slotKey: const ValueKey<String>('el-input-prefix-slot'),
              style: component.affixStyle,
              iconSize: iconSize,
              extent: slotExtent,
            ),
          if (component.prefix != null && affixGap > 0) SizedBox(width: affixGap),
          Expanded(child: editArea),
          if (component.clearable)
            _InputActionSlot(
              slotKey: const ValueKey<String>('el-input-clear-slot'),
              extent: slotExtent,
              child: showClear
                  ? _InputActionIcon(
                      style: component.actionStyle,
                      icon: clearIcon ?? ElDesktopIcons.circleClose,
                      size: iconSize,
                      extent: slotExtent,
                      onTap: () {
                        controller.replaceRange(0, controller.length, '');
                        node.requestFocus();
                        binding.onClear?.call();
                      },
                    )
                  : null,
            ),
          if (component.suffix != null && affixGap > 0) SizedBox(width: affixGap),
          if (component.suffix != null)
            _InputAffix(
              component.suffix,
              slotKey: const ValueKey<String>('el-input-suffix-slot'),
              style: component.affixStyle,
              iconSize: iconSize,
              extent: slotExtent,
            ),
          if (component.showPassword && !component.textarea)
            _InputActionSlot(
              slotKey: const ValueKey<String>('el-input-password-slot'),
              extent: slotExtent,
              child: showPwd
                  ? _InputActionIcon(
                      style: component.actionStyle,
                      icon: (pwdVisible.value ? passwordVisibleIcon : passwordIcon) ?? ElDesktopIcons.view,
                      size: iconSize,
                      extent: slotExtent,
                      active: pwdVisible.value,
                      onTap: () => pwdVisible.value = !pwdVisible.value,
                    )
                  : null,
            ),
          if (showCount) _InputCount(length: committedTextLength, maxLength: component.maxLength!),
        ],
      );
    }

    return ElView(
      semantics: isDisabled
          ? ElSemantics(
              container: true,
              properties: SemanticsProperties(
                textField: true,
                readOnly: true,
                enabled: false,
                obscured: masked,
                multiline: component.textarea,
                label: component.semanticLabel ?? component.placeholder,
                value: empty ? '' : (masked ? '•' * doc.length : controller.text),
                maxValueLength: component.maxLength,
                currentValueLength: component.maxLength == null ? null : doc.length,
              ),
            )
          : null,
      style: ((BuildContext c) {
        final base = _inputShellStyle(
          c,
          isDisabled: isDisabled,
          hasError: hasError,
          textarea: component.textarea,
          compact: compact,
          fontSize: effectiveFontSize,
          padding: padding,
        );
        return base.merge(ElStyle(width: component.width)).merge(_resolveInputStyle(c, _style));
      })(context),
      event: isDisabled
          ? null
          : ElEvent(
              onPointerEnter: (_) => hovered.value = true,
              onPointerExit: (_) => hovered.value = false,
              // 壳整域都是 text 光标，点 padding/前后缀空白也必须激活编辑器
              //（官方 wrapper 点击即 focus）；editable 内部命中自会定位 caret，
              // requestFocus 幂等不冲突
              onPointerDown: (_) {
                if (node.hasFocus) return;
                // 空白落点不挂焦点节点，焦点仲裁器会在 down 微任务先执行全局
                // blur；帧尾再把焦点交给内部 editable，才能稳定覆盖该默认动作。
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (node.context != null && node.canRequestFocus) {
                    node.requestFocus();
                  }
                });
              },
            ),
      child: body,
    );
  }
}

// InputControlBridge 保持稳定 callback identity，避免 ElEditableView 每次
// build 都把旧回调当卸载处理；真正的 control/controller/focus 走字段热更新。
class _InputControlBridge {
  late final ValueChanged<ElEditableController?> onStateChanged = _handleStateChanged;
  final GlobalKey editableKey = GlobalKey(debugLabel: 'ElInput ElEditableView');

  ElInputController? _control;
  Object? _owner;
  ElEditableController? _controller;
  FocusNode? _focusNode;
  bool _enabled = false;
  bool _active = false;

  void update({
    required ElInputController? control,
    required Object owner,
    required ElEditableController controller,
    required FocusNode focusNode,
    required bool enabled,
  }) {
    _control = control;
    _owner = owner;
    _controller = controller;
    _focusNode = focusNode;
    _enabled = enabled;
    sync();
  }

  void activate() {
    _active = true;
    sync();
  }

  void deactivate(ElInputController? control, Object owner) {
    _active = false;
    control?.detach(owner);
  }

  void sync() {
    if (!_active) return;
    final owner = _owner;
    if (owner == null) return;
    _control?.attach(owner: owner, controller: _enabled ? _controller : null, focusNode: _enabled ? _focusNode : null);
  }

  void _handleStateChanged(ElEditableController? state) {
    sync();
  }
}

/// 迟绑定桥：hooks 监听器生命周期长于 widget 实例，最新的回调/数据源经此
/// 对象每次 build 刷新，监听器闭包只捕获它（避免旧 widget 闭包失联）。
/// 表单数据同步归 [ElFormModelValue] 基类通道，这里恒只对 $obs 收敛。
class _InputBinding {
  Obs<String>? obs;
  ElFormState? form;
  String? prop;
  VoidCallback? onFocusCb;
  VoidCallback? onBlurCb;
  ValueChanged<String>? onSubmitted;
  VoidCallback? onClear;

  /// syncIn 应用外部值期间抑制 flushOut 回声。
  bool syncingIn = false;

  /// composing 期挂起的出站 flush 标记。
  bool pendingFlush = false;

  ElEditableController? _listenedController;
  int _controllerGeneration = 0;
  int _flushGeneration = 0;
  bool _listenerAlive = false;
  bool _flushDirty = false;

  /// 数据源当前文本（表单模式下基类已把 formData 镜像进 obs）。
  String get sourceText => obs?.value ?? '';

  int attachController(ElEditableController controller) {
    _listenedController = controller;
    _listenerAlive = true;
    _controllerGeneration++;
    _invalidateScheduledFlush(clearDirty: true);
    return _controllerGeneration;
  }

  void detachController(ElEditableController controller, int generation) {
    if (!_isCurrentController(controller, generation)) return;
    _listenerAlive = false;
    _listenedController = null;
    _controllerGeneration++;
    _invalidateScheduledFlush(clearDirty: true);
  }

  void handleControllerDocumentChange(ElEditableController controller, int generation) {
    if (!_isCurrentController(controller, generation) || syncingIn) return;
    _flushDirty = true;
    final composing = controller.composing;
    if (composing.isValid && !composing.isCollapsed) {
      pendingFlush = true;
      _flushGeneration++;
      return;
    }
    pendingFlush = false;
    _flushWhenSafe(controller, generation);
  }

  void handleControllerVisualChange(ElEditableController controller, int generation) {
    if (!_isCurrentController(controller, generation) || syncingIn) return;
    final composing = controller.composing;
    if (composing.isValid && !composing.isCollapsed) {
      if (_flushDirty) pendingFlush = true;
      return;
    }
    if (!pendingFlush && !_flushDirty) return;
    pendingFlush = false;
    _flushWhenSafe(controller, generation);
  }

  void _flushWhenSafe(ElEditableController controller, int generation) {
    if (!_isCurrentController(controller, generation) || !_flushDirty) return;
    final taskGeneration = ++_flushGeneration;
    final docRevision = controller.docRevision;
    final composingAtSchedule = controller.composing;
    if (_canFlushNow) {
      _completeScheduledFlush(controller, generation, taskGeneration, docRevision, composingAtSchedule);
      return;
    }
    scheduleMicrotask(
      () => _completeScheduledFlush(controller, generation, taskGeneration, docRevision, composingAtSchedule),
    );
  }

  void _completeScheduledFlush(
    ElEditableController controller,
    int generation,
    int taskGeneration,
    int docRevision,
    TextRange composingAtSchedule,
  ) {
    if (!_isCurrentController(controller, generation) || taskGeneration != _flushGeneration || !_flushDirty) {
      return;
    }
    if (controller.docRevision != docRevision || controller.composing != composingAtSchedule) {
      _flushWhenSafe(controller, generation);
      return;
    }
    final composing = controller.composing;
    if (composing.isValid && !composing.isCollapsed) {
      pendingFlush = true;
      return;
    }
    _flushDirty = false;
    flushOut(controller);
  }

  bool _isCurrentController(ElEditableController controller, int generation) =>
      _listenerAlive && identical(_listenedController, controller) && _controllerGeneration == generation;

  bool get _canFlushNow {
    final phase = WidgetsBinding.instance.schedulerPhase;
    return phase == SchedulerPhase.idle || phase == SchedulerPhase.postFrameCallbacks;
  }

  void _invalidateScheduledFlush({required bool clearDirty}) {
    _flushGeneration++;
    if (!clearDirty) return;
    pendingFlush = false;
    _flushDirty = false;
  }

  /// editable → 数据源：写 obs 即可——ElModelValue 自动转发 modelValue/
  /// onChanged，ElFormModelValue 基类通道负责替换式写入表单 + change 校验。
  void flushOut(ElEditableController controller) {
    if (syncingIn) return;
    final text = controller.text;
    final obs = this.obs;
    if (obs == null || obs.value == text) return;
    obs.value = text;
  }

  /// 数据源 → editable：最小 diff 替换（保光标/保历史）。内核策略（单行剔
  /// 换行、maxLength 截断）归一后若与源不一致，回写一次收敛。
  void syncIn(ElEditableController controller) {
    _invalidateScheduledFlush(clearDirty: true);
    final text = sourceText;
    final sameText = text == controller.text;
    if (sameText && !controller.hasActiveImeComposition) return;
    syncingIn = true;
    try {
      if (sameText) {
        // 外部值恰好采纳当前 preedit 仍是一次权威同步：同文 setter 会清空
        // composing/IME 会话与旧历史并建立保存基线，避免失焦后把候选再回传。
        controller.text = text;
      } else {
        _minimalReplace(controller, text);
      }
    } finally {
      syncingIn = false;
    }
    if (controller.text != text) flushOut(controller);
  }

  void blurValidate() {
    if (form != null && prop != null) {
      form!.validateField(prop!, trigger: .blur);
    }
  }

  /// 公共前后缀 diff → 单次 replaceRange。光标映射：变更区之前保持原位、
  /// 之后随长度差平移、区内落到新内容末尾。
  static void _minimalReplace(ElEditableController controller, String next) {
    final prev = controller.text;
    var start = 0;
    final minLen = math.min(prev.length, next.length);
    while (start < minLen && prev.codeUnitAt(start) == next.codeUnitAt(start)) {
      start++;
    }
    var endPrev = prev.length;
    var endNext = next.length;
    while (endPrev > start && endNext > start && prev.codeUnitAt(endPrev - 1) == next.codeUnitAt(endNext - 1)) {
      endPrev--;
      endNext--;
    }
    final caret = controller.selection.extentOffset;
    final int target;
    if (caret <= start) {
      target = caret;
    } else if (caret >= endPrev) {
      target = caret + (next.length - prev.length);
    } else {
      target = endNext;
    }
    controller.replaceRange(
      start,
      endPrev,
      next.substring(start, endNext),
      selection: TextSelection.collapsed(offset: target.clamp(0, next.length)),
    );
  }
}
