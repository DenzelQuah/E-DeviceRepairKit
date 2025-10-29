import '../models/ai_response.dart';
import '../models/message.dart';

abstract class AIService {
  Future<AIResponse> diagnose({required Message message});
}