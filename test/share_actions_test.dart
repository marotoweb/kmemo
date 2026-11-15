// test/share_actions_test.dart

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kmemo/ui/share_actions.dart';
import 'package:share_plus/share_plus.dart';
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';

/// A platform that cannot share, the way the Linux build behaves when no mail
/// handler is registered: share_plus opens a `mailto:` URI and throws.
class _FailingShare extends SharePlatform {
  @override
  Future<ShareResult> share(ShareParams params) async {
    throw Exception('Failed to launch mailto');
  }
}

class _WorkingShare extends SharePlatform {
  @override
  Future<ShareResult> share(ShareParams params) async =>
      ShareResult.unavailable;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> clipboardWrites;

  setUp(() {
    clipboardWrites = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') clipboardWrites.add(call);
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  test('copies the text when the platform cannot share', () async {
    final shared = await shareTextOrCopy(
      text: 'olá',
      title: 'Nota',
      sharePlus: SharePlus.custom(_FailingShare()),
    );

    expect(shared, isFalse);
    expect(clipboardWrites, hasLength(1));
    expect((clipboardWrites.single.arguments as Map)['text'], 'olá');
  });

  test('does not touch the clipboard when the share sheet opens', () async {
    final shared = await shareTextOrCopy(
      text: 'olá',
      title: 'Nota',
      sharePlus: SharePlus.custom(_WorkingShare()),
    );

    expect(shared, isTrue);
    expect(clipboardWrites, isEmpty);
  });
}
