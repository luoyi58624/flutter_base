part of 'index.dart';

/// copyWith 三态哨兵(freezed 式):生成的 copyWith 参数以此为默认值——
/// 参数保持哨兵 = 未传参(保留原值);显式传 null = 真置空;传值 = 覆盖。
///
/// 仅供模型生成代码作参数默认值与 identical 判定，业务代码不要直接引用。
///
/// 注意与 merge 的分工:merge 是声明合并语义,other 侧字段为 null 表示
/// "未声明、保留本侧",与 copyWith 的显式 null 置空互不干扰。
const $absent = _A();

final class _A {
  const _A();
}
