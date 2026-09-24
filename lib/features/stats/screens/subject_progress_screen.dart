import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:studycompete/features/auth/models/user_model.dart';
import 'package:studycompete/features/auth/providers/auth_provider.dart';
import 'package:studycompete/shared/constants/app_constants.dart';
import 'package:studycompete/shared/theme/app_theme.dart';
import 'package:studycompete/shared/utils/hunter_rank.dart';

// -----------------------------------------------------------------------------
// SUBJECT PROGRESS SCREEN
//
// WHY THIS EXISTS:
// Students need granular visibility into how they perform across their
// enrolled subjects — not just a global XP number. This screen reveals:
//  • XP earned per subject (from quiz completions and offline logs)
//  • Quiz accuracy rate per subject (correct / total attempts)
//  • Daily history for the last 7 days per subject
//  • Which subject is their strongest and which needs attention
//  • Personalized AI suggestion for where to focus next
//
// This drives engagement because hunters can see where to deploy study
// resources to maximise their Intelligence stat and battle IQ.
// -----------------------------------------------------------------------------

// ── Providers ────────────────────────────────────────────────────────────────

/// Fetches the last 30 quiz attempts across all subjects for a user.
final quizHistoryProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>(
        (ref, uid) async {
  if (uid.isEmpty) return [];

  final snap = await FirebaseFirestore.instance
      .collection(AppConstants.usersCollection)
      .doc(uid)
      .collection('quizAttempts')
      .orderBy('completedAt', descending: true)
      .limit(30)
      .get();

  return snap.docs.map((d) => {...d.data(), 'id': d.id}).toList();
});

// ── Screen ────────────────────────────────────────────────────────────────────

class SubjectProgressScreen extends ConsumerWidget {
  final String uid;

  const SubjectProgressScreen({super.key, required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProfileProvider);
    final quizAsync = ref.watch(quizHistoryProvider(uid));

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SUBJECT PROGRESS',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 14,
                letterSpacing: 1.2,
                color: Color(0xFF38BDF8),
              ),
            ),
            Text(
              'Per-subject intelligence breakdown',
              style: TextStyle(fontSize: 11, color: Colors.white54),
            ),
          ],
        ),
      ),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (user) {
          if (user == null) {
            return const Center(child: Text('User not found'));
          }
          return quizAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) =>
                Center(child: Text('Error loading history: $e')),
            data: (history) =>
                _SubjectProgressBody(user: user, quizHistory: history),
          );
        },
      ),
    );
  }
}

// ── Body ─────────────────────────────────────────────────────────────────────

class _SubjectProgressBody extends StatelessWidget {
  final UserModel user;
  final List<Map<String, dynamic>> quizHistory;

  const _SubjectProgressBody(
      {required this.user, required this.quizHistory});

  // Compute per-subject accuracy from quizHistory
  Map<String, _SubjectStat> _computeStats() {
    final stats = <String, _SubjectStat>{};

    // Seed from user's enrolled subjects
    for (final id in user.subjectIds) {
      stats[id] = _SubjectStat(
        subjectId: id,
        xpEarned: user.stats.subjectStats[id] ?? 0,
      );
    }

    // Process quiz attempts
    for (final attempt in quizHistory) {
      final sid = attempt['subjectId'] as String? ?? '';
      final correct = (attempt['correctAnswers'] as int?) ?? 0;
      final total = (attempt['totalQuestions'] as int?) ?? 0;
      final xp = (attempt['xpAwarded'] as int?) ?? 0;

      if (!stats.containsKey(sid)) {
        stats[sid] = _SubjectStat(subjectId: sid, xpEarned: 0);
      }

      stats[sid] = stats[sid]!.copyWith(
        totalAttempts: stats[sid]!.totalAttempts + total,
        correctAnswers: stats[sid]!.correctAnswers + correct,
      );
    }

    return stats;
  }

