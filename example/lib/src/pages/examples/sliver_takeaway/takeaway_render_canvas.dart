part of 'takeaway.dart';

typedef _TakeawayInk = ({
  TextStyle text,
  TextScaler scaler,
  TextDirection direction,
  Locale? locale,
  bool boldText,
  Color foreground,
  Color muted,
  Color background,
  Color border,
});

enum _ShopField {
  brand,
  title,
  timely,
  rating,
  sales,
  minimum,
  minutes,
  distance,
  delivery,
  address,
  recent,
  years,
  quality,
  couponTag,
  discount,
  pickup,
  description,
  review,
  couponTitle,
  couponPrice,
  couponHint,
  assurance,
  number,
}

class _TakeawayCanvas {
  static const _gap = 6.0;
  static const _buttonWidth = 28.0;
  static const _buttonHeight = 26.0;
  static const _chipFill = Color(0x17f26718);
  static const _chipOutline = Color(0x40f26718);

  final _labels = List<_TakeawayLabel?>.filled(_ShopField.values.length, null);
  final _dishes = <_TakeawayDish?>[];
  final _fill = Paint();
  final _stroke = Paint()..style = .stroke;
  final _imagePaint = Paint()..filterQuality = .low;

  late _TakeawayInk _ink;
  late _Store _store;
  Rect _card = Rect.zero;
  Rect _logo = Rect.zero;
  Rect _coupon = Rect.zero;
  Rect _menu = Rect.zero;
  double _tileWidth = 0;
  double _couponIconY = 0;
  double _reviewX = 0;
  double _assuranceX = 0;
  double _atlasOpacity = 1;

  Rect get menuBounds => _menu.isEmpty ? _menu : _physicalRect(_menu);

  double get menuItemExtent => _tileWidth + _gap;

  Rect menuButtonRect(int index, double offset) => _physicalRect(
    Rect.fromLTWH(
      _itemX(index, offset) + _tileWidth - _buttonWidth,
      _menu.bottom - _buttonHeight,
      _buttonWidth,
      _buttonHeight,
    ),
  );

  double layout({required double width, required _Store store, required _TakeawayInk ink}) {
    _store = store;
    _ink = ink;
    final cardWidth = math.min(840.0, math.max(0.0, width - 16));
    final outerLeft = (width - cardWidth) / 2;
    final padding = math.min(8.0, cardWidth / 4);
    final left = outerLeft + padding;
    final right = outerLeft + cardWidth - padding;
    final innerWidth = right - left;
    const top = 14.0;
    final logoSide = math.min(52.0, innerWidth * .28);
    _logo = Rect.fromLTWH(left, top, logoSide, logoSide);
    final brand = _text(.brand, '品牌好店', logoSide, size: 9, color: _orange);
    brand.place(left + (logoSide - brand.width) / 2, _logo.bottom + 2);

    final infoX = _logo.right + math.min(8.0, innerWidth * .05);
    final infoWidth = right - infoX;
    final timely = _chip(.timely, '准时达', infoWidth * .38);
    final title = _text(
      .title,
      store.name,
      infoWidth - timely.width - 14,
      size: 14,
      bold: true,
      lines: infoWidth < 205 || ink.scaler.scale(14) > 17 ? 2 : 1,
    );
    title.place(infoX, top);
    timely.placeChip(right - timely.width - 8, top, outlined: true);
    var y = top + math.max(title.height, timely.height + 2) + 2;

    _text(.rating, '${store.rating} 分', infoWidth, color: _orange, bold: true);
    _text(.sales, '月售 ${store.sales}+', infoWidth, size: 10, color: ink.muted);
    _text(.minimum, '起送 ¥${store.minimum}', infoWidth, size: 10, color: ink.muted);
    _text(.minutes, '${store.minutes}–${store.minutes + 10}分钟', infoWidth, size: 11, color: _green);
    _text(.distance, '${store.distance}km', infoWidth, size: 10, color: ink.muted);
    y = _wrap(.rating, .distance, infoX, right, y, spacing: 6) + 2;

    final delivery = _text(.delivery, '免配送费', infoWidth * .38, size: 10, color: _orange);
    delivery.place(infoX, y);
    final address = _text(.address, store.address, infoWidth - delivery.width - 6, size: 9.5, color: ink.muted);
    address.place(right - address.width, y);
    y += math.max(delivery.height, address.height) + 2;

    _chip(.recent, store.tags[0], infoWidth);
    _chip(.years, store.tags[1], infoWidth);
    _chip(.quality, store.tags[2], infoWidth);
    y = _wrap(.recent, .quality, infoX, right, y, chips: true) + 2;
    _chip(.couponTag, '${store.coupon}元店铺红包', infoWidth);
    _chip(.discount, '满35减5', infoWidth);
    _chip(.pickup, '支持自取', infoWidth);
    y = _wrap(.couponTag, .pickup, infoX, right, y, chips: true, outlined: true);

    y = math.max(y, _logo.bottom + 2 + brand.height) + 4;
    final description = _text(.description, store.description, innerWidth, size: 11, color: ink.muted, lines: 3);
    description.place(left, y);
    y += description.height + 4;
    _reviewX = left;
    final review = _text(.review, store.review, innerWidth - 16, size: 10, color: ink.muted, lines: 2);
    review.place(left + 16, y);
    y += review.height + 4;

    final fontDelta = math.max(0.0, ink.scaler.scale(14) - 14);
    _tileWidth = 94 + fontDelta * 3;
    final menuHeight = math.max(
      184 + fontDelta * 8,
      _tileWidth +
          2 * ink.scaler.scale(12) * 1.22 +
          2 * ink.scaler.scale(9.5) * 1.22 +
          math.max(_buttonHeight, ink.scaler.scale(16) * 1.22) +
          12,
    );
    final couponWidth = math.min(52 + fontDelta * 2, innerWidth * .34);
    _coupon = Rect.fromLTWH(left, y, couponWidth, menuHeight);
    _menu = Rect.fromLTRB(_coupon.right + math.min(8.0, innerWidth * .05), y, right, y + menuHeight);
    _layoutCoupon(store.coupon);
    y += menuHeight + 4;

    _assuranceX = left;
    final number = _text(.number, '门店 #${store.id + 1}', innerWidth * .4, size: 9.5, color: ink.muted);
    final assurance = _text(
      .assurance,
      '明厨亮灶 · 独立封签 · 售后有保障',
      innerWidth - number.width - 20,
      size: 9.5,
      color: ink.muted,
      lines: 2,
    );
    number.place(right - number.width, y);
    assurance.place(left + 15, y);
    final height = y + math.max(number.height, assurance.height) + 8;
    _card = Rect.fromLTWH(outerLeft, 6, cardWidth, height - 6);
    return height;
  }

