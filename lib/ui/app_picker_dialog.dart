import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/planning.dart';
import 'theme.dart';

/// Shows only apps that are not already allowed, so multiple choices can be
/// added in one save without mixing the current whitelist into the catalog.
class AppPickerDialog extends StatefulWidget {
  const AppPickerDialog({super.key, required this.apps});

  final List<InstalledApp> apps;

  @override
  State<AppPickerDialog> createState() => _AppPickerDialogState();
}

class _AppPickerDialogState extends State<AppPickerDialog> {
  final selected = <String>{};
  String query = '';
  String category = '全部';

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final categories = [
      '全部',
      ...widget.apps.map((a) => a.category).toSet().toList()..sort(),
    ];
    final visible = widget.apps.where((app) {
      final matchesCategory = category == '全部' || app.category == category;
      final matchesQuery =
          query.isEmpty ||
          app.name.toLowerCase().contains(query) ||
          app.package.toLowerCase().contains(query);
      return matchesCategory && matchesQuery;
    }).toList();
    return Dialog(
      child: SizedBox(
        width: math.min(size.width - 32, 600),
        height: math.min(size.height * 0.73, 700),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('添加白名单应用', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              const Text('勾选专注时需要使用的应用，可一次添加多个。'),
              const SizedBox(height: 16),
              TextField(
                key: const Key('app-picker-search'),
                decoration: const InputDecoration(
                  hintText: '搜索应用名称',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (value) =>
                    setState(() => query = value.trim().toLowerCase()),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final choice = categories[index];
                    return ChoiceChip(
                      label: Text(choice),
                      selected: choice == category,
                      onSelected: (_) => setState(() => category = choice),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: visible.isEmpty
                    ? Center(
                        child: Text(
                          widget.apps.isEmpty ? '所有可选应用都已加入白名单' : '没有找到匹配的应用',
                        ),
                      )
                    : ListView.builder(
                        itemCount: visible.length,
                        itemBuilder: (context, index) {
                          final app = visible[index];
                          return CheckboxListTile(
                            key: Key('pick-${app.package}'),
                            contentPadding: EdgeInsets.zero,
                            title: Text(app.name),
                            subtitle: Text(app.category),
                            value: selected.contains(app.package),
                            onChanged: (checked) => setState(() {
                              if (checked == true) {
                                selected.add(app.package);
                              } else {
                                selected.remove(app.package);
                              }
                            }),
                          );
                        },
                      ),
              ),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '已选 ${selected.length} 个',
                      style: const TextStyle(color: NestColors.muted),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    key: const Key('confirm-app-picker'),
                    onPressed: selected.isEmpty
                        ? null
                        : () => Navigator.pop(
                            context,
                            widget.apps
                                .where((a) => selected.contains(a.package))
                                .toList(),
                          ),
                    child: const Text('添加'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
