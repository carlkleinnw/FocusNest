import 'dart:convert';
import 'models.dart';
import 'planning.dart';
import 'planner_agent.dart' show AgentFailure, validateDraft;

/// Period outlines reuse the existing roadmap storage. Legacy rows acquire a
/// deterministic ID; an edited row keeps that ID even when its dates change.
class PeriodPlan {
  const PeriodPlan({
    required this.id,
    required this.level,
    required this.title,
    required this.start,
    required this.end,
    this.goalId,
  });
  final String id, level, title, start, end;
  final String? goalId;
  Map<String, dynamic> toJson() => {
    'id': id,
    'level': level,
    'title': title,
    'start': start,
    'end': end,
    'goalId': goalId,
  };
}

List<PeriodPlan> periodPlans(AppState s) {
  final result = <PeriodPlan>[];
  for (final entry in s.workspace.roadmaps.entries) {
    final roadmap = entry.value as Map;
    for (final level in ['week', 'month', 'quarter']) {
      final key = {
        'week': 'weeks',
        'month': 'months',
        'quarter': 'quarters',
      }[level]!;
      for (final raw in roadmap[key] as List? ?? []) {
        final row = raw as Map;
        final month = row['month'] as String?;
        final start = row['start'] as String? ?? '$month-01';
        final date = DateTime.tryParse(start);
        if (date == null) continue;
        final end =
            row['end'] as String? ??
            dateKey(DateTime(date.year, date.month + 1, 0));
        result.add(
          PeriodPlan(
            id: row['id'] as String? ?? '${entry.key}_${level}_$start',
            level: level,
            title: row['objective'] as String,
            start: start,
            end: end,
            goalId: entry.key == '_standalone' ? null : entry.key,
          ),
        );
      }
    }
    if (!roadmap.containsKey('quarters')) {
      final months = result
          .where((p) => p.goalId == entry.key && p.level == 'month')
          .toList();
      final groups = <String, List<PeriodPlan>>{};
      for (final m in months) {
        final d = DateTime.parse(m.start);
        final start = dateKey(DateTime(d.year, ((d.month - 1) ~/ 3) * 3 + 1));
        (groups[start] ??= []).add(m);
      }
      for (final group in groups.entries) {
        final d = DateTime.parse(group.key);
        result.add(
          PeriodPlan(
            id: '${entry.key}_quarter_${group.key}',
            level: 'quarter',
            title: group.value.map((p) => p.title).toSet().join('；'),
            start: group.key,
            end: dateKey(DateTime(d.year, d.month + 3, 0)),
            goalId: entry.key,
          ),
        );
      }
    }
  }
  return result;
}

AppState withPeriodPlans(AppState s, List<PeriodPlan> periods) {
  final maps = <String, dynamic>{};
  for (final e in s.workspace.roadmaps.entries) {
    maps[e.key] = {
      ...Map<String, dynamic>.from(e.value as Map),
      'weeks': <Object>[],
      'months': <Object>[],
      'quarters': <Object>[],
    };
  }
  for (final p in periods) {
    final id = p.goalId ?? '_standalone';
    maps.putIfAbsent(
      id,
      () => {
        'title':
            s.goals.where((g) => g.id == id).firstOrNull?.title ?? '独立周期计划',
        'assumptions': <String>[],
        'tasks': <Object>[],
        'weeks': <Object>[],
        'months': <Object>[],
        'quarters': <Object>[],
      },
    );
    final key = {
      'week': 'weeks',
      'month': 'months',
      'quarter': 'quarters',
    }[p.level]!;
    (maps[id][key] as List).add({
      'id': p.id,
      'start': p.start,
      'end': p.end,
      if (p.level == 'month') 'month': p.start.substring(0, 7),
      'objective': p.title,
    });
  }
  return s.copyWith(workspace: s.workspace.copyWith(roadmaps: maps));
}

