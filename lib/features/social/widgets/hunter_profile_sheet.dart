import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:studycompete/features/auth/models/user_model.dart';
import 'package:studycompete/features/auth/providers/auth_provider.dart';
import 'package:studycompete/features/competition/providers/competition_provider.dart';
import 'package:studycompete/features/social/providers/social_provider.dart';
import 'package:studycompete/shared/constants/app_constants.dart';
import 'package:studycompete/shared/utils/haptic_feedback_utils.dart';
import 'package:studycompete/shared/utils/hunter_rank.dart';

// -----------------------------------------------------------------------------
// HUNTER PROFILE SHEET (Classmate & Rival Inspector)
//
// WHY THIS EXISTS: In competitive and social apps, players must be able to
// tap any other player's avatar or name (on leaderboards, classmate rosters,
// or battle screens) to inspect their stats, see their hunter rank, challenge
// them to a duel, or send a direct message. Without this, the social and
// competition systems feel disconnected and static.
// -----------------------------------------------------------------------------

class HunterProfileSheet extends ConsumerStatefulWidget {
  final UserModel targetUser;
  const HunterProfileSheet({super.key, required this.targetUser});

  static Future<void> show(BuildContext context, UserModel user) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => HunterProfileSheet(targetUser: user),
    );
  }

  static Future<void> showFromUid(BuildContext context, String uid) async {
    final doc = await FirebaseFirestore.instance.collection(AppConstants.usersCollection).doc(uid).get();
    if (!doc.exists) return;
    final user = UserModel.fromFirestore(doc);
    if (context.mounted) {
      show(context, user);
    }
  }

  @override
  ConsumerState<HunterProfileSheet> createState() => _HunterProfileSheetState();
}

class _HunterProfileSheetState extends ConsumerState<HunterProfileSheet> {
  bool _isCreatingDm = false;
  bool _isChallenging = false;
  bool _isBlocking = false;

  Future<void> _handleDirectMessage() async {
    final myUser = ref.read(currentUserProfileProvider).value;
    if (myUser == null) return;
    if (myUser.uid == widget.targetUser.uid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You cannot message yourself!')),
      );
      return;
    }

    setState(() => _isCreatingDm = true);
    try {
      final socialSvc = ref.read(socialServiceProvider);
      final chatId = await socialSvc.openOrCreateDm(widget.targetUser.uid);
      if (mounted) {
        Navigator.pop(context); // Close bottom sheet
        context.push(
          '/home/social/chat/$chatId',
          extra: {
            'chatTitle': widget.targetUser.displayName,
            'type': 'dm',
          },
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open chat: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreatingDm = false);
    }
  }

  Future<void> _handleChallenge() async {
    final myUser = ref.read(currentUserProfileProvider).value;
    if (myUser == null) return;
    if (myUser.uid == widget.targetUser.uid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You cannot duel yourself!')),
      );
      return;
    }

