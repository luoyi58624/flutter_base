# Icon

ElIcon 保留 Flutter IconData 作为 child，共同参数只有 size、color、style 和 semanticLabel。装饰图标可以省略辅助名称。

不再单独公开 fill / weight / grade / opticalSize、fontWeight、textDirection 或 applyTextScaling。字形数据、可变轴、字体与方向由 ElStyle 或既有图标机制承接，不在接口复制一份 Flutter Icon 配置。

当前移动端尚未登记 Icon Builder，具体实现不公开导出。
