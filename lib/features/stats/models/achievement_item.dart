import 'package:flutter/material.dart';

enum HunterRarity { common, rare, epic, legendary }

class AchievementItem {
  final String id;
  final String title;
  final String description;
  final String emoji;
  final HunterRarity rarity;
  final bool isUnlocked;
  final double progress; // 0.0 - 1.0

  const AchievementItem({
    required this.id,
    required this.title,
    required this.description,
    required this.emoji,
    required this.rarity,
    required this.isUnlocked,
    this.progress = 1.0,
  });

  Color get rarityColor {
    switch (rarity) {
      case HunterRarity.legendary:
        return const Color(0xFFFFD700); // Gold
      case HunterRarity.epic:
        return const Color(0xFFA855F7); // Purple
      case HunterRarity.rare:
        return const Color(0xFF38BDF8); // Cyan
      case HunterRarity.common:
        return const Color(0xFF94A3B8); // Slate
    }
  }

  String get rarityLabel {
    switch (rarity) {
      case HunterRarity.legendary:
        return 'LEGENDARY';
      case HunterRarity.epic:
        return 'EPIC';
      case HunterRarity.rare:
        return 'RARE';
      case HunterRarity.common:
        return 'COMMON';
    }
  }
}
