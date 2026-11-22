// lib/ui/widgets/sync_prompts.dart

import 'package:flutter/material.dart';
import 'package:kmemo/l10n/app_localizations.dart';

/// Asks for the passphrase of a note that is encrypted in the cloud.
///
/// Returns the passphrase typed by the user, or null when they choose to
/// ignore the note. The cycle uses it to read the note and, when it works,
/// adopts it for the backend, so the replacement is uploaded encrypted.
Future<String?> requestSyncPassphrase(BuildContext context) {
  return showDialog<String?>(
    context: context,
    builder: (_) => const _RequestPassphraseDialog(),
  );
}

/// After two failed attempts with a note: ignore it or delete the remote file.
Future<bool> confirmDeleteRemoteNote(BuildContext context) async {
  final delete = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(AppLocalizations.of(context)!.couldNotDecrypt),
      content: Text(AppLocalizations.of(context)!.afterTwoAttempts),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(AppLocalizations.of(context)!.ignore),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(AppLocalizations.of(context)!.delete),
        ),
      ],
    ),
  );
  return delete == true;
}

/// Dialog that owns its controller and disposes it when it leaves the tree,
/// avoiding the "_dependents.isEmpty" assertion that happened when the
/// controller was disposed right after showDialog returned.
class _RequestPassphraseDialog extends StatefulWidget {
  const _RequestPassphraseDialog();

  @override
  State<_RequestPassphraseDialog> createState() =>
      _RequestPassphraseDialogState();
}

class _RequestPassphraseDialogState extends State<_RequestPassphraseDialog> {
  final _controller = TextEditingController();
  bool _showPassphrase = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(AppLocalizations.of(context)!.noteEncryptedInCloud),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.90,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppLocalizations.of(context)!.thisNoteIsEncryptedInCloud,
              style: TextStyle(fontSize: 13),
            ),
            SizedBox(height: 12),
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context)!.passphrase,
                suffixIcon: IconButton(
                  icon: Icon(
                    _showPassphrase ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () =>
                      setState(() => _showPassphrase = !_showPassphrase),
                ),
              ),
              obscureText: !_showPassphrase,
              maxLines: 1,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: Text(AppLocalizations.of(context)!.ignore),
        ),
        TextButton(
          onPressed: () {
            final text = _controller.text.trim();
            Navigator.pop(context, text.isEmpty ? null : text);
          },
          child: Text(AppLocalizations.of(context)!.confirm),
        ),
      ],
    );
  }
}
