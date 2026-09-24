import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:studycompete/features/auth/providers/auth_provider.dart';
import 'package:studycompete/features/missions/providers/missions_provider.dart';
import 'package:studycompete/shared/utils/hunter_rank.dart';

// -----------------------------------------------------------------------------
// DAILY AGENDA — Hunter Mission Briefing Planner
//
// WHY THIS EXISTS: Hunters without a structured daily plan tend to study
// reactively instead of proactively. The Daily Agenda transforms today's
// missions into a time-blocked schedule aligned with the hunter's peak
// performance windows. This screen answers: "When do I do what today?"
// It is the hunter's "mission briefing" before the day begins.
// -----------------------------------------------------------------------------

class DailyAgendaScreen extends ConsumerWidget {
  final String uid;
  const DailyAgendaScreen({super.key, required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProfileProvider);
    final missionsAsync = ref.watch(todaysMissionsProvider(uid));
    final today = DateFormat('EEEE, MMMM d').format(DateTime.now());
    final nowHour = DateTime.now().hour;

    return Scaffold(
      backgroundColor: const Color(0xFF060B14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Mission Briefing', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            Text(today, style: const TextStyle(color: Colors.white38, fontSize: 11)),
          ],
        ),
        iconTheme: const IconThemeData(color: Colors.white70),
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(height: 1, color: Colors.white10)),
      ),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: Colors.white38))),
        data: (user) {
          if (user == null) return const Center(child: Text('No user data.', style: TextStyle(color: Colors.white38)));

          final level = (user.xp ~/ 200) + 1;
          final rankInfo = HunterRankUtils.getRankInfo(level);
          final derived = HunterRankUtils.calculateDerivedStats(user);

          // Build agenda blocks from user's subjects and game state.
          // WHY: We model peak study time based on the user's INT stat.
          // High-INT hunters are mentally sharpest in early morning and late night;
          // average hunters perform best mid-morning and evening.
          final agendaBlocks = _buildAgendaBlocks(user.subjectIds, derived.intelligence, missionsAsync.value);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // -- DAILY BRIEF --------------------------------------------------
              _buildDailyBrief(rankInfo, user.displayName, derived),
              const SizedBox(height: 24),

              // -- QUICK ACTIONS ------------------------------------------------
              _buildQuickActions(context),
              const SizedBox(height: 24),

              // -- TIMELINE -----------------------------------------------------
              Row(
                children: [
                  Icon(Icons.schedule, size: 14, color: rankInfo.color),
                  const SizedBox(width: 8),
                  Text('TODAY\'S TIMELINE', style: TextStyle(color: rankInfo.color, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.5)),
                ],
              ),
              const SizedBox(height: 12),
              ...agendaBlocks.map((block) => _AgendaBlock(block: block, nowHour: nowHour, rankInfo: rankInfo)),

              const SizedBox(height: 24),

              // -- HUNTER TIP ---------------------------------------------------
              _buildHunterTip(derived, rankInfo),
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDailyBrief(HunterRankInfo rankInfo, String name, DerivedRpgStats derived) {
    final greetingTime = DateTime.now().hour;
    final greeting = greetingTime < 12 ? 'Morning Protocol' : greetingTime < 17 ? 'Afternoon Session' : 'Night Training';
    final condition = derived.fatigue >= 40 ? 'FATIGUED ⚠️' : derived.fatigue >= 20 ? 'NORMAL' : 'PEAK CONDITION ⚡';
    final condColor = derived.fatigue >= 40 ? const Color(0xFFEF4444) : derived.fatigue >= 20 ? const Color(0xFFF59E0B) : const Color(0xFF10B981);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [rankInfo.color.withOpacity(0.15), Colors.transparent], begin: Alignment.topLeft),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: rankInfo.color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(rankInfo.badgeAssetOrEmoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$greeting, ${name.split(' ').first}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
                    Text(rankInfo.title, style: TextStyle(color: rankInfo.color, fontSize: 11, letterSpacing: 1.0)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _BriefStat(label: 'CONDITION', value: condition, color: condColor),
              const SizedBox(width: 10),
              _BriefStat(label: 'INT STAT', value: '${derived.intelligence.round()}', color: const Color(0xFF38BDF8)),
              const SizedBox(width: 10),
              _BriefStat(label: 'SEN STAT', value: '${derived.sense.round()}', color: const Color(0xFFA855F7)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _QuickActionButton(icon: Icons.self_improvement, label: 'Focus Timer', color: const Color(0xFF38BDF8), onTap: () => context.push('/home/missions/focus'))),
        const SizedBox(width: 10),
        Expanded(child: _QuickActionButton(icon: Icons.fitness_center, label: 'Physical Training', color: const Color(0xFF22C55E), onTap: () => context.push('/home/missions/fitness'))),
        const SizedBox(width: 10),
        Expanded(child: _QuickActionButton(icon: Icons.camera_alt, label: 'Verify Notes', color: const Color(0xFFA855F7), onTap: () => context.push('/home/missions/study-verification'))),
      ],
    );
  }

  Widget _buildHunterTip(DerivedRpgStats derived, HunterRankInfo rankInfo) {
    String tip;
    if (derived.intelligence >= 60) tip = '"Your INT is in elite range. Tackle the hardest subject first — cognitive prime time is now."';
    else if (derived.fatigue >= 40) tip = '"Fatigue is impairing your focus windows. Short 25-min Pomodoro sprints are optimal today."';
    else if (derived.sense >= 50) tip = '"High Sense detected. Your instinct is sharp — trust your first answers in quiz scenarios."';
    else tip = '"Consistent daily training builds the strongest hunters. Each quest completed is a permanent stat upgrade."';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: rankInfo.color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: rankInfo.color.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.memory, size: 18, color: rankInfo.color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SYSTEM A.I. BRIEFING', style: TextStyle(color: rankInfo.color, fontWeight: FontWeight.w900, fontSize: 9, letterSpacing: 1.2)),
                const SizedBox(height: 4),
                Text(tip, style: const TextStyle(color: Colors.white70, fontSize: 12, fontStyle: FontStyle.italic, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<_AgendaItem> _buildAgendaBlocks(List<String> subjects, double intelligence, dynamic missions) {
    final blocks = <_AgendaItem>[];
    final isHighInt = intelligence >= 55;

    // Morning block — higher INT hunters start earlier
    if (isHighInt) {
      blocks.add(_AgendaItem(startHour: 6, endHour: 7, label: 'Morning Conditioning', type: _AgendaType.fitness, icon: Icons.fitness_center, color: const Color(0xFF22C55E), description: 'Physical training protocol — 30 min cardio or bodyweight'));
    }

    blocks.add(_AgendaItem(startHour: 8, endHour: 9, label: 'Focus Protocol I', type: _AgendaType.focus, icon: Icons.self_improvement, color: const Color(0xFF38BDF8), description: 'Deep work Pomodoro — 25 min study + 5 min break'));

    // Subject quests
    for (int i = 0; i < subjects.length && i < 3; i++) {
      final hour = 9 + i;
      blocks.add(_AgendaItem(
        startHour: hour,
        endHour: hour + 1,
        label: subjects[i],
        type: _AgendaType.subject,
        icon: Icons.menu_book,
        color: _subjectColor(i),
        description: '5-question curriculum quiz — earn +50 XP on pass',
      ));
    }

    if (!isHighInt) {
      blocks.add(_AgendaItem(startHour: 12, endHour: 13, label: 'Midday Conditioning', type: _AgendaType.fitness, icon: Icons.fitness_center, color: const Color(0xFF22C55E), description: 'Physical training protocol — 30 min cardio or bodyweight'));
    }

    blocks.add(_AgendaItem(startHour: 14, endHour: 15, label: 'Focus Protocol II', type: _AgendaType.focus, icon: Icons.self_improvement, color: const Color(0xFF38BDF8), description: 'Afternoon deep work session — momentum building'));

    // Remaining subjects
    for (int i = 3; i < subjects.length && i < 6; i++) {
      final hour = 15 + (i - 3);
      blocks.add(_AgendaItem(
        startHour: hour,
        endHour: hour + 1,
        label: subjects[i],
        type: _AgendaType.subject,
        icon: Icons.menu_book,
        color: _subjectColor(i),
        description: '5-question curriculum quiz — earn +50 XP on pass',
      ));
    }

    blocks.add(_AgendaItem(startHour: 19, endHour: 20, label: 'Notes Verification', type: _AgendaType.verify, icon: Icons.camera_alt, color: const Color(0xFFA855F7), description: 'AI-powered handwritten notes verification — +80 XP'));

    blocks.add(_AgendaItem(startHour: 21, endHour: 22, label: 'Infinite Trial', type: _AgendaType.trial, icon: Icons.bolt, color: const Color(0xFFFFD700), description: 'Solo endless wave combat — build your XP multiplier'));

    return blocks;
  }

  Color _subjectColor(int i) {
    const colors = [Color(0xFF38BDF8), Color(0xFFA855F7), Color(0xFF10B981), Color(0xFFF59E0B), Color(0xFFEF4444), Color(0xFF6366F1)];
    return colors[i % colors.length];
  }
}

enum _AgendaType { subject, focus, fitness, verify, trial, rest }

class _AgendaItem {
  final int startHour;
  final int endHour;
  final String label;
  final _AgendaType type;
  final IconData icon;
  final Color color;
  final String description;

  const _AgendaItem({
    required this.startHour,
    required this.endHour,
    required this.label,
    required this.type,
    required this.icon,
    required this.color,
    required this.description,
  });

  String get timeLabel {
    final start = startHour <= 12 ? '${startHour}:00 ${startHour < 12 ? "AM" : "PM"}' : '${startHour - 12}:00 PM';
    final end = endHour <= 12 ? '${endHour}:00 ${endHour < 12 ? "AM" : "PM"}' : '${endHour - 12}:00 PM';
    return '$start — $end';
  }
}

// -----------------------------------------------------------------------------
// AGENDA BLOCK WIDGET — timeline item with active state detection
// -----------------------------------------------------------------------------

class _AgendaBlock extends StatelessWidget {
  final _AgendaItem block;
  final int nowHour;
  final HunterRankInfo rankInfo;

  const _AgendaBlock({required this.block, required this.nowHour, required this.rankInfo});

  @override
  Widget build(BuildContext context) {
    final isActive = nowHour >= block.startHour && nowHour < block.endHour;
    final isPast = nowHour >= block.endHour;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline rail
          SizedBox(
            width: 48,
            child: Column(
              children: [
                Text(
                  '${block.startHour > 12 ? block.startHour - 12 : block.startHour}${block.startHour < 12 ? 'AM' : 'PM'}',
                  style: TextStyle(color: isActive ? block.color : Colors.white38, fontSize: 9, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: Container(
                    width: 2,
                    color: isActive ? block.color.withOpacity(0.6) : Colors.white10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Block card
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isActive ? block.color.withOpacity(0.1) : isPast ? Colors.white.withOpacity(0.02) : const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isActive ? block.color.withOpacity(0.5) : isPast ? Colors.white10 : Colors.white12,
                  width: isActive ? 1.5 : 1.0,
                ),
                boxShadow: isActive ? [BoxShadow(color: block.color.withOpacity(0.15), blurRadius: 10)] : [],
              ),
              child: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: block.color.withOpacity(isPast ? 0.05 : 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: block.color.withOpacity(isPast ? 0.1 : 0.25)),
                    ),
                    child: Icon(block.icon, size: 18, color: isPast ? block.color.withOpacity(0.4) : block.color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                block.label,
                                style: TextStyle(
                                  color: isPast ? Colors.white38 : Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isActive)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: block.color.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                                child: Text('ACTIVE', style: TextStyle(color: block.color, fontWeight: FontWeight.w900, fontSize: 8, letterSpacing: 1.0)),
                              ),
                            if (isPast)
                              const Icon(Icons.check_circle_outline, size: 14, color: Colors.white24),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(block.timeLabel, style: TextStyle(color: isPast ? Colors.white24 : Colors.white38, fontSize: 10)),
                        const SizedBox(height: 4),
                        Text(block.description, style: TextStyle(color: isPast ? Colors.white24 : Colors.white54, fontSize: 11, height: 1.3), maxLines: 2, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BriefStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _BriefStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withOpacity(0.2))),
        child: Column(
          children: [
            Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 12)),
            Text(label, style: const TextStyle(color: Colors.white38, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 0.6)),
          ],
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickActionButton({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 9), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

