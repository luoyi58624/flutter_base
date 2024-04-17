import 'package:flutter_base/flutter_base.dart';

class GlobalController extends GetxController {
  static GlobalController of = Get.find();
  final isLogin = useLocalObs(false, 'isLogin');
  final count = 0.obs;
}
