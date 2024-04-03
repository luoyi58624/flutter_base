part of flutter_base;

/// 根据文件类型渲染图片组件
class FileTypeImageWidget extends StatelessWidget {
  const FileTypeImageWidget({super.key, this.fileName, this.fileSuffix, this.width, this.height});

  /// 通过文件名获取图标
  final String? fileName;

  /// 通过文件后缀获取图标
  final String? fileSuffix;

  /// 图片宽高
  final double? width;
  final double? height;

  /// 根据文件名或文件后缀获取文件图标，返回assets目录
  static String getFileTypeIcon({String? fileName, String? fileSuffix}) {
    String suffix = '';
    if (fileName != null) {
      suffix = DartUtil.getFileSuffix(fileName) ?? '';
    }
    if (fileSuffix != null) {
      suffix = suffix;
    }
    String path;
    switch (suffix) {
      case 'jpg':
      case 'png':
      case 'gif':
        path = 'assets/file_icon/image.png';
        break;
      case 'mkv':
      case 'mp4':
      case 'avi':
      case 'mov':
      case 'wmv':
        path = 'assets/file_icon/video.png';
        break;
      case 'exe':
        path = 'assets/file_icon/exe.png';
        break;
      case 'doc':
      case 'docx':
        path = 'assets/file_icon/word.png';
        break;
      case 'xls':
      case 'xlsx':
        path = 'assets/file_icon/excel.png';
        break;
      case 'ppt':
      case 'pptx':
        path = 'assets/file_icon/ppt.png';
        break;
      case 'pdf':
        path = 'assets/file_icon/pdf.png';
        break;
      case 'apk':
        path = 'assets/file_icon/android.png';
        break;
      case 'zip':
      case 'rar':
        path = 'assets/file_icon/compress.png';
        break;
      case 'txt':
      case 'text':
        path = 'assets/file_icon/txt.png';
        break;
      default:
        path = 'assets/file_icon/other.png';
        break;
    }
    return path;
  }

  @override
  Widget build(BuildContext context) {
    return ImageWidget(
      asset: getFileTypeIcon(fileName: fileName, fileSuffix: fileSuffix),
      width: width,
      height: height,
      package: 'flutter_base',
    );
  }
}