  @override
  Widget build(BuildContext context) {
    final subjectStats = _computeStats();
    final sortedSubjects = subjectStats.values.toList()
      ..sort((a, b) => b.xpEarned.compareTo(a.xpEarned));

    if (sortedSubjects.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.school_outlined,
                size: 72, color: Colors.white.withOpacity(0.15)),
            const SizedBox(height: 16),
            const Text(
              'No subjects enrolled',
              style: TextStyle(color: Colors.white54),
            ),
          ],
        ),
      );
    }

    // Identify weakest and strongest
    final strongest = sortedSubjects.first;
    final weakest = sortedSubjects.last;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // ── Summary Intelligence Card ───────────────────────────────────
        _buildSummaryCard(context, user, sortedSubjects),
        const SizedBox(height: 20),

        // ── AI Tactical Recommendation ─────────────────────────────────
        _buildRecommendationCard(strongest, weakest),
        const SizedBox(height: 20),

        // ── Per-Subject breakdown ──────────────────────────────────────
        const Text(
          'SUBJECT BREAKDOWN',
          style: TextStyle(
            color: Colors.white38,
            fontWeight: FontWeight.w800,
            fontSize: 11,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        ...sortedSubjects.asMap().entries.map((entry) {
          final rank = entry.key + 1;
          final stat = entry.value;
          return _buildSubjectCard(
              context, stat, rank, strongest.xpEarned);
        }),
        const SizedBox(height: 24),

        // ── Recent Quiz Activity ────────────────────────────────────────
        if (quizHistory.isNotEmpty) ...[
          const Text(
            'RECENT QUIZ ACTIVITY',
            style: TextStyle(
              color: Colors.white38,
              fontWeight: FontWeight.w800,
              fontSize: 11,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          ...quizHistory.take(8).map((q) => _buildQuizHistoryTile(q)),
        ],
      ],
    );
  }

  Widget _buildSummaryCard(BuildContext context, UserModel user,
      List<_SubjectStat> sortedSubjects) {
    final totalXp = sortedSubjects.fold(0, (sum, s) => sum + s.xpEarned);
    final totalAttempts =
        sortedSubjects.fold(0, (sum, s) => sum + s.totalAttempts);
    final totalCorrect =
        sortedSubjects.fold(0, (sum, s) => sum + s.correctAnswers);
    final accuracy = totalAttempts > 0
        ? ((totalCorrect / totalAttempts) * 100).round()
        : 0;

    final level = (user.xp ~/ 200) + 1;
    final rankInfo = HunterRankUtils.getRankInfo(level);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            rankInfo.color.withOpacity(0.15),
            const Color(0xFF0F172A),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: rankInfo.color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(rankInfo.badgeAssetOrEmoji,
                  style: const TextStyle(fontSize: 32)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '${rankInfo.title}  •  Lv.$level',
                      style: TextStyle(
                        color: rankInfo.color,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${user.xp} XP',
                    style: TextStyle(
                      color: rankInfo.color,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                  const Text(
                    'Total XP',
                    style: TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStatPill('📚', 'Subjects',
                  '${sortedSubjects.length}', rankInfo.color),
              const SizedBox(width: 8),
              _buildStatPill('🎯', 'Accuracy',
                  '$accuracy%', const Color(0xFF10B981)),
              const SizedBox(width: 8),
              _buildStatPill('⚡', 'Subject XP',
                  '$totalXp', const Color(0xFFFFD700)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatPill(
      String emoji, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
            Text(
              label,
              style: const TextStyle(color: Colors.white38, fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationCard(
      _SubjectStat strongest, _SubjectStat weakest) {
    final isStrong = strongest.accuracy > 75;
    final recommendation = weakest.totalAttempts == 0
        ? '${weakest.subjectDisplayName} hasn\'t been attempted yet — start there to unlock full battle IQ potential!'
        : weakest.accuracy < 60
            ? '${weakest.subjectDisplayName} accuracy is at ${weakest.accuracy}% — below the 60% mastery threshold. Prioritise it to boost your Knowledge Power.'
            : '${strongest.subjectDisplayName} is your strongest subject at ${strongest.accuracy}% accuracy. Cross-train by focusing on ${weakest.subjectDisplayName} to balance all stats.';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🤖', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SYSTEM A.I. RECOMMENDATION',
                  style: TextStyle(
                    color: Color(0xFF38BDF8),
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  recommendation,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectCard(BuildContext context, _SubjectStat stat, int rank,
      int maxXp) {
    // Color progression: highest gets gold, lowest gets dimmer color
    final colors = [
      const Color(0xFFFFD700), // 1st - gold
      const Color(0xFF38BDF8), // 2nd - cyan
      const Color(0xFF10B981), // 3rd - green
      const Color(0xFFA855F7), // 4th - purple
      const Color(0xFFF59E0B), // 5th+ - amber
    ];
    final color = colors[rank <= 5 ? rank - 1 : 4];
    final progressFraction =
        maxXp > 0 ? (stat.xpEarned / maxXp).clamp(0.0, 1.0) : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withOpacity(0.4)),
                ),
                child: Center(
                  child: Text(
                    '#$rank',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  stat.subjectDisplayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              Text(
                '+${stat.xpEarned} XP',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // XP progress bar relative to top subject
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progressFraction,
              backgroundColor: color.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildMiniStat('Attempts', '${stat.totalAttempts}',
                  Colors.white54),
              const SizedBox(width: 16),
              _buildMiniStat('Correct', '${stat.correctAnswers}',
                  const Color(0xFF10B981)),
              const SizedBox(width: 16),
              _buildMiniStat(
                  'Accuracy',
                  stat.totalAttempts > 0 ? '${stat.accuracy}%' : 'N/A',
                  stat.accuracy >= 60
                      ? const Color(0xFF10B981)
                      : const Color(0xFFEF4444)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white30, fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildQuizHistoryTile(Map<String, dynamic> attempt) {
    final subject =
        (attempt['subjectId'] as String? ?? '').replaceAll('_', ' ');
    final correct = (attempt['correctAnswers'] as int?) ?? 0;
    final total = (attempt['totalQuestions'] as int?) ?? 1;
    final xp = (attempt['xpAwarded'] as int?) ?? 0;
    final ts = attempt['completedAt'];
    final DateTime? date =
        ts is Timestamp ? ts.toDate() : null;
    final accuracy = total > 0 ? ((correct / total) * 100).round() : 0;
    final passed = accuracy >= 60;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (passed ? const Color(0xFF10B981) : const Color(0xFFEF4444))
              .withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            passed ? Icons.check_circle : Icons.cancel,
            color: passed
                ? const Color(0xFF10B981)
                : const Color(0xFFEF4444),
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subject.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                Text(
                  '$correct/$total correct • $accuracy% accuracy',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '+$xp XP',
                style: TextStyle(
                  color: passed
                      ? const Color(0xFF10B981)
                      : Colors.white38,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              if (date != null)
                Text(
                  DateFormat('MMM d').format(date),
                  style:
                      const TextStyle(color: Colors.white30, fontSize: 10),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Data model ────────────────────────────────────────────────────────────────

class _SubjectStat {
  final String subjectId;
  final int xpEarned;
  final int totalAttempts;
  final int correctAnswers;

  const _SubjectStat({
    required this.subjectId,
    required this.xpEarned,
    this.totalAttempts = 0,
    this.correctAnswers = 0,
  });

  _SubjectStat copyWith({
    int? xpEarned,
    int? totalAttempts,
    int? correctAnswers,
  }) {
    return _SubjectStat(
      subjectId: subjectId,
      xpEarned: xpEarned ?? this.xpEarned,
      totalAttempts: totalAttempts ?? this.totalAttempts,
      correctAnswers: correctAnswers ?? this.correctAnswers,
    );
  }

  int get accuracy => totalAttempts > 0
      ? ((correctAnswers / totalAttempts) * 100).round()
      : 0;

  String get subjectDisplayName =>
      subjectId.replaceAll('_', ' ').split(' ').map((w) {
        if (w.isEmpty) return w;
        return w[0].toUpperCase() + w.substring(1);
      }).join(' ');
}
