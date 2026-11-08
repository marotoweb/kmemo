// lib/models/background_images.dart

import 'package:flutter/services.dart' show AssetManifest, rootBundle;

/// Supported image extensions, in resolution priority order.
const List<String> _backgroundExtensions = [
  'png',
  'jpg',
  'jpeg',
  'webp',
  'avif',
  'gif',
  'bmp',
];

final RegExp _backgroundPattern = RegExp(
  r'^assets/backgrounds/bg_(\d+)\.([a-zA-Z0-9]+)$',
);

final Map<int, String> _backgroundPaths = {};

/// Discovers `assets/backgrounds/bg_<n>.<ext>` from the asset manifest and
/// caches the paths. Call once at startup (before `runApp`) so cards resolve
/// synchronously. Any image format listed in [_backgroundExtensions] is picked
/// up automatically; adding a file to `assets/backgrounds/` is enough.
Future<void> loadNoteBackgroundImages() async {
  _backgroundPaths.clear();
  final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);

  // number -> extension -> asset path.
  final candidates = <int, Map<String, String>>{};
  for (final asset in manifest.listAssets()) {
    final match = _backgroundPattern.firstMatch(asset);
    if (match == null) continue;
    final number = int.tryParse(match.group(1)!);
    if (number == null || number < 1) continue;
    final extension = match.group(2)!.toLowerCase();
    if (!_backgroundExtensions.contains(extension)) continue;
    candidates.putIfAbsent(number, () => {})[extension] = asset;
  }

  for (final entry in candidates.entries) {
    for (final extension in _backgroundExtensions) {
      final path = entry.value[extension];
      if (path != null) {
        _backgroundPaths[entry.key] = path;
        break;
      }
    }
  }
}

/// Available background image numbers, ascending.
List<int> get noteBackgroundNumbers =>
    _backgroundPaths.keys.toList(growable: false)..sort();

/// Resolves the asset path for a stored background image index.
///
/// Index `-1` means "no background image". New values are the file number
/// (`1` → `bg_1.*`). Legacy values were zero-based positions in the list of
/// available images; since `bg_0.*` does not exist, `0` maps to `bg_1.*`.
String? noteBackgroundImagePath(int index) {
  if (index < 0) return null;
  final number = index == 0 ? 1 : index;
  return _backgroundPaths[number];
}

/// Normalizes a stored index to the file number (legacy `0` → `1`).
int normalizedBackgroundImageIndex(int index) => index == 0 ? 1 : index;
