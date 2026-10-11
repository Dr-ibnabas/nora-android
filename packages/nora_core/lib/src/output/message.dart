import '../language.dart';

/// Ce que NORA veut dire à l'utilisateur, avant tout choix de langue ou de
/// canal.
sealed class NoraMessage {
  const NoraMessage();

  /// Identité utilisée pour ne pas répéter le même message.
  String get identity;
}

/// Message prévu à l'avance, résolu par un `MessageCatalog`.
///
/// Les paramètres sont des valeurs énumérées (`person`, `near`), jamais du
/// texte libre : chaque combinaison peut être traduite, et enregistrée par
/// des locuteurs natifs pour les langues sans synthèse vocale fiable.
final class CatalogMessage extends NoraMessage {
  const CatalogMessage(this.key, [this.params = const {}]);

  /// Clé stable, préfixée par l'identifiant du module (`vision.obstacle`).
  final String key;
  final Map<String, String> params;

  @override
  String get identity {
    final names = params.keys.toList()..sort();
    return [key, for (final name in names) '$name=${params[name]}'].join('|');
  }

  @override
  String toString() => identity;
}

/// Texte libre déjà rédigé dans une langue (texte lu par l'OCR, phrase
/// transcrite). Il ne peut être que synthétisé, pas pré-enregistré.
final class LiteralMessage extends NoraMessage {
  const LiteralMessage(this.text, this.language);

  final String text;
  final NoraLanguage language;

  @override
  String get identity => 'literal|${language.code}|$text';

  @override
  String toString() => identity;
}

enum FeedbackPriority { info, warning, danger }

/// Une demande de restitution émise par un module.
final class NoraFeedback {
  const NoraFeedback(
    this.message, {
    this.priority = FeedbackPriority.info,
    this.cooldown,
  });

  final NoraMessage message;
  final FeedbackPriority priority;

  /// Délai minimal avant de répéter ce message ; par défaut, celui de sa
  /// priorité (voir `FeedbackPolicy.defaultCooldowns`).
  final Duration? cooldown;
}
