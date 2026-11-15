// lib/ui/cloud_export.dart

import '../l10n/app_localizations.dart';
import '../services/storage_repository.dart';

/// Texts for the "export a note to the configured remote storage" action.
///
/// The action is backend-agnostic: it always uses the storage that sync is
/// currently configured with, so the label follows the backend ("kDrive" or
/// "WebDAV"). When no backend is configured the wording falls back to a
/// generic "cloud" and the caller sends the user to the sync settings.
class CloudExportLabels {
  /// Menu entry, e.g. "Copy to kDrive".
  final String action;

  /// Snackbar after a successful upload.
  final String success;

  /// Snackbar prefix when the upload fails.
  final String failure;

  /// Snackbar when no backend is configured at all.
  final String notConfigured;

  const CloudExportLabels({
    required this.action,
    required this.success,
    required this.failure,
    required this.notConfigured,
  });

  /// Resolves the labels for [storage] (the active backend, as exposed by
  /// `MemoProvider.storage`), or the generic cloud wording when there is none.
  static CloudExportLabels of(
    AppLocalizations l10n,
    StorageRepository? storage,
  ) {
    final notConfigured = l10n.cloudNotConfigured;
    if (storage == null || !storage.isConfigured) {
      return CloudExportLabels(
        action: l10n.copyToCloud,
        success: l10n.copiedToCloud,
        failure: l10n.copyToCloudFailed,
        notConfigured: notConfigured,
      );
    }

    switch (storage.backendId) {
      case kSyncBackendWebDav:
        return CloudExportLabels(
          action: l10n.copyToWebdav,
          success: l10n.copiedToWebdav,
          failure: l10n.copyToWebdavFailed,
          notConfigured: notConfigured,
        );
      case kSyncBackendKDrive:
      default:
        return CloudExportLabels(
          action: l10n.copyToKdrive,
          success: l10n.copiedToKdrive,
          failure: l10n.copyToKdriveFailed,
          notConfigured: notConfigured,
        );
    }
  }

  /// Success message with the note that the exported file is not encrypted,
  /// shown only when the backend has encryption enabled (otherwise there is
  /// nothing to warn about).
  String successMessage(AppLocalizations l10n, StorageRepository storage) {
    if (!storage.encryptionEnabled) return success;
    return '$success. ${l10n.docxNotEncrypted}';
  }
}
