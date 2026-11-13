part of '../style.dart';

List<_ShadowLayer> _materialShadow(int level) {
  // 日常级别接近原版的投影距离，更高级别逐渐放缓，避免模糊半径暴涨。
  final height = level <= 16 ? level.toDouble() : 16 * (1 + math.log(level / 16));
  final spread = math.max(0.0, height - 4);
  final density = .95 + .08 * height / (height + 4);
  return [
    // 本影收在底边附近，半影向下拉开，环境阴影在四周逐渐散开。
    (y: 1.6 + .4 * height, blur: .4 + .6 * height, spread: -math.max(1.0, .32 * height), alpha: .20 * density),
    (y: height, blur: height * (1 + .75 * height / (height + 8)), spread: .22 * spread, alpha: .14 * density),
    (y: 1 + .4 * spread, blur: 1 + 1.84 * height, spread: .4 * spread, alpha: .12 * density),
  ];
}
