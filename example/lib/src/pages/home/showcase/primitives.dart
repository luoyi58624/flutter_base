import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_base/mobile.dart';

import 'panel.dart';

/// 提示、分隔线、进度、通知与步骤的完整展示。
class PrimitivesShowcase extends StatelessWidget {
  /// 创建基础反馈示例。
  const PrimitivesShowcase({super.key});
  @override
  Widget build(BuildContext context) => showcaseColumn([
    ShowcaseGrid(children: [_Tooltips(), _Dividers()]),
    ShowcaseMotion(child: _Progress()),
    ShowcaseMotion(child: _Playback()),
    _Sliders(),
    _Notices(),
    _Steps(),
  ], gap: 22);
}

class _Tooltips extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ShowcasePanel(
    title: '文字提示',
    description: '悬停、点击或长按时展示补充信息，支持不同方向。',
    child: demoColumn([
      demoActions([
        for (final direction in [
          ('上方', ElPlacement.top),
          ('右侧', ElPlacement.right),
          ('下方', ElPlacement.bottom),
          ('左侧', ElPlacement.left),
        ])
          ElTooltip(
            placement: direction.$2,
            content: direction.$1 == '右侧'
                ? Row(
                    mainAxisSize: .min,
                    spacing: 8,
                    children: [
                      Text('邀请代码 MY-UI'),
                      ElButton(
                        variant: .text,
                        child: '复制',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: 'MY-UI'));
                          demoNotify(context, '邀请代码已复制');
                        },
                      ),
                    ],
                  )
                : '${direction.$1}的补充说明',
            child: ElButton(variant: .outline, child: direction.$1),
          ),
      ], gap: 8),
      demoActions([
        for (final item in [('收藏', ElMobileIcons.heart), ('分享', ElMobileIcons.share), ('设置', ElMobileIcons.sliders)])
          ElTooltip(
            content: item.$1,
            child: ElButton(
              variant: .text,
              semanticLabel: item.$1,
              style: ElStyle(
                width: 44,
                height: 44,
                padding: .zero,
                backgroundColor: context.elTheme.fill,
                borderRadius: .circular(13),
              ),
              child: item.$2,
            ),
          ),
      ]),
      demoHint(context, '提示内容可以包含可复制的信息与操作。'),
    ], gap: 18),
  );
}

class _Dividers extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    Widget divider(String label, {bool dashed = false}) => Row(
      spacing: 12,
      children: [
        Expanded(
          child: ElView(
            style: ElStyle(
              height: 1,
              border: ElBorder.only(
                borderBottom: ElBorderSide(
                  borderColor: context.elTheme.borderColor,
                  borderStyle: dashed ? .dashed : .solid,
                ),
              ),
            ),
          ),
        ),
        demoHint(context, label),
        Expanded(
          child: ElView(
            style: ElStyle(
              height: 1,
              border: ElBorder.only(
                borderBottom: ElBorderSide(
                  borderColor: context.elTheme.borderColor,
                  borderStyle: dashed ? .dashed : .solid,
                ),
              ),
            ),
          ),
        ),
      ],
    );
    return ShowcasePanel(
      title: '分隔线',
      description: '用轻量分隔组织信息，保留自然的阅读节奏。',
      child: demoColumn([
        Row(
          children: [
            Expanded(child: demoLabel(context, '我的收件箱')),
            ElTag(child: '3 条未读'),
          ],
        ),
        divider('今天'),
        ElListTile(title: '同步已经完成', subtitle: '所有内容都已更新到最新', leading: ElMobileIcons.cloud, trailing: null),
        ElListTile(title: '新的灵感等待查看', subtitle: '收集一点日常的好风景', leading: ElMobileIcons.spark, trailing: null),
        divider('更早', dashed: true),
        demoActions([
          for (final label in ['帮助中心', '意见反馈', '关于我们'])
            ElButton(variant: .link, child: label, onPressed: () => demoNotify(context, label)),
        ], gap: 12),
      ], gap: 14),
    );
  }
}

