import 'package:flutter_base/desktop.dart';
import 'package:flutter_base/src/ui/mobile/components/builders.dart';
import 'package:flutter_test/flutter_test.dart';

/// 品牌默认表除已知缺口外不得留空；缺口清单只减不增，新增组件必须两端登记实现。
void main() {
  test('桌面默认表只缺已知项', () {
    const builders = ElementPlusThemeData();
    final gaps = {
      'checkbox': builders.checkbox,
      'radio': builders.radio,
      'card': builders.card,
      'loadingIndicator': builders.loadingIndicator,
      'listTile': builders.listTile,
      'listTileGroup': builders.listTileGroup,
      'progress': builders.progress,
      'slider': builders.slider,
      'skeleton': builders.skeleton,
      'steps': builders.steps,
      'step': builders.step,
      'avatar': builders.avatar,
      'calendar': builders.calendar,
      'collapse': builders.collapse,
      'collapseItem': builders.collapseItem,
      'empty': builders.empty,
      'segmented': builders.segmented,
      'tabs': builders.tabs,
      'tabBar': builders.tabBar,
      'alert': builders.alert,
    };
    expect(gaps.values, everyElement(isNull), reason: '已补齐的缺口请从清单移除');
    expect(builders.props.where((builder) => builder == null).length, gaps.length);
  });

  test('移动默认表只缺已知项', () {
    const builders = defaultComponentBuilders;
    final gaps = {
      'buttonGroup': builders.buttonGroup,
      'input': builders.input,
      'checkbox': builders.checkbox,
      'radio': builders.radio,
      'select': builders.select,
      'autocomplete': builders.autocomplete,
      'inputNumber': builders.inputNumber,
      'mention': builders.mention,
      'inputTag': builders.inputTag,
      'inputOtp': builders.inputOtp,
      'formItem': builders.formItem,
      'tableStyle': builders.tableStyle,
      'steps': builders.steps,
      'step': builders.step,
      'avatar': builders.avatar,
      'calendar': builders.calendar,
      'collapse': builders.collapse,
      'collapseItem': builders.collapseItem,
      'empty': builders.empty,
      'segmented': builders.segmented,
      'tabs': builders.tabs,
      'tabBar': builders.tabBar,
      'alert': builders.alert,
    };
    expect(gaps.values, everyElement(isNull), reason: '已补齐的缺口请从清单移除');
    expect(builders.props.where((builder) => builder == null).length, gaps.length);
  });
}
