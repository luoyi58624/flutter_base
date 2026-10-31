# Backtop

回到顶部组件的参数声明，保留 controller、visibilityHeight、right、bottom、duration、onTap、child、style 和辅助名称。

`backtopBuilder(context, component)` 接收声明。当前不会监听滚动、计算可见性或调用 animateTo；后续品牌实现负责这些行为。控制器由调用方管理，默认 Builder 为 null。
