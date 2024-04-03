import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

const String imageUrl = 'https://images.pexels.com/photos/2286895/pexels-photo-2286895.jpeg';

class ImageTestPage extends StatefulWidget {
  const ImageTestPage({super.key});

  @override
  State<ImageTestPage> createState() => _ImageTestPageState();
}

class _ImageTestPageState extends State<ImageTestPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Image图片组件测试'),
      ),
      body: buildCenterColumn([
        const ImageWidget(
          url: imageUrl,
          width: 64,
          height: 64,
        ),
        const ImageWidget.circle(url: imageUrl, size: 64),
      ]),
    );
  }
}
