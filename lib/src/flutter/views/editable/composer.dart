import 'package:flutter/painting.dart';

/// 上层拥有前景绘制，内核只提供已排版的标准几何。
abstract interface class EditableCanvasComposer {
  void paintForeground(
    Canvas canvas,
    Offset offset, {
    required int line,
    required int lineLength,
    required TextRange visibleRange,
    required TextStyle style,
    required TextDirection textDirection,
    required double lineHeight,
    required double originX,
    required Size size,
    required List<Rect> Function(TextRange) rects,
    required Rect Function(TextPosition, {double widthInCharacters}) characterCell,
  });
}

/// 行装配上下文：composer 装配一行时可见的全部信息。
class EditableLineContext {
  const EditableLineContext({required this.line, required this.text, required this.baseStyle})
    : textStart = 0,
      _windowLineLength = null,
      isCompleteLine = true;

  /// 创建完整逻辑行中的有界装配窗口。
  EditableLineContext.windowed({
    required this.line,
    required this.text,
    required this.baseStyle,
    required this.textStart,
    required int lineLength,
  }) : isCompleteLine = false,
       _windowLineLength = lineLength,
       assert(textStart >= 0),
       assert(textStart + text.length <= lineLength);

  /// 逻辑行 index。
  final int line;

  /// 行纯文本（不含换行符）。
  final String text;

  /// 编辑器基础文本样式（composer 输出应以它为底做增量覆盖）。
  final TextStyle baseStyle;

  /// 当前 [text] 在完整逻辑行中的 UTF-16 起点。
  final int textStart;

  /// 完整逻辑行的 UTF-16 长度。
  int get lineLength => _windowLineLength ?? text.length;
  final int? _windowLineLength;

  /// 当前 [text] 是否就是完整逻辑行。
  final bool isCompleteLine;
}

/// 行内容装配器：把一行纯文本装配成 [InlineSpan]。
///
/// 对齐 vscode 的 tokens / decorations 呈现层——**文本内容归文档模型，呈现
/// 属性归装配器**。上层凭它实现语法高亮、富文本、搜索命中标注等，而编辑
/// 内核（光标 / 选区 / IME / 编辑操作）完全不感知呈现属性的存在。
///
/// 合约：
/// - 输出 span 的**纯文本必须与 [EditableLineContext.text] 完全一致**
///   （编辑坐标 = 纯文本 offset，装配只准换样式不准换内容；debug 下断言）。
/// - 不支持 [PlaceholderSpan] / `WidgetSpan`：editable 行是纯文本 Paragraph，
///   inline widget 没有文档 offset、字素、选区、IME 与语义合同；请用 decoration
///   或 overlay 呈现非文本内容。违反时所有构建模式都会明确抛出 [FlutterError]。
/// - 装配必须是纯函数：同一（行文本, 呈现版本）恒产出等价 span。呈现属性
///   变化（如高亮规则更新、富文本属性编辑）后调用
///   [EditableController.invalidatePresentation] 触发重排。
/// - 装配在行 relayout 时同步执行，重实现应自带缓存（行文本 + 属性版本为 key）。
abstract class EditableComposer {
  const EditableComposer();

  /// 纯文本装配器（默认）。
  static const EditableComposer plain = _PlainComposer();

  /// 装配一行。
  InlineSpan compose(EditableLineContext context);
}

/// 显式声明 composer 理解有界长行窗口的能力标记。
///
/// 未实现本接口的旧 composer 在长行中会降级为纯文本；短行行为
/// 不变。能力独立于 [EditableComposer] 是为了不破坏既有
/// `implements EditableComposer` 的源码兼容性。
abstract interface class EditableWindowedComposer {}

class _PlainComposer extends EditableComposer implements EditableWindowedComposer {
  const _PlainComposer();

  @override
  InlineSpan compose(EditableLineContext context) => TextSpan(text: context.text, style: context.baseStyle);
}
