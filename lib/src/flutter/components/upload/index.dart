import 'package:flutter/widgets.dart';

import '../../views/view/style/style.dart';
import '../../views/view/event/event.dart';
import '../index.dart';

/// 上传项当前状态，实际文件读取和传输由应用提供。
enum ElUploadStatus {
  /// 已选择，等待上传。
  ready,

  /// 正在传输。
  uploading,

  /// 上传完成。
  success,

  /// 上传失败，可重试。
  error,

  /// 已取消，可再次开始。
  canceled,
}

/// 上传列表的不可变展示数据。
class ElUploadFile {
  /// id 是列表内稳定身份，文件句柄由应用保存。
  const ElUploadFile({
    required this.id,
    required this.name,
    this.size = 0,
    this.status = .ready,
    this.progress = 0,
    this.error,
    this.thumbnail,
  });

  /// 稳定业务身份。
  final String id;

  /// 文件名。
  final String name;

  /// 文件字节数。
  final int size;

  /// 当前状态。
  final ElUploadStatus status;

  /// 0 至 100 的传输进度。
  final double progress;

  /// 错误说明。
  final String? error;

  /// 可选预览内容，原实例由品牌保留。
  final Widget? thumbnail;
}

/// 文件选择入口与上传列表，传输、取消和重试由调用方回调负责。
class ElUpload extends StatelessWidget {
  /// 组件不绑定文件系统或网络库，应用可注入任意来源。
  const ElUpload({
    super.key,
    required this.files,
    this.onPick,
    this.onRemove,
    this.onRetry,
    this.onCancel,
    this.hint,
    this.drag = false,
    this.disabled = false,
    this.style,
    this.event,
    this.semanticLabel,
  });

  /// 当前文件列表。
  final List<ElUploadFile> files;

  /// 打开应用提供的文件选择器。
  final VoidCallback? onPick;

  /// 移除指定文件。
  final ValueChanged<ElUploadFile>? onRemove;

  /// 重新上传指定文件。
  final ValueChanged<ElUploadFile>? onRetry;

  /// 取消指定文件的传输。
  final ValueChanged<ElUploadFile>? onCancel;

  /// 文件类型、大小等辅助说明。
  final String? hint;

  /// 使用拖放区域外观；平台文件拖放由外层通过 event 接入。
  final bool drag;

  /// 禁止全部操作。
  final bool disabled;

  /// 覆盖品牌默认外观。
  final ElStyle? style;

  /// 接入原生事件。
  final ElEvent? event;

  /// 辅助名称。
  final String? semanticLabel;
  @override
  Widget build(BuildContext context) => ElComponentProvider.builderOf(context, this, (b) => b.upload)(context, this);
}
