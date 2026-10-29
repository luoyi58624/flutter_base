import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';

import 'package:flutter_base/src/ui/cores/editable/editable_controller.dart';
import 'package:flutter_base/src/ui/cores/editable/model/edit_operation.dart';
import 'ime_window.dart';
import 'windows_ime_geometry.dart';

/// 平台 IME 连接桥：[TextInputClient] 实现 + 连接生命周期 + 窗口化同步。
///
/// 职责边界：
/// - 持有 [TextInputConnection]，把平台整值或 granular delta 翻译成 controller
///   编辑原语（[EditableController.imeReplace] / imeUpdateSelection）；
/// - 把本地变化（键盘编辑、指针选区、undo…）经 [ImeWindow] 回推平台；
/// - 不做几何计算——caret / 尺寸上报由视图层算好经 [updateGeometry] 透传。
///
/// 默认的大文档窗口化：平台眼中的“全文”只是覆盖选区的有界窗口（见
/// [ImeWindow]），通道负载与文档规模无关；显式启用 Autofill 的表单字段是
/// 例外，平台会发送字段全文，因此改用全文窗口保证回填不会残留窗口外正文。
class EditableImeClient implements DeltaTextInputClient {
  /// 创建窗口化 IME 客户端；平台附加能力均通过可选回调交给视图层实现。
  EditableImeClient({
    required this.controller,
    this.onAction,
    this.onNewline,
    this.onConnectionClosed,
    this.onPlatformFocusReceived,
    this.onPrivateCommand,
    this.onFloatingCursor,
    this.onAutocorrectionPromptRect,
    this.onShowToolbar,
    this.onTextPlaceholderChanged,
    this.onSelector,
    this.onUnhandledContent,
    this.onInputControlChanged,
    this.onGeometryRequested,
    this.autofillScope,
  });

  /// 接收平台编辑并承载文档、选区与 composing 的控制器。
  final EditableController controller;

  /// 原生请求尚未缓存的字符位置时，交给宿主安排帧尾读取已排版几何。
  final VoidCallback? onGeometryRequested;

  /// 平台输入动作（done / next / search…；多行 newline 已内部消化）。
  final void Function(TextInputAction action)? onAction;

  /// 平台明确用单个换行替换当前已推送选区时的可选编辑策略。
  ///
  /// 回调在 full / delta 正文更新上触发，而不是在随后到达的 newline action
  /// 上触发；上层可借此把普通换行原子替换为自动缩进等策略编辑。
  final VoidCallback? onNewline;

  /// 平台侧关闭连接（如键盘收起）时回调。
  final VoidCallback? onConnectionClosed;

  /// 平台输入控件请求重新取得焦点时交给视图层恢复焦点与连接。
  final bool Function()? onPlatformFocusReceived;

  /// Android IME 私有命令；协议层不解释业务载荷，原样交给上层。
  final void Function(String action, Map<String, dynamic> data)? onPrivateCommand;

  /// iOS 浮动光标事件；需要文本几何的移动与绘制由上层完成。
  final ValueChanged<RawFloatingCursorPoint>? onFloatingCursor;

  /// iOS 待自动更正范围，回调收到的是文档全局 offset。
  final ValueChanged<TextRange>? onAutocorrectionPromptRect;

  /// 平台请求显示编辑工具栏；IME 层只通知，不创建任何 UI。
  final VoidCallback? onShowToolbar;

  /// Scribble 文本占位变化；插入传尺寸，移除传 null。
  final ValueChanged<Size?>? onTextPlaceholderChanged;

  /// macOS 标准键绑定 selector；具体编辑动作由上层键盘策略裁决。
  final ValueChanged<String>? onSelector;

  /// 无法安全解码为纯文本的键盘插入内容，交给上层富内容策略处理。
  final ValueChanged<KeyboardInsertedContent>? onUnhandledContent;

  /// 自定义输入控件完成默认隐藏旧控件、显示新控件后的切换通知。
  final void Function(TextInputControl? oldControl, TextInputControl? newControl)? onInputControlChanged;

  /// 当前所属自动填充作用域；由挂载视图动态提供以支持组重挂载。
  final AutofillScope? Function()? autofillScope;

  TextInputConnection? _connection;
  WindowsImeGeometry? _windowsGeometry;
  int? _viewId;
  Set<String> _allowedMimeTypes = const <String>{};
  ImeWindow _window = const ImeWindow(start: 0, end: 0);
  TextEditingValue _lastValue = TextEditingValue.empty;
  bool _applying = false;
  bool _autofillEnabled = false;
  List<String> _autofillHints = const <String>[];
  String? _autofillHintText;
  bool _autofillRequestPending = false;

  /// 上一次与平台对齐（push / 采纳）时刻的 doc 选区。平台编辑基于上一次
  /// setEditingState 的窗口值，recv 侧的越窗判定与扩回必须以它为锚——
  /// push 与 recv 之间本地选区漂移（协议竞态）时若读 recv 时刻的实时选区，
  /// 误删范围会从窗口级放大到漂移后的整个 doc 选区。
  TextSelection _pushedSelection = const TextSelection.collapsed(offset: -1);

  // 窗口计算依赖这组完整输入；缓存命中时跳过重复的 lineIndexOf 树遍历。
  int _windowCacheDocRevision = -1;
  TextSelection? _windowCacheSelection;
  TextRange? _windowCacheComposing;
  bool? _windowCacheAutofillEnabled;
  ImeWindow? _cachedWindow;

  // 窗口正文只依赖文档修订与 `[start, end)`；选区或 composing 独立变化时
  // TextEditingValue 复用同一 String，避免重复 piece tree 读取与字符串复制。
  int _windowTextDocRevision = -1;
  int _windowTextStart = -1;
  int _windowTextEnd = -1;
  String? _cachedWindowText;
  int _debugWindowTextBuildCount = 0;
  int _debugWindowTextReuseCount = 0;

  /// 测试探针：从文档重新读取 IME 窗口正文的次数。
  @visibleForTesting
  int get debugWindowTextBuildCount => _debugWindowTextBuildCount;

