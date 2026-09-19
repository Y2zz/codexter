import 'dart:io';

import 'package:codexter/utils/unix_path.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('UnixPath 注入 Homebrew 前缀且去重', () {
    if (Platform.isWindows) {
      expect(UnixPath.augmentedEnvironment({'PATH': r'C:\Windows'}), {'PATH': r'C:\Windows'});
      return;
    }

    final env = UnixPath.augmentedEnvironment({
      'PATH': '/usr/bin:/bin:/opt/homebrew/bin',
      'HOME': '/Users/demo',
    });
    final parts = env['PATH']!.split(':');
    expect(parts.first, '/opt/homebrew/bin');
    expect(parts.where((part) => part == '/opt/homebrew/bin').length, 1);
    expect(parts, contains('/usr/local/bin'));
    expect(parts, contains('/usr/bin'));
    expect(env['HOME'], '/Users/demo');
  });
}
