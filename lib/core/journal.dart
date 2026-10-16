/// Only compact, verified facts survive each roll-up. AI cannot change totals.
class Review {
  const Review({
    required this.id,
    required this.level,
    required this.start,
    required this.end,
    required this.tasks,
    required this.units,
    required this.minutes,
    required this.cancelledMinutes,
    required this.sessions,
    required this.byGoal,
    required this.highlights,
    required this.advice,
    required this.digest,
    required this.sources,
    required this.createdAt,
  });
  final String id, level, start, end, advice, digest, createdAt;
  final int tasks, units, minutes, cancelledMinutes, sessions, sources;
  final Map<String, int> byGoal;
  final List<String> highlights;
  Map<String, Object?> toJson() => {
    'id': id,
    'level': level,
    'start': start,
    'end': end,
    'tasks': tasks,
    'units': units,
    'minutes': minutes,
    'cancelledMinutes': cancelledMinutes,
    'sessions': sessions,
    'byGoal': byGoal,
    'highlights': highlights,
    'advice': advice,
    'digest': digest,
    'sources': sources,
    'createdAt': createdAt,
  };
  factory Review.fromJson(Map<String, dynamic> j) => Review(
    id: j['id'] as String,
    level: j['level'] as String,
    start: j['start'] as String,
    end: j['end'] as String,
    tasks: j['tasks'] as int,
    units: j['units'] as int,
    minutes: j['minutes'] as int,
    cancelledMinutes: j['cancelledMinutes'] as int,
    sessions: j['sessions'] as int,
    byGoal: Map<String, int>.from(j['byGoal'] as Map),
    highlights: List<String>.from(j['highlights'] as List),
    advice: j['advice'] as String,
    digest: j['digest'] as String,
    sources: j['sources'] as int,
    createdAt: j['createdAt'] as String,
  );
}

class Workspace {
  Workspace({
    List<Review> reviews = const [],
    List<Map<String, String>> chat = const [],
    Map<String, dynamic>? draft,
    Map<String, dynamic> roadmaps = const {},
    this.rounds = 0,
    this.autoReview = false,
    this.demoAgent = false,
  }) : reviews = List.unmodifiable(reviews),
       chat = List.unmodifiable(
         chat.map((m) => Map<String, String>.unmodifiable(m)),
       ),
       draft = draft == null ? null : Map.unmodifiable(draft),
       roadmaps = Map.unmodifiable(roadmaps);
  final List<Review> reviews;
  final List<Map<String, String>> chat;
  final Map<String, dynamic>? draft;
  final Map<String, dynamic> roadmaps;
  final int rounds;
  final bool autoReview, demoAgent;
  Workspace copyWith({
    List<Review>? reviews,
    List<Map<String, String>>? chat,
    Map<String, dynamic>? draft,
    bool clearDraft = false,
    Map<String, dynamic>? roadmaps,
    int? rounds,
    bool? autoReview,
    bool? demoAgent,
  }) => Workspace(
    reviews: reviews ?? this.reviews,
    chat: chat ?? this.chat,
    draft: clearDraft ? null : draft ?? this.draft,
    roadmaps: roadmaps ?? this.roadmaps,
    rounds: rounds ?? this.rounds,
    autoReview: autoReview ?? this.autoReview,
    demoAgent: demoAgent ?? this.demoAgent,
  );
  Map<String, Object?> toJson() => {
    'reviews': reviews.map((r) => r.toJson()).toList(),
    'chat': chat,
    'draft': draft,
    'roadmaps': roadmaps,
    'rounds': rounds,
    'autoReview': autoReview,
    'demoAgent': demoAgent,
  };
  factory Workspace.fromJson(Map<String, dynamic> j) => Workspace(
    reviews: (j['reviews'] as List? ?? [])
        .map((r) => Review.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList(),
    chat: (j['chat'] as List? ?? [])
        .map((r) => Map<String, String>.from(r as Map))
        .toList(),
    draft: j['draft'] == null
        ? null
        : Map<String, dynamic>.from(j['draft'] as Map),
    roadmaps: Map<String, dynamic>.from(j['roadmaps'] as Map? ?? {}),
    rounds: j['rounds'] as int? ?? 0,
    autoReview: j['autoReview'] as bool? ?? false,
    demoAgent: j['demoAgent'] as bool? ?? false,
  );
}