  /// 测试探针：复用同一修订与窗口正文字符串的次数。
  @visibleForTesting
  int get debugWindowTextReuseCount => _debugWindowTextReuseCount;

  /// 测试探针：当前客户端缓存的窗口正文长度；关闭连接后为 0。
  @visibleForTesting
  int get debugCachedWindowTextCodeUnits => _cachedWindowText?.length ?? 0;

  /// IME 通道线级日志（默认关）：`--dart-define=EL_IME_LOG=true` 开启。
  /// mock 通道不模拟引擎侧组合行为，协议类 bug 只能录制真实消息序列定位；
  /// 录到的序列回放进 testTextInput 即成回归测试。
  static bool debugLogWire = const bool.fromEnvironment('EL_IME_LOG');

  /// 日志收惰性闭包：插值参数（_fmt 拼接窗口文本等）只在开关打开时才求值，
  /// 关闭态（含 release）击键 / 选区热路径零字符串分配。
  static void _log(String Function() message) {
    if (debugLogWire) debugPrint('[el-ime] ${message()}');
  }

  static String _fmt(TextEditingValue v) =>
      '"${v.text}" sel=${v.selection.baseOffset},${v.selection.extentOffset} comp=${v.composing.start},${v.composing.end}';

  /// 当前连接是否仍是 [TextInput] 的活动客户端。
  bool get attached => _connection?.attached ?? false;

  // ===========================================================================
  // 连接生命周期（视图层驱动）
  // ===========================================================================

  /// 建立连接并弹出键盘；已连接则原位更新配置后再次 show。
  void open(TextInputConfiguration configuration) {
    final autofillChanged = _autofillShapeChanged(configuration.autofillConfiguration);
    _rememberConfiguration(configuration);
    if (attached && !autofillChanged) {
      _log(() => 'open: already attached → updateConfig + show');
      _connection!
        ..updateConfig(_platformConfiguration(configuration))
        ..show();
      return;
    }
    if (attached) {
      _clearWindowsGeometry();
      _connection!.close();
      _connection = null;
    }
    _rebuildWindow();
    _lastValue = _currentWindowValue();
    _pushedSelection = controller.selection;
    _log(() => 'open: attach + seed ${_fmt(_lastValue)} window=[${_window.start},${_window.end})');
    _connection = TextInput.attach(this, _platformConfiguration(configuration))
      ..setEditingState(_lastValue)
      ..show();
    _autofillRequestPending = _autofillEnabled;
  }

  /// 关闭连接。
  void close() {
    _clearWindowsGeometry();
    _connection?.close();
    _connection = null;
    _autofillRequestPending = false;
    _lastValue = TextEditingValue.empty;
    _pushedSelection = const TextSelection.collapsed(offset: -1);
    _clearWindowTextCache();
  }

  /// 原位更新活动连接配置；未连接时静默等待下一次 [open] 使用新配置。
  void updateConfiguration(TextInputConfiguration configuration) {
    final autofillChanged = _autofillShapeChanged(configuration.autofillConfiguration);
    _rememberConfiguration(configuration);
    if (!attached) return;
    if (autofillChanged) {
      _clearWindowsGeometry();
      _connection!.close();
      _connection = null;
      open(configuration);
      return;
    }
    _connection!.updateConfig(_platformConfiguration(configuration));
  }

  void _rememberConfiguration(TextInputConfiguration configuration) {
    if (_viewId != configuration.viewId) _clearWindowsGeometry();
    _viewId = configuration.viewId;
    _allowedMimeTypes = Set<String>.unmodifiable(configuration.allowedMimeTypes.map(_baseMimeType));
    final autofill = configuration.autofillConfiguration;
    _autofillEnabled = autofill.enabled;
    _autofillHints = List<String>.unmodifiable(autofill.autofillHints);
    _autofillHintText = autofill.hintText;
  }

  bool _autofillShapeChanged(AutofillConfiguration next) =>
      _autofillEnabled != next.enabled ||
      !listEquals(_autofillHints, next.autofillHints) ||
      _autofillHintText != next.hintText;

  TextInputConfiguration _platformConfiguration(TextInputConfiguration current) {
    final scope = currentAutofillScope;
    return _autofillEnabled && scope != null
        ? _EditableAutofillScopeConfiguration(
            current: current,
            fields: scope.autofillClients.map((client) => client.textInputConfiguration),
          )
        : current;
  }

  /// 明确结束当前 composing，并同步平台与控制器的最终结构。
  ///
  /// [commit] 为 true 时保留候选文本且生成一个原子 undo；为 false 时恢复组合
  /// 开始前的文本与选区且不产生历史。[commitUnconfirmedAsPlainText] 仅把仍活动的
  /// ASCII 字母候选按未确认英文提交，并删除其中的 U+0027 分隔符。
  /// 返回是否实际结束了一个组合生命周期。
  bool finishComposing({bool commit = true, bool commitUnconfirmedAsPlainText = false}) {
    final hadActiveComposition = controller.hasActiveImeComposition;
    bool? finished;
    try {
      finished = controller.finishImeComposition(
        commit: commit,
        commitUnconfirmedAsPlainText: commitUnconfirmedAsPlainText,
      );
      return finished;
    } finally {
      if (finished == true || (hadActiveComposition && !controller.hasActiveImeComposition)) {
        _syncFinishedComposition();
      }
    }
  }

  void _syncFinishedComposition() {
    _rebuildWindow();
    final value = _currentWindowValue();
    final changed =
        value.text != _lastValue.text ||
        value.selection != _lastValue.selection ||
        !_composingEquivalent(value.composing, _lastValue.composing);
    _lastValue = value;
    _pushedSelection = controller.selection;
    if (changed && attached) _connection!.setEditingState(value);
  }

