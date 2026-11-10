part of 'app.dart';

class _ProfilePage extends HookWidget {
  const _ProfilePage(this.typography, this.options);
  final _Typography typography;
  final ElExampleApp options;
  @override
  Widget build(BuildContext context) {
    final push = useState(true), update = useState(false);
    return ExamplePanel(
      key: ValueKey('page-我的'),
      style: ElStyle(backgroundColor: _background),
      child: ElScrollView(
        key: PageStorageKey('profile-list'),
        padding: EdgeInsets.only(bottom: 12),
        children: [
          ExamplePanel(
            style: ElStyle(
              margin: .all(12),
              padding: .all(16),
              backgroundColor: _surface,
              borderRadius: .circular(8),
            ),
            child: Row(
              children: [
                ElView(
                  style: ElStyle(
                    width: 56,
                    height: 56,
                    backgroundColor: _primary,
                    borderRadius: .circular(16),
                    alignment: .center,
                  ),
                  child: _Label(
                    '牛',
                    typography,
                    size: 20,
                    weight: .w700,
                    color: _surface,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: .start,
                    children: [
                      _Label(
                        '牛马老铁',
                        typography,
                        size: 17,
                        weight: .w700,
                        color: _text,
                        maxLines: 1,
                      ),
                      SizedBox(height: 4),
                      _Label(
                        'ID: 10086 · 已用 128 天',
                        typography,
                        size: 12,
                        color: _tertiary,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
                _Icon('arrow_right', size: 16, color: Color(0xffc4c4c4)),
              ],
            ),
          ),
          _Section('示例', typography),
          _Setting(
            '组件示例',
            'info',
            typography,
            onPressed: () => _push(context, HomePage()),
          ),
          _Section('账号', typography),
          _Setting(
            '账号与安全',
            'shield',
            typography,
            onPressed: () => _push(context, _AccountPage(typography)),
          ),
          _Setting(
            '我的收藏',
            'star',
            typography,
            value: '12',
            divider: false,
            onPressed: () => _push(context, _FavoritePage(typography)),
          ),
          _Section('偏好设置', typography),
          _Setting(
            '消息推送',
            'notify',
            typography,
            checked: push.value,
            onChanged: (value) {
              push.value = value;
              _toast('消息推送 ${value ? '已开启' : '已关闭'}');
            },
          ),
          _Setting(
            '自动检查更新',
            'info',
            typography,
            divider: false,
            checked: update.value,
            onChanged: (value) {
              update.value = value;
              _toast('自动检查更新 ${value ? '已开启' : '已关闭'}');
            },
          ),
          _Section('其它', typography),
          _Setting(
            '帮助与反馈',
            'help',
            typography,
            onPressed: () => _push(
              context,
              _WebPage(
                '帮助与反馈',
                'demo_page.html',
                typography,
                options.pageContentBuilder,
              ),
            ),
          ),
          _Setting(
            '关于我们',
            'info',
            typography,
            value: 'v1.0.0',
            divider: false,
            onPressed: () => _push(
              context,
              _WebPage(
                '关于我们',
                'about.html',
                typography,
                options.pageContentBuilder,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, this.typography);
  final String title;
  final _Typography typography;
  @override
  Widget build(BuildContext context) => ElView(
    style: ElStyle(
      height: 40,
      width: '100%',
      padding: .only(left: 12, bottom: 6),
      alignment: .bottomLeft,
    ),
    child: _Label(title, typography, size: 12, color: _tertiary),
  );
}

class _Setting extends StatelessWidget {
  const _Setting(
    this.title,
    this.icon,
    this.typography, {
    this.value = '',
    this.divider = true,
    this.checked,
    this.onChanged,
    this.onPressed,
  });
  final String title, icon, value;
  final _Typography typography;
  final bool divider;
  final bool? checked;
  final ValueChanged<bool>? onChanged;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => ExamplePanel(
    style: ElStyle(backgroundColor: _surface),
    child: Column(
      children: [
        ElButtonView(
          key: ValueKey('setting-$title'),
          semanticLabel: title,
          onPressed: onPressed,
          style: ElStyle(
            height: 52,
            padding: .only(left: 16, right: 12),
            alignment: .center,
          ),
          child: Row(
            children: [
              _Icon(icon, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: _Label(
                  title,
                  typography,
                  size: 15,
                  color: _text,
                  maxLines: 1,
                ),
              ),
              if (value.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: _Label(value, typography, size: 12, color: _tertiary),
                ),
              SizedBox(width: 4),
              if (checked == null)
                _Icon('arrow_right', size: 16, color: Color(0xffc4c4c4))
              else
                _Switch(title, checked!, onChanged!),
            ],
          ),
        ),
        _line(indent: 46, visible: divider),
      ],
    ),
  );
}

class _Switch extends StatelessWidget {
  const _Switch(this.label, this.value, this.onChanged);
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => ElSwitch(
    key: ValueKey('switch-$label'),
    value: value,
    onChanged: onChanged,
    semanticLabel: label,
  );
}

class _AccountPage extends HookWidget {
  const _AccountPage(this.typography);
  final _Typography typography;
  @override
  Widget build(BuildContext context) {
    final find = useState(true), online = useState(false);
    return _Page(
      '账号与安全',
      typography,
      ElScrollView(
        padding: EdgeInsets.only(bottom: 12),
        children: [
          _Section('登录与安全', typography),
          _Setting(
            '登录密码',
            'shield',
            typography,
            value: '已设置',
            onPressed: () => _toast('点击了：登录密码'),
          ),
          _Setting(
            '手机绑定',
            'info',
            typography,
            value: '138****8888',
            divider: false,
            onPressed: () => _toast('点击了：手机绑定'),
          ),
          _Section('隐私', typography),
          _Setting(
            '允许通过手机号找到我',
            'shield',
            typography,
            checked: find.value,
            onChanged: (value) {
              find.value = value;
              _toast('允许通过手机号找到我 ${value ? '已开启' : '已关闭'}');
            },
          ),
          _Setting(
            '展示在线状态',
            'info',
            typography,
            checked: online.value,
            divider: false,
            onChanged: (value) {
              online.value = value;
              _toast('展示在线状态 ${value ? '已开启' : '已关闭'}');
            },
          ),
        ],
      ),
    );
  }
}
