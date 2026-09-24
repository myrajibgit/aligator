import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studycompete/features/auth/providers/auth_provider.dart';
import 'package:studycompete/features/stats/providers/stats_provider.dart';
import 'package:studycompete/shared/utils/hunter_rank.dart';

// -----------------------------------------------------------------------------
// HUNTER ANALYTICS DASHBOARD
//
// WHY THIS EXISTS: Every solo-leveling RPG needs a "System Status" panel where
// the hunter can inspect every dimension of their progression over time.
// Without historical visibility, hunters cannot identify their weak subjects,
// study time trends, or when their XP growth peaked/dropped. This screen is
// the System's intelligence report on the hunter.
// -----------------------------------------------------------------------------

class AnalyticsScreen extends ConsumerWidget {
  final String uid;
  const AnalyticsScreen({super.key, required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userModelProvider(uid));
    final currentUser = ref.watch(currentUserProfileProvider).value;
    final level = currentUser != null ? (currentUser.xp ~/ 200) + 1 : 1;
    final rankInfo = HunterRankUtils.getRankInfo(level);

    return Scaffold(
      backgroundColor: const Color(0xFF060B14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        title: Row(
          children: [
            Icon(Icons.analytics_outlined, color: rankInfo.color, size: 22),
            const SizedBox(width: 8),
            const Text('System Intelligence Report', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        iconTheme: const IconThemeData(color: Colors.white70),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.white10),
        ),
      ),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.white54))),
        data: (user) {
          if (user == null) return const Center(child: Text('No data', style: TextStyle(color: Colors.white38)));

          final derived = HunterRankUtils.calculateDerivedStats(user);
          final totalXp = user.xp;
          final totalFocus = user.stats.totalFocusMinutes;
          final streak = user.stats.streak;
          final subjectStats = user.subjectStats;

          // Simulate weekly XP data (7 days) — in production this would
          // come from a Firestore `xpHistory` subcollection. For now we
          // generate realistic data seeded from the user's real total XP
          // so the chart is always relative to actual progress.
          final weeklyXp = _generateWeeklyXp(totalXp, streak);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // -- SYSTEM STATUS HEADER -----------------------------------------
              _buildStatusHeader(user.displayName, rankInfo, totalXp, level),
              const SizedBox(height: 20),

              // -- WEEKLY XP CHART ----------------------------------------------
              _SectionLabel(label: 'WEEKLY XP TREND', icon: Icons.show_chart, color: rankInfo.color),
              const SizedBox(height: 12),
              _WeeklyXpChart(weeklyXp: weeklyXp, rankColor: rankInfo.color),
              const SizedBox(height: 24),

              // -- QUICK STATS ROW ----------------------------------------------
              _SectionLabel(label: 'PERFORMANCE METRICS', icon: Icons.speed, color: rankInfo.color),
              const SizedBox(height: 12),
              _buildMetricsRow(totalFocus, streak, user.stats.knowledgePower, user.stats.battleIQ),
              const SizedBox(height: 24),

              // -- 5-AXIS STAT BARS ---------------------------------------------
              _SectionLabel(label: 'ATTRIBUTE BREAKDOWN', icon: Icons.radar, color: rankInfo.color),
              const SizedBox(height: 12),
              _buildStatBars(derived, rankInfo),
              const SizedBox(height: 24),

              // -- SUBJECT MASTERY HEATMAP --------------------------------------
              if (subjectStats.isNotEmpty) ...[
                _SectionLabel(label: 'SUBJECT MASTERY MAP', icon: Icons.grid_view_rounded, color: rankInfo.color),
                const SizedBox(height: 12),
                _SubjectHeatmap(subjectStats: subjectStats),
                const SizedBox(height: 24),
              ],

              // -- FOCUS EFFICIENCY ---------------------------------------------
              _SectionLabel(label: 'FOCUS EFFICIENCY INDEX', icon: Icons.self_improvement, color: rankInfo.color),
              const SizedBox(height: 12),
              _FocusEfficiencyCard(totalFocusMinutes: totalFocus, totalXp: totalXp),
              const SizedBox(height: 24),

              // -- SYSTEM ASSESSMENT --------------------------------------------
              _SectionLabel(label: 'SYSTEM ASSESSMENT', icon: Icons.memory, color: rankInfo.color),
              const SizedBox(height: 12),
              _SystemAssessmentCard(derived: derived, streak: streak, rankInfo: rankInfo),
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatusHeader(String name, HunterRankInfo rankInfo, int xp, int level) {
    final xpInLevel = xp % 200;
    final xpToNextLevel = 200;
    final progress = xpInLevel / xpToNextLevel;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [rankInfo.color.withOpacity(0.15), Colors.transparent],
          begin: Alignment.topLeft,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: rankInfo.color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: rankInfo.color.withOpacity(0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: rankInfo.color.withOpacity(0.4))),
                child: Text(rankInfo.name, style: TextStyle(color: rankInfo.color, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.2)),
              ),
              const SizedBox(width: 8),
              Text('LV.$level', style: TextStyle(color: rankInfo.color, fontWeight: FontWeight.bold, fontSize: 14)),
              const Spacer(),
              Text('$xp XP TOTAL', style: const TextStyle(color: Colors.white54, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 12),
          Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20)),
          Text(rankInfo.title, style: TextStyle(color: rankInfo.color, fontSize: 12, letterSpacing: 1.0)),
          const SizedBox(height: 14),
          Row(
            children: [
              const Text('LV PROGRESS', style: TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
              const Spacer(),
              Text('$xpInLevel / $xpToNextLevel XP', style: TextStyle(color: rankInfo.color, fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation<Color>(rankInfo.color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsRow(int focusMinutes, int streak, int kp, int battleIq) {
    final hours = focusMinutes ~/ 60;
    final mins = focusMinutes % 60;
    return Row(
      children: [
        _MetricCard(label: 'FOCUS TIME', value: '${hours}h${mins}m', icon: Icons.self_improvement, color: const Color(0xFF10B981)),
        const SizedBox(width: 10),
        _MetricCard(label: 'STREAK', value: '${streak}d', icon: Icons.local_fire_department, color: const Color(0xFFF59E0B)),
        const SizedBox(width: 10),
        _MetricCard(label: 'KNOW. PWR', value: '$kp', icon: Icons.psychology_outlined, color: const Color(0xFF38BDF8)),
        const SizedBox(width: 10),
        _MetricCard(label: 'BATTLE IQ', value: '$battleIq', icon: Icons.sports_martial_arts, color: const Color(0xFFEF4444)),
      ],
    );
  }

  Widget _buildStatBars(DerivedRpgStats derived, HunterRankInfo rankInfo) {
    final stats = [
      ('INT', derived.intelligence, const Color(0xFF38BDF8)),
      ('SEN', derived.sense, const Color(0xFFA855F7)),
      ('STR', derived.strength, const Color(0xFFEF4444)),
      ('VIT', derived.vitality, const Color(0xFF10B981)),
      ('AGI', derived.agility, const Color(0xFFFBBF24)),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: stats.map((s) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              SizedBox(width: 32, child: Text(s.$1, style: TextStyle(color: s.$3, fontWeight: FontWeight.w900, fontSize: 11))),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (s.$2 / 100).clamp(0.0, 1.0),
                    minHeight: 10,
                    backgroundColor: s.$3.withOpacity(0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(s.$3),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(width: 36, child: Text(s.$2.round().toString(), style: TextStyle(color: s.$3, fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.end)),
            ],
          ),
        )).toList(),
      ),
    );
  }

  List<int> _generateWeeklyXp(int totalXp, int streak) {
    // Deterministic simulation based on total XP. In production this
    // would be replaced with Firestore `xpHistory` subcollection reads.
    final rng = Random(totalXp);
    final base = max(10, totalXp ~/ 20);
    return List.generate(7, (i) {
      final streakBonus = i < streak ? rng.nextInt(30) + 10 : 0;
      return rng.nextInt(base) + streakBonus;
    });
  }
}

// -----------------------------------------------------------------------------
// WEEKLY XP BAR CHART (custom canvas painter)
// -----------------------------------------------------------------------------

class _WeeklyXpChart extends StatelessWidget {
  final List<int> weeklyXp;
  final Color rankColor;

  const _WeeklyXpChart({required this.weeklyXp, required this.rankColor});

  @override
  Widget build(BuildContext context) {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final maxXp = weeklyXp.isEmpty ? 1 : weeklyXp.reduce(max);
    final todayIndex = DateTime.now().weekday - 1; // 0 = Mon

    return Container(
      height: 160,
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(7, (i) {
          final xp = i < weeklyXp.length ? weeklyXp[i] : 0;
          final frac = maxXp > 0 ? xp / maxXp : 0.0;
          final isToday = i == todayIndex;
          final barColor = isToday ? rankColor : rankColor.withOpacity(0.35);

          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (xp > 0)
                Text('$xp', style: TextStyle(color: barColor, fontSize: 8, fontWeight: FontWeight.bold)),
              const SizedBox(height: 3),
              AnimatedContainer(
                duration: Duration(milliseconds: 600 + i * 80),
                curve: Curves.easeOutCubic,
                width: 28,
                height: (100 * frac).clamp(4.0, 100.0),
                decoration: BoxDecoration(
                  color: barColor,
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(6), topRight: Radius.circular(6)),
                  boxShadow: isToday ? [BoxShadow(color: rankColor.withOpacity(0.5), blurRadius: 8, offset: const Offset(0, -2))] : [],
                ),
              ),
              const SizedBox(height: 6),
              Text(days[i], style: TextStyle(color: isToday ? rankColor : Colors.white38, fontSize: 9, fontWeight: isToday ? FontWeight.bold : FontWeight.normal)),
            ],
          );
        }),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// SUBJECT MASTERY HEATMAP
// -----------------------------------------------------------------------------

class _SubjectHeatmap extends StatelessWidget {
  final Map<String, int> subjectStats;
  const _SubjectHeatmap({required this.subjectStats});

  static const List<Color> _subjectColors = [
    Color(0xFF38BDF8), Color(0xFFA855F7), Color(0xFF10B981),
    Color(0xFFF59E0B), Color(0xFFEF4444), Color(0xFF6366F1),
  ];

  @override
  Widget build(BuildContext context) {
    final entries = subjectStats.entries.toList();
    if (entries.isEmpty) return const SizedBox.shrink();

    final maxXp = entries.map((e) => e.value).reduce(max);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: List.generate(entries.length, (i) {
          final entry = entries[i];
          final frac = maxXp > 0 ? entry.value / maxXp : 0.0;
          final color = _subjectColors[i % _subjectColors.length];
          return _HeatmapTile(
            subject: entry.key,
            xp: entry.value,
            intensity: frac,
            color: color,
          );
        }),
      ),
    );
  }
}

class _HeatmapTile extends StatelessWidget {
  final String subject;
  final int xp;
  final double intensity;
  final Color color;

  const _HeatmapTile({required this.subject, required this.xp, required this.intensity, required this.color});

  @override
  Widget build(BuildContext context) {
    final bgOpacity = 0.05 + (intensity * 0.35);
    final borderOpacity = 0.15 + (intensity * 0.45);
    final displayName = subject.length > 12 ? '${subject.substring(0, 10)}..' : subject;

    return Container(
      width: (MediaQuery.of(context).size.width - 72) / 2,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(bgOpacity),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(borderOpacity)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(displayName, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12), overflow: TextOverflow.ellipsis),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(value: intensity, minHeight: 4, backgroundColor: color.withOpacity(0.1), valueColor: AlwaysStoppedAnimation<Color>(color)),
          ),
          const SizedBox(height: 4),
          Text('$xp XP', style: TextStyle(color: color.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// FOCUS EFFICIENCY CARD
// -----------------------------------------------------------------------------

class _FocusEfficiencyCard extends StatelessWidget {
  final int totalFocusMinutes;
  final int totalXp;
  const _FocusEfficiencyCard({required this.totalFocusMinutes, required this.totalXp});

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF10B981);
    final xpPerHour = totalFocusMinutes > 0
        ? ((totalXp / totalFocusMinutes) * 60).round()
        : 0;
    final efficiency = (xpPerHour / 200).clamp(0.0, 1.0);

    String rating;
    if (xpPerHour >= 150) rating = 'ELITE EFFICIENCY';
    else if (xpPerHour >= 80) rating = 'ABOVE AVERAGE';
    else if (xpPerHour >= 40) rating = 'DEVELOPING';
    else rating = 'NOVICE';

    return Container(
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$xpPerHour XP / HOUR', style: const TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 22)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.3))),
                child: Text(rating, style: const TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 9, letterSpacing: 1.0)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(value: efficiency, minHeight: 8, backgroundColor: color.withOpacity(0.1), valueColor: const AlwaysStoppedAnimation<Color>(color)),
          ),
          const SizedBox(height: 8),
          Text('Measures XP gained per hour of focused study time. Increase by studying harder subjects and using Relics.', style: TextStyle(color: Colors.white38, fontSize: 10, height: 1.4)),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// SYSTEM ASSESSMENT CARD
// -----------------------------------------------------------------------------

class _SystemAssessmentCard extends StatelessWidget {
  final DerivedRpgStats derived;
  final int streak;
  final HunterRankInfo rankInfo;

  const _SystemAssessmentCard({required this.derived, required this.streak, required this.rankInfo});

  List<_AssessmentPoint> _buildPoints() {
    final points = <_AssessmentPoint>[];
    if (derived.intelligence >= 60) points.add(const _AssessmentPoint('High INT detected — suitable for S-rank subject mastery.', Icons.psychology, Color(0xFF38BDF8)));
    if (streak >= 7) points.add(const _AssessmentPoint('7+ day streak maintained — fatigue immunity protocol active.', Icons.local_fire_department, Color(0xFFF59E0B)));
    if (derived.fatigue >= 40) points.add(const _AssessmentPoint('Fatigue levels elevated — complete physical training to recover.', Icons.warning_amber_rounded, Color(0xFFEF4444)));
    if (derived.strength >= 50) points.add(const _AssessmentPoint('Battle IQ competitive — eligible for A-rank stat duels.', Icons.sports_martial_arts, Color(0xFFA855F7)));
    if (derived.sense >= 50) points.add(const _AssessmentPoint('Sense attribute strong — ideal candidate for Speed Trial challenges.', Icons.visibility, Color(0xFF10B981)));
    if (points.isEmpty) points.add(const _AssessmentPoint('System monitoring hunter progress. Keep training to unlock assessments.', Icons.info_outline, Colors.white38));
    return points;
  }

  @override
  Widget build(BuildContext context) {
    final points = _buildPoints();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: rankInfo.color.withOpacity(0.2)),
      ),
      child: Column(
        children: points.map((p) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(p.icon, size: 16, color: p.color),
              const SizedBox(width: 10),
              Expanded(child: Text(p.text, style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4))),
            ],
          ),
        )).toList(),
      ),
    );
  }
}

class _AssessmentPoint {
  final String text;
  final IconData icon;
  final Color color;
  const _AssessmentPoint(this.text, this.icon, this.color);
}

// -----------------------------------------------------------------------------
// REUSABLE WIDGETS
// -----------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _SectionLabel({required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.5)),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _MetricCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.18)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 15)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: Colors.white38, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 0.6), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

