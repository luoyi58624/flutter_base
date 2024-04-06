part of flutter_base;

/// 显示级联选择器弹窗
Future<List<Map<String, dynamic>>?> showCascaderPopup(
  BuildContext context, {
  String title = '请选择',
  String labelKey = 'label', // 展示名称关键字
  String valueKey = 'value', // 控制对象数组唯一选项关键字
  String childKey = 'children', // 用于控制下一级数据的字段
  bool autoClose = false, // 当用户选中没有子节点的数据时，是否自动关闭弹窗
  required List<Map<String, dynamic>> data, // 级联数据-树形数组，它必须包含指定的childKey
  // 选中的每一级数据，用于重新初始化，因为flutter中的弹窗是一个路由，
  // 路由关闭后数据会丢失，所以当你重新打开时需要传递之前选中的数据用于还原
  required List<Map<String, dynamic>> selectData,
}) async {
  return await showCupertinoModalBottomSheet<List<Map<String, dynamic>>>(
    context: context,
    builder: (context) => _CascaderPopupPage(
      title,
      data,
      selectData,
      labelKey,
      valueKey,
      childKey,
      autoClose,
    ),
  );
}

class _CascaderPopupPage extends StatefulWidget {
  const _CascaderPopupPage(
    this.title,
    this.data,
    this.selectData,
    this.labelKey,
    this.valueKey,
    this.childKey,
    this.autoClose,
  );

  final String title;
  final List<Map<String, dynamic>> data;
  final List<Map<String, dynamic>> selectData;
  final String labelKey;
  final String valueKey;
  final String childKey;
  final bool autoClose;

  @override
  State<_CascaderPopupPage> createState() => _CascaderPopupPageState();
}

class _CascaderPopupPageState extends State<_CascaderPopupPage> {
  List<Map<String, dynamic>> _data = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          Tooltip(
            message: '确定',
            child: IconButton(
              onPressed: () {
                Navigator.pop(context, _data);
              },
              icon: const Icon(Icons.check),
            ),
          )
        ],
      ),
      body: CascaderWidget(
        data: widget.data,
        selectData: widget.selectData,
        labelKey: widget.labelKey,
        valueKey: widget.valueKey,
        childKey: widget.childKey,
        onChanged: (value) {
          _data = value;
          if (widget.autoClose && DartUtil.isEmpty(_data.last[widget.childKey])) {
            Navigator.pop(context, _data);
          }
        },
      ),
    );
  }
}

/// 级联选择器
class CascaderWidget extends StatefulWidget {
  const CascaderWidget({
    super.key,
    required this.data,
    this.selectData,
    this.labelKey = 'label',
    this.valueKey = 'value',
    this.childKey = 'children',
    this.onChanged,
  });

  final List<Map<String, dynamic>> data;
  final List<Map<String, dynamic>>? selectData;
  final String labelKey;
  final String valueKey;
  final String childKey;
  final ValueChanged<List<Map<String, dynamic>>>? onChanged;

  @override
  State<CascaderWidget> createState() => _CascaderWidgetState();
}

class _CascaderWidgetState extends State<CascaderWidget> {
  // 所有分组标签列表集合，它是一个二维数组，每个数组包含当前索引下的标签列表数据
  List<List<Map<String, dynamic>>> allTabs = [];

  // 选中的每一级标签
  List<Map<String, dynamic>> selectedTabs = [];

  @override
  void initState() {
    super.initState();
    bool allowAddNullMap = true; // 是否允许新增待选择标签
    allTabs.add(widget.data);
    // 初始化选中的节点
    if (widget.selectData != null && widget.selectData!.isNotEmpty) {
      selectedTabs.addAll(widget.selectData!);
      for (int i = 0; i < selectedTabs.length; i++) {
        for (int j = 0; j < allTabs[i].length; j++) {
          if (allTabs[i][j][widget.valueKey] == selectedTabs[i][widget.valueKey]) {
            // 根据已选择的数据，添加每一屏TabView
            if (!DartUtil.isEmpty(allTabs[i][j][widget.childKey])) {
              allTabs.add((allTabs[i][j][widget.childKey] as List).cast<Map<String, dynamic>>());
            }
            // 如果选中的节点已经到了最后一级，同时所有节点下没有最后一级的子节点，
            // 说明用户已经选择完整个流程，这时，我们不允许在最后面新增空Map用于用户选择
            if (i == selectedTabs.length - 1 && DartUtil.isEmpty(allTabs[i][j][widget.childKey])) {
              allowAddNullMap = false;
            }
          }
        }
      }
    }
    if (allowAddNullMap) selectedTabs.add({});
  }

  /// firstIndex - tab的下标
  ///
  /// secondIndex - 每个tab下的数据下标
  void setSelectedValue(BuildContext context, firstIndex, secondIndex) {
    // 先获取当前所有的tabs的最大长度，从点击的节点开始，移除后续的内容，防止重复添加
    int endIndex = allTabs.length;
    selectedTabs.removeRange(firstIndex + 1, endIndex);
    allTabs.removeRange(firstIndex + 1, endIndex);
    // 设置当前点击的tab，如果它没有子节点，则直接调用setState更新页面
    selectedTabs[firstIndex] = allTabs[firstIndex][secondIndex];
    if (DartUtil.isEmpty(allTabs[firstIndex][secondIndex][widget.childKey])) {
      setState(() {});
    } else {
      // 追加一个新的空Map，待用户选择
      selectedTabs.add({});
      // 往所有tabs里追加子节点
      allTabs.add((allTabs[firstIndex][secondIndex][widget.childKey] as List).cast<Map<String, dynamic>>());
      setState(() {});
      // 延迟100毫秒进行跳转下一节点，因为调用setState进行页面更新需要一些时间
      Future.delayed(const Duration(milliseconds: 100), () {
        DefaultTabController.of(context).index = firstIndex + 1;
      });
    }
    if (widget.onChanged != null) {
      late List<Map<String, dynamic>> result;
      // 过滤掉用户未选择的数据，它是一个空Map
      if (selectedTabs.last.isEmpty) {
        result = selectedTabs.sublist(0, selectedTabs.length - 1);
      } else {
        result = selectedTabs;
      }
      widget.onChanged!(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: allTabs.length,
      initialIndex: allTabs.length - 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TabBar(
              isScrollable: true,
              indicatorSize: TabBarIndicatorSize.label,
              indicatorPadding: const EdgeInsets.symmetric(horizontal: -4),
              labelColor: Theme.of(context).primaryColor,
              tabs: [for (int i = 0; i < allTabs.length; i++) Tab(text: selectedTabs[i][widget.labelKey] ?? '请选择')]),
          Expanded(
            child: ScrollerRipperWidget(
              disabledRipper: true,
              child: ExtendedTabBarView(
                children: [
                  for (int i = 0; i < allTabs.length; i++)
                    ScrollerRipperWidget(
                      disabledRipper: true,
                      child: ListView.builder(
                        itemCount: allTabs[i].length,
                        itemBuilder: (context, index) => ListTile(
                          title: Text(allTabs[i][index][widget.labelKey]),
                          leading: Radio<String>(
                            value: selectedTabs[i][widget.valueKey] ?? '',
                            groupValue: allTabs[i][index][widget.valueKey],
                            onChanged: (value) {
                              setSelectedValue(context, i, index);
                            },
                          ),
                          trailing: DartUtil.isEmpty(allTabs[i][index][widget.childKey])
                              ? null
                              : const Icon(Icons.keyboard_arrow_right_outlined),
                          onTap: () {
                            setSelectedValue(context, i, index);
                          },
                        ),
                      ),
                    )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
