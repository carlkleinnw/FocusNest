import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/controller.dart';
import '../core/models.dart';
import '../pet/pet_drawing.dart';
import '../ui/components.dart';
import '../ui/theme.dart';

class AdoptPage extends ConsumerStatefulWidget {
  const AdoptPage({super.key});
  @override
  ConsumerState<AdoptPage> createState() => _AdoptPageState();
}

class _AdoptPageState extends ConsumerState<AdoptPage> {
  final name = TextEditingController(text: '小满');
  int color = 0;
  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appProvider);
    final controller = ref.read(appProvider.notifier);
    return PageFrame(
      title: '新的陪伴，从这里开始',
      subtitle: '过去的努力留在记录里。准备好时，迎接下一位伙伴。',
      eyebrow: 'A NEW BEGINNING',
      children: [
        if (!state.pet.dead)
          EmptyPanel(
            title: '${state.pet.name}还在陪着你',
            body: '每天的坚持，会让你们一起走得更远。',
            action: MainButton('回小屋看看它', onPressed: () => context.go('/home')),
          )
        else if (!state.adoptionReady)
          SurfacePanel(
            child: Column(
              children: [
                const Icon(
                  Icons.spa_outlined,
                  size: 52,
                  color: NestColors.green,
                ),
                const SizedBox(height: 20),
                Text(
                  '先为新伙伴做一点准备',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                const Text(
                  '完整完成一次30分钟的重启专注，就能重新领养。',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                MainButton(
                  state.focusing ? '继续重启专注' : '开始30分钟重启专注',
                  onPressed: () {
                    if (state.focusing) {
                      context.go('/focus');
                      return;
                    }
                    final result = controller.start(
                      const Plan(
                        id: 'restart',
                        title: '重新出发 · 专注一个小任务',
                        minutes: 30,
                        time: '09:00',
                      ),
                      restart: true,
                    );
                    if (result.ok) {
                      context.go('/focus');
                    } else {
                      showResult(context, result);
                    }
                  },
                ),
              ],
            ),
          )
        else
          SurfacePanel(
            child: Column(
              children: [
                const StatusPill('领养资格已获得', icon: Icons.check_circle_outline),
                const SizedBox(height: 20),
                Text('选一位新伙伴', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [0, 1]
                      .map(
                        (index) => OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: color == index
                                ? NestColors.softGreen
                                : NestColors.surface,
                          ),
                          onPressed: () => setState(() => color = index),
                          child: Column(
                            children: [
                              PetPortrait(pet: PetState(colorIndex: index)),
                              Text(index == 0 ? '暖暖橘猫' : '软软奶牛猫'),
                              const SizedBox(height: 12),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: 350,
                  child: TextField(
                    controller: name,
                    maxLength: 12,
                    decoration: const InputDecoration(labelText: '给它取个名字'),
                  ),
                ),
                const SizedBox(height: 20),
                MainButton(
                  '带它回家',
                  icon: Icons.home_outlined,
                  onPressed: () {
                    final result = controller.adopt(name.text, color);
                    showResult(context, result);
                    if (result.ok) context.go('/home');
                  },
                ),
                const SizedBox(height: 12),
                const Text(
                  '新伙伴以健康状态入住，重启专注算作它的第一餐。',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        const SizedBox(height: 24),
        if (state.memorials.isNotEmpty) ...[
          Text('曾经的陪伴', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          ...state.memorials.map(
            (pet) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SurfacePanel(
                child: Text(
                  '${pet.name} · 陪伴${pet.companionDays}天 · 收到${pet.meals}次饭饭',
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
