import 'package:flutter/services.dart';

class HapticFeedbackUtils {
  /// Subtle click for selection changes and light interactions
  static void lightClick() {
    HapticFeedback.selectionClick();
  }

  static void selectionClick() {
    HapticFeedback.selectionClick();
  }

  static void selection() {
    HapticFeedback.selectionClick();
  }

  static void mediumImpact() {
    HapticFeedback.mediumImpact();
  }

  static void heavyImpact() {
    HapticFeedback.heavyImpact();
  }

  static void success() {
    HapticFeedback.mediumImpact();
  }

  /// Medium pulse when counting physical reps or incrementing targets
  static void repCount() {
    HapticFeedback.mediumImpact();
  }

  /// Heavy punch when completing a quest, level up, or duel round victory
  static void questComplete() {
    HapticFeedback.heavyImpact();
  }

  /// Double pulse for rank ascension or boss defeat
  static void levelUp() {
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 150), () {
      HapticFeedback.heavyImpact();
    });
  }

  /// Vibration pattern for high fatigue warnings or penalty alerts
  static void alertWarning() {
    HapticFeedback.vibrate();
  }

  /// Tactile clash for head-to-head stat battles
  static void duelClash() {
    HapticFeedback.mediumImpact();
  }
}
