import '../engines.dart';
import '../language.dart';
import 'message.dart';

/// Textes et enregistrements des messages, par langue. Chaque module fournit
/// le sien (assets/messages, assets/voice) ; l'application les fusionne.
abstract interface class MessageCatalog {
  /// Texte du message dans [language], ou `null` s'il n'est pas traduit.
  String? text(CatalogMessage message, NoraLanguage language);

  /// Clips pré-enregistrés à enchaîner (ex. `['aa/obstacle_person_near']`),
  /// ou `null` si le message n'a pas été enregistré dans [language].
  List<String>? clips(CatalogMessage message, NoraLanguage language);
}

abstract interface class ClipPlayer {
  /// Se termine quand le dernier clip a été joué.
  Future<void> play(List<String> clips);
  Future<void> stop();
}

sealed class VoicePlan {
  const VoicePlan(this.language);

  final NoraLanguage language;
}

final class SynthesisPlan extends VoicePlan {
  const SynthesisPlan(this.text, super.language);

  final String text;
}

final class ClipsPlan extends VoicePlan {
  const ClipsPlan(this.clips, super.language);

  final List<String> clips;
}

/// Choisit comment prononcer un message, langue par langue dans l'ordre de
/// préférence de l'utilisateur :
/// 1. clips enregistrés par des locuteurs natifs (meilleure intelligibilité
///    pour les messages fixes, seule option fiable en somali et en afar) ;
/// 2. synthèse vocale, si le moteur couvre la langue ;
/// 3. sinon, langue suivante.
final class VoiceRenderer {
  VoiceRenderer({
    required this.catalog,
    required this.synthesizer,
    required this.clipPlayer,
  });

  final MessageCatalog catalog;
  final SpeechSynthesizer synthesizer;
  final ClipPlayer clipPlayer;

  /// Renvoie `null` si aucune voix n'est disponible : le texte affiché prend
  /// alors le relais.
  VoicePlan? plan(NoraMessage message, List<NoraLanguage> languages) {
    return switch (message) {
      LiteralMessage(:final text, :final language) =>
        synthesizer.supports(language) ? SynthesisPlan(text, language) : null,
      CatalogMessage catalogMessage => _planCatalog(catalogMessage, languages),
    };
  }

  /// Prononce [message] ; renvoie `false` si aucune voix n'est disponible.
  Future<bool> speak(NoraMessage message, List<NoraLanguage> languages) async {
    final voicePlan = plan(message, languages);
    if (voicePlan == null) return false;
    switch (voicePlan) {
      case ClipsPlan(:final clips):
        await clipPlayer.play(clips);
      case SynthesisPlan(:final text, :final language):
        await synthesizer.speak(text, language: language);
    }
    return true;
  }

  Future<void> stop() async {
    await Future.wait([synthesizer.stop(), clipPlayer.stop()]);
  }

  VoicePlan? _planCatalog(
    CatalogMessage message,
    List<NoraLanguage> languages,
  ) {
    for (final language in languages) {
      final clips = catalog.clips(message, language);
      if (clips != null && clips.isNotEmpty) return ClipsPlan(clips, language);
      final text = catalog.text(message, language);
      if (text != null && synthesizer.supports(language)) {
        return SynthesisPlan(text, language);
      }
    }
    return null;
  }
}
