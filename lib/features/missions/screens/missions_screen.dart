import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:studycompete/shared/utils/hunter_rank.dart';
import 'package:studycompete/shared/widgets/notification_bell.dart';
import 'package:studycompete/shared/services/notifications_service.dart';
import '../providers/missions_provider.dart';
import '../models/mission_model.dart';
import '../../social/providers/social_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/models/user_model.dart';
import '../widgets/daily_streak_banner.dart';
import '../services/hunter_streak_service.dart';
import 'package:studycompete/features/competition/providers/competition_provider.dart';

class MissionsScreen extends ConsumerStatefulWidget {
  final String uid;

  const MissionsScreen({Key? key, required this.uid}) : super(key: key);

  @override
  ConsumerState<MissionsScreen> createState() => _MissionsScreenState();
}

class _MissionsScreenState extends ConsumerState<MissionsScreen> {
  String? _initializationAttemptedFor;

  void _ensureTodayIsReady(UserModel? user) {
    if (user == null || user.uid != widget.uid || user.subjectIds.isEmpty) return;
    if (_initializationAttemptedFor == user.uid) return;

    _initializationAttemptedFor = user.uid;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await ref.read(missionsNotifierProvider.notifier).initMissions(user);
      } catch (_) {
        _initializationAttemptedFor = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final missionsAsync = ref.watch(todaysMissionsProvider(widget.uid));
    final userAsync = ref.watch(currentUserProfileProvider);
    final today = DateFormat('EEEE, MMM d').format(DateTime.now());

    _ensureTodayIsReady(userAsync.value);

    final user = userAsync.value;
    final level = user != null ? (user.xp ~/ 200) + 1 : 1;
    final rankInfo = HunterRankUtils.getRankInfo(level);
    final derived = user != null
        ? HunterRankUtils.calculateDerivedStats(user)
        : const DerivedRpgStats(
            intelligence: 20, sense: 20, strength: 20, vitality: 16, agility: 24, fatigue: 0);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Daily Quests', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: rankInfo.color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: rankInfo.color.withOpacity(0.4)),
                  ),
                  child: Text(
                    rankInfo.code,
                    style: TextStyle(
                      color: rankInfo.color,
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
            Text(today, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
        actions: [
          NotificationBell(uid: widget.uid),
          IconButton(
            tooltip: 'Mission Briefing (Daily Agenda)',
            icon: const Icon(Icons.calendar_today, color: Color(0xFF10B981)),
            onPressed: () => context.push('/home/missions/agenda'),
          ),
          IconButton(
            tooltip: 'Infinite Trial — Solo Wave Combat',
            icon: const Icon(Icons.bolt, color: Color(0xFFFFD700)),
            onPressed: () => context.push('/home/missions/infinite-trial'),
          ),
          IconButton(
            tooltip: 'Deep Focus Protocol',
            icon: const Icon(Icons.self_improvement, color: Color(0xFF38BDF8)),
            onPressed: () => context.push('/home/missions/focus'),
          ),
          IconButton(
            tooltip: 'System A.I. Hologram',
            icon: const Icon(Icons.memory, color: Color(0xFF38BDF8)),
            onPressed: () => context.push('/home/system-ai'),
          ),
          IconButton(
            tooltip: 'Settings & Account',
            icon: const Icon(Icons.settings_outlined, color: Colors.white70),
            onPressed: () => context.push('/home/stats/settings'),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: GestureDetector(
              onTap: () => context.push('/home/stats'),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: rankInfo.color.withOpacity(0.7), width: 1.5),
                ),
                child: CircleAvatar(
                  radius: 16,
                  backgroundImage: user?.photoUrl != null && user!.photoUrl!.isNotEmpty
                      ? NetworkImage(user.photoUrl!)
                      : null,
                  child: user?.photoUrl == null || user!.photoUrl!.isEmpty
                      ? const Icon(Icons.person, size: 16)
                      : null,
                ),
              ),
            ),
          ),
        ],
      ),
      body: missionsAsync.when(
        data: (missions) {
          if (missions == null) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Preparing today\'s missions…'),
                ],
              ),
            );
          }

          int totalXpToday = 0;
          for (var sm in missions.subjectMissions) {
            totalXpToday += sm.xpAwarded;
          }
          totalXpToday += missions.fitnessMission.xpAwarded;
          totalXpToday += missions.studyMission.xpAwarded;

          final streak = user?.stats.streak ?? 0;
          final dailyGoal = user?.stats.dailyXpGoal ?? 180;
          final isAllCompleted = missions.subjectMissions.every((m) => m.status == 'completed') &&
              missions.fitnessMission.status == 'completed';

          final hasAnyCompleted = missions.subjectMissions.any((m) => m.status == 'completed') ||
              missions.fitnessMission.status == 'completed' ||
              missions.studyMission.status == 'completed';
          if (hasAnyCompleted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref.read(hunterStreakServiceProvider).recordMissionCompleted(widget.uid);
            });
          }

          // ── Evaluate and dispatch in-app notifications ──────────────────
          // WHY: After each missions load, check game state and notify the
          // player if their streak is at risk or their supply crate is ready.
          // This is the primary trigger for the notification bell's content.
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            try {
              final streakData = await ref
                  .read(hunterStreakServiceProvider)
                  .watchStreak(widget.uid)
                  .first;
              final pendingDuels = await ref
                  .read(battleServiceProvider)
                  .watchPendingChallenges(widget.uid)
                  .first;
              final notifSvc = ref.read(notificationsServiceProvider);
              await notifSvc.evaluateAndNotify(
                uid: widget.uid,
                isStreakAtRisk: streakData.isStreakAtRisk(
                    DateFormat('yyyy-MM-dd').format(DateTime.now())),
                hasCrateAvailable: streakData.isCrateClaimable(
                    DateFormat('yyyy-MM-dd').format(DateTime.now())),
                hasPendingDuels: pendingDuels.isNotEmpty,
              );
            } catch (_) {}
          });

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // ── HIGH FATIGUE / SUDDEN QUEST WARNING (SOLO-LEVELING) ──
              if (derived.fatigue >= 30) ...[
                _buildFatigueWarningCard(context, derived.fatigue),
                const SizedBox(height: 16),
              ],

              // ── SOLO-LEVELING AWAKENING STREAK & GUILD SUPPLY CRATE ──
              DailyStreakBanner(uid: widget.uid),
              const SizedBox(height: 16),

              _buildTopXpCard(context, totalXpToday, streak, dailyGoal, rankInfo),
              const SizedBox(height: 24),

              // ── SUBJECT MISSIONS ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Subject Quests', style: Theme.of(context).textTheme.titleLarge),
                  Text('${missions.subjectMissions.where((m) => m.status == "completed").length}/${missions.subjectMissions.length} Complete',
                      style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              ...missions.subjectMissions.map((sm) => _SubjectMissionCard(mission: sm)),
              const SizedBox(height: 24),

              // ── FITNESS MISSION ──
              Text('Physical Training Protocol', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              _FitnessMissionCard(mission: missions.fitnessMission),
              const SizedBox(height: 24),

              // ── STUDY MISSION ──
              Text('Syllabus Verification Quest', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              _StudyMissionCard(mission: missions.studyMission),
              const SizedBox(height: 28),

              // ── INFINITE TRIAL PROMO ─────────────────────────────────────────
              GestureDetector(
                onTap: () => context.push('/home/missions/infinite-trial'),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF1A0A00), Color(0xFF0F172A)]),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.4), width: 1.5),
                    boxShadow: [BoxShadow(color: const Color(0xFFFFD700).withOpacity(0.08), blurRadius: 12)],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: const Color(0xFFFFD700).withOpacity(0.1), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.3))),
                        child: const Text('\u26a1', style: TextStyle(fontSize: 28)),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('INFINITE TRIAL', style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.5)),
                            SizedBox(height: 3),
                            Text('Solo wave combat — endless questions, growing combos, max XP', style: TextStyle(color: Colors.white60, fontSize: 11, height: 1.3)),
                            SizedBox(height: 6),
                            Text('1x -> 4x XP MULTIPLIER  -  No entry cost', style: TextStyle(color: Color(0xFFFFD700), fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Color(0xFFFFD700)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ── DAILY AGENDA SHORTCUT ────────────────────────────────────────
              GestureDetector(
                onTap: () => context.push('/home/missions/agenda'),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF10B981).withOpacity(0.25)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.calendar_today, color: Color(0xFF10B981), size: 20),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('MISSION BRIEFING', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.2)),
                            SizedBox(height: 2),
                            Text('View your optimised daily study schedule', style: TextStyle(color: Colors.white54, fontSize: 11)),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: Color(0xFF10B981), size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ── OFFLINE STUDY LOG SHORTCUT ───────────────────────────────────
              GestureDetector(
                onTap: () => context.push('/home/missions/offline-log'),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF38BDF8).withOpacity(0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.25)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.menu_book_outlined, color: Color(0xFF38BDF8), size: 20),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('OFFLINE STUDY LOG', style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.2)),
                            SizedBox(height: 2),
                            Text('Log textbook, homework & group sessions for XP', style: TextStyle(color: Colors.white54, fontSize: 11)),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: Color(0xFF38BDF8), size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildFatigueWarningCard(BuildContext context, int fatigue) {
    final isCritical = fatigue >= 70;
    final color = isCritical ? const Color(0xFFEF4444) : const Color(0xFFF59E0B);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Icon(
            isCritical ? Icons.warning_rounded : Icons.info_outline,
            color: color,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCritical ? '⚠️ CRITICAL FATIGUE WARNING ($fatigue%)' : '⚡ FATIGUE ELEVATED ($fatigue%)',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isCritical
                      ? 'Fatigue is reducing XP yields. Complete your physical training to recover stamina!'
                      : 'Complete daily missions on time to avoid fatigue penalties and sustain streaks.',
                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.arrow_forward_ios, size: 14, color: color),
            onPressed: () => context.push('/home/system-ai'),
          ),
        ],
      ),
    );
  }

  Widget _buildTopXpCard(
    BuildContext context,
    int totalXp,
    int streak,
    int dailyGoal,
    HunterRankInfo rankInfo,
  ) {
    // Build a simple 7-day activity pattern from streak length.
    // True = that day had activity (heuristic from streak, sufficient for sparkline).
    final activity = List.generate(7, (i) => i < streak.clamp(0, 7));
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: rankInfo.color.withOpacity(0.3), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: rankInfo.glowColor.withOpacity(0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 64,
                    height: 64,
                    child: CircularProgressIndicator(
                      value: dailyGoal > 0 ? (totalXp / dailyGoal).clamp(0.0, 1.0) : 0.0,
                      strokeWidth: 6,
                      backgroundColor: Colors.white12,
                      valueColor: AlwaysStoppedAnimation<Color>(rankInfo.color),
                    ),
                  ),
                  Text(
                    '🔥$streak',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'DAILY XP GAIN',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          rankInfo.title,
                          style: TextStyle(
                            color: rankInfo.color,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '+$totalXp XP',
                      style: TextStyle(
                        color: rankInfo.color,
                        fontWeight: FontWeight.w900,
                        fontSize: 26,
                      ),
                    ),
                    Text(
                      'Daily Quota: $dailyGoal XP ${totalXp >= dailyGoal ? "• COMPLETED ✅" : "• IN PROGRESS"}',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // ── 7-day XP activity sparkline ──────────────────────────────────
          _WeeklyXpSparkline(activity: activity, accentColor: rankInfo.color),
        ],
      ),
    );
  }
}

