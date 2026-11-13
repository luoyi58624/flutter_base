part of '../style.dart';

List<_ShadowLayer> _glowShadow(int level) {
  final scale = _shadowScale(level);
  final density = _shadowDensity(level) * .75;
  return [
    (y: 0, blur: 2.25 * scale, spread: .85 * scale, alpha: .13 * density),
    (y: 0, blur: 4.2 * scale, spread: .475 * scale, alpha: .10 * density),
    (y: 0, blur: 8.25 * scale, spread: .35 * scale, alpha: .08 * density),
  ];
}
