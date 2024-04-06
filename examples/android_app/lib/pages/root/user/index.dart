import 'package:android_app/controllers/global.dart';
import 'package:android_app/router.dart';
import 'package:flutter_base/flutter_base.dart';

class UserPage extends StatelessWidget {
  const UserPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: CustomScrollView(
        slivers: [
          const CupertinoSliverNavigationBar(
            largeTitle: Text(
              '用户信息',
            ),
          ),
          const SliverToBoxAdapter(
            child: SizedBox(height: 150),
          ),
          SliverToBoxAdapter(
            child: Column(
              children: [
                CupertinoButton.filled(
                  onPressed: () {
                    GlobalController.of.isLogin.value = false;
                    context.go('/login');
                  },
                  child: const Text('退出登录'),
                ),
                const SizedBox(height: 8),
                CupertinoButton.filled(
                  onPressed: () {
                    GlobalController.of.isLogin.value = false;
                  },
                  child: const Text('清除登录信息'),
                ),
                const SizedBox(height: 8),
                CupertinoButton.filled(
                  onPressed: () {
                    // RouterUtil.push(const _ChildPage());
                    context.push('/cuperitno_root_child');
                  },
                  child: const Text('下一页'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CupertinoChildPage extends StatelessWidget {
  const CupertinoChildPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text(
          '子页面',
        ),
        previousPageTitle: '用户信息',
        // previousPageTitle: 'Back',
      ),
      child: Center(
        child: CupertinoButton.filled(
          onPressed: () {
            router.pop(context);
          },
          child: const Text('返回'),
        ),
      ),
    );
  }
}
