# Contacts

ElContactGroup<T> 声明索引、标题和业务成员；ElContacts<T> 声明分组列表、姓名提取、联系人和标题 Builder、点击回调、顶部与底部内容、滚动控制器及刷新配置。

`contactsBuilder<T>(context, component)` 保留业务类型，不进行排序、拼音推断、索引定位、吸顶或刷新操作。当前仅定义数据与回调契约，默认 Builder 为 null；调用方持有并释放外部控制器。
