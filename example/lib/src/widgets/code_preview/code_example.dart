import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';

import 'code_preview.dart';

/// 卡片圆角（与站点卡片语言一致）。
const _kCardRadius = 12.0;

/// 代码区只收底角，与卡片底边对齐。
const _kCodeBottomRadius = BorderRadius.only(
  bottomLeft: Radius.circular(_kCardRadius),
  bottomRight: Radius.circular(_kCardRadius),
);

/// 多文件代码示例中的单个源码文件。
@immutable
final class ElCodeFile {
  /// 创建源码文件，文件名不能为空。
  const ElCodeFile({required this.name, required this.code, this.lang = 'dart'}) : assert(name != '', '文件名不能为空。');

  /// 文件栏显示的文件名。
  final String name;

  /// 文件源码。
  final String code;

  /// 传给代码高亮器的语言 id，默认是 Dart。
  final String lang;
}

/// 站点级展开联动域：非 null 时强制覆盖域内全部示例卡的折叠态
/// （文档站「默认展开示例代码」设置用）。null = 不覆盖，卡片各自按
/// [ElCodeExample.expanded] 与手动折叠结果显示。
class ElCodeExampleScope extends InheritedWidget {
  /// 创建联动域。
  const ElCodeExampleScope({required this.expandedAll, required super.child, super.key});

  /// 全局强制展开值；null = 不覆盖。
  final bool? expandedAll;

  /// 读取最近联动域；null = 无覆盖。
  static bool? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ElCodeExampleScope>()?.expandedAll;

  @override
  bool updateShouldNotify(ElCodeExampleScope oldWidget) => expandedAll != oldWidget.expandedAll;
}

/// 示例卡：演示区 + 可折叠高亮代码。
///
/// 用法：`ElCodeExample(code: '源码', children: [演示组件])`
/// 多文件示例改传 [files]，它与 [code] 互斥。
///
/// 卡壳使用文档主题 token，默认无阴影，hover 时浮起。
class ElCodeExample extends StatefulWidget {
  /// 创建示例卡。
  const ElCodeExample({
    super.key,
    this.code,
    this.files,
    this.padding = const .all(20),
    required this.children,
    this.expanded = false,
  }) : assert(code == null || files == null, 'code 与 files 不能同时传入。');

  /// 演示源码；null 时不显示代码区与折叠条。
  final String? code;

  /// 多文件演示源码；显式传入时即使只有一个文件也显示文件栏。
  final List<ElCodeFile>? files;

  /// 初始是否展开代码。
  final bool expanded;

  /// 演示区内边距。
  final EdgeInsetsGeometry padding;

  /// 演示内容。
  final List<Widget> children;

  @override
  State<ElCodeExample> createState() => _CodeExampleState();

  static bool _debugValidateFiles(List<ElCodeFile>? files) {
    if (files == null) return true;
    assert(files.isNotEmpty, 'files 不能为空列表。');
    final names = <String>{};
    for (final file in files) {
      assert(file.name.trim().isNotEmpty, '文件名不能为空。');
      assert(names.add(file.name), 'files 中的文件名必须唯一。');
    }
    return true;
  }
}

class _CodeExampleState extends State<ElCodeExample> {
  late bool _expanded = widget.expanded;
  late String? _selectedFileName = _fallbackFileName(widget.files);

  /// 生效折叠态：联动域非 null 时强制覆盖，null 时用卡片自身状态
  /// （初始参数 + 手动折叠结果）。
  bool get _effectiveExpanded => ElCodeExampleScope.of(context) ?? _expanded;

  bool get _hasCode => widget.code != null || widget.files != null;

  ElCodeFile? get _selectedFile {
    final files = widget.files;
    if (files == null) return null;
    return files.firstWhere((file) => file.name == _selectedFileName);
  }

  void _toggle() => setState(() => _expanded = !_expanded);

  void _selectFile(String name) {
    if (_selectedFileName == name) return;
    setState(() => _selectedFileName = name);
  }

  @override
  void didUpdateWidget(covariant ElCodeExample oldWidget) {
    super.didUpdateWidget(oldWidget);
    final files = widget.files;
    if (files == null) {
      _selectedFileName = null;
    } else if (!files.any((file) => file.name == _selectedFileName)) {
      _selectedFileName = _fallbackFileName(files);
    }
  }

  static String? _fallbackFileName(List<ElCodeFile>? files) {
    if (files == null || files.isEmpty) return null;
    for (final file in files) {
      if (file.name == 'ui.dart') return file.name;
    }
    return files.first.name;
  }

