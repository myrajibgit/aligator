import 'package:flutter/material.dart';
import 'package:studycompete/features/auth/models/user_model.dart';

enum HunterRankTier { e, d, c, b, a, s }

class HunterRankInfo {
  final HunterRankTier tier;
  final String code; // 'E', 'D', 'C', 'B', 'A', 'S'
  final String name; // 'E-RANK', etc.
  final String title; // 'NOVICE HUNTER', etc.
  final Color color;
  final Color glowColor;
  final List<Color> gradientColors;
  final String badgeAssetOrEmoji;
  final String rankDescription;

  const HunterRankInfo({
    required this.tier,
    required this.code,
    required this.name,
    required this.title,
    required this.color,
    required this.glowColor,
    required this.gradientColors,
    required this.badgeAssetOrEmoji,
    required this.rankDescription,
  });
}

class DerivedRpgStats {
  final double intelligence; // INT
  final double sense; // SEN
  final double strength; // STR
  final double vitality; // VIT (0.8 * STR)
  final double agility; // AGI (1.2 * STR)
  final int fatigue; // 0 - 100%

  const DerivedRpgStats({
    required this.intelligence,
    required this.sense,
    required this.strength,
    required this.vitality,
    required this.agility,
    required this.fatigue,
  });

  List<RadarStatPoint> toRadarPoints() {
    return [
      RadarStatPoint(label: 'INT', value: intelligence, max: 100, fullName: 'Intelligence'),
      RadarStatPoint(label: 'SEN', value: sense, max: 100, fullName: 'Sense / Focus'),
      RadarStatPoint(label: 'VIT', value: vitality, max: 100, fullName: 'Vitality'),
      RadarStatPoint(label: 'STR', value: strength, max: 100, fullName: 'Strength'),
      RadarStatPoint(label: 'AGI', value: agility, max: 100, fullName: 'Agility'),
    ];
  }
}

class RadarStatPoint {
  final String label;
  final double value;
  final double max;
  final String fullName;

  const RadarStatPoint({
    required this.label,
    required this.value,
    required this.max,
    required this.fullName,
  });
}

class HunterRankUtils {
  /// Resolves the Hunter Rank information according to the student's level.
  static HunterRankInfo getRankInfo(int level) {
    if (level >= 50) {
      return const HunterRankInfo(
        tier: HunterRankTier.s,
        code: 'S',
        name: 'S-RANK',
        title: 'SHADOW MONARCH',
        color: Color(0xFFFFD700), // Gold
        glowColor: Color(0x99FFD700),
        gradientColors: [Color(0xFFFFD700), Color(0xFFFFA000)],
        badgeAssetOrEmoji: '👑',
        rankDescription: 'Supreme Monarch of Academic and Physical Mastery.',
      );
    } else if (level >= 40) {
      return const HunterRankInfo(
        tier: HunterRankTier.a,
        code: 'A',
        name: 'A-RANK',
        title: 'NATIONAL LEVEL',
        color: Color(0xFFEF4444), // Crimson
        glowColor: Color(0x99EF4444),
        gradientColors: [Color(0xFFEF4444), Color(0xFFDC2626)],
        badgeAssetOrEmoji: '⚔️',
        rankDescription: 'Elite competitive powerhouse representing the top echelon.',
      );
    } else if (level >= 30) {
      return const HunterRankInfo(
        tier: HunterRankTier.b,
        code: 'B',
        name: 'B-RANK',
        title: 'GUILD MASTER',
        color: Color(0xFFA855F7), // Purple
        glowColor: Color(0x99A855F7),
        gradientColors: [Color(0xFFA855F7), Color(0xFF9333EA)],
        badgeAssetOrEmoji: '🔮',
        rankDescription: 'Proven party leader commanding advanced study parties.',
      );
    } else if (level >= 20) {
      return const HunterRankInfo(
        tier: HunterRankTier.c,
        code: 'C',
        name: 'C-RANK',
        title: 'RAID LEADER',
        color: Color(0xFF38BDF8), // Cyan Blue
        glowColor: Color(0x9938BDF8),
        gradientColors: [Color(0xFF38BDF8), Color(0xFF0284C7)],
        badgeAssetOrEmoji: '🛡️',
        rankDescription: 'Reliable warrior orchestrating team duels and high daily quotas.',
      );
    } else if (level >= 10) {
      return const HunterRankInfo(
        tier: HunterRankTier.d,
        code: 'D',
        name: 'D-RANK',
        title: 'WOLF SLAYER',
        color: Color(0xFF22C55E), // Emerald
        glowColor: Color(0x9922C55E),
        gradientColors: [Color(0xFF22C55E), Color(0xFF16A34A)],
        badgeAssetOrEmoji: '🐺',
        rankDescription: 'Awakened candidate breaking through beginner barriers.',
      );
    } else {
      return const HunterRankInfo(
        tier: HunterRankTier.e,
        code: 'E',
        name: 'E-RANK',
        title: 'NOVICE HUNTER',
        color: Color(0xFF94A3B8), // Slate
        glowColor: Color(0x6694A3B8),
        gradientColors: [Color(0xFF64748B), Color(0xFF475569)],
        badgeAssetOrEmoji: '🗡️',
        rankDescription: 'Newly awakened student embarking on the path to greatness.',
      );
    }
  }

  /// Calculates derived 5-axis RPG stats from the UserModel
  static DerivedRpgStats calculateDerivedStats(UserModel user) {
    final level = (user.xp ~/ 200) + 1;
    final kp = user.knowledgePower.toDouble();
    final iq = user.iq.toDouble();
    final battleIq = user.battleIQ.toDouble();
    final streak = user.stats.streak;

    // Base attributes scaled realistically
    final rawInt = 15.0 + (kp * 0.8) + (level * 1.2);
    final rawSen = 12.0 + (iq * 0.6) + (streak * 1.5) + (level * 0.8);
    final rawStr = 10.0 + (battleIq * 1.4) + (level * 1.0) + (streak * 0.5);

    final intelligence = rawInt.clamp(10.0, 100.0);
    final sense = rawSen.clamp(10.0, 100.0);
    final strength = rawStr.clamp(10.0, 100.0);

    final vitality = (strength * 0.8).clamp(10.0, 100.0);
    final agility = (strength * 1.15).clamp(10.0, 100.0);

    // Fatigue: Streak lowers fatigue, low recent activity increases fatigue
    int calculatedFatigue = 0;
    if (streak == 0) {
      calculatedFatigue = 40; // Penalty for broken streak
    } else if (streak >= 7) {
      calculatedFatigue = 0; // Peak conditioning
    } else {
      calculatedFatigue = (25 - (streak * 3)).clamp(0, 50);
    }

    return DerivedRpgStats(
      intelligence: intelligence,
      sense: sense,
      strength: strength,
      vitality: vitality,
      agility: agility,
      fatigue: calculatedFatigue,
    );
  }
}