Map<String, dynamic> planContext(AppState s) => {
  'today': s.dayKey,
  'dailyCapacity': s.dailyCapacity,
  'goals': s.goals.map((g) => g.toJson()).toList(),
  'periods': periodPlans(s).map((p) => p.toJson()).toList(),
  'tasks': s.plans
      .map(
        (p) => {
          'id': p.id,
          'title': p.title,
          'date': p.date,
          'time': p.time,
          'minutes': p.minutes,
          'goalId': p.goalId,
          'units': p.units,
          'doneUnits': p.doneUnits,
          'milestoneId': p.milestoneId,
          'rollovers': p.rollovers,
        },
      )
      .toList(),
  'milestones': s.milestones.map((p) => p.toJson()).toList(),
};
String planRevision(AppState s) => jsonEncode({
  ...planContext(s),
  'tasks': s.plans.map((p) => p.toJson()).toList(),
});

/// A bounded catalog lets the model discover details with queries rather than
/// filling every request with an ever-growing database. Revision checks still
/// use the complete data above, never this preview.
Map<String, dynamic> agentPlanContext(AppState s) {
  final all = planContext(s);
  return {
    'today': s.dayKey,
    'dailyCapacity': s.dailyCapacity,
    for (final entry in {'goals': 50, 'periods': 80, 'tasks': 80}.entries)
      entry.key: {
        'count': (all[entry.key] as List).length,
        'preview': (all[entry.key] as List).take(entry.value).toList(),
        'truncated': (all[entry.key] as List).length > entry.value,
      },
    'milestones': all['milestones'],
  };
}

class PlanActionResult {
  PlanActionResult(this.state, this.receipts, this.changed);
  final AppState state;
  final List<Map<String, dynamic>> receipts;
  final bool changed;
}

List<Map<String, dynamic>> draftActions(
  Map<String, dynamic> raw,
  AppState s,
  String id,
) {
  final draft = validateDraft(raw, s);
  final tasks = (draft['tasks'] as List).cast<Map<String, dynamic>>();
  final dates = tasks.map((t) => t['date'] as String).toList()..sort();
  final periods = <PeriodPlan>[];
  for (final month in draft['months'] as List) {
    final start = DateTime.parse('${month['month']}-01');
    periods.add(
      PeriodPlan(
        id: '${id}_month_${month['month']}',
        level: 'month',
        title: month['objective'] as String,
        start: dateKey(start),
        end: dateKey(DateTime(start.year, start.month + 1, 0)),
        goalId: id,
      ),
    );
  }
  for (var i = 0; i < (draft['weeks'] as List).length; i++) {
    final week = draft['weeks'][i] as Map;
    periods.add(
      PeriodPlan(
        id: '${id}_week_$i',
        level: 'week',
        title: week['objective'] as String,
        start: week['start'] as String,
        end: week['end'] as String,
        goalId: id,
      ),
    );
  }
  final quarters = <String>{};
  for (final task in tasks) {
    final d = DateTime.parse(task['date'] as String);
    final start = DateTime(d.year, ((d.month - 1) ~/ 3) * 3 + 1);
    if (quarters.add(dateKey(start))) {
      periods.add(
        PeriodPlan(
          id: '${id}_quarter_${dateKey(start)}',
          level: 'quarter',
          title: '围绕「${draft['title']}」完成本季度阶段成果',
          start: dateKey(start),
          end: dateKey(DateTime(start.year, start.month + 3, 0)),
          goalId: id,
        ),
      );
    }
  }
  return [
    {
      'op': 'create',
      'entity': 'goal',
      'id': id,
      'values': {
        'title': draft['title'],
        'deadline': dates.last,
        'totalUnits': tasks.length,
        'unit': '项',
      },
    },
    for (final p in periods)
      {
        'op': 'create',
        'entity': 'period',
        'id': p.id,
        'values': {...p.toJson()}..remove('id'),
      },
    for (var i = 0; i < tasks.length; i++)
      {
        'op': 'create',
        'entity': 'task',
        'id': '${id}_$i',
        'values': {...tasks[i], 'goalId': id, 'category': 'AI 计划'},
      },
  ];
}

String _text(Object? v, [int max = 60]) {
  if (v is! String || v.trim().isEmpty || v.length > max) {
    throw const AgentFailure('计划字段缺失或过长，原计划未修改。');
  }
  return v.trim();
}

String _day(Object? v) {
  final text = _text(v, 10);
  final d = DateTime.tryParse(text);
  if (d == null || dateKey(d) != text) throw const AgentFailure('日期无效，原计划未修改。');
  return text;
}

