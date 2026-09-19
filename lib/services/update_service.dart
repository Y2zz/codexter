import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../app_info.dart';
import '../utils/win_kill_job.dart';

typedef UpdateProgress = void Function(double? fraction);

class AppUpdateInfo {
  final String version;
  final String tag;
  final String installerUrl;
  final String installerSha256;
  final String platform;
  final String? releaseUrl;
  final DateTime? publishedAt;

  const AppUpdateInfo({
    required this.version,
    required this.tag,
    required this.installerUrl,
    required this.installerSha256,
    required this.platform,
    this.releaseUrl,
    this.publishedAt,
  });

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json, {String? platformKey}) {
    final key = platformKey ?? _defaultPlatformKey;
    final block = json[key];
    if (block is! Map) {
      throw FormatException('更新清单缺少 $key 安装包信息');
    }
    final version = '${json['version'] ?? ''}'.trim();
    final installerUrl = '${block['installer_url'] ?? block['portable_url'] ?? ''}'.trim();
    final installerSha256 = '${block['installer_sha256'] ?? block['portable_sha256'] ?? ''}'.trim();
    if (version.isEmpty || installerUrl.isEmpty || installerSha256.isEmpty) {
      throw const FormatException('更新清单字段不完整');
    }
    return AppUpdateInfo(
      version: version,
      tag: '${json['tag'] ?? 'v$version'}'.trim(),
      installerUrl: installerUrl,
      installerSha256: installerSha256.toLowerCase(),
      platform: key,
      releaseUrl: '${json['release_url'] ?? ''}'.trim().isEmpty
          ? null
          : '${json['release_url']}'.trim(),
      publishedAt: DateTime.tryParse('${json['published_at'] ?? ''}'),
    );
  }

  static String get _defaultPlatformKey {
    if (Platform.isWindows) return 'windows';
    if (Platform.isMacOS) return 'macos';
    throw UnsupportedError('当前平台不支持应用内更新');
  }
}

class UpdateCheckResult {
  final String currentVersion;
  final AppUpdateInfo latest;

  const UpdateCheckResult({required this.currentVersion, required this.latest});

  bool get hasUpdate => AppUpdateService.compareVersions(latest.version, currentVersion) > 0;
}

class AppUpdateService {
  AppUpdateService([this._manifestUrl = appUpdateManifestUrl]);

  final String _manifestUrl;

  Future<UpdateCheckResult> check() async {
    final currentVersion = await AppRuntimeInfo.version;
    final data = await _fetchJson(Uri.parse(_manifestUrl));
    return UpdateCheckResult(currentVersion: currentVersion, latest: AppUpdateInfo.fromJson(data));
  }

  Future<File> downloadInstaller(AppUpdateInfo update, {UpdateProgress? onProgress}) async {
    if (!Platform.isWindows && !Platform.isMacOS) {
      throw UnsupportedError('当前平台不支持自动下载更新');
    }

    final uri = Uri.parse(update.installerUrl);
    final client = _client();
    try {
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.userAgentHeader, '$appName Updater');
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('下载更新失败（HTTP ${response.statusCode}）', uri: uri);
      }

      final tempDir = await getTemporaryDirectory();
      final filename = Platform.isWindows
          ? '$appName-${update.version}-Setup.exe'
          : p.basename(uri.path).isEmpty
          ? '$appName-${update.version}-macos.zip'
          : p.basename(uri.path);
      final file = File(p.join(tempDir.path, filename));
      if (await file.exists()) await file.delete();

      final sink = file.openWrite();
      var received = 0;
      final total = response.contentLength > 0 ? response.contentLength : null;
      try {
        await for (final chunk in response) {
          sink.add(chunk);
          received += chunk.length;
          onProgress?.call(total == null ? null : received / total);
        }
      } finally {
        await sink.close();
      }

      final digest = await sha256.bind(file.openRead()).first;
      if (digest.toString().toLowerCase() != update.installerSha256) {
        await file.delete();
        throw const FormatException('安装包校验失败，请重新下载');
      }
      onProgress?.call(1);
      return file;
    } finally {
      client.close(force: true);
    }
  }

  Future<void> launchInstaller(File installer) async {
    if (Platform.isWindows) {
      // 使用 Windows 官方 Job breakaway 机制，确保 Codexter 退出后 Setup 继续运行。
      await WinKillOnCloseJob.launchBreakaway(installer.path);
      return;
    }
    if (Platform.isMacOS) {
      final result = await Process.run('open', [installer.path]);
      if (result.exitCode != 0) {
        throw ProcessException('open', [installer.path], '无法打开更新包');
      }
      return;
    }
    throw UnsupportedError('当前平台不支持自动安装更新');
  }

  Future<Map<String, dynamic>> _fetchJson(Uri uri) async {
    final client = _client();
    try {
      final request = await client.getUrl(uri);
      request.headers
        ..set(HttpHeaders.acceptHeader, 'application/json')
        ..set(HttpHeaders.userAgentHeader, '$appName Updater');
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('检查更新失败（HTTP ${response.statusCode}）', uri: uri);
      }
      final text = await utf8.decoder.bind(response).join();
      final decoded = jsonDecode(text);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('更新清单格式错误');
      }
      return decoded;
    } finally {
      client.close(force: true);
    }
  }

  HttpClient _client() => HttpClient()
    ..connectionTimeout = const Duration(seconds: 15)
    ..idleTimeout = const Duration(seconds: 15);

  static int compareVersions(String left, String right) {
    final a = _parseVersion(left);
    final b = _parseVersion(right);
    final length = a.length > b.length ? a.length : b.length;
    for (var i = 0; i < length; i++) {
      final av = i < a.length ? a[i] : 0;
      final bv = i < b.length ? b[i] : 0;
      if (av != bv) return av.compareTo(bv);
    }
    return 0;
  }

  static List<int> _parseVersion(String value) {
    final core = value.trim().replaceFirst(RegExp(r'^[vV]'), '').split('-').first;
    return core
        .split('.')
        .map((part) => int.tryParse(part.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
        .toList(growable: false);
  }
}
