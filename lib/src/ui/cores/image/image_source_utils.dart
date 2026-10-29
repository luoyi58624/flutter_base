import 'dart:convert';

/// asset 语义判定（双端共用规则，io/stub 两个 resolver 共 import 此单一实现，
/// 防止平台分支的来源识别契约漂移）：`asset://` 前缀显式声明，或惯例的
/// `assets/` 目录前缀。返回资源路径；非 asset 返回 null。
String? assetPathForSource(String source) {
  if (source.startsWith('asset://')) return source.substring('asset://'.length);
  if (source.startsWith('assets/')) return source;
  return null;
}

/// FNV-1a 64bit：跨进程稳定的字符串哈希（不引 crypto 依赖），磁盘缓存文件名用。
/// 64 位状态拆成 16 位 limb 手算乘法：Web 端 int 是 double（53 位精度），
/// 64 位字面量编译报错、64 位乘法丢精度；limb 版双端逐位一致，VM 输出与
/// 直接 64 位实现完全相同（磁盘缓存文件名不受影响）。
String fnv1aHex(String input) {
  // offset basis 0xcbf29ce484222325 按 16 位 limb 从低到高拆开。
  var h0 = 0x2325, h1 = 0x8422, h2 = 0x9ce4, h3 = 0xcbf2;
  for (final unit in utf8.encode(input)) {
    h0 ^= unit;
    // 乘 prime 0x100000001b3：limb 仅 0x01b3（位0）与 0x0100（位32）非零，
    // 溢出 64 位的部分积自然丢弃；中间值 < 2^33，double 精度内安全。
    final t0 = h0 * 0x01b3;
    final t1 = h1 * 0x01b3 + t0 ~/ 0x10000;
    final t2 = h2 * 0x01b3 + h0 * 0x0100 + t1 ~/ 0x10000;
    final t3 = h3 * 0x01b3 + h1 * 0x0100 + t2 ~/ 0x10000;
    h0 = t0 % 0x10000;
    h1 = t1 % 0x10000;
    h2 = t2 % 0x10000;
    h3 = t3 % 0x10000;
  }
  // 复刻原实现在 VM 上的有符号 toRadixString(16) 口径（高位为 1 时输出
  // `-` + 两补数取负的绝对值），保证存量磁盘缓存文件名不失效。
  final neg = h3 >= 0x8000;
  if (neg) {
    final n0 = (0xffff - h0) + 1;
    final n1 = (0xffff - h1) + (n0 >> 16);
    final n2 = (0xffff - h2) + (n1 >> 16);
    final n3 = (0xffff - h3) + (n2 >> 16);
    h0 = n0 & 0xffff;
    h1 = n1 & 0xffff;
    h2 = n2 & 0xffff;
    h3 = n3 & 0xffff;
  }
  final full =
      h3.toRadixString(16).padLeft(4, '0') +
      h2.toRadixString(16).padLeft(4, '0') +
      h1.toRadixString(16).padLeft(4, '0') +
      h0.toRadixString(16).padLeft(4, '0');
  // 去掉整数的前导零。
  var i = 0;
  while (i < full.length - 1 && full.codeUnitAt(i) == 0x30) {
    i++;
  }
  return (neg ? '-' : '') + full.substring(i);
}
