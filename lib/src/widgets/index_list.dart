part of flutter_base;

/// 继承分组序号实例
class _IndexListDataModel extends ISuspensionBean {
  final String tagIndex; // A-Z标签
  final LabelModel data;
  bool selected; // 多选情况下是否选中该项
  bool disabledUpdate; // 是否禁止更新该值

  _IndexListDataModel(
    this.tagIndex,
    this.data,
    this.selected,
    this.disabledUpdate,
  );

  /// 实现getSuspensionTag方法供azlistview获取当前标签索引
  @override
  String getSuspensionTag() {
    return tagIndex;
  }
}

/// 构建A-Z索引列表的组件，基于azlistview
class IndexListWidget extends StatefulWidget {
  /// 单选构造器
  const IndexListWidget(
    this.listData, {
    super.key,
    this.topListData,
    this.initValue,
    this.scrollToSelected = true,
    this.topTag = '↑',
    this.onTap,
  })  : multiple = false,
        initListValue = null,
        initDisabledUpdateListValue = null,
        excludeDisabledData = false,
        onChanged = null;

  /// 多选构造器
  const IndexListWidget.multiple(
    this.listData, {
    super.key,
    this.topListData,
    this.initListValue,
    this.initDisabledUpdateListValue,
    this.excludeDisabledData = false,
    this.scrollToSelected = true,
    this.topTag = '↑',
    this.onTap,
    this.onChanged,
  })  : multiple = true,
        initValue = null;

  /// 是否支持多选
  final bool multiple;

  /// 列表数据
  final List<LabelModel> listData;

  /// 顶部数据
  final List<LabelModel>? topListData;

  /// 单选模式下初始选中的数据，LabelModel->value
  final String? initValue;

  /// 多选模式下初始选中的数据，LabelModel->value
  final List<String>? initListValue;

  /// 初始化禁止更新的列表数据，仅限多选
  final List<String>? initDisabledUpdateListValue;

  /// 返回新数据时是否排除禁止更新的value，仅限多选
  final bool excludeDisabledData;

  /// 是否自动滚动到选中的位置，如果是多选，则滚动到第一个值
  final bool scrollToSelected;

  /// 顶部标签
  final String topTag;

  /// 自定义点击事件，多选模式下，内部会先触发复选框选中事件，再触发自定义onChanged事件，最后触发点击事件；
  ///
  /// 单选模式下，如果onTap==null，则默认触发路由返回事件(携带选中的数据)，如果你希望禁止路由返回操作，请定义onTap。
  final void Function(LabelModel data)? onTap;

  /// 选中的值变化，仅限多选模式，单选模式需要监听数据使用onTap即可
  final ValueChanged<List<LabelModel>>? onChanged;

  @override
  State<IndexListWidget> createState() => _IndexListWidgetState();
}

class _IndexListWidgetState<T> extends State<IndexListWidget> {
  late ItemScrollController itemScrollController = ItemScrollController();
  List<_IndexListDataModel> tagList = []; // 标签信息，包含 A-Z、# 等标签
  List<String> indexList = []; // 提取A-Z索引数组

  @override
  void initState() {
    super.initState();
    loadIndexListData();
  }

  /// 加载索引列表数据
  void loadIndexListData() {
    List<_IndexListDataModel> topTagList = [];
    tagList = [];
    if (widget.topListData != null) {
      for (var e in widget.topListData!) {
        topTagList.add(_IndexListDataModel(
          widget.topTag,
          e,
          getSelectedStatus(e),
          getDisabledUpdateStatus(e),
        ));
      }
    }
    // 设置禁止更新的数据
    if (!DartUtil.isEmpty(widget.initDisabledUpdateListValue)) {}
    for (int i = 0; i < widget.listData.length; i++) {
      // 获取用户名拼音
      String pinyin = PinyinHelper.getPinyinE(widget.listData[i].label);
      String tag = pinyin.substring(0, 1).toUpperCase();
      bool selected = getSelectedStatus(widget.listData[i]);
      bool disabledUpdate = getDisabledUpdateStatus(widget.listData[i]);
      // 添加将A-Z开头的用户名首字母，对于非A-Z开头的用户名一律丢到#分组
      if (RegExp("[A-Z]").hasMatch(tag)) {
        tagList.add(_IndexListDataModel(
          tag,
          widget.listData[i],
          selected,
          disabledUpdate,
        ));
      } else {
        tagList.add(_IndexListDataModel(
          '#',
          widget.listData[i],
          selected,
          disabledUpdate,
        ));
      }
    }
    // 对加入的A-Z进行排序
    SuspensionUtil.sortListBySuspensionTag(tagList);
    // 往排好序的标签列表插入顶部标签数据
    tagList.insertAll(0, topTagList);
    // 设置悬停状态
    SuspensionUtil.setShowSuspensionStatus(tagList);
    // 获取纯标签
    indexList = SuspensionUtil.getTagIndexList(tagList);
    setState(() {});
    if (widget.scrollToSelected) {
      int justIndex = 0;
      for (int i = 0; i < tagList.length; i++) {
        if (tagList[i].selected == true) {
          justIndex = i;
          if (justIndex > 0) {
            justIndex--;
          }
          break;
        }
      }
      if (widget.listData.isNotEmpty) {
        Future.delayed(const Duration(milliseconds: 50), () {
          itemScrollController.jumpTo(index: justIndex);
        });
      }
    }
  }

