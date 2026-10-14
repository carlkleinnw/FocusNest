import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/controller.dart';
import '../core/models.dart';
import '../pet/pet_drawing.dart';
import '../ui/components.dart';
import '../ui/theme.dart';
import '../ui/focus_exit.dart';

class FocusPage extends ConsumerStatefulWidget {
  const FocusPage({super.key, this.planId});
  final String? planId;
  @override
  ConsumerState<FocusPage> createState() => _FocusPageState();
}

class _FocusPageState extends ConsumerState<FocusPage> {
  int? selectedMinutes;
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appProvider);
    final controller = ref.read(appProvider.notifier);
    final plan =
        state.plans.where((p) => p.id == widget.planId).firstOrNull ??
        state.plans
            .where((p) => !p.done && (p.date.isEmpty || p.date == state.dayKey))
            .firstOrNull ??
        const Plan(id: 'free', title: '完成一个小任务', minutes: 30, time: '09:00');
    final session = state.session;
    final minutes = selectedMinutes ?? plan.minutes;
    return PageFrame(
      title: '只做眼前这一件事',
      subtitle: '把手机的热闹留在外面，把注意力留给自己。',
      eyebrow: 'YOUR QUIET MOMENT',
      children: [
        if (session == null)
          SurfacePanel(
            child: Column(
              children: [
                const StatusPill('手动开始 · 至少30分钟', icon: Icons.schedule),
                const SizedBox(height: 24),
                Text(
                  plan.title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 28),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children:
                      [
                            30,
                            45,
                            60,
                            90,
                            if (![30, 45, 60, 90].contains(plan.minutes))
                              plan.minutes,
                          ]
                          .map(
                            (n) => ChoiceChip(
                              label: Text('$n 分钟'),
                              selected: minutes == n,
                              onSelected: (_) =>
                                  setState(() => selectedMinutes = n),
                            ),
                          )
                          .toList(),
                ),
                const SizedBox(height: 32),
                PetPortrait(pet: state.pet),
                const Text('你开始专注，我就安静陪着你。'),
                const SizedBox(height: 28),
                MainButton(
                  state.pet.dead ? '先去重启领养' : '确认并开始专注',
                  icon: Icons.play_arrow_rounded,
                  onPressed: () async {
                    if (state.pet.dead) {
                      context.go('/adopt');
                      return;
                    }
                    final result = await controller.start(
                      Plan(
                        id: plan.id,
                        title: plan.title,
                        minutes: minutes,
                        time: plan.time,
                        category: plan.category,
                        date: plan.date,
                        goalId: plan.goalId,
                        milestoneId: plan.milestoneId,
                        units: plan.units,
                        doneUnits: plan.doneUnits,
                      ),
                    );
                    if (context.mounted) showResult(context, result);
                  },
                ),
              ],
            ),
          )
        else if (state.focusing)
          SurfacePanel(
            color: const Color(0xFFEAF0E6),
            child: Column(
              children: [
                StatusPill(
                  session.restart ? '重启专注进行中' : '沉浸模式进行中',
                  icon: Icons.lock_outline,
                ),
                const SizedBox(height: 22),
                Text(
                  session.title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 32),
                Semantics(
                  label: '剩余时间',
                  liveRegion: false,
                  child: Text(
                    timerLabel(session.remainingSeconds(state.now)),
                    style: TextStyle(
                      fontSize: MediaQuery.sizeOf(context).width < 420
                          ? 56
                          : 80,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w300,
                      color: NestColors.green,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: 300,
                  child: LinearProgressIndicator(
                    value:
                        1 -
                        session.remainingSeconds(state.now) /
                            (session.minutes * 60),
                    minHeight: 5,
                    borderRadius: BorderRadius.circular(10),
                    backgroundColor: const Color(0xFFD4DECC),
                  ),
                ),
                const SizedBox(height: 22),
                PetPortrait(pet: state.pet, sleeping: true, size: 88),
                Text(
                  session.restart
                      ? '每一次重新开始，都值得被认真对待。'
                      : '${state.pet.name}在休息，等你坚持到结束。',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                OutlinedButton(
                  onPressed: _requestExit,
                  child: const Text('提前结束'),
                ),
                const SizedBox(height: 12),
                if (controller.simulated)
                  TextButton(
                    onPressed: () => context.go('/demo'),
                    child: const Text('去演示控制快进时间'),
                  ),
              ],
            ),
          )
        else
          SurfacePanel(
            child: Column(
              children: [
                Icon(
                  session.status == FocusStatus.completed
                      ? Icons.check_circle_outline
                      : Icons.restart_alt,
                  size: 56,
                  color: NestColors.green,
                ),
                const SizedBox(height: 20),
                Text(
                  session.status == FocusStatus.completed
                      ? '这一段，你坚持下来了'
                      : '这次先停在这里',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(state.message, textAlign: TextAlign.center),
                const SizedBox(height: 20),
                PetPortrait(pet: state.pet),
                const SizedBox(height: 24),
                MainButton(
                  state.adoptionReady ? '去迎接新伙伴' : '返回小屋',
                  onPressed: () {
                    controller.dismissSession();
                    context.go(state.adoptionReady ? '/adopt' : '/home');
                  },
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: controller.dismissSession,
                  child: const Text('准备下一次专注'),
                ),
              ],
            ),
          ),
        const SizedBox(height: 24),
        SurfacePanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('专注时的应用', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                controller.simulated
                    ? '演示：点击下列应用，体验允许访问和分心拦截。'
                    : state.focusing
                    ? '本次专注使用开始时确认的白名单。结束后可在应用锁定页调整。'
                    : '请在应用锁定页确认白名单和保护权限。',
                style: TextStyle(color: NestColors.muted, fontSize: 12),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children:
                    (controller.simulated
                            ? ['课程平台', '词典', '短视频', '游戏', '电话']
                            : <String>[])
                        .map(
                          (app) => ActionChip(
                            avatar: Icon(
                              !_simBlocked(state, app)
                                  ? Icons.check_circle_outline
                                  : Icons.lock_outline,
                              size: 17,
                            ),
                            label: Text(app),
                            onPressed: () => _openApp(app),
                          ),
                        )
                        .toList(),
              ),
              const SizedBox(height: 16),
              Text(
                controller.simulated
                    ? '网页不会拦截真实手机应用。'
                    : (state.protectionReady
                          ? '权限已开启；受限应用会显示提醒并返回桌面。'
                          : '保护未生效：请先开启无障碍权限。'),
                style: TextStyle(fontSize: 12, color: NestColors.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _openApp(String app) async {
    final state = ref.read(appProvider);
    if (!state.focusing || !_simBlocked(state, app)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$app：允许访问（模拟）')));
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.lock_outline, color: NestColors.green, size: 36),
        title: Text('$app正在休息'),
        content: const Text('先完成眼前的任务。你正在把时间用在自己选择的事情上。'),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('回到专注'),
          ),
        ],
      ),
    );
  }

  Future<void> _requestExit() => requestFocusExit(context, ref);

  bool _simBlocked(AppState state, String app) =>
      app != '电话' &&
      !state.allowedApps.contains(
        {
          '课程平台': 'demo.course',
          '词典': 'demo.dictionary',
          '短视频': 'demo.video',
          '游戏': 'demo.game',
          '电话': 'demo.phone',
        }[app],
      );
}
