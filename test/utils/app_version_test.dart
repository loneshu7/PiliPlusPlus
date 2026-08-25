import 'package:PiliPlus/utils/app_version.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses installed package version metadata', () {
    final version = AppVersion.fromPackageValues(
      version: '2.1.9',
      buildNumber: '2026082501',
    );

    expect(version.name, '2.1.9');
    expect(version.code, 2026082501);
    expect(version.display, '2.1.9+2026082501');
  });

  test('does not parse a non-decimal package build number', () {
    final version = AppVersion.fromPackageValues(
      version: '2.1.9',
      buildNumber: 'invalid',
    );

    expect(version.name, '2.1.9');
    expect(version.code, greaterThanOrEqualTo(0));
  });
}
