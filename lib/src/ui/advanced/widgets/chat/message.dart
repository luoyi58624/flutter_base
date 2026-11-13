import 'package:flutter/foundation.dart';

/// 聊天行共有的身份、发送方向和发送者信息。
@immutable
abstract class ElChatMessage {
  /// 创建消息，业务可继承此类型以添加自己的消息内容。
  const ElChatMessage({required this.id, required this.isMine, this.senderName, this.avatarSrc, this.sentAt});

  /// 同一会话内唯一且稳定的消息 ID。
  final Object id;

  /// 是否为自己发送的消息。
  final bool isMine;

  /// 发送者的显示名称。
  final String? senderName;

  /// 发送者的头像地址。
  final String? avatarSrc;

  /// 消息发送时间。
  final DateTime? sentAt;
}

/// 显示可选择纯文本的聊天消息。
class ElChatTextMessage extends ElChatMessage {
  /// 创建一条文字消息。
  const ElChatTextMessage({
    required super.id,
    required super.isMine,
    required this.text,
    super.senderName,
    super.avatarSrc,
    super.sentAt,
  });

  /// 可换行的消息正文。
  final String text;
}

/// 显示缩略图并支持点击预览的聊天消息。
class ElChatImageMessage extends ElChatMessage {
  /// 创建一条图片消息，传入宽高比可在加载前预留空间。
  const ElChatImageMessage({
    required super.id,
    required super.isMine,
    required this.src,
    this.aspectRatio,
    this.alt,
    super.senderName,
    super.avatarSrc,
    super.sentAt,
  }) : assert(aspectRatio == null || aspectRatio > 0 && aspectRatio < double.infinity);

  /// 网络、资源或本地图片地址，格式与 ElImageView 一致。
  final String src;

  /// 缩略图的宽高比，省略时使用自然尺寸。
  final double? aspectRatio;

  /// 图片的辅助文字。
  final String? alt;
}

/// 显示文件名和大小的聊天消息。
class ElChatFileMessage extends ElChatMessage {
  /// 创建一条文件消息，调用方可根据消息 ID 查找文件。
  const ElChatFileMessage({
    required super.id,
    required super.isMine,
    required this.name,
    this.size,
    super.senderName,
    super.avatarSrc,
    super.sentAt,
  }) : assert(size == null || size >= 0);

  /// 文件的显示名称。
  final String name;

  /// 文件大小，单位为字节。
  final int? size;
}
