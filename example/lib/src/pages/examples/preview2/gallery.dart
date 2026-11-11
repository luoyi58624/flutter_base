import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

/// 基于 ElPreview2View 二次包装的图片画廊：接收图片数组，自定义滑动过渡、计数栏、单击切换外观与下拉关闭。
class ImageGallery extends HookWidget {
  /// 创建画廊，[initialIndex] 为打开时显示的图片。
  const ImageGallery({super.key, required this.images, this.initialIndex = 0});

  /// 图片资源路径。
  final List<String> images;

  /// 打开时显示的图片。
  final int initialIndex;

  /// 以淡入的透明路由打开画廊。
  static Future<void> open(BuildContext context, List<String> images, int index) => Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      transitionDuration: Duration(milliseconds: 200),
      reverseTransitionDuration: Duration(milliseconds: 160),
      pageBuilder: (context, animation, secondaryAnimation) => ImageGallery(images: images, initialIndex: index),
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final controller = useMemoized(() => ElPreview2Controller(initialIndex: initialIndex));
    useEffect(() => controller.dispose, [controller]);
    final index = useListenableSelector(controller, () => controller.index);
    final chrome = useState(true);
    // 下拉距离只驱动背景与内容位移，不重建预览。
    final dismiss = useValueNotifier(0.0);
    final back = useAnimationController(duration: Duration(milliseconds: 200));
    final backFrom = useRef(0.0);
    useEffect(() {
      void tick() => dismiss.value = backFrom.value * (1 - Curves.easeOutCubic.transform(back.value));
      back.addListener(tick);
      return () => back.removeListener(tick);
    }, [back]);

    void close() => Navigator.of(context).maybePop();

    final preview = ElPreview2View(
      controller: controller,
      itemCount: images.length,
      itemBuilder: (context, index) => Image.asset(images[index], fit: .contain),
      // 上层决定切换过渡：横向滑动并在相邻图片之间留出 4% 间隔。
      transitionBuilder: (context, index, position, child) => ValueListenableBuilder(
        valueListenable: position,
        builder: (context, value, child) => FractionalTranslation(translation: Offset(value * 1.04, 0), child: child),
        child: child,
      ),
      onTap: () => chrome.value = !chrome.value,
      onVerticalDragStart: (_) => back.stop(),
      onVerticalDragUpdate: (details) => dismiss.value += details.primaryDelta!,
      onVerticalDragEnd: (details) {
        if (dismiss.value.abs() > 120 || details.primaryVelocity!.abs() > 800) return close();
        backFrom.value = dismiss.value;
        back.forward(from: 0);
      },
    );

    return Stack(
      fit: .expand,
      children: [
        ValueListenableBuilder(
          valueListenable: dismiss,
          builder: (context, offset, child) {
            final progress = (offset.abs() / 300).clamp(0.0, 1.0);
            return ColoredBox(
              color: Colors.black.withValues(alpha: 1 - progress * 0.85),
              child: Transform.translate(
                offset: Offset(0, offset),
                child: Transform.scale(scale: 1 - progress * 0.25, child: child),
              ),
            );
          },
          child: preview,
        ),
        IgnorePointer(
          ignoring: !chrome.value,
          child: AnimatedOpacity(
            opacity: chrome.value ? 1 : 0,
            duration: Duration(milliseconds: 160),
            child: SafeArea(
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        tooltip: '关闭',
                        onPressed: close,
                        icon: Icon(Icons.close, color: Colors.white),
                      ),
                      Expanded(
                        child: Text(
                          '${index + 1} / ${images.length}',
                          textAlign: .center,
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: .w600),
                        ),
                      ),
                      IconButton(
                        tooltip: '还原',
                        onPressed: controller.resetTransform,
                        icon: Icon(Icons.fit_screen_outlined, color: Colors.white),
                      ),
                    ],
                  ),
                  Spacer(),
                  Padding(
                    padding: .all(16),
                    child: Text(
                      '双指缩放 / 旋转 · 拖到边缘继续翻页 · 双击放大 · 滚轮缩放 · 下拉关闭',
                      textAlign: .center,
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
