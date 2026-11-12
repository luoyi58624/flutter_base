import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';

import 'panel.dart';

/// 文件选择与可取消的本地上传模拟，不向服务端发送文件。
class UploadShowcase extends StatelessWidget {
  /// 创建自动和手动上传两个示例。
  const UploadShowcase({super.key});
  @override
  Widget build(BuildContext context) => ShowcaseGrid(children: [_Upload(auto: true), _Upload(auto: false)]);
}

class _Upload extends HookWidget {
  const _Upload({required this.auto});
  final bool auto;
  @override
  Widget build(BuildContext context) {
    final files = useState(<ElUploadFile>[
      if (auto)
        ElUploadFile(
          id: 'cover',
          name: '旅行封面.svg',
          size: 1840,
          status: .success,
          thumbnail: ElImage(showcaseLake, fit: .cover),
        ),
    ]);
    final timers = useMemoized(() => <String, Timer>{});
    final sequence = useRef(0);
    useEffect(
      () => () {
        for (final timer in timers.values) {
          timer.cancel();
        }
      },
      [],
    );
    ElUploadFile replace(ElUploadFile file, ElUploadStatus status, {double? progress, String? error}) => ElUploadFile(
      id: file.id,
      name: file.name,
      size: file.size,
      status: status,
      progress: progress ?? file.progress,
      error: error,
      thumbnail: file.thumbnail,
    );
    void update(String id, ElUploadFile Function(ElUploadFile file) change) {
      if (!context.mounted) return;
      files.value = [for (final file in files.value) file.id == id ? change(file) : file];
    }

    void start(ElUploadFile file, {bool fail = false}) {
      timers.remove(file.id)?.cancel();
      update(file.id, (file) => replace(file, .uploading, progress: 0));
      var progress = 0.0;
      timers[file.id] = Timer.periodic(Duration(milliseconds: 160), (timer) {
        progress += 10;
        if (fail && progress >= 50) {
          timer.cancel();
          timers.remove(file.id);
          update(file.id, (file) => replace(file, .error, progress: progress, error: '上传中断，点击重试'));
        } else if (progress >= 100) {
          timer.cancel();
          timers.remove(file.id);
          update(file.id, (file) => replace(file, .success, progress: 100));
        } else {
          update(file.id, (file) => replace(file, .uploading, progress: progress));
        }
      });
    }

    void cancel(ElUploadFile file) {
      timers.remove(file.id)?.cancel();
      update(file.id, (file) => replace(file, .canceled));
    }

    void addExample({bool fail = false}) {
      if (files.value.length >= 3) {
        demoNotify(context, '最多选择 3 个文件');
        return;
      }
      final id = 'sample-${sequence.value++}';
      final file = ElUploadFile(
        id: id,
        name: fail
            ? '重试示例.txt'
            : auto
            ? '旅行笔记.txt'
            : '待上传文档.txt',
        size: 2480,
      );
      files.value = [...files.value, file];
      if (auto) start(file, fail: fail);
    }

    Future<void> pick() async {
      try {
        final selected = await openFiles(
          acceptedTypeGroups: [
            XTypeGroup(
              label: auto ? '图片和文档' : '文本文件',
              extensions: auto ? ['png', 'jpg', 'jpeg', 'webp', 'svg', 'pdf', 'txt'] : ['txt'],
              uniformTypeIdentifiers: auto
                  ? ['public.image', 'com.adobe.pdf', 'public.plain-text']
                  : ['public.plain-text'],
            ),
          ],
        );
        for (final picked in selected) {
          final size = await picked.length();
          if (!context.mounted) return;
          if (files.value.length >= 3) {
            demoNotify(context, '最多选择 3 个文件');
            break;
          }
          if (size > 5 * 1024 * 1024) {
            demoNotify(context, '${picked.name} 超过 5 MB');
            continue;
          }
          final file = ElUploadFile(id: 'file-${sequence.value++}', name: picked.name, size: size);
          files.value = [...files.value, file];
          if (auto) start(file);
        }
      } catch (_) {
        if (context.mounted) demoNotify(context, '暂时无法打开文件选择器');
      }
    }

    return ShowcasePanel(
      title: auto ? '自动上传' : '手动上传',
      description: auto ? '选择文件后开始上传，列表展示进度、完成与重试状态。' : '先添加文件，再手动开始；上传过程可以随时取消。',
      child: demoColumn([
        ElUpload(
          files: files.value,
          drag: true,
          hint: auto ? '支持图片、PDF、TXT，最多 3 个，每个不超过 5 MB' : '支持 TXT 文件，最多 3 个，每个不超过 5 MB',
          onPick: pick,
          onRemove: (file) {
            timers.remove(file.id)?.cancel();
            files.value = files.value.where((f) => f.id != file.id).toList();
          },
          onRetry: (file) => start(file),
          onCancel: cancel,
        ),
        demoActions([
          ElButton(variant: .outline, child: auto ? '添加示例文件' : '添加文本文件', onPressed: addExample),
          if (auto) ElButton(variant: .text, child: '体验失败重试', onPressed: () => addExample(fail: true)),
          if (!auto)
            ElButton(
              child: '开始上传',
              disabled: !files.value.any((f) => f.status != .success && f.status != .uploading),
              onPressed: () {
                for (final file in files.value.where((f) => f.status != .success && f.status != .uploading).toList()) {
                  start(file);
                }
              },
            ),
          if (!auto)
            ElButton(
              variant: .text,
              child: '取消上传',
              disabled: !files.value.any((f) => f.status == .uploading),
              onPressed: () {
                for (final file in files.value.where((f) => f.status == .uploading).toList()) {
                  cancel(file);
                }
              },
            ),
          ElButton(
            variant: .text,
            child: '清空',
            disabled: files.value.isEmpty,
            onPressed: () {
              for (final timer in timers.values) {
                timer.cancel();
              }
              timers.clear();
              files.value = [];
            },
          ),
        ], gap: 8),
        demoHint(context, '仅模拟上传进度，所选文件保留在本地。'),
      ]),
    );
  }
}
