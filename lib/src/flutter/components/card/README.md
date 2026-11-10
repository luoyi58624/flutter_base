# Card

`ElCard` 提供可选 Widget child、loading、style、event、shadowLevel 和 onTap，通过品牌 cardBuilder 分派。标题、说明等内容由调用方直接在 child 中组合。

onTap 或 event.onTap 非空时启用整卡操作，详细识别配置通过 event.config 设置，event.preventDefault 可取消 onTap。移动端默认按压变色并缩放，用户通过 style.onTap 覆写；内部按钮、输入仍独立操作。

shadowLevel 读取对应的通用阴影 token，省略时无阴影；style.boxShadow 最后覆盖，包括用空列表移除阴影。loading 显示指示器并暂停整卡与内容交互，内容实例仍保留。

区域语义由品牌实现建立（可用 semanticLabel 命名），品牌只负责默认外观与反馈。桌面实现无默认外观，移动实现带默认外观。
