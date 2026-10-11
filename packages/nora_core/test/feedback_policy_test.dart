import 'package:nora_core/nora_core.dart';
import 'package:test/test.dart';

void main() {
  late DateTime now;

  FeedbackPolicy policyFor(Set<DisabilityProfile> profiles) => FeedbackPolicy(
        channels: UserProfile(profiles: profiles, language: NoraLanguage.french)
            .outputChannels,
        clock: () => now,
      );

  const personNear = NoraFeedback(
    CatalogMessage('vision.obstacle', {'object': 'person', 'distance': 'near'}),
    priority: FeedbackPriority.danger,
  );
  const pathClear = NoraFeedback(CatalogMessage('vision.path_clear'));

  setUp(() => now = DateTime(2026, 10, 5, 9));

  test("un même danger n'est pas répété avant son délai", () {
    final policy = policyFor({DisabilityProfile.visual});
    expect(policy.evaluate(personNear), isNotNull);

    now = now.add(const Duration(milliseconds: 500));
    expect(policy.evaluate(personNear), isNull);

    now = now.add(const Duration(seconds: 2));
    expect(policy.evaluate(personNear), isNotNull);
  });

  test('un paramètre différent est un nouveau message', () {
    final policy = policyFor({DisabilityProfile.visual});
    policy.evaluate(personNear);

    const carNear = NoraFeedback(
      CatalogMessage('vision.obstacle', {'object': 'car', 'distance': 'near'}),
      priority: FeedbackPriority.danger,
    );
    expect(policy.evaluate(carNear), isNotNull);
  });

  test('malvoyant : voix + vibration pour un danger, voix seule sinon', () {
    final policy = policyFor({DisabilityProfile.visual});

    final danger = policy.evaluate(personNear)!;
    expect(danger.channels,
        unorderedEquals([OutputChannel.voice, OutputChannel.haptic]));
    expect(danger.interrupt, isTrue);

    expect(policy.evaluate(pathClear)!.channels, unorderedEquals([OutputChannel.voice]));
  });

  test('malentendant : jamais de voix', () {
    final policy = policyFor({DisabilityProfile.hearing});
    const horn = NoraFeedback(
      CatalogMessage('hearing.sound', {'sound': 'car_horn'}),
      priority: FeedbackPriority.warning,
    );

    final decision = policy.evaluate(horn)!;
    expect(
      decision.channels,
      unorderedEquals(
          [OutputChannel.text, OutputChannel.haptic, OutputChannel.flash]),
    );
    expect(decision.interrupt, isFalse);
  });

  test('sourd-aveugle : la vibration est gardée même pour une info', () {
    final policy =
        policyFor({DisabilityProfile.visual, DisabilityProfile.hearing});
    expect(policy.evaluate(pathClear)!.channels, unorderedEquals([OutputChannel.haptic]));
  });
}
