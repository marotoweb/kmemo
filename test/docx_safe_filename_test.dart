// test/docx_safe_filename_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:kmemo/services/docx_export_service.dart';

void main() {
  group('DocxExportService.safeFileName', () {
    test('keeps an ordinary title and appends the extension', () {
      expect(
        DocxExportService.safeFileName('Reuniao semanal'),
        'Reuniao semanal.docx',
      );
      expect(
        DocxExportService.safeFileName('Nota', extension: '.txt'),
        'Nota.txt',
      );
    });

    test('never leaves a path separator in the name', () {
      for (final title in [
        '2026/11 notas',
        r'..\segredo',
        '../../etc/passwd',
        'a/b/c',
      ]) {
        final name = DocxExportService.safeFileName(title);
        expect(name.contains('/'), isFalse, reason: name);
        expect(name.contains(r'\'), isFalse, reason: name);
      }
    });

    test('drops characters that are invalid in a file name', () {
      expect(
        DocxExportService.safeFileName('a:b*c?d"e<f>g|h'),
        'a-b-c-d-e-f-g-h.docx',
      );
    });

    test('trims spaces, dots and control characters', () {
      expect(DocxExportService.safeFileName('  .hidden.  '), 'hidden.docx');
      expect(DocxExportService.safeFileName('a\u0000b'), 'ab.docx');
      expect(DocxExportService.safeFileName('muitos    espaços'),
          'muitos espaços.docx');
    });

    test('falls back when the title has no usable characters', () {
      expect(DocxExportService.safeFileName(''), 'kMemo.docx');
      expect(DocxExportService.safeFileName('   '), 'kMemo.docx');
      expect(DocxExportService.safeFileName('...'), 'kMemo.docx');
    });

    test('caps very long titles', () {
      final name = DocxExportService.safeFileName('x' * 400);
      expect(name.length, lessThanOrEqualTo(125));
      expect(name.endsWith('.docx'), isTrue);
    });
  });
}
