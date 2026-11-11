import 'package:flutter/widgets.dart';

import '../../../../../flutter.dart';
import '../../commons/icons.dart';
import '../../internal/common.dart';

/// 上传皮肤只展示文件状态并转交动作，不持有文件或发起网络传输。
Widget uploadBuilder(BuildContext context, ElUpload c) {
  final t = context.elTheme;
  String size(int bytes) => bytes < 1024
      ? '$bytes B'
      : bytes < 1048576
      ? '${(bytes / 1024).toStringAsFixed(1)} KB'
      : '${(bytes / 1048576).toStringAsFixed(1)} MB';
  return ElView(
    style: c.style,
    event: c.event,
    semantics: ElSemantics(container: true, label: c.semanticLabel),
    child: Column(
      mainAxisSize: .min,
      crossAxisAlignment: .stretch,
      spacing: 12,
      children: [
        if (c.onPick != null && !c.drag)
          Align(
            alignment: .centerLeft,
            child: ElButton(disabled: c.disabled, onPressed: c.onPick, icon: ElMobileIcons.add, child: '选择文件'),
          ),
        if (c.onPick != null && c.drag)
          ActionView(
            disabled: c.disabled,
            onActivate: (_) => c.onPick!(),
            label: '选择文件',
            style: ElStyle(
              padding: const .symmetric(horizontal: 18, vertical: 24),
              borderRadius: .circular(16),
              border: .all(borderColor: t.borderColor, borderStyle: .dashed),
              backgroundColor: t.fill.withValues(alpha: .5),
              color: t.textColor,
              iconColor: t.primary,
              iconSize: 28,
            ),
            child: Column(
              mainAxisSize: .min,
              spacing: 10,
              children: [
                ElMobileIcons.cloud,
                const Text('点击选择文件', style: TextStyle(fontSize: 14, fontWeight: .w500)),
                if (c.hint != null)
                  Text(
                    c.hint!,
                    textAlign: .center,
                    style: TextStyle(fontSize: 12, color: t.textSecondary, height: 1.6),
                  ),
              ],
            ),
          ),
        for (final file in c.files)
          ElView(
            key: ValueKey(file.id),
            style: ElStyle(padding: const .all(12), borderRadius: .circular(14), backgroundColor: t.fill),
            child: Row(
              children: [
                ElView(
                  style: ElStyle(
                    width: 42,
                    height: 42,
                    alignment: .center,
                    borderRadius: .circular(10),
                    backgroundColor: t.cardColor,
                    clipBehavior: .antiAlias,
                    iconColor: t.primary,
                    iconSize: 22,
                  ),
                  child: file.thumbnail ?? ElMobileIcons.file,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: .min,
                    crossAxisAlignment: .stretch,
                    spacing: 5,
                    children: [
                      Text(
                        file.name,
                        maxLines: 1,
                        overflow: .ellipsis,
                        style: TextStyle(fontSize: 13, color: t.textColor),
                      ),
                      Text(switch (file.status) {
                        .ready => '${size(file.size)} · 等待上传',
                        .uploading => '上传中 ${file.progress.round()}%',
                        .success => '${size(file.size)} · 上传成功',
                        .error => file.error ?? '上传失败，请重试',
                        .canceled => '已取消',
                      }, style: TextStyle(fontSize: 11, color: file.status == .error ? t.error : t.textSecondary)),
                      if (file.status == .uploading)
                        ElProgress(value: file.progress, showText: false, style: const ElStyle(height: 3)),
                    ],
                  ),
                ),
                if ((file.status == .error || file.status == .canceled) && c.onRetry != null)
                  ElButton(
                    semanticLabel: '重试 ${file.name}',
                    variant: .text,
                    disabled: c.disabled,
                    style: const ElStyle(padding: .all(8)),
                    child: '重试',
                    onPressed: () => c.onRetry!(file),
                  ),
                if (file.status == .uploading && c.onCancel != null)
                  ElButton(
                    semanticLabel: '取消 ${file.name}',
                    variant: .text,
                    disabled: c.disabled,
                    style: const ElStyle(padding: .all(8)),
                    child: '取消',
                    onPressed: () => c.onCancel!(file),
                  )
                else if (c.onRemove != null)
                  ElButton(
                    semanticLabel: '移除 ${file.name}',
                    variant: .text,
                    disabled: c.disabled,
                    style: const ElStyle(width: 32, padding: .zero),
                    child: ElMobileIcons.x,
                    onPressed: () => c.onRemove!(file),
                  ),
              ],
            ),
          ),
      ],
    ),
  );
}