  ElStyle get _cardStyle => ElStyle(
    width: '100%',
    margin: .only(top: 16),
    backgroundColor: _PreviewColors.of(context).cBgElv,
    border: .all(borderColor: _PreviewColors.of(context).cDivider),
    borderRadius: .all(Radius.circular(_kCardRadius)),
    clipBehavior: Clip.antiAlias,
    onHover: ElStyle(boxShadow: _PreviewColors.shadow2),
    transition: [.all(Duration(milliseconds: 200))],
  );

  @override
  Widget build(BuildContext context) {
    assert(ElCodeExample._debugValidateFiles(widget.files));
    return RepaintBoundary(
      child: ElCardView(
        style: _cardStyle,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RepaintBoundary(
              child: ElCardView(
                key: ValueKey('el-code-example-stage'),
                style: ElStyle(padding: widget.padding),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _spaced(widget.children, 8),
                ),
              ),
            ),
            if (_hasCode) ...[
              _CodeToggleBar(expanded: _effectiveExpanded, onToggle: _toggle),
              ElCollapseAnimation(
                _effectiveExpanded,
                duration: Duration(milliseconds: 250),
                curve: Curves.easeOut,
                keepState: false,
                child: RepaintBoundary(
                  child: widget.files == null
                      ? ElCodePreview(
                          code: widget.code!,
                          lang: 'dart',
                          showLineNumbers: true,
                          showToolbar: false,
                          borderRadius: _kCodeBottomRadius,
                        )
                      : _MultiFileCodePreview(
                          files: widget.files!,
                          selectedFile: _selectedFile!,
                          onSelected: _selectFile,
                        ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static List<Widget> _spaced(List<Widget> items, double gap) {
    if (items.isEmpty) return [];
    return [
      for (var i = 0; i < items.length; i++) ...[if (i > 0) ElView(style: ElStyle(height: gap)), items[i]],
    ];
  }
}

/// 多文件预览只在原代码预览器上方增加文件栏。
class _MultiFileCodePreview extends StatelessWidget {
  const _MultiFileCodePreview({required this.files, required this.selectedFile, required this.onSelected});

  final List<ElCodeFile> files;
  final ElCodeFile selectedFile;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CodeFileBar(files: files, selectedName: selectedFile.name, onSelected: onSelected),
        ElCodePreview(
          code: selectedFile.code,
          lang: selectedFile.lang,
          showLineNumbers: true,
          showToolbar: false,
          borderRadius: _kCodeBottomRadius,
        ),
      ],
    );
  }
}

/// 文件栏保持单行并横向滚动，长文件名不会挤压或截断。
class _CodeFileBar extends StatelessWidget {
  const _CodeFileBar({required this.files, required this.selectedName, required this.onSelected});

  final List<ElCodeFile> files;
  final String selectedName;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return ElView(
      key: ValueKey<String>('el-code-example-file-bar'),
      themeMode: ElThemeMode(brightness: .dark, duration: .zero),
      style: ElStyle(
        width: '100%',
        height: 48,
        backgroundColor: Color(0xff282c34),
        border: .only(borderBottom: ElBorderSide(borderColor: Color(0x1fabb2bf))),
      ),
      child: ElScrollView(
        axis: .horizontal,
        scrollbar: ElNoScrollBar(),
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final file in files)
                _CodeFileButton(
                  file: file,
                  selected: file.name == selectedName,
                  onPressed: () => onSelected(file.name),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 文件按钮用 ElButtonView 统一提供点击、键盘、焦点与选中语义。
class _CodeFileButton extends StatelessWidget {
  const _CodeFileButton({required this.file, required this.selected, required this.onPressed});

  final ElCodeFile file;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElButtonView(
      key: ValueKey<(String, String)>(('el-code-example-file', file.name)),
      selected: selected,
      semanticLabel: file.name,
      onPressed: onPressed,
      style: _fileButtonStyle,
      child: ElView(
        semantics: ElSemantics(exclude: true),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 8,
          children: [
            ElView(style: ElStyle(fontSize: 15, lineHeight: 1), child: Icons.description_outlined),
            ElView(style: ElStyle(maxLines: 1, softWrap: false), child: file.name),
          ],
        ),
      ),
    );
  }
}

/// 文件按钮用背景、底边和文字三种信号共同表达选中态。
ElStyle get _fileButtonStyle => ElStyle(
  height: 48,
  padding: .symmetric(horizontal: 16),
  alignment: .center,
  color: Color(0xffabb2bf),
  fontSize: 13,
  fontWeight: .w500,
  lineHeight: 1,
  userSelect: .none,
  cursor: SystemMouseCursors.click,
  onHover: ElStyle(backgroundColor: Color(0x143c4451)),
  onTap: ElStyle(backgroundColor: Color(0x293c4451)),

  onFocusVisible: ElStyle(outline: ElOutline(outlineWidth: 2, outlineColor: Color(0xff61afef), outlineOffset: -2)),
  transition: [.all(Duration(milliseconds: 150))],
  iconColor: Color(0xffabb2bf),
);

/// 折叠条：默认只有居中箭头；hover 时文本淡入、整组左移归位。
class _CodeToggleBar extends StatelessWidget {
  const _CodeToggleBar({required this.expanded, required this.onToggle});

  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final label = expanded ? '收起代码' : '展开代码';
    return ElButtonView(
      key: ValueKey('el-code-example-toggle'),
      onPressed: onToggle,
      semanticLabel: label,
      style: _barStyle(context),
      child: Builder(
        builder: (context) => ElView(
          style: _toggleShiftStyle(context),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElView(
                key: ValueKey('el-code-example-arrow'),
                style: ElStyle(
                  transform: ElTransform.rotate(expanded ? 3.14159 : 0),
                  transformOrigin: .center,
                  transition: [.field(ElTransitionField.transform, Duration(milliseconds: 300), Curves.easeOut)],
                ),
                child: ElView(style: ElStyle(fontSize: 16, lineHeight: 1), child: Icons.keyboard_arrow_down),
              ),
              ElView(
                key: ValueKey('el-code-example-toggle-label'),
                style: _textRevealStyle(context),
                semantics: ElSemantics(exclude: true),
                child: label,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 只迁移预览卡消费的旧文档颜色，避免把旧应用主题带入当前示例。
class _PreviewColors {
  _PreviewColors.of(BuildContext context) : isDark = ElView.of(context).isDark, cBrand1 = context.elTheme.primary;

  final bool isDark;
  final Color cBrand1;

  Color get cBgElv => isDark ? Color(0xff202127) : Color(0xffffffff);
  Color get cDivider => isDark ? Color(0xff2e2e32) : Color(0xffe2e2e3);
  Color get cText2 => isDark ? Color(0xff98989f) : Color(0xff67676c);

  static final shadow2 = [
    BoxShadow(color: Color(0x12000000), blurRadius: 12, offset: Offset(0, 3)),
    BoxShadow(color: Color(0x12000000), blurRadius: 4, offset: Offset(0, 1)),
  ];
}

/// bar 本体：顶部分割线，hover 淡填充 + 文字转主色。
ElStyle _barStyle(BuildContext context) => ElStyle(
  width: '100%',
  height: 44,
  alignment: .center,
  color: _PreviewColors.of(context).cText2,
  fontSize: 13,
  lineHeight: 1,
  userSelect: .none,
  cursor: SystemMouseCursors.click,
  border: .only(borderTop: ElBorderSide(borderColor: _PreviewColors.of(context).cDivider)),
  onHover: ElStyle(color: _PreviewColors.of(context).cBrand1, iconColor: _PreviewColors.of(context).cBrand1),
  onTap: ElStyle(color: _PreviewColors.of(context).cBrand1, iconColor: _PreviewColors.of(context).cBrand1),
  onFocusVisible: ElStyle(
    outline: ElOutline(outlineWidth: 2, outlineColor: _PreviewColors.of(context).cBrand1, outlineOffset: -2),
  ),
  transition: [
    .fields({ElTransitionField.color, ElTransitionField.backgroundColor}, Duration(milliseconds: 250), Curves.easeOut),
  ],
  iconColor: _PreviewColors.of(context).cText2,
);

/// 文本槽恒定宽：8 间隙 + 64 文本（'展开代码' / '收起代码' 恒四字）。
const _kToggleTextSlot = 72.0;

/// 偏移壳：idle 右移让箭头居中，hover 时滑回原位。
ElStyle _toggleShiftStyle(BuildContext context) =>
    ElStyle(
      transform: .translate(_kToggleTextSlot / 2, 0),
      transition: [.field(ElTransitionField.transform, Duration(milliseconds: 250), Curves.easeOut)],
    ).merge(
      ElStyle()
          .merge(ElView.of(context).hasHover ? ElStyle(transform: .translate(0, 0)) : null)
          .merge(ElView.of(context).hasTap ? ElStyle(transform: .translate(0, 0)) : null),
    );

/// 文本显隐盒：恒定槽宽，显隐只走透明度。
ElStyle _textRevealStyle(BuildContext context) =>
    ElStyle(
      width: _kToggleTextSlot,
      padding: .only(left: 8),
      maxLines: 1,
      softWrap: false,
      clipBehavior: Clip.hardEdge,
      opacity: 0,
      transition: [.field(ElTransitionField.opacity, Duration(milliseconds: 250), Curves.easeOut)],
    ).merge(
      ElStyle()
          .merge(ElView.of(context).hasHover ? ElStyle(opacity: 1) : null)
          .merge(ElView.of(context).hasTap ? ElStyle(opacity: 1) : null),
    );
