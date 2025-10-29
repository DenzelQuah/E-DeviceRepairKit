class RepairSuggestion {
  final String id;
  final String title;
  final List<String> steps;
  final List<String> tools;
  final double confidence;
  final int estimatedTimeMinutes;
  final String safetyNotes;

  RepairSuggestion({
    required this.id,
    required this.title,
    required this.steps,
    required this.tools,
    required this.confidence,
    required this.estimatedTimeMinutes,
    required this.safetyNotes,
  });
}