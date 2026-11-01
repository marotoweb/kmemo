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
}
