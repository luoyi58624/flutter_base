import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';

import 'panel.dart';

/// 单列、多列和级联滚轮各自按需构建。
List<ShowcaseItem> pickerShowcaseItems(bool mobile) => [
  ...ShowcaseItem.rows([
    ShowcaseItem((context) {
      final drink = useState(['茉莉花茶']);
      return ShowcasePanel(
        title: '单列选择',
        description: '滚动选择一项内容，禁用选项会自动跳过。',
        child: demoColumn([
          ElPicker<String>(
            modelValue: drink,
            semanticLabel: '选择饮品',
            columns: [
              [
                for (final label in ['温水', '茉莉花茶', '拿铁', '浓缩咖啡', '鲜榨橙汁', '牛奶'])
                  ElMenuOption(label, label, disabled: label == '浓缩咖啡'),
              ],
            ],
          ),
          demoHint(context, '当前饮品：${drink.value.first}'),
        ]),
      );
    }),
    ShowcaseItem((context) {
      final time = useState(['09', '30']);
      return ShowcasePanel(
        title: '独立多列',
        description: '每一列独立选择，再组合成完整业务值。',
        child: demoColumn([
          ElPicker<String>(
            modelValue: time,
            columnLabels: ['小时', '分钟'],
            columns: [
              [for (var hour = 7; hour <= 20; hour++) ElMenuOption('$hour'.padLeft(2, '0'), '$hour'.padLeft(2, '0'))],
              [
                for (final minute in ['00', '15', '30', '45']) ElMenuOption(minute, minute),
              ],
            ],
          ),
          demoHint(context, '预约时段：${time.value.join(':')}'),
        ]),
      );
    }),
  ], columns: mobile ? 1 : 2),
  ShowcaseItem((context) {
    final region = useState(['浙江', '杭州', '西湖区']);
    final regions = [
      ElMenuOption(
        '浙江',
        '浙江',
        children: [
          ElMenuOption('杭州', '杭州', children: [ElMenuOption('西湖区', '西湖区'), ElMenuOption('滨江区', '滨江区')]),
          ElMenuOption('宁波', '宁波', children: [ElMenuOption('海曙区', '海曙区'), ElMenuOption('鄞州区', '鄞州区')]),
        ],
      ),
      ElMenuOption(
        '江苏',
        '江苏',
        children: [
          ElMenuOption('南京', '南京', children: [ElMenuOption('玄武区', '玄武区'), ElMenuOption('秦淮区', '秦淮区')]),
          ElMenuOption('苏州', '苏州', children: [ElMenuOption('姑苏区', '姑苏区'), ElMenuOption('吴中区', '吴中区')]),
        ],
      ),
      ElMenuOption(
        '上海',
        '上海',
        children: [
          ElMenuOption('上海市', '上海市', children: [ElMenuOption('徐汇区', '徐汇区'), ElMenuOption('浦东新区', '浦东新区')]),
        ],
      ),
    ];
    return ShowcasePanel(
      title: '级联选择',
      description: '父级选项决定下一列内容，切换后自动保留有效选择。',
      child: demoColumn([
        Row(
          children: [
            Expanded(child: demoLabel(context, '配送地区')),
            demoHint(context, region.value.join(' / ')),
          ],
        ),
        ElPicker<String>(modelValue: region, options: regions, columnLabels: ['省份', '城市', '区县']),
        demoActions([
          demoHint(context, '也可以在底部面板中选择，确认后保存。'),
          ElButton(
            variant: .outline,
            child: '选择配送地区',
            onPressed: () async {
              final draft = ValueNotifier([...region.value]);
              final result = await el.dialog.show<List<String>>(
                context,
                placement: .bottom,
                title: '选择配送地区',
                showClose: false,
                child: HookBuilder(
                  builder: (context) {
                    useEffect(() => draft.dispose, []);
                    return Padding(
                      padding: .fromLTRB(20, 8, 20, 20),
                      child: ElPicker<String>(modelValue: draft, options: regions, columnLabels: ['省份', '城市', '区县']),
                    );
                  },
                ),
                footer: demoPopupActions(confirm: '确定', onConfirm: () => [...draft.value]),
              );
              // 路由退场仍会短暂保留编辑内容，模型在转场结束后释放。
              if (context.mounted && result != null) region.value = result;
            },
          ),
        ]),
      ]),
    );
  }),
];

