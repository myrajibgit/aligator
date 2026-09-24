import 'package:flutter_test/flutter_test.dart';

// Standalone test replica of Infinite Trial combo and scoring logic
double calculateComboMultiplier(int combo) {
  if (combo >= 20) return 4.0;
  if (combo >= 15) return 3.0;
  if (combo >= 10) return 2.5;
  if (combo >= 7)  return 2.0;
  if (combo >= 5)  return 1.5;
  if (combo >= 3)  return 1.25;
  return 1.0;
}

String getComboLabel(int combo) {
  if (combo >= 20) return 'MONARCH SLAUGHTER';
  if (combo >= 15) return 'S-CLASS DOMINANCE';
  if (combo >= 10) return 'UNSTOPPABLE';
  if (combo >= 7)  return 'CRITICAL COMBO';
  if (combo >= 5)  return 'COMBO RISING';
  if (combo >= 3)  return 'ON FIRE';
  return 'STRIKE';
}

int calculateXpGain(int baseScore, int combo) {
  return (baseScore * calculateComboMultiplier(combo)).round();
}

void main() {
  group('Infinite Trial Combo Multiplier Engine', () {
    test('returns 1.0x baseline for combos under 3', () {
      expect(calculateComboMultiplier(0), equals(1.0));
      expect(calculateComboMultiplier(1), equals(1.0));
      expect(calculateComboMultiplier(2), equals(1.0));
    });

    test('scales through all progressive combo tiers correctly', () {
      expect(calculateComboMultiplier(3), equals(1.25));
      expect(calculateComboMultiplier(4), equals(1.25));
      expect(calculateComboMultiplier(5), equals(1.5));
      expect(calculateComboMultiplier(6), equals(1.5));
      expect(calculateComboMultiplier(7), equals(2.0));
      expect(calculateComboMultiplier(9), equals(2.0));
      expect(calculateComboMultiplier(10), equals(2.5));
      expect(calculateComboMultiplier(14), equals(2.5));
      expect(calculateComboMultiplier(15), equals(3.0));
      expect(calculateComboMultiplier(19), equals(3.0));
      expect(calculateComboMultiplier(20), equals(4.0));
      expect(calculateComboMultiplier(50), equals(4.0));
    });

    test('assigns proper Solo-Leveling combo battle ranks', () {
      expect(getComboLabel(0), equals('STRIKE'));
      expect(getComboLabel(2), equals('STRIKE'));
      expect(getComboLabel(3), equals('ON FIRE'));
      expect(getComboLabel(5), equals('COMBO RISING'));
      expect(getComboLabel(7), equals('CRITICAL COMBO'));
      expect(getComboLabel(10), equals('UNSTOPPABLE'));
      expect(getComboLabel(15), equals('S-CLASS DOMINANCE'));
      expect(getComboLabel(25), equals('MONARCH SLAUGHTER'));
    });

    test('calculates correct scaled XP disbursements', () {
      const base = 15;
      expect(calculateXpGain(base, 0), equals(15));
      expect(calculateXpGain(base, 3), equals(19)); // 15 * 1.25 = 18.75 -> 19
      expect(calculateXpGain(base, 5), equals(23)); // 15 * 1.5 = 22.5 -> 23 (round half to even or ceil)
      expect(calculateXpGain(base, 7), equals(30)); // 15 * 2.0 = 30
      expect(calculateXpGain(base, 10), equals(38)); // 15 * 2.5 = 37.5 -> 38
      expect(calculateXpGain(base, 15), equals(45)); // 15 * 3.0 = 45
      expect(calculateXpGain(base, 20), equals(60)); // 15 * 4.0 = 60
    });
  });
}
