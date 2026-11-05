# RecyclerView 长列表示例

入口为「示例 → RecyclerView」，两端使用相同页面；也可打开 `/examples/recycler-selection` 或 `/examples/recycler-chat`。

## 万条复选列表

- 创建 10,000 条不同编号、标题和描述的业务记录，按需挂载条目 Widget。
- `Adapter` 提供稳定 ID，`ViewHolder` 保留结构，`onBindViewHolder` 更新本次记录和选中状态。
- 勾选状态存在按业务 ID 索引的集合中，离屏或复用 holder 不会把旧状态带给另一条记录。
- 顶部提供已选计数、清空、首尾跳转和按 1 开始的序号定位。

## 聊天长列表

- 初始 10,000 条长短不同、方向不同的消息，从末端显示。
- 「更早 50 条」在顶部插入历史，使用稳定 ID 与范围插入通知保留当前阅读锚点。
- 底部阅读时发送或收到消息会跟随末端；阅读旧消息时保持位置，并显示新消息数量。
- 「最新消息」回到末端并清除未读提示；未读按钮宽度固定，避免文案变化撑高工具栏。
- 所有消息共用两种结构类型，重新绑定时更新内容、方向和时间。

这两个示例直接使用 RecyclerView，不受文档页面的滚动选择或重复倍率影响；10,000 表示实际记录数量。

无头回归测试：

```powershell
cd example
flutter test test/recycler_long_examples_test.dart --no-pub --concurrency=1
```
