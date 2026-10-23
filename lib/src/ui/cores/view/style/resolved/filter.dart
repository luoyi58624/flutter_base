/// 已展开模糊短手并完成范围规范的滤镜分量，色相保留完整圈数用于过渡。
typedef FilterStyle = ({
  double blurX,
  double blurY,
  double saturate,
  double brightness,
  double contrast,
  double grayscale,
  double sepia,
  double invert,
  double hueRotate,
  double opacity,
});

/// 所有滤镜分量的视觉恒等值，供空声明过渡时补位。
const FilterStyle identityFilterStyle = (
  blurX: 0,
  blurY: 0,
  saturate: 1,
  brightness: 1,
  contrast: 1,
  grayscale: 0,
  sepia: 0,
  invert: 0,
  hueRotate: 0,
  opacity: 1,
);
