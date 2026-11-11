import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

import '../../example_page.dart';
import 'zoom_view.dart';

/// 体验用图片，与列表示例共用打包资源。
final officialZoomPagerImages = [
  'assets/recycler_cards/owl.jpg',
  'assets/recycler_cards/owl-2.jpg',
  'assets/recycler_cards/takeaway-food.webp',
  'assets/recycler_cards/bili_home.webp',
];

/// 对照官方手势原型与当前 ElPreviewView 的缩放翻页交接。
class OfficialZoomPagerPage extends HookWidget {
  /// 创建缩放翻页原型页。
  const OfficialZoomPagerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final useCurrent = useState(false);
    final controller = usePageController();
    final page = useListenableSelector(
      controller,
      () => controller.hasClients && controller.position.hasContentDimensions ? (controller.page ?? 0).round() : 0,
    );
    final images = [
      for (final path in officialZoomPagerImages) Image.asset(path, fit: .contain, width: .infinity, height: .infinity),
    ];
    return ExamplePage(
      title: '官方手势 · 缩放翻页',
      backgroundColor: Colors.black,
      actions: [
        Text('当前 ElPreviewView'),
        Semantics(
          label: '切换到当前 ElPreviewView',
          child: Switch(value: useCurrent.value, onChanged: (value) => useCurrent.value = value),
        ),
      ],
      child: Stack(
        children: [
          Positioned.fill(
            child: useCurrent.value
                ? ElPreviewView(key: ValueKey('current-preview'), children: images)
                : PageView(
                    key: ValueKey('official-pager'),
                    controller: controller,
                    children: [for (final image in images) OfficialZoomView(child: image)],
                  ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: IgnorePointer(
              child: Text(
                [
                  if (!useCurrent.value) '${page + 1} / ${images.length}',
                  useCurrent.value ? '当前实现：ElView 事件层台账分账' : '官方识别器 + ScrollPosition.drag 交接',
                  '双击或双指放大，放大后拖到边缘继续翻页，不松手反向可收回',
                ].join('\n'),
                textAlign: .center,
                style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
