part of flutter_base;

/// 文件选择器工具类
class FilePickerUtil {
  FilePickerUtil._();

  /// 拉起系统相机
  static Future<AssetEntity?> camera(BuildContext context) async {
    return await CameraPicker.pickFromCamera(
      context,
      pickerConfig: const CameraPickerConfig(
        enableRecording: true,
      ),
    );
  }

  /// 选择图库，返回本地路径集合
  static Future<List<String>> photo(
    BuildContext context, {
    int max = 9,
  }) async {
    final List<AssetEntity>? results = await AssetPicker.pickAssets(
      context,
      pickerConfig: AssetPickerConfig(
        maxAssets: max,
        requestType: RequestType.image,
      ),
    );
    return _getFilePaths(results);
  }

  /// 选择视频，返回本地路径集合
  static Future<List<String>> video(BuildContext context) async {
    final List<AssetEntity>? results = await AssetPicker.pickAssets(
      context,
      pickerConfig: const AssetPickerConfig(
        maxAssets: 9,
        requestType: RequestType.video,
      ),
    );
    return _getFilePaths(results);
  }

  /// 选择文件
  static Future<List<PlatformFile>?> file(
    BuildContext context, {
    bool allowMultiple = true,
  }) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: allowMultiple,
    );
    if (result == null) {
      return null;
    } else {
      return result.files;
    }
  }

  static Future<List<String>> _getFilePaths(List<AssetEntity>? results) async {
    List<String> filePaths = [];

    if (results != null) {
      for (var result in results) {
        File? file = await result.file;
        if (file != null) {
          filePaths.add(file.path);
        }
      }
    }
    return filePaths;
  }
}