    setState(() => _isChallenging = true);
    try {
      final battleSvc = ref.read(battleServiceProvider);
      final canBattle = await battleSvc.canChallenge(
        challengerUid: myUser.uid,
        challengedUid: widget.targetUser.uid,
      );

      if (!canBattle) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Anti-Farming Limit: Max 2 duels against this hunter per week.'),
              backgroundColor: Color(0xFFF59E0B),
            ),
          );
        }
        return;
      }

      final battleId = await battleSvc.createChallenge(
        challenger: myUser,
        challenged: widget.targetUser,
      );

      HapticFeedbackUtils.success();
      if (mounted) {
        Navigator.pop(context); // Close sheet
        context.push('/home/compete/duel/$battleId');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not issue challenge: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    } finally {
      if (mounted) setState(() => _isChallenging = false);
    }
  }

  Future<void> _handleReport() async {
    final reasons = [
      'Abusive language',
      'Cheating / XP farming',
      'Spam or fake account',
      'Harassment or bullying',
      'Inappropriate content',
    ];
    String? selectedReason;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          title: const Text('Report Hunter', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Report @${widget.targetUser.username} for:',
                style: const TextStyle(color: Colors.white60, fontSize: 13),
              ),
              const SizedBox(height: 12),
              ...reasons.map((reason) => RadioListTile<String>(
                    title: Text(reason, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    value: reason,
                    groupValue: selectedReason,
                    activeColor: const Color(0xFFEF4444),
                    onChanged: (val) => setDialogState(() => selectedReason = val),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  )),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
              onPressed: selectedReason == null ? null : () => Navigator.pop(ctx, true),
              child: const Text('Submit Report'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || selectedReason == null) return;

    try {
      final myUid = ref.read(currentUserProvider)?.uid ?? '';
      await FirebaseFirestore.instance.collection('reports').add({
        'reportedUid': widget.targetUser.uid,
        'reportedBy': myUid,
        'reason': selectedReason,
        'reportedAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      if (mounted) {
        Navigator.pop(context); // Close sheet
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Report submitted. Our team will review within 48 hours.'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting report: $e')),
        );
      }
    }
  }

  Future<void> _handleBlock() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        title: const Text('Block Hunter', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          'Block @${widget.targetUser.username}? They will no longer be able to send you messages or challenge you to duels. You can unblock from Settings.',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.grey.shade800),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Block'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isBlocking = true);
    try {
      final myUid = ref.read(currentUserProvider)?.uid ?? '';
      await FirebaseFirestore.instance
          .collection(AppConstants.usersCollection)
          .doc(myUid)
          .update({
        'blockedUids': FieldValue.arrayUnion([widget.targetUser.uid]),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('@${widget.targetUser.username} has been blocked.'),
            backgroundColor: Colors.grey.shade800,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error blocking user: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isBlocking = false);
    }
  }

  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.flag_outlined, color: Color(0xFFF59E0B)),
              title: const Text('Report this Hunter',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              subtitle: const Text('Flag for abuse, cheating, or misconduct',
                  style: TextStyle(color: Colors.white38, fontSize: 11)),
              onTap: () {
                Navigator.pop(context); // close options sheet
                _handleReport();
              },
            ),
            ListTile(
              leading: const Icon(Icons.block, color: Color(0xFFEF4444)),
              title: const Text('Block this Hunter',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              subtitle: const Text('Prevents DMs and duel challenges from them',
                  style: TextStyle(color: Colors.white38, fontSize: 11)),
              onTap: () {
                Navigator.pop(context);
                _handleBlock();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.targetUser;
    final level = (user.xp ~/ 200) + 1;
    final rankInfo = HunterRankUtils.getRankInfo(level);
    final derived = HunterRankUtils.calculateDerivedStats(user);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0A0F1D),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: Colors.white12, width: 1.5)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
          ),

          // Header Profile Card
          Row(
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: rankInfo.color.withOpacity(0.2),
                backgroundImage: user.photoUrl != null && user.photoUrl!.isNotEmpty ? NetworkImage(user.photoUrl!) : null,
                child: user.photoUrl == null || user.photoUrl!.isEmpty
                    ? Text(user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?', style: TextStyle(fontSize: 26, color: rankInfo.color, fontWeight: FontWeight.bold))
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.displayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 2),
                    Text('@${user.username}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: rankInfo.color.withOpacity(0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: rankInfo.color.withOpacity(0.4))),
                          child: Text('${rankInfo.name}  •  ${rankInfo.title}', style: TextStyle(color: rankInfo.color, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 8),
                        Text('LV.$level', style: TextStyle(color: rankInfo.color, fontWeight: FontWeight.bold, fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ),
              // ── Report / Block menu ────────────────────────────────────
              IconButton(
                tooltip: 'Report or Block',
                icon: const Icon(Icons.more_vert, color: Colors.white38),
                onPressed: _showMoreOptions,
              ),
            ],
          ),
          if (user.bio.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(10)),
              child: Text('"${user.bio}"', style: const TextStyle(color: Colors.white70, fontSize: 12, fontStyle: FontStyle.italic)),
            ),
          ],
          const SizedBox(height: 16),

          // Quick Metric Badges
          Row(
            children: [
              _buildBadge('TOTAL XP', '${user.xp}', const Color(0xFFFFD700)),
              const SizedBox(width: 8),
              _buildBadge('KNOW. PWR', '${user.stats.knowledgePower}', const Color(0xFF38BDF8)),
              const SizedBox(width: 8),
              _buildBadge('BATTLE IQ', '${user.stats.battleIQ}', const Color(0xFFEF4444)),
              const SizedBox(width: 8),
              _buildBadge('STREAK', '${user.stats.streak}d', const Color(0xFFF59E0B)),
            ],
          ),
          const SizedBox(height: 16),

          // 5-Axis Derived Stats Mini Breakdown
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFF131D31), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white10)),
            child: Column(
              children: [
                _buildStatBar('INT', derived.intelligence, const Color(0xFF38BDF8)),
                const SizedBox(height: 6),
                _buildStatBar('SEN', derived.sense, const Color(0xFFA855F7)),
                const SizedBox(height: 6),
                _buildStatBar('STR', derived.strength, const Color(0xFFEF4444)),
                const SizedBox(height: 6),
                _buildStatBar('VIT', derived.vitality, const Color(0xFF10B981)),
                const SizedBox(height: 6),
                _buildStatBar('AGI', derived.agility, const Color(0xFFFBBF24)),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF38BDF8)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: _isCreatingDm
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF38BDF8)))
                      : const Icon(Icons.chat_bubble_outline, color: Color(0xFF38BDF8), size: 18),
                  label: const Text('Send DM', style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold)),
                  onPressed: _isCreatingDm ? null : _handleDirectMessage,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: _isChallenging
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.sports_kabaddi, color: Colors.white, size: 18),
                  label: const Text('Duel Challenge', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  onPressed: _isChallenging ? null : _handleChallenge,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withOpacity(0.25))),
        child: Column(
          children: [
            Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 13)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: Colors.white38, fontSize: 7, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBar(String label, double value, Color color) {
    return Row(
      children: [
        SizedBox(width: 28, child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 10))),
        const SizedBox(width: 6),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(value: (value / 100).clamp(0.0, 1.0), minHeight: 6, backgroundColor: color.withOpacity(0.1), valueColor: AlwaysStoppedAnimation<Color>(color)),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(width: 26, child: Text(value.round().toString(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.end)),
      ],
    );
  }
}
