import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

import '../../../widgets/example_image.dart';
import '../../../layout/example_page.dart';
import 'comparison_list.dart';
import 'scroll_mode.dart';
import '../../../widgets/panel.dart';

/// 混排长文、照片、转发和投票，比较各容器的异构条目滚动。
class RecyclerSocialFeedPage extends StatefulWidget {
  /// 创建社交动态流对照页。
  // ignore: prefer_const_constructors_in_immutables
  RecyclerSocialFeedPage({super.key});

  @override
  State<RecyclerSocialFeedPage> createState() => _RecyclerSocialFeedPageState();
}

class _RecyclerSocialFeedPageState extends State<RecyclerSocialFeedPage> {
  final _controller = ScrollController(keepScrollOffset: false);

  final _adapter = _SocialRecords();
  SliverExampleMode _mode = .recycler;

  void _changeMode(SliverExampleMode mode) {
    if (_mode == mode) return;
    setState(() => _mode = mode);
    if (_controller.hasClients) _controller.jumpTo(0);
  }

  @override
  void dispose() {
    _controller.dispose();

    _adapter.disposePosts();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExamplePage(
    title: '社交动态流',
    actions: [SliverComparisonModeMenu(mode: _mode, onChanged: _changeMode)],
    child: SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: .stretch,
            children: [
              Padding(
                padding: .fromLTRB(16, 8, 16, 10),
                child: Text('城市观察 · 千条动态\n长文、九宫格、转发和投票交替出现', style: Theme.of(context).textTheme.bodySmall),
              ),
              Expanded(
                child: SliverComparisonList(
                  mode: _mode,
                  controller: _controller,

                  itemCount: _adapter.getItemCount(),
                  itemType: (index) => index % _PostKind.values.length,
                  itemBuilder: (context, index) => _SocialCard(record: AlwaysStoppedAnimation(_adapter.postAt(index))),
                  recycledItemBuilder: (context, index) => HookBuilder(
                    builder: (context) {
                      final record = useMemoized(() => ValueNotifier(_adapter.postAt(index.value)), [index]);
                      useEffect(() {
                        void bind() => record.value = _adapter.postAt(index.value);
                        index.addListener(bind);
                        return () {
                          index.removeListener(bind);
                          record.dispose();
                        };
                      }, [index]);
                      return useMemoized(() => _SocialCard(record: record), [record]);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

enum _PostKind {
  article('长文', Icons.article_outlined),
  gallery('九宫格', Icons.photo_library_outlined),
  repost('转发', Icons.repeat_rounded),
  poll('投票', Icons.poll_outlined);

  const _PostKind(this.label, this.icon);
  final String label;
  final IconData icon;
}

final _authors = ['林间拾记', '山谷信箱', '街角周刊', '周末观鸟社', '南岸步道', '小岛电台'];

class _SocialPost {
  _SocialPost(this.id);

  final int id;
  _PostKind get kind => _PostKind.values[id % _PostKind.values.length];
  String get author => _authors[id % _authors.length];
  int get likes => 18 + id % 131;
  final expanded = ValueNotifier(false);
  final liked = ValueNotifier(false);
  final vote = ValueNotifier<int?>(null);

  void dispose() {
    expanded.dispose();
    liked.dispose();
    vote.dispose();
  }
}

class _SocialRecords {
  final _posts = <int, _SocialPost>{};

  _SocialPost postAt(int index) => _posts.putIfAbsent(index, () => _SocialPost(index));

  void disposePosts() {
    for (final post in _posts.values) {
      post.dispose();
    }
  }

  int getItemCount() => 1000;
}

Widget _postField<T>(
  BuildContext context,
  ValueListenable<_SocialPost> post, {
  required T Function(ValueListenable<_SocialPost>) select,
  required TransitionBuilder builder,
}) {
  // 官方行的记录不会换绑，直接构建叶子，不增加无效监听节点。
  if (post is AlwaysStoppedAnimation<_SocialPost>) return builder(context, null);
  return ElListenableBuilder(listenable: post, select: select, builder: builder);
}

class _SocialCard extends StatelessWidget {
  // ignore: prefer_const_constructors_in_immutables
  _SocialCard({required this.record});

  final ValueListenable<_SocialPost> record;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final kind = record.value.kind;
    return Padding(
      padding: .fromLTRB(12, 4, 12, 8),
      child: ExamplePanel(
        key: ValueKey('social-post-card'),
        style: ElStyle(padding: .all(14), backgroundColor: colors.surfaceContainerLow, borderRadius: .circular(16)),
        child: Column(
          crossAxisAlignment: .stretch,
          spacing: 10,
          children: [
            Row(
              spacing: 10,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: colors.primaryContainer,
                  foregroundColor: colors.onPrimaryContainer,
                  child: Icon(kind.icon, size: 18),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: .start,
                    children: [
                      _postField(
                        context,
                        record,
                        select: (source) => source.value.author,
                        builder: (context, child) => Text(record.value.author, style: theme.textTheme.titleSmall),
                      ),
                      _postField(
                        context,
                        record,
                        select: (source) => source.value.id,
                        builder: (context, child) => Text(
                          '${2 + record.value.id % 49} 分钟前 · 动态 #${record.value.id + 1}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(kind.label, style: theme.textTheme.labelMedium?.copyWith(color: colors.primary)),
              ],
            ),
            switch (kind) {
              .article => _Article(post: record),
              .gallery => _Gallery(post: record),
              .repost => _Repost(post: record),
              .poll => _Poll(post: record),
            },
            Row(
              children: [
                _postField(
                  context,
                  record,
                  select: (source) => source.value,
                  builder: (context, child) => ValueListenableBuilder(
                    valueListenable: record.value.liked,
                    builder: (context, liked, child) => TextButton.icon(
                      key: ValueKey('social-like'),
                      onPressed: () => record.value.liked.value = !record.value.liked.value,
                      icon: Icon(liked ? Icons.favorite_rounded : Icons.favorite_border_rounded, size: 16),
                      label: Text('${record.value.likes + (liked ? 1 : 0)}'),
                    ),
                  ),
                ),
                Expanded(
                  child: _postField(
                    context,
                    record,
                    select: (source) => source.value.id % 13,
                    builder: (context, child) => Text(
                      '${record.value.id % 13 + 2} 条讨论 · #城市自然观察',
                      maxLines: 1,
                      overflow: .ellipsis,
                      textAlign: .end,
                      style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Article extends StatelessWidget {
  // ignore: prefer_const_constructors_in_immutables
  _Article({required this.post});
  final ValueListenable<_SocialPost> post;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: .start,
    spacing: 4,
    children: [
      Text('写在天亮之前', style: Theme.of(context).textTheme.titleMedium),
      _postField(
        context,
        post,
        select: (source) => source.value,
        builder: (context, child) => ValueListenableBuilder(
          valueListenable: post.value.expanded,
          builder: (context, expanded, child) => Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '第 ${post.value.id + 1} 次晨间记录。',
                  style: TextStyle(fontWeight: .w700),
                ),
                TextSpan(
                  text:
                      '清晨的沿江步道只有零星行人。雨停后，麻雀沿着屋檐排成一列，树林里的声响逐渐清晰。'
                      '\n\n我把这段路分成四个观察点，每站停留三分钟，记录鸟叫的方向和变化。'
                      '到第三站时，风从水面转向，原本安静的灌木丛突然有了动静。'
                      '\n\n下次想沿原路反向走一遍，看看声音与光线变化会不会让同一个地方显得完全不同。',
                ),
              ],
            ),
            maxLines: expanded ? null : 2,
            overflow: expanded ? .clip : .ellipsis,
          ),
        ),
      ),
      _postField(
        context,
        post,
        select: (source) => source.value.expanded,
        builder: (context, child) => ValueListenableBuilder(
          valueListenable: post.value.expanded,
          builder: (context, expanded, child) => TextButton(
            key: ValueKey('social-expand'),
            onPressed: () => post.value.expanded.value = !post.value.expanded.value,
            child: Text(expanded ? '收起长文' : '展开长文'),
          ),
        ),
      ),
    ],
  );
}

class _Gallery extends StatelessWidget {
  // ignore: prefer_const_constructors_in_immutables
  _Gallery({required this.post});
  final ValueListenable<_SocialPost> post;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: .stretch,
    spacing: 5,
    children: [
      _postField(
        context,
        post,
        select: (source) => source.value.id % 9,
        builder: (context, child) => Text('保护区的九个镜头 · 路线 ${post.value.id % 9 + 1}'),
      ),
      for (var row = 0; row < 3; row++)
        Row(
          spacing: 5,
          children: [
            for (var col = 0; col < 3; col++)
              Expanded(
                child: AspectRatio(
                  aspectRatio: 1.6,
                  child: ClipRRect(
                    borderRadius: .circular(7),
                    // 同 kind 的记录 id 相差 4，图片奇偶排列不变，可以保留整组图片。
                    child: Image.asset(
                      (post.value.id + row + col).isEven
                          ? 'assets/recycler_cards/owl.jpg'
                          : 'assets/recycler_cards/owl-2.jpg',
                      cacheWidth: 360,
                      fit: .cover,
                      frameBuilder: exampleImageFrame,
                      errorBuilder: exampleImageError,
                      semanticLabel: '猫头鹰观察照片 ${row * 3 + col + 1}',
                    ),
                  ),
                ),
              ),
          ],
        ),
    ],
  );
}

class _Repost extends StatelessWidget {
  // ignore: prefer_const_constructors_in_immutables
  _Repost({required this.post});
  final ValueListenable<_SocialPost> post;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: .stretch,
    spacing: 7,
    children: [
      Text('这条关于夜间观察的提醒值得收藏。'),
      ExamplePanel(
        style: ElStyle(
          padding: .all(10),
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: .circular(10),
        ),
        child: Row(
          spacing: 10,
          children: [
            Icon(Icons.format_quote_rounded),
            Expanded(
              child: _postField(
                context,
                post,
                select: (source) => source.value.id,
                builder: (context, child) => Text('自然笔记 #${post.value.id + 101}\n给动物留下距离，观察结束后把器材和垃圾一起带走。'),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _Poll extends StatelessWidget {
  // ignore: prefer_const_constructors_in_immutables
  _Poll({required this.post});
  final ValueListenable<_SocialPost> post;
  static final _options = ['河边慢走', '清晨观鸟', '绘制街区地图'];

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: .stretch,
    children: [
      Text('本周末想参加哪场活动？', style: Theme.of(context).textTheme.titleMedium),
      for (final (index, option) in _options.indexed)
        _postField(
          context,
          post,
          select: (source) => source.value.vote,
          builder: (context, child) => ValueListenableBuilder(
            valueListenable: post.value.vote,
            builder: (context, selected, child) => OutlinedButton.icon(
              key: ValueKey('social-vote-$index'),
              onPressed: () => post.value.vote.value = index,
              icon: Icon(selected == index ? Icons.check_circle_outline : Icons.radio_button_unchecked, size: 17),
              label: Text(selected == null ? option : '$option · ${38 - index * 8 + (selected == index ? 1 : 0)} 票'),
            ),
          ),
        ),
    ],
  );
}
