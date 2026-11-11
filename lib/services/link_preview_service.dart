// lib/services/link_preview_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Metadata shown in a link preview card.
/// [localImagePath] points to a locally cached image file; rendering must use
/// it (never the remote [imageUrl]) to avoid unexpected network requests.
class LinkPreview {
  final String title;
  final String? imageUrl;
  final String siteName;
  final String? localImagePath;

  const LinkPreview({
    required this.title,
    this.imageUrl,
    required this.siteName,
    this.localImagePath,
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

  /// Cache schema version.
  /// v1: raw HTML-encoded text. v2: decoded entities. v3: adds local image file.
  static const int _cacheVersion = 3;

  // In-memory caches warmed by [preload]. Cards read them synchronously so a
  // preview never appears after the card was laid out (which made the list
  // jump while scrolling).
  static final Map<String, LinkPreview> _previewCache = {};
  static final Map<String, Set<String>> _removedCache = {};
  static bool _preloaded = false;

  /// Loads every cached preview and removed-URL set into memory once, at
  /// startup, so card builds never wait on SharedPreferences.
  static Future<void> preload() async {
    if (_preloaded) return;
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys()) {
      if (key.startsWith('link_preview_')) {
        final raw = prefs.getString(key);
        if (raw == null) continue;
        final preview = _decodePreview(null, raw);
        if (preview != null) _previewCache[key] = preview;
      } else if (key.startsWith('link_removed_')) {
        final memoUuid = key.substring('link_removed_'.length);
        _removedCache[memoUuid] = (prefs.getStringList(key) ?? []).toSet();
      }
    }
    _preloaded = true;
  }

  /// Synchronous preview lookup for widget builds. Returns null until
  /// [preload] has run or the preview was fetched in this session.
  static LinkPreview? cachedPreviewSync(String url) => _previewCache[_cacheKey(url)];

  /// Synchronous removed-URL check for widget builds.
  static bool isRemovedSync(String memoUuid, String url) =>
      _removedCache[memoUuid]?.contains(url) ?? false;

  static LinkPreview? _decodePreview(String? fallbackUrl, String raw) {
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      // Older cache entries stored raw HTML-encoded text; decode them on read
      // so existing previews are fixed without a new network request.
      final needsDecode = (j['v'] as int? ?? 1) < 2;
      String decode(String value) =>
          needsDecode ? decodeHtmlEntities(value) : value;
      final cachedImage = j['image'] as String?;
      final cachedImagePath = j['imagePath'] as String?;
      final fallback = fallbackUrl ?? '';
      return LinkPreview(
        title: decode(j['title'] as String? ?? fallback),
        imageUrl: cachedImage == null ? null : decode(cachedImage),
        siteName: decode(
          j['site'] as String? ??
              Uri.tryParse(fallback)?.host ??
              fallback,
        ),
        localImagePath:
            (cachedImagePath != null && cachedImagePath.isNotEmpty)
            ? cachedImagePath
            : null,
      );
    } catch (_) {
      return null;
    }
  }

