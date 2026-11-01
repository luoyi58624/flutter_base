# Text

内部 `textBuilder` 将 ElText 的全部平铺参数传给 Flutter Text，字体、颜色与默认字重由 ElMobileTheme 的 DefaultTextStyle 提供；显式 TextStyle 保持优先。用户只调用 ElText，组件不额外建立值模型或交互入口。
