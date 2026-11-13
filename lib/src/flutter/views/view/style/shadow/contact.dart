part of '../style.dart';

List<_ShadowLayer> _contactShadow(int level) {
  final scale = _shadowScale(level);
  final density = _shadowDensity(level);
  return [
    (y: .1625 * scale, blur: .525 * scale, spread: -.25 * scale, alpha: .13 * density),
    (y: .375 * scale, blur: .98 * scale, spread: -.0625 * scale, alpha: .10 * density),
    (y: .2125 * scale, blur: 1.925 * scale, spread: 0, alpha: .08 * density),
  ];
}
