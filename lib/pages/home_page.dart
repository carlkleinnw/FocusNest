import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/controller.dart';
import '../core/models.dart';
import '../pet/room_scene.dart';
import '../ui/components.dart';
import '../ui/theme.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});
  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final sceneKey = GlobalKey<RoomSceneState>();
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appProvider);
    final controller = ref.read(appProvider.notifier);
    return PageFrame(
      title: '${state.pet.name}的小屋',
      subtitle: '一点点专注，换来一起长大的日子。',
      eyebrow: 'A LITTLE HOME, A LITTLE PROGRESS',
      action: StatusPill(
        state.focusing ? '安静陪伴中' : state.pet.condition,
        warning: state.pet.hungryDays > 0,
        icon: Icons.pets_outlined,
      ),
      children: [
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF1EEE2),
            border: Border.all(color: NestColors.line),
            borderRadius: BorderRadius.circular(24),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              RoomScene(
                key: sceneKey,
                pet: state.pet,
                focusing: state.focusing,
                mealCount: state.pet.meals,
                showMeal: state.todayFed,
                onInteract: controller.interact,
              ),
              Positioned(
                top: 16,
                left: 16,
                child: StatusPill(
                  '${shortDate(state.now)} · ${state.resting ? '休息日' : '学习日'}',
                ),
              ),
              Positioned(
                top: 16,
                right: 16,
                child: IconButton.filledTonal(
                  tooltip: '切换悬浮宠物预览',
                  onPressed: controller.toggleFloating,
                  icon: Icon(
                    state.floating
                        ? Icons.picture_in_picture_alt
                        : Icons.picture_in_picture_outlined,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SurfacePanel(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              const Icon(
                Icons.chat_bubble_outline,
                size: 20,
                color: NestColors.green,
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(state.message)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (!state.pet.dead) ...[
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              MainButton(
                '摸摸${state.pet.name}',
                icon: Icons.favorite_border,
                onPressed: state.focusing
                    ? null
                    : () => sceneKey.currentState?.interact('pet'),
              ),
              OutlinedButton.icon(
                onPressed: state.focusing
                    ? null
                    : () => sceneKey.currentState?.interact('ball'),
                icon: const Icon(Icons.sports_baseball_outlined, size: 18),
                label: const Text('一起玩球'),
              ),
              OutlinedButton.icon(
                onPressed: state.focusing
                    ? null
                    : () => sceneKey.currentState?.interact('rest'),
                icon: const Icon(Icons.bedtime_outlined, size: 18),
                label: const Text('去窝里休息'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            state.focusing ? '专注期间互动暂停，宠物会安静陪着你。' : '也可以直接点点宠物、玩具球或地板。互动不会喂食。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ] else
          EmptyPanel(
            title: '把陪伴留在心里',
            body: '完成一次30分钟的重启专注，就能迎接下一位伙伴。',
            action: MainButton('去重新领养', onPressed: () => context.go('/adopt')),
          ),
        const SizedBox(height: 28),
        SurfacePanel(
          child: Wrap(
            spacing: 44,
            runSpacing: 20,
            children: [
              StatBlock('一起度过', '${state.pet.companionDays}', unit: '天'),
              StatBlock('收到的饭饭', '${state.pet.meals}', unit: '次'),
              StatBlock('连续未喂食', '${state.pet.hungryDays}', unit: '/ 7 天'),
              StatBlock(
                '今天的照顾',
                state.todayFed
                    ? '已喂食'
                    : state.resting
                    ? '休息中'
                    : '等你来',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          '完整完成至少30分钟的专注，饭饭会自动送到小屋。',
          style: TextStyle(fontSize: 12, color: NestColors.muted),
        ),
      ],
    );
  }
}
