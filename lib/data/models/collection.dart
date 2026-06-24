class Collection {
  final String id;
  final String name;
  final int color; // Hex color code
  final List<String> articleIds;
  final List<String> tags;

  Collection({
    required this.id,
    required this.name,
    required this.color,
    required this.articleIds,
    required this.tags,
  });

  Collection copyWith({
    String? id,
    String? name,
    int? color,
    List<String>? articleIds,
    List<String>? tags,
  }) {
    return Collection(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      articleIds: articleIds ?? this.articleIds,
      tags: tags ?? this.tags,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'color': color,
      'articleIds': articleIds,
      'tags': tags,
    };
  }

  factory Collection.fromJson(Map<String, dynamic> json) {
    return Collection(
      id: json['id'] as String,
      name: json['name'] as String,
      color: json['color'] as int,
      articleIds: List<String>.from(json['articleIds'] as List? ?? []),
      tags: List<String>.from(json['tags'] as List? ?? []),
    );
  }
}
