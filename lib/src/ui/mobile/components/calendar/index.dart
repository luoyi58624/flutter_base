import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../../../../../flutter.dart';
import '../../commons/icons.dart';
import '../../internal/common.dart';

DateTime _day(DateTime date) => DateTime(date.year, date.month, date.day);

/// 移动日历以七列自然布局展示单日和范围，禁选规则同时约束端点与区间。
Widget calendarBuilder<D>(BuildContext context, ElCalendar<D> c) => _Calendar(c);

class _Calendar<D> extends HookWidget {
  const _Calendar(this.c);
  final ElCalendar<D> c;
  @override
  Widget build(BuildContext context) {
    final t = context.elTheme;
    final selected = c.isRange
        ? c.currentValue as List<DateTime>
        : [if (c.currentValue != null) c.currentValue as DateTime];
    final initial = c.month ?? (selected.isEmpty ? DateTime.now() : selected.first);
    final month = useState(DateTime(initial.year, initial.month));
    useEffect(() {
      if (c.month != null) month.value = DateTime(c.month!.year, c.month!.month);
      return null;
    }, [c.month]);
    bool disabled(DateTime date) =>
        c.disabled ||
        (c.min != null && date.isBefore(_day(c.min!))) ||
        (c.max != null && date.isAfter(_day(c.max!))) ||
        c.disabledDate?.call(date) == true;
    void move(DateTime date) {
      month.value = DateTime(date.year, date.month);
      c.onMonthChanged?.call(month.value);
    }

    void select(DateTime date) {
      if (disabled(date)) return;
      if (c.isRange) {
        if (selected.length != 1) {
          c.currentValue = [date] as D;
          return;
        }
        final start = date.isBefore(selected.first) ? date : _day(selected.first);
        final end = date.isBefore(selected.first) ? _day(selected.first) : date;
        // 不允许用两个可选端点跨过已预约日期。
        for (var cursor = start; !cursor.isAfter(end); cursor = DateTime(cursor.year, cursor.month, cursor.day + 1)) {
          if (disabled(cursor)) {
            c.currentValue = [date] as D;
            return;
          }
        }
        c.currentValue = [start, end] as D;
      } else {
        c.currentValue = date as D;
      }
      if (date.month != month.value.month) move(date);
      c.onSelect?.call(c.currentValue);
    }

    final offset = (month.value.weekday - c.firstDayOfWeek + 7) % 7;
    final days = DateTime(month.value.year, month.value.month + 1, 0).day;
    final count = ((days + offset + 6) ~/ 7) * 7;
    return ElView(
      style: c.style,
      semantics: ElSemantics(container: true, label: c.semanticLabel),
      child: Align(
        alignment: .centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: .min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: ElView(
                      style: ElStyle(fontSize: 17, fontWeight: .w600, color: t.textColor),
                      child: '${month.value.year}年${month.value.month}月',
                    ),
                  ),
                  _nav(
                    context,
                    '上个月',
                    ElView(
                      style: ElStyle(transform: ElTransform.rotate(math.pi)),
                      child: ElMobileIcons.chevronRight,
                    ),
                    () => move(DateTime(month.value.year, month.value.month - 1)),
                  ),
                  _nav(context, '回到今天', const Text('今天', style: TextStyle(fontSize: 12)), () => move(DateTime.now())),
                  _nav(
                    context,
                    '下个月',
                    ElMobileIcons.chevronRight,
                    () => move(DateTime(month.value.year, month.value.month + 1)),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  for (var i = 0; i < 7; i++)
                    Expanded(
                      child: ElView(
                        style: ElStyle(height: 28, alignment: .center, fontSize: 12, color: t.textSecondary),
                        child: ['一', '二', '三', '四', '五', '六', '日'][(c.firstDayOfWeek - 1 + i) % 7],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              for (var row = 0; row < count ~/ 7; row++)
                Row(
                  children: [
                    for (var column = 0; column < 7; column++)
                      Expanded(
                        child: Builder(
                          builder: (context) {
                            final date = DateTime(month.value.year, month.value.month, row * 7 + column - offset + 1);
                            final chosen = selected.any((value) => _day(value) == date);
                            final within =
                                c.isRange &&
                                selected.length == 2 &&
                                !date.isBefore(_day(selected.first)) &&
                                !date.isAfter(_day(selected.last));
                            final outside = date.month != month.value.month, blocked = disabled(date);
                            return ElView(
                              style: ElStyle(
                                height: 42,
                                alignment: .center,
                                backgroundColor: within ? t.primary.withValues(alpha: .10) : null,
                              ),
                              child: ActionView(
                                label: '${date.year}-${date.month}-${date.day}',
                                selected: chosen,
                                disabled: blocked,
                                onActivate: (_) => select(date),
                                style: ElStyle(
                                  width: 36,
                                  height: 36,
                                  alignment: .center,
                                  borderRadius: .circular(12),
                                  fontSize: 14,
                                  fontWeight: chosen ? .w600 : .w400,
                                  color: blocked
                                      ? t.textDisabled
                                      : chosen
                                      ? t.primaryText
                                      : outside
                                      ? t.gray
                                      : t.textColor,
                                  backgroundColor: chosen ? t.primary : null,
                                  onTap: ElStyle(backgroundColor: chosen ? t.primary : t.press),
                                  transition: const [ElTransition.all(Duration(milliseconds: 120))],
                                ),
                                child: Text('${date.day}'),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _nav(BuildContext context, String label, Widget child, VoidCallback action) => ActionView(
    disabled: c.disabled,
    label: label,
    onActivate: (_) => action(),
    style: ElStyle(
      minWidth: 32,
      height: 32,
      padding: const .symmetric(horizontal: 6),
      alignment: .center,
      iconSize: 18,
      color: context.elTheme.textSecondary,
      iconColor: context.elTheme.textSecondary,
      borderRadius: .circular(8),
    ),
    child: child,
  );
}
