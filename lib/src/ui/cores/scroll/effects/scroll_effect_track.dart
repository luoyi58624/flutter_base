// ignore_for_file: prefer_initializing_formals
part of '../virtual/virtual_pipeline.dart';

/// 效果自由度自身的单位，输入行程另外通过 pixelsPerUnit 明确换算。
enum ElScrollEffectUnit {
  /// 逻辑像素。
  logicalPixels,

  /// 无量纲进度。
  progress,
}

/// 当前 client 声明的有限效果自由度，不绑定 RenderObject 或样式补丁。
@immutable
final class ElScrollEffectTrack {
  /// 声明稳定身份、值域及正常 State 更新入口；不参与输入时 pixelsPerUnit 为零。
  const ElScrollEffectTrack({
    required this.effectId,
    required this.minValue,
    required this.maxValue,
    required double Function() readValue,
    required ValueChanged<double> updateValue,
    this.unit = ElScrollEffectUnit.logicalPixels,
    this.pixelsPerUnit = 0,
  }) : _readValue = readValue,
       _updateValue = updateValue;

  /// 在所属 client 生命周期内稳定且唯一的效果身份。
  final Object effectId;

  /// 自由度的最小值。
  final double minValue;

  /// 自由度的最大值。
  final double maxValue;

  /// 当前值的物理或进度单位。
  final ElScrollEffectUnit unit;

  /// 当前值每增加一单位所接受的标准化输入距离；零表示仅参与效果动画。
  final double pixelsPerUnit;
  final double Function() _readValue;
  final ValueChanged<double> _updateValue;

  /// 读取实际 State 的当前值，越界或非有限值明确失败。
  double get value {
    final result = _readValue();
    _validateValue(result);
    return result;
  }

  /// 在合法输入或动画阶段更新最小效果 State。
  void updateValue(double value) {
    _validateValue(value);
    _updateValue(value);
  }

  void _validate() {
    if (!minValue.isFinite ||
        !maxValue.isFinite ||
        maxValue < minValue ||
        !(maxValue - minValue).isFinite ||
        !pixelsPerUnit.isFinite ||
        pixelsPerUnit < 0 ||
        !((maxValue - minValue) * pixelsPerUnit).isFinite) {
      throw FlutterError('效果 $effectId 必须提供有限且有序的值域，以及非负有限的 pixelsPerUnit。');
    }
    _validateValue(_readValue());
  }

  void _validateValue(double value) {
    if (!value.isFinite || value < minValue || value > maxValue) {
      throw FlutterError('效果 $effectId 的当前值 $value 超出已声明值域 [$minValue, $maxValue]。');
    }
  }
}

typedef _EffectTrackBinding = ({
  _ScrollMixinClient client,
  _ScrollMixinClientRegistration registration,
  ElScrollEffectTrack track,
});
