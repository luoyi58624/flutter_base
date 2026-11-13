part of '../style.dart';

List<_ShadowLayer> _floatingShadow(int level) {
  final scale = _shadowScale(level);
  final density = _shadowDensity(level) * .75;
  return [
    (y: .975 * scale, blur: 2.4 * scale, spread: -scale, alpha: .13 * density),
    (y: 2.25 * scale, blur: 4.48 * scale, spread: -.25 * scale, alpha: .10 * density),
    (y: 1.275 * scale, blur: 8.8 * scale, spread: 0, alpha: .08 * density),
  ];
}
