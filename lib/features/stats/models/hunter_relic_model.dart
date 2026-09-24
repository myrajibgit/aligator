import 'package:flutter/material.dart';

enum RelicSlot { weapon, amulet, ring, armor }

enum RelicRarity { common, rare, epic, legendary, mythic }

enum RelicBuffType {
  xpBoost,
  fatigueReduction,
  gateDamage,
  streakShield,
  battleIq,
  allStats,
}

class HunterRelic {
  final String id;
  final String name;
  final RelicSlot slot;
  final RelicRarity rarity;
  final String iconEmoji;
  final String statBuff;
  final RelicBuffType buffType;
  final double buffMultiplier;
  final String description;
  final String lore;
  final String source;
  final bool isEquipped;

  const HunterRelic({
    required this.id,
    required this.name,
    required this.slot,
    required this.rarity,
    required this.iconEmoji,
    required this.statBuff,
    required this.buffType,
    required this.buffMultiplier,
    required this.description,
    required this.lore,
    required this.source,
    this.isEquipped = false,
  });

  Color get rarityColor {
    switch (rarity) {
      case RelicRarity.common:
        return const Color(0xFF94A3B8); // Slate silver
      case RelicRarity.rare:
        return const Color(0xFF38BDF8); // Cyan blue
      case RelicRarity.epic:
        return const Color(0xFFA855F7); // Void purple
      case RelicRarity.legendary:
        return const Color(0xFFFFD700); // Sovereign gold
      case RelicRarity.mythic:
        return const Color(0xFFEF4444); // Monarch crimson
    }
  }

  String get slotDisplayName {
    switch (slot) {
      case RelicSlot.weapon:
        return 'WEAPON';
      case RelicSlot.amulet:
        return 'AMULET';
      case RelicSlot.ring:
        return 'RING';
      case RelicSlot.armor:
        return 'ARMOR';
    }
  }

  String get rarityDisplayName {
    switch (rarity) {
      case RelicRarity.common:
        return 'COMMON';
      case RelicRarity.rare:
        return 'RARE';
      case RelicRarity.epic:
        return 'EPIC';
      case RelicRarity.legendary:
        return 'LEGENDARY';
      case RelicRarity.mythic:
        return 'MYTHIC';
    }
  }

  HunterRelic copyWith({bool? isEquipped}) {
    return HunterRelic(
      id: id,
      name: name,
      slot: slot,
      rarity: rarity,
      iconEmoji: iconEmoji,
      statBuff: statBuff,
      buffType: buffType,
      buffMultiplier: buffMultiplier,
      description: description,
      lore: lore,
      source: source,
      isEquipped: isEquipped ?? this.isEquipped,
    );
  }

