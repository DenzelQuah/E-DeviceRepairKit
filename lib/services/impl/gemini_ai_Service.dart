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
        ],
      );

  @override
  Future<AIResponse> diagnose({
    required Message message,
    String? imagePath,
    double? temperature,
    double? topP,
    String? mode,
    Map<String, dynamic>? imageAnalysis,
  }) async {
    try {
      final prompt = _buildPrompt(
        message.text,
        imagePath: imagePath,
        temperature: temperature,
        mode: mode,
        imageAnalysis: imageAnalysis,
      );
      // --- THIS IS WHERE _model IS USED ---
      // Note: the plugin call is kept simple; creativity knobs are included in the prompt so
      // behaviour can be influenced without changing SDK calls. If your SDK supports passing
      // temperature/top_p, extend this call accordingly.
      if (imageAnalysis != null) {
        // small debug hint to logs to help trace whether imageAnalysis is included
        // ignore: avoid_print
        print(
          'GeminiAIService: sending imageAnalysis to model: ${jsonEncode(imageAnalysis)}',
        );
      }
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

  String _buildPrompt(
    String problem, {
    String? imagePath,
    double? temperature,
    String? mode,
    Map<String, dynamic>? imageAnalysis,
  }) {
    // This tells the AI its job and *exactly* what JSON format to return.
    // Add a short header to control creativity when provided
  String modeInstruction = '';
    if (mode == 'experimental') {
      modeInstruction = '''
      IMPORTANT: You are in EXPERIMENTAL mode.
      Provide one safe, practical solution first. 
      Then, provide a *second* solution that is more creative, experimental, or unconventional (a "tinker's trick" or "clever hack"). 
      Clearly label the second solution "🧪 Experimental Hack:" and include a small warning.
      ''';
    } else {
      modeInstruction = '''
      IMPORTANT: You are in PRACTICAL mode.
      Provide ONLY the most common, safest, and most reliable solutions. Do not suggest anything risky.
      ''';
    }

    final imageNote =
        (imagePath != null)
            ? '\nUser attached an image; analyze visible faults when possible.'
            : '';

    String analysisNote = '';
    if (imageAnalysis != null) {
      try {
        final rawLabels = imageAnalysis['labels'] ?? [];
        final ocr = imageAnalysis['ocr'] ?? '';
        final filename =
            imageAnalysis['attachedImageFilename'] ?? imagePath ?? '';
        final unavailable = imageAnalysis['analysisUnavailable'] == true;

        // Normalize labels: they might be List<Map> with 'label' and 'confidence' or older List<String>.
        final formattedLabels = <String>[];
        double topConfidence = 0.0;
        String topLabel = '';

        if (rawLabels is List) {
          for (final l in rawLabels) {
            if (l is Map && l.containsKey('label')) {
              final lab = l['label'] as String;
              final conf =
                  (l['confidence'] is num)
                      ? (l['confidence'] as num).toDouble()
                      : 0.0;
              formattedLabels.add('$lab (${(conf * 100).toStringAsFixed(0)}%)');
              if (conf > topConfidence) {
                topConfidence = conf;
                topLabel = lab;
              }
            } else if (l is String) {
              formattedLabels.add(l);
            }
          }
        }

        analysisNote =
            '\nImage analysis summary for ${filename.isNotEmpty ? filename : 'attached image'}:';
        analysisNote +=
            '\n- labels: ${formattedLabels.isNotEmpty ? formattedLabels : rawLabels}';
        if (ocr != null && (ocr as String).isNotEmpty) {
          analysisNote += '\n- ocr: $ocr';
        }
        if (unavailable) {
          analysisNote +=
              '\n- note: On-device analysis was unavailable. The user attached an image but automatic labels/ocr could not be extracted.';
        }
        analysisNote += '\n- raw: ${jsonEncode(imageAnalysis)}';

        // If topConfidence is low, we'll ask the model to prefer follow-up questions instead of assuming identity.
        if (topConfidence > 0) {
          analysisNote += '\n- top_label: $topLabel';
          analysisNote +=
              '\n- top_confidence: ${(topConfidence * 100).toStringAsFixed(0)}%';
        }
      } catch (e) {
        analysisNote =
            '\nImage attached but could not include analysis details.';
      }
    }

    // If labels exist with low confidence, add an instruction to prefer clarifying questions
    double parsedTopConf = 0.0;
    try {
      if (imageAnalysis != null &&
          imageAnalysis['labels'] is List &&
          imageAnalysis['labels'].isNotEmpty) {
        final first = imageAnalysis['labels'][0];
        if (first is Map && first['confidence'] is num) {
          parsedTopConf = (first['confidence'] as num).toDouble();
        }
      }
    } catch (_) {}
    final lowConfidenceInstruction =
        (parsedTopConf > 0 && parsedTopConf < 0.75)
            ? '\nNote for assistant: the top visual label has low confidence (${(parsedTopConf * 100).toStringAsFixed(0)}%). Do not assert the object identity; instead, in the "rawText" field briefly acknowledge the uncertainty and ask for a clearer photo or which part to inspect.'
            : '';

    // If analysis was unavailable, instruct the assistant to acknowledge the attachment in rawText
    final analysisUnavailable =
        imageAnalysis != null && (imageAnalysis['analysisUnavailable'] == true);
    final analysisInstruction =
        analysisUnavailable
            ? '\nNote: The user attached an image but automatic on-device analysis was unavailable. In your "rawText" please briefly acknowledge the attachment (filename if provided) and ask any clarifying questions needed to proceed. Still return ONLY the JSON object as specified.'
            : '';

    // Important: Restrict the assistant to repair-related queries only.
    // If the user's question is outside of diagnosing or repairing electronic devices
    // or finding nearby repair shops, the model MUST NOT attempt to answer. Instead
    // it MUST return a JSON object where "rawText" is a short refusal message and
    // "suggestions" is an empty list. Example:
    // { "rawText": "Sorry — I can only help with electronic device repairs and finding repair shops.", "suggestions": [] }
    return '''
    You are an expert electronics repair assistant.
    A user has this problem: "$problem"

  $modeInstruction
  $imageNote
  $analysisNote
  $lowConfidenceInstruction
  $analysisInstruction

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

For experimental suggestions include a 1-step quick test the user can run to verify the idea safely.
Only output valid JSON and nothing else.

    Here is an example of a perfect response:
    {
      "rawText": "I see your phone screen is cracked. Here's a suggestion.",
      "suggestions": [
        {
          "id": "sugg_123",
          "category": "Phone Screen",
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
      final cleanedText =
          responseText.replaceAll('```json', '').replaceAll('```', '').trim();

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
        rawText:
            "Sorry, I had trouble formatting my response. Please try again.",
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
      final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1/models?key=$key',
      );
      final res = await http.get(uri);
      print('ListModels status: ${res.statusCode}');
      print('ListModels body: ${res.body}');
    } catch (err) {
      print('Failed to list models: $err');
    }
  }
}
