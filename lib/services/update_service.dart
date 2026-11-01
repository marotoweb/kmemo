import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

/// Result of an in-app update check against the GitHub releases.
class UpdateInfo {
  final String currentVersion;
  final String latestVersion;
  final bool hasUpdate;
  final String releaseNotes;
  final String downloadUrl;
  final String releaseUrl;
  final String error;

  const UpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.hasUpdate,
    required this.releaseNotes,
    required this.downloadUrl,
    required this.releaseUrl,
    this.error = '',
  });
}

/// Checks GitHub releases for a newer version of kMemo.
class UpdateService {
  static const String _apiUrl =
      'https://api.github.com/repos/marotoweb/kmemo/releases/latest';

  Future<UpdateInfo> checkForUpdate() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;

    try {
      final response = await http
          .get(
            Uri.parse(_apiUrl),
            headers: <String, String>{
              'Accept': 'application/vnd.github+json',
              'User-Agent': 'kMemo/$currentVersion',
            },
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        return UpdateInfo(
          currentVersion: currentVersion,
          latestVersion: currentVersion,
          hasUpdate: false,
          releaseNotes: '',
          downloadUrl: '',
          releaseUrl: '',
          error: 'HTTP ${response.statusCode}',
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final tagName = (data['tag_name'] as String? ?? '').trim();
      final latestVersion =
          tagName.startsWith('v') ? tagName.substring(1) : tagName;
      final releaseNotes = (data['body'] as String? ?? '').trim();
      final releaseUrl = (data['html_url'] as String? ?? '').trim();

      String downloadUrl = '';
      final assets = data['assets'] as List<dynamic>? ?? const <dynamic>[];
      // Prefer an APK matching the device ABI; fall back to arm64-v8a, then first .apk.
      final apkAssets = assets
          .whereType<Map<String, dynamic>>()
          .where((a) => (a['name'] as String? ?? '').toLowerCase().endsWith('.apk'))
          .toList();
      if (apkAssets.isNotEmpty) {
        const preference = ['arm64-v8a', 'armeabi-v7a', 'x86_64'];
        for (final abi in preference) {
          for (final asset in apkAssets) {
            final name = (asset['name'] as String? ?? '').toLowerCase();
            if (name.contains(abi)) {
              downloadUrl = (asset['browser_download_url'] as String? ?? '').trim();
              break;
            }
          }
          if (downloadUrl.isNotEmpty) break;
        }
        if (downloadUrl.isEmpty) {
          downloadUrl = (apkAssets.first['browser_download_url'] as String? ?? '').trim();
        }
      }

      final hasUpdate = compareVersions(latestVersion, currentVersion) > 0;

      return UpdateInfo(
        currentVersion: currentVersion,
        latestVersion: latestVersion,
        hasUpdate: hasUpdate,
        releaseNotes: releaseNotes,
        downloadUrl: downloadUrl,
        releaseUrl: releaseUrl,
      );
    } catch (e) {
      return UpdateInfo(
        currentVersion: currentVersion,
        latestVersion: currentVersion,
        hasUpdate: false,
        releaseNotes: '',
        downloadUrl: '',
        releaseUrl: '',
        error: e.toString(),
      );
    }
  }

  /// Returns negative if [a] < [b], 0 if equal, positive if [a] > [b].
  static int compareVersions(String a, String b) {
    final pa = _parse(a);
    final pb = _parse(b);
    final len = pa.length > pb.length ? pa.length : pb.length;
    for (int i = 0; i < len; i++) {
      final va = i < pa.length ? pa[i] : 0;
      final vb = i < pb.length ? pb[i] : 0;
      if (va != vb) return va.compareTo(vb);
    }
    return 0;
  }

  static List<int> _parse(String v) {
    final cleaned = v.trim().toLowerCase().replaceAll(RegExp(r'^v'), '');
    final core = cleaned.split(RegExp(r'[-+]')).first;
    return core
        .split('.')
        .map((p) => int.tryParse(p.trim()) ?? 0)
        .toList();
  }
}