  void _layoutCoupon(int amount) {
    final width = _coupon.width - 8;
    final title = _text(.couponTitle, '店铺红包', width, size: 10, color: _orange, lines: 2);
    final price = _text(.couponPrice, '¥$amount', width, size: 22, color: _orange, bold: true, scaleDown: true);
    final hint = _text(.couponHint, '进店领好价', width, size: 9, color: _orange, lines: 2);
    _couponIconY = _coupon.center.dy - (20 + title.height + price.height + hint.height + 18) / 2;
    title.place(_coupon.center.dx - title.width / 2, _couponIconY + 26);
    price.place(_coupon.center.dx - price.width / 2, title.bottom + 6);
    hint.place(_coupon.center.dx - hint.width / 2, price.bottom + 6);
  }

  _TakeawayLabel _text(
    _ShopField field,
    String content,
    double width, {
    double size = 12,
    Color? color,
    bool bold = false,
    int lines = 1,
    bool scaleDown = false,
  }) =>
      (_labels[field.index] ??= _TakeawayLabel())
        ..layout(content, width, _ink, size: size, color: color, bold: bold, lines: lines, scaleDown: scaleDown);

  _TakeawayLabel _chip(_ShopField field, String content, double width) =>
      _text(field, content, width - 8, size: 9.5, color: _orange);

  double _wrap(
    _ShopField first,
    _ShopField last,
    double left,
    double right,
    double y, {
    double spacing = 4,
    bool chips = false,
    bool outlined = false,
  }) {
    var x = left;
    var lineHeight = 0.0;
    for (var index = first.index; index <= last.index; index++) {
      final label = _labels[index]!;
      final width = label.width + (chips ? 8 : 0);
      if (x > left && x + width > right) {
        x = left;
        y += lineHeight + 3;
        lineHeight = 0;
      }
      if (chips) {
        label.placeChip(x, y, outlined: outlined);
      } else {
        label.place(x, y);
      }
      lineHeight = math.max(lineHeight, label.height + (chips ? 2 : 0));
      x += width + spacing;
    }
    return y + lineHeight;
  }

  double _itemX(int index, double offset) => _menu.left + index * menuItemExtent - offset;

  double _physicalX(double x, double width) => _ink.direction == .ltr ? x : _card.left + _card.right - x - width;

  Rect _physicalRect(Rect rect) => _ink.direction == .ltr
      ? rect
      : Rect.fromLTWH(_physicalX(rect.left, rect.width), rect.top, rect.width, rect.height);

