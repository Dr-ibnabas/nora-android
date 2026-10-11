import 'package:nora_core/nora_core.dart';
import 'package:test/test.dart';

/// Synthèse factice : ne couvre que le français et l'arabe.
final class FakeSynthesizer implements SpeechSynthesizer {
  final spoken = <(String, NoraLanguage)>[];

  @override
  bool supports(NoraLanguage language) =>
      language == NoraLanguage.french || language == NoraLanguage.arabic;

  @override
  Future<void> speak(String text, {required NoraLanguage language}) async {
    spoken.add((text, language));
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}

final class FakeClipPlayer implements ClipPlayer {
  final played = <List<String>>[];

  @override
  Future<void> play(List<String> clips) async {
    played.add(clips);
  }

  @override
  Future<void> stop() async {}
}

final class MapCatalog implements MessageCatalog {
  MapCatalog({this.texts = const {}, this.recordings = const {}});

  final Map<(String, NoraLanguage), String> texts;
  final Map<(String, NoraLanguage), List<String>> recordings;

  @override
  String? text(CatalogMessage message, NoraLanguage language) =>
      texts[(message.key, language)];

  @override
  List<String>? clips(CatalogMessage message, NoraLanguage language) =>
      recordings[(message.key, language)];
}

void main() {
  const obstacle =
      CatalogMessage('vision.obstacle', {'object': 'person', 'distance': 'near'});
  const frenchText = 'Attention, personne devant, proche';
  const afarFirst = [NoraLanguage.afar, NoraLanguage.french];

  late FakeSynthesizer tts;
  late FakeClipPlayer clipPlayer;

  setUp(() {
    tts = FakeSynthesizer();
    clipPlayer = FakeClipPlayer();
  });

  VoiceRenderer renderer(MessageCatalog catalog) => VoiceRenderer(
        catalog: catalog,
        synthesizer: tts,
        clipPlayer: clipPlayer,
      );

  test('français : synthèse vocale', () async {
    final voice = renderer(MapCatalog(
      texts: {('vision.obstacle', NoraLanguage.french): frenchText},
    ));

    expect(await voice.speak(obstacle, [NoraLanguage.french]), isTrue);
    expect(tts.spoken.single, (frenchText, NoraLanguage.french));
  });

  test('afar : clips enregistrés par un locuteur natif', () async {
    final voice = renderer(MapCatalog(
      texts: {('vision.obstacle', NoraLanguage.french): frenchText},
      recordings: {
        ('vision.obstacle', NoraLanguage.afar): ['aa/obstacle_person_near'],
      },
    ));

    expect(await voice.speak(obstacle, afarFirst), isTrue);
    expect(clipPlayer.played.single, ['aa/obstacle_person_near']);
    expect(tts.spoken, isEmpty);
  });

  test('afar traduit mais ni enregistré ni synthétisable : repli français', () {
    final voice = renderer(MapCatalog(texts: {
      ('vision.obstacle', NoraLanguage.afar): '<texte afar>',
      ('vision.obstacle', NoraLanguage.french): frenchText,
    }));

    expect(
      voice.plan(obstacle, afarFirst),
      isA<SynthesisPlan>()
          .having((p) => p.language, 'language', NoraLanguage.french),
    );
  });

  test('texte libre dans une langue non synthétisable : pas de voix', () async {
    final voice = renderer(MapCatalog());
    const sign = LiteralMessage('Magaalada Jabuuti', NoraLanguage.somali);

    expect(await voice.speak(sign, [NoraLanguage.somali]), isFalse);
  });
}
