import 'dart:async';
import '../core/models.dart';
import '../core/ports.dart';
import '../core/planning.dart';
import '../core/protection_status.dart';

class DemoClock implements ClockPort {
  DateTime _anchor = DateTime.now();
  Duration _offset = Duration.zero;
  final DateTime _base = DateTime(2026, 10, 13, 8, 40);
  @override
  DateTime now() => _base.add(DateTime.now().difference(_anchor)).add(_offset);
  void advance(Duration duration) => _offset += duration;
  void reset() {
    _anchor = DateTime.now();
    _offset = Duration.zero;
  }
}

class MemoryRepository implements DataRepository {
  MemoryRepository(this.clock);
  final ClockPort clock;
  AppState? _saved;
  @override
  AppState load() =>
      _saved ??
      AppState(
        now: clock.now(),
        pet: const PetState(),
        plans: const [
          Plan(
            id: 'p1',
            title: '高数 · 完成五道导数练习',
            minutes: 30,
            time: '09:00',
            category: '数学',
          ),
          Plan(
            id: 'p2',
            title: '英语 · 阅读一篇短文',
            minutes: 45,
            time: '14:00',
            category: '英语',
          ),
          Plan(
            id: 'p3',
            title: '编程 · 实现一个小功能',
            minutes: 60,
            time: '19:30',
            category: '编程',
          ),
        ],
        records: [
          FocusRecord(
            id: 'seed1',
            title: '高数 · 整理错题',
            minutes: 45,
            at: DateTime(2026, 10, 12, 19, 30),
            completed: true,
            virtual: true,
          ),
          FocusRecord(
            id: 'seed2',
            title: '英语 · 单词复习',
            minutes: 30,
            at: DateTime(2026, 10, 12, 9),
            completed: true,
            virtual: true,
          ),
          FocusRecord(
            id: 'seed3',
            title: '编程 · 阅读教材',
            minutes: 12,
            at: DateTime(2026, 10, 11, 20),
            completed: false,
            virtual: true,
          ),
        ],
      );
  @override
  void save(AppState state) => _saved = state;
  void reset() => _saved = null;
}

class DemoEvents implements EventPort {
  final _controller = StreamController<AppEvent>.broadcast();
  @override
  Stream<AppEvent> get events => _controller.stream;
  @override
  void publish(AppEvent event) => _controller.add(event);
  void dispose() => _controller.close();
}

class SimulatedDevice implements DevicePort {
  @override
  bool get simulated => true;
  @override
  OperationResult applyRestrictions(
    Set<String> blockedPackages,
    FocusSession session,
    AppState snapshot,
  ) => const OperationResult(true, 'SIMULATED', '已开启应用限制模拟');
  @override
  OperationResult releaseRestrictions([AppState? snapshot]) =>
      const OperationResult(true, 'SIMULATED', '已解除应用限制模拟');
  @override
  bool ready() => true;
  @override
  Future<ProtectionStatus> status() async =>
      const ProtectionStatus(ready: true);
  @override
  Future<void> openSettings() async {}
  @override
  Future<void> openBackgroundSettings() async {}
  @override
  Future<List<InstalledApp>> apps() async => const [
    InstalledApp(package: 'demo.course', name: '课程平台', category: '学习'),
    InstalledApp(package: 'demo.dictionary', name: '词典', category: '工具'),
    InstalledApp(
      package: 'demo.video',
      name: '短视频',
      category: '视频',
      recommendedBlocked: true,
    ),
    InstalledApp(
      package: 'demo.game',
      name: '游戏',
      category: '游戏',
      recommendedBlocked: true,
    ),
    InstalledApp(
      package: 'demo.phone',
      name: '电话',
      category: '通讯',
      protected: true,
    ),
  ];
}

class DisabledIntelligence implements IntelligencePort {
  @override
  Future<IntelligenceResponse> suggest(IntelligenceRequest request) async =>
      const IntelligenceResponse(available: false, message: '智能扩展尚未启用');
}
