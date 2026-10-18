import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../ui/components.dart';
import '../ui/theme.dart';

class MePage extends StatelessWidget {
  const MePage({super.key});

  @override
  Widget build(BuildContext context) => PageFrame(
    subtitle: '长期目标、专注保护与设置。',
    children: [
      SurfacePanel(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: NestColors.softOrange,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.auto_stories_rounded,
                size: 24,
                color: NestColors.orange,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '伴学小屋',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      color: NestColors.ink,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'FocusNest · 0.4.9 体验版',
                    style: TextStyle(fontSize: 13, color: NestColors.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      SettingsGroup(
        children: [
          SettingsRow(
            title: '长期目标',
            subtitle: '目标、阶段与每日任务',
            trailing: const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: NestColors.faint,
            ),
            onTap: () => context.go('/goals'),
          ),
          SettingsRow(
            title: '专注保护与白名单',
            subtitle: '系统权限与专注时允许的应用',
            trailing: const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: NestColors.faint,
            ),
            onTap: () => context.go('/apps'),
          ),
          SettingsRow(
            title: '设置',
            subtitle: '模型、密钥与计划偏好',
            trailing: const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: NestColors.faint,
            ),
            onTap: () => context.go('/settings'),
          ),
        ],
      ),
      const SizedBox(height: 16),
      const Center(
        child: Text(
          '计划与专注记录保存在本机',
          style: TextStyle(fontSize: 12, color: NestColors.faint),
        ),
      ),
    ],
  );
}
