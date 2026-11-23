// lib/services/image_attachment_service.dart

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// What went wrong while importing a photo.
enum ImageAttachmentError { unsupported, tooLarge, unreadable }

class ImageAttachmentException implements Exception {
  const ImageAttachmentException(this.error);

  final ImageAttachmentError error;
}

/// Dimensions and format of a picked file, read from its header.
class ImageProbe {
  const ImageProbe({
    required this.width,
    required this.height,
    required this.isPng,
  });

  final int width;
  final int height;
  final bool isPng;
}

/// A photo already stored inside the app.
class ImportedImage {
  const ImportedImage({
    required this.relativePath,
    required this.width,
    required this.height,
  });

  /// Path stored in `Memos.imageAttachments`, relative to the app support
  /// folder so it survives a move of the app data and can travel in the sync
  /// payload.
  final String relativePath;
  final int width;
  final int height;
}

/// Imports photos into the app: validates, sanitises with a re-encode and
/// stores the result with a thumbnail.
///
/// Every image is decoded and re-encoded even when it is not resized: the
/// re-encode is what strips EXIF (GPS, device, date) and any other metadata.
/// The original file is never stored. See the image pipeline rules in the
/// developer guide.
class ImageAttachmentService {
  static const int maxFileBytes = 50 * 1024 * 1024;
  static const int maxPixels = 24 * 1000 * 1000;
  static const int thumbnailSide = 300;
  static const int jpegQuality = 85;

  static const List<int> _pngSignature = <int>[
    0x89,
    0x50,
    0x4E,
    0x47,
    0x0D,
    0x0A,
    0x1A,
    0x0A,
  ];

  final Uuid _uuid = const Uuid();
  String? _baseDir;

  /// Resolves and caches the folder that holds the attachments.
  Future<String> ensureBaseDir() async {
    return _baseDir ??= (await getApplicationSupportDirectory()).path;
  }

  /// Absolute path for a value stored in `Memos.imageAttachments`.
  ///
  /// Older values may be absolute paths; they are returned untouched.
  String resolve(String stored) {
    if (p.isAbsolute(stored) || _baseDir == null) return stored;
    return p.join(_baseDir!, stored);
  }

  /// Absolute path of the thumbnail that belongs to [stored].
  String thumbnailPath(String stored) {
    final absolute = resolve(stored);
    final extension = p.extension(absolute);
    if (extension.isEmpty) return '${absolute}_thumb.jpg';
    return '${absolute.substring(0, absolute.length - extension.length)}'
        '_thumb.jpg';
  }

  /// Reads the dimensions from the file header without decoding the pixels.
  Future<ImageProbe> probe(String path) async {
    final bytes = await _read(path);
    return _probeBytes(bytes);
  }

  /// Validates, re-encodes and stores the photo of [sourcePath].
  ///
  /// [resize] is decided by the caller from the settings and from the dialog,
  /// so this method never asks anything. When the photo fits the maximum side
  /// the value is ignored.
  Future<ImportedImage> import({
    required String sourcePath,
    required String memoUuid,
    required int maxSide,
    required bool resize,
  }) async {
    final bytes = await _read(sourcePath);
    final probe = _probeBytes(bytes);
    final isPng = probe.isPng;

    final longest = probe.width > probe.height ? probe.width : probe.height;
    final shouldScale = resize && longest > maxSide;
    final target = shouldScale
        ? _fit(probe.width, probe.height, maxSide)
        : (width: probe.width, height: probe.height);

    final decoded = await _decode(bytes, target.width, target.height);
    try {
      final encoded = isPng
          ? Uint8List.fromList(img.encodePng(decoded))
          : Uint8List.fromList(
              img.encodeJpg(decoded, quality: jpegQuality),
            );
      final thumb = _thumbnail(decoded);
      final thumbBytes = Uint8List.fromList(
        img.encodeJpg(thumb, quality: 80),
      );

      final base = await ensureBaseDir();
      final folder = Directory(p.join(base, 'attachments', memoUuid));
      await folder.create(recursive: true);

      final id = _uuid.v4();
      final extension = isPng ? 'png' : 'jpg';
      final fileName = '$id.$extension';
      final absolute = p.join(folder.path, fileName);
      await File(absolute).writeAsBytes(encoded, flush: true);
      await File(
        p.join(folder.path, '${id}_thumb.jpg'),
      ).writeAsBytes(thumbBytes, flush: true);

      return ImportedImage(
        relativePath: p.join('attachments', memoUuid, fileName),
        width: decoded.width,
        height: decoded.height,
      );
    } finally {
      // The image package object holds the pixel buffer.
      decoded.clear();
    }
  }

