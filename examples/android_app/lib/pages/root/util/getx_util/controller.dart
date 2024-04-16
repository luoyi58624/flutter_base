import 'dart:convert';

import 'package:flutter_base/flutter_base.dart';

class UserModel {
  String? username;
  num? password;

  UserModel();

  UserModel.fromJson(Map<String, dynamic> json) {
    username = json['username'] ?? '';
    password = json['password'] ?? 0;
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['username'] = username;
    data['password'] = password;
    return data;
  }

  @override
  String toString() {
    return jsonEncode(this);
  }
}

class GetxUtilController extends GetxController {
  final xx = 0.0.obs;
  final count = useLocalObs(0, 'getx_test_count');
  final userList = useLocalListObs<Map<String, dynamic>>(
    [],
    'getx_user_list',
    // expireDateTimeFun: () => DateTime.now().millisecondsSinceEpoch + 1000 * 5,
  );
  final userModel = useLocalObs(
    UserModel(),
    'getx_test_userModel',
    serializeFun: (model) => jsonEncode(model.toJson()),
    deserializeFun: (json) => UserModel.fromJson(jsonDecode(json)),
  );
}
