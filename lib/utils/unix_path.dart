import 'dart:io';

/// 补齐 GUI 启动时常见缺失的 Unix 工具路径（Homebrew 等）。
class UnixPath {
  UnixPath._();

  static const _extraPrefixes = <String>[
    '/opt/homebrew/bin',
    '/opt/homebrew/sbin',
    '/usr/local/bin',
    '/usr/local/sbin',
  ];

  /// 返回注入额外 PATH 后的环境变量副本。
  static Map<String, String> augmentedEnvironment([Map<String, String>? base]) {
    final env = Map<String, String>.from(base ?? Platform.environment);
    if (Platform.isWindows) return env;

    final current = env['PATH'] ?? '';
    final existing = current.split(':').where((part) => part.isNotEmpty).toList();
    final rest = existing.where((part) => !_extraPrefixes.contains(part)).toList();
    env['PATH'] = [..._extraPrefixes, ...rest].join(':');
    return env;
  }
}
