import 'dart:convert';

// (Your _parseList helper function stays the same)
List<String> _parseList(dynamic jsonValue) {
  if (jsonValue == null) return [];
  if (jsonValue is String) {
    if (jsonValue.isEmpty) return [];
    try {
      final list = jsonDecode(jsonValue) as List;
      return list.map((e) => e.toString()).toList();
    } catch (e) {
      return [];
    }
  }
  if (jsonValue is List) {
    return jsonValue.map((e) => e.toString()).toList();
  }
  return [];
}

class RepairSuggestion {
  final String id;
  final String title;
  final List<String> steps;
  final List<String> tools;
  final double confidence;
  final int estimatedTimeMinutes;
  final String safetyNotes;
  final String query;
  final List<String> keywords;

  // --- 1. ADD THESE NEW COMMUNITY FIELDS ---
  final int tryCount;
  final double avgRating;
  final int ratingCount;
  final int commentCount;

  RepairSuggestion({
    required this.id,
    required this.title,
    required this.steps,
    required this.tools,
    required this.confidence,
    required this.estimatedTimeMinutes,
    required this.safetyNotes,
    this.query = '',
    this.keywords = const [],
    // --- 2. ADD TO CONSTRUCTOR (WITH DEFAULTS) ---
    this.tryCount = 0,
    this.avgRating = 0.0,
    this.ratingCount = 0,
    this.commentCount = 0,
  });

  factory RepairSuggestion.fromJson(Map<String, dynamic> json) {
    return RepairSuggestion(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: json['title'] ?? 'No Title',
      steps: _parseList(json['steps']),
      tools: _parseList(json['tools']),
      confidence: (json['confidence'] ?? 0.80).toDouble(),
      estimatedTimeMinutes: (json['estimatedTimeMinutes'] ?? 10).toInt(),
      safetyNotes: json['safetyNotes'] ?? '',
      query: json['query'] ?? '',
      keywords: _parseList(json['keywords']),
      // --- 3. ADD TO FROMJSON ---
      tryCount: (json['tryCount'] ?? 0).toInt(),
      avgRating: (json['avgRating'] ?? 0.0).toDouble(),
      ratingCount: (json['ratingCount'] ?? 0).toInt(),
      commentCount: (json['commentCount'] ?? 0).toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'steps': jsonEncode(steps),
      'tools': jsonEncode(tools),
      'confidence': confidence,
      'estimatedTimeMinutes': estimatedTimeMinutes,
      'safetyNotes': safetyNotes,
      'query': query,
      'keywords': jsonEncode(keywords),
      // --- 4. ADD TO TOJSON ---
      'tryCount': tryCount,
      'avgRating': avgRating,
      'ratingCount': ratingCount,
      'commentCount': commentCount,
    };
  }

  // --- 5. ADD TO COPYWITH ---
  RepairSuggestion copyWith({
    String? id,
    String? title,
    List<String>? steps,
    List<String>? tools,
    double? confidence,
    int? estimatedTimeMinutes,
    String? safetyNotes,
    String? query,
    List<String>? keywords,
    int? tryCount,
    double? avgRating,
    int? ratingCount,
    int? commentCount,
  }) {
    return RepairSuggestion(
      id: id ?? this.id,
      title: title ?? this.title,
      steps: steps ?? this.steps,
      tools: tools ?? this.tools,
      confidence: confidence ?? this.confidence,
      estimatedTimeMinutes: estimatedTimeMinutes ?? this.estimatedTimeMinutes,
      safetyNotes: safetyNotes ?? this.safetyNotes,
      query: query ?? this.query,
      keywords: keywords ?? this.keywords,
      tryCount: tryCount ?? this.tryCount,
      avgRating: avgRating ?? this.avgRating,
      ratingCount: ratingCount ?? this.ratingCount,
      commentCount: commentCount ?? this.commentCount,
    );
  }
}
