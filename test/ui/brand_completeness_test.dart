import 'package:flutter_base/desktop.dart';
import 'package:flutter_base/mobile.dart' show ElMobileExt;
import 'package:flutter_test/flutter_test.dart';

int _missingBuilders(ElComponents components) =>
    components.props.where((value) => value == null).length - (components.style == null ? 1 : 0);

/// 品牌默认表除已知缺口外不得留空；缺口清单只减不增，新增组件必须两端登记实现。
void main() {
  test('桌面默认表只缺已知项', () {
    final builders = el.desktopComponents;
    final gaps = {'skeleton': builders.skeleton, 'empty': builders.empty};
    expect(gaps.values, everyElement(isNull), reason: '已补齐的缺口请从清单移除');
    expect(_missingBuilders(builders), gaps.length);
  });

  test('移动默认表只缺已知项', () {
    final builders = el.mobileComponents;
    final gaps = {
      'inputNumber': builders.inputNumber,
      'mention': builders.mention,
      'inputTag': builders.inputTag,
      'inputOtp': builders.inputOtp,
      'formItem': builders.formItem,
      'tableStyle': builders.tableStyle,
      'empty': builders.empty,
    };
    expect(gaps.values, everyElement(isNull), reason: '已补齐的缺口请从清单移除');
    expect(_missingBuilders(builders), gaps.length);
  });
}
