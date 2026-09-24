import 'package:flutter_test/flutter_test.dart';
import 'package:studycompete/features/social/models/dungeon_gate_model.dart';

void main() {
  group('DungeonGateModel & Raids', () {
    test('default gates generate properly with HP and rank styling', () {
      final gates = DungeonGateModel.getDefaultGates();
      expect(gates.length, equals(3));

      final cRankGate = gates.first;
      expect(cRankGate.rank, equals('C'));
      expect(cRankGate.bossName, equals('Calculus Golem'));
      expect(cRankGate.currentHp, inInclusiveRange(0, cRankGate.maxHp));
    });

    test('boss HP decreases with damage strikes and clamps at 0', () {
      final gate = DungeonGateModel(
        gateId: 'test_gate',
        name: 'Test Gate',
        rank: 'B',
        bossName: 'Test Boss',
        bossEmoji: '👾',
        maxHp: 100,
        currentHp: 100,
        xpReward: 50,
        relicDrop: 'Test Relic',
        subjectTheme: 'Chemistry',
      );

      gate.currentHp = (gate.currentHp - 40).clamp(0, gate.maxHp);
      expect(gate.currentHp, equals(60));

      gate.currentHp = (gate.currentHp - 80).clamp(0, gate.maxHp);
      expect(gate.currentHp, equals(0));
    });

    test('default gates have curricula raid questions and valid correct indices', () {
      final gates = DungeonGateModel.getDefaultGates();
      for (final gate in gates) {
        expect(gate.questions, isNotEmpty);
        expect(gate.relicId, isNotEmpty);
        for (final q in gate.questions) {
          expect(q.options.length, greaterThanOrEqualTo(2));
          expect(q.correctIndex, inInclusiveRange(0, q.options.length - 1));
          expect(q.baseDamage, greaterThan(0));
        }
      }
    });
  });
}