  /// Removes every stored attachment.
  ///
  /// Used by the danger zone, where every local note disappears at once.
  Future<void> clearAll() async {
    try {
      final base = await ensureBaseDir();
      await Directory(p.join(base, 'attachments')).delete(recursive: true);
    } catch (_) {
      // Nothing stored yet, or the platform has no path provider (tests).
    }
  }

  /// Removes the photo and its thumbnail.
  Future<void> delete(String stored) async {
    for (final file in <String>[resolve(stored), thumbnailPath(stored)]) {
      try {
        await File(file).delete();
      } catch (_) {
        // Already gone, or no permission: the note must still save.
      }
    }
  }

  Future<Uint8List> _read(String path) async {
    final file = File(path);
    try {
      if (await file.length() > maxFileBytes) {
        throw const ImageAttachmentException(ImageAttachmentError.tooLarge);
      }
      return await file.readAsBytes();
    } on ImageAttachmentException {
      rethrow;
    } catch (_) {
      throw const ImageAttachmentException(ImageAttachmentError.unreadable);
    }
  }

  ImageProbe _probeBytes(Uint8List bytes) {
    final isPng = _hasPngSignature(bytes);
    final isJpeg =
        bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF;
    if (!isPng && !isJpeg) {
      throw const ImageAttachmentException(ImageAttachmentError.unsupported);
    }

    final decoder = img.findDecoderForData(bytes);
    final info = decoder?.startDecode(bytes);
    if (decoder == null || info == null) {
      throw const ImageAttachmentException(ImageAttachmentError.unsupported);
    }
    // Animated files are rejected: a note photo is a still image, and the
    // re-encode would silently keep only the first frame.
    if (info.numFrames > 1) {
      throw const ImageAttachmentException(ImageAttachmentError.unsupported);
    }
    if (info.width * info.height > maxPixels) {
      throw const ImageAttachmentException(ImageAttachmentError.tooLarge);
    }
    return ImageProbe(width: info.width, height: info.height, isPng: isPng);
  }

  bool _hasPngSignature(Uint8List bytes) {
    if (bytes.length < _pngSignature.length) return false;
    for (var i = 0; i < _pngSignature.length; i++) {
      if (bytes[i] != _pngSignature[i]) return false;
    }
    return true;
  }

  ({int width, int height}) _fit(int width, int height, int maxSide) {
    final longest = width > height ? width : height;
    final scale = maxSide / longest;
    return (
      width: (width * scale).round().clamp(1, maxSide),
      height: (height * scale).round().clamp(1, maxSide),
    );
  }

  /// Decodes at the requested size, so a huge photo never allocates its full
  /// pixel buffer. The engine also applies the EXIF orientation here.
  Future<img.Image> _decode(Uint8List bytes, int width, int height) async {
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: width,
      targetHeight: height,
      allowUpscaling: false,
    );
    try {
      final frame = await codec.getNextFrame();
      final image = frame.image;
      try {
        final data = await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        if (data == null) {
          throw const ImageAttachmentException(
            ImageAttachmentError.unsupported,
          );
        }
        return img.Image.fromBytes(
          width: image.width,
          height: image.height,
          bytes: data.buffer,
          numChannels: 4,
          order: img.ChannelOrder.rgba,
        );
      } finally {
        image.dispose();
      }
    } catch (_) {
      throw const ImageAttachmentException(ImageAttachmentError.unsupported);
    } finally {
      codec.dispose();
    }
  }

  img.Image _thumbnail(img.Image source) {
    final longest = source.width > source.height
        ? source.width
        : source.height;
    if (longest <= thumbnailSide) return source;
    final scale = thumbnailSide / longest;
    return img.copyResize(
      source,
      width: (source.width * scale).round().clamp(1, thumbnailSide),
      height: (source.height * scale).round().clamp(1, thumbnailSide),
      interpolation: img.Interpolation.average,
    );
  }
}
