import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

import '../../../layout/example_page.dart';
import 'gallery.dart';

/// 画廊演示图片，与列表示例共用打包资源。
final preview2Images = [
  'assets/recycler_cards/owl.jpg',
  'assets/recycler_cards/takeaway-food.webp',
  'assets/recycler_cards/owl-2.jpg',
  'assets/recycler_cards/bili_home.webp',
  'assets/recycler_cards/owl-2.jpg',
  'assets/recycler_cards/owl.jpg',
];

/// ElPreview2View 示例：缩略图入口打开上层包装的图片画廊。
class Preview2Page extends StatelessWidget {
  /// 创建 Preview2 示例页。
  const Preview2Page({super.key});

  @override
  Widget build(BuildContext context) {
    return ExamplePage(
      title: 'Preview2 · 图片画廊',
      child: ElScroll(
        padding: .all(16),
        gap: 16,
        children: [
          ElCard(
            style: ElStyle(padding: .all(16)),
            child: Text(
              'ElPreview2View 负责手势、变换与左右切换，内容可以是任意 Widget；画廊的计数栏、单击切换外观和下拉关闭在上层包装里实现。',
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
              for (var i = 0; i < preview2Images.length; i++)
                GestureDetector(
                  key: ValueKey('preview2-thumb-$i'),
                  onTap: () => ImageGallery.open(context, preview2Images, i),
                  child: ClipRRect(
                    borderRadius: .circular(8),
                    child: Image.asset(preview2Images[i], fit: .cover),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
