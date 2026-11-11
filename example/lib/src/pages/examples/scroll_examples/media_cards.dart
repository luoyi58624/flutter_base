part of 'media.dart';

double _footerExtent(BuildContext context) {
  final scaler = MediaQuery.textScalerOf(context);
  return scaler.scale(13) * 1.3 * 2 + scaler.scale(10.5) * 1.3 + 23;
}

double _feedExtent(BuildContext context, double width) => (width - 6) * .75 + _footerExtent(context) + 6;

const _waterfallGap = 6.0;

({double title, double description, double source}) _waterfallCaptionSlots(BuildContext context) {
  final scaler = MediaQuery.textScalerOf(context);
  return (
    title: (scaler.scale(13) * 1.3).ceilToDouble() * 2,
    description: (scaler.scale(11) * 1.3).ceilToDouble() * 3,
    source: math.max(12, (scaler.scale(10.5) * 1.3).ceilToDouble()),
  );
}

double _waterfallFooterExtent(BuildContext context) {
  final slots = _waterfallCaptionSlots(context);
  return slots.title + slots.description + slots.source + 26;
}

Widget _caption(String value, {double size = 13, Color? color, int lines = 1, bool bold = false}) => ElView(
  style: ElStyle(
    fontSize: size,
    color: color,
    fontWeight: bold ? .w600 : .w400,
    lineHeight: 1.3,
    maxLines: lines,
    textOverflow: .ellipsis,
  ),
  child: value,
);

Widget _entryCaption(
  ValueListenable<_MediaEntry?> model,
  String Function(_MediaEntry) select, {
  double size = 13,
  Color? color,
  int lines = 1,
  bool bold = false,
}) {
  final style = ElStyle(
    fontSize: size,
    color: color,
    fontWeight: bold ? .w600 : .w400,
    lineHeight: 1.3,
    maxLines: lines,
    textOverflow: .ellipsis,
  );
  String? previous;
  Widget? view;
  return ValueListenableBuilder<_MediaEntry?>(
    valueListenable: model,
    builder: (_, entry, _) {
      final value = entry == null ? '' : select(entry);
      if (view == null || value != previous) {
        previous = value;
        view = ElView(style: style, child: value);
      }
      return view!;
    },
  );
}

class _MediaTile extends HookWidget {
  // ignore: prefer_const_constructors_in_immutables
  _MediaTile({
    required this.model,
    required this.kind,
    required this.featured,
    required this.tag,
    required this.onOpen,
    this.fixedCover = false,
  });
  final ValueNotifier<_MediaEntry?> model;
  final _MediaKind kind;
  final bool featured;
  final Object Function(_MediaEntry) tag;
  final ValueChanged<_MediaEntry> onOpen;
  final bool fixedCover;

  @override
  Widget build(BuildContext context) {
    useEffect(() => model.dispose, [model]);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final cover = _MediaCover(
      model: model,
      tag: tag,
      metadata: kind == .album,
      naturalHeight: kind == .waterfall,
      fixedRatio: fixedCover,
    );
    final Widget image;
    if (kind == .waterfall) {
      image = cover;
    } else {
      image = AspectRatio(
        aspectRatio: featured
            ? 16 / 9
            : kind == .album
            ? 1
            : 4 / 3,
        child: cover,
      );
    }
    final Widget contents;
    if (featured) {
      contents = Stack(
        children: [
          image,
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: .topCenter,
                  end: .bottomCenter,
                  colors: [Colors.transparent, Colors.black.withValues(alpha: .65)],
                ),
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: _entryCaption(model, (entry) => entry.title, size: 16, color: Colors.white, bold: true, lines: 2),
          ),
        ],
      );
    } else if (kind == .album) {
      contents = image;
    } else {
      final waterfallSlots = kind == .waterfall ? _waterfallCaptionSlots(context) : null;
      final title = _entryCaption(model, (entry) => entry.title, lines: 2, bold: true);
      final description = kind == .waterfall
          ? _entryCaption(model, (entry) => entry.description, size: 11, color: muted, lines: 3)
          : null;
      final source = Row(
        spacing: 4,
        children: [
          Icon(Icons.photo_camera_outlined, size: 12, color: muted),
          Expanded(child: _entryCaption(model, (entry) => entry.source, size: 10.5, color: muted)),
        ],
      );
      Widget buildFooter({bool reserveCaptionHeight = false}) {
        final slots = reserveCaptionHeight ? waterfallSlots : null;
        return Padding(
          padding: .all(8),
          child: Column(
            mainAxisSize: .min,
            crossAxisAlignment: .stretch,
            spacing: 5,
            children: [
              if (kind == .feed || slots != null)
                SizedBox(height: slots?.title ?? MediaQuery.textScalerOf(context).scale(13) * 1.3 * 2, child: title)
              else
                title,
              if (description != null)
                if (slots != null) SizedBox(height: slots.description, child: description) else description,
              if (slots != null) SizedBox(height: slots.source, child: source) else source,
            ],
          ),
        );
      }

      final naturalFooter = buildFooter();
      final fixedFooter = waterfallSlots == null ? null : buildFooter(reserveCaptionHeight: true);
      final footer = fixedFooter == null
          ? naturalFooter
          : ValueListenableBuilder<_MediaEntry?>(
              valueListenable: model,
              builder: (_, entry, _) => entry?.coverRatio == null ? naturalFooter : fixedFooter,
            );
      contents = Column(
        mainAxisSize: .min,
        crossAxisAlignment: .stretch,
        children: [
          image,
          if (kind == .feed) SizedBox(height: _footerExtent(context), child: footer) else footer,
        ],
      );
    }
    final body = LayoutBuilder(
      builder: (context, constraints) {
        final gap = kind == .album ? 1.5 : _waterfallGap;
        final card = Padding(
          padding: .only(right: gap, bottom: gap),
          child: ClipRRect(
            borderRadius: .circular(kind == .album ? 0 : 6),
            clipBehavior: .hardEdge,
            child: ElCard(
              key: ValueKey(featured ? 'media-featured' : 'media-card'),
              style: ElStyle(padding: EdgeInsets.zero, borderRadius: .circular(kind == .album ? 0 : 6)),
              event: ElEvent(
                onTap: (_) {
                  final entry = model.value;
                  if (entry != null) onOpen(entry);
                },
              ),
              child: contents,
            ),
          ),
        );
        if (kind == .waterfall) return card;
        final height = featured
            ? (constraints.maxWidth - gap) * 9 / 16 + gap
            : kind == .album
            ? constraints.maxWidth
            : _feedExtent(context, constraints.maxWidth);
        return SizedBox(height: height, child: card);
      },
    );
    // 原卡片和布局保持原实例，换绑只更新可访问名称、封面与文字叶子。
    return ValueListenableBuilder<_MediaEntry?>(
      valueListenable: model,
      child: body,
      builder: (_, entry, child) => Semantics(
        label: entry == null ? '' : '${entry.isVideo ? '视频' : '照片'}：${entry.title}',
        button: true,
        excludeSemantics: true,
        onTap: entry == null ? null : () => onOpen(entry),
        child: child,
      ),
    );
  }
}

