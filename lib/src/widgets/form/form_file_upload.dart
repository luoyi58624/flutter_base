part of flutter_base;

/// 带有验证函数的表单文件上传组件，文件选择基于 file_picker 库
class FormFileUploadWidget extends StatefulWidget {
  const FormFileUploadWidget({
    super.key,
    this.initValue,
    this.fileType = FileType.any,
    this.allowedExtensions,
    this.allowMultiple = false,
    this.rowCount = 3,
    this.validator,
    this.onChanged,
  }) : assert(
            (fileType != FileType.custom && allowedExtensions == null) ||
                (fileType == FileType.custom && allowedExtensions != null),
            'FileType.custom和allowedExtensions要么同时存在要么都不设置');

  /// 初始值
  final List<PlatformFile>? initValue;

  /// 允许选择的文件类型，默认为任意类型
  final FileType fileType;

  /// 允许的文件扩展名：['jpg','png']，当fileType=custom时必须设置
  final List<String>? allowedExtensions;

  /// 是否允许多选，注意：由于file_picker库的限制，暂时不能限制用户选择文件数量，
  /// 用户要么只能选择一个文件，要么选择多个文件。
  ///
  /// 原因是file_picker是对底层平台进行的封装，安卓原生文件选择是无法做到限制用户选择最大数量。
  final bool allowMultiple;

  /// 每行显示的文件数量
  final int rowCount;

  /// 验证回调
  final FormFieldValidator<List<PlatformFile>>? validator;

  /// 文件选择回调
  final ValueChanged<List<PlatformFile>>? onChanged;

  @override
  State<FormFileUploadWidget> createState() => FormFileUploadWidgetState();
}

class FormFileUploadWidgetState extends State<FormFileUploadWidget> with FlutterThemeMixin{
  @override
  Widget build(BuildContext context) {
    var validator = widget.validator ??
        (FormItemInheritedWidget.of(context)?.required != null
            ? (value) {
                if (value == null || value.isEmpty) {
                  return DartUtil.safeString(
                    FormItemInheritedWidget.of(context)?.required,
                    defaultValue: '请选择文件',
                  );
                } else {
                  return null;
                }
              }
            : null);
    return FormField<List<PlatformFile>>(
      initialValue: widget.initValue ?? [],
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: validator,
      builder: (FormFieldState<List<PlatformFile>> state) {
        return Padding(
          padding: EdgeInsets.only(bottom: state.hasError ? 24 : 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GridView.count(
                crossAxisCount: widget.rowCount,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 16 / 15,
                children: [
                  ...buildFileItems(state),
                  // 如果允许多选或者单选时文件为空，则显示添加按钮
                  if (widget.allowMultiple || (!widget.allowMultiple && (state.value == null || state.value!.isEmpty)))
                    TapScaleWidget(
                      onTap: () async {
                        FilePickerResult? result = await FilePicker.platform.pickFiles(
                          type: widget.fileType,
                          allowedExtensions: widget.allowedExtensions,
                          allowMultiple: widget.allowMultiple,
                        );
                        if (result != null) {
                          List<PlatformFile> fileList = [...state.value!];
                          if (widget.allowMultiple) {
                            fileList.addAll(result.files);
                          } else {
                            fileList.add(result.files.single);
                          }
                          state.didChange(fileList);
                          if (widget.onChanged != null) {
                            widget.onChanged!(state.value!);
                          }
                        }
                      },
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: double.infinity,
                            height: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                width: 1,
                                color: state.hasError
                                    ? $errorColor
                                    : ColorUtil.dynamicColor(
                                        Colors.grey.shade600,
                                        Colors.grey.shade300,
                                        context,
                                      ),
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Icon(
                                Icons.add,
                                size: 32,
                                color: state.hasError
                                    ? $errorColor
                                    : ColorUtil.dynamicColor(
                                        Colors.grey.shade600,
                                        Colors.grey.shade300,
                                        context,
                                      ),
                              ),
                            ),
                          ),
                          if (state.hasError)
                            Positioned(
                              bottom: -24,
                              left: 0,
                              right: 0,
                              child: Center(
                                child: Text(
                                  state.errorText!,
                                  softWrap: false,
                                  overflow: TextOverflow.visible,
                                  style: TextStyle(
                                    color: $errorColor,
                                    fontSize: hintFontSize[FormInheritedWidget.of(state.context)?.size] ??
                                        hintFontSize[FormSize.medium]!,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// 构建已经选择的文件
  List<Widget> buildFileItems(FormFieldState<List<PlatformFile>> state) {
    return state.value!
        .asMap()
        .map(
          (index, value) => MapEntry(
            index,
            TapScaleWidget(
              onTap: () async {
                FilePickerResult? result = await FilePicker.platform.pickFiles(
                  type: widget.fileType,
                  allowedExtensions: widget.allowedExtensions,
                  allowMultiple: false,
                );
                if (result != null) {
                  List<PlatformFile> fileList = [...state.value!];
                  fileList.replaceRange(index, index + 1, [result.files.single]);
                  state.didChange(fileList);
                  if (widget.onChanged != null) {
                    widget.onChanged!(state.value!);
                  }
                }
              },
              onLongPress: () {
                ModalUtils.showConfitmModal(
                    content: '你确定要删除吗？',
                    onConfirm: () {
                      List<PlatformFile> fileList = [...state.value!];
                      fileList.removeAt(index);
                      state.didChange(fileList);
                      if (widget.onChanged != null) {
                        widget.onChanged!(state.value!);
                      }
                    });
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: DartUtil.isImage(value.name)
                        ? ImageWidget(file: value.path!)
                        : FileTypeImageWidget(fileName: value.name),
                  ),
                  const SizedBox(height: 4),
                  Tooltip(
                    message: value.name,
                    child: Text(
                      value.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        )
        .values
        .toList();
  }
}