  /// 连接期间上报编辑框几何与 caret 矩形（IME 候选窗定位）。
  void updateGeometry({
    required Size size,
    required Matrix4 transform,
    Rect? caretRect,
    Rect? composingRect,
    Rect? composingAnchorRect,
    Rect? composingEndRect,
    Object? layoutVersion,
    Rect? Function(int offset)? resolveComposingPosition,
  }) {
    final connection = _connection;
    if (connection == null || !connection.attached) return;
    // 先发布同步查询快照，再让官方通道移动候选窗，避免查询新范围却读到上一帧。
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows && _viewId != null && caretRect != null) {
      final geometry = _windowsGeometry ??= WindowsImeGeometry(
        viewId: _viewId!,
        onPositionRequested: onGeometryRequested,
      );
      geometry.update(
        anchor: MatrixUtils.transformRect(transform, composingAnchorRect ?? caretRect),
        document: MatrixUtils.transformRect(transform, Offset.zero & size),
        caret: MatrixUtils.transformRect(transform, caretRect),
        composingEnd: composingEndRect == null ? null : MatrixUtils.transformRect(transform, composingEndRect),
        composingLength: controller.composing.isValid ? controller.composing.end - controller.composing.start : 0,
        version: (controller.docRevision, controller.presentationRevision, controller.composing, layoutVersion),
        resolvePosition: resolveComposingPosition == null
            ? null
            : (offset) {
                final rect = resolveComposingPosition(offset);
                return rect == null ? null : MatrixUtils.transformRect(transform, rect);
              },
      );
    }
    connection.setEditableSizeAndTransform(size, transform);
    if (caretRect != null) connection.setCaretRect(caretRect);
    // Windows 把 marked rect 的左边当成系统光标；使用真实 caret，避免它先回到
    // 组合起点、随后又被同步字符查询移回当前输入位置。
    final platformComposingRect = !kIsWeb && defaultTargetPlatform == TargetPlatform.windows
        ? caretRect ?? composingRect
        : composingRect;
    if (platformComposingRect != null) connection.setComposingRect(platformComposingRect);
    if (_autofillRequestPending) {
      _autofillRequestPending = false;
      connection.requestAutofill();
    }
  }

  void _clearWindowsGeometry() {
    _windowsGeometry?.close();
    _windowsGeometry = null;
  }

  /// 上报文本样式（部分平台的 IME 内联候选渲染用）。
  void updateStyle(TextStyle style, TextDirection direction, TextAlign align) {
    final connection = _connection;
    if (connection == null || !connection.attached) return;
    connection.updateStyle(
      TextInputStyle(
        fontFamily: style.fontFamily,
        fontSize: style.fontSize,
        fontWeight: style.fontWeight,
        textDirection: direction,
        textAlign: align,
      ),
    );
  }

  /// 本地变化后回推平台。IME 应用路径内（[_applying]）不回推，避免自激。
  ///
  /// 平台输入回调期由 [_applying] 截断回声；其余本地 selection、
  /// composing 或窗口 base 变化都是新权威状态，必须向平台建立顺序屏障。
  void syncFromController() {
    if (!attached || _applying) return;
    final previousWindow = _window;
    _rebuildWindow();
    final value = _currentWindowValue();
    final windowChanged = previousWindow.start != _window.start || previousWindow.end != _window.end;
    if (!windowChanged &&
        value.text == _lastValue.text &&
        value.selection == _lastValue.selection &&
        _composingEquivalent(value.composing, _lastValue.composing)) {
      return;
    }
    _log(
      () =>
          'sync: PUSH ${_fmt(value)} (last=${_fmt(_lastValue)} window=${previousWindow.start},${previousWindow.end}→${_window.start},${_window.end})',
    );
    _lastValue = value;
    _pushedSelection = controller.selection;
    _connection!.setEditingState(value);
  }

  /// 在 tagged 自动填充期间抑制控制器监听回声，并把活动连接重新校准到 IME 窗口。
  void applyAutofill(TextEditingValue platformValue, VoidCallback apply) {
    try {
      _applyAutofillValue(platformValue, apply);
    } catch (error, stackTrace) {
      _recoverAndRethrow(error, stackTrace);
    }
  }

  void _applyAutofillValue(TextEditingValue platformValue, VoidCallback apply) {
    _applying = true;
    try {
      apply();
    } finally {
      _applying = false;
    }
    _rebuildWindow();
    final synced = _currentWindowValue();
    _lastValue = synced;
    _pushedSelection = controller.selection;
    final aligned =
        synced.text == platformValue.text &&
        _sameOffsets(synced.selection, platformValue.selection) &&
        _composingEquivalent(synced.composing, platformValue.composing);
    if (attached && !aligned) _connection!.setEditingState(synced);
  }

  /// collapsed / invalid composing 一律视为"无组合"等价。官方语义是把平台值
  /// 原样收下、从不纠偏；引擎 compose-begin 会发 collapsed `[0,0]`，若把它与
  /// 本地 empty(-1,-1) 的差异当结构偏差回推 setEditingState，引擎
  /// TextInputModel 的组合跟踪被打死——之后每次组合变更退化成光标处插入整段
  /// 拼音（中文输入无限叠加事故的实锤根因，线级日志坐实）。
  static bool _composingEquivalent(TextRange a, TextRange b) {
    final aActive = a.isValid && !a.isCollapsed;
    final bActive = b.isValid && !b.isCollapsed;
    if (!aActive && !bActive) return true;
    return a == b;
  }

  /// 输入未变时复用 IME 窗口，避免重复的 lineIndexOf 树遍历。
  void _rebuildWindow() {
    final docRev = controller.docRevision;
    final selection = controller.selection;
    final composing = controller.composing;

    if (_cachedWindow != null &&
        _windowCacheDocRevision == docRev &&
        _windowCacheSelection == selection &&
        _windowCacheComposing == composing &&
        _windowCacheAutofillEnabled == _autofillEnabled) {
      _window = _cachedWindow!;
      return;
    }

    _window = _autofillEnabled
        ? ImeWindow(start: 0, end: controller.document.length)
        : ImeWindow.cover(controller.document, selection, composing);

    _cachedWindow = _window;
    _windowCacheDocRevision = docRev;
    _windowCacheSelection = selection;
    _windowCacheComposing = composing;
    _windowCacheAutofillEnabled = _autofillEnabled;
  }

  TextEditingValue _currentWindowValue() =>
      _window.valueWithText(_windowText(_window), controller.selection, controller.composing);

  String _windowText(ImeWindow window) {
    final docRevision = controller.docRevision;
    var text = _cachedWindowText;
    if (text == null ||
        _windowTextDocRevision != docRevision ||
        _windowTextStart != window.start ||
        _windowTextEnd != window.end) {
      text = controller.document.getText(window.start, window.end);
      _cachedWindowText = text;
      _windowTextDocRevision = docRevision;
      _windowTextStart = window.start;
      _windowTextEnd = window.end;
      _debugWindowTextBuildCount++;
    } else {
      _debugWindowTextReuseCount++;
    }
    return text;
  }

  void _clearWindowTextCache() {
    _windowTextDocRevision = -1;
    _windowTextStart = -1;
    _windowTextEnd = -1;
    _cachedWindowText = null;
  }

  /// 平台回调异常后以 controller 权威快照恢复窗口和远端基线。
  void _recoverAfterRemoteFailure() {
    _applying = false;
    _rebuildWindow();
    final synced = _currentWindowValue();
    _lastValue = synced;
    _pushedSelection = controller.selection;
    final connection = _connection;
    if (connection != null && connection.attached) connection.setEditingState(synced);
  }

  Never _recoverAndRethrow(Object error, StackTrace stackTrace) {
    try {
      _recoverAfterRemoteFailure();
    } catch (recoveryError, recoveryStackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: recoveryError,
          stack: recoveryStackTrace,
          library: 'el_ui editable',
          context: ErrorDescription('while recovering editable IME state after a callback failure'),
        ),
      );
    }
    Error.throwWithStackTrace(error, stackTrace);
  }

  // ===========================================================================
  // TextInputClient
  // ===========================================================================

  @override
  TextEditingValue? get currentTextEditingValue => attached ? _lastValue : null;

  @override
  AutofillScope? get currentAutofillScope => autofillScope?.call();

  @override
  void updateEditingValue(TextEditingValue value) {
    try {
      _applyRemoteEditingValue(value);
    } catch (error, stackTrace) {
      _recoverAndRethrow(error, stackTrace);
    }
  }

  void _applyRemoteEditingValue(TextEditingValue value) {
    final old = _lastValue;
    final useNewlinePolicy = _matchesNewlinePolicyUpdate(old, value, requireTextDifference: true);
    _log(
      () =>
          'recv: ${_fmt(value)} (old=${_fmt(old)} window=[${_window.start},${_window.end}) lines=${controller.document.lineCount})',
    );
    _lastValue = value;
    // 官方护栏（flutter#65811）：引擎会对同一值重复通知，原样吸收。
    if (value == old) return;
    if (useNewlinePolicy) {
      _applyNewlinePolicy(value);
      return;
    }
    _applying = true;
    try {
      _applyWindowValue(value, window: _window, pushedSelection: _pushedSelection);
    } finally {
      _applying = false;
    }
    _finishRemoteUpdate(value);
  }

  /// 先在冻结窗口值上完整演算一批 delta，再以单一原子事务落控制器。
  ///
  /// 一批中任一 `oldText` 与前一份远端值失步时，整批改走最终整值 diff；
  /// 不会先把已对齐的前缀 delta 暴露成中间文档状态。
  @override
  void updateEditingValueWithDeltas(List<TextEditingDelta> textEditingDeltas) {
    if (textEditingDeltas.isEmpty) return;
    try {
      _applyRemoteEditingDeltas(textEditingDeltas);
    } catch (error, stackTrace) {
      _recoverAndRethrow(error, stackTrace);
    }
  }

  void _applyRemoteEditingDeltas(List<TextEditingDelta> textEditingDeltas) {
    final window = _window;
    final pushedSelection = _pushedSelection;
    final base = window.start;
    final oldRemote = _lastValue;
    final windowText = _windowText(window);
    var remote = oldRemote;
    var receivedChange = false;
    var chainAligned = true;
    TextEditingDelta? onlyTextDelta;
    List<TextEditingDelta>? normalizedDeltas;
    var textDeltaCount = 0;
    _log(
      () => 'recv-delta: count=${textEditingDeltas.length} old=${_fmt(remote)} window=[${window.start},${window.end})',
    );

    // Flutter delta 是 last-write-wins：apply 以 delta.oldText 为基线。这里仍按
    // 平台语义演算最终值，另外严格验证整条 oldText 链以决定能否
    // 保留单条 typed delta 的精确区间。演算期不触碰 controller。
    for (var index = 0; index < textEditingDeltas.length; index++) {
      var delta = textEditingDeltas[index];
      if (delta.oldText != remote.text) chainAligned = false;
      if (chainAligned) {
        final normalized = _normalizeWindowsCompositionStart(remote, delta);
        if (!identical(normalized, delta)) {
          if (textEditingDeltas.length > 1) {
            (normalizedDeltas ??= List<TextEditingDelta>.of(textEditingDeltas))[index] = normalized;
          }
          delta = normalized;
        }
      }
      final value = delta.apply(remote);
      if (delta is! TextEditingDeltaNonTextUpdate) {
        textDeltaCount++;
        onlyTextDelta = delta;
      }
      if (value != remote) receivedChange = true;
      remote = value;
      _log(() => 'recv-delta[$index]: ${delta.runtimeType} old="${delta.oldText}" → ${_fmt(value)}');
    }
    _lastValue = remote;
    if (!receivedChange) return;

    final deltaEdit = textDeltaCount == 1 ? _deltaEdit(onlyTextDelta!) : null;
    final useNewlinePolicy =
        chainAligned &&
        windowText == oldRemote.text &&
        deltaEdit != null &&
        _matchesNewlinePolicyUpdate(oldRemote, remote, explicitRange: deltaEdit.range, explicitText: deltaEdit.text);
    if (useNewlinePolicy) {
      _applyNewlinePolicy(remote);
      return;
    }

    _applying = true;
    try {
      final docSelection = pushedSelection.isValid ? pushedSelection : controller.selection;
      final beyondWindow = _selectionBeyondWindow(window, docSelection);
      var appliedTyped = false;

      // 纯非文本批次只在整条链对齐时采纳最终选区；即使一批内有多个
      // selection/composing 漂移也只通知 controller 一次。
      if (chainAligned && textDeltaCount == 0) {
        final composing = _composingToDoc(remote.composing, base);
        if (beyondWindow && _sameOffsets(remote.selection, window.selectionToLocal(docSelection))) {
          controller.imeUpdateSelection(controller.selection, composing);
        } else {
          controller.imeUpdateSelection(
            _selectionToDoc(remote.selection, base, composing: remote.composing),
            composing,
          );
        }
        appliedTyped = true;
      } else if (chainAligned && textDeltaCount == 1 && windowText == oldRemote.text) {
        // 唯一文本 delta 可保留平台给出的精确替换区间；前后的 non-text
        // delta 仍以整批最终 selection/composing 为准。
        if (beyondWindow) {
          appliedTyped = _applyBeyondWindowDelta(onlyTextDelta!, remote, window: window, docSelection: docSelection);
        } else {
          appliedTyped = _applyTypedDelta(onlyTextDelta!, remote, base);
        }
      } else if (chainAligned && textDeltaCount > 1 && windowText == oldRemote.text && !beyondWindow) {
        // delta 区间属于各自 oldText；先在符号片段上演算，再映射回批次初始窗口
        // 坐标。相隔的编辑保持相隔，不能被公共前后缀 diff 扩成首尾宽替换。
        final localOperations = _DeltaBatchMap.map(normalizedDeltas ?? textEditingDeltas, windowText);
        if (localOperations != null) {
          controller.imeApplyEdits(
            [
              for (final operation in localOperations)
                EditOperation.replace(base + operation.start, base + operation.end, operation.text),
            ],
            selection: _selectionToDoc(remote.selection, base, composing: remote.composing),
            composing: _composingToDoc(remote.composing, base),
          );
          appliedTyped = true;
        } else {
          // 链仍对齐却无法证明坐标映射时拒绝整批；尾部结构校准会把旧值回推。
          appliedTyped = true;
        }
      } else if (chainAligned && textDeltaCount > 1 && windowText == oldRemote.text && beyondWindow) {
        // 被窗口钳制的 doc 大选区不能把多笔局部坐标安全扩回全文；宁可整批拒绝，
        // 也不能用首尾宽 diff 误删窗口外正文或让中间装饰漂移。
        appliedTyped = true;
      }
      if (!appliedTyped) {
        // 仅 oldText 链或本地窗口基线失步时退回最终整值 diff 自愈；不会将
        // 已对齐的前缀中间态暴露给 revision、通知或 undo 历史。
        _applyWindowValue(remote, window: window, pushedSelection: pushedSelection, currentWindowText: windowText);
      }
    } finally {
      _applying = false;
    }
    if (receivedChange) _finishRemoteUpdate(remote);
  }

  static TextEditingDelta _normalizeWindowsCompositionStart(TextEditingValue before, TextEditingDelta delta) {
    final selection = before.selection;
    if (kIsWeb ||
        defaultTargetPlatform != TargetPlatform.windows ||
        !selection.isValid ||
        selection.isCollapsed ||
        selection.end > before.text.length ||
        _hasActiveComposing(before.composing) ||
        delta is! TextEditingDeltaInsertion ||
        delta.insertionOffset != selection.start ||
        !_hasActiveComposing(delta.composing) ||
        delta.composing.start != selection.start ||
        delta.composing.end != selection.start + delta.textInserted.length ||
        (delta.selection.isValid &&
            (!delta.selection.isCollapsed || delta.selection.extentOffset != delta.composing.end))) {
      return delta;
    }
    // Windows ComposeChangeHook 在 DeleteSelected 前保存 collapsed composing_range，
    // 首笔误报 insertion；以平台此前持有的选区还原替换，不回推状态打断组合。
    return TextEditingDeltaReplacement(
      oldText: delta.oldText,
      replacementText: delta.textInserted,
      replacedRange: TextRange(start: selection.start, end: selection.end),
      selection: delta.selection,
      composing: delta.composing,
    );
  }

  /// 只承认“当前平台锚选区被一个 `\n` 精确替换”的更新。
  ///
  /// full update 没有显式编辑区间，因此还要求正文实际变化；delta 则用平台
  /// 给出的精确 range 证明意图。活动 composing、失步窗口、异位 diff 与
  /// 多字符输入一律走普通 IME 路径，避免把候选提交或粘贴误判成回车。
  bool _matchesNewlinePolicyUpdate(
    TextEditingValue old,
    TextEditingValue value, {
    TextRange? explicitRange,
    String? explicitText,
    bool requireTextDifference = false,
  }) {
    if (onNewline == null || controller.singleLine) return false;
    if (_hasActiveComposing(old.composing) ||
        _hasActiveComposing(value.composing) ||
        _hasActiveComposing(controller.composing)) {
      return false;
    }
    final pushedSelection = _pushedSelection;
    if (!pushedSelection.isValid || !_sameOffsets(controller.selection, pushedSelection)) return false;
    final localSelection = _window.selectionToLocal(pushedSelection);
    if (!_sameOffsets(old.selection, localSelection)) return false;
    if (localSelection.start < 0 || localSelection.end > old.text.length) return false;
    if (_windowText(_window) != old.text) return false;
    if (explicitRange != null &&
        (explicitText != '\n' ||
            explicitRange.start != localSelection.start ||
            explicitRange.end != localSelection.end)) {
      return false;
    }
    if (explicitRange == null && explicitText != null) return false;
    if (requireTextDifference && value.text == old.text) return false;
    if (value.text != old.text.replaceRange(localSelection.start, localSelection.end, '\n')) return false;
    return value.selection.isValid &&
        value.selection.isCollapsed &&
        value.selection.extentOffset == localSelection.start + 1;
  }

  void _applyNewlinePolicy(TextEditingValue remote) {
    _log(() => 'recv: newline-policy remote=${_fmt(remote)}');
    _applying = true;
    try {
      onNewline!.call();
    } finally {
      _applying = false;
    }
    // 策略可能写入额外缩进并重划窗口，必须以 controller 结果纠偏平台。
    _finishRemoteUpdate(remote);
  }

  static bool _hasActiveComposing(TextRange range) => range.isValid && !range.isCollapsed;

  bool _applyTypedDelta(TextEditingDelta delta, TextEditingValue value, int base) {
    if (delta is TextEditingDeltaNonTextUpdate) {
      controller.imeUpdateSelection(
        _selectionToDoc(value.selection, base, composing: value.composing),
        _composingToDoc(value.composing, base),
      );
      return true;
    }
    final edit = _deltaEdit(delta);
    if (edit == null) return false;
    controller.imeReplace(
      base + edit.range.start,
      base + edit.range.end,
      edit.text,
      selection: _selectionToDoc(value.selection, base, composing: value.composing),
      composing: _composingToDoc(value.composing, base),
    );
    return true;
  }

  bool _applyBeyondWindowDelta(
    TextEditingDelta delta,
    TextEditingValue value, {
    required ImeWindow window,
    required TextSelection docSelection,
  }) {
    final edit = _deltaEdit(delta);
    if (edit == null || docSelection.isCollapsed) return false;
    final localSelection = window.selectionToLocal(docSelection);
    if (edit.range.start != localSelection.start || edit.range.end != localSelection.end) return false;

    // delta 自带精确替换范围，命中钳制选区时无需再猜公共前后缀；整个 doc
    // 选区就是用户实际操作对象。即使替换后窗口文本与旧值相同也必须兑现。
    final start = docSelection.start;
    final end = docSelection.end;
    final insertEnd = start + edit.text.length;
    int remap(int localOffset) => (start + localOffset - edit.range.start).clamp(start, insertEnd);
    controller.imeReplace(
      start,
      end,
      edit.text,
      selection: _mapRemoteSelection(value.selection, remap, composing: value.composing),
      composing: value.composing.isValid && !value.composing.isCollapsed
          ? TextRange(start: remap(value.composing.start), end: remap(value.composing.end))
          : TextRange.empty,
    );
    return true;
  }

  static ({TextRange range, String text})? _deltaEdit(TextEditingDelta delta) {
    if (delta is TextEditingDeltaInsertion) {
      return (range: TextRange.collapsed(delta.insertionOffset), text: delta.textInserted);
    }
    if (delta is TextEditingDeltaDeletion) return (range: delta.deletedRange, text: '');
    if (delta is TextEditingDeltaReplacement) {
      return (range: delta.replacedRange, text: delta.replacementText);
    }
    return null;
  }

  void _applyWindowValue(
    TextEditingValue value, {
    required ImeWindow window,
    required TextSelection pushedSelection,
    String? currentWindowText,
  }) {
    // 窗口起点在一批编辑中恒定，局部 → doc 是纯平移。
    final base = window.start;
    final selection = _selectionToDoc(value.selection, base, composing: value.composing);
    final composing = _composingToDoc(value.composing, base);
    // 官方语义 = 整体采纳平台值；窗口化下对本地真实窗口求最小 diff，
    // 不依赖可能过期的远端 oldText，双方失步时仍能单步自愈。
    final windowText = currentWindowText ?? _windowText(window);
    final diff = TextDiff.diff(windowText, value.text);
    final docSelection = pushedSelection.isValid ? pushedSelection : controller.selection;
    final beyondWindow = _selectionBeyondWindow(window, docSelection);
    if (diff == null) {
      // 钳制选区的无文本回声不能把 doc 大选区截成窗口片段。
      if (beyondWindow && _sameOffsets(value.selection, window.selectionToLocal(docSelection))) {
        controller.imeUpdateSelection(controller.selection, composing);
      } else {
        controller.imeUpdateSelection(selection, composing);
      }
      return;
    }
    if (!beyondWindow) {
      controller.imeReplace(
        base + diff.start,
        base + diff.end,
        diff.inserted,
        selection: selection,
        composing: composing,
      );
      return;
    }

    // 平台对钳制选区的替换编辑 = 用户对整个 doc 选区的替换。优先按窗口
    // 选区外前后缀切出真实插入文本，避免最小 diff 把同前/后缀字符裁掉。
    final localSel = window.selectionToLocal(docSelection);
    final tailLen = windowText.length - localSel.end;
    final insertLen = value.text.length - localSel.start - tailLen;
    final structural =
        insertLen >= 0 &&
        value.text.startsWith(windowText.substring(0, localSel.start)) &&
        value.text.endsWith(windowText.substring(localSel.end));
    final int start;
    final int end;
    final String inserted;
    final int anchor;
    if (structural) {
      start = docSelection.start;
      end = docSelection.end;
      inserted = value.text.substring(localSel.start, localSel.start + insertLen);
      anchor = localSel.start;
    } else {
      start = math.min(base + diff.start, docSelection.start);
      end = math.max(base + diff.end, docSelection.end);
      inserted = diff.inserted;
      anchor = diff.start;
    }
    final insertEnd = start + inserted.length;
    int remap(int localOffset) => (start + localOffset - anchor).clamp(start, insertEnd);
    controller.imeReplace(
      start,
      end,
      inserted,
      selection: _mapRemoteSelection(value.selection, remap, composing: value.composing),
      composing: value.composing.isValid && !value.composing.isCollapsed
          ? TextRange(start: remap(value.composing.start), end: remap(value.composing.end))
          : TextRange.empty,
    );
  }

  TextSelection _selectionToDoc(TextSelection local, int base, {TextRange composing = TextRange.empty}) =>
      _mapRemoteSelection(local, (offset) => base + offset, composing: composing);

  TextSelection _mapRemoteSelection(
    TextSelection remote,
    int Function(int offset) mapOffset, {
    TextRange composing = TextRange.empty,
  }) {
    // Windows 组合首笔与候选拒绝后的 selection-only 都可能携带 -1；它只
    // 表示平台没有有效端点。活动候选以 composing 尾为 caret；终态消息保留
    // controller 权威端点，绝不能经范围钳制解释成文首。
    if (!remote.isValid) {
      return _hasActiveComposing(composing)
          ? TextSelection.collapsed(offset: mapOffset(composing.end))
          : controller.selection;
    }
    return TextSelection(
      baseOffset: mapOffset(remote.baseOffset),
      extentOffset: mapOffset(remote.extentOffset),
      affinity: remote.affinity,
      isDirectional: remote.isDirectional,
    );
  }

  static TextRange _composingToDoc(TextRange local, int base) => local.isValid && !local.isCollapsed
      ? TextRange(start: base + local.start, end: base + local.end)
      : TextRange.empty;

  static bool _selectionBeyondWindow(ImeWindow window, TextSelection selection) =>
      !selection.isCollapsed && (selection.start < window.start || selection.end > window.end);

  void _finishRemoteUpdate(TextEditingValue value) {
    // 应用后窗口可能因换行 / 选区迁移而重划：只在**结构性偏差**（策略截断 /
    // 窗口重划改了 text 或 composing）时纠正平台。有效选区的细微差异仍不
    // 回推，避免打断 Windows 组合；但候选已结束后的 invalid selection 必须
    // 恢复本地有效 caret，否则平台下一次组合会从文首开始。
    _rebuildWindow();
    // 无论回推与否，应用完平台编辑后双方即重新对齐，选区锚同步刷新。
    _pushedSelection = controller.selection;
    final synced = _currentWindowValue();
    final invalidTerminalSelection =
        !value.selection.isValid && !_hasActiveComposing(value.composing) && !_hasActiveComposing(synced.composing);
    if (synced.text != value.text ||
        !_composingEquivalent(synced.composing, value.composing) ||
        invalidTerminalSelection) {
      _log(() => 'recv-tail: CORRECTION PUSH ${_fmt(synced)} lines=${controller.document.lineCount}');
      _lastValue = synced;
      final connection = _connection;
      if (connection != null && connection.attached) connection.setEditingState(synced);
    } else {
      _log(
        () =>
            'recv-tail: aligned lines=${controller.document.lineCount} comp=${controller.composing.start},${controller.composing.end}',
      );
    }
  }

  /// 只比选区端点（affinity 是引擎侧微差，不构成用户意图变化）。
  static bool _sameOffsets(TextSelection a, TextSelection b) =>
      a.baseOffset == b.baseOffset && a.extentOffset == b.extentOffset;

  @override
  void performAction(TextInputAction action) {
    if (action == TextInputAction.newline) {
      if (controller.singleLine) {
        onAction?.call(action);
      }
      // Flutter 平台在 multiline 上先通过 full/delta update 插入换行，
      // 再发 newline action；action 只是终态通知，不得二次写正文。
      return;
    }
    onAction?.call(action);
  }

  @override
  void performPrivateCommand(String action, Map<String, dynamic> data) {
    onPrivateCommand?.call(action, data);
  }

  @override
  void updateFloatingCursor(RawFloatingCursorPoint point) {
    onFloatingCursor?.call(point);
  }

  @override
  void showAutocorrectionPromptRect(int start, int end) {
    final range = start >= 0 && end >= start
        ? TextRange(start: _window.toDoc(start), end: _window.toDoc(end))
        : TextRange.empty;
    onAutocorrectionPromptRect?.call(range);
  }

  @override
  void showToolbar() {
    onShowToolbar?.call();
  }

  @override
  void insertTextPlaceholder(Size size) {
    onTextPlaceholderChanged?.call(size);
  }

  @override
  void removeTextPlaceholder() {
    onTextPlaceholderChanged?.call(null);
  }

  @override
  void performSelector(String selectorName) {
    onSelector?.call(selectorName);
  }

  @override
  void insertContent(KeyboardInsertedContent content) {
    if (!attached || !_allowedMimeTypes.contains(_baseMimeType(content.mimeType))) {
      return;
    }
    final text = _decodePlainTextContent(content);
    if (text == null) {
      onUnhandledContent?.call(content);
      return;
    }
    // commitContent 是独立平台动作，不与相邻键入合并；insertText 会按当前
    // 全部选区写入，并在必要时先结清 composing 会话。
    controller.closeHistoryRun();
    controller.insertText(text);
    controller.closeHistoryRun();
  }

  static String? _decodePlainTextContent(KeyboardInsertedContent content) {
    final mimeType = _baseMimeType(content.mimeType);
    if (mimeType != 'text/plain') return null;
    final data = content.data;
    if (data != null) {
      try {
        return utf8.decode(data);
      } on FormatException {
        // 非 UTF-8 字节不能无损落纯文本，继续尝试自描述 data URI。
      }
    }
    final uri = Uri.tryParse(content.uri);
    if (uri?.scheme != 'data') return null;
    try {
      return uri!.data?.contentAsString();
    } on FormatException {
      return null;
    }
  }

  static String _baseMimeType(String mimeType) => mimeType.split(';').first.trim().toLowerCase();

  @override
  void didChangeInputControl(TextInputControl? oldControl, TextInputControl? newControl) {
    if (attached) {
      oldControl?.hide();
      newControl?.show();
    }
    onInputControlChanged?.call(oldControl, newControl);
  }

  @override
  bool onFocusReceived() => onPlatformFocusReceived?.call() ?? false;

  @override
  void connectionClosed() {
    _clearWindowsGeometry();
    final connection = _connection;
    if (connection == null) return;
    if (connection.attached) connection.connectionClosedReceived();
    _connection = null;
    _autofillRequestPending = false;
    onConnectionClosed?.call();
  }
}

