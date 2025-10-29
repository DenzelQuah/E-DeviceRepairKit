import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import '../../models/ai_response.dart';
import '../../models/message.dart';
import '../ai_service.dart';

class GeminiAIService implements AIService {
  final GenerativeModel _model;

  GeminiAIService()
      : _model = GenerativeModel(
          // Use 'gemini-1.5-flash' for the fastest, cheapest model
          model: 'models/gemini-2.5-flash',
          
          apiKey: dotenv.env['GEMINI_API_KEY']!,
          // Set safety settings to be less restrictive
          safetySettings: [
              SafetySetting(HarmCategory.harassment, HarmBlockThreshold.none),
              SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.none),
              SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.none),
              SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.none),
          ]
        );

  @override
  Future<AIResponse> diagnose({required Message message}) async {
    try {
      final prompt = _buildPrompt(message.text);
      // --- THIS IS WHERE _model IS USED ---
      final response = await _model.generateContent([Content.text(prompt)]);
      
      if (response.text == null) {
        throw Exception('Response was blocked or empty.');
      }

      return _parseResponse(response.text!);
    } catch (e) {
      print('Error calling Gemini API: $e');
      // If model-not-found, log available models to help debugging
      if (e.toString().contains('is not found')) {
        await _logAvailableModels();
      }
      throw Exception('Failed to get diagnosis from AI.');
    }
  }

  // --- PRIVATE HELPERS ---

  String _buildPrompt(String problem) {
    // This tells the AI its job and *exactly* what JSON format to return.
    return '''
    You are an expert electronics repair assistant.
    A user has this problem: "$problem"

    You MUST reply ONLY with a valid JSON object. Do not include ```json or any other text.
    The JSON object must have two keys: "rawText" and "suggestions".
    - "rawText": A short, friendly reply to the user.
    - "suggestions": A list of repair suggestions.

    Each suggestion object in the list must have these exact keys:
    - "id": A unique string ID
    - "title": A short title for the repair step
    - "steps": A list of strings, each being a clear, easy-to-follow step
    - "tools": A list of strings for required tools
    - "confidence": A number between 0.0 and 1.0
    - "estimatedTimeMinutes": An integer for the time in minutes
    - "safetyNotes": A string with any safety warnings.

    Here is an example of a perfect response:
    {
      "rawText": "I see your phone screen is cracked. Here's a suggestion.",
      "suggestions": [
        {
          "id": "sugg_123",
          "title": "Assess Screen Damage",
          "steps": [
            "Power off the device.",
            "Inspect the screen under a bright light to check the extent of the damage."
          ],
          "tools": ["Bright light"],
          "confidence": 0.9,
          "estimatedTimeMinutes": 5,
          "safetyNotes": "Be careful not to cut your fingers on broken glass."
        }
      ]
    }
    ''';
  }

  AIResponse _parseResponse(String responseText) {
    try {
      // Clean the response text (sometimes Gemini adds ```json)
      final cleanedText = responseText
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();
          
      // --- THIS IS WHERE 'dart:convert' IS USED ---
      final jsonMap = jsonDecode(cleanedText) as Map<String, dynamic>;
      return AIResponse.fromJson(jsonMap, responseText);
    } catch (e) {
    // ignore: avoid_print
    print('Error parsing JSON response: $e');
    // ignore: avoid_print
    print('Raw AI Response: $responseText');
      // Fallback in case of bad JSON
      return AIResponse(
        suggestions: [],
        rawText: "Sorry, I had trouble formatting my response. Please try again.",
      );
    }
  }

  Future<void> _logAvailableModels() async {
    final key = dotenv.env['GEMINI_API_KEY'];
    if (key == null) {
      print('No API key found in env; cannot list models.');
      return;
    }
    try {
      final uri = Uri.parse('https://generativelanguage.googleapis.com/v1/models?key=$key');
      final res = await http.get(uri);
      print('ListModels status: ${res.statusCode}');
      print('ListModels body: ${res.body}');
    } catch (err) {
      print('Failed to list models: $err');
    }
  }

}