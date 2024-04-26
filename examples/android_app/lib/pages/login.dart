import 'package:android_app/controllers/global.dart';
import 'package:flutter/material.dart';

import '../global.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('用户登录'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(28),
        child: FormWidget(
          child: Column(
            children: [
              const FormTextFieldWidget(
                label: '用户名',
              ),
              const SizedBox(height: 20),
              const FormTextFieldWidget(
                label: '密码',
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: () async {
                    // LoadingUtil.show('登录中...');
                    // await 2.delay();
                    // LoadingUtil.close();
                    GlobalController.of.isLogin.value = true;
                    if (context.mounted) context.go(RoutePath.root);
                  },
                  child: const Text('登陆'),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