class _Progress extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final value = useState(64.0), running = useState(false);
    final active = TickerMode.valuesOf(context).enabled;
    useEffect(() {
      if (!running.value || !active) return null;
      final timer = Timer.periodic(Duration(milliseconds: 350), (_) {
        value.value = (value.value + 4).clamp(0, 100);
        if (value.value >= 100) running.value = false;
      });
      return timer.cancel;
    }, [running.value, active]);
    return ShowcasePanel(
      title: '任务进度',
      description: '线性与圆环进度共同展示任务状态，也支持不确定进度。',
      child: demoColumn([
        ShowcaseGrid(
          gap: 30,
          children: [
            demoColumn([
              Row(
                children: [
                  Expanded(child: demoLabel(context, '正在同步内容')),
                  Text(
                    '${value.value.round()}%',
                    style: TextStyle(color: context.elTheme.primary, fontSize: 24, fontWeight: .w600),
                  ),
                ],
              ),
              ElProgress(value: value.value, showText: false),
              demoActions([
                ElButton(
                  child: running.value
                      ? '暂停同步'
                      : value.value >= 100
                      ? '重新开始'
                      : '继续同步',
                  onPressed: () {
                    if (value.value >= 100) value.value = 0;
                    running.value = !running.value;
                  },
                ),
                ElButton(
                  variant: .text,
                  child: '重置进度',
                  onPressed: () {
                    running.value = false;
                    value.value = 64;
                  },
                ),
              ]),
              ElProgress(value: 100, status: .success),
              ElProgress(value: 72, status: .warning),
              ElProgress(value: 38, status: .error),
            ], gap: 20),
            demoActions([
              Column(
                mainAxisSize: .min,
                spacing: 12,
                children: [
                  ElProgress.circle(value: value.value, style: ElStyle(width: 104, height: 104)),
                  demoHint(context, '同步进度'),
                ],
              ),
              Column(
                mainAxisSize: .min,
                spacing: 12,
                children: [
                  ElProgress.circle(style: ElStyle(width: 104, height: 104)),
                  demoHint(context, '正在处理'),
                ],
              ),
              Column(
                mainAxisSize: .min,
                spacing: 12,
                children: [
                  ElProgress.circle(
                    value: 6,
                    max: 12,
                    style: ElStyle(width: 104, height: 104),
                    textBuilder: (_, value) =>
                        Text('${value.value?.round() ?? 0} / 12', style: TextStyle(fontSize: 14)),
                  ),
                  demoHint(context, '自定义读数'),
                ],
              ),
            ], gap: 24),
          ],
        ),
        ShowcaseMotion(
          child: RepaintBoundary(child: ElProgress(showText: false, semanticLabel: '等待服务器响应')),
        ),
        demoHint(context, '无法预估完成时间时，用不确定进度表达正在处理。'),
      ], gap: 22),
    );
  }
}

class _Playback extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final position = useState(36.0), buffer = useState(72.0), playing = useState(false);
    final active = TickerMode.valuesOf(context).enabled;
    useEffect(() {
      if (!playing.value || !active) return null;
      final timer = Timer.periodic(Duration(milliseconds: 500), (_) {
        buffer.value = (buffer.value + 2).clamp(0, 100);
        position.value = (position.value + 1).clamp(0, 100);
        if (position.value >= 100) playing.value = false;
      });
      return timer.cancel;
    }, [playing.value, active]);
    final seconds = (position.value * 3).round(), elapsed = '${seconds ~/ 60}:${'${seconds % 60}'.padLeft(2, '0')}';
    return ShowcasePanel(
      title: '播放与缓冲',
      description: 'buffer 表示已缓冲进度。滑块可以拖动定位，Progress 展示对应的只读进度。',
      child: ShowcaseGrid(
        gap: 36,
        children: [
          demoColumn([
            Row(
              children: [
                Expanded(
                  child: demoColumn([demoLabel(context, '周末的好风景'), demoHint(context, '模拟播放 · 拖动调整播放位置')], gap: 5),
                ),
                demoHint(context, '$elapsed / 5:00'),
              ],
            ),
            ElSlider<double>(
              modelValue: position,
              buffer: buffer.value,
              label: '播放进度',
              startLabel: elapsed,
              endLabel: '5:00',
              onChanged: (value) {
                if (value > buffer.value) buffer.value = value;
              },
            ),
            demoActions([
              ElButton(
                child: playing.value ? '暂停播放' : '播放',
                onPressed: () {
                  if (position.value >= 100) position.value = 0;
                  playing.value = !playing.value;
                },
              ),
              ElButton(
                variant: .outline,
                child: '继续缓冲',
                disabled: buffer.value >= 100,
                onPressed: () => buffer.value = (buffer.value + 12).clamp(0, 100),
              ),
              ElButton(
                variant: .text,
                child: '重置',
                onPressed: () {
                  playing.value = false;
                  position.value = 36;
                  buffer.value = 72;
                },
              ),
            ]),
          ]),
          demoColumn([
            Row(
              children: [
                Expanded(child: demoHint(context, '相同样式的只读进度')),
                demoHint(context, '已缓冲 ${buffer.value.round()}%'),
              ],
            ),
            ElProgress(value: position.value, buffer: buffer.value, showText: false),
            demoActions([demoHint(context, '● 已播放'), demoHint(context, '● 已缓冲'), demoHint(context, '○ 剩余')], gap: 18),
          ], gap: 24),
        ],
      ),
    );
  }
}

