// lib/ui/share_actions.dart

import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

/// Shares [text] with the system share sheet, falling back to the clipboard.
///
/// Not every platform can share. The Linux build of share_plus opens a
/// `mailto:` URI, which fails when no mail handler is registered; Android and
/// iOS throw `PlatformException` when the sheet cannot be shown; a plugin
/// missing from a desktop build throws `MissingPluginException`. Copying the
/// text is the closest thing to sharing there, and it is what the user can
/// paste into the app they wanted.
///
/// Returns true when the text was shared, false when it was only copied.
///
/// [sharePlus] exists for tests only: `SharePlus.instance` is a `static final`
/// that captures the platform implementation the first time it is read, so a
/// test cannot replace it afterwards (see `SharePlus.custom`).
Future<bool> shareTextOrCopy({
  required String text,
  required String title,
  SharePlus? sharePlus,
}) async {
  try {
    await (sharePlus ?? SharePlus.instance).share(
      ShareParams(text: text, title: title),
    );
    return true;
  } catch (_) {
    await Clipboard.setData(ClipboardData(text: text));
    return false;
  }
}
