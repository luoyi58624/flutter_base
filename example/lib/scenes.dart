part of 'animations_page.dart';

class _DemoScene extends StatelessWidget {
  const _DemoScene({
    required this.demo,
    required this.value,
    required this.animate,
  });

  final _Demo demo;
  final bool value;
  final Widget Function(Widget) animate;

  @override
  Widget build(BuildContext context) => switch (demo) {
    _Demo.fade => _hint(),
    _Demo.slide => _drawer(),
    _Demo.scale => _status(),
    _Demo.fadeSlide => _notification(),
    _Demo.fadeScale => _dialog(),
    _Demo.reveal => _landscape(),
    _Demo.flip => _memberCard(),
    _Demo.collapseVertical => _accordion(),
    _Demo.collapseHorizontal => _searchBar(),
  };

  Widget _hint() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        animate(
          Container(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: Color(0xff202638),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Color(0x18202638),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_rounded, size: 16, color: Color(0xffa6e1bd)),
                SizedBox(width: 6),
                Text(
                  '链接已复制',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 14),
        _surface(
          width: 212,
          child: Row(
            children: [
              Icon(Icons.link_rounded, color: Color(0xff747a8c), size: 18),
              SizedBox(width: 10),
              Expanded(child: Text('项目分享链接', style: TextStyle(fontSize: 12))),
              Icon(Icons.copy_outlined, color: Color(0xff6658df), size: 16),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _drawer() => Stack(
    children: [
      Positioned(
        left: 18,
        top: 24,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '工作空间',
              style: TextStyle(fontSize: 12, color: Color(0xff8e95a6)),
            ),
            SizedBox(height: 18),
            for (final width in [84.0, 58.0, 74.0]) ...[
              Container(
                width: width,
                height: 7,
                decoration: BoxDecoration(
                  color: Color(0xffdce1e9),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              SizedBox(height: 14),
            ],
          ],
        ),
      ),
      Align(
        alignment: Alignment.centerRight,
        child: animate(
          Padding(
            padding: EdgeInsets.all(10),
            child: _surface(
              width: 166,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '快捷设置',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.close_rounded,
                        size: 14,
                        color: Color(0xff959bab),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  _item(Icons.palette_outlined, '外观设置'),
                  SizedBox(height: 14),
                  _item(Icons.notifications_none_rounded, '消息通知'),
                  SizedBox(height: 14),
                  _item(Icons.lock_outline_rounded, '隐私与安全'),
                ],
              ),
            ),
          ),
        ),
      ),
    ],
  );

  Widget _status() => Center(
    child: _surface(
      width: 222,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '部署完成',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 8),
                Text(
                  'v2.4 已上线',
                  style: TextStyle(fontSize: 11, color: Color(0xff8c93a4)),
                ),
              ],
            ),
          ),
          SizedBox(width: 12),
          animate(
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Color(0xffe1f4ea),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_rounded,
                color: Color(0xff238761),
                size: 24,
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _notification() => Center(
    child: animate(
      _surface(
        width: 222,
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Color(0xffe1f4ea),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(
                Icons.done_rounded,
                size: 20,
                color: Color(0xff238761),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '更改已保存',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 5),
                  Text(
                    '所有内容已同步',
                    style: TextStyle(fontSize: 11, color: Color(0xff8c93a4)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _dialog() => Stack(
    fit: StackFit.expand,
    children: [
      AnimatedOpacity(
        opacity: value ? 0.08 : 0,
        duration: Duration(milliseconds: value ? 90 : 70),
        curve: Curves.easeOut,
        child: ColoredBox(color: Color(0xff111b32)),
      ),
      Center(
        child: animate(
          _surface(
            width: 216,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '创建新项目',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 10),
                Text(
                  '为新想法留一个位置。',
                  style: TextStyle(fontSize: 11, color: Color(0xff8c93a4)),
                ),
                SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _pill('取消', Color(0xffeff1f6), Color(0xff626b7e)),
                    SizedBox(width: 8),
                    _pill('创建', Color(0xff6658df), Colors.white),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );

  Widget _landscape() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        animate(
          Container(
            width: 216,
            height: 140,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CustomPaint(painter: _LandscapePainter()),
            ),
          ),
        ),
        SizedBox(height: 10),
        Text(
          'A QUIET AFTERNOON',
          style: TextStyle(
            color: Color(0xff8c93a4),
            fontSize: 9,
            letterSpacing: 1.2,
          ),
        ),
      ],
    ),
  );

  Widget _memberCard() => Center(
    child: animate(
      Container(
        width: 216,
        height: 132,
        padding: EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xff283951), Color(0xff142237)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Color(0x24243350),
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'STUDIO',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xffd6c3a0),
                      letterSpacing: 2,
                    ),
                  ),
                ),
                Icon(
                  Icons.auto_awesome_rounded,
                  size: 20,
                  color: Color(0xffd6c3a0),
                ),
              ],
            ),
            Spacer(),
            Text(
              'CREATIVE MEMBER',
              style: TextStyle(
                fontSize: 11,
                color: Colors.white,
                letterSpacing: 1,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '2026  /  0186',
              style: TextStyle(
                fontSize: 10,
                color: Color(0xff8f9db1),
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _accordion() => Align(
    alignment: Alignment.topCenter,
    child: Padding(
      padding: EdgeInsets.only(top: 22),
      child: _surface(
        width: 222,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '工作区设置',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
                _AccordionArrow(
                  value,
                  key: ValueKey('collapse-arrow'),
                  child: Icon(
                    Icons.expand_more_rounded,
                    size: 18,
                    color: Color(0xff8c93a4),
                  ),
                ),
              ],
            ),
            animate(
              SizedBox(
                width: 194,
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Column(
                    children: [
                      _item(Icons.language_rounded, '语言与地区'),
                      SizedBox(height: 12),
                      _item(Icons.palette_outlined, '外观与主题'),
                    ],
                  ),
                ),
              ),
            ),
            Divider(height: 14, color: Color(0xffeceef4)),
            Text(
              '自动同步到所有设备',
              style: TextStyle(fontSize: 10, color: Color(0xff8c93a4)),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _searchBar() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('文档与项目', style: TextStyle(fontSize: 11, color: Color(0xff8c93a4))),
        SizedBox(height: 12),
        _surface(
          width: 222,
          padding: 10,
          child: Row(
            children: [
              Icon(Icons.grid_view_rounded, size: 19, color: Color(0xff747a8c)),
              SizedBox(width: 10),
              animate(
                Container(
                  width: 136,
                  height: 34,
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Color(0xfff1f2f7),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search_rounded,
                        size: 16,
                        color: Color(0xff8c93a4),
                      ),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '搜索项目',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xff8c93a4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 10),
              Icon(
                Icons.more_horiz_rounded,
                size: 19,
                color: Color(0xff747a8c),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// 箭头复用面板的时序和反转机制，避免独立曲线造成错拍。
class _AccordionArrow extends ElSwitcherAnimation {
  const _AccordionArrow(super.value, {super.key, required super.child});

  @override
  Duration get $reverseDuration => const Duration(milliseconds: 160);

  @override
  Widget builder(BuildContext context, Animation<double> animation) =>
      RotationTransition(
        turns: animation.drive(Tween<double>(begin: 0, end: 0.5)),
        child: child,
      );
}

Widget _surface({
  required double width,
  required Widget child,
  double padding = 14,
}) => Container(
  width: width,
  padding: EdgeInsets.all(padding),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(10),
    border: Border.all(color: Color(0xffe6e9f0)),
    boxShadow: [
      BoxShadow(color: Color(0x0d1b2540), blurRadius: 16, offset: Offset(0, 5)),
    ],
  ),
  child: child,
);

Widget _item(IconData icon, String label) => Row(
  children: [
    Icon(icon, size: 16, color: Color(0xff8c93a4)),
    SizedBox(width: 8),
    Expanded(
      child: Text(
        label,
        style: TextStyle(fontSize: 11, color: Color(0xff525e74)),
      ),
    ),
  ],
);

Widget _pill(String label, Color background, Color foreground) => Container(
  padding: EdgeInsets.symmetric(horizontal: 15, vertical: 7),
  decoration: BoxDecoration(
    color: background,
    borderRadius: BorderRadius.circular(6),
  ),
  child: Text(label, style: TextStyle(color: foreground, fontSize: 11)),
);

class _StagePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Color(0xfff5f6fa));
    final paint = Paint()..color = Color(0xffdde2ec);
    for (double y = 12; y < size.height; y += 16) {
      for (double x = 12; x < size.width; x += 16) {
        canvas.drawCircle(Offset(x, y), 0.7, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_StagePainter oldDelegate) => false;
}

class _LandscapePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Color(0xffeeded0));
    canvas.drawCircle(
      Offset(size.width * 0.73, size.height * 0.27),
      18,
      Paint()..color = Color(0xffd99969),
    );
    final far = Path()
      ..moveTo(0, size.height * 0.63)
      ..cubicTo(
        size.width * 0.22,
        size.height * 0.29,
        size.width * 0.45,
        size.height * 0.95,
        size.width,
        size.height * 0.4,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(far, Paint()..color = Color(0xffb7b2a4));
    final near = Path()
      ..moveTo(0, size.height * 0.82)
      ..cubicTo(
        size.width * 0.38,
        size.height * 0.44,
        size.width * 0.75,
        size.height * 0.66,
        size.width,
        size.height * 0.94,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(near, Paint()..color = Color(0xff718b88));
  }

  @override
  bool shouldRepaint(_LandscapePainter oldDelegate) => false;
}
