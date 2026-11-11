part of 'app.dart';

class _Home extends HookWidget {
  const _Home(this.typography, this.delay, {this.desktop = false});
  final _Typography typography;
  final Duration delay;
  final bool desktop;
  @override
  Widget build(BuildContext context) {
    final scroll = useScrollController();
    final count = useState(0);
    final busy = useState(false);
    final ended = useState(false);
    final alive = useRef(true);
    Future<void> load({bool refresh = false}) async {
      if (busy.value || (!refresh && ended.value)) return;
      busy.value = true;
      await Future<void>.delayed(delay);
      if (!alive.value) return;
      if (refresh) {
        count.value = 8;
        ended.value = false;
      } else if (count.value == _articles.length) {
        ended.value = true;
      } else {
        count.value = math.min(count.value + 8, _articles.length);
      }
      busy.value = false;
    }

    useEffect(() {
      alive.value = true;
      // 首屏和追加均沿用原生的 800ms 模拟请求，不在卸载后更新状态。
      scheduleMicrotask(() => load());
      void onScroll() {
        if (scroll.position.userScrollDirection == ScrollDirection.reverse && scroll.position.extentAfter < 330) {
          unawaited(load());
        }
      }

      scroll.addListener(onScroll);
      return () {
        alive.value = false;
        scroll.removeListener(onScroll);
      };
    }, [scroll]);
    return ExamplePanel(
      key: ValueKey('page-推荐'),
      style: ElStyle(backgroundColor: _background),
      child: ElScroll.sliver(
        key: PageStorageKey('home-list'),
        controller: scroll,
        physics: AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
        slivers: [
          ElSliverRefresh(
            onRefresh: () => load(refresh: true),
            refresher: ElAndroidRefresher(color: _primary),
          ),
          if (desktop) ...[
            SliverLayoutBuilder(
              key: ValueKey('home-grid'),
              builder: (context, constraints) => SliverGrid.builder(
                itemCount: count.value,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  // 每列至少 360 宽，列数随视口宽度增加。
                  crossAxisCount: math.max(1, (constraints.crossAxisExtent + 16) ~/ (360 + 16)),
                  mainAxisExtent: 216 * MediaQuery.textScalerOf(context).scale(14) / 14,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                ),
                itemBuilder: (context, index) =>
                    _ArticleCard(_articles[index], typography, index: index, desktop: true),
              ),
            ),
            if (ended.value || busy.value)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: _Label(ended.value ? '没有更多了' : '加载中…', typography, size: 12, color: _tertiary, align: .center),
                ),
              ),
          ] else
            SliverPadding(
              padding: EdgeInsets.all(12),
              sliver: SliverList.builder(
                itemCount: count.value + 1,
                itemBuilder: (context, index) => index < count.value
                    ? Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: _ArticleCard(_articles[index], typography, index: index),
                      )
                    : (!ended.value && !(busy.value && count.value > 0))
                    ? SizedBox.shrink()
                    : Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: _Label(
                          ended.value ? '没有更多了' : '加载中…',
                          typography,
                          size: 12,
                          color: _tertiary,
                          align: .center,
                        ),
                      ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ArticleCard extends StatelessWidget {
  const _ArticleCard(this.article, this.typography, {required this.index, this.desktop = false});
  final _Article article;
  final _Typography typography;
  final int index;
  final bool desktop;
  @override
  Widget build(BuildContext context) => ExamplePanel(
    key: ValueKey('article-$index'),
    event: ElEvent(onTap: (_) => _push(context, _DetailPage(article, typography))),
    style: ElStyle(backgroundColor: _surface, borderRadius: .circular(8), padding: .all(desktop ? 16 : 12)),
    child: Row(
      crossAxisAlignment: .start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: .start,
            children: [
              _Tag(article.tag, typography),
              SizedBox(height: 6),
              _Label(
                article.title,
                typography,
                key: ValueKey('home-title-$index'),
                size: desktop ? 18 : 16,
                weight: .w700,
                color: _text,
                maxLines: 2,
              ),
              SizedBox(height: 4),
              _Label(
                article.summary,
                typography,
                key: ValueKey('home-summary-$index'),
                size: desktop ? 14 : 13,
                extraLeading: 3,
                maxLines: 2,
              ),
              SizedBox(height: 8),
              _Label(article.meta, typography, size: 12, color: _tertiary),
            ],
          ),
        ),
        SizedBox(width: 12),
        ElView(
          style: ElStyle(
            width: desktop ? 112 : 96,
            height: desktop ? 84 : 72,
            backgroundColor: article.cover,
            borderRadius: .circular(8),
          ),
        ),
      ],
    ),
  );
}

class _Tag extends StatelessWidget {
  const _Tag(this.text, this.typography);
  final String text;
  final _Typography typography;
  @override
  Widget build(BuildContext context) => ElTag(child: text, round: true);
}
