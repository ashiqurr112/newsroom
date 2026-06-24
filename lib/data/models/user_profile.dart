class UserProfile {
  final int streakCount;
  final String lastReadDate; // YYYY-MM-DD
  final List<String> readDates; // List of YYYY-MM-DD
  final List<String> followedAuthors;
  final List<String> mutedKeywords;
  final Map<String, int> paperPriorities; // Newspaper name -> Rank (1, 2, 3...)
  final List<String> searchHistory;
  final String selectedRegion; // Filter (e.g. All, US, South Asia)
  final Map<String, bool> enabledPapers; // Newspaper name -> enabled/disabled

  UserProfile({
    this.streakCount = 0,
    this.lastReadDate = '',
    this.readDates = const [],
    this.followedAuthors = const [],
    this.mutedKeywords = const [],
    this.paperPriorities = const {},
    this.searchHistory = const [],
    this.selectedRegion = 'All',
    this.enabledPapers = const {},
  });

  UserProfile copyWith({
    int? streakCount,
    String? lastReadDate,
    List<String>? readDates,
    List<String>? followedAuthors,
    List<String>? mutedKeywords,
    Map<String, int>? paperPriorities,
    List<String>? searchHistory,
    String? selectedRegion,
    Map<String, bool>? enabledPapers,
  }) {
    return UserProfile(
      streakCount: streakCount ?? this.streakCount,
      lastReadDate: lastReadDate ?? this.lastReadDate,
      readDates: readDates ?? this.readDates,
      followedAuthors: followedAuthors ?? this.followedAuthors,
      mutedKeywords: mutedKeywords ?? this.mutedKeywords,
      paperPriorities: paperPriorities ?? this.paperPriorities,
      searchHistory: searchHistory ?? this.searchHistory,
      selectedRegion: selectedRegion ?? this.selectedRegion,
      enabledPapers: enabledPapers ?? this.enabledPapers,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'streakCount': streakCount,
      'lastReadDate': lastReadDate,
      'readDates': readDates,
      'followedAuthors': followedAuthors,
      'mutedKeywords': mutedKeywords,
      'paperPriorities': paperPriorities,
      'searchHistory': searchHistory,
      'selectedRegion': selectedRegion,
      'enabledPapers': enabledPapers,
    };
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      streakCount: json['streakCount'] as int? ?? 0,
      lastReadDate: json['lastReadDate'] as String? ?? '',
      readDates: List<String>.from(json['readDates'] as List? ?? []),
      followedAuthors: List<String>.from(json['followedAuthors'] as List? ?? []),
      mutedKeywords: List<String>.from(json['mutedKeywords'] as List? ?? []),
      paperPriorities: Map<String, int>.from(json['paperPriorities'] as Map? ?? {}),
      searchHistory: List<String>.from(json['searchHistory'] as List? ?? []),
      selectedRegion: json['selectedRegion'] as String? ?? 'All',
      enabledPapers: Map<String, bool>.from(json['enabledPapers'] as Map? ?? {}),
    );
  }
}
