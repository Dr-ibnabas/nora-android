import 'dart:typed_data';

/// Bloc audio mono, échantillons normalisés dans [-1, 1].
///
/// Tous les moteurs audio de NORA consomment ce format, à 16 kHz par défaut.
final class AudioChunk {
  const AudioChunk({
    required this.samples,
    required this.timestamp,
    this.sampleRate = 16000,
  });

  final Float32List samples;
  final int sampleRate;

  /// Début du bloc, compté depuis le lancement de la capture.
  final Duration timestamp;

  Duration get duration =>
      Duration(microseconds: samples.length * 1000000 ~/ sampleRate);
}

enum FrameFormat { yuv420, nv21, bgra8888 }

/// Un plan d'image tel que fourni par la caméra, sans copie.
final class FramePlane {
  const FramePlane(this.bytes, {required this.bytesPerRow, this.bytesPerPixel});

  final Uint8List bytes;
  final int bytesPerRow;
  final int? bytesPerPixel;
}

/// Image caméra brute. La conversion vers l'entrée du modèle se fait dans le
/// moteur, hors du fil d'interface.
final class CameraFrame {
  const CameraFrame({
    required this.width,
    required this.height,
    required this.format,
    required this.planes,
    required this.rotationDegrees,
    required this.timestamp,
  });

  final int width;
  final int height;
  final FrameFormat format;
  final List<FramePlane> planes;

  /// Rotation à appliquer pour redresser l'image (0, 90, 180 ou 270).
  final int rotationDegrees;
  final Duration timestamp;
}

final class GeoPosition {
  const GeoPosition({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.time,
  });

  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final DateTime time;
}

/// Micro. Le flux est *broadcast* : plusieurs modules peuvent écouter en même
/// temps (ex. mot d'éveil « NORA » + transcription).
abstract interface class MicrophoneSource {
  Stream<AudioChunk> get chunks;
  Future<void> start();
  Future<void> stop();
}

/// Caméra. Le flux est *broadcast* et ne garde pas d'images en retard : un
/// consommateur lent reçoit toujours la plus récente.
abstract interface class CameraSource {
  Stream<CameraFrame> get frames;
  Future<void> start();
  Future<void> stop();
}

abstract interface class LocationSource {
  /// Position actuelle, ou `null` si le GPS n'a pas encore de point fiable.
  Future<GeoPosition?> current();
  Stream<GeoPosition> get positions;
}
