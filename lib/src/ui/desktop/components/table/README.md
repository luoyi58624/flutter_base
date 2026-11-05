# Table Style

从 Element Plus `components/data/table/theme.dart` 迁入本目录 index.dart，注册到 `ElementPlusThemeData.tableStyleBuilder`。只提供 ElTableStyle，表格布局、虚拟化、选择与编辑继续使用通用 ElTable。

保留 normal / compact 两态行高（40 / 36）、单元格内边距、表头字重、外框与网格线、悬停色和当前行色。预设默认开启外框，关闭斑马纹和当前行高亮；显式 ElTableStyle 配置可在预设上 copyWith 局部覆盖。

安装与整体迁移范围见 [Desktop](../../README.md)。
