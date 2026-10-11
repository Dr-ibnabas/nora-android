import 'profile.dart';

enum Capability { camera, microphone, location, phoneCall, sms, notifications }

/// Coût de calcul d'un module une fois démarré.
enum ComputeCost {
  /// Peut tourner en permanence (mot d'éveil, rappels).
  light,

  /// Inférence continue (vision, transcription) : un seul à la fois.
  heavy,
}

/// Un module métier de NORA, démontrable seul via sa mini-app `example/`.
abstract interface class NoraModule {
  /// Identifiant stable, aussi préfixe de ses clés de messages (`vision`…).
  String get id;
  Set<DisabilityProfile> get profiles;
  Set<Capability> get requiredCapabilities;
  ComputeCost get computeCost;
  Future<void> start();
  Future<void> stop();
}

/// Démarre et arrête les modules en garantissant qu'un seul module lourd
/// tourne à la fois : sur un téléphone milieu de gamme, détection d'objets et
/// transcription continue simultanées saturent le processeur et la batterie.
final class ModuleHost {
  final _active = <NoraModule>{};

  Set<NoraModule> get active => Set.unmodifiable(_active);

  Future<void> activate(NoraModule module) async {
    if (_active.contains(module)) return;
    if (module.computeCost == ComputeCost.heavy) {
      final running =
          _active.where((m) => m.computeCost == ComputeCost.heavy).toList();
      for (final other in running) {
        await deactivate(other);
      }
    }
    await module.start();
    _active.add(module);
  }

  Future<void> deactivate(NoraModule module) async {
    if (!_active.remove(module)) return;
    await module.stop();
  }
}
