part of 'app.dart';

class _DetailPage extends StatelessWidget {
  const _DetailPage(this.article, this.typography);
  final _Article article;
  final _Typography typography;
  @override
  Widget build(BuildContext context) => _Page(
    '详情',
    typography,
    ElScrollView(
      padding: EdgeInsets.all(16),
      children: [
        Column(
          crossAxisAlignment: .start,
          children: [
            _Tag(article.tag, typography),
            SizedBox(height: 10),
            _Label(
              article.title,
              typography,
              key: ValueKey('detail-title'),
              size: 20,
              weight: .w700,
              color: _text,
              extraLeading: 4,
            ),
            SizedBox(height: 10),
            _Label(article.meta, typography, size: 12, color: _tertiary),
            SizedBox(height: 14),
            _line(),
            SizedBox(height: 16),
            _Label(
              '${article.summary}\n\n先说结论：这类改动最怕的不是做不出来，而是做出来之后没人用。所以动手之前先问清楚三个问题——用户是谁、在什么场景下用、现在是怎么凑合解决的。\n\n落地的时候建议拆成两步走：第一步只做最小可用的链路，把数据从入口一路打通到展示，先确认结构没问题；第二步再补交互细节和边界情况，比如空态、加载失败、重复点击。\n\n最后提醒一句，别在没数据的时候做优化。先把指标埋好，上线一周看真实行为，再决定往哪个方向使劲——很多看起来明显的性能问题，实际用户根本感知不到。',
              typography,
              size: 15,
              extraLeading: 8,
            ),
          ],
        ),
      ],
    ),
    color: _surface,
  );
}

class _FavoritePage extends StatelessWidget {
  const _FavoritePage(this.typography);
  final _Typography typography;
  @override
  Widget build(BuildContext context) => _Page(
    '我的收藏',
    typography,
    ElScrollView(
      padding: EdgeInsets.all(12),
      gap: 8,
      children: [for (var index = 0; index < 5; index++) _ArticleCard(_articles[index], typography, index: index)],
    ),
  );
}

class _ChatPage extends HookWidget {
  const _ChatPage(this.title, this.typography, this.replyDelay);
  final String title;
  final _Typography typography;
  final Duration replyDelay;
  @override
  Widget build(BuildContext context) {
    final messages = useState([..._initialChat]);
    final input = useMemoized(() => ElEditableController());
    final focus = useFocusNode();
    // 原生发送 TextView 不抢焦点，发送后保留输入焦点和键盘。
    final sendFocus = useFocusNode(canRequestFocus: false, skipTraversal: true);
    final scroll = useScrollController();
    final timers = useRef(<Timer>[]);
    useListenable(input.textChanges);
    useEffect(
      () => () {
        for (final timer in timers.value) {
          timer.cancel();
        }
        input.dispose();
      },
      [input],
    );
    void bottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scroll.hasClients) scroll.jumpTo(0);
    });
    useEffect(() {
      bottom();
      return null;
    }, [messages.value, MediaQuery.viewInsetsOf(context).bottom]);
    void send() {
      final text = input.text.trim();
      if (text.isEmpty) return;
      input.text = '';
      messages.value = [...messages.value, (text: text, mine: true)];
      timers.value.add(
        Timer(replyDelay, () => messages.value = [...messages.value, (text: '收到，我这边稍后同步一下进度。', mine: false)]),
      );
    }

    return _Page(
      title,
      typography,
      Column(
        children: [
          Expanded(
            child: ElScrollView.sliver(
              key: ValueKey('chat-list'),
              controller: scroll,
              reverse: true,
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  sliver: SliverList.builder(
                    itemCount: messages.value.length,
                    itemBuilder: (context, index) {
                      final message = messages.value[messages.value.length - 1 - index];
                      return Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: Align(
                          alignment: message.mine ? Alignment.centerRight : Alignment.centerLeft,
                          child: ExamplePanel(
                            style: ElStyle(
                              maxWidth: 270,
                              padding: .symmetric(horizontal: 12, vertical: 9),
                              backgroundColor: message.mine ? _primary : Color(0xfff7f8fa),
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(message.mine ? 12 : 4),
                                topRight: Radius.circular(message.mine ? 4 : 12),
                                bottomLeft: Radius.circular(12),
                                bottomRight: Radius.circular(12),
                              ),
                            ),
                            child: _Label(
                              message.text,
                              typography,
                              size: 14,
                              color: message.mine ? _surface : _text,
                              extraLeading: 3,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          _line(),
          ExamplePanel(
            style: ElStyle(backgroundColor: _surface, padding: .all(8)),
            child: Row(
              crossAxisAlignment: .end,
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final style = typography.style(14, color: _text);
                      final painter = TextPainter(
                        text: TextSpan(
                          text: input.text.isEmpty ? ' ' : input.text,
                          style: TextStyle(
                            fontSize: 14,
                            height: style.lineHeight,
                            fontVariations: style.fontVariationSettings,
                          ),
                        ),
                        textDirection: .ltr,
                        textScaler: MediaQuery.textScalerOf(context),
                      )..layout(maxWidth: math.max(1, constraints.maxWidth - 24));
                      final height = math.max(
                        40.0,
                        math.min(4, painter.computeLineMetrics().length) *
                                MediaQuery.textScalerOf(context).scale(14) *
                                style.lineHeight! +
                            18,
                      );
                      painter.dispose();
                      return ElView(
                        style: ElStyle(
                          height: height,
                          backgroundColor: Color(0xfff2f3f5),
                          borderRadius: .circular(14),
                          padding: .symmetric(horizontal: 12, vertical: 9),
                        ),
                        child: Stack(
                          children: [
                            if (input.text.isEmpty)
                              IgnorePointer(child: _Label('说点什么…', typography, size: 14, color: _tertiary)),
                            ElEditableView(
                              key: ValueKey('chat-input'),
                              controller: input,
                              focusNode: focus,
                              style: ElEditableStyle(
                                view: style.copyWith(width: '100%', height: '100%'),
                                caretColor: _primary,
                                scrollbars: false,
                                inputConfiguration: TextInputConfiguration(
                                  inputType: TextInputType.multiline,
                                  inputAction: TextInputAction.newline,
                                ),
                                semanticLabel: '说点什么…',
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(width: 8),
                ElButtonView(
                  key: ValueKey('send-message'),
                  focusNode: sendFocus,
                  semanticLabel: '发送',
                  onPressed: send,
                  style: ElStyle(
                    height: 40,
                    padding: .symmetric(horizontal: 18),
                    alignment: .center,
                    backgroundColor: _primary,
                    borderRadius: .circular(6),
                  ),
                  child: _Label('发送', typography, size: 14, color: _surface),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WebPage extends StatelessWidget {
  const _WebPage(this.title, this.asset, this.typography, this.builder);
  final String title, asset;
  final _Typography typography;
  final Widget Function(String url)? builder;
  @override
  Widget build(BuildContext context) => _Page(
    title,
    typography,
    builder?.call(asset) ??
        ElScrollView(
          padding: EdgeInsets.all(16),
          children: [
            ElCard(
              child: Text(
                asset == 'about.html'
                    ? 'Flutter Base 移动端示例\n使用移动端主题、统一组件与 ElScrollView 构建。'
                    : '在推荐页浏览内容，在分类页选择条目，在消息页体验聊天。组件示例入口位于“我的”页面。',
              ),
            ),
          ],
        ),
  );
}
