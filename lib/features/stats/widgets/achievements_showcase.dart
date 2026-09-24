import 'package:flutter/material.dart';
import 'package:studycompete/features/auth/models/user_model.dart';
import 'package:studycompete/features/stats/models/achievement_item.dart';

class AchievementsShowcase extends StatelessWidget {
  final UserModel user;

  const AchievementsShowcase({super.key, required this.user});

  List<AchievementItem> _generateAchievements() {
    final level = (user.xp ~/ 200) + 1;
    final streak = user.stats.streak;
    final battleIq = user.battleIQ;
    final kp = user.knowledgePower;

    return [
      AchievementItem(
        id: 'awakened',
        title: 'Awakened Hunter',
        description: 'Successfully joined the Hunter Association and activated daily missions.',
        emoji: '🗡️',
        rarity: HunterRarity.common,
        isUnlocked: true,
      ),
      AchievementItem(
        id: 'iron_will',
        title: 'Iron Will',
        description: 'Maintain a study streak of at least 7 consecutive days.',
        emoji: '🔥',
        rarity: HunterRarity.rare,
        isUnlocked: streak >= 7,
        progress: (streak / 7).clamp(0.0, 1.0),
      ),
      AchievementItem(
        id: 'wolf_slayer',
        title: 'Wolf Slayer',
        description: 'Reach Hunter Level 10 and break through to D-Rank.',
        emoji: '🐺',
        rarity: HunterRarity.rare,
        isUnlocked: level >= 10,
        progress: (level / 10).clamp(0.0, 1.0),
      ),
      AchievementItem(
        id: 'grimoire_master',
        title: 'Grimoire Master',
        description: 'Accumulate over 50 Knowledge Power through subject quiz excellence.',
        emoji: '📖',
        rarity: HunterRarity.epic,
        isUnlocked: kp >= 50,
        progress: (kp / 50).clamp(0.0, 1.0),
      ),
      AchievementItem(
        id: 'kasaka_venom',
        title: "Kasaka's Fang",
        description: 'Emerge victorious in 5 head-to-head RPG stat battles.',
        emoji: '⚔️',
        rarity: HunterRarity.epic,
        isUnlocked: battleIq >= 5,
        progress: (battleIq / 5).clamp(0.0, 1.0),
      ),
      AchievementItem(
        id: 'guild_master',
        title: 'Guild Master',
        description: 'Achieve Level 30 and obtain the B-Rank leadership authority.',
        emoji: '🔮',
        rarity: HunterRarity.epic,
        isUnlocked: level >= 30,
        progress: (level / 30).clamp(0.0, 1.0),
      ),
      AchievementItem(
        id: 'rulers_authority',
        title: "Ruler's Authority",
        description: 'Attain Level 50 and ascend to the S-Rank Shadow Monarch.',
        emoji: '👑',
        rarity: HunterRarity.legendary,
        isUnlocked: level >= 50,
        progress: (level / 50).clamp(0.0, 1.0),
      ),
      AchievementItem(
        id: 'mind_of_light',
        title: 'Mind of Light',
        description: 'Achieve an IQ rating of 100+ through verified syllabus testing.',
        emoji: '⚡',
        rarity: HunterRarity.legendary,
        isUnlocked: user.iq >= 100,
        progress: (user.iq / 100).clamp(0.0, 1.0),
      ),
    ];
  }

  void _showAchievementDetail(BuildContext context, AchievementItem item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: item.rarityColor.withOpacity(0.18),
                border: Border.all(color: item.rarityColor, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: item.rarityColor.withOpacity(0.35),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: Center(
                child: Text(item.emoji, style: const TextStyle(fontSize: 34)),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              item.title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: item.rarityColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: item.rarityColor.withOpacity(0.4)),
              ),
              child: Text(
                item.rarityLabel,
                style: TextStyle(
                  color: item.rarityColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 10,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              item.description,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 18),
            if (!item.isUnlocked) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: item.progress,
                  minHeight: 8,
                  backgroundColor: Colors.white10,
                  valueColor: AlwaysStoppedAnimation<Color>(item.rarityColor),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Progress: ${(item.progress * 100).toInt()}%',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ] else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.greenAccent),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, color: Colors.greenAccent, size: 14),
                    SizedBox(width: 6),
                    Text(
                      'UNLOCKED & ACTIVE',
                      style: TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final achievements = _generateAchievements();
    final unlockedCount = achievements.where((a) => a.isUnlocked).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.military_tech, size: 20, color: Color(0xFFFFD700)),
                  SizedBox(width: 8),
                  Text(
                    'Hunter Relics & Badges',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
              Text(
                '$unlockedCount/${achievements.length} Unlocked',
                style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.85,
          ),
          itemCount: achievements.length,
          itemBuilder: (context, i) {
            final item = achievements[i];
            return GestureDetector(
              onTap: () => _showAchievementDetail(context, item),
              child: Container(
                decoration: BoxDecoration(
                  color: item.isUnlocked
                      ? item.rarityColor.withOpacity(0.08)
                      : Colors.black26,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: item.isUnlocked
                        ? item.rarityColor.withOpacity(0.5)
                        : Colors.white12,
                    width: 1.5,
                  ),
                  boxShadow: item.isUnlocked
                      ? [
                          BoxShadow(
                            color: item.rarityColor.withOpacity(0.15),
                            blurRadius: 8,
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Text(
                          item.emoji,
                          style: TextStyle(
                            fontSize: 26,
                            color: item.isUnlocked ? null : Colors.grey,
                          ),
                        ),
                        if (!item.isUnlocked)
                          Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black87,
                            ),
                            child: const Icon(Icons.lock, size: 12, color: Colors.white54),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: Text(
                        item.title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: item.isUnlocked ? Colors.white : Colors.white38,
                          height: 1.1,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