class _Sliders extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final stepped = useState(50.0),
        temperature = useState(20.0),
        range = useState([20.0, 70.0]),
        volume = useState(36.0);
    return showcaseColumn([
      ShowcaseGrid(
        gap: 32,
        children: [
          ShowcasePanel(
            title: '按步长生成刻度',
            description: 'step 设置调整间隔，marks 按步长生成刻度。',
            child: demoColumn([
              ElSlider<double>(modelValue: stepped, label: '显示强度', step: 10, marks: true),
              demoHint(context, '每 10 调整一档，悬停或拖动时显示当前值。', size: 13),
            ]),
          ),
          ShowcasePanel(
            title: '仅选择指定刻度',
            description: 'step 设为 null，使用 marks 指定允许选择的值与文案。',
            child: demoColumn([
              ElSlider<double>(
                modelValue: temperature,
                label: '适宜温度',
                step: null,
                unit: '°C',
                marks: [
                  for (final value in [0.0, 20.0, 37.0, 100.0]) ElSliderMark(value: value, label: '${value.round()}°C'),
                ],
              ),
              demoHint(context, '拖动连续跟手，按相邻刻度中点预览；触屏抬起后提交，纵向滚动不改值。', size: 13),
            ]),
          ),
          ShowcasePanel(
            title: '双滑块范围',
            description: '数组值表示范围，两个滑块分别控制上下限。',
            child: demoColumn([
              ElSlider.range(
                modelValue: range,
                label: '筛选范围',
                step: 5,
                marks: true,
                startLabel: '0%',
                endLabel: '100%',
              ),
              demoHint(context, '拖动最近的端点，交叉后自动切换上下限，范围值始终有序。', size: 13),
            ]),
          ),
          ShowcasePanel(
            title: '常显数值',
            description: 'valueLabelDisplay 设置为 on，始终显示当前数值提示。',
            child: ElSlider<double>(modelValue: volume, label: '预设音量', valueLabelDisplay: .on),
          ),
        ],
      ),
      ShowcasePanel(
        title: '提示箭头',
        description: '默认箭头指向目标，也可以使用不带箭头的简洁面板。',
        child: demoActions([
          ElButton(
            variant: .text,
            child: '重置示例',
            onPressed: () {
              stepped.value = 50;
              temperature.value = 20;
              range.value = [20, 70];
              volume.value = 36;
            },
          ),
          ElTooltip(
            arrow: false,
            content: '圆角面板，简洁的文字提示',
            child: ElButton(variant: .outline, child: '无箭头提示'),
          ),
          ElTooltip(
            placement: .bottom,
            content: '提示会随目标位置自动调整',
            child: ElButton(variant: .outline, child: '默认箭头'),
          ),
        ], gap: 12),
      ),
    ], gap: 22);
  }
}

class _Notices extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final visible = useState(true);
    return ShowcasePanel(
      title: '通知条',
      description: '信息、成功、警告与错误，为状态提供清晰反馈。',
      child: demoColumn([
        ElAlert(modelValue: visible, title: '有新内容可用', description: '新的灵感已经准备好，刷新后即可查看。', closable: true),
        ElAlert(type: .success, title: '同步完成', description: '所有内容已经安全保存。'),
        ElAlert(
          type: .warning,
          title: '存储空间即将用满',
          description: demoActions([
            demoHint(context, '清理不再需要的内容，为新的灵感留出空间。'),
            ElButton(variant: .link, type: .warning, child: '管理空间', onPressed: () => demoNotify(context, '已打开存储管理')),
          ]),
        ),
        ElAlert(type: .error, title: '暂时无法连接', description: '请检查网络连接，稍后再试。'),
        Align(
          alignment: .centerLeft,
          child: ElButton(
            variant: .text,
            disabled: visible.value,
            child: '恢复通知',
            onPressed: () => visible.value = true,
          ),
        ),
      ], gap: 14),
    );
  }
}

class _Steps extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final step = useState(1), error = useState(false);
    return ShowcasePanel(
      title: '步骤条',
      description: '清楚展示当前进度，支持横向、纵向与异常状态。',
      child: demoColumn([
        ElSteps(
          modelValue: step,
          interactive: true,
          status: error.value ? .error : .process,
          children: [
            ElStep(title: '选择内容', description: '准备需要同步的资料'),
            ElStep(title: '确认信息', description: '检查内容和设置'),
            ElStep(title: '开始同步', description: '稍等片刻'),
            ElStep(title: '完成', description: '继续新的灵感'),
          ],
        ),
        demoActions([
          ElButton(variant: .outline, disabled: step.value <= 0, child: '上一步', onPressed: () => step.value--),
          ElButton(disabled: step.value >= 3, child: '下一步', onPressed: () => step.value++),
          ElButton(variant: .text, child: error.value ? '恢复进行中' : '模拟错误', onPressed: () => error.value = !error.value),
        ]),
        Divider(color: context.elTheme.borderColor),
        ElSteps(
          value: 1,
          vertical: true,
          children: [
            ElStep(title: '订单已提交', description: '我们已经收到你的内容'),
            ElStep(title: '正在处理', description: '内容正在同步，请稍等片刻'),
            ElStep(title: '完成', description: '可以在其他设备继续查看'),
          ],
        ),
      ], gap: 24),
    );
  }
}
