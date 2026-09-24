import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:studycompete/features/auth/models/user_model.dart';
import 'package:studycompete/shared/utils/hunter_rank.dart';

class HunterIdCard extends StatelessWidget {
  final UserModel user;
  final DerivedRpgStats derivedStats;
  final HunterRankInfo rankInfo;

  const HunterIdCard({
    super.key,
    required this.user,
    required this.derivedStats,
    required this.rankInfo,
  });

  @override
  Widget build(BuildContext context) {
    final level = (user.xp ~/ 200) + 1;
    final currentLevelXp = user.xp % 200;
    final progressToNext = currentLevelXp / 200.0;
    final streak = user.stats.streak;
    final fatigue = derivedStats.fatigue;

    final fatigueColor = fatigue >= 70
        ? const Color(0xFFEF4444)
        : (fatigue >= 30 ? const Color(0xFFF59E0B) : const Color(0xFF22C55E));

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A), // Sleek deep slate
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: rankInfo.color.withOpacity(0.6), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: rankInfo.glowColor.withOpacity(0.2),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // CARD TOP META
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: rankInfo.color,
                      boxShadow: [
                        BoxShadow(
                          color: rankInfo.color,
                          blurRadius: 5,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'HUNTER ASSOCIATION • ID PASS',
                    style: TextStyle(
                      color: rankInfo.color,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              // Streak badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🔥', style: TextStyle(fontSize: 11)),
                    const SizedBox(width: 4),
                    Text(
                      '$streak Days',
                      style: const TextStyle(
                        color: Colors.orange,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // AVATAR & IDENTITY
          Row(
            children: [
              // Avatar with glowing rank ring
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: rankInfo.gradientColors),
                  boxShadow: [
                    BoxShadow(
                      color: rankInfo.glowColor.withOpacity(0.5),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 34,
                  backgroundColor: const Color(0xFF1E293B),
                  child: ClipOval(
                    child: user.photoUrl != null && user.photoUrl!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: user.photoUrl!,
                            width: 68,
                            height: 68,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => const Icon(
                              Icons.person,
                              size: 34,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.person, size: 34, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Names & Title
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '@${user.username}',
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    const SizedBox(height: 6),

                    // Rank & Title Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            rankInfo.color.withOpacity(0.25),
                            rankInfo.color.withOpacity(0.08),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: rankInfo.color.withOpacity(0.5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(rankInfo.badgeAssetOrEmoji, style: const TextStyle(fontSize: 12)),
                          const SizedBox(width: 5),
                          Text(
                            '${rankInfo.name} — ${rankInfo.title}',
                            style: TextStyle(
                              color: rankInfo.color,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // LEVEL PROGRESS BAR
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'HUNTER LEVEL $level',
                    style: TextStyle(
                      color: rankInfo.color,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    '$currentLevelXp / 200 XP',
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progressToNext.clamp(0.0, 1.0),
                  minHeight: 8,
                  backgroundColor: Colors.white12,
                  valueColor: AlwaysStoppedAnimation<Color>(rankInfo.color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // FATIGUE METER (SOLO-LEVELING MECHANIC)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black38,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: fatigue >= 70 ? Colors.redAccent.withOpacity(0.6) : Colors.white10,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.battery_charging_full,
                  size: 16,
                  color: fatigueColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'FATIGUE STATUS:',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '$fatigue%',
                  style: TextStyle(
                    color: fatigueColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                if (fatigue >= 70)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.redAccent),
                    ),
                    child: const Text(
                      'HIGH FATIGUE',
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  )
                else
                  Text(
                    fatigue == 0 ? 'PEAK CONDITION' : 'NOMINAL',
                    style: TextStyle(
                      color: fatigueColor.withOpacity(0.8),
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
