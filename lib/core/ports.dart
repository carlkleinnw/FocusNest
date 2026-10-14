import 'dart:async';
import 'models.dart';
import 'planning.dart';
import 'protection_status.dart';

// Versioned local contracts. Future native/network adapters share JSON-safe data.
abstract interface class ClockPort {
  DateTime now();
}

abstract interface class DataRepository {
  AppState load();
  void save(AppState state);
}

class AppEvent {
  const AppEvent(this.type, this.at, this.payload);
  final String type;
  final DateTime at;
  final Map<String, Object?> payload;
  Map<String, Object?> toJson() => {
    'version': 1,
    'type': type,
    'at': at.toIso8601String(),
    'payload': payload,
  };
}

abstract interface class EventPort {
  Stream<AppEvent> get events;
  void publish(AppEvent event);
}

class OperationResult {
  const OperationResult(this.ok, this.code, this.message);
  final bool ok;
  final String code, message;
  Map<String, Object> toJson() => {'ok': ok, 'code': code, 'message': message};
}

abstract interface class DevicePort {
  bool get simulated;
  FutureOr<OperationResult> applyRestrictions(
    Set<String> allowedPackages,
    FocusSession session,
    AppState snapshot,
  );
  FutureOr<OperationResult> releaseRestrictions([AppState? snapshot]);
  FutureOr<bool> ready();
  Future<ProtectionStatus> status();
  Future<List<InstalledApp>> apps();
  Future<void> openSettings();
  Future<void> openBackgroundSettings();
}

class IntelligenceRequest {
  const IntelligenceRequest({required this.goal, required this.context});
  final String goal;
  final Map<String, Object?> context;
}

class IntelligenceResponse {
  const IntelligenceResponse({
    required this.available,
    required this.message,
    this.suggestions = const [],
  });
  final bool available;
  final String message;
  final List<Map<String, Object?>> suggestions;
}

abstract interface class IntelligencePort {
  Future<IntelligenceResponse> suggest(IntelligenceRequest request);
}

abstract interface class ContextPort {
  Map<String, Object?> readContext();
}

// Agent proposals never get access to arbitrary state writes or demo time controls.
abstract interface class ActionPort {
  OperationResult upsertPlan(Plan plan);
  OperationResult upsertGoal(Goal goal);
  OperationResult upsertMilestone(Milestone milestone);
  OperationResult setRest(DateTime day, bool enabled);
}
