# round 2 修复范围与复验计划

1. MyGlyph 增加目标边长（默认24），Loading传16/24/32，Progress传circle size×0.28或line 18；实际RenderBox尺寸与绘制同步。
2. MyThemeData增加fontFamily / fontFamilyFallback token与copyWith，MyTheme同时写入DefaultTextStyle和ElView；默认Times New Roman，中文回退按同机Chrome实际字体取证后确定，记录平台可用字体前提。
3. 回归测试检查真实MyGlyph尺寸、与包装层/圆环中心的坐标、尺寸更新；主题测试检查默认值及两条文字链继承/覆写。
4. 使用isolated SDK与PUB_CACHE=D:/data/pub-cache，仅分析lib/src/my_ui与test/my_ui，运行test/my_ui；先记录分析基线。
5. 重新采集全部8组件×390/1440×明暗及原状态补图，另测40/64/96/128圆环成功/失败；round2目录保留新图、几何、字体和像素证据。
6. 原报告结论与图片保留，追加修复复验及残差；输出.codex/my-ui-fix-last.md。禁git、依赖修改和下一批扩展。

补充：同机复验发现Material宿主行高会通过DefaultTextStyle.merge进入普通Text插槽；主题根明确使用字体自身normal行高（kTextHeightNone），ElView同步，组件显式行高仍优先。此项属于字体继承契约，仅修改theme与相关测试，不修改Card/Divider/Button。
