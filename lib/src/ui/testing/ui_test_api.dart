/// Internal white-box test surface. Application code must import
/// `package:flutter_base/ui.dart` instead.
library;

export 'package:flutter_base/ui.dart';
export '../cores/editable/render/editable_line_view.dart' show EditableLineView, RenderEditableLine;
export '../cores/editable/render/editable_caret_motion_overlay.dart' show RenderEditableCaretMotionOverlay;
export '../cores/editable/render/editable_render_scope.dart'
    show EditableLineCaretPaint, EditableLinePaint, EditableRenderConfig;
export '../cores/view/event/dispatcher.dart';
export '../cores/view/event/press.dart' show EventDetailsAccess;
export 'package:flutter_base/src/ui/cores/image/render/render_image_view.dart';
export 'package:flutter_base/src/ui/cores/image/image_decode_pipeline.dart' show ImageDecodePipeline;
export '../cores/scroll/common/pointer/scroll_touch_gate.dart';
export '../cores/scroll/refresh/refresher.dart' show RefreshGapClip, RenderRefreshGapClip;
export '../cores/scroll/refresh/refresh_host.dart';
export '../cores/scroll/common/render/scroll_viewport_base.dart';
export '../cores/scroll/virtual/virtual_pipeline.dart'
    show ElScrollViewStateTesting, ElVirtualScrollDebugCounters, ScrollMixinClientProbe, ScrollMixinClientProbeState;
export 'package:flutter_base/src/ui/views/menu/context_menu.dart';
export '../cores/selection/common/selection_core.dart';
export '../cores/selection/docs/selection_view.dart';
export '../cores/view/style/animation/driver.dart';
export '../cores/view/style/animation/field_animation.dart';
export '../cores/view/style/style_context.dart';
export '../cores/view/render/content_sizes.dart';
export '../cores/view/render/box_painter.dart';
export '../cores/view/style/cascade/tick.dart';
export '../cores/view/style/damage.dart';
export '../cores/view/render/render_view.dart';
export '../cores/view/render/scroll_cursor_freeze.dart';
export '../cores/view/style/state/view_state.dart';
export '../cores/view/style/cascade/resolver.dart';
export '../cores/view/style/style.dart';
export '../cores/view/style/internal/field_spec.dart';
export '../cores/view/style/resolved/resolved_style.dart';
export 'package:flutter_base/src/ui/cores/view/text/text_engine.dart';

// 可编辑渲染的显式白盒入口，业务代码仅使用 el_ui.dart。
export '../cores/editable/editable_view.dart' show EditableView, EditableViewTestState;
export '../cores/editable/editable_controller.dart' show EditableController;
export '../cores/editable/editable_style.dart' show EditableConfiguration;
export '../cores/editable/line_height.dart' show EditableLineHeightMode, EditableLineMetrics;
export '../cores/editable/model/text_document.dart' show DocumentEdit, LinePosition, TextDocument, TextDocumentEol;
export '../cores/editable/model/editable_selection.dart' show EditableSelection, EditableSelectionSet;
export '../cores/editable/model/edit_operation.dart' show EditOperation;
export '../cores/editable/model/edit_transaction.dart' show EditableEditSource, EditTransaction;
export '../cores/editable/model/edit_interceptor.dart'
    show
        EditableEditAllowed,
        EditableEditContext,
        EditableEditInterception,
        EditableEditInterceptor,
        EditableEditRejected,
        EditableEditRejectedException,
        EditableEditRewritten;
export '../cores/editable/model/document_change_set.dart' show DocumentChangeSet;
export '../cores/editable/model/document_version.dart' show DocumentVersion;
export '../cores/editable/composer.dart' show EditableComposer, EditableLineContext, EditableWindowedComposer;
export '../cores/editable/projection/editable_hidden_areas_model.dart' show EditableHiddenArea, EditableLineMask;

export 'editable_test_api.dart';
export '../cores/editable/inline_content.dart' show InlineContent, InlineContentMatcher;
export '../cores/editable/render/inline_text_painter.dart'
    show InlineTextProjection, InlineTextPainter, InlineContentWidget;
