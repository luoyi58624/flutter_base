part of 'index.dart';

// ===========================================================================
// ElLevelType 五级阴影生成（ElApp 私有实现）
//
// xs：贴地分组卡片，不投外阴影；sm..xl：沿用先前低层级已调过的几何与
// alpha，按 ElLevelType 的顺序递进。普通白卡与 #F0F1F3 页面背景的分层由
// 底色、圆角和留白完成，不强行附加投影。
// ===========================================================================

/// 亮表基色：墨蓝黑，避免纯黑阴影发灰。
const Color _shadowColorLight = Color(0xFF0F172A);

/// 暗表基色：纯黑。
const Color _shadowColorDark = Color(0xFF000000);

/// `sm` 是无横向偏移的贴地环境阴影。
List<BoxShadow> _buildShadowSm(Color color, double alpha) => [
  BoxShadow(
    color: color.withValues(alpha: alpha),
    blurRadius: 6,
    offset: const Offset(0, 1),
  ),
];

/// `md..xl` 的多层投影：每层 `(blur, y偏移, spread)`，x:y = 1:2。
List<BoxShadow> _buildShadow(
  List<(double, double, double)> spec,
  Color color,
  List<double> alpha,
) => [
  for (var i = 0; i < spec.length; i++)
    BoxShadow(
      color: color.withValues(alpha: alpha[i]),
      blurRadius: spec[i].$1,
      offset: Offset(spec[i].$2 / 2, spec[i].$2),
      spreadRadius: spec[i].$3,
    ),
];

/// 亮表五档：xs 无阴影；sm..xl 总 alpha 为 4.5% / 8% / 12% / 16.5%。
Map<ElLevelType, List<BoxShadow>> get _shadowLevelsLight => {
  ElLevelType.xs: const <BoxShadow>[],
  ElLevelType.sm: _buildShadowSm(_shadowColorLight, 0.045),
  ElLevelType.md: _buildShadow(
    const [(2, 2, 0), (4, 4, 0)],
    _shadowColorLight,
    const [0.04, 0.04],
  ),
  ElLevelType.lg: _buildShadow(
    const [(2, 2, 0), (6, 6, 0)],
    _shadowColorLight,
    const [0.06, 0.06],
  ),
  ElLevelType.xl: _buildShadow(
    const [(2, 2, 0), (4, 4, 0), (8, 8, 0)],
    _shadowColorLight,
    const [0.055, 0.055, 0.055],
  ),
};

/// 暗表五档：xs 无阴影；sm..xl 总 alpha 为 7% / 12% / 18% / 24%。
Map<ElLevelType, List<BoxShadow>> get _shadowLevelsDark => {
  ElLevelType.xs: const <BoxShadow>[],
  ElLevelType.sm: _buildShadowSm(_shadowColorDark, 0.07),
  ElLevelType.md: _buildShadow(
    const [(2, 2, 0), (4, 4, 0)],
    _shadowColorDark,
    const [0.06, 0.06],
  ),
  ElLevelType.lg: _buildShadow(
    const [(2, 2, 0), (6, 6, 0)],
    _shadowColorDark,
    const [0.09, 0.09],
  ),
  ElLevelType.xl: _buildShadow(
    const [(2, 2, 0), (4, 4, 0), (8, 8, 0)],
    _shadowColorDark,
    const [0.08, 0.08, 0.08],
  ),
};
