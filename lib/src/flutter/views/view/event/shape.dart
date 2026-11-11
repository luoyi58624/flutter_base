import 'package:flutter/gestures.dart'
    show kBackMouseButton, kForwardMouseButton, kPrimaryButton, kSecondaryButton, kTertiaryButton;
import 'package:flutter/widgets.dart' show Axis;

import '../../../utils/internal/bit_mask.dart';
import 'details.dart';

/// 一份事件声明里已声明回调的位图。
///
/// 分发器在设置声明时编译一次；手势候选、换形比较和命中判定都读这份位图，
/// 不再逐个回调现查，也不为声明对象另存回调列表。
extension type const EventShape._(FieldMask _mask) {
  /// 没有任何回调的声明。
  static const none = EventShape._(FieldMask.empty);

  /// 按 [handlerFor] 的查询结果编译位图：先是各阶段，其后是横向、纵向拖拽组。
  static EventShape compile(Object? Function(ElEventPhase phase, [Axis? axis]) handlerFor) {
    var mask = FieldMask.empty;
    for (final phase in ElEventPhase.values) {
      if (handlerFor(phase) != null) mask = maskSetBit(mask, phase.index);
    }
    for (final axis in Axis.values) {
      for (final phase in ElEventPhase.dragPhases) {
        if (handlerFor(phase, axis) != null) mask = maskSetBit(mask, _bit(phase, axis));
      }
    }
    return EventShape._(mask);
  }

  /// 是否声明了任何回调。
  bool get isNotEmpty => _mask.isNotEmpty;

  /// 是否声明了指定阶段的回调，[axis] 选择拖拽阶段的轴向组。
  bool has(ElEventPhase phase, [Axis? axis]) => maskHas(_mask, _bit(phase, axis));

  /// 是否声明了自由拖拽。
  bool get pan => _any(_pan);

  /// 是否声明了任一拖拽组，不含拖拽按下。
  bool get drag => _any(_drag);

  /// 该轴向的位移是否有拖拽组承接；自由拖拽承接所有轴向。
  bool acceptsDrag(Axis axis) => _any(axis == Axis.horizontal ? _panOrHorizontal : _panOrVertical);

  /// 是否声明了缩放或旋转。
  bool get scale => _any(_scale);

  /// 是否声明了需要参加手势竞技场的回调：点击、长按、拖拽、缩放。
  bool get gesture => _any(_gesture);

  /// 只声明了长按，没有其他主键点击回调。
  bool get longPressOnly => has(ElEventPhase.longPress) && !_any(_plainTap);

  /// 需要识别的最大连击数。
  int get maxTaps => _any(_triple) ? 3 : (_any(_double) ? 2 : 1);

  /// 是否为该按键组合建立点击候选。
  bool wantsTap(int buttons) => switch (buttons) {
    kPrimaryButton => has(ElEventPhase.longPress) || _any(_plainTap),
    kSecondaryButton => _any(_secondaryTap),
    kTertiaryButton => _any(_tertiaryTap),
    kForwardMouseButton => _any(_forwardTap),
    kBackMouseButton => _any(_backTap),
    _ => false,
  };

  /// 两份声明在点击、长按、原始指针、键盘等非拖拽阶段上的回调集合是否相同。
  bool sameDiscrete(EventShape other) => _same(other, _discrete);

  /// 两份声明的缩放与旋转回调集合是否相同。
  bool sameScale(EventShape other) => _same(other, _scale);

  bool _any(FieldMask group) => maskAnd(_mask, group).isNotEmpty;

  bool _same(EventShape other, FieldMask group) => maskAnd(_mask, group) == maskAnd(other._mask, group);
}

final int _axisBase = ElEventPhase.values.length;

int _bit(ElEventPhase phase, [Axis? axis]) {
  if (axis == null) return phase.index;
  assert(ElEventPhase.dragPhases.contains(phase), '只有拖拽阶段区分轴向组。');
  return _axisBase + axis.index * ElEventPhase.dragPhases.length + ElEventPhase.dragPhases.indexOf(phase);
}

FieldMask _group(Iterable<ElEventPhase> phases, [Axis? axis]) =>
    phases.fold(FieldMask.empty, (mask, phase) => maskSetBit(mask, _bit(phase, axis)));

final _pan = _group(ElEventPhase.dragPhases);
final _panOrHorizontal = maskOr(_pan, _group(ElEventPhase.dragPhases, Axis.horizontal));
final _panOrVertical = maskOr(_pan, _group(ElEventPhase.dragPhases, Axis.vertical));
final _drag = maskOr(_panOrHorizontal, _panOrVertical);
final _scale = _group(ElEventPhase.scalePhases);
final _double = _group(const [.doubleTap, .doubleTapDown]);
final _triple = _group(const [.tripleTap, .tripleTapDown]);
final _plainTap = maskOr(maskOr(_double, _triple), _group(const [.tapDown, .tapUp, .tap, .tapCancel]));
final _secondaryTap = _group(const [.secondaryTapDown, .secondaryTapUp, .secondaryTap]);
final _tertiaryTap = _group(const [.tertiaryTapDown, .tertiaryTapUp, .tertiaryTap]);
final _forwardTap = _group(const [.forwardTapDown, .forwardTapUp, .forwardTap]);
final _backTap = _group(const [.backTapDown, .backTapUp, .backTap]);

// 点击到旋转之间的全部派生手势阶段，加上两个轴向拖拽组。
final _gesture = maskOr(
  _drag,
  _group(ElEventPhase.values.getRange(ElEventPhase.tapDown.index, ElEventPhase.rotationUpdate.index + 1)),
);

// 拖拽订阅独立更新，不计入点击识别条件。
final _discrete = _group(
  ElEventPhase.values.where(
    (phase) => phase.index < ElEventPhase.dragDown.index || phase.index > ElEventPhase.dragCancel.index,
  ),
);
