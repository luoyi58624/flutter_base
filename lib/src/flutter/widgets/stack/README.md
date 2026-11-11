# ElStack：自然占位与绝对定位

```dart
SizedBox(
  width: 240, height: 160,
  child: ElStack(children: [
    ElStackItem(zIndex: 1, offset: Offset(0, 4), child: Text('保留自然槽位')),
    ElPositioned(top: 8, right: '10%', zIndex: 2, child: Text('定位角标')),
  ]),
);
```

- ElStackItem 的 offset 改变呈现位置，不改变兄弟布局；只调层级也可用它。
- ElPositioned 接受数字、百分比和 ElDimension；水平 left/right/width、垂直 top/bottom/height 各最多设两个。`.fill` 四边贴 0。
- 同层 zIndex 越大越靠前；负值保留布局但隐藏呈现及语义。
- alignment 定义非定位子和缺边定位子的对齐，fit 使用官方 StackFit。
- 默认 `clipBehavior: Clip.none`，支持溢出命中；改为裁剪会截断溢出绘制和命中。
- ElStack 可接官方 Positioned；ElPositioned 不能放进官方 Stack。
