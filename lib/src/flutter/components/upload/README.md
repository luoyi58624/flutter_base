# 上传

`ElUpload` 负责选择入口、文件列表、进度和操作。应用用 `ElUploadFile` 提供稳定身份与状态，通过 `onPick/onRemove/onRetry/onCancel` 对接文件选择和传输。

组件不读取本地文件、不发起网络请求，也不保存文件句柄。`drag` 开启大面积选择区域外观；操作系统文件拖放由应用外层接入。`style` 和 `event` 作用于组件根节点。