/// 日期、时间和日历各自管理演示值。
List<ShowcaseItem> dateShowcaseItems() => [
  ShowcaseItem((context) {
    final now = useMemoized(DateTime.now);
    final min = DateTime(now.year - 1), max = DateTime(now.year + 2, 12, 31);
    final date = useState(DateTime(now.year, now.month, now.day));
    return ShowcasePanel(
      title: '日期选择',
      description: 'min 与 max 限制范围，年月变化后自动保留有效日期，也可放入底部面板确认。',
      child: demoColumn([
        Row(
          children: [
            Expanded(child: demoLabel(context, '选择日期')),
            Text(
              _dateText(date.value),
              style: TextStyle(color: context.elTheme.primary, fontSize: 14, fontWeight: .w600),
            ),
          ],
        ),
        ElDatePicker(modelValue: date, min: min, max: max, semanticLabel: '出发日期'),
        demoHint(context, '大小月与闰年自动联动，年月变化后保留有效日期。'),
        Divider(height: 1, color: context.elTheme.borderColor),
        demoActions([
          demoHint(context, '也可以在底部面板中选择，确认后保存。'),
          ElButton(
            variant: .outline,
            child: '修改出发日期',
            onPressed: () async {
              final draft = ValueNotifier(date.value);
              final result = await el.dialog.show<DateTime>(
                context,
                placement: .bottom,
                title: '选择出发日期',
                showClose: false,
                child: HookBuilder(
                  builder: (context) {
                    useEffect(() => draft.dispose, []);
                    return Padding(
                      padding: .fromLTRB(20, 8, 20, 20),
                      child: ElDatePicker(modelValue: draft, min: min, max: max, semanticLabel: '出发日期草稿'),
                    );
                  },
                ),
                footer: demoPopupActions(confirm: '确定', onConfirm: () => draft.value),
              );
              if (context.mounted && result != null) date.value = result;
            },
          ),
        ]),
      ], gap: 18),
    );
  }, anchor: 'control-dates'),
  ShowcaseItem((context) {
    final time = useState(Duration(hours: 9, minutes: 30));
    return ShowcasePanel(
      title: '时间选择',
      description: '通过 min、max 与 minuteStep 定义可选时段和分钟间隔。',
      child: demoColumn([
        Row(
          children: [
            Expanded(child: demoLabel(context, '预约时间')),
            Text(_timeText(time.value), style: TextStyle(color: context.elTheme.primary)),
          ],
        ),
        ElTimePicker(
          modelValue: time,
          min: Duration(hours: 9),
          max: Duration(hours: 18, minutes: 30),
          minuteStep: 15,
          semanticLabel: '预约时间',
        ),
        demoHint(context, '营业时段 09:00—18:30，每 15 分钟一个时刻。'),
      ]),
    );
  }),
  ShowcaseItem((context) {
    final precise = useState(Duration(hours: 1, minutes: 20, seconds: 30));
    return ShowcasePanel(
      title: '精确到秒',
      description: 'showSeconds 开启秒列，secondStep 控制秒间隔。',
      child: demoColumn([
        ElTimePicker(modelValue: precise, showSeconds: true, secondStep: 5, semanticLabel: '精确时间'),
        demoHint(context, '当前时间 ${_timeText(precise.value, true)} · 秒间隔为 5'),
      ]),
    );
  }),
  ShowcaseItem((context) {
    final now = useMemoized(DateTime.now);
    final min = DateTime(now.year - 1), max = DateTime(now.year + 2, 12, 31);
    final day = useState<DateTime?>(DateTime(now.year, now.month, now.day));
    return ShowcasePanel(
      title: '单日选择',
      description: 'Calendar 在月视图中选择日期，支持切换月份。',
      child: demoColumn([
        ElCalendar<DateTime?>(modelValue: day, min: min, max: max, semanticLabel: '行程日历'),
        demoHint(context, '点击日期进行选择，通过月份两侧的箭头切换月份。'),
      ]),
    );
  }),
  ShowcaseItem((context) {
    final now = useMemoized(DateTime.now);
    final min = DateTime(now.year - 1), max = DateTime(now.year + 2, 12, 31);
    final range = useState(<DateTime>[]);
    return ShowcasePanel(
      title: '日期范围与禁选',
      description: 'range 开启范围选择，disabledDate 控制不可选择的日期。',
      child: demoColumn([
        ElCalendar.range(
          modelValue: range,
          min: min,
          max: max,
          disabledDate: (date) => date.day == 13 || date.day == 23,
          semanticLabel: '日期范围',
        ),
        demoHint(context, '每月 13 日、23 日已被预约，范围不能跨过这些日期。'),
        if (range.value.isNotEmpty) demoHint(context, range.value.map(_dateText).join(' 至 ')),
      ]),
    );
  }),
];

String _dateText(DateTime value) =>
    '${value.year}-${'${value.month}'.padLeft(2, '0')}-${'${value.day}'.padLeft(2, '0')}';

String _timeText(Duration value, [bool seconds = false]) => [
  value.inHours,
  value.inMinutes % 60,
  if (seconds) value.inSeconds % 60,
].map((part) => '$part'.padLeft(2, '0')).join(':');