/// A zero-dependency CustomPainter that draws a 7-day activity sparkline.
/// Each of the 7 day-columns is represented by a dot that glows on active days
/// and is faint on inactive days. The active dots are connected by a smooth line.
class _WeeklyXpSparkline extends StatelessWidget {
  final List<bool> activity; // 7 entries, index 0 = oldest day
  final Color accentColor;

  const _WeeklyXpSparkline({required this.activity, required this.accentColor});

  static const _dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    // Compute current weekday index (Mon=1..Sun=7) so labels align.
    final today = DateTime.now().weekday; // 1=Mon, 7=Sun
    final labels = List.generate(7, (i) {
      final dayIdx = (today - 6 + i) % 7;
      return _dayLabels[dayIdx < 0 ? dayIdx + 7 : dayIdx];
    });

    return Column(
      children: [
        SizedBox(
          height: 32,
          child: CustomPaint(
            painter: _SparklinePainter(activity: activity, accentColor: accentColor),
            size: const Size(double.infinity, 32),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: List.generate(7, (i) {
            final isActive = i < activity.length ? activity[i] : false;
            return Expanded(
              child: Text(
                labels[i],
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: isActive ? accentColor.withOpacity(0.9) : Colors.white24,
                  letterSpacing: 0.5,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<bool> activity;
  final Color accentColor;

  const _SparklinePainter({required this.activity, required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    final n = activity.length;
    if (n == 0) return;
    final spacing = size.width / n;
    final cy = size.height / 2;
    const dotR = 4.5;
    const activeR = 5.5;

    // Draw connecting line through active dots
    final linePaint = Paint()
      ..color = accentColor.withOpacity(0.35)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    bool started = false;
    for (int i = 0; i < n; i++) {
      if (!activity[i]) continue;
      final x = spacing * i + spacing / 2;
      if (!started) {
        path.moveTo(x, cy);
        started = true;
      } else {
        path.lineTo(x, cy);
      }
    }
    canvas.drawPath(path, linePaint);

    // Draw dots
    for (int i = 0; i < n; i++) {
      final x = spacing * i + spacing / 2;
      final isActive = activity[i];

      if (isActive) {
        // Glow
        canvas.drawCircle(
          Offset(x, cy),
          activeR + 4,
          Paint()..color = accentColor.withOpacity(0.15),
        );
        canvas.drawCircle(
          Offset(x, cy),
          activeR,
          Paint()..color = accentColor,
        );
      } else {
        canvas.drawCircle(
          Offset(x, cy),
          dotR,
          Paint()
            ..color = Colors.white12
            ..style = PaintingStyle.fill,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_SparklinePainter old) => old.activity != activity || old.accentColor != accentColor;
}

class _SubjectMissionCard extends StatelessWidget {
  final SubjectMission mission;

  const _SubjectMissionCard({Key? key, required this.mission}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isCompleted = mission.status == 'completed';
    final displayName = mission.subjectName.isNotEmpty ? mission.subjectName : mission.subjectId;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: Icon(
          isCompleted ? Icons.check_circle : Icons.menu_book,
          color: isCompleted ? Colors.greenAccent : const Color(0xFF38BDF8),
        ),
        title: Text(
          displayName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Text(
          isCompleted ? '+${mission.xpAwarded} XP Awarded • Passed' : '5-question curriculum quiz • +50 XP',
          style: TextStyle(color: isCompleted ? Colors.greenAccent : Colors.grey, fontSize: 12),
        ),
        trailing: isCompleted
            ? const Chip(
                label: Text('Cleared', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11)),
                backgroundColor: Colors.greenAccent,
              )
            : ElevatedButton(
                onPressed: () {
                  final encodedName = Uri.encodeComponent(displayName);
                  context.push('/home/missions/quiz/${mission.subjectId}?subjectName=$encodedName');
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                child: const Text('Start Quiz', style: TextStyle(fontSize: 12)),
              ),
      ),
    );
  }
}

class _FitnessMissionCard extends StatelessWidget {
  final FitnessMission mission;

  const _FitnessMissionCard({Key? key, required this.mission}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isCompleted = mission.status == 'completed';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: Icon(
          isCompleted ? Icons.check_circle : Icons.fitness_center,
          color: isCompleted ? Colors.greenAccent : const Color(0xFF22C55E),
        ),
        title: const Text('Physical Conditioning', style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          isCompleted
              ? '+${mission.xpAwarded} XP Awarded • Conditioning Complete'
              : '30-min Cardio or Bodyweight Reps (Push-ups/Squats) • +30 XP',
          style: TextStyle(color: isCompleted ? Colors.greenAccent : Colors.grey, fontSize: 12),
        ),
        trailing: isCompleted
            ? const Chip(
                label: Text('Cleared', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11)),
                backgroundColor: Colors.greenAccent,
              )
            : ElevatedButton(
                onPressed: () => context.push('/home/missions/fitness'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF22C55E),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                child: const Text('Train Now', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
      ),
    );
  }
}

class _StudyMissionCard extends StatelessWidget {
  final StudyMission mission;

  const _StudyMissionCard({Key? key, required this.mission}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isCompleted = mission.status == 'completed';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: Icon(
          isCompleted ? Icons.check_circle : Icons.camera_alt,
          color: isCompleted ? Colors.greenAccent : const Color(0xFFA855F7),
        ),
        title: const Text('AI Notes Verification', style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          isCompleted
              ? '+${mission.xpAwarded} XP Awarded • Syllabus Verified'
              : 'Photo capture of handwritten notes verified by AI • +80 XP',
          style: TextStyle(color: isCompleted ? Colors.greenAccent : Colors.grey, fontSize: 12),
        ),
        trailing: isCompleted
            ? const Chip(
                label: Text('Cleared', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11)),
                backgroundColor: Colors.greenAccent,
              )
            : ElevatedButton(
                onPressed: () => context.push('/home/missions/study-verification'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFA855F7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                child: const Text('Verify Notes', style: TextStyle(fontSize: 12)),
              ),
      ),
    );
  }
}
