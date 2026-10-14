class ProtectionStatus {
  const ProtectionStatus({
    required this.ready,
    this.active = false,
    this.blockedCount = 0,
    this.windowEvents = 0,
    this.reminders = 0,
    this.homeResult = '',
    this.error = '',
    this.connections = 0,
    this.disconnections = 0,
    this.errorCode = '',
    this.version = '',
    this.windowAccess = false,
    this.allowlistMode = false,
    this.reminderVisible = false,
    this.reminderAttempts = 0,
    this.foregroundChecks = 0,
    this.unknownWindows = 0,
    this.homeVerified = 0,
    this.hideReason = '',
    this.backgroundRunning = false,
  });
  final bool ready, active;
  final int blockedCount, windowEvents, reminders;
  final String homeResult, error;
  final int connections, disconnections;
  final String errorCode, version;
  final bool windowAccess, allowlistMode, reminderVisible;
  final int reminderAttempts, foregroundChecks, unknownWindows, homeVerified;
  final String hideReason;
  final bool backgroundRunning;
  Map<String, Object> toJson() => {
    'version': version,
    'ready': ready,
    'active': active,
    'blockedCount': blockedCount,
    'windowEvents': windowEvents,
    'reminders': reminders,
    'homeResult': homeResult,
    'connections': connections,
    'disconnections': disconnections,
    'errorCode': errorCode,
    'error': error,
    'windowAccess': windowAccess,
    'allowlistMode': allowlistMode,
    'reminderVisible': reminderVisible,
    'reminderAttempts': reminderAttempts,
    'foregroundChecks': foregroundChecks,
    'unknownWindows': unknownWindows,
    'homeVerified': homeVerified,
    'hideReason': hideReason,
    'backgroundRunning': backgroundRunning,
  };
  factory ProtectionStatus.fromJson(Map<String, dynamic> data) =>
      ProtectionStatus(
        ready: data['ready'] == true,
        active: data['active'] == true,
        blockedCount: (data['blockedCount'] as num?)?.toInt() ?? 0,
        windowEvents: (data['windowEvents'] as num?)?.toInt() ?? 0,
        reminders: (data['reminders'] as num?)?.toInt() ?? 0,
        homeResult: data['homeResult'] as String? ?? '',
        error: data['error'] as String? ?? '',
        connections: (data['connections'] as num?)?.toInt() ?? 0,
        disconnections: (data['disconnections'] as num?)?.toInt() ?? 0,
        errorCode: data['errorCode'] as String? ?? '',
        version: data['version'] as String? ?? '',
        windowAccess: data['windowAccess'] == true,
        allowlistMode: data['allowlistMode'] == true,
        reminderVisible: data['reminderVisible'] == true,
        reminderAttempts: (data['reminderAttempts'] as num?)?.toInt() ?? 0,
        foregroundChecks: (data['foregroundChecks'] as num?)?.toInt() ?? 0,
        unknownWindows: (data['unknownWindows'] as num?)?.toInt() ?? 0,
        homeVerified: (data['homeVerified'] as num?)?.toInt() ?? 0,
        hideReason: data['hideReason'] as String? ?? '',
        backgroundRunning: data['backgroundRunning'] == true,
      );
}