  void paint(Canvas canvas, _FoodAtlas atlas, double menuOffset) {
    if (_card.isEmpty) return;
    final atlasOpacity = atlas.opacity;
    if (_atlasOpacity != atlasOpacity) {
      _atlasOpacity = atlasOpacity;
      _imagePaint.color = Color.fromRGBO(0, 0, 0, atlasOpacity);
    }
    final tiles = _cuisinePhotoTiles[_store.id % _cuisinePhotoTiles.length];
    final card = RRect.fromRectAndRadius(_card, const Radius.circular(10));
    canvas.drawRRect(card, _fill..color = _ink.background);
    canvas.drawRRect(card.deflate(.5), _stroke..color = _ink.border);
    canvas.save();
    canvas.clipRRect(card);
    _paintPhoto(canvas, atlas, tiles.first, _logo);
    _paintRounded(canvas, _coupon, 6, _chipFill);
    _paintCouponIcon(canvas);
    _paintDecorations(canvas);
    for (final label in _labels) {
      if (label == null) continue;
      final chip = label.chip;
      if (chip != null) {
        final bounds = RRect.fromRectAndRadius(_physicalRect(chip), const Radius.circular(4));
        if (label.outlined) {
          canvas.drawRRect(bounds.deflate(.5), _stroke..color = _chipOutline);
        } else {
          canvas.drawRRect(bounds, _fill..color = _chipFill);
        }
      }
      label.paint(canvas, _physicalX(label.position.dx, label.width));
    }
    _paintMenu(canvas, atlas, tiles, menuOffset);
    canvas.restore();
  }

  void _paintMenu(Canvas canvas, _FoodAtlas atlas, List<int> tiles, double offset) {
    if (_menu.isEmpty) return;
    final dishes = _store.dishes;
    final first = (offset / menuItemExtent).floor().clamp(0, dishes.length);
    final end = ((offset + _menu.width) / menuItemExtent).ceil().clamp(0, dishes.length);
    canvas.save();
    canvas.clipRect(menuBounds);
    // 菜品文字只在进入横向视口时排版，复用的卡片仅重排换过数据的槽位。
    if (_dishes.length < end) _dishes.length = end;
    for (var index = first; index < end; index++) {
      final x = _itemX(index, offset);
      final bounds = Rect.fromLTWH(x, _menu.top, _tileWidth, _menu.height);
      if (bounds.right <= _menu.left) continue;
      final tile = _dishes[index] ??= _TakeawayDish();
      tile.layout(dishes[index], _tileWidth, _ink);
      _paintRounded(canvas, bounds, 6, _ink.background, border: _ink.border);
      _paintPhoto(canvas, atlas, tiles[index % tiles.length], Rect.fromLTWH(x, _menu.top, _tileWidth, _tileWidth));
      var y = _menu.top + _tileWidth + 3;
      for (final label in tile.details) {
        label.paintAt(canvas, Offset(_physicalX(x + 2, label.width), y));
        y += label.height + 3;
      }
      final button = menuButtonRect(index, offset);
      tile.price.paintAt(canvas, Offset(_physicalX(x + 2, tile.price.width), button.center.dy - tile.price.height / 2));
      _paintAdd(canvas, button.center);
    }
    canvas.restore();
  }

  void _paintPhoto(Canvas canvas, _FoodAtlas atlas, int index, Rect logicalBounds) {
    final image = atlas.value;
    if (image == null || _atlasOpacity == 0 || logicalBounds.isEmpty) return;
    final bounds = _physicalRect(logicalBounds);
    final rounded = RRect.fromRectAndRadius(bounds, const Radius.circular(8));
    canvas.save();
    canvas.clipRRect(rounded);
    canvas.drawImageRect(image, atlas.tileRect(index), bounds, _imagePaint);
    canvas.restore();
  }

  void _paintRounded(Canvas canvas, Rect bounds, double radius, Color color, {Color? border}) {
    final rounded = RRect.fromRectAndRadius(_physicalRect(bounds), Radius.circular(radius));
    canvas.drawRRect(rounded, _fill..color = color);
    if (border != null) canvas.drawRRect(rounded.deflate(.5), _stroke..color = border);
  }

  void _paintAdd(Canvas canvas, Offset center) {
    canvas.drawCircle(center, 10, _fill..color = _orange);
    _stroke.color = Colors.white;
    canvas.drawLine(center - const Offset(4, 0), center + const Offset(4, 0), _stroke);
    canvas.drawLine(center - const Offset(0, 4), center + const Offset(0, 4), _stroke);
  }

