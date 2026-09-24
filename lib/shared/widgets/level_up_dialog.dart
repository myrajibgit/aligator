import 'package:flutter/material.dart';
import 'package:studycompete/shared/utils/hunter_rank.dart';

class LevelUpDialog extends StatelessWidget {
  final int newLevel;
  final String oldRank;
  final String newRank;
  final VoidCallback? onDismiss;

  const LevelUpDialog({
    super.key,
    required this.newLevel,
    required this.oldRank,
    required this.newRank,
    this.onDismiss,
  });

  static Future<void> show(
    BuildContext context, {
    required int newLevel,
    required String oldRank,
    required String newRank,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => LevelUpDialog(
        newLevel: newLevel,
        oldRank: oldRank,
        newRank: newRank,
        onDismiss: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rankInfo = HunterRankUtils.getRankInfo(newLevel);
    final isRankUp = oldRank != newRank && newRank.isNotEmpty;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A).withOpacity(0.95), // Deep slate cyber
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: rankInfo.color, width: 2),
          boxShadow: [
            BoxShadow(
              color: rankInfo.glowColor.withOpacity(0.4),
              blurRadius: 28,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // SYSTEM HEADER
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: rankInfo.color.withOpacity(0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: rankInfo.color,
                      boxShadow: [
                        BoxShadow(
                          color: rankInfo.color,
                          blurRadius: 6,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isRankUp ? '[SYSTEM: RANK ASCENSION]' : '[SYSTEM: LEVEL UP DETECTED]',
                    style: TextStyle(
                      color: rankInfo.color,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ICON / BADGE
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: rankInfo.gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: rankInfo.glowColor,
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  rankInfo.badgeAssetOrEmoji,
                  style: const TextStyle(fontSize: 42),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // LEVEL DISPLAY
            Text(
              'LEVEL $newLevel',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 32,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${rankInfo.name} • ${rankInfo.title}',
              style: TextStyle(
                color: rankInfo.color,
                fontWeight: FontWeight.bold,
                fontSize: 14,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 16),

            // BUFFS SUMMARY
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.black38,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                children: [
                  _buildBuffRow(Icons.bolt, 'Fatigue Cleared', 'Restored to 0%', Colors.greenAccent),
                  const Divider(color: Colors.white10, height: 16),
                  _buildBuffRow(Icons.auto_graph, 'Attributes Scaled', 'INT, SEN & STR Upgraded', Colors.cyanAccent),
                  if (isRankUp) ...[
                    const Divider(color: Colors.white10, height: 16),
                    _buildBuffRow(Icons.workspace_premium, 'New Rank Tier', rankInfo.name, rankInfo.color),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // CONFIRM BUTTON
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onDismiss,
                style: ElevatedButton.styleFrom(
                  backgroundColor: rankInfo.color,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 8,
                  shadowColor: rankInfo.glowColor,
                ),
                child: const Text(
                  'CONFIRM ASCENSION',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBuffRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
        ),
      ],
    );
  }
}
