// lib/services/link_preview_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Metadata shown in a link preview card.
class LinkPreview {
  final String title;
  final String? imageUrl;
  final String siteName;

  const LinkPreview({
    required this.title,
    this.imageUrl,
    required this.siteName,
  });
}

/// Fetches, caches and restores link previews.
/// Previews are only fetched on explicit user action; cached data is local only.
class LinkPreviewService {
  static final RegExp _urlRegex = RegExp(r'https?://[^\s]+', caseSensitive: false);

  static Iterable<RegExpMatch> matches(String text) => _urlRegex.allMatches(text);

  static List<String> extractUrls(String text) {
    final seen = <String>{};
    final urls = <String>[];
    for (final m in _urlRegex.allMatches(text)) {
      final url = m.group(0)!;
      if (seen.add(url)) urls.add(url);
    }
    return urls;
  }

  static String _cacheKey(String url) => 'link_preview_${url.hashCode}';

  static String _removedKey(String memoUuid) => 'link_removed_$memoUuid';

  /// Returns the cached preview for [url], or null if none was saved.
  static Future<LinkPreview?> loadCached(String url) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey(url));
    if (raw == null) return null;
    final j = jsonDecode(raw) as Map<String, dynamic>;
    return LinkPreview(
      title: j['title'] as String? ?? url,
      imageUrl: j['image'] as String?,
      siteName: j['site'] as String? ?? Uri.tryParse(url)?.host ?? url,
    );
  }

  /// Downloads metadata for [url] (Open Graph), caches it and returns it.
  static Future<LinkPreview> fetchAndCache(String url) async {
    final uri = Uri.parse(url);
    String title = uri.host;
    String? image;
    String site = uri.host;
    try {
      final resp = await http.get(uri).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final body = resp.body;
        final ogTitle = _meta(body, 'og:title');
        if (ogTitle != null) {
          title = ogTitle;
        } else {
          final t = RegExp(r'<title[^>]*>([^<]+)</title>', caseSensitive: false)
              .firstMatch(body);
          if (t != null) title = t.group(1)!.trim();
        }
        image = _meta(body, 'og:image');
        site = _meta(body, 'og:site_name') ?? site;
      }
    } catch (_) {
      // Fall back to host-only preview below.
    }
    final preview = LinkPreview(title: title, imageUrl: image, siteName: site);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _cacheKey(url),
      jsonEncode({'title': title, 'image': image, 'site': site}),
    );
    return preview;
  }

  static String? _meta(String html, String property) {
    final re = RegExp(
      '<meta[^>]+property=["\']$property["\'][^>]+content=["\']([^"\']+)["\']',
      caseSensitive: false,
    );
    return re.firstMatch(html)?.group(1);
  }

  /// URLs the user removed the preview card for, per note.
  static Future<Set<String>> loadRemoved(String memoUuid) async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_removedKey(memoUuid)) ?? []).toSet();
  }

  static Future<void> saveRemoved(String memoUuid, Set<String> urls) async {
    final prefs = await SharedPreferences.getInstance();
    if (urls.isEmpty) {
      await prefs.remove(_removedKey(memoUuid));
    } else {
      await prefs.setStringList(_removedKey(memoUuid), urls.toList());
    }
  }
}
