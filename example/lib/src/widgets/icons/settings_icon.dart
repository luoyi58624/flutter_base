part of 'settings_icons.dart';

/// 绘制原设置页的矢量图标，可直接作为 ElView 或 Row 的 child。
class ElSettingIcon extends StatelessWidget {
  /// 创建图标，省略尺寸与颜色时使用原设置页的默认值。
  const ElSettingIcon(this.icon, {super.key, this.size, this.color, this.label})
    : assert(size == null || (size > 0 && size < double.infinity));

  /// 要绘制的设置图标。
  final ElSettingIcons icon;

  /// 覆盖图标边长，不受文字缩放影响。
  final double? size;

  /// 覆盖图标颜色。
  final Color? color;

  /// 独立图标的读屏说明；与文字同行时省略，避免重复播报。
  final String? label;

  @override
  Widget build(BuildContext context) => Semantics(
    image: label != null,
    label: label,
    excludeSemantics: label == null,
    child: SizedBox.square(
      dimension: size ?? icon.size,
      child: CustomPaint(painter: _IconPainter(icon, color ?? icon.color)),
    ),
  );
}

final _pathCache = <ElSettingIcons, List<Path>>{};

class _IconPainter extends CustomPainter {
  _IconPainter(this.icon, this.color);

  final ElSettingIcons icon;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paths = _pathCache.putIfAbsent(
      icon,
      () => [
        ...icon._sources.map(_svgPath),
        for (final circle in icon._circles) Path()..addOval(circle),
      ],
    );
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = icon.strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    for (final path in paths) {
      canvas.drawPath(path, paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _IconPainter oldDelegate) =>
      oldDelegate.icon != icon || oldDelegate.color != color;
}

/// 保留原版路径的相对坐标和椭圆弧，只解析提取素材实际使用的指令。
Path _svgPath(String source) {
  final tokens = RegExp(r'[a-zA-Z]|[-+]?(?:\d*\.?\d+)(?:[eE][-+]?\d+)?')
      .allMatches(source)
      .map((match) => match[0]!)
      .toList();
  final path = Path();
  var index = 0;
  var command = '';
  var current = Offset.zero;
  var start = Offset.zero;
  Offset? cubicControl;
  double number() => double.parse(tokens[index++]);
  while (index < tokens.length) {
    if (RegExp(r'^[a-zA-Z]$').hasMatch(tokens[index])) {
      command = tokens[index++];
    }
    final relative = command == command.toLowerCase();
    final operation = command.toUpperCase();
    final origin = current;
    Offset point() {
      final value = Offset(number(), number());
      return relative ? origin + value : value;
    }

    switch (operation) {
      case 'M':
        current = point();
        start = current;
        path.moveTo(current.dx, current.dy);
        command = relative ? 'l' : 'L';
      case 'L':
        current = point();
        path.lineTo(current.dx, current.dy);
      case 'H':
        current = Offset(number() + (relative ? origin.dx : 0), origin.dy);
        path.lineTo(current.dx, current.dy);
      case 'V':
        current = Offset(origin.dx, number() + (relative ? origin.dy : 0));
        path.lineTo(current.dx, current.dy);
      case 'C':
        final first = point(), second = point(), end = point();
        path.cubicTo(first.dx, first.dy, second.dx, second.dy, end.dx, end.dy);
        cubicControl = second;
        current = end;
      case 'S':
        final first = cubicControl == null ? origin : origin * 2 - cubicControl;
        final second = point(), end = point();
        path.cubicTo(first.dx, first.dy, second.dx, second.dy, end.dx, end.dy);
        cubicControl = second;
        current = end;
      case 'A':
        final rx = number(), ry = number(), rotation = number();
        final large = number() != 0, sweep = number() != 0, end = point();
        path.arcToPoint(
          end,
          radius: Radius.elliptical(rx, ry),
          rotation: rotation,
          largeArc: large,
          clockwise: sweep,
        );
        current = end;
      case 'Z':
        path.close();
        current = start;
        command = '';
      default:
        throw FormatException('设置图标含未支持的路径命令', command);
    }
    if (operation != 'C' && operation != 'S') cubicControl = null;
  }
  return path;
}
