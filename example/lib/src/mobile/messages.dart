part of 'app.dart';

class _MessagesPage extends StatelessWidget {
  const _MessagesPage(this.typography, this.unread, this.onOpen);
  final _Typography typography;
  final Set<int> unread;
  final ValueChanged<int> onOpen;
  @override
  Widget build(BuildContext context) => ExamplePanel(
    key: ValueKey('page-消息'),
    style: ElStyle(backgroundColor: _surface),
    child: ElScroll(
      key: PageStorageKey('messages-list'),
      children: [
        for (var i = 0; i < _messages.length; i++) ...[
          if (i == 0 || _messages[i].group != _messages[i - 1].group)
            ElView(
              style: ElStyle(
                height: 36,
                backgroundColor: _background,
                padding: .symmetric(horizontal: 12),
                alignment: .centerLeft,
              ),
              child: _Label(_messages[i].group, typography, size: 12, color: _tertiary),
            ),
          ExamplePanel(
            key: ValueKey('message-$i'),
            event: ElEvent(onTap: (_) => onOpen(i)),
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: .start,
                    children: [
                      ElView(
                        style: ElStyle(
                          width: 40,
                          height: 40,
                          backgroundColor: _messages[i].color,
                          borderRadius: .circular(8),
                          alignment: .center,
                        ),
                        child: _Label(
                          _messages[i].title.substring(0, 1),
                          typography,
                          size: 15,
                          weight: .w700,
                          color: _surface,
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: .start,
                          children: [
                            Row(
                              crossAxisAlignment: .start,
                              children: [
                                Expanded(
                                  child: _Label(
                                    _messages[i].title,
                                    typography,
                                    size: 15,
                                    weight: .w700,
                                    color: _text,
                                    maxLines: 1,
                                  ),
                                ),
                                SizedBox(width: 8),
                                _Label(_messages[i].time, typography, size: 11, color: _tertiary),
                              ],
                            ),
                            SizedBox(height: 4),
                            _Label(_messages[i].content, typography, maxLines: 1),
                          ],
                        ),
                      ),
                      if (unread.contains(i))
                        Padding(
                          padding: EdgeInsets.only(left: 8, top: 16),
                          child: ElView(
                            key: ValueKey('unread-$i'),
                            style: ElStyle(
                              width: 8,
                              height: 8,
                              backgroundColor: Color(0xffff3b30),
                              borderRadius: .circular(4),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                _line(indent: 62),
              ],
            ),
          ),
        ],
      ],
    ),
  );
}
