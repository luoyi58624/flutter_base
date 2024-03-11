part of flutter_base;

class FlexWrapWidget extends StatelessWidget {
  /// 多行flex布局，效果类似于GridView，但GridView只能通过宽高比指定每个元素的高度
  const FlexWrapWidget({
    Key? key,
    required this.children,
    required this.span,
    this.rowSpacing,
    this.columnSpacing,
    this.padding,
    this.rowCrossAxisAlignment = CrossAxisAlignment.center,
  }) : super(key: key);

  final List<Widget> children;

  /// 一行显示多少个
  final int span;

  /// 每一行之间的间距，最后一行不生效
  final double? rowSpacing;

  /// 每一列之间的间距，只会作用于元素之间
  final double? columnSpacing;

  /// flex盒子内边距
  final EdgeInsetsGeometry? padding;

  /// 每一行的对齐方式，默认居中
  final CrossAxisAlignment rowCrossAxisAlignment;

  // 添加每一行Row，它们会在每一行之间追加 rowSpacing
  void _addRow(columnWidget, int i) {
    List<Widget> row = [];
    List.generate(
      span,
      (index) {
        row.add(Expanded(
          child: Center(child: children[i * span + index]),
        ));
        if (index != span - 1) {
          row.add(SizedBox(
            width: columnSpacing ?? 0,
          ));
        }
      },
    );
    columnWidget.add(Row(
      crossAxisAlignment: rowCrossAxisAlignment,
      children: row,
    ));
    columnWidget.add(
      SizedBox(
        height: rowSpacing ?? 0,
      ),
    );
  }

  // 添加最后一行，根据 span - surplus 来填充空白widget
  void _addLastRow(columnWidget, int i, int surplus) {
    List<Widget> lastRow = [];
    List.generate(surplus, (index) {
      lastRow.add(Expanded(
        child: Center(child: children[i * span + index]),
      ));
      if (index != span - 1) {
        lastRow.add(SizedBox(width: columnSpacing ?? 0));
      }
    });
    List.generate(span - surplus, (index) {
      lastRow.add(const Expanded(
        child: SizedBox(),
      ));
      if (index != span - surplus - 1) {
        lastRow.add(SizedBox(width: columnSpacing ?? 0));
      }
    });
    columnWidget.add(Row(
      crossAxisAlignment: rowCrossAxisAlignment,
      children: lastRow,
    ));
  }

  @override
  Widget build(BuildContext context) {
    // addRow可执行次数，如果没有剩余，循环次数将减一
    int num = (children.length / span).truncateToDouble().toInt();
    // 剩余元素个数，空白元素将使用SizeBox填充
    int surplus = children.length % span;
    List<Widget> columnWidget = [];
    if (children.isEmpty) {
      columnWidget = [];
    } else if (surplus == 0) {
      // 若没有剩余，则最后一行widget执行addLastRow方法
      for (int i = 0; i < num - 1; i++) {
        _addRow(columnWidget, i);
      }
      _addLastRow(columnWidget, num - 1, span);
    } else {
      for (int i = 0; i < num; i++) {
        _addRow(columnWidget, i);
      }
      _addLastRow(columnWidget, num, surplus);
    }
    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: columnWidget,
      ),
    );
  }
}
