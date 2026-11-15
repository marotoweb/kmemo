// test/cloud_export_labels_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:kmemo/database/database.dart';
import 'package:kmemo/l10n/app_localizations_pt.dart';
import 'package:kmemo/services/storage_repository.dart';
import 'package:kmemo/ui/cloud_export.dart';

/// Minimal backend used to exercise the label mapping without any network.
class _FakeStorage extends StorageRepository {
  @override
  final bool isConfigured;
  @override
  final String backendId;
  @override
  final String storageName;
  @override
  final bool encryptionEnabled;

  _FakeStorage({
    required this.backendId,
    required this.storageName,
    this.isConfigured = true,
    this.encryptionEnabled = false,
  });

  @override
  Future<void> init() async {}

  @override
  Future<void> clearConfiguration() async {}

  @override
  Future<String?> uploadMemo(Memo memo, List<Block> blocks) async => null;

  @override
  Future<String?> uploadFile({
    required String fileName,
    required List<int> bytes,
  }) async => null;

  @override
  Future<void> deleteMemo(String remoteFileId) async {}

  @override
  Future<List<RemoteMemoInfo>> listRemoteMemos() async => [];

  @override
  Future<RemoteMemo?> downloadMemo(String remoteFileId) async => null;
}

void main() {
  final l10n = AppLocalizationsPt();

  test('falls back to the generic cloud wording when nothing is configured', () {
    final none = CloudExportLabels.of(l10n, null);
    expect(none.action, 'Copiar para a nuvem');
    expect(none.success, 'Copiado para a nuvem');
    expect(none.notConfigured, 'Nenhum armazenamento remoto está configurado');

    final unconfigured = CloudExportLabels.of(
      l10n,
      _FakeStorage(
        backendId: kSyncBackendKDrive,
        storageName: 'kDrive',
        isConfigured: false,
      ),
    );
    expect(unconfigured.action, 'Copiar para a nuvem');
  });

  test('follows the configured backend', () {
    final kdrive = CloudExportLabels.of(
      l10n,
      _FakeStorage(backendId: kSyncBackendKDrive, storageName: 'kDrive'),
    );
    expect(kdrive.action, 'Copiar para o kDrive');
    expect(kdrive.success, 'Copiado para o kDrive');

    final webdav = CloudExportLabels.of(
      l10n,
      _FakeStorage(backendId: kSyncBackendWebDav, storageName: 'WebDAV'),
    );
    expect(webdav.action, 'Copiar para o WebDAV');
    expect(webdav.success, 'Copiado para o WebDAV');
    expect(webdav.failure, 'Falha ao copiar para o WebDAV');
  });

  test('mentions that the .docx is not encrypted only with encryption on', () {
    final plain = _FakeStorage(
      backendId: kSyncBackendWebDav,
      storageName: 'WebDAV',
    );
    expect(
      CloudExportLabels.of(l10n, plain).successMessage(l10n, plain),
      'Copiado para o WebDAV',
    );

    final encrypted = _FakeStorage(
      backendId: kSyncBackendWebDav,
      storageName: 'WebDAV',
      encryptionEnabled: true,
    );
    expect(
      CloudExportLabels.of(l10n, encrypted).successMessage(l10n, encrypted),
      'Copiado para o WebDAV. O ficheiro .docx não é cifrado.',
    );
  });
}
