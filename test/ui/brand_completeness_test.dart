import 'package:flutter_base/desktop.dart';
import 'package:flutter_base/src/ui/mobile/components/builders.dart';
import 'package:flutter_test/flutter_test.dart';

/// 品牌默认表除已知缺口外不得留空；缺口清单只减不增，新增组件必须两端登记实现。
void main() {
  test('桌面默认表只缺已知项', () {
    const builders = ElementPlusThemeData();
    final gaps = {
      'checkbox': builders.checkboxBuilder,
      'radio': builders.radioBuilder,
      'card': builders.cardBuilder,
      'loadingIndicator': builders.loadingIndicatorBuilder,
      'listTile': builders.listTileBuilder,
      'listTileGroup': builders.listTileGroupBuilder,
      'progress': builders.progressBuilder,
      'slider': builders.sliderBuilder,
      'skeleton': builders.skeletonBuilder,
      'steps': builders.stepsBuilder,
      'step': builders.stepBuilder,
      'avatar': builders.avatarBuilder,
      'calendar': builders.calendarBuilder,
      'collapse': builders.collapseBuilder,
      'collapseItem': builders.collapseItemBuilder,
      'empty': builders.emptyBuilder,
      'segmented': builders.segmentedBuilder,
      'tabs': builders.tabsBuilder,
      'tabBar': builders.tabBarBuilder,
      'alert': builders.alertBuilder,
    };
    expect(gaps.values, everyElement(isNull), reason: '已补齐的缺口请从清单移除');
    expect(builders.props.where((builder) => builder == null).length, gaps.length);
  });

  test('移动默认表只缺已知项', () {
    const builders = defaultComponentBuilders;
    final gaps = {
      'buttonGroup': builders.buttonGroupBuilder,
      'input': builders.inputBuilder,
      'checkbox': builders.checkboxBuilder,
      'radio': builders.radioBuilder,
      'select': builders.selectBuilder,
      'autocomplete': builders.autocompleteBuilder,
      'inputNumber': builders.inputNumberBuilder,
      'mention': builders.mentionBuilder,
      'inputTag': builders.inputTagBuilder,
      'inputOtp': builders.inputOtpBuilder,
      'formItem': builders.formItemBuilder,
      'tableStyle': builders.tableStyleBuilder,
      'steps': builders.stepsBuilder,
      'step': builders.stepBuilder,
      'avatar': builders.avatarBuilder,
      'calendar': builders.calendarBuilder,
      'collapse': builders.collapseBuilder,
      'collapseItem': builders.collapseItemBuilder,
      'empty': builders.emptyBuilder,
      'segmented': builders.segmentedBuilder,
      'tabs': builders.tabsBuilder,
      'tabBar': builders.tabBarBuilder,
      'alert': builders.alertBuilder,
    };
    expect(gaps.values, everyElement(isNull), reason: '已补齐的缺口请从清单移除');
    expect(builders.props.where((builder) => builder == null).length, gaps.length);
  });
}
