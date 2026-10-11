import 'package:nora_core/nora_core.dart';
import 'package:test/test.dart';

final class FakeModule implements NoraModule {
  FakeModule(this.id, this.computeCost);

  @override
  final String id;

  @override
  final ComputeCost computeCost;

  @override
  Set<DisabilityProfile> get profiles => const {};

  @override
  Set<Capability> get requiredCapabilities => const {};

  bool running = false;

  @override
  Future<void> start() async {
    running = true;
  }

  @override
  Future<void> stop() async {
    running = false;
  }
}

void main() {
  test('un seul module lourd à la fois, les légers restent actifs', () async {
    final host = ModuleHost();
    final wakeWord = FakeModule('voice_control', ComputeCost.light);
    final vision = FakeModule('vision', ComputeCost.heavy);
    final hearing = FakeModule('hearing', ComputeCost.heavy);

    await host.activate(wakeWord);
    await host.activate(vision);
    await host.activate(hearing);

    expect(vision.running, isFalse);
    expect(hearing.running, isTrue);
    expect(wakeWord.running, isTrue);
    expect(host.active, unorderedEquals([wakeWord, hearing]));
  });

  test('désactiver un module inactif ne fait rien', () async {
    final host = ModuleHost();
    final vision = FakeModule('vision', ComputeCost.heavy);

    await host.deactivate(vision);
    expect(host.active, isEmpty);
  });
}