/// 当前 Flutter 内建 AutofillScope 聚合器漏拷 delta/MIME/locale/inline 等新字段；
/// 本地等价配置保留当前客户端完整协议，同时追加同组 fields。
final class _EditableAutofillScopeConfiguration extends TextInputConfiguration {
  _EditableAutofillScopeConfiguration({
    required TextInputConfiguration current,
    required Iterable<TextInputConfiguration> fields,
  }) : _fields = List<TextInputConfiguration>.unmodifiable(fields),
       super(
         viewId: current.viewId,
         inputType: current.inputType,
         readOnly: current.readOnly,
         obscureText: current.obscureText,
         autocorrect: current.autocorrect,
         smartDashesType: current.smartDashesType,
         smartQuotesType: current.smartQuotesType,
         enableSuggestions: current.enableSuggestions,
         enableInteractiveSelection: current.enableInteractiveSelection,
         actionLabel: current.actionLabel,
         inputAction: current.inputAction,
         keyboardAppearance: current.keyboardAppearance,
         textCapitalization: current.textCapitalization,
         autofillConfiguration: current.autofillConfiguration,
         enableIMEPersonalizedLearning: current.enableIMEPersonalizedLearning,
         allowedMimeTypes: current.allowedMimeTypes,
         enableDeltaModel: current.enableDeltaModel,
         hintLocales: current.hintLocales,
         enableInlinePrediction: current.enableInlinePrediction,
       );

