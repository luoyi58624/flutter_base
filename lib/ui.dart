/// flutter_base UI 公共入口：视图引擎（ElView）、事件、选中、滚动、布局、浮层与功能组件。
library;

export 'src/ui/theme.dart';

export 'src/flutter/components/list_tile/index.dart';
export 'src/flutter/views/selection/index.dart';
export 'src/flutter/views/view/index.dart';

export 'package:flutter_base/flutter.dart';

// 基础类型与全局扩展
export 'src/flutter/utils/internal/gutter.dart'
    show
        OrdinalGutterEntry,
        OrdinalGutterEntriesBuilder,
        OrdinalGutterPaintEntry,
        OrdinalGutterHost,
        RenderOrdinalGutter;
export 'src/flutter/views/view/style/dimension.dart' show ElDimension, ElLengthKind;
export 'src/flutter/commons/global.dart' show ElViewExt;
export 'src/flutter/commons/models.dart'
    show ElLabelModel, ElLevelType, ElMenuModel, ElMenuModelExt, ElNestModel, ElThemeType;

// 核心视图、样式、状态与语义
export 'src/flutter/views/view/view.dart' show ElView;
export 'src/flutter/views/view/provider.dart' show ElViewProvider;
export 'src/flutter/views/view/style/style.dart'
    show
        ElAnimation,
        ElAnimationDirection,
        ElAnimationFillMode,
        ElBorder,
        ElBorderAlign,
        ElBorderSide,
        ElBorderStyle,
        ElBoxShadow,
        ElBreakpoint,
        ElClipper,
        ElFilter,
        ElOutline,
        ElPointerEvents,
        ElStyle,
        ElStyleExt,
        ElThemeMode,
        ElTransform,
        ElTransition,
        ElTransitionField,
        ElUserSelect;
export 'src/flutter/views/view/style/style_context.dart' show ElStyleContext;
export 'src/flutter/views/view/style/linear_gradient.dart' show ElLinearGradient;
export 'src/flutter/views/view/render/hit_bounds.dart' show ElOverflowHitBounds;
export 'src/flutter/views/view/render/render_view.dart' show ElRenderView;
export 'src/flutter/views/view/semantics/semantics.dart' show ElSemantics, ElSemanticsExt;

// 事件与手势
export 'src/flutter/views/view/event/event.dart'
    show
        ElDragProxy,
        ElDragProxyExt,
        ElEvent,
        ElEventExt,
        ElEventDetails,
        ElEventCancelReason,
        ElEventConfig,
        ElEventConfigExt,
        ElEventHandler,
        ElEventPhase,
        ElFocusReason;

// 滚动、虚拟化、滚动条与刷新
export 'src/flutter/views/scroll/scroll_view.dart' show ElScrollController, ElScrollView, ElVisibilityInfo, ElVisibleRange;
export 'src/flutter/views/scroll/scroll_state.dart'
    show
        ElScrollSnapshot,
        ElScrollItemSnapshot,
        ElScrollTravelDirection,
        ElScrollInputSource,
        ElScrollActivityType,
        ElScrollUpdateCause,
        ElScrollVelocitySource;
export 'src/flutter/views/scroll/virtual/virtual_pipeline.dart'
    show
        ElScrollViewState,
        ElScrollMixin,
        ElScrollCollapseMixin,
        ElScrollCollapseMode,
        ElLargeTitleNavbarMixin,
        ElScrollRevealMixin,
        ElParallaxMixin,
        ElScrollProgressMixin,
        ElNestedScrollMixin,
        ElScrollDetails,
        ElScrollStartDetails,
        ElScrollUpdateDetails,
        ElScrollEndDetails,
        ElScrollMetricsDetails,
        ElScrollActivityDetails,
        ElScrollItemUpdateDetails,
        ElScrollInputDetails,
        ElScrollReleaseDetails,
        ElScrollSessionDetails,
        ElScrollEffectTrack,
        ElScrollEffectUnit,
        ElStickyMixin;
export 'src/flutter/views/scroll/scrollbar/scrollbar.dart'
    show
        ElAndroidScrollBar,
        ElIosScrollBar,
        ElMacScrollBar,
        ElNoScrollBar,
        ElScrollbar,
        ElScrollbarAxisDetails,
        ElScrollbarDetails,
        ElWindowScrollBar;
