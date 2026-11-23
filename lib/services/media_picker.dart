// lib/services/media_picker.dart

import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

/// Where a photo comes from.
enum ImageSourceKind { camera, gallery }

/// Picks one photo from the camera or the system picker.
///
/// No permission is requested by the app: on Android the camera is opened by
/// the system camera app and the gallery by the system photo picker, and on the
/// desktop the file chooser belongs to the OS. Nothing is requested at startup.
class MediaPicker {
  MediaPicker({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  /// The camera entry is hidden where the platform has no camera to open.
  bool get supportsCamera => !kIsWeb && Platform.isAndroid;

  /// Returns the path of the picked file, or null when the user cancels.
  Future<String?> pick(ImageSourceKind source) async {
    if (source == ImageSourceKind.camera) {
      if (!supportsCamera) return null;
      final file = await _picker.pickImage(
        source: ImageSource.camera,
        requestFullMetadata: false,
      );
      return file?.path;
    }

    if (!kIsWeb && Platform.isAndroid) {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        requestFullMetadata: false,
      );
      return file?.path;
    }

    const group = XTypeGroup(
      label: 'images',
      extensions: ['jpg', 'jpeg', 'png'],
    );
    final file = await openFile(acceptedTypeGroups: const [group]);
    return file?.path;
  }
}
