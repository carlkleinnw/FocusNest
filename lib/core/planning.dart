class Goal {
  const Goal({
    required this.id,
    required this.title,
    required this.deadline,
    required this.totalUnits,
    this.unit = '项',
  });
  final String id, title, unit, deadline;
  final int totalUnits;
  Map<String, Object> toJson() => {
    'id': id,
    'title': title,
    'deadline': deadline,
    'totalUnits': totalUnits,
    'unit': unit,
  };
  factory Goal.fromJson(Map<String, dynamic> j) => Goal(
    id: j['id'] as String,
    title: j['title'] as String,
    deadline: j['deadline'] as String,
    totalUnits: j['totalUnits'] as int,
    unit: j['unit'] as String,
  );
}

class Milestone {
  const Milestone({
    required this.id,
    required this.goalId,
    required this.title,
    required this.units,
    required this.deadline,
  });
  final String id, goalId, title, deadline;
  final int units;
  Map<String, Object> toJson() => {
    'id': id,
    'goalId': goalId,
    'title': title,
    'units': units,
    'deadline': deadline,
  };
  factory Milestone.fromJson(Map<String, dynamic> j) => Milestone(
    id: j['id'] as String,
    goalId: j['goalId'] as String,
    title: j['title'] as String,
    units: j['units'] as int,
    deadline: j['deadline'] as String,
  );
}

class InstalledApp {
  const InstalledApp({
    required this.package,
    required this.name,
    required this.category,
    this.protected = false,
    this.recommendedBlocked = false,
  });
  final String package, name, category;
  final bool protected, recommendedBlocked;
  factory InstalledApp.fromJson(Map<String, dynamic> j) => InstalledApp(
    package: j['package'] as String,
    name: j['name'] as String,
    category: j['category'] as String,
    protected: j['protected'] as bool,
    recommendedBlocked: j['recommendedBlocked'] as bool,
  );
}