int _int(Object? v, int min, int max) {
  if (v is! int || v < min || v > max) {
    throw const AgentFailure('数量或时长超出范围，原计划未修改。');
  }
  return v;
}

void validatePeriod(PeriodPlan p, AppState s) {
  _text(p.title, 240);
  _day(p.start);
  _day(p.end);
  if (!['week', 'month', 'quarter'].contains(p.level) ||
      p.end.compareTo(p.start) < 0 ||
      (p.goalId != null && !s.goals.any((g) => g.id == p.goalId))) {
    throw const AgentFailure('周期或关联目标无效。');
  }
  final start = DateTime.parse(p.start), end = DateTime.parse(p.end);
  if ((p.level == 'week' && end.difference(start).inDays > 6) ||
      (p.level == 'month' &&
          p.start.substring(0, 7) != p.end.substring(0, 7)) ||
      (p.level == 'quarter' &&
          (start.year != end.year ||
              (start.month - 1) ~/ 3 != (end.month - 1) ~/ 3))) {
    throw const AgentFailure('周计划最多7天，月／季度计划应在同一自然月／季度内。');
  }
}

/// Pure transactional tool executor shared by the agent and period editors.
/// IDs must be observed or created explicitly. Unknown fields never grant new
/// capabilities (notably no key, file, permission, or completion access).
PlanActionResult applyPlanActions(AppState initial, Object? raw, String stamp) {
  if (raw is! List || raw.isEmpty || raw.length > 500) {
    throw const AgentFailure('计划操作数量无效。');
  }
  var s = initial;
  var changed = false;
  final receipts = <Map<String, dynamic>>[];
  final touchedDates = <String>{};
  for (var index = 0; index < raw.length; index++) {
    if (raw[index] is! Map) throw const AgentFailure('计划操作格式无效。');
    final a = Map<String, dynamic>.from(raw[index] as Map);
    final op = a['op'], entity = a['entity'];
    if (op == 'create_plan' && entity == 'goal') {
      final id = a['id'] == null ? 'ai_${stamp}_$index' : _text(a['id'], 100);
      final draft = Map<String, dynamic>.from(a['values'] as Map);
      final result = applyPlanActions(
        s,
        draftActions(draft, s, id),
        '${stamp}_full_$index',
      );
      final maps = {...result.state.workspace.roadmaps};
      maps[id] = {
        ...maps[id] as Map,
        'assumptions': draft['assumptions'],
        'demo': s.workspace.demoAgent,
      };
      s = result.state.copyWith(
        workspace: result.state.workspace.copyWith(
          roadmaps: maps,
          clearDraft: true,
        ),
      );
      changed = true;
      receipts.addAll(result.receipts);
      continue;
    }
    if (!['query', 'create', 'update', 'delete'].contains(op) ||
        !['task', 'goal', 'period'].contains(entity)) {
      throw const AgentFailure('不支持的计划操作，原计划未修改。');
    }
    final rows = entity == 'task'
        ? s.plans.map((p) => p.toJson()).toList()
        : entity == 'goal'
        ? s.goals.map((g) => g.toJson()).toList()
        : periodPlans(s).map((p) => p.toJson()).toList();
    if (op == 'query') {
      final filter = a['filter'] == null
          ? <String, dynamic>{}
          : Map<String, dynamic>.from(a['filter'] as Map);
      if (filter.keys.any(
        (k) => ![
          'id',
          'goalId',
          'level',
          'from',
          'to',
          'text',
          'done',
        ].contains(k),
      )) {
        throw const AgentFailure('查询条件无效。');
      }
      final found = rows.where((r) {
        final start = '${r['date'] ?? r['start'] ?? r['deadline']}';
        final end = '${r['date'] ?? r['end'] ?? r['deadline']}';
        return (filter['id'] == null || r['id'] == filter['id']) &&
            (filter['goalId'] == null || r['goalId'] == filter['goalId']) &&
            (filter['level'] == null || r['level'] == filter['level']) &&
            (filter['from'] == null ||
                end.compareTo(_day(filter['from'])) >= 0) &&
            (filter['to'] == null ||
                start.compareTo(_day(filter['to'])) <= 0) &&
            (filter['text'] == null ||
                '${r['title']}'.toLowerCase().contains(
                  _text(filter['text']).toLowerCase(),
                )) &&
            (filter['done'] == null ||
                entity == 'task' &&
                    ((r['doneUnits'] as int) >= (r['units'] as int)) ==
                        filter['done']);
      }).toList();
      final offset = _int(a['offset'] ?? 0, 0, 1000000);
      final limit = _int(a['limit'] ?? 100, 1, 200);
      receipts.add({
        'op': op,
        'entity': entity,
        'count': found.length,
        'rows': found.skip(offset).take(limit).toList(),
        'offset': offset,
        'nextOffset': offset + limit < found.length ? offset + limit : null,
      });
      continue;
    }
    final id = a['id'] == null && op == 'create'
        ? 'agent_${stamp}_$index'
        : _text(a['id'], 128);
    if (!RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(id)) {
      throw const AgentFailure('计划标识无效。');
    }
    final existing = rows.where((r) => r['id'] == id).firstOrNull;
    if ((op == 'create' && existing != null) ||
        (op != 'create' && existing == null)) {
      throw const AgentFailure('计划已变化或目标不存在，请重新查询。');
    }
    if (op == 'delete') {
      if (entity == 'task') {
        s = s.copyWith(plans: s.plans.where((p) => p.id != id).toList());
      } else if (entity == 'period') {
        s = withPeriodPlans(
          s,
          periodPlans(s).where((p) => p.id != id).toList(),
        );
      } else {
        final cascade = a['cascade'] == true;
        final maps = {...s.workspace.roadmaps}..remove(id);
        // Goal deletion is explicit about child tasks; completed evidence stays.
        s = s.copyWith(
          goals: s.goals.where((g) => g.id != id).toList(),
          milestones: s.milestones.where((m) => m.goalId != id).toList(),
          plans: s.plans
              .where((p) => !cascade || p.goalId != id || p.done)
              .map(
                (p) => p.goalId != id
                    ? p
                    : Plan(
                        id: p.id,
                        title: p.title,
                        minutes: p.minutes,
                        time: p.time,
                        category: p.category,
                        date: p.date,
                        units: p.units,
                        doneUnits: p.doneUnits,
                        completedAt: p.completedAt,
                        originalDate: p.originalDate,
                        rollovers: p.rollovers,
                      ),
              )
              .toList(),
          workspace: s.workspace.copyWith(roadmaps: maps),
        );
      }
    } else {
      final values = Map<String, dynamic>.from(a['values'] as Map? ?? {});
      final allowed = entity == 'task'
          ? ['title', 'date', 'minutes', 'time', 'goalId', 'category']
          : entity == 'goal'
          ? ['title', 'deadline', 'totalUnits', 'unit']
          : ['title', 'level', 'start', 'end', 'goalId'];
      if (values.keys.any((k) => !allowed.contains(k))) {
        throw const AgentFailure('操作包含不支持的字段；任务完成需由你手动确认。');
      }
      final v = {...?existing, ...values};
      if (entity == 'task') {
        final old = s.plans.where((p) => p.id == id).firstOrNull;
        final day = _day(v['date']);
        if (day.compareTo(s.dayKey) < 0 && day != old?.date) {
          throw const AgentFailure('新任务不能安排在过去。');
        }
        final time = _text(v['time'] ?? '19:00', 5);
        if (!RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(time)) {
          throw const AgentFailure('任务时间无效。');
        }
        if (s.plans.any(
          (p) =>
              p.id != id &&
              p.date == day &&
              p.time == time &&
              p.title == v['title'],
        )) {
          throw const AgentFailure('同日同时间已有同名任务，请修改已有任务，避免重复创建。');
        }
        final plan = Plan(
          id: id,
          title: _text(v['title']),
          date: day,
          minutes: _int(v['minutes'] ?? 30, 30, 180),
          time: time,
          goalId: (v['goalId'] == '' ? null : v['goalId']) as String?,
          milestoneId: old?.goalId == v['goalId'] ? old?.milestoneId : null,
          category: _text(v['category'] ?? '学习'),
          units: old?.units ?? 1,
          doneUnits: old?.doneUnits ?? 0,
          completedAt: old?.completedAt,
          originalDate: old?.originalDate.isNotEmpty == true
              ? old!.originalDate
              : day,
          rollovers: old?.rollovers ?? 0,
        );
        s = s.copyWith(plans: [...s.plans.where((p) => p.id != id), plan]);
        touchedDates.add(day);
      } else if (entity == 'goal') {
        final goal = Goal(
          id: id,
          title: _text(v['title']),
          deadline: _day(v['deadline']),
          totalUnits: _int(v['totalUnits'] ?? 100000, 1, 100000),
          unit: _text(v['unit'] ?? '项', 8),
        );
        if (goal.deadline.compareTo(s.dayKey) < 0 &&
            existing?['deadline'] != goal.deadline) {
          throw const AgentFailure('目标截止日期不能在过去。');
        }
        s = s.copyWith(goals: [...s.goals.where((g) => g.id != id), goal]);
        if (s.workspace.roadmaps.containsKey(id)) {
          s = s.copyWith(
            workspace: s.workspace.copyWith(
              roadmaps: {
                ...s.workspace.roadmaps,
                id: {...s.workspace.roadmaps[id] as Map, 'title': goal.title},
              },
            ),
          );
        }
      } else {
        final p = PeriodPlan(
          id: id,
          level: _text(v['level']),
          title: _text(v['title'], 240),
          start: _day(v['start']),
          end: _day(v['end']),
          goalId: (v['goalId'] == '' ? null : v['goalId']) as String?,
        );
        validatePeriod(p, s);
        s = withPeriodPlans(s, [...periodPlans(s).where((p) => p.id != id), p]);
      }
    }
    changed = true;
    receipts.add({
      'op': op,
      'entity': entity,
      'id': id,
      'title': op == 'delete'
          ? existing!['title']
          : (a['values'] as Map?)?['title'] ?? existing?['title'],
      'status': 'staged',
    });
  }
  // Validate the final batch, allowing a task to be moved and its old date reused
  // in either order. An invalid action aborts the complete transaction.
  for (final p in s.plans) {
    if (p.goalId != null && !s.goals.any((g) => g.id == p.goalId)) {
      throw const AgentFailure('关联目标不存在，原计划未修改。');
    }
  }
  for (final day in touchedDates) {
    final before = initial.plans
        .where((p) => p.date == day && !p.done)
        .fold(0, (n, p) => n + p.minutes);
    final after = s.plans
        .where((p) => p.date == day && !p.done)
        .fold(0, (n, p) => n + p.minutes);
    if (after > s.dailyCapacity && after > before) {
      throw AgentFailure('$day 超过每日可用的 ${s.dailyCapacity} 分钟，原计划未修改。');
    }
  }
  for (final g in s.goals) {
    final tasks = s.plans.where((p) => p.goalId == g.id);
    final archived = s.workspace.reviews.fold(
      0,
      (n, r) => n + (r.byGoal[g.id] ?? 0),
    );
    final stages = s.milestones.where((m) => m.goalId == g.id);
    if (tasks.fold(0, (n, p) => n + p.units) + archived > g.totalUnits ||
        stages.fold(0, (n, m) => n + m.units) > g.totalUnits ||
        stages.any((m) => m.deadline.compareTo(g.deadline) > 0) ||
        tasks.any(
          (p) => p.rollovers == 0 && p.date.compareTo(g.deadline) > 0,
        )) {
      throw const AgentFailure('任务超出总目标数量或截止日期，请同时调整总目标。');
    }
  }
  for (final m in s.milestones) {
    if (s.plans
                .where((p) => p.milestoneId == m.id)
                .fold(0, (n, p) => n + p.units) >
            m.units ||
        s.plans.any(
          (p) =>
              p.milestoneId == m.id &&
              (p.goalId != m.goalId ||
                  p.rollovers == 0 && p.date.compareTo(m.deadline) > 0),
        )) {
      throw const AgentFailure('任务超出原有阶段数量或截止日期，原计划未修改。');
    }
  }
  return PlanActionResult(s, receipts, changed);
}
