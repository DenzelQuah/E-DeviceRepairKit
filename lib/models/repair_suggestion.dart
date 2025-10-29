class RepairSuggestion {
  // 1. These are the "fields"
  final String id;
  final String title;
  final List<String> steps;
  final List<String> tools;
  final double confidence;
  final int estimatedTimeMinutes;
  final String safetyNotes;

  // 2. This is the "constructor"
  RepairSuggestion({
    required this.id,
    required this.title,
    required this.steps,
    required this.tools,
    required this.confidence,
    required this.estimatedTimeMinutes,
    required this.safetyNotes,
  });

  // 3. This is the "fromJson" factory
  factory RepairSuggestion.fromJson(Map<String, dynamic> json) {
    return RepairSuggestion(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: json['title'] ?? 'No Title',
      steps: List<String>.from(json['steps'] ?? []),
      tools: List<String>.from(json['tools'] ?? []),
      confidence: (json['confidence'] ?? 0.5).toDouble(),
      estimatedTimeMinutes: json['estimatedTimeMinutes'] ?? 10,
      safetyNotes: json['safetyNotes'] ?? '',
    );
  }

  // 4. This is the "toJson" method
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'steps': steps,
      'tools': tools,
      'confidence': confidence,
      'estimatedTimeMinutes': estimatedTimeMinutes,
      'safetyNotes': safetyNotes,
    };
  }
}