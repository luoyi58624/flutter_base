# Avatar

ElAvatar 以 Web Avatar 的图片与回退内容为基线：src、alt、child、size、shape、style、semanticLabel、onLoad、onError。默认 alt 为空、size 为 40、shape 为 circle。

child 对应明确的回退文字或自定义插槽，优先于从 alt 提取的自动缩写；图片缺失或失败时由品牌展示回退。加载完成通知复用 ImageLoadInfo，错误通知接收 Object，不复制 DOM Event 模型。

移除独立 icon、fit、onTap、disabled 等参数，交互由外层 ElView / 按钮组合。AvatarGroup 不在 Web 基线内，已移除。当前移动端尚未登记 Avatar Builder。
