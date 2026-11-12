import 'package:flutter_base/mobile.dart';

/// 首页各展示区共用的本地收藏状态。
final showcaseLiked = Obs(false, cacheKey: 'showcase.liked');

/// 首页各展示区共用的稍后阅读状态。
final showcaseLater = Obs(false, cacheKey: 'showcase.later');
