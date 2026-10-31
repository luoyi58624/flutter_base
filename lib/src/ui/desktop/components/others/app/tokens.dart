part of 'index.dart';

// 默认值表沿用旧 ElApp.tokens，通用键与移动端共享，阴影保留既有几何。
final Map<Object, Object> _lightVars = Map.unmodifiable({
  ...ElTheme.lightVars,
  ElDesktopTheme.$compact: false,
  for (final entry in _shadowLevelsLight.entries)
    switch (entry.key) {
      ElLevelType.xs => ElTheme.$shadowXs,
      ElLevelType.sm => ElTheme.$shadowSm,
      ElLevelType.md => ElTheme.$shadowMd,
      ElLevelType.lg => ElTheme.$shadowLg,
      ElLevelType.xl => ElTheme.$shadowXl,
    }: List<BoxShadow>.unmodifiable(
      entry.value,
    ),
});

final Map<Object, Object> _darkVars = Map.unmodifiable({
  ...ElTheme.darkVars,
  for (final entry in _shadowLevelsDark.entries)
    switch (entry.key) {
      ElLevelType.xs => ElTheme.$shadowXs,
      ElLevelType.sm => ElTheme.$shadowSm,
      ElLevelType.md => ElTheme.$shadowMd,
      ElLevelType.lg => ElTheme.$shadowLg,
      ElLevelType.xl => ElTheme.$shadowXl,
    }: List<BoxShadow>.unmodifiable(
      entry.value,
    ),
});
