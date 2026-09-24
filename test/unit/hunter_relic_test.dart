import 'package:flutter_test/flutter_test.dart';
import 'package:studycompete/features/stats/models/hunter_relic_model.dart';
import 'package:studycompete/features/stats/services/hunter_relic_service.dart';

void main() {
  group('HunterRelic Catalog & Mechanics', () {
    test('contains all canonical Solo-Leveling relics', () {
      final relics = RelicCatalog.allRelics;
      expect(relics.length, greaterThanOrEqualTo(7));

      final ids = relics.map((r) => r.id).toList();
      expect(ids, containsAll([
        'kasaka_fang',
        'golem_core',
        'knight_killer',
        'rulers_crest',
        'eternal_helix',
        'orb_of_avarice',
        'demon_monarch_dagger',
      ]));
    });

    test('relic slot and rarity attributes resolve correctly', () {
      final kasaka = RelicCatalog.find('kasaka_fang')!;
      expect(kasaka.slot, equals(RelicSlot.weapon));
      expect(kasaka.slotDisplayName, equals('WEAPON'));
      expect(kasaka.rarity, equals(RelicRarity.rare));
      expect(kasaka.rarityDisplayName, equals('RARE'));
      expect(kasaka.iconEmoji, equals('🗡️'));

      final crest = RelicCatalog.find('rulers_crest')!;
      expect(crest.slot, equals(RelicSlot.ring));
      expect(crest.slotDisplayName, equals('RING'));
      expect(crest.rarity, equals(RelicRarity.epic));
    });

    test('copyWith properly reflects equipped status', () {
      final base = RelicCatalog.find('golem_core')!;
      expect(base.isEquipped, isFalse);

      final equipped = base.copyWith(isEquipped: true);
      expect(equipped.isEquipped, isTrue);
      expect(equipped.name, equals(base.name));
      expect(equipped.buffType, equals(RelicBuffType.streakShield));
    });

    test('active hunter buffs aggregate properly', () {
      const buffs = ActiveHunterBuffs(
        xpMultiplierBoost: 0.30,
        fatigueReduction: 0.15,
        gateDamageMultiplier: 1.20,
        battleIqBonus: 0.20,
        hasStreakShield: true,
      );

      expect(buffs.xpMultiplierBoost, equals(0.30));
      expect(buffs.fatigueReduction, equals(0.15));
      expect(buffs.gateDamageMultiplier, equals(1.20));
      expect(buffs.hasStreakShield, isTrue);
    });

    test('fromMap resolves known relics from catalog', () {
      final relic = HunterRelic.fromMap('orb_of_avarice', {}, isEquipped: true);
      expect(relic.id, equals('orb_of_avarice'));
      expect(relic.name, equals('Orb of Avarice'));
      expect(relic.rarity, equals(RelicRarity.legendary));
      expect(relic.isEquipped, isTrue);
    });
  });
}
