import 'package:example/src/pages/view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

import '../widgets/icons/settings_icons.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  MyListTile _tile(BuildContext context, ElSettingIcons icon, [Widget? page]) => MyListTile(
    title: icon.label,
    icon: ElSettingIcon(icon),
    onPressed: () {
      if (page != null) {
        Navigator.of(context).push(MaterialPageRoute(builder: (context) => page));
      }
    },
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade200,
      appBar: AppBar(title: Text('首页'), backgroundColor: Colors.white),
      body: SingleChildScrollView(
        child: Padding(
          padding: .all(16),
          child: Column(
            spacing: 16,
            children: [
              MyListGroup(
                children: [
                  _tile(context, .airplane, ElViewPage()),
                  _tile(context, .wifi),
                  _tile(context, .bluetooth),
                  _tile(context, .mobile),
                  _tile(context, .connect),
                ],
              ),
              MyListGroup(
                children: [
                  _tile(context, .personalize),
                  _tile(context, .display),
                  _tile(context, .sound),
                  _tile(context, .notifications),
                ],
              ),
              MyListGroup(children: [_tile(context, .password), _tile(context, .privacy), _tile(context, .location)]),
              MyListGroup(
                children: [
                  _tile(context, .apps),
                  _tile(context, .battery),
                  _tile(context, .accessibility),
                  _tile(context, .cloud),
                ],
              ),
              MyListGroup(
                children: [
                  _tile(context, .system),
                  _tile(context, .about),
                  _tile(context, .account),
                  _tile(context, .help),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