export 'src/flutter/views/scroll/smooth_scroll/smooth_scroll.dart'
    show ElChromiumSmoothScroll, ElNoSmoothScroll, ElSmoothScroll, ElWindowsSmoothScroll;
export 'src/flutter/views/scroll/common/nested/nested_scroll.dart' show ElNestedScrollParent;
export 'src/flutter/views/scroll/common/nested/scroll_delta_interceptor.dart'
    show ElScrollDeltaInterceptor, ElScrollDeltaSource;
export 'src/flutter/views/scroll/common/physics/bouncing_scroll_physics.dart' show ElBouncingScrollPhysics;
export 'src/flutter/views/scroll/common/physics/browser_scroll_physics.dart'
    show ElBrowserScrollPhysics, ElFlingBoostSpec, elBrowserMaxFlingDuration, elBrowserMaxFlingVelocity;
export 'src/flutter/views/scroll/common/physics/clamping_scroll_physics.dart' show ElClampingScrollPhysics;
export 'src/flutter/views/scroll/common/physics/platform_scroll_physics.dart' show ElScrollBehavior, elScrollPhysicsFor;
export 'src/flutter/views/scroll/refresh/refresh.dart'
    show
        ElAndroidRefresher,
        ElCustomRefresher,
        ElIosRefresher,
        ElNoRefresher,
        ElRefreshCupertinoSpinner,
        ElRefreshDetails,
        ElRefreshEdge,
        ElRefreshMaterialSpinner,
        ElRefreshSnapshot,
        ElRefresher,
        RefreshIndicatorStatus,
        elWebKitRubberBandSpring;

// 布局
export 'src/flutter/views/layout/stack/stack_view.dart'
    show ElStackView, ElStackItem, ElPositioned, ElStackParentData, RenderStackView;
export 'src/flutter/views/layout/grid/grid_view.dart' show ElGridView, ElGridParentData, ElRenderGridView;
export 'src/flutter/views/layout/list/list_view.dart' show ElListView, ElListParentData, ElRenderListView;

// 浮层、锚点与 Portal
export 'src/flutter/widgets/popup/portal.dart' show ElPortal, ElPortalController, ElPortalPhase;
export 'src/flutter/widgets/popup/anchor.dart' show ElOverlayAnchor, ElOverlayAnchorGeometry, ElPlacement;
export 'src/flutter/widgets/popup/hover_intent.dart' show ElHoverIntent;

// 文本选择、框选与选区操作
export 'src/flutter/views/selection/selection.dart'
    show ElSelectionView, ElSelectionController, ElBoxSelectionView, ElBoxSelectionController, ElBoxSelectable;

// 文本编辑：公开视图和控制器，编辑器扩展由 el_editor 提供。
export 'src/ui/cores/editable/view.dart' show ElEditableView;
export 'src/ui/cores/editable/style.dart' show ElEditableStyle;
export 'src/ui/cores/editable/controller.dart' show ElEditableController;

// 标签页与表格
export 'src/flutter/views/tab/tab_view.dart' show ElTabView;
export 'src/flutter/views/tab/tab_controller.dart' show ElTabController;

export 'src/flutter/views/table/table_column.dart'; // 列 + 大部分配套类型
export 'src/flutter/views/table/table.dart' show ElTable, ElTableStyle, ElTableController, ElTableSelectionChange;

export 'src/flutter/widgets/row/index.dart' show ElCol, ElRow, ElRowAlign, ElRowJustify;

// 基础视图：卡片、按钮、切换、链接与分隔线
export 'src/flutter/views/card/card_view.dart' show ElCardView;
export 'src/flutter/views/button/button_view.dart' show ElButtonView, ElButtonViewPressController;

export 'src/flutter/widgets/link/index.dart' show LinkTarget, ElLink;
export 'src/flutter/widgets/link/status_bar.dart' show ElLinkStatusBar;
export 'src/flutter/widgets/divider/index.dart' show ElDivider;
export 'src/ui/widgets/badge/index.dart' show ElBadge;
export 'src/flutter/widgets/watermark/index.dart' show ElWatermark;
export 'src/flutter/views/splitter/index.dart' show ElSplitterPanel, ElSplitterView;

