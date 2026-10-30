import 'package:flutter/foundation.dart' show precisionErrorTolerance;

/// item 主轴 extent 对齐到物理像素网格（**ceil** 到 n/dpr 的整数倍）。
///
/// 逐 item 的 RepaintBoundary layer 由引擎按物理像素各自吸附合成：item 高度
/// 带小数（真实字体行高的常态）时各 layer 偏移的小数相位不同、被各自取整，
/// 相位回绕处相邻 item 的半透明内容（选区带 / bgColor）叠出 1 物理像素深线
/// （Windows 桌面实测：全选虚拟文本列表出现周期性深色横带；toImage / Web
/// 合成器不走该吸附路径，测不出）。extent 落在网格上 → 前缀和行边界恒为
/// 物理像素整数。注意这里只量化**布局 extent**；滚动 transform 必须保留
/// 亚像素，否则高刷慢速运动会被合帧。
///
/// **取 ceil 而非 floor**（2026-07-25 修正）：floor 使 quantized < 实测高，落地时
/// 必须用上界约束把 item **压缩** <1 物理像素——内部 flex 收不动就直接
/// `RenderFlex OVERFLOWING`（卡片行 = 定高图片 + 文本 + padding 刚好填满，是这个
/// 形状的常态），旧注释「视觉不可感」漏算了这条错误路径。ceil 后 quantized ≥
/// 实测高，改用**下界**约束把 item 拉伸到网格（见 `_layoutChildToGrid`），
/// 不压缩任何内容，溢出随之消失。
///
/// 亮缝为何不会出现：选区带取 `min(ceil(lineBottom), size)`，而
/// `ceil_grid(extent) ≤ ceil(extent)`（网格比整数像素更细），且 `lineBottom ≤ extent`，
/// 故 `size ≤ ceil(lineBottom)` → min 恒取到 size → 带与 item 底边齐平。
double snapVirtualItemExtentToPixelGrid(double extent, double devicePixelRatio) {
  if (devicePixelRatio <= 0.0 || !devicePixelRatio.isFinite || extent <= 0.0) return extent;
  // − 容差：浮点噪声（如 96.000…01 × 3 = 288.000…03）不得被 ceil 误抬 1 物理像素。
  final snapped = (extent * devicePixelRatio - precisionErrorTolerance).ceilToDouble() / devicePixelRatio;
  return snapped > 0.0 ? snapped : extent;
}