  final List<TextInputConfiguration> _fields;

  @override
  Map<String, dynamic> toJson() {
    final result = super.toJson();
    result['fields'] = _fields.map((field) => field.toJson()).toList(growable: false);
    return result;
  }
}

/// 把顺序 delta 维护成“原窗口片段 + 新插入片段”，最终导出初始坐标编辑集。
class _DeltaBatchMap {
  _DeltaBatchMap(int originalLength)
    : _originalLength = originalLength,
      _segments = originalLength == 0 ? <_DeltaSegment>[] : <_DeltaSegment>[_OriginalDeltaSegment(0, originalLength)];

  final int _originalLength;
  final List<_DeltaSegment> _segments;

  static List<EditOperation>? map(List<TextEditingDelta> deltas, String originalText) {
    final mapping = _DeltaBatchMap(originalText.length);
    for (final delta in deltas) {
      if (delta is TextEditingDeltaNonTextUpdate) continue;
      final edit = EditableImeClient._deltaEdit(delta);
      if (edit == null || !mapping._replace(edit.range.start, edit.range.end, edit.text)) return null;
    }
    return mapping._toOperations(originalText);
  }

  int get _length => _segments.fold<int>(0, (total, segment) => total + segment.length);

  bool _replace(int start, int end, String text) {
    final length = _length;
    if (start < 0 || end < start || end > length) return false;
    _splitAt(end);
    final startIndex = _splitAt(start);
    // split start 后，end 的边界索引可能右移，重新定位避免索引漂移。
    final resolvedEndIndex = _boundaryIndex(end);
    _segments.removeRange(startIndex, resolvedEndIndex);
    if (text.isNotEmpty) _segments.insert(startIndex, _InsertedDeltaSegment(text));
    _coalesceAround(startIndex.clamp(0, _segments.length));
    return true;
  }

