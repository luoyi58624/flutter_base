import 'package:flutter_base/src/ui/cores/popup/anchor.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('公开配置默认值与旧锚定配置一致', () {
    final anchor = ElOverlayAnchor();
    expect(anchor.placement, ElPlacement.bottom);
    expect(anchor.offset, 0);
    expect(anchor.crossOffset, 0);
    expect(anchor.flip, isTrue);
    expect(anchor.shift, isTrue);
    expect(anchor.viewportPadding, 8);
    expect(anchor.matchWidth, isFalse);
    expect(anchor.matchMinWidth, isFalse);
    expect(anchor, ElOverlayAnchor());
    expect(anchor.hashCode, ElOverlayAnchor().hashCode);
  });

  test('底部空间不足翻到上方，保留交叉轴对齐与偏移', () {
    final result = ElOverlayAnchor(
      placement: .bottomEnd,
      offset: 4,
      crossOffset: 3,
    ).resolve(Rect.fromLTWH(200, 180, 60, 20), Size(100, 70), Size(300, 220));
    expect(result.placement, ElPlacement.topEnd);
    expect(result.overlayRect, Rect.fromLTWH(163, 106, 100, 70));
  });

  test('左右翻转与双轴 clamp；两侧均不足仍停在安全区', () {
    final result = ElOverlayAnchor(
      placement: .rightStart,
    ).resolve(Rect.fromLTWH(260, 190, 20, 20), Size(100, 100), Size(300, 220));
    expect(result.placement, ElPlacement.leftStart);
    expect(result.overlayRect, Rect.fromLTWH(160, 112, 100, 100));
    final clamped = ElOverlayAnchor(
      placement: .bottomStart,
    ).resolve(Rect.fromLTWH(-20, 70, 20, 20), Size(284, 204), Size(300, 220));
    expect(clamped.overlayRect, Rect.fromLTWH(8, 8, 284, 204));
  });

  test('关闭 flip 和 shift 时保留越界位置', () {
    final result = ElOverlayAnchor(
      placement: .bottomStart,
      flip: false,
      shift: false,
    ).resolve(Rect.fromLTWH(-10, 200, 20, 20), Size(100, 100), Size(300, 220));
    expect(result.placement, ElPlacement.bottomStart);
    expect(result.overlayRect.topLeft, Offset(-10, 220));
  });

  test('十二种 placement 的翻转可逆，箭头投影在面板边界内', () {
    final positions = <ElPlacement, Offset>{
      .top: Offset(73, 36),
      .topStart: Offset(103, 36),
      .topEnd: Offset(43, 36),
      .bottom: Offset(73, 124),
      .bottomStart: Offset(103, 124),
      .bottomEnd: Offset(43, 124),
      .left: Offset(16, 83),
      .leftStart: Offset(16, 103),
      .leftEnd: Offset(16, 63),
      .right: Offset(124, 83),
      .rightStart: Offset(124, 103),
      .rightEnd: Offset(124, 63),
    };
    for (final placement in ElPlacement.values) {
      expect(placement.flipped.flipped, placement);
      final geometry = ElOverlayAnchor(
        placement: placement,
        offset: 4,
        crossOffset: 3,
      ).resolve(Rect.fromLTWH(100, 100, 20, 20), Size(80, 60), Size(300, 300));
      expect(geometry.placement, placement);
      expect(geometry.overlayRect.topLeft, positions[placement]);
      expect(geometry.arrowTarget.dx, inInclusiveRange(0, 80));
      expect(geometry.arrowTarget.dy, inInclusiveRange(0, 60));
    }
  });
}
