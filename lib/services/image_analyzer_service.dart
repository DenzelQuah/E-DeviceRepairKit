import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class ImageAnalyzerService {
  /// Analyze image at [path]. Returns a map with keys:
  // ignore: unintended_html_in_doc_comment
  /// - 'labels': List<Map<String, dynamic>> [{ 'label': String, 'confidence': double }] (Top 3)
  /// - 'ocr': String
  Future<Map<String, dynamic>> analyzeImage(String path) async {
    final inputImage = InputImage.fromFilePath(path);

    // --- Image Labeling (ML Kit) ---
    // Keep threshold at 0.0 to get all results initially
    final labeler = ImageLabeler(
      options: ImageLabelerOptions(confidenceThreshold: 0.0),
    );
    List<ImageLabel> allLabels = [];
    try {
      allLabels = await labeler.processImage(inputImage);
    } catch (e) {
      // ignore errors
    } finally {
      await labeler.close();
    }

    // --- Sort and Take Top 3 ---
    // 1. Sort the list by confidence in descending order (highest first)
    allLabels.sort((a, b) => b.confidence.compareTo(a.confidence));

    // 2. Take the first 3 elements (or fewer if less than 3 labels were found)
    final topLabels = allLabels.take(3).toList();

    // 3. Map the top labels to the desired format
    final labelsFound = topLabels
        .map((l) => {'label': l.label, 'confidence': l.confidence})
        .toList();
    // --- End Sorting Logic ---

    // --- OCR / Text recognition (Remains the same) ---
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    String extractedText = '';
    try {
      final result = await textRecognizer.processImage(inputImage);
      extractedText = result.text;
    } catch (e) {
      // ignore
    } finally {
      await textRecognizer.close();
    }

    return {'labels': labelsFound, 'ocr': extractedText};
  }
}
