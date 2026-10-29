import 'package:flutter/painting.dart' show TextPosition;

final class EditableBoxSelectionRow {
  /// 创建一个已完成排版命中的列选视觉行。
  const EditableBoxSelectionRow({required this.anchor, required this.active, this.isActiveRow = false});

  /// 列选固定端在本视觉行的文档位置。
  final TextPosition anchor;

  /// 列选活动端在本视觉行的文档位置。
  final TextPosition active;

  /// 本行是否承载当前指针；它会成为主选区以保留活动端身份。
  final bool isActiveRow;
}
