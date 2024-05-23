part of 'index.dart';

class AppController extends GetxController {
  AppController._();

  static AppController get of => Get.find();

  late final themeMode = useLocalObs<ThemeMode>(
    ThemeMode.system,
    'theme_mode',
    serializeFun: (model) => model.index.toString(),
    deserializeFun: (json) => ThemeMode.values[int.parse(json)],
  );

  late final Rx<AppData> appData;
  late final selectPresetTheme = useLocalObs(0, 'selected_preset_theme');
  final showPerformanceOverlay = false.obs;

  AppData getAppData(int index) {
    if (index == 1) return AppData.m2Data;
    if (index == 2) return AppData.m2FlatData;
    if (index == 3) return AppData.m3Data;
    if (index == 4) return AppData.m3FlatData;
    return AppData.defaultData;
  }

  @override
  void onInit() {
    super.onInit();
    appData = getAppData(selectPresetTheme.value).obs;
    ever(selectPresetTheme, (index) {
      appData.value = getAppData(index);
    });
  }
}
