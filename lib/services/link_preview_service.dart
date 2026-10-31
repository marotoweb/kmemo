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

  /// Cache schema version. Entries below this need entity decoding on read.
  static const int _cacheVersion = 2;

  /// Returns the cached preview for [url], or null if none was saved.
  static Future<LinkPreview?> loadCached(String url) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey(url));
    if (raw == null) return null;
    final j = jsonDecode(raw) as Map<String, dynamic>;
    // Older cache entries stored raw HTML-encoded text; decode them on read so
    // existing previews are fixed without a new network request.
    final needsDecode = (j['v'] as int? ?? 1) < _cacheVersion;
    String decode(String value) =>
        needsDecode ? decodeHtmlEntities(value) : value;
    final cachedImage = j['image'] as String?;
    return LinkPreview(
      title: decode(j['title'] as String? ?? url),
      imageUrl: cachedImage == null ? null : decode(cachedImage),
      siteName: decode(
        j['site'] as String? ?? Uri.tryParse(url)?.host ?? url,
      ),
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
          if (t != null) title = decodeHtmlEntities(t.group(1)!.trim());
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
      jsonEncode({
        'title': title,
        'image': image,
        'site': site,
        'v': _cacheVersion,
      }),
    );
    return preview;
  }

  static String? _meta(String html, String property) {
    final p = RegExp.escape(property);
    // `content` may appear before or after `property`/`name` in the tag.
    final patterns = [
      '<meta[^>]+(?:property|name)=["\']$p["\'][^>]+content=["\']([^"\']+)["\']',
      '<meta[^>]+content=["\']([^"\']+)["\'][^>]+(?:property|name)=["\']$p["\']',
    ];
    for (final pattern in patterns) {
      final match =
          RegExp(pattern, caseSensitive: false).firstMatch(html);
      if (match != null) return decodeHtmlEntities(match.group(1)!);
    }
    return null;
  }

  static final RegExp _entityRegex = RegExp(
    r'&(#[xX][0-9a-fA-F]+|#[0-9]+|[a-zA-Z][a-zA-Z0-9]*);',
  );

  static const Map<String, String> _namedEntities = {
    'amp': '&',
    'lt': '<',
    'gt': '>',
    'quot': '"',
    'apos': "'",
    'nbsp': '\u00A0',
    'ndash': '\u2013',
    'mdash': '\u2014',
    'hellip': '\u2026',
    'lsquo': '\u2018',
    'rsquo': '\u2019',
    'ldquo': '\u201C',
    'rdquo': '\u201D',
    'laquo': '\u00AB',
    'raquo': '\u00BB',
    'copy': '\u00A9',
    'reg': '\u00AE',
    'trade': '\u2122',
    'euro': '\u20AC',
    'pound': '\u00A3',
    'deg': '\u00B0',
    'middot': '\u00B7',
    'bull': '\u2022',
  };

  /// Decodes HTML entities such as `&#xE1;`, `&#225;` or `&amp;`.
  /// Unknown or invalid entities are left untouched.
  static String decodeHtmlEntities(String input) {
    if (!input.contains('&')) return input;
    return input.replaceAllMapped(_entityRegex, (match) {
      final entity = match.group(1)!;
      if (entity.startsWith('#x') || entity.startsWith('#X')) {
        final code = int.tryParse(entity.substring(2), radix: 16);
        return _fromCodePoint(code) ?? match.group(0)!;
      }
      if (entity.startsWith('#')) {
        final code = int.tryParse(entity.substring(1));
        return _fromCodePoint(code) ?? match.group(0)!;
      }
      return _namedEntities[entity.toLowerCase()] ?? match.group(0)!;
    });
  }

  static String? _fromCodePoint(int? code) {
    if (code == null || code < 0 || code > 0x10FFFF) return null;
    // Reject the UTF-16 surrogate range, which is not a valid code point.
    if (code >= 0xD800 && code <= 0xDFFF) return null;
    return String.fromCharCode(code);
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
