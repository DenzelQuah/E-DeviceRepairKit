import 'package:e_repairkit/models/ai_response.dart';
import 'package:e_repairkit/models/repair_suggestion.dart';
import 'package:e_repairkit/services/ai_service.dart';

class MockAIService implements AIService {
  @override
  Future<AIResponse> diagnose({required message}) async {
    await Future.delayed(const Duration(milliseconds: 800));

    final suggestion = RepairSuggestion(
      id: 'mock_sugg_1',
      title: 'How to fix: ${message.text}',
      steps: [
        'Step 1: Turn it off and on again.',
        'Step 2: Check all the cables.',
        'Step 3: If still broken, cry.',
      ],
      tools: ['Your hands'],
      confidence: 0.7,
      estimatedTimeMinutes: 5,
      safetyNotes: 'Do not perform near water.',
    );

    return AIResponse(
      suggestions: [suggestion],
      rawText: 'I think I know how to fix "${message.text}". Here is one suggestion.',
    );
  }
}