  int _splitAt(int offset) {
    var cursor = 0;
    for (var index = 0; index < _segments.length; index++) {
      final segment = _segments[index];
      final next = cursor + segment.length;
      if (offset == cursor) return index;
      if (offset == next) return index + 1;
      if (offset > cursor && offset < next) {
        final local = offset - cursor;
        final parts = segment.split(local);
        _segments
          ..removeAt(index)
          ..insertAll(index, parts);
        return index + 1;
      }
      cursor = next;
    }
    return _segments.length;
  }

  int _boundaryIndex(int offset) {
    var cursor = 0;
    for (var index = 0; index < _segments.length; index++) {
      if (cursor == offset) return index;
      cursor += _segments[index].length;
    }
    return _segments.length;
  }

  void _coalesceAround(int boundary) {
    var index = math.max(0, boundary - 2);
    while (index + 1 < _segments.length) {
      final left = _segments[index];
      final right = _segments[index + 1];
      if (left is _OriginalDeltaSegment && right is _OriginalDeltaSegment && left.end == right.start) {
        _segments[index] = _OriginalDeltaSegment(left.start, right.end);
        _segments.removeAt(index + 1);
        continue;
      }
      if (left is _InsertedDeltaSegment && right is _InsertedDeltaSegment) {
        _segments[index] = _InsertedDeltaSegment(left.text + right.text);
        _segments.removeAt(index + 1);
        continue;
      }
      index++;
    }
  }

