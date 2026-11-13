part of '../style.dart';

List<_ShadowLayer> _insetShadow(int level) {
  final scale = _shadowScale(level);
  final density = _shadowDensity(level) * .8;
  return [
    (y: .325 * scale, blur: .75 * scale, spread: 0, alpha: .13 * density),
    (y: .75 * scale, blur: 1.4 * scale, spread: 0, alpha: .10 * density),
    (y: .425 * scale, blur: 2.75 * scale, spread: 0, alpha: .08 * density),
  ];
}
