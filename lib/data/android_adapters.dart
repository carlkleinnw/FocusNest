import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import '../core/models.dart';
import '../core/planning.dart';
import '../core/ports.dart';
import 'snapshot_codec.dart';

const nativeChannel = MethodChannel('focusnest/device_v1');

class RealClock implements ClockPort {
  @override
  DateTime now() => DateTime.now();
}

class AndroidRepository implements DataRepository {
  AndroidRepository(this._state);
  AppState _state;
  Future<void> _pending = Future.value();
  String? error;
  @override
  AppState load() => _state;
  @override
  void save(AppState state) {
    _state = state;
    final snapshot = jsonEncode(encodeSnapshot(state));
    _pending = _pending.then((_) async {
      try {
        await nativeChannel.invokeMethod<void>('save', {'snapshot': snapshot});
        error = null;
      } catch (_) {
        error = '本地保存失败，请保持应用打开并重试。';
      }
    });
  }

  Future<void> flush() => _pending;
  static Future<AndroidRepository> open(AppState initial) async {
    final stored = await nativeChannel.invokeMethod<String>('load');
    return AndroidRepository(
      stored == null
          ? initial
          : decodeSnapshot(jsonDecode(stored) as Map<String, dynamic>),
    );
  }
}

class AndroidDevice implements DevicePort {
  @override
  bool get simulated => false;
  @override
  Future<bool> ready() async {
    try {
      final s = await nativeChannel.invokeMapMethod<String, dynamic>('status');
      return s?['ready'] == true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<InstalledApp>> apps() async {
    final rows = await nativeChannel.invokeListMethod<dynamic>('apps') ?? [];
    return rows
        .map((r) => InstalledApp.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  @override
  Future<void> openSettings() => nativeChannel.invokeMethod<void>('settings');
  @override
  Future<OperationResult> applyRestrictions(
    Set<String> blockedPackages,
    FocusSession session,
    AppState snapshot,
  ) async {
    try {
      await nativeChannel.invokeMethod<void>('start', {
        'blocked': blockedPackages.toList(),
        'started': session.startedAt.millisecondsSinceEpoch,
        'deadline': session.deadline.millisecondsSinceEpoch,
        'title': session.title,
        'snapshot': jsonEncode(encodeSnapshot(snapshot)),
      });
      return const OperationResult(true, 'OK', '专注保护已生效');
    } on PlatformException catch (e) {
      return OperationResult(
        false,
        'PERMISSION_REQUIRED',
        e.message ?? '请先开启专注保护',
      );
    }
  }

  @override
  Future<OperationResult> releaseRestrictions([AppState? snapshot]) async {
    try {
      await nativeChannel.invokeMethod<void>('stop', {
        'snapshot': snapshot == null
            ? null
            : jsonEncode(encodeSnapshot(snapshot)),
      });
      return const OperationResult(true, 'OK', '限制已解除');
    } on PlatformException catch (e) {
      return OperationResult(false, 'DEVICE_ERROR', e.message ?? '解除限制失败');
    }
  }
}
