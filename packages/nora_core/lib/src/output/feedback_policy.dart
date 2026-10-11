import '../profile.dart';
import 'message.dart';

final class FeedbackDecision {
  const FeedbackDecision({
    required this.feedback,
    required this.channels,
    required this.interrupt,
  });

  final NoraFeedback feedback;
  final Set<OutputChannel> channels;

  /// Couper la parole en cours : réservé aux dangers.
  final bool interrupt;
}

/// Décide si et comment restituer un [NoraFeedback], pour tous les modules :
/// - anti-répétition : un même message n'est pas répété avant son délai
///   (une personne malvoyante ne doit pas entendre « personne devant » dix
///   fois par seconde) ;
/// - canaux : ceux du profil, la vibration et le flash étant réservés aux
///   alertes pour garder leur valeur de signal ;
/// - interruption : seul un danger coupe la parole en cours.
final class FeedbackPolicy {
  FeedbackPolicy({
    required Set<OutputChannel> channels,
    DateTime Function()? clock,
  })  : _channels = channels,
        _now = clock ?? DateTime.now;

  static const defaultCooldowns = {
    FeedbackPriority.info: Duration(seconds: 8),
    FeedbackPriority.warning: Duration(seconds: 4),
    FeedbackPriority.danger: Duration(milliseconds: 1500),
  };

  static const _alertOnlyChannels = {OutputChannel.haptic, OutputChannel.flash};

  final Set<OutputChannel> _channels;
  final DateTime Function() _now;
  final _lastEmitted = <String, DateTime>{};

  /// Renvoie `null` si le message doit être tu.
  FeedbackDecision? evaluate(NoraFeedback feedback) {
    final now = _now();
    final identity = feedback.message.identity;
    final cooldown =
        feedback.cooldown ?? defaultCooldowns[feedback.priority]!;
    final last = _lastEmitted[identity];
    if (last != null && now.difference(last) < cooldown) return null;
    _lastEmitted[identity] = now;

    final isAlert = feedback.priority != FeedbackPriority.info;
    var channels = {
      for (final channel in _channels)
        if (isAlert || !_alertOnlyChannels.contains(channel)) channel,
    };
    // Sourd-aveugle : la vibration est le seul canal, on la garde toujours.
    if (channels.isEmpty) channels = {..._channels};

    return FeedbackDecision(
      feedback: feedback,
      channels: channels,
      interrupt: feedback.priority == FeedbackPriority.danger,
    );
  }
}
