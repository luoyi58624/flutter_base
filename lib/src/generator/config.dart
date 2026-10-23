class ModelTemplateConfig {
  static late ModelTemplateConfig instance;

  /// 声明扩展后缀，默认 Ext
  final String extSuffix;

  ModelTemplateConfig._({required this.extSuffix});

  factory ModelTemplateConfig(Map<String, dynamic> config) {
    return ModelTemplateConfig._(extSuffix: config['ext_suffix'] ?? 'Ext');
  }
}
