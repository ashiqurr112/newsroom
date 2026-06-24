
class ArticleContentBlock {
  final String type; // 'text' or 'image'
  final String value;

  ArticleContentBlock({required this.type, required this.value});

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'value': value,
    };
  }

  factory ArticleContentBlock.fromJson(Map<String, dynamic> json) {
    return ArticleContentBlock(
      type: json['type'] as String,
      value: json['value'] as String,
    );
  }
}

class Article {
  final String id;
  final String title;
  final String link;
  final String description;
  final String contentSnippet;
  final DateTime pubDate;
  final String author;
  final String source;
  final int estimatedReadingTime; // in minutes
  final String region; // US, Europe, South Asia, Global
  final double readProgress; // 0.0 to 1.0
  final bool isReadLater;
  final bool isSaved;
  final bool isArchived;
  final DateTime? savedDate;
  final String? imageUrl;
  final List<ArticleContentBlock>? bodyContent;
  final DateTime? cachedDate;

  Article({
    required this.id,
    required this.title,
    required this.link,
    required this.description,
    required this.contentSnippet,
    required this.pubDate,
    required this.author,
    required this.source,
    required this.estimatedReadingTime,
    required this.region,
    this.readProgress = 0.0,
    this.isReadLater = false,
    this.isSaved = false,
    this.isArchived = false,
    this.savedDate,
    this.imageUrl,
    this.bodyContent,
    this.cachedDate,
  });

  Article copyWith({
    String? id,
    String? title,
    String? link,
    String? description,
    String? contentSnippet,
    DateTime? pubDate,
    String? author,
    String? source,
    int? estimatedReadingTime,
    String? region,
    double? readProgress,
    bool? isReadLater,
    bool? isSaved,
    bool? isArchived,
    DateTime? savedDate,
    String? imageUrl,
    List<ArticleContentBlock>? bodyContent,
    DateTime? cachedDate,
  }) {
    return Article(
      id: id ?? this.id,
      title: title ?? this.title,
      link: link ?? this.link,
      description: description ?? this.description,
      contentSnippet: contentSnippet ?? this.contentSnippet,
      pubDate: pubDate ?? this.pubDate,
      author: author ?? this.author,
      source: source ?? this.source,
      estimatedReadingTime: estimatedReadingTime ?? this.estimatedReadingTime,
      region: region ?? this.region,
      readProgress: readProgress ?? this.readProgress,
      isReadLater: isReadLater ?? this.isReadLater,
      isSaved: isSaved ?? this.isSaved,
      isArchived: isArchived ?? this.isArchived,
      savedDate: savedDate ?? this.savedDate,
      imageUrl: imageUrl ?? this.imageUrl,
      bodyContent: bodyContent ?? this.bodyContent,
      cachedDate: cachedDate ?? this.cachedDate,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'link': link,
      'description': description,
      'contentSnippet': contentSnippet,
      'pubDate': pubDate.toIso8601String(),
      'author': author,
      'source': source,
      'estimatedReadingTime': estimatedReadingTime,
      'region': region,
      'readProgress': readProgress,
      'isReadLater': isReadLater,
      'isSaved': isSaved,
      'isArchived': isArchived,
      'savedDate': savedDate?.toIso8601String(),
      'imageUrl': imageUrl,
      'bodyContent': bodyContent?.map((b) => b.toJson()).toList(),
      'cachedDate': cachedDate?.toIso8601String(),
    };
  }

  factory Article.fromJson(Map<String, dynamic> json) {
    return Article(
      id: json['id'] as String,
      title: json['title'] as String,
      link: json['link'] as String,
      description: json['description'] as String,
      contentSnippet: json['contentSnippet'] as String? ?? '',
      pubDate: DateTime.parse(json['pubDate'] as String),
      author: json['author'] as String,
      source: json['source'] as String,
      estimatedReadingTime: json['estimatedReadingTime'] as int? ?? 3,
      region: json['region'] as String? ?? 'Global',
      readProgress: (json['readProgress'] as num?)?.toDouble() ?? 0.0,
      isReadLater: json['isReadLater'] as bool? ?? false,
      isSaved: json['isSaved'] as bool? ?? false,
      isArchived: json['isArchived'] as bool? ?? false,
      savedDate: json['savedDate'] != null ? DateTime.parse(json['savedDate'] as String) : null,
      imageUrl: json['imageUrl'] as String?,
      bodyContent: json['bodyContent'] != null
          ? (json['bodyContent'] as List)
              .map((item) => ArticleContentBlock.fromJson(item as Map<String, dynamic>))
              .toList()
          : null,
      cachedDate: json['cachedDate'] != null ? DateTime.parse(json['cachedDate'] as String) : null,
    );
  }
}
