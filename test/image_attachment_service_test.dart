// test/image_attachment_service_test.dart

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:kmemo/services/image_attachment_service.dart';

Future<Directory> _tempDir() async {
  final dir = await Directory.systemTemp.createTemp('kmemo_attachments');
  addTearDown(() => dir.delete(recursive: true));
  return dir;
}

Future<String> _writeJpeg(Directory dir, int width, int height) async {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(180, 40, 40));
  final file = File('${dir.path}/source.jpg');
  await file.writeAsBytes(img.encodeJpg(image, quality: 90));
  return file.path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory supportDir;
  late ImageAttachmentService service;

  setUp(() async {
    supportDir = await _tempDir();
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => supportDir.path);
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    service = ImageAttachmentService();
    await service.ensureBaseDir();
  });

  test('reduces a large photo to the maximum side', () async {
    final source = await _writeJpeg(supportDir, 2400, 1200);
    final probe = await service.probe(source);
    expect(probe.width, 2400);
    expect(probe.height, 1200);

    final imported = await service.import(
      sourcePath: source,
      memoUuid: 'memo-1',
      maxSide: 1920,
      resize: true,
    );

    final stored = img.decodeImage(
      File(service.resolve(imported.relativePath)).readAsBytesSync(),
    )!;
    expect(stored.width, 1920);
    expect(stored.height, 960);
    // The thumbnail is generated next to the photo.
    final thumb = File(service.thumbnailPath(imported.relativePath));
    expect(thumb.existsSync(), isTrue);
    final thumbImage = img.decodeImage(thumb.readAsBytesSync())!;
    expect(thumbImage.width, lessThanOrEqualTo(300));
  });

  test('keeps the dimensions when the caller does not resize', () async {
    final source = await _writeJpeg(supportDir, 2400, 1200);

    final imported = await service.import(
      sourcePath: source,
      memoUuid: 'memo-2',
      maxSide: 1920,
      resize: false,
    );

    final stored = img.decodeImage(
      File(service.resolve(imported.relativePath)).readAsBytesSync(),
    )!;
    expect(stored.width, 2400);
    expect(stored.height, 1200);
  });

  test('never enlarges a small photo', () async {
    final source = await _writeJpeg(supportDir, 800, 600);

    final imported = await service.import(
      sourcePath: source,
      memoUuid: 'memo-3',
      maxSide: 1920,
      resize: true,
    );

    final stored = img.decodeImage(
      File(service.resolve(imported.relativePath)).readAsBytesSync(),
    )!;
    expect(stored.width, 800);
    expect(stored.height, 600);
  });

  test('rejects a file that is not an image', () async {
    final file = File('${supportDir.path}/not-an-image.txt');
    await file.writeAsBytes(Uint8List.fromList(List.filled(64, 65)));

    expect(
      () => service.probe(file.path),
      throwsA(
        isA<ImageAttachmentException>().having(
          (error) => error.error,
          'error',
          ImageAttachmentError.unsupported,
        ),
      ),
    );
  });

  test('removes the photo and the thumbnail', () async {
    final source = await _writeJpeg(supportDir, 400, 300);
    final imported = await service.import(
      sourcePath: source,
      memoUuid: 'memo-4',
      maxSide: 1920,
      resize: false,
    );
    final photo = File(service.resolve(imported.relativePath));
    final thumb = File(service.thumbnailPath(imported.relativePath));
    expect(photo.existsSync(), isTrue);

    await service.delete(imported.relativePath);

    expect(photo.existsSync(), isFalse);
    expect(thumb.existsSync(), isFalse);
  });
}
