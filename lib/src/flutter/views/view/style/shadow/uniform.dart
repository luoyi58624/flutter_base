part of '../style.dart';

List<_ShadowLayer> _uniformShadow(int level) {
  final scale = _shadowScale(level);
  final density = _shadowDensity(level) * .75;
  return [
    (y: 0, blur: 1.5 * scale, spread: -scale, alpha: .13 * density),
    (y: 0, blur: 2.8 * scale, spread: -.25 * scale, alpha: .10 * density),
    (y: 0, blur: 5.5 * scale, spread: 0, alpha: .08 * density),
  ];
}
