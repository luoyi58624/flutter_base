part of 'index.dart';

/// 提供分级日志输出，统一过滤、格式化与调用方堆栈。
class ElLog {
  ElLog._();

  /// 打印日志
  ///
  /// [stackTrace] 的首帧必须是捕获者自身，输出堆栈时跳过首帧，使堆栈直接从日志调用方开始；
  /// 封装自定义日志入口时，在函数体内通过 StackTrace.current 捕获后传入即可隐藏封装层，
  /// 不传则在当前入口捕获
  static void printLog(
    dynamic message, {
    int level = ElLogConfig.info,
    dynamic title,
    ElLogConfig? config,
    StackTrace? stackTrace,
  }) {
    if (ElLogConfig.filterFun(level)) {
      config = ElLogConfig.defaultConfig.merge(config);
      config.formatAndPrint(
        level,
        message,
        title: title,
        stackTrace: stackTrace ?? StackTrace.current,
      );
    }
  }

  /// 输出最低级别日志
  static void d(
    dynamic message, {
    dynamic title,
    ElLogConfig? config,
    StackTrace? stackTrace,
  }) {
    printLog(
      message,
      level: ElLogConfig.debug,
      title: title,
      config: config,
      stackTrace: stackTrace ?? StackTrace.current,
    );
  }

  /// 输出普通级别日志
  static void i(
    dynamic message, {
    dynamic title,
    ElLogConfig? config,
    StackTrace? stackTrace,
  }) {
    printLog(
      message,
      level: ElLogConfig.info,
      title: title,
      config: config,
      stackTrace: stackTrace ?? StackTrace.current,
    );
  }

  /// 输出成功类型日志
  static void s(
    dynamic message, {
    dynamic title,
    ElLogConfig? config,
    StackTrace? stackTrace,
  }) {
    printLog(
      message,
      level: ElLogConfig.success,
      title: title,
      config: config,
      stackTrace: stackTrace ?? StackTrace.current,
    );
  }

  /// 输出警告类型日志
  static void w(
    dynamic message, {
    dynamic title,
    ElLogConfig? config,
    StackTrace? stackTrace,
  }) {
    printLog(
      message,
      level: ElLogConfig.warning,
      title: title,
      config: config,
      stackTrace: stackTrace ?? StackTrace.current,
    );
  }

  /// 输出错误类型日志
  static void e(
    dynamic message, {
    dynamic title,
    ElLogConfig? config,
    StackTrace? stackTrace,
  }) {
    printLog(
      message,
      level: ElLogConfig.error,
      title: title,
      config: config,
      stackTrace: stackTrace ?? StackTrace.current,
    );
  }
}

/// 日志配置对象
class ElLogConfig {
  // 日志级别静态常量，之所以不使用 logger 提供的 enum，是因为它不提供 success 状态
  /// 所有日志级别的起始值。
  static const all = 0;

  /// 调试日志级别。
  static const debug = 1000;

  /// 普通日志级别。
  static const info = 2000;

  /// 成功日志级别。
  static const success = 2001;

  /// 警告日志级别。
  static const warning = 3000;

  /// 错误日志级别。
  static const error = 4000;

  /// 默认日志配置对象
  static ElLogConfig defaultConfig = const ElLogConfig(
    methodCount: bool.fromEnvironment('dart.library.js_interop') ? null : 2,
    lineLength: bool.fromEnvironment('dart.library.js_interop') ? null : 120,
    printTitle: !bool.fromEnvironment('dart.library.js_interop'),
    autoWrap: true,
    levelColors: defaultLevelColors,
  );

  /// 日志过滤函数
  static bool Function(int level) filterFun = (int level) {
    if (const bool.fromEnvironment('dart.vm.product')) {
      return level >= warning;
    } else {
      return true;
    }
  };

  /// 创建日志格式配置，未设置的选项由默认配置补齐。
  const ElLogConfig({
    this.methodCount,
    this.lineLength,
    this.printTitle,
    this.color,
    this.autoWrap,
    this.levelColors,
  });

  /// 限制方法执行的堆栈数量
  final int? methodCount;

  /// 日志分隔线长度，如果长度为 0，则不绘制任何线条
  final int? lineLength;

  /// 是否打印标题
  final bool? printTitle;

  /// 自定义日志终端颜色
  final AnsiColor? color;

  /// 打印可迭代集合对象时是否自动换行
  final bool? autoWrap;

  /// 不同级别日志对应的颜色集合
  final Map<int, AnsiColor>? levelColors;

  /// 各日志级别的默认终端颜色。
  static const defaultLevelColors = {
    debug: AnsiColor.none(),
    info: AnsiColor.fg(12),
    success: AnsiColor.fg(34),
    warning: AnsiColor.fg(208),
    error: AnsiColor.fg(196),
  };

  /// 克隆新的日志配置
  ElLogConfig copyWith({
    int? methodCount,
    int? lineLength,
    bool? printTitle,
    AnsiColor? color,
    bool? autoWrap,
    Map<int, AnsiColor>? levelColors,
  }) {
    return ElLogConfig(
      methodCount: methodCount ?? this.methodCount,
      lineLength: lineLength ?? this.lineLength,
      printTitle: printTitle ?? this.printTitle,
      color: color ?? this.color,
      autoWrap: autoWrap ?? this.autoWrap,
      levelColors: levelColors == null
          ? this.levelColors
          : {...this.levelColors ?? {}, ...levelColors},
    );
  }