class _MediaCover extends StatelessWidget {
  // ignore: prefer_const_constructors_in_immutables
  _MediaCover({
    required this.model,
    required this.tag,
    required this.metadata,
    required this.naturalHeight,
    this.fixedRatio = false,
  });
  final ValueListenable<_MediaEntry?> model;
  final Object Function(_MediaEntry) tag;
  final bool metadata;
  final bool naturalHeight;
  final bool fixedRatio;

  @override
  Widget build(BuildContext context) {
    if (naturalHeight) {
      return LayoutBuilder(
        builder: (_, constraints) => ValueListenableBuilder<_MediaEntry?>(
          valueListenable: model,
          builder: (_, entry, _) {
            final emptyArea = AspectRatio(aspectRatio: entry?.aspectRatio ?? 1);
            if (entry == null) return emptyArea;
            final image = Hero(
              tag: tag(entry),
              child: Image(
                image: entry.thumbnail,
                width: constraints.maxWidth,
                fit: .cover,
                excludeFromSemantics: true,
                frameBuilder: (context, child, frame, synchronous) =>
                    exampleImageFrame(context, frame == null ? emptyArea : child, frame, synchronous),
                errorBuilder: (_, _, _) => emptyArea,
              ),
            );
            // 有数据库尺寸时预先定高，本地文件直接沿用缩略图自身的布局比例，省掉另一轮尺寸读取。
            if (fixedRatio || entry.coverRatio != null || entry.width > 0 && entry.height > 0) {
              return AspectRatio(aspectRatio: entry.aspectRatio, child: image);
            }
            return ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxWidth / 1.8, maxHeight: constraints.maxWidth / .6),
              child: image,
            );
          },
        ),
      );
    }
    return ValueListenableBuilder<_MediaEntry?>(
      valueListenable: model,
      builder: (_, entry, _) {
        if (entry == null) return SizedBox.shrink();
        return Stack(
          fit: .expand,
          children: [
            Hero(
              tag: tag(entry),
              child: metadata
                  ? _AlbumCover(entry.albumThumbnail)
                  : Image(
                      image: entry.thumbnail,
                      fit: .cover,
                      excludeFromSemantics: true,
                      frameBuilder: exampleImageFrame,
                      errorBuilder: exampleImageError,
                    ),
            ),
            if (metadata && entry.isVideo)
              Positioned(
                right: 4,
                bottom: 4,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: .65), borderRadius: .circular(4)),
                  child: Padding(
                    padding: .symmetric(horizontal: 4, vertical: 2),
                    child: Row(
                      mainAxisSize: .min,
                      spacing: 3,
                      children: [
                        Icon(Icons.videocam_rounded, size: 11, color: Colors.white),
                        Text(
                          entry.duration > 0 ? _duration(entry.duration) : '视频',
                          style: TextStyle(fontSize: 10, height: 1.1, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _AlbumCover extends HookWidget {
  // ignore: prefer_const_constructors_in_immutables
  _AlbumCover(this.thumbnail);

  final AlbumThumbnail thumbnail;

  @override
  Widget build(BuildContext context) {
    final info = useValueListenable(thumbnail);
    final fade = useAnimationController(duration: exampleImageFadeDuration, initialValue: 1);
    final opacity = useCurvedAnimation(parent: fade, curve: Curves.easeOut);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    useEffect(() {
      fade.value = 1;
      if (reduceMotion) return null;
      // 复用格子时只播放当前缩略图的首帧，不让上一张的透明度影响新图。
      void reveal() {
        if (thumbnail.value == null) {
          fade.value = 1;
        } else {
          fade.forward(from: 0);
        }
      }

      thumbnail.addListener(reveal);
      return () => thumbnail.removeListener(reveal);
    }, [thumbnail, reduceMotion]);
    return RawImage(
      image: info?.image,
      scale: info?.scale ?? 1,
      opacity: opacity,
      fit: .cover,
      invertColors: MediaQuery.invertColorsOf(context),
    );
  }
}
