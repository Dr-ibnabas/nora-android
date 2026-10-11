import 'capture.dart';
import 'language.dart';

// Contrats des moteurs d'IA embarqués. Les implémentations (TFLite,
// ONNX Runtime…) vivent dans packages/engines/ : les modules n'en dépendent
// jamais directement.

/// Boîte englobante normalisée (0..1) dans l'image redressée.
final class BoundingBox {
  const BoundingBox(this.left, this.top, this.right, this.bottom);

  final double left;
  final double top;
  final double right;
  final double bottom;

  double get width => right - left;
  double get height => bottom - top;
  double get centerX => (left + right) / 2;
  double get area => width * height;
}

final class Detection {
  const Detection({
    required this.label,
    required this.confidence,
    required this.box,
  });

  /// Classe stable (`person`, `car`, `open_drain`…), jamais un texte affiché :
  /// la traduction passe par le catalogue de messages.
  final String label;
  final double confidence;
  final BoundingBox box;
}

abstract interface class ObjectDetector {
  /// Classes reconnues par le modèle chargé.
  Set<String> get labels;
  Future<List<Detection>> detect(CameraFrame frame);
  Future<void> dispose();
}

final class RecognizedText {
  const RecognizedText({required this.text, required this.box});

  final String text;
  final BoundingBox box;
}

abstract interface class TextRecognizer {
  bool supports(NoraLanguage language);
  Future<List<RecognizedText>> recognize(CameraFrame frame);
  Future<void> dispose();
}

final class Transcript {
  const Transcript({
    required this.text,
    required this.isFinal,
    required this.language,
    this.confidence,
  });

  final String text;

  /// `false` pour un résultat partiel, affiché en direct puis remplacé.
  final bool isFinal;
  final NoraLanguage language;
  final double? confidence;
}

abstract interface class SpeechRecognizer {
  bool supports(NoraLanguage language);
  Stream<Transcript> transcribe(
    Stream<AudioChunk> audio, {
    required NoraLanguage language,
  });
  Future<void> dispose();
}

final class SoundEvent {
  const SoundEvent({
    required this.label,
    required this.confidence,
    required this.timestamp,
  });

  /// Classe de son (`car_horn`, `siren`, `doorbell`, `baby_cry`, `speech`…).
  final String label;
  final double confidence;
  final Duration timestamp;
}

abstract interface class SoundClassifier {
  Stream<SoundEvent> classify(Stream<AudioChunk> audio);
  Future<void> dispose();
}

abstract interface class SpeechSynthesizer {
  bool supports(NoraLanguage language);

  /// Se termine quand la phrase a été entièrement prononcée.
  Future<void> speak(String text, {required NoraLanguage language});
  Future<void> stop();
  Future<void> dispose();
}
