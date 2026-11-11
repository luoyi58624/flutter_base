import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

import '../../../layout/example_page.dart';

/// 画廊演示图片，与列表示例共用打包资源。
final previewImages = [
  'assets/recycler_cards/owl.jpg',
  'assets/recycler_cards/takeaway-food.webp',
  'assets/recycler_cards/owl-2.jpg',
  'assets/recycler_cards/bili_home.webp',
  'assets/recycler_cards/owl-2.jpg',
  'assets/recycler_cards/owl.jpg',
];

/// 图片预览示例：单张图片与地址列表画廊，共用无路由的进退场动画。
class PreviewPage extends StatelessWidget {
  /// 创建 Preview 示例页。
  const PreviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ExamplePage(
      title: 'Preview · 图片画廊',
      child: ElScroll(
        padding: .all(16),
        gap: 16,
        children: [
          ElCard(
            style: ElStyle(padding: .all(16)),
            child: Text(
              '点击图片打开预览。手机支持双指缩放、旋转、横滑翻页和下拉关闭；桌面支持滚轮缩放、拖动图片，以及切换、旋转和还原按钮。按返回或 Esc 关闭预览。',
              style: TextStyle(fontSize: 13, height: 1.6),
            ),
          ),
          GridView.count(
            crossAxisCount: 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            children: [
              for (var i = 0; i < previewImages.length; i++)
                ElImagePreview(
                  key: ValueKey('preview-thumb-$i'),
                  images: previewImages,
                  initialIndex: i,
                  child: ElImage(previewImages[i], fit: .cover),
                ),
            ],
          ),
          ElCard(
            style: ElStyle(padding: .all(16)),
            child: Column(
              crossAxisAlignment: .start,
              children: [
                Text('单张预览 · 不传 images'),
                SizedBox(height: 12),
                ElImagePreview(
                  key: ValueKey('preview-single'),
                  child: ElImage(previewImages.first, width: 180, height: 120, fit: .cover),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
