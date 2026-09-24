import 'package:flutter/material.dart';

class ShadowSoldier {
  final String id;
  final String name;
  final String title;
  final int unlockLevel;
  final String buffDescription;
  final String buffStat;
  final double buffMultiplier;
  final String emoji;
  final String quote;
  final Color shadowColor;

  const ShadowSoldier({
    required this.id,
    required this.name,
    required this.title,
    required this.unlockLevel,
    required this.buffDescription,
    required this.buffStat,
    required this.buffMultiplier,
    required this.emoji,
    required this.quote,
    required this.shadowColor,
  });
}

class ShadowCatalog {
  static const List<ShadowSoldier> allShadows = [
    ShadowSoldier(
      id: 'igris',
      name: 'Igris',
      title: 'The Bloodred Commander',
      unlockLevel: 10,
      buffDescription: '+10% Knowledge Power (INT) from quizzes',
      buffStat: 'INT',
      buffMultiplier: 0.10,
      emoji: '🗡️',
      quote: '"I will eliminate every obstacle on my master\'s path."',
      shadowColor: Color(0xFFEF4444), // Bloodred
    ),
    ShadowSoldier(
      id: 'tank',
      name: 'Tank',
      title: 'Ice Bear Alpha',
      unlockLevel: 20,
      buffDescription: '+20% Fatigue Resistance (slower exhaustion)',
      buffStat: 'FATIGUE',
      buffMultiplier: 0.20,
      emoji: '🐻',
      quote: '"ROOOAAAR! (Stands unyielding against exhaustion.)"',
      shadowColor: Color(0xFF38BDF8), // Ice blue
    ),
    ShadowSoldier(
      id: 'iron',
      name: 'Iron',
      title: 'Heavy Shield Guardian',
      unlockLevel: 30,
      buffDescription: '+15% Strength & Vitality in physical conditioning',
      buffStat: 'STR',
      buffMultiplier: 0.15,
      emoji: '🛡️',
      quote: '"My shield stands between my lord and all harm."',
      shadowColor: Color(0xFFA855F7), // Royal purple
    ),
    ShadowSoldier(
      id: 'beru',
      name: 'Beru',
      title: 'Ant King General',
      unlockLevel: 40,
      buffDescription: '+20% Battle IQ in Stat Duels & PvP',
      buffStat: 'BATTLE_IQ',
      buffMultiplier: 0.20,
      emoji: '👑',
      quote: '"My King! Let me devour your academic rivals!"',
      shadowColor: Color(0xFFF59E0B), // Amber / Gold
    ),
    ShadowSoldier(
      id: 'bellion',
      name: 'Bellion',
      title: 'Grand Marshal',
      unlockLevel: 50,
      buffDescription: '+25% Boost to All Attributes (INT, SEN, STR, VIT, AGI)',
      buffStat: 'ALL',
      buffMultiplier: 0.25,
      emoji: '⚡',
      quote: '"I command the millions of the Shadow Monarch\'s legion."',
      shadowColor: Color(0xFFFFD700), // Supreme Gold
    ),
  ];
}
