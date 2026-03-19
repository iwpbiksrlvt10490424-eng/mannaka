class SavedGroup {
  const SavedGroup({
    required this.id,
    required this.name,
    required this.memberNames,
    required this.createdAt,
  });

  final String id;
  final String name;
  final List<String> memberNames;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'memberNames': memberNames,
        'createdAt': createdAt.toIso8601String(),
      };

  factory SavedGroup.fromJson(Map<String, dynamic> j) => SavedGroup(
        id: j['id'] as String,
        name: j['name'] as String,
        memberNames: List<String>.from(j['memberNames'] as List),
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}
