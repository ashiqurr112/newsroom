class Highlight {
  final String id;
  final String articleId;
  final String passageText;
  final String noteText;
  final DateTime createdAt;

  Highlight({
    required this.id,
    required this.articleId,
    required this.passageText,
    required this.noteText,
    required this.createdAt,
  });

  Highlight copyWith({
    String? id,
    String? articleId,
    String? passageText,
    String? noteText,
    DateTime? createdAt,
  }) {
    return Highlight(
      id: id ?? this.id,
      articleId: articleId ?? this.articleId,
      passageText: passageText ?? this.passageText,
      noteText: noteText ?? this.noteText,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'articleId': articleId,
      'passageText': passageText,
      'noteText': noteText,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Highlight.fromJson(Map<String, dynamic> json) {
    return Highlight(
      id: json['id'] as String,
      articleId: json['articleId'] as String,
      passageText: json['passageText'] as String,
      noteText: json['noteText'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
