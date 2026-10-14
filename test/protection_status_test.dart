import 'package:flutter_test/flutter_test.dart';
import 'package:focus_pet_demo/core/protection_status.dart';

void main() {
  test('copied diagnosis preserves outcomes while excluding app inventory', () {
    final status = ProtectionStatus.fromJson({
      'version': '0.2.3',
      'ready': true,
      'active': true,
      'blockedCount': 11,
      'windowEvents': 21,
      'reminders': 2,
      'homeResult': 'HOME_REJECTED',
      'connections': 2,
      'disconnections': 1,
      'errorCode': 'BadTokenException',
      'error': '提醒未能显示',
      'blockedPackages': ['private.package'],
      'title': 'private task title',
      'windowAccess': true,
      'allowlistMode': true,
      'foregroundChecks': 40,
      'reminderAttempts': 3,
      'reminderVisible': true,
      'unknownWindows': 2,
      'homeVerified': 1,
      'hideReason': 'ALLOWED_FOREGROUND',
      'foregroundPackage': 'private.foreground',
      'backgroundRunning': true,
    });
    final copied = status.toJson();
    expect(copied['homeResult'], 'HOME_REJECTED');
    expect(copied['windowEvents'], 21);
    expect(copied['connections'], 2);
    expect(copied['windowAccess'], true);
    expect(copied['foregroundChecks'], 40);
    expect(copied['homeVerified'], 1);
    expect(copied['reminderVisible'], true);
    expect(copied['backgroundRunning'], true);
    expect(copied.containsKey('foregroundPackage'), false);
    expect(copied.containsKey('blockedPackages'), false);
    expect(copied.containsKey('title'), false);
  });
  test('missing status fields never claim protection is active', () {
    final status = ProtectionStatus.fromJson({});
    expect(status.ready, false);
    expect(status.active, false);
    expect(status.blockedCount, 0);
    expect(status.reminderVisible, false);
    expect(status.windowAccess, false);
    expect(status.backgroundRunning, false);
  });
}
