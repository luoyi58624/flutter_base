import '../style.dart';
import '../state/view_state.dart';

/// 计算 [width] 对应的响应式状态位。
///
/// 响应式模型:划分 5 个尺寸级别,每一档都是纯上界判断——宽度 <= 该档上界
/// 即为 true(超小屏 xs、移动端 sm、平板 md、桌面 lg、超大桌面 xl)。
/// 全部 5 档均为 false 表示布局超过 xl 定义的上界(默认 2560),
/// 即一个超大布局。
int computeResponsiveBits(double width, ElBreakpoint? breakpoint) {
  final xsMax = breakpoint?.xs ?? ElBreakpoint.defaultXs;
  final smMax = breakpoint?.sm ?? ElBreakpoint.defaultSm;
  final mdMax = breakpoint?.md ?? ElBreakpoint.defaultMd;
  final lgMax = breakpoint?.lg ?? ElBreakpoint.defaultLg;
  final xlMax = breakpoint?.xl ?? ElBreakpoint.defaultXl;
  var bits = 0;
  if (width <= xsMax) bits |= 1 << ViewState.xs.index;
  if (width <= smMax) bits |= 1 << ViewState.sm.index;
  if (width <= mdMax) bits |= 1 << ViewState.md.index;
  if (width <= lgMax) bits |= 1 << ViewState.lg.index;
  if (width <= xlMax) bits |= 1 << ViewState.xl.index;
  return bits;
}

/// 响应式状态掩码，随枚举位次生成，避免与交互状态串位。
final int responsiveStateMask =
    (1 << ViewState.xs.index) |
    (1 << ViewState.sm.index) |
    (1 << ViewState.md.index) |
    (1 << ViewState.lg.index) |
    (1 << ViewState.xl.index);
