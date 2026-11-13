part of 'scroll.dart';

class _ChatMessageRow extends StatelessWidget {
  const _ChatMessageRow({
    required this.message,
    required this.avatarBuilder,
    required this.messageBuilder,
    required this.onOpenFile,
  });

  final ElChatMessage message;
  final Widget? Function(BuildContext, ElChatMessage)? avatarBuilder;
  final Widget? Function(BuildContext, ElChatMessage)? messageBuilder;
  final ValueChanged<ElChatFileMessage>? onOpenFile;

  @override
  Widget build(BuildContext context) {
    final mine = message.isMine;
    final name = message.senderName;
    final time = message.sentAt?.toLocal();
    final colors = Theme.of(context).colorScheme;
    final view = ElView.maybeOf(context);
    final secondary = view?.getVar<Color>(ElTokens.$textSecondary) ?? colors.onSurfaceVariant;
    final background = mine
        ? (view?.getVar<Color>(ElTokens.$primary) ?? colors.primary).withValues(alpha: .12)
        : view?.getVar<Color>(ElTokens.$fill) ?? colors.surfaceContainerHighest;
    final avatar = avatarBuilder?.call(context, message) ?? _avatar(context, name);
    final body = messageBuilder?.call(context, message) ?? _body(context);

    return Padding(
      padding: const .symmetric(horizontal: 12, vertical: 6),
      child: Row(
        mainAxisAlignment: mine ? .end : .start,
        crossAxisAlignment: .start,
        spacing: 8,
        children: [
          if (!mine) avatar,
          Flexible(
            child: Column(
              mainAxisSize: .min,
              crossAxisAlignment: mine ? .end : .start,
              spacing: 4,
              children: [
                if (!mine && name != null && name.isNotEmpty)
                  Text(name, style: TextStyle(color: secondary, fontSize: 11)),
                ElView(
                  style: ElStyle(backgroundColor: background, padding: const .all(10), borderRadius: .circular(12)),
                  child: body,
                ),
                if (time != null)
                  Text(
                    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(color: secondary, fontSize: 10),
                  ),
              ],
            ),
          ),
          if (mine) avatar,
        ],
      ),
    );
  }

  Widget _avatar(BuildContext context, String? name) {
    final label = name?.trim() ?? '';
    final src = message.avatarSrc;
    if (ElComponentProvider.maybeOf(context)?.avatar != null) {
      return ElAvatar(src: src, alt: label, size: 34, child: label.isEmpty ? const Icon(Icons.person_outline) : null);
    }
    final colors = Theme.of(context).colorScheme;
    final fallback = ColoredBox(
      color: colors.surfaceContainerHighest,
      child: Center(child: label.isEmpty ? const Icon(Icons.person_outline, size: 18) : Text(label.characters.first)),
    );
    return SizedBox.square(
      dimension: 34,
      child: ClipOval(
        child: src == null || src.isEmpty ? fallback : ElImageView(src, fit: .cover, error: fallback),
      ),
    );
  }

  Widget _body(BuildContext context) => switch (message) {
    ElChatTextMessage(:final text) => SelectableText(text),
    ElChatImageMessage(:final src, :final alt, :final aspectRatio) => _ChatImage(src, alt, aspectRatio),
    final ElChatFileMessage file => _ChatFile(file: file, onOpen: onOpenFile),
    _ => const Text('无法显示此消息'),
  };
}

class _ChatImage extends StatelessWidget {
  const _ChatImage(this.src, this.alt, this.aspectRatio);

  final String src;
  final String? alt;
  final double? aspectRatio;

  @override
  Widget build(BuildContext context) {
    final image = ElImagePreview(
      child: ElImageView(
        src,
        alt: alt,
        fit: .contain,
        placeholder: const Center(child: Icon(Icons.image_outlined)),
        error: const Center(child: Icon(Icons.broken_image_outlined, semanticLabel: '图片加载失败')),
      ),
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 240, maxHeight: 240, minHeight: 48),
      child: aspectRatio == null ? image : AspectRatio(aspectRatio: aspectRatio!, child: image),
    );
  }
}

class _ChatFile extends StatelessWidget {
  const _ChatFile({required this.file, required this.onOpen});

  final ElChatFileMessage file;
  final ValueChanged<ElChatFileMessage>? onOpen;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisSize: .min,
      spacing: 8,
      children: [
        const Icon(Icons.insert_drive_file_outlined),
        Flexible(
          child: Column(
            mainAxisSize: .min,
            crossAxisAlignment: .start,
            children: [
              Text(file.name, maxLines: 2, overflow: .ellipsis),
              if (file.size case final size?) Text(size == 0 ? '0 B' : ElDartUtil.formatSize(size)),
            ],
          ),
        ),
      ],
    );
    final open = onOpen;
    if (open == null) return child;
    if (ElComponentProvider.maybeOf(context)?.button == null) {
      return Semantics(
        button: true,
        child: GestureDetector(onTap: () => open(file), child: child),
      );
    }
    return ElButton(variant: .text, onPressed: () => open(file), child: child);
  }
}
