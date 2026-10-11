import 'language.dart';

/// Les cinq profils servis par NORA. Un utilisateur peut en cumuler plusieurs.
enum DisabilityProfile { visual, hearing, speech, motor, cognitive }

/// Canaux par lesquels NORA restitue une information.
enum OutputChannel { voice, text, haptic, flash }

/// Préférences de l'utilisateur, stockées sur l'appareil.
final class UserProfile {
  const UserProfile({
    required this.profiles,
    required this.language,
    this.fallbackLanguages = const [NoraLanguage.french],
  });

  final Set<DisabilityProfile> profiles;

  /// Langue préférée.
  final NoraLanguage language;

  /// Autres langues comprises par l'utilisateur, utilisées quand aucun
  /// moteur ni enregistrement ne couvre [language] (ex. : afar → français).
  final List<NoraLanguage> fallbackLanguages;

  /// [language] puis les langues de repli, sans doublon.
  List<NoraLanguage> get languageChain =>
      {language, ...fallbackLanguages}.toList(growable: false);

  /// Canaux adaptés au profil : jamais la voix seule pour une personne
  /// malentendante, jamais le texte seul pour une personne malvoyante.
  /// Sourd-aveugle : la vibration seule.
  Set<OutputChannel> get outputChannels {
    final visual = profiles.contains(DisabilityProfile.visual);
    final hearing = profiles.contains(DisabilityProfile.hearing);
    return {
      if (!hearing) OutputChannel.voice,
      if (!visual) OutputChannel.text,
      if (visual || hearing) OutputChannel.haptic,
      if (hearing && !visual) OutputChannel.flash,
    };
  }
}
