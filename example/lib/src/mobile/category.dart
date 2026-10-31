part of 'app.dart';

class _CategoryPage extends HookWidget {
  const _CategoryPage(this.typography, {this.desktop = false});
  final _Typography typography;
  final bool desktop;
  @override
  Widget build(BuildContext context) {
    final columns = desktop ? 3 : 2;
    final selected = useState(0);
    final right = useScrollController();
    final left = useScrollController();
    final viewport = useMemoized(GlobalKey.new);
    final keys = useMemoized(
      () => List.generate(_categories.length, (_) => GlobalKey()),
    );
    final locked = useRef(false);
    useEffect(() {
      void sync() {
        if (locked.value) return;
        final box = viewport.currentContext?.findRenderObject() as RenderBox?;
        if (box == null) return;
        final top = box.localToGlobal(Offset.zero).dy;
        var index = 0;
        for (var i = 0; i < keys.length; i++) {
          final render =
              keys[i].currentContext?.findRenderObject() as RenderBox?;
          if (render != null &&
              render.localToGlobal(Offset.zero).dy <= top + 1) {
            index = i;
          }
        }
        if (selected.value == index) return;
        selected.value = index;
        if (left.hasClients) {
          unawaited(
            left.animateTo(
              (index * 48.0).clamp(0, left.position.maxScrollExtent),
              duration: Duration(milliseconds: 200),
              curve: Curves.easeOut,
            ),
          );
        }
      }

      right.addListener(sync);
      return () => right.removeListener(sync);
    }, [right]);
    Future<void> select(int index) async {
      if (index == selected.value) return;
      selected.value = index;
      locked.value = true;
      final context = keys[index].currentContext;
      if (context != null) {
        final item = context.findRenderObject() as RenderBox?;
        final host = viewport.currentContext?.findRenderObject() as RenderBox?;
        if (item != null && host != null && right.hasClients) {
          await right.animateTo(
            (right.offset +
                    item.localToGlobal(Offset.zero).dy -
                    host.localToGlobal(Offset.zero).dy)
                .clamp(0, right.position.maxScrollExtent),
            duration: Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      }
      locked.value = false;
    }

    return ElCardView(
      key: ValueKey('page-分类'),
      style: ElStyle(bgColor: _background),
      child: Row(
        children: [
          ElCardView(
            style: ElStyle(
              width: desktop ? 144 : 92,
              bgColor: Color(0xfff7f8fa),
            ),
            child: ElScrollView(
              controller: left,
              children: [
                ElListView.builder(
                  itemCount: _categories.length,
                  itemBuilder: (context, i) => ElButtonView(
                    key: ValueKey('category-$i'),
                    semanticLabel: _categories[i].name,
                    selected: selected.value == i,
                    onPressed: () => unawaited(select(i)),
                    style: ElStyle(
                      height: 48,
                      bgColor: selected.value == i ? _surface : null,
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Center(
                          child: _Label(
                            _categories[i].name,
                            typography,
                            size: 13,
                            color: selected.value == i ? _primary : _secondary,
                            weight: selected.value == i ? .w700 : .w400,
                            maxLines: 1,
                          ),
                        ),
                        if (selected.value == i)
                          Align(
                            alignment: .centerLeft,
                            child: ElView(
                              style: ElStyle(
                                width: 3,
                                height: 18,
                                bgColor: _primary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: NotificationListener<ScrollStartNotification>(
              key: viewport,
              onNotification: (event) {
                if (event.dragDetails != null) locked.value = false;
                return false;
              },
              child: ElScrollView(
                key: ValueKey('category-list'),
                controller: right,
                padding: EdgeInsets.all(8),
                children: [
                  Column(
                    children: [
                      for (var i = 0; i < _categories.length; i++)
                        ElCardView(
                          key: keys[i],
                          child: Column(
                            children: [
                              ElView(
                                style: ElStyle(
                                  height: 40,
                                  width: '100%',
                                  padding: .symmetric(horizontal: 4),
                                  alignment: .centerLeft,
                                ),
                                child: _Label(
                                  _categories[i].name,
                                  typography,
                                  size: 14,
                                  weight: .w700,
                                  color: _text,
                                ),
                              ),
                              for (var row = 0; row < 6 ~/ columns; row++)
                                Row(
                                  children: [
                                    for (
                                      var column = 0;
                                      column < columns;
                                      column++
                                    )
                                      Expanded(
                                        child: Padding(
                                          padding: EdgeInsets.all(8),
                                          child: ElCardView(
                                            style: ElStyle(
                                              bgColor: _surface,
                                              borderRadius: .circular(8),
                                              padding: .all(10),
                                            ),
                                            child: Column(
                                              children: [
                                                ElView(
                                                  style: ElStyle(
                                                    width: 48,
                                                    height: 48,
                                                    borderRadius: .circular(10),
                                                    bgColor: _categories[i]
                                                        .items[row * columns +
                                                            column]
                                                        .color,
                                                  ),
                                                ),
                                                SizedBox(height: 6),
                                                _Label(
                                                  _categories[i]
                                                      .items[row * columns +
                                                          column]
                                                      .name,
                                                  typography,
                                                  size: 12,
                                                  color: _text,
                                                  maxLines: 1,
                                                  align: .center,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
