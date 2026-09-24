import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:studycompete/features/missions/models/hunter_streak_model.dart';
import 'package:studycompete/features/missions/services/hunter_streak_service.dart';
import 'package:studycompete/features/missions/widgets/supply_crate_dialog.dart';
import 'package:studycompete/shared/utils/haptic_feedback_utils.dart';

class DailyStreakBanner extends ConsumerStatefulWidget {
  final String uid;

  const DailyStreakBanner({super.key, required this.uid});

  @override
  ConsumerState<DailyStreakBanner> createState() => _DailyStreakBannerState();
}

class _DailyStreakBannerState extends ConsumerState<DailyStreakBanner> {
  bool _isClaiming = false;

  Future<void> _claimCrate(HunterStreakData streak) async {
    if (_isClaiming) return;
    setState(() => _isClaiming = true);

    try {
      final service = ref.read(hunterStreakServiceProvider);
      final result = await service.claimDailyCrate(
        uid: widget.uid,
        xpMultiplier: streak.xpMultiplier,
      );

      if (mounted) {
        await SupplyCrateDialog.show(
          context,
          xpAwarded: result['xpAwarded'] as int,
          fatiguePurged: result['fatiguePurged'] as int,
          multiplier: streak.xpMultiplier,
          systemQuote: result['quote'] as String,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isClaiming = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final streakAsync = ref.watch(hunterStreakProvider(widget.uid));
    final streak = streakAsync.value ?? const HunterStreakData();
    final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final isClaimable = streak.isCrateClaimable(todayKey);
    final isAtRisk = streak.isStreakAtRisk(todayKey);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF0F172A),
            streak.auraColor.withOpacity(0.18),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: streak.auraColor.withOpacity(0.4),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: streak.auraColor.withOpacity(0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Flame Streak + Tier + Crate Action
          Row(
            children: [
              // Flame Counter
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: streak.auraColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: streak.auraColor.withOpacity(0.35)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(streak.flameEmoji, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 6),
                    Text(
                      '${streak.currentStreak} DAYS',
                      style: TextStyle(
                        color: streak.auraColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Multiplier Chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bolt_rounded, color: Colors.amber, size: 14),
                    const SizedBox(width: 3),
                    Text(
                      '${streak.xpMultiplier.toStringAsFixed(2)}x XP',
                      style: const TextStyle(
                        color: Colors.amber,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Claim Crate Button
              ElevatedButton.icon(
                onPressed: isClaimable && !_isClaiming
                    ? () => _claimCrate(streak)
                    : null,
                icon: _isClaiming
                    ? const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(isClaimable ? '🎁' : '✓', style: const TextStyle(fontSize: 12)),
                label: Text(
                  isClaimable ? 'CLAIM CRATE' : 'CLAIMED',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 10),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isClaimable
                      ? const Color(0xFFA855F7)
                      : Colors.white.withOpacity(0.08),
                  foregroundColor: isClaimable ? Colors.white : Colors.white54,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: isClaimable ? 4 : 0,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // 7-Day Rolling Habit Tracker
          _build7DayTracker(streak),

          // Warning if streak is at risk today
          if (isAtRisk) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Text('⚠️', style: TextStyle(fontSize: 12)),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Complete a mission today to protect your streak from reset!',
                      style: TextStyle(
                        color: Colors.amber,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _build7DayTracker(HunterStreakData streak) {
    final now = DateTime.now();
    // 7 days ending today
    final days = List.generate(7, (i) => now.subtract(Duration(days: 6 - i)));

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: days.map((day) {
        final key = DateFormat('yyyy-MM-dd').format(day);
        final dayName = DateFormat('E').format(day)[0]; // M, T, W...
        final isToday = DateFormat('yyyy-MM-dd').format(now) == key;
        final isCompleted = streak.isDateActive(key);

        return Column(
          children: [
            Text(
              dayName,
              style: TextStyle(
                color: isToday ? streak.auraColor : Colors.white38,
                fontSize: 10,
                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted
                    ? streak.auraColor.withOpacity(0.25)
                    : (isToday ? Colors.white10 : Colors.white.withOpacity(0.04)),
                border: Border.all(
                  color: isCompleted
                      ? streak.auraColor
                      : (isToday ? streak.auraColor.withOpacity(0.6) : Colors.white12),
                  width: isToday ? 1.5 : 1,
                ),
              ),
              child: Center(
                child: isCompleted
                    ? Icon(Icons.local_fire_department_rounded,
                        color: streak.auraColor, size: 16)
                    : (isToday
                        ? Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: streak.auraColor,
                              shape: BoxShape.circle,
                            ),
                          )
                        : null),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}
