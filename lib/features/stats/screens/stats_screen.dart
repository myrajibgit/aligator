import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:studycompete/features/stats/widgets/achievements_showcase.dart';
import 'package:studycompete/features/stats/widgets/hunter_id_card.dart';
import 'package:studycompete/features/stats/widgets/radar_chart_widget.dart';
import 'package:studycompete/shared/theme/app_theme.dart';
import 'package:studycompete/shared/utils/hunter_rank.dart';
import 'package:studycompete/shared/widgets/notification_bell.dart';
import '../providers/stats_provider.dart';

class StatsScreen extends ConsumerWidget {
  final String uid;

  const StatsScreen({Key? key, required this.uid}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userModelProvider(uid));
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Hunter Status & RPG Stats', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          NotificationBell(uid: uid),
          IconButton(
            tooltip: 'Subject Mastery Breakdown',
            icon: const Icon(Icons.bar_chart_outlined, color: Color(0xFF38BDF8)),
            onPressed: () => context.push('/home/stats/subject-progress'),
          ),
          IconButton(
            tooltip: 'System Intelligence Report',
            icon: const Icon(Icons.analytics_outlined, color: Color(0xFF10B981)),
            onPressed: () => context.push('/home/stats/analytics'),
          ),
          IconButton(
            tooltip: "Monarch's Relic Vault",
            icon: const Icon(Icons.shield, color: Color(0xFFFFD700)),
            onPressed: () => context.push('/home/stats/vault'),
          ),
          IconButton(
            tooltip: 'Shadow Army Barracks',
            icon: const Icon(Icons.shield_moon, color: Color(0xFFA855F7)),
            onPressed: () => context.push('/home/stats/shadow-army'),
          ),
          IconButton(
            tooltip: 'System A.I. Hologram',
            icon: const Icon(Icons.memory, color: Color(0xFF38BDF8)),
            onPressed: () => context.push('/home/system-ai'),
          ),
          IconButton(
            tooltip: 'Settings & Guild Registry',
            icon: const Icon(Icons.settings_outlined, color: Colors.white70),
            onPressed: () => context.push('/home/stats/settings'),
          ),
        ],
      ),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text('Error: $err')),
        data: (user) {
          if (user == null) {
            return const Center(child: Text('User not found'));
          }

          final level = (user.xp ~/ 200) + 1;
          final rankInfo = HunterRankUtils.getRankInfo(level);
          final derivedStats = HunterRankUtils.calculateDerivedStats(user);
          final radarPoints = derivedStats.toRadarPoints();

          return CustomScrollView(
            slivers: [
              // ── HUNTER ID LICENSE CARD ────────────────────────────────────
              SliverToBoxAdapter(
                child: HunterIdCard(
                  user: user,
                  derivedStats: derivedStats,
                  rankInfo: rankInfo,
                ),
              ),

              // ── 5-AXIS RADAR CHART SECTION ────────────────────────────────
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A).withOpacity(0.6),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.radar, size: 18, color: rankInfo.color),
                          const SizedBox(width: 8),
                          Text(
                            'ATTRIBUTE RADAR MATRIX',
                            style: TextStyle(
                              color: rankInfo.color,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      RadarChartWidget(
                        points: radarPoints,
                        accentColor: rankInfo.color,
                        size: 270,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'INT (Intellect) • SEN (Sense) • VIT (Vitality) • STR (Strength) • AGI (Agility)',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white38, fontSize: 9.5),
                      ),
                    ],
                  ),
                ),
              ),

              // ── RPG STATS + FOCUS HOURS ───────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              title: 'Knowledge\nPower',
                              value: '${user.knowledgePower}',
                              icon: Icons.psychology_outlined,
                              color: const Color(0xFF0EA5E9),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _StatCard(
                              title: 'IQ Score',
                              value: '${user.iq}',
                              icon: Icons.lightbulb_outline,
                              color: const Color(0xFFF59E0B),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => context.push('/home/compete'),
                              child: _StatCard(
                                title: 'Battle IQ',
                                value: '${user.battleIQ}',
                                icon: Icons.sports_martial_arts,
                                color: const Color(0xFFEF4444),
                                badge: 'Duel →',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Focus hours card — full width
                      // WHY: Focus sessions accumulated totalFocusMinutes but this
                      // metric had zero UI presence. Showing it creates a tangible
                      // progression axis that rewards consistent deep-work habits.
                      _FocusHoursCard(
                        totalFocusMinutes: user.stats.totalFocusMinutes,
                      ),
                    ],
                  ),
                ),
              ),

              // ── ACHIEVEMENTS & RELICS ──────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 20.0),
                  child: AchievementsShowcase(user: user),
                ),
              ),

              // ── SUBJECT BREAKDOWN ─────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 28, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    'Subject Mastery Progress',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                    ),
                  ),
                ),
              ),

              if (user.subjectIds.isEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      'No subjects configured yet.',
                      style: TextStyle(color: cs.onSurface.withOpacity(0.45)),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) {
                        final subjectId = user.subjectIds[i];
                        final xp = user.subjectStats[subjectId] ?? 0;
                        return _SubjectRow(
                          subjectName: subjectId,
                          xp: xp,
                          colorSeed: i,
                        );
                      },
                      childCount: user.subjectIds.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? badge;

  const _StatCard({
    Key? key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.badge,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 26, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.65),
              height: 1.3,
            ),
            textAlign: TextAlign.center,
          ),
          if (badge != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                badge!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SubjectRow extends StatelessWidget {
  final String subjectName;
  final int xp;
  final int colorSeed;

  const _SubjectRow({
    Key? key,
    required this.subjectName,
    required this.xp,
    required this.colorSeed,
  }) : super(key: key);

  static const List<Color> _palette = [
    Color(0xFF6366F1),
    Color(0xFF0EA5E9),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
    Color(0xFF8B5CF6),
  ];

  @override
  Widget build(BuildContext context) {
    final color = _palette[colorSeed % _palette.length];
    final progress = xp > 0 ? (xp % 500) / 500.0 : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  subjectName,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '$xp XP',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: color.withOpacity(0.12),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}

/// Displays cumulative deep-work focus minutes as a stylized Hunter stat card.
///
/// Shows hours + minutes, a progress bar toward the next 100-minute milestone,
/// and a lore flavor text that scales with how much focus has been accumulated.
class _FocusHoursCard extends StatelessWidget {
  final int totalFocusMinutes;

  const _FocusHoursCard({required this.totalFocusMinutes});

  String get _progressLabel {
    if (totalFocusMinutes == 0) return 'No focus sessions recorded yet.';
    if (totalFocusMinutes < 60) return 'Training begins. The System observes.';
    if (totalFocusMinutes < 300) return 'Concentration awakening detected.';
    if (totalFocusMinutes < 1000) return 'Consistent deep work. INT is rising.';
    return 'Elite focus discipline. Monarch-level mental fortitude.';
  }

  @override
  Widget build(BuildContext context) {
    final hours = totalFocusMinutes ~/ 60;
    final mins = totalFocusMinutes % 60;
    // Progress bar cycles every 100 minutes milestone
    final milestoneProgress = (totalFocusMinutes % 100) / 100.0;
    const accentColor = Color(0xFF10B981); // Emerald

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.self_improvement, color: accentColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'DEEP FOCUS PROTOCOL',
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    ),
                    Text(
                      totalFocusMinutes == 0
                          ? '—'
                          : '${hours}h ${mins}m',
                      style: const TextStyle(
                        color: accentColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: milestoneProgress,
                    minHeight: 5,
                    backgroundColor: accentColor.withOpacity(0.12),
                    valueColor: const AlwaysStoppedAnimation<Color>(accentColor),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _progressLabel,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withOpacity(0.55),
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

