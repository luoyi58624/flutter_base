import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class CustomPainterTestPage extends StatefulWidget {
  const CustomPainterTestPage({super.key});


  @override
  State<CustomPainterTestPage> createState() => _CustomPainterTestPageState();
}

class _CustomPainterTestPageState extends State<CustomPainterTestPage> {
  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('自定义绘制'),
      ),
      child: SafeArea(
        child: Center(
          child: CustomPaint(
            painter: RectPainter(),
            size: const Size(300, 100),
            // child: SizedBox(
            //   width: 300,
            //   height: 100,
            //   child: Text('xx你这可能你检查扩散层可接受的你擦科技大奶萨抽卡你打啥抽卡奶萨登记卡'),
            // ),
          ),
          // child: TrianglePainter(
          //   painter: RectPainter(),
          //   size: Size(300, 300),
          // ),
        ),
      ),
    );
  }
}

class RectPainter extends CustomPainter {
  double degToRad(num deg) => deg * (pi / 180.0);

  @override
  void paint(Canvas canvas, Size size) {
    var paint = Paint()..color = Colors.red;
    var path = Path();
    // double sw = size.width;
    // double sh = size.height;

    double radius = 70.0;
    double e = 0.28;
    double g = size.width * 0.5;
    double x1 = g - radius;
    double x2 = g + radius;

    path.lineTo(x1, 0);
    // path.cubicTo(x1, radius * 0.9, x1 + radius * 0.66, radius, x1 + radius, radius);
    // path.cubicTo(g + radius * 0.33, radius, x2, radius * 0.9, x2, 0);

    path.cubicTo(x1 + radius * e, 0, x1, radius, g, radius);
    path.cubicTo(x2, radius, g + radius * (1 - e), 0, x2, 0);
    path.lineTo(x2, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);

    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class TrianglePainter extends CustomPainter {
  double degToRad(num deg) => deg * (pi / 180.0);

  @override
  void paint(Canvas canvas, Size size) {
    double radius = 16;
    var paint = Paint()
      ..color = Colors.red
      ..isAntiAlias = true;
    var path = Path();

    path.moveTo(0, size.height / 3);
    path.lineTo(0, size.height - radius);
    // path.quadraticBezierTo(0, size.height, radius, size.height);
    path.cubicTo(0, size.height - radius * 0.33, radius * 0.33, size.height, radius, size.height);
    // path.cubicTo(0, size.height, radius, size.height - radius, radius, size.height);
    path.lineTo(size.width - radius, size.height);
    path.quadraticBezierTo(size.width, size.height, size.width, size.height - radius);
    path.lineTo(size.width, radius);
    // path.quadraticBezierTo(size.width, 0, size.width - radius, 0);
    path.quadraticBezierTo(size.width, 0, size.width - radius * 2, radius / 2);
    path.lineTo(radius, size.height / 3 - radius);
    // path.quadraticBezierTo(0, size.height / 3 - radius / 2, 0, size.height / 3 + radius);
    path.cubicTo(radius, size.height / 3 - radius * 0.33, 0, size.height / 3 - radius * 0.66, 0, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class BezierPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    var paint = Paint()..color = Colors.red;
    var path = Path();

    path.lineTo(0, size.height);
    path.quadraticBezierTo(size.width / 2, size.height + 100, size.width, size.height);
    path.lineTo(size.width, size.height);
    path.lineTo(size.width, 0);
    // path.quadraticBezierTo(size.width, 0, 0, 0);

    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
