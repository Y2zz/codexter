import 'package:codexter/services/update_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AppUpdateInfo 解析 macos 字段', () {
    final info = AppUpdateInfo.fromJson({
      'version': '1.0.7',
      'tag': 'v1.0.7',
      'release_url': 'https://github.com/meesii/codexter/releases/tag/v1.0.7',
      'macos': {
        'installer_url':
            'https://github.com/meesii/codexter/releases/download/v1.0.7/Codexter-1.0.7-macos-arm64.zip',
        'installer_sha256': 'abc123',
      },
    }, platformKey: 'macos');

    expect(info.version, '1.0.7');
    expect(info.platform, 'macos');
    expect(info.installerUrl, contains('macos-arm64.zip'));
    expect(info.installerSha256, 'abc123');
  });

  test('AppUpdateInfo 缺少平台块时抛错', () {
    expect(
      () => AppUpdateInfo.fromJson({'version': '1.0.7'}, platformKey: 'macos'),
      throwsA(isA<FormatException>()),
    );
  });
}
