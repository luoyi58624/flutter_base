/// 视图引擎公开入口：`ElView` 盒模型、事件分发、样式与语义。
///
/// 迁移自 el_ui（`packages/el_ui/lib/src/cores/view`），保留 el 侧目录结构，
/// 便于后续与上游同步。
///
/// `sameViewTextPayload` 标注了 `@internal`（引擎内部文本载荷比较），
/// 不随公开面导出。
library;

export 'event/event.dart';
export 'semantics/semantics.dart';
export 'style/style.dart';
export 'view.dart' hide sameViewTextPayload;