  List<EditOperation> _toOperations(String originalText) {
    final operations = <EditOperation>[];
    final inserted = <String>[];
    var originalCursor = 0;

    void flush(int originalEnd) {
      final text = inserted.join();
      inserted.clear();
      if (originalCursor == originalEnd && text.isEmpty) return;
      if (originalText.substring(originalCursor, originalEnd) == text) {
        originalCursor = originalEnd;
        return;
      }
      operations.add(EditOperation.replace(originalCursor, originalEnd, text));
      originalCursor = originalEnd;
    }

    for (final segment in _segments) {
      if (segment is _InsertedDeltaSegment) {
        inserted.add(segment.text);
        continue;
      }
      final original = segment as _OriginalDeltaSegment;
      if (original.start != originalCursor || inserted.isNotEmpty) flush(original.start);
      originalCursor = original.end;
    }
    if (originalCursor != _originalLength || inserted.isNotEmpty) flush(_originalLength);
    return operations;
  }
}

abstract class _DeltaSegment {
  int get length;

  List<_DeltaSegment> split(int offset);
}

class _OriginalDeltaSegment implements _DeltaSegment {
  const _OriginalDeltaSegment(this.start, this.end);

  final int start;
  final int end;

  @override
  int get length => end - start;

  @override
  List<_DeltaSegment> split(int offset) => [
    _OriginalDeltaSegment(start, start + offset),
    _OriginalDeltaSegment(start + offset, end),
  ];
}

class _InsertedDeltaSegment implements _DeltaSegment {
  const _InsertedDeltaSegment(this.text);

  final String text;

  @override
  int get length => text.length;

  @override
  List<_DeltaSegment> split(int offset) => [
    _InsertedDeltaSegment(text.substring(0, offset)),
    _InsertedDeltaSegment(text.substring(offset)),
  ];
}
