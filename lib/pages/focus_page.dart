import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/controller.dart';
import '../core/models.dart';
import '../pet/pet_drawing.dart';
import '../ui/components.dart';
import '../ui/theme.dart';

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
        state.plans.firstOrNull ??
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
                  onPressed: () {
                    if (state.pet.dead) {
                      context.go('/adopt');
                      return;
                    }
                    showResult(
                      context,
                      controller.start(
                        Plan(
                          id: plan.id,
                          title: plan.title,
                          minutes: minutes,
                          time: plan.time,
                          category: plan.category,
                        ),
                      ),
                    );
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
              const Text(
                '演示：点击下列应用，体验允许访问和分心拦截。',
                style: TextStyle(color: NestColors.muted, fontSize: 12),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: ['课程平台', '词典', '短视频', '游戏', '电话']
                    .map(
                      (app) => ActionChip(
                        avatar: Icon(
                          state.allowedApps.contains(app)
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
              const Text(
                '这里模拟限制效果，网页不会锁定真实手机或拦截其他应用。',
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
    if (!state.focusing || state.allowedApps.contains(app)) {
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

  Future<void> _requestExit() async {
    final session = ref.read(appProvider).session;
    if (session == null) return;
    final first = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('再给自己一点时间？'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const StatusPill('确认 1 / 2'),
            const SizedBox(height: 18),
            Text('正在专注：${session.title}'),
            const SizedBox(height: 10),
            Text(
              '还剩 ${timerLabel(session.remainingSeconds(ref.read(appProvider).now))}。开始已经不容易，接下来只需要继续这一小段。',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('仍要退出'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('继续坚持'),
          ),
        ],
      ),
    );
    if (first != true || !mounted || !ref.read(appProvider).focusing) return;
    final second = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认结束这次专注？'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StatusPill('确认 2 / 2', warning: true),
            SizedBox(height: 18),
            Text('提前结束后，本次不会获得食物或重新领养资格。'),
            SizedBox(height: 12),
            Text('如果可以，试着回到眼前的一小步；如果需要离开，也可以之后重新开始。'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确认结束'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('返回专注'),
          ),
        ],
      ),
    );
    if (second == true && mounted) {
      showResult(context, ref.read(appProvider.notifier).cancelFocus());
    }
  }
}