  /// Returns the cached preview for [url], or null if none was saved.
  /// Only local cache is read; no network requests are made.
  static Future<LinkPreview?> loadCached(String url) async {
    final key = _cacheKey(url);
    final cached = _previewCache[key];
    if (cached != null) return cached;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) return null;
    final preview = _decodePreview(url, raw);
    if (preview != null) _previewCache[key] = preview;
    return preview;
  }

  /// Downloads metadata for [url] (Open Graph), caches it and returns it.
  /// Also caches the OG image locally (explicit user action only) so displaying
  /// a cached preview never triggers network requests.
  static Future<LinkPreview> fetchAndCache(String url) async {
    final uri = Uri.parse(url);
    String title = uri.host;
    String? image;
    String site = uri.host;
    try {
      final resp = await http
          .get(uri, headers: {'User-Agent': 'kMemo'})
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final body = resp.body;
        final ogTitle = _meta(body, 'og:title');
        if (ogTitle != null) {
          title = ogTitle;
        } else {
          final t =
              RegExp(r'<title[^>]*>([^<]+)</title>', caseSensitive: false)
                  .firstMatch(body);
          if (t != null) title = decodeHtmlEntities(t.group(1)!.trim());
        }
        final rawImage = _meta(body, 'og:image');
        if (rawImage != null && rawImage.isNotEmpty) {
          image = Uri.tryParse(rawImage)?.hasScheme == true
              ? rawImage
              : uri.resolve(rawImage).toString();
        }
        site = _meta(body, 'og:site_name') ?? site;
      }
    } catch (_) {
      // Fall back to host-only preview below.
    }
    String? localImagePath;
    if (image != null) {
      localImagePath = await _cacheImage(image);
    }
    final preview = LinkPreview(
      title: title,
      imageUrl: image,
      siteName: site,
      localImagePath: localImagePath,
    );
    // Make the new preview available to the next synchronous card build.
    _previewCache[_cacheKey(url)] = preview;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _cacheKey(url),
      jsonEncode({
        'title': title,
        'image': image,
        'imagePath': localImagePath,
        'site': site,
        'v': _cacheVersion,
      }),
    );
    return preview;
  }

  static Future<Directory> _imageCacheDir() async {
    final base = await getTemporaryDirectory();
    final dir = Directory(p.join(base.path, 'link_previews'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Downloads [imageUrl] into the local cache (explicit action only).
  /// Returns the local file path, or null on failure. Never throws.
  static Future<String?> _cacheImage(String imageUrl) async {
    try {
      final uri = Uri.tryParse(imageUrl);
      if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
        return null;
      }
      final resp = await http
          .get(uri, headers: {'User-Agent': 'kMemo'})
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200 || resp.bodyBytes.isEmpty) return null;
      // Avoid caching excessively large images.
      if (resp.bodyBytes.length > 3 * 1024 * 1024) return null;
      final dir = await _imageCacheDir();
      final ext = _imageExtension(resp.headers['content-type'], imageUrl);
      final name =
          'img_${imageUrl.hashCode.toRadixString(16)}_${DateTime.now().microsecondsSinceEpoch.toRadixString(16)}$ext';
      final file = File(p.join(dir.path, name));
      await file.writeAsBytes(resp.bodyBytes, flush: true);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  static String _imageExtension(String? contentType, String imageUrl) {
    final ct = (contentType ?? '').toLowerCase();
    if (ct.contains('png')) return '.png';
    if (ct.contains('webp')) return '.webp';
    if (ct.contains('gif')) return '.gif';
    if (ct.contains('svg')) return '.svg';
    if (ct.contains('jpeg') || ct.contains('jpg')) return '.jpg';
    final lower = imageUrl.toLowerCase();
    for (final ext in ['.png', '.webp', '.gif', '.jpg', '.jpeg', '.svg']) {
      if (lower.contains(ext)) return ext == '.jpeg' ? '.jpg' : ext;
    }
    return '.jpg';
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
    final cached = _removedCache[memoUuid];
    if (cached != null) return cached;
    final prefs = await SharedPreferences.getInstance();
    final removed = (prefs.getStringList(_removedKey(memoUuid)) ?? []).toSet();
    _removedCache[memoUuid] = removed;
    return removed;
  }

  static Future<void> saveRemoved(String memoUuid, Set<String> urls) async {
    if (urls.isEmpty) {
      _removedCache.remove(memoUuid);
    } else {
      _removedCache[memoUuid] = Set<String>.from(urls);
    }
    final prefs = await SharedPreferences.getInstance();
    if (urls.isEmpty) {
      await prefs.remove(_removedKey(memoUuid));
    } else {
      await prefs.setStringList(_removedKey(memoUuid), urls.toList());
    }
  }
}
