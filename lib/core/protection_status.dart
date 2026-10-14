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
  });
  final bool ready, active;
  final int blockedCount, windowEvents, reminders;
  final String homeResult, error;
  final int connections, disconnections;
  final String errorCode, version;
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
      );
}