  /// 合并新的日志配置
  ElLogConfig merge([ElLogConfig? other]) {
    if (other == null) return this;
    return copyWith(
      methodCount: other.methodCount,
      lineLength: other.lineLength,
      printTitle: other.printTitle,
      color: other.color,
      autoWrap: other.autoWrap,
    );
  }

  /// 日志框的顶部边界。
  String get topBorder {
    assert(lineLength != null && lineLength! > 0);
    return '${PrettyPrinter.topLeftCorner}${PrettyPrinter.doubleDivider * lineLength!}';
  }

  /// 日志框的分隔边界。
  String get middleBorder {
    assert(lineLength != null && lineLength! > 0);
    return '${PrettyPrinter.middleCorner}${PrettyPrinter.singleDivider * lineLength!}';
  }

  /// 日志框的底部边界。
  String get bottomBorder {
    assert(lineLength != null && lineLength! > 0);
    return '${PrettyPrinter.bottomLeftCorner}${PrettyPrinter.doubleDivider * lineLength!}';
  }

  /// 日志正文的左侧边界。
  String get verticalLineAtLevel {
    return '${PrettyPrinter.verticalLine} ';
  }

  /// 以当前配置对象格式化打印日志
  ///
  /// [stackTrace] 的首帧必须是捕获者自身（即在你的函数体内通过 StackTrace.current 捕获后传入），
  /// 输出堆栈时会跳过首帧，使堆栈直接从日志调用方开始；为 null 时在 [formatStackTrace] 中捕获
  void formatAndPrint(
    int level,
    dynamic message, {
    dynamic title,
    StackTrace? stackTrace,
  }) {
    List<String> buffer = [];
    final stacktrace = formatStackTrace(stackTrace);
    final color = this.color ?? levelColors?[level] ?? const AnsiColor.none();

    if (lineLength == null || lineLength! <= 0) {
      void addBuffer(String content) {
        for (var line in content.split('\n')) {
          buffer.add(color(line));
        }
      }

      if (printTitle == true && title != null) addBuffer(title.toString());
      if (stacktrace != null) addBuffer(stacktrace);
      addBuffer(stringifyMessage(message));
    } else {
      final verticalLineAtLevel = this.verticalLineAtLevel;

      void addBuffer(String content) {
        for (var line in content.split('\n')) {
          buffer.add(color('$verticalLineAtLevel$line'));
        }
      }

      buffer.add(color(topBorder));

      if (printTitle == true && title != null) {
        addBuffer(title.toString());
        buffer.add(color(middleBorder));
      }

      if (stacktrace != null) {
        addBuffer(stacktrace);
        buffer.add(color(middleBorder));
      }

      addBuffer(stringifyMessage(message));
      buffer.add(color(bottomBorder));
    }

    // 日志已完成过滤和格式化，直接输出到当前 Zone，允许调用方接管终端输出。
    // ignore: avoid_print
    buffer.forEach(print);
  }

  /// 格式化消息内容
  String stringifyMessage(dynamic message) {
    final finalMessage = message is Function ? message() : message;
    if (finalMessage is Map || finalMessage is Iterable) {
      late JsonEncoder encoder;

      if (autoWrap == true) {
        encoder = JsonEncoder.withIndent('  ', toEncodableFallback);
      } else {
        encoder = JsonEncoder(toEncodableFallback);
      }

      return encoder.convert(finalMessage);
    } else {
      return finalMessage.toString();
    }
  }

  /// 将无法直接编码为 JSON 的对象转换为字符串。
  Object toEncodableFallback(dynamic object) {
    return object.toString();
  }

  /// 格式化方法执行堆栈
  ///
  /// [stackTrace] 的首帧必须是捕获者自身，格式化时跳过首帧，使堆栈直接从日志调用方开始，
  /// 因此无需维护任何过滤路径清单；为 null 时在此捕获（首帧为本方法，同样被跳过）
  String? formatStackTrace([StackTrace? stackTrace]) {
    if (methodCount == null || methodCount! <= 0) return null;

    List<String> formatted = [];
    List<String> lines = (stackTrace ?? StackTrace.current)
        .toString()
        .split('\n')
        .skip(1)
        .where((line) => !_isSdkLine(line) && line.isNotEmpty)
        .toList();

    int stackTraceLength = math.min(lines.length, methodCount!);
    for (int count = 0; count < stackTraceLength; count++) {
      var line = lines[count];
      formatted.add('#$count   ${line.replaceFirst(RegExp(r'#\d+\s+'), '')}');
    }

    if (formatted.isEmpty) {
      return null;
    } else {
      return formatted.join('\n');
    }
  }

  /// web 端 StackTrace.current 自身会携带 sdk 内部帧，输出时丢弃
  static bool _isSdkLine(String line) {
    return line.startsWith('dart-sdk/lib') || line.startsWith('dart:');
  }

  @override
  String toString() {
    return 'ElLogConfig{methodCount: $methodCount, lineLength: $lineLength, printTitle: $printTitle, color: $color, autoWrap: $autoWrap, levelColors: $levelColors}';
  }
}

/// 自定义日志输出函数的签名。
typedef ElLogFunction = void Function(
  dynamic message, {
  dynamic title,
  ElLogConfig? config,
  StackTrace? stackTrace,
});
