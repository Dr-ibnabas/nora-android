/// Les quatre langues cibles de NORA.
///
/// Le support réel varie selon les moteurs installés sur l'appareil :
/// chaque moteur l'expose via sa méthode `supports`.
enum NoraLanguage {
  french('fr', 'Français'),
  arabic('ar', 'العربية', isRtl: true),
  somali('so', 'Af-Soomaali'),
  afar('aa', 'Qafar af');

  const NoraLanguage(this.code, this.nativeName, {this.isRtl = false});

  /// Code ISO 639-1.
  final String code;

  /// Nom de la langue dans la langue elle-même (affiché à l'utilisateur).
  final String nativeName;

  /// Écriture de droite à gauche.
  final bool isRtl;

  static NoraLanguage? fromCode(String code) {
    for (final language in values) {
      if (language.code == code) return language;
    }
    return null;
  }
}
