/// Internal white-box test surface. Application code must import
/// `package:flutter_base/ui.dart` instead.
library;

export '../../../ui.dart';
export '../../flutter/views/editable/render/editable_line_view.dart' show EditableLineView, RenderEditableLine;
export '../../flutter/views/editable/render/editable_caret_motion_overlay.dart' show RenderEditableCaretMotionOverlay;
export '../../flutter/views/editable/render/editable_render_scope.dart'
    show EditableLineCaretPaint, EditableLinePaint, EditableRenderConfig;
export '../../flutter/views/view/event/dispatcher.dart';
export '../../flutter/views/view/event/drag_pointer_lock.dart';
export '../../flutter/views/view/event/details.dart' show EventDetailsAccess;
export '../../flutter/widgets/image/render/render_image.dart';
export '../../flutter/widgets/popup/context_menu.dart';
export '../../flutter/views/selection/common/selection_core.dart';
export '../../flutter/views/selection/docs/selection_view.dart';
export '../../flutter/views/view/style/animation/driver.dart';
export '../../flutter/views/view/style/animation/field_animation.dart';
export '../../flutter/views/view/style/style_context.dart';
export '../../flutter/views/view/render/content_sizes.dart';
export '../../flutter/views/view/render/box_painter.dart';
export '../../flutter/views/view/style/cascade/tick.dart';
export '../../flutter/views/view/style/damage.dart';
export '../../flutter/views/view/render/render_view.dart';
export '../../flutter/views/view/render/scroll_cursor_freeze.dart';
export '../../flutter/views/view/style/state/view_state.dart';
export '../../flutter/views/view/style/cascade/resolver.dart';
export '../../flutter/views/view/style/style.dart';
export '../../flutter/views/view/style/internal/field_spec.dart';
export '../../flutter/views/view/style/resolved/resolved_style.dart';
export '../../flutter/views/view/text/text_engine.dart';

// 可编辑渲染的显式白盒入口，业务代码仅使用 el_ui.dart。
export '../../flutter/views/editable/editable_view.dart' show EditableView, EditableViewTestState;
export '../../flutter/views/editable/editable_controller.dart' show EditableController;
export '../../flutter/views/editable/editable_style.dart' show EditableConfiguration;
export '../../flutter/views/editable/line_height.dart' show EditableLineHeightMode, EditableLineMetrics;
export '../../flutter/views/editable/model/text_document.dart'
    show DocumentEdit, LinePosition, TextDocument, TextDocumentEol;
export '../../flutter/views/editable/model/editable_selection.dart' show EditableSelection, EditableSelectionSet;
export '../../flutter/views/editable/model/edit_operation.dart' show EditOperation;
export '../../flutter/views/editable/model/edit_transaction.dart' show EditableEditSource, EditTransaction;
export '../../flutter/views/editable/model/edit_interceptor.dart'
    show
        EditableEditAllowed,
        EditableEditContext,
        EditableEditInterception,
        EditableEditInterceptor,
        EditableEditRejected,
        EditableEditRejectedException,
        EditableEditRewritten;
export '../../flutter/views/editable/model/document_change_set.dart' show DocumentChangeSet;
export '../../flutter/views/editable/model/document_version.dart' show DocumentVersion;
export '../../flutter/views/editable/composer.dart'
    show EditableComposer, EditableLineContext, EditableWindowedComposer;
export '../../flutter/views/editable/projection/editable_hidden_areas_model.dart'
    show EditableHiddenArea, EditableLineMask;

export 'editable_test_api.dart';
export '../../flutter/views/editable/inline_content.dart' show InlineContent, InlineContentMatcher;
export '../../flutter/views/editable/render/inline_text_painter.dart'
    show InlineTextProjection, InlineTextPainter, InlineContentWidget;
