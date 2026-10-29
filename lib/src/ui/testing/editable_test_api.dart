import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import '../cores/editable/controller.dart';
import '../cores/editable/editable_controller.dart';
import '../cores/editable/editable_view.dart';
import '../cores/editable/model/document_change_set.dart';
import '../cores/editable/model/editable_selection.dart';
import '../cores/editable/model/text_document.dart';
import '../cores/editable/render/editable_line_view.dart';

/// 从已挂载编辑器读取最终文字样式，避免把声明参数当成实际排版结果。
TextStyle? editableTextStyleOf(BuildContext context) {
  TextStyle? result;
  void visit(Element element) {
    if (result != null) return;
    if (element is RenderObjectElement && element.renderObject is RenderEditableLine) {
      result = (element.renderObject as RenderEditableLine).scope.config.textStyle;
      return;
    }
    element.visitChildElements(visit);
  }

  visit(context as Element);
  return result;
}

/// 仅供普通输入框的白盒测试读取内部通知和历史，不进入业务入口。
extension EditableControllerTestAccess on ElEditableController {
  EditableController get testModel => this as EditableController;
  TextDocument get document => testModel.document;
  EditableSelectionSet get selections => testModel.selections;
  Listenable get docChanges => testModel.docChanges;
  Listenable get visualChanges => testModel.visualChanges;
  Listenable get configurationChanges => testModel.configurationChanges;
  int get visualRevision => testModel.visualRevision;
  int get configurationRevision => testModel.configurationRevision;
  int get undoDepth => testModel.undoDepth;
  int get redoDepth => testModel.redoDepth;
  DocumentChangeSet? get lastChangeSet => testModel.lastChangeSet;
  ValueListenable<DocumentChangeSet?> get transactionChanges => testModel.transactionChanges;
}

/// 从公开宿主找到真实的私有渲染 State，避免把宿主壳误当成渲染器。
EditableViewTestState findEditableViewState(BuildContext context) {
  EditableViewTestState? result;
  void visit(Element element) {
    if (element is StatefulElement && element.state is EditableViewTestState) {
      result = element.state as EditableViewTestState;
      return;
    }
    element.visitChildElements(visit);
  }

  visit(context as Element);
  return result!;
}
