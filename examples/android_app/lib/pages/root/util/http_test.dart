import 'package:android_app/global.dart';
import 'package:flutter/cupertino.dart';

class HttpTestPage extends StatefulWidget {
  const HttpTestPage(this.title, {super.key});

  final String title;

  @override
  State<HttpTestPage> createState() => _HttpTestPageState();
}

class _HttpTestPageState extends State<HttpTestPage> {
  String? text;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(widget.title),
        previousPageTitle: '插件测试',
      ),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: buildCenterColumn([
          Text('请求的数据：$text'),
          CupertinoButton.filled(
            onPressed: () async {
              // var resData = http.test();
              LoadingUtil.show('加载中');
              var resData = await httpBase.get('https://jsonplaceholder.typicode.com/todos/1');
              logger.i(resData);
              setState(() {
                text = resData.toString();
              });
            },
            child: const Text('发送get请求'),
          ),
          const SizedBox(height: 8),
          CupertinoButton.filled(
            onPressed: () async {
              LoadingUtil.show('加载中');
              var resData = await http.test('/todos/1');
              logger.i(resData);
              setState(() {
                text = resData.toString();
              });
            },
            child: const Text('发送get请求'),
          ),
          const SizedBox(height: 8),
          CupertinoButton.filled(
            onPressed: () async {
              setState(() {
                text = '';
              });
              logger.i(http.instance == httpBase.instance);
              logger.i(http.instance.options.baseUrl);
              logger.i(httpBase.instance.options.baseUrl);
            },
            child: const Text('清空数据'),
          ),
        ]),
      ),
    );
  }
}