  void _paintCouponIcon(Canvas canvas) {
    final center = Offset(_physicalX(_coupon.center.dx, 0), _couponIconY + 10);
    final ticket = Rect.fromCenter(center: center, width: 18, height: 12);
    canvas.drawRRect(RRect.fromRectAndRadius(ticket, const Radius.circular(2)), _fill..color = _orange);
    canvas.drawLine(center - const Offset(0, 3), center + const Offset(0, 3), _stroke..color = Colors.white);
  }

  void _paintDecorations(Canvas canvas) {
    final review = _labels[_ShopField.review.index]!;
    final quote = Offset(_physicalX(_reviewX + 6, 0), review.position.dy + 5);
    canvas.drawCircle(quote - const Offset(2.5, 0), 1.6, _fill..color = _orange);
    canvas.drawCircle(quote + const Offset(2.5, 0), 1.6, _fill);
    final assurance = _labels[_ShopField.assurance.index]!;
    final check = Offset(_physicalX(_assuranceX + 5.5, 0), assurance.position.dy + 5.5);
    canvas.drawCircle(check, 5, _fill..color = _green);
    _stroke.color = Colors.white;
    canvas.drawLine(check + const Offset(-2.5, 0), check + const Offset(-.5, 2), _stroke);
    canvas.drawLine(check + const Offset(-.5, 2), check + const Offset(2.5, -2), _stroke);
  }

  void dispose() {
    for (final label in _labels) {
      label?.dispose();
    }
    for (final dish in _dishes) {
      dish?.dispose();
    }
  }
}

class _TakeawayDish {
  final details = [_TakeawayLabel(), _TakeawayLabel(), _TakeawayLabel()];
  final price = _TakeawayLabel();
  _Dish? _dish;
  double _width = 0;
  _TakeawayInk? _ink;

  void layout(_Dish dish, double width, _TakeawayInk ink) {
    if (identical(_dish, dish) && _width == width && _ink == ink) return;
    _dish = dish;
    _width = width;
    _ink = ink;
    details[0].layout(dish.name, width - 4, ink, lines: 2);
    details[1].layout(dish.subtitle, width - 4, ink, size: 9.5, color: ink.muted);
    details[2].layout('月售${dish.sales} · 好评${dish.praise}%', width - 4, ink, size: 9.5, color: ink.muted);
    price.layout('¥${_money(dish.cents)}', width - 30, ink, size: 16, color: _orange, bold: true, scaleDown: true);
  }

  void dispose() {
    for (final label in details) {
      label.dispose();
    }
    price.dispose();
  }
}

class _TakeawayLabel {
  final _painter = TextPainter(ellipsis: '…');
  (String, double, _TakeawayInk, double, Color, bool, int, bool)? _configuration;
  double _scale = 1;
  Offset position = Offset.zero;
  Rect? chip;
  bool outlined = false;

  double get width => _painter.width * _scale;
  double get height => _painter.height * _scale;
  double get bottom => position.dy + height;

  void layout(
    String content,
    double maxWidth,
    _TakeawayInk ink, {
    double size = 12,
    Color? color,
    bool bold = false,
    int lines = 1,
    bool scaleDown = false,
  }) {
    final limit = math.max(0.0, maxWidth);
    final foreground = color ?? ink.foreground;
    final configuration = (content, limit, ink, size, foreground, bold, lines, scaleDown);
    if (_configuration == configuration) return;
    _configuration = configuration;
    _painter
      ..text = TextSpan(
        text: content,
        style: ink.text.copyWith(
          color: foreground,
          fontSize: size,
          fontWeight: bold || ink.boldText ? .w700 : .w400,
          height: 1.22,
          letterSpacing: 0,
          leadingDistribution: .even,
        ),
      )
      ..textDirection = ink.direction
      ..textScaler = ink.scaler
      ..locale = ink.locale
      ..maxLines = lines
      ..layout(maxWidth: scaleDown ? double.infinity : limit);
    _scale = scaleDown && _painter.width > limit ? limit / _painter.width : 1;
  }

  void place(double x, double y) {
    chip = null;
    position = Offset(x, y);
  }

  void placeChip(double x, double y, {required bool outlined}) {
    chip = Rect.fromLTWH(x, y, width + 8, height + 2);
    position = Offset(x + 4, y + 1);
    this.outlined = outlined;
  }

  void paint(Canvas canvas, double x) => paintAt(canvas, Offset(x, position.dy));

  void paintAt(Canvas canvas, Offset offset) {
    if (_scale == 1) {
      _painter.paint(canvas, offset);
    } else if (_scale > 0) {
      canvas.save();
      canvas.translate(offset.dx, offset.dy);
      canvas.scale(_scale);
      _painter.paint(canvas, Offset.zero);
      canvas.restore();
    }
  }

  void dispose() => _painter.dispose();
}
