import 'package:flutter_test/flutter_test.dart';
import 'package:kmemo/services/update_service.dart';

void main() {
  group('UpdateService.compareVersions', () {
    test('equal versions', () {
      expect(UpdateService.compareVersions('0.1.13', '0.1.13'), 0);
    });
    test('latest greater (patch)', () {
      expect(UpdateService.compareVersions('0.1.13', '0.1.14'), -1);
    });
    test('current greater', () {
      expect(UpdateService.compareVersions('0.2.0', '0.1.13'), 1);
    });
    test('handles v prefix', () {
      expect(UpdateService.compareVersions('v0.1.13', '0.1.13'), 0);
    });
    test('handles missing parts', () {
      expect(UpdateService.compareVersions('0.1', '0.1.0'), 0);
    });
    test('pre-release suffix ignored for numeric compare', () {
      expect(UpdateService.compareVersions('0.1.13', '0.1.13-rc1'), 0);
    });
  });

  group('UpdateService.withoutPlatformTags', () {
    test('removes the tag after a bullet', () {
      expect(
        UpdateService.withoutPlatformTags('- [All] **A note:** text'),
        '- **A note:** text',
      );
    });

    test('removes the tag at the start of a line', () {
      expect(
        UpdateService.withoutPlatformTags('[Android] Only phones'),
        'Only phones',
      );
    });

    test('keeps indentation and the bullet marker', () {
      expect(
        UpdateService.withoutPlatformTags('  - [Desktop] Linux only'),
        '  - Linux only',
      );
    });

    test('leaves an unrelated bracket alone', () {
      expect(
        UpdateService.withoutPlatformTags('- [WIP] not a platform tag'),
        '- [WIP] not a platform tag',
      );
    });

    test('cleans every line of a release body', () {
      expect(
        UpdateService.withoutPlatformTags(
          '### New\n- [All] first\n- [CI] second\n',
        ),
        '### New\n- first\n- second\n',
      );
    });
  });
}