  factory HunterRelic.fromMap(String id, Map<String, dynamic> map, {bool isEquipped = false}) {
    final catalogMatch = RelicCatalog.find(id);
    if (catalogMatch != null) {
      return catalogMatch.copyWith(isEquipped: isEquipped);
    }
    return HunterRelic(
      id: id,
      name: map['name'] as String? ?? 'Mysterious Relic',
      slot: RelicSlot.values.firstWhere(
        (s) => s.name == map['slot'],
        orElse: () => RelicSlot.amulet,
      ),
      rarity: RelicRarity.values.firstWhere(
        (r) => r.name == map['rarity'],
        orElse: () => RelicRarity.rare,
      ),
      iconEmoji: map['iconEmoji'] as String? ?? '🔮',
      statBuff: map['statBuff'] as String? ?? '+5% All Stats',
      buffType: RelicBuffType.values.firstWhere(
        (b) => b.name == map['buffType'],
        orElse: () => RelicBuffType.xpBoost,
      ),
      buffMultiplier: (map['buffMultiplier'] as num?)?.toDouble() ?? 0.05,
      description: map['description'] as String? ?? 'An ancient artifact humming with mana.',
      lore: map['lore'] as String? ?? '"Power speaks to those who conquer."',
      source: map['source'] as String? ?? 'Dungeon Gate',
      isEquipped: isEquipped,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'slot': slot.name,
        'rarity': rarity.name,
        'iconEmoji': iconEmoji,
        'statBuff': statBuff,
        'buffType': buffType.name,
        'buffMultiplier': buffMultiplier,
        'description': description,
        'lore': lore,
        'source': source,
        'isEquipped': isEquipped,
      };
}

class RelicCatalog {
  static const List<HunterRelic> allRelics = [
    HunterRelic(
      id: 'kasaka_fang',
      name: "Kasaka's Venom Dagger",
      slot: RelicSlot.weapon,
      rarity: RelicRarity.rare,
      iconEmoji: '🗡️',
      statBuff: '-15% Study Fatigue Rate',
      buffType: RelicBuffType.fatigueReduction,
      buffMultiplier: 0.15,
      description: 'Slows mental exhaustion accumulation by 15% during deep focus study timers.',
      lore: '"A dagger fashioned from the venom-infused canine tooth of the Blue Poison-Fang Kasaka."',
      source: 'C-Rank Swamp Gate Boss Drop',
    ),
    HunterRelic(
      id: 'golem_core',
      name: 'Golem Core of Precision',
      slot: RelicSlot.amulet,
      rarity: RelicRarity.rare,
      iconEmoji: '🗿',
      statBuff: '+10% INT & Streak Shield',
      buffType: RelicBuffType.streakShield,
      buffMultiplier: 0.10,
      description: 'Stabilizes cognitive reasoning and grants 1 grace day to protect streak multipliers.',
      lore: '"The pulsating geometric core extracted from the Calculus Golem. Calibrates mental logic."',
      source: 'C-Rank Math Labyrinth Gate Drop',
    ),
    HunterRelic(
      id: 'knight_killer',
      name: 'Knight Killer',
      slot: RelicSlot.weapon,
      rarity: RelicRarity.rare,
      iconEmoji: '⚔️',
      statBuff: '+20% Boss Raid Damage',
      buffType: RelicBuffType.gateDamage,
      buffMultiplier: 0.20,
      description: 'Boosts raid strike impact against STEM Dungeon Gate bosses by +20%.',
      lore: '"A serrated combat blade engineered to pierce heavily armored academic challenges."',
      source: 'Hunter Guild Supply Crate',
    ),
    HunterRelic(
      id: 'rulers_crest',
      name: "Ruler's Vector Crest",
      slot: RelicSlot.ring,
      rarity: RelicRarity.epic,
      iconEmoji: '⚡',
      statBuff: '+20% Battle IQ & +10% XP',
      buffType: RelicBuffType.battleIq,
      buffMultiplier: 0.20,
      description: 'Sharpens combat instincts in 1v1 Stat Battles and elevates baseline XP acquisition.',
      lore: '"Infused with the unseen celestial magnetic vectors of the ancient Rulers."',
      source: 'B-Rank Red Gate: Magnetic Vortex Drop',
    ),
    HunterRelic(
      id: 'eternal_helix',
      name: 'Eternal Helix Artifact',
      slot: RelicSlot.armor,
      rarity: RelicRarity.epic,
      iconEmoji: '🧬',
      statBuff: 'Purges 25% Fatigue on Quest',
      buffType: RelicBuffType.fatigueReduction,
      buffMultiplier: 0.25,
      description: 'Instantly purges 25% accumulated mental fatigue each time a daily mission is verified.',
      lore: '"A self-repairing biomorphic relic recovered from the core of the Organic Chimera."',
      source: 'A-Rank Gate: Cell Mutation Boss Drop',
    ),
    HunterRelic(
      id: 'orb_of_avarice',
      name: 'Orb of Avarice',
      slot: RelicSlot.amulet,
      rarity: RelicRarity.legendary,
      iconEmoji: '🔮',
      statBuff: '+30% Focus Session XP',
      buffType: RelicBuffType.xpBoost,
      buffMultiplier: 0.30,
      description: 'Amplifies XP output by +30% during timed Pomodoro focus sessions.',
      lore: '"A hypnotic crimson jewel forged in the Demon Realm that doubles magical concentration."',
      source: 'Guild High-Tier Raid Drop',
    ),
    HunterRelic(
      id: 'demon_monarch_dagger',
      name: "Demon King's Dagger",
      slot: RelicSlot.weapon,
      rarity: RelicRarity.mythic,
      iconEmoji: '👑',
      statBuff: '+25% All Stats & Monarch Flame',
      buffType: RelicBuffType.allStats,
      buffMultiplier: 0.25,
      description: 'Empowers INT, VIT, STR, AGI, and SEN with the thunderous lightning of the Monarchs.',
      lore: '"Forged from the thunder and storm clouds of Baran, Monarch of White Flames."',
      source: 'Solo-Leveling Apex Achievement',
    ),
  ];

  static HunterRelic? find(String id) {
    try {
      return allRelics.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }
}
