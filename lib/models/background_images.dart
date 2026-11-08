// lib/models/background_images.dart

/// Highest background image number probed by the pickers (`bg_1.png` …
/// `bg_16.png`). Add more files to `assets/backgrounds/` and raise this limit
/// if needed; no other code change is required.
const int kMaxBackgroundImageNumber = 16;

/// Resolves the asset path for a stored background image index.
///
/// Index `-1` means "no background image". New values are the file number
/// (`1` → `bg_1.png`). Legacy values were zero-based positions in the list of
/// available images; since `bg_0.png` does not exist, `0` maps to `bg_1.png`.
String? noteBackgroundImagePath(int index) {
  if (index < 0) return null;
  final number = index == 0 ? 1 : index;
  return 'assets/backgrounds/bg_$number.png';
}

/// Normalizes a stored index to the file number (legacy `0` → `1`).
int normalizedBackgroundImageIndex(int index) => index == 0 ? 1 : index;
