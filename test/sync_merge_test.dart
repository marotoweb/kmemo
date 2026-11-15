// test/sync_merge_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:kmemo/services/sync_merge.dart';

/// The merge rule is shared with any future client, so it is tested as a
/// decision table instead of through the sync loop.
void main() {
  SyncAction decide({
    bool localDirty = false,
    bool remoteExists = true,
    bool remoteDirty = false,
    bool localDeleted = false,
    bool remoteDeleted = false,
  }) => decideSyncAction(
    localDirty: localDirty,
    remoteExists: remoteExists,
    remoteDirty: remoteDirty,
    localDeleted: localDeleted,
    remoteDeleted: remoteDeleted,
  );

  group('decideSyncAction', () {
    test('nothing changed on either side', () {
      expect(decide(), SyncAction.none);
    });

    test('a local edit is uploaded', () {
      expect(decide(localDirty: true), SyncAction.upload);
    });

    test('a remote edit is downloaded', () {
      expect(decide(remoteDirty: true), SyncAction.download);
    });

    test('both sides changed: conflict copy', () {
      expect(decide(localDirty: true, remoteDirty: true), SyncAction.conflict);
    });

    test('a missing remote copy is restored from the local one', () {
      expect(decide(remoteExists: false), SyncAction.upload);
      expect(decide(localDirty: true, remoteExists: false), SyncAction.upload);
    });

    test('a remote deletion reaches a clean local note', () {
      expect(
        decide(remoteDirty: true, remoteDeleted: true),
        SyncAction.download,
      );
    });

    test('restoring a note the other device deleted is not a conflict', () {
      // Local restored (dirty, not deleted) while the remote copy is still
      // flagged as deleted: the restore wins.
      expect(
        decide(localDirty: true, remoteDirty: true, remoteDeleted: true),
        SyncAction.upload,
      );
    });

    test('an edit to a note that is in the local trash is a conflict', () {
      // The local note was sent to the trash while another device edited it:
      // the edit must survive as a conflict copy.
      expect(
        decide(localDirty: true, remoteDirty: true, localDeleted: true),
        SyncAction.conflict,
      );
    });
  });

  group('sameRemoteInstant', () {
    test('ignores the sub-second digits the database cannot store', () {
      final withMillis = DateTime.utc(2026, 11, 15, 10, 30, 45, 123);
      final stored = DateTime.utc(2026, 11, 15, 10, 30, 45);
      expect(sameRemoteInstant(withMillis, stored), isTrue);
    });

    test('detects a change one second later', () {
      final before = DateTime.utc(2026, 11, 15, 10, 30, 45);
      final after = before.add(const Duration(seconds: 1));
      expect(sameRemoteInstant(before, after), isFalse);
    });

    test('null timestamps never match', () {
      final now = DateTime.utc(2026, 11, 15);
      expect(sameRemoteInstant(null, now), isFalse);
      expect(sameRemoteInstant(now, null), isFalse);
      expect(sameRemoteInstant(null, null), isFalse);
    });

    test('compares instants, not timezone representations', () {
      final utc = DateTime.utc(2026, 11, 15, 10, 30, 45);
      final local = utc.toLocal();
      expect(sameRemoteInstant(utc, local), isTrue);
    });
  });
}