  void selectData(_IndexListDataModel item) {
    if (widget.multiple) {
      setState(() {
        item.selected = !item.selected;
      });
      if (widget.onChanged != null) {
        List<LabelModel> dataList = [];
        for (var item in tagList) {
          if (item.selected && !item.disabledUpdate) {
            dataList.add(item.data);
          }
        }
        widget.onChanged!(dataList);
      }
      if (widget.onTap != null) {
        widget.onTap!(item.data);
      }
    } else {
      if (widget.onTap == null) {
        if (DartUtil.isEmpty(item.data.value)) {
          ToastUtil.showToast('该数据存在问题！');
        } else {
          Navigator.pop(context, item.data);
        }
      } else {
        for (var item in tagList) {
          if (item.selected == true) {
            item.selected = false;
            break;
          }
        }
        item.selected = true;
        setState(() {});
        widget.onTap!(item.data);
      }
    }
  }

  /// 获取是否选中此数据状态
  bool getSelectedStatus(LabelModel data) {
    bool selected = false;
    if (widget.multiple) {
      if (!DartUtil.isEmpty(widget.initListValue)) {
        selected =
            DartUtil.listContains(widget.initListValue!, (element) => DartUtil.compareString(element, data.value));
      }
      if (!DartUtil.isEmpty(widget.initDisabledUpdateListValue)) {
        selected = DartUtil.listContains(
            widget.initDisabledUpdateListValue!, (element) => DartUtil.compareString(element, data.value));
      }
    } else {
      selected = DartUtil.compareString(widget.initValue ?? '', data.value);
    }
    return selected;
  }

  /// 获取禁止更新此数据状态
  bool getDisabledUpdateStatus(LabelModel data) {
    if (widget.multiple) {
      if (DartUtil.isEmpty(widget.initDisabledUpdateListValue)) {
        return false;
      } else {
        bool flag = false;
        for (var i in widget.initDisabledUpdateListValue!) {
          if (i == data.value) {
            flag = true;
            break;
          }
        }
        return flag;
      }
    } else {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AzListView(
      itemScrollController: itemScrollController,
      data: tagList,
      itemCount: tagList.length,
      indexBarData: indexList,
      itemBuilder: (BuildContext context, int index) {
        var item = tagList[index];
        return ListTile(
          onTap: item.disabledUpdate
              ? null
              : () {
                  selectData(item);
                },
          leading: widget.multiple
              ? Checkbox(
                  value: item.selected,
                  onChanged: item.disabledUpdate
                      ? null
                      : (value) {
                          selectData(item);
                        })
              : Radio<bool>(
                  value: item.selected,
                  groupValue: true,
                  toggleable: true,
                  onChanged: (value) {
                    selectData(item);
                  },
                ),
          title: Text(
            item.data.label,
            style: const TextStyle(fontSize: 16),
          ),
        );
      },
      susItemBuilder: (BuildContext context, int index) {
        var item = tagList[index];
        if (widget.topTag == item.getSuspensionTag()) {
          return Container();
        }
        return Container(
          width: MediaQuery.of(context).size.width,
          height: 40,
          padding: const EdgeInsets.only(left: 16),
          color: ColorUtil.dynamicColor(Colors.grey.shade300, Colors.grey.shade700, context),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              item.getSuspensionTag(),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
      indexBarOptions: const IndexBarOptions(
        hapticFeedback: true,
        needRebuild: true,
        ignoreDragCancel: true,
        selectTextStyle: TextStyle(fontSize: 12, color: Colors.white),
        selectItemDecoration: BoxDecoration(shape: BoxShape.circle, color: Colors.green),
        indexHintWidth: 120 / 2,
        indexHintHeight: 100 / 2,
        indexHintAlignment: Alignment.centerRight,
        indexHintOffset: Offset(-20, 0),
      ),
    );
  }
}