// 图片、缩放与预览
export 'src/ui/cores/image/image_view.dart' show ElImageView, ImageLoadInfo;
export 'src/ui/cores/image/image_prefetch_controller.dart' show ImagePrefetchController;
export 'src/flutter/views/zoom/zoom_view.dart' show ElZoomController, ElZoomTransform, ElZoomView;
export 'src/flutter/views/preview/preview_view.dart' show ElPreviewController, PreviewItemIdBuilder, ElPreviewView;

// 菜单与上下文菜单
export 'src/ui/widgets/menu_bar/index.dart' show ElMenuBar, ElMenuBarItem, ElMenuBarShortcutPriority;
export 'src/ui/views/menu/context_menu.dart'
    show ElContextMenu, ElContextMenuHandle, ContextMenuInitialFocus, ElContextMenuItem;

// 拖放
export 'src/ui/widgets/dnd/draggable.dart' show ElDraggable;
export 'src/ui/widgets/dnd/drop_target.dart' show ElDropCandidate, ElDropDetails, ElDropTarget;

// 点击反馈
export 'src/flutter/widgets/tap/index.dart' show ElFadeTap, ElRippleTap, ElScaleTap;

// 通用表单状态、校验、字段绑定与布局。
export 'src/flutter/widgets/form/index.dart'
    show
        ElForm,
        ElFormItem,
        ElFormItemView,
        ElFormLabelPosition,
        ElFormModelValue,
        ElFormRule,
        ElFormRuleTrigger,
        ElFormState,
        ElInputModelValue,
        ElInputNumModelValue,
        ElRangeFormRule,
        ElRequiredFormRule;

// 组件
export 'src/flutter/components/index.dart'
    show
        ElAutocomplete,
        ElButton,
        ElButtonGroup,
        ElButtonGroupItem,
        ElButtonGroupMode,
        ElCheckbox,
        ElCheckboxState,
        ElComponentProvider,
        ElComponentBuilders,
        ElComponentBuildersExt,
        ElInput,
        ElInputController,
        ElInputNumber,
        ElInputNumberControls,
        ElInputOtp,
        ElInputOtpType,
        ElInputTag,
        ElInputTagController,
        ElInputTagDuplicatePolicy,
        ElInputTagTrigger,
        ElMention,
        ElMentionContext,
        ElMentionOption,
        ElMentionPlacement,
        ElMentionWholeContext,
        ElRadio,
        ElRadioState,
        ElSelect,
        ElSelectOption,
        ElSwitch,
        ElTag,
        ElTagEffect,
        ElText,
        ElAffix,
        ElAlert,
        ElAlertEffect,
        ElAnchor,
        ElAnchorLink,
        ElAnchorType,
        ElAvatar,
        ElAvatarGroup,
        ElAvatarShape,
        ElBacktop,
        ElCalendar,
        ElCalendarDayType,
        ElCard,
        ElCarousel,
        ElCarouselArrow,
        ElCarouselIndicator,
        ElCarouselTrigger,
        ElCollapse,
        ElCollapseItem,
        ElCountdown,
        ElDescriptions,
        ElDescriptionsItem,
        ElEmpty,
        ElIcon,
        ElListTile,
        ElListTileGroup,
        ElListTileType,
        ElLoadingIndicator,
        ElPagination,
        ElProgress,
        ElProgressColorStop,
        ElProgressShape,
        ElProgressStatus,
        ElProgressTextBuilder,
        ElProgressValue,
        ElRate,
        ElResult,
        ElSegmented,
        ElSegmentedOption,
        ElSkeleton,
        ElSkeletonItem,
        ElSkeletonVariant,
        ElSlider,
        ElStatistic,
        ElStep,
        ElStepStatus,
        ElSteps,
        ElTabBar,
        ElTabIndicatorBuilder,
        ElTabItem,
        ElTabPane,
        ElTabs,
        ElTabsPosition,
        ElTabsType,
        ElTimeline,
        ElTimelineItem,
        ElTimelineNodeSize,
        ElTimelinePlacement,
        resolveElMentionContext,
        resolveElMentionWholeContext;
