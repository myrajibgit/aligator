import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:studycompete/features/auth/providers/auth_provider.dart';
import 'package:studycompete/features/competition/models/battle_model.dart';
import 'package:studycompete/features/competition/models/leaderboard_entry_model.dart';
import 'package:studycompete/features/competition/providers/competition_provider.dart';
import 'package:studycompete/shared/theme/app_theme.dart';
import 'package:studycompete/shared/utils/hunter_rank.dart';
import 'package:studycompete/shared/widgets/notification_bell.dart';
import 'package:studycompete/features/social/widgets/hunter_profile_sheet.dart';

class CompetitionHubScreen extends ConsumerStatefulWidget {
  const CompetitionHubScreen({super.key});

  @override
  ConsumerState<CompetitionHubScreen> createState() => _CompetitionHubScreenState();
}

class _CompetitionHubScreenState extends ConsumerState<CompetitionHubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _leaderboardTierIndex = 0; // 0: Class, 1: School, 2: Area, 3: Weekly

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final user = ref.watch(currentUserProfileProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.emoji_events, color: Colors.amber, size: 28),
            const SizedBox(width: 8),
            const Text('Competition Arena', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          NotificationBell(uid: user?.uid ?? ''),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: cs.onSurface.withOpacity(0.6),
          tabs: const [
            Tab(icon: Icon(Icons.leaderboard), text: 'Rankings'),
            Tab(icon: Icon(Icons.sports_kabaddi), text: 'Stat Battles'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLeaderboardTab(context, cs, user),
          _buildBattlesTab(context, cs, user),
        ],
      ),
      floatingActionButton: _tabController.index == 1
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/home/compete/new-challenge'),
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add_moderator, color: Colors.white),
              label: const Text('New Challenge', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          : null,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 1: RANKINGS & LEADERBOARDS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildLeaderboardTab(BuildContext context, ColorScheme cs, dynamic user) {
    final scoutAsync = ref.watch(scoutStatusProvider);

    return Column(
      children: [
        // ── Scout Status Banner (Top 10%) ──
        scoutAsync.when(
          data: (scout) {
            if (scout.isScout) {
              return Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6A1B9A), Color(0xFF8E24AA)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.purple.withOpacity(0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.stars_rounded, color: Colors.amber, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '⭐ CROSS-SCHOOL SCOUT ACTIVE',
                            style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          Text(
                            'Top ${(100 - scout.percentile * 100).clamp(1, 10).toInt()}% in your class! You can challenge students across schools.',
                            style: const TextStyle(color: Colors.white, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }
            return const SizedBox.shrink();
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),

        // ── Tier Selection Chips ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildTierChip('Class Rank', 0),
                const SizedBox(width: 8),
                _buildTierChip('School Rank', 1),
                const SizedBox(width: 8),
                _buildTierChip('City / Area', 2),
                const SizedBox(width: 8),
                _buildTierChip('Weekly Elite', 3),
              ],
            ),
          ),
        ),

        // ── Leaderboard List ──
        Expanded(
          child: _buildSelectedLeaderboardList(context, cs),
        ),
      ],
    );
  }

  Widget _buildTierChip(String label, int index) {
    final isSelected = _leaderboardTierIndex == index;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        if (val) setState(() => _leaderboardTierIndex = index);
      },
      selectedColor: AppColors.primary.withOpacity(0.15),
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primary : null,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildSelectedLeaderboardList(BuildContext context, ColorScheme cs) {
    AsyncValue<List<LeaderboardEntry>> listAsync;
    switch (_leaderboardTierIndex) {
      case 0:
        listAsync = ref.watch(classLeaderboardProvider);
        break;
      case 1:
        listAsync = ref.watch(schoolLeaderboardProvider);
        break;
      case 2:
        listAsync = ref.watch(areaLeaderboardProvider);
        break;
      case 3:
      default:
        listAsync = ref.watch(weeklyLeaderboardProvider);
        break;
    }

    return listAsync.when(
      data: (entries) {
        if (entries.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.military_tech_outlined, size: 64, color: cs.onSurface.withOpacity(0.3)),
                const SizedBox(height: 12),
                Text('No rankings available for this tier yet.', style: TextStyle(color: cs.onSurface.withOpacity(0.6))),
                const SizedBox(height: 4),
                const Text('Complete missions and quizzes to climb the ladder!', style: TextStyle(fontSize: 12)),
              ],
            ),
          );
        }

        final top3 = entries.take(3).toList();
        final rest = entries.skip(3).toList();

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            if (top3.length >= 2) ...[
              _buildPodium(context, top3, cs),
              const SizedBox(height: 16),
            ],
            ...entries.map((entry) => _buildLeaderboardTile(context, entry, cs)),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error loading ladder: $err')),
    );
  }

  Widget _buildPodium(BuildContext context, List<LeaderboardEntry> top, ColorScheme cs) {
    LeaderboardEntry? first = top.isNotEmpty ? top[0] : null;
    LeaderboardEntry? second = top.length > 1 ? top[1] : null;
    LeaderboardEntry? third = top.length > 2 ? top[2] : null;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (second != null) _buildPodiumCol(context, second, '🥈', 110, Colors.grey.shade400),
          if (first != null) _buildPodiumCol(context, first, '🥇', 140, Colors.amber),
          if (third != null) _buildPodiumCol(context, third, '🥉', 90, Colors.brown.shade300),
        ],
      ),
    );
  }

  Widget _buildPodiumCol(BuildContext context, LeaderboardEntry e, String badge, double height, Color color) {
    return GestureDetector(
      onTap: () => HunterProfileSheet.showFromUid(context, e.uid),
      child: Column(
        children: [
          Text(badge, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 4),
          CircleAvatar(
            radius: 24,
            backgroundColor: color.withOpacity(0.25),
            child: Text(
              e.displayName.isNotEmpty ? e.displayName[0].toUpperCase() : 'S',
              style: TextStyle(fontWeight: FontWeight.bold, color: color),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 85,
            child: Text(
              e.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          Text('${e.xp} XP', style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Container(
            width: 75,
            height: height * 0.4,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withOpacity(0.5)),
            ),
            child: Center(
              child: Text('#${e.rank}', style: TextStyle(fontWeight: FontWeight.bold, color: color)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardTile(BuildContext context, LeaderboardEntry entry, ColorScheme cs) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: entry.isCurrentUser
            ? AppColors.primary.withOpacity(0.08)
            : cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: entry.isCurrentUser
              ? AppColors.primary
              : cs.outlineVariant.withOpacity(0.4),
          width: entry.isCurrentUser ? 1.5 : 1,
        ),
      ),
      child: ListTile(
        onTap: () => HunterProfileSheet.showFromUid(context, entry.uid),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 28,
              child: Text(
                '#${entry.rank}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: entry.rank <= 3 ? Colors.amber : cs.onSurface.withOpacity(0.6),
                ),
              ),
            ),
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primary.withOpacity(0.12),
              child: Text(
                entry.displayName.isNotEmpty ? entry.displayName[0].toUpperCase() : 'S',
                style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      entry.displayName,
                      style: TextStyle(
                        fontWeight: entry.isCurrentUser ? FontWeight.bold : FontWeight.w600,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: HunterRankUtils.getRankInfo((entry.xp ~/ 200) + 1).color.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: HunterRankUtils.getRankInfo((entry.xp ~/ 200) + 1).color.withOpacity(0.5),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      HunterRankUtils.getRankInfo((entry.xp ~/ 200) + 1).code,
                      style: TextStyle(
                        color: HunterRankUtils.getRankInfo((entry.xp ~/ 200) + 1).color,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (entry.isCurrentUser)
              Container(
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('YOU', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
        subtitle: Row(
          children: [
            Text('🧠 KP: ${entry.knowledgePower}', style: TextStyle(fontSize: 11, color: cs.onSurface.withOpacity(0.6))),
            const SizedBox(width: 8),
            Text('🎯 IQ: ${entry.iq}', style: TextStyle(fontSize: 11, color: cs.onSurface.withOpacity(0.6))),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('${entry.xp} XP', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
            Text('⚔️ BIQ: ${entry.battleIq}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 2: HEAD-TO-HEAD STAT BATTLES
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildBattlesTab(BuildContext context, ColorScheme cs, dynamic user) {
    final theme = Theme.of(context);
    final uid = ref.watch(currentUserProvider)?.uid ?? '';
    final battlesAsync = ref.watch(userBattlesStreamProvider(uid));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Battle IQ Header Card ──
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, const Color(0xFF3F51B5)],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.sports_kabaddi, color: Colors.white, size: 36),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('RPG STAT BATTLES', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                    const SizedBox(height: 2),
                    Text(
                      'Battle IQ: ${user?.stats.battleIQ ?? 0}',
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '3-round asynchronous duels. Win +100 XP and boost your Battle IQ!',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ── Challenge Opponent Button ──
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => context.push('/home/compete/new-challenge'),
            icon: const Icon(Icons.flash_on, color: Colors.white),
            label: const Text('Challenge a Classmate or Rival', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),

        const SizedBox(height: 24),

        // ── Battles Stream ──
        battlesAsync.when(
          data: (battles) {
            final pendingIncoming = battles
                .where((b) => b.status == 'pending' && b.challengedUid == uid)
                .toList();
            final pendingOutgoing = battles
                .where((b) => b.status == 'pending' && b.challengerUid == uid)
                .toList();
            final completed = battles
                .where((b) => b.status == 'completed' || b.status == 'declined')
                .toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Incoming Challenges
                if (pendingIncoming.isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(Icons.notification_important, color: Colors.orange, size: 20),
                      const SizedBox(width: 8),
                      Text('Incoming Challenges (${pendingIncoming.length})', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...pendingIncoming.map((b) => _buildIncomingChallengeCard(context, b, cs)),
                  const SizedBox(height: 20),
                ],

                // 2. Sent Challenges
                if (pendingOutgoing.isNotEmpty) ...[
                  Text('Sent Challenges', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...pendingOutgoing.map((b) => _buildSentChallengeCard(context, b, cs)),
                  const SizedBox(height: 20),
                ],

                // 3. Battle History
                Text('Battle History', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (completed.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(
                      child: Text('No completed battles yet. Send your first challenge above!'),
                    ),
                  )
                else
                  ...completed.map((b) => _buildCompletedBattleCard(context, b, cs, uid)),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Error loading battles: $err')),
        ),
      ],
    );
  }

  Widget _buildIncomingChallengeCard(BuildContext context, BattleModel battle, ColorScheme cs) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.orange.withOpacity(0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.orange.withOpacity(0.2),
                  child: Text(
                    battle.challengerName.isNotEmpty ? battle.challengerName[0].toUpperCase() : 'C',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(battle.challengerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      Text('Has challenged you to a 3-Round Duel!', style: TextStyle(color: cs.onSurface.withOpacity(0.6), fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final service = ref.read(battleServiceProvider);
                      await service.declineBattle(battle.id);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: cs.error,
                      side: BorderSide(color: cs.error.withOpacity(0.5)),
                    ),
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () async {
                      final service = ref.read(battleServiceProvider);
                      final resolved = await service.acceptAndResolveBattle(battle.id);
                      if (context.mounted) {
                        context.push('/home/compete/duel/${resolved.id}');
                      }
                    },
                    icon: const Icon(Icons.sports_kabaddi, size: 18),
                    label: const Text('Accept Duel'),
                    style: FilledButton.styleFrom(backgroundColor: Colors.orange),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSentChallengeCard(BuildContext context, BattleModel battle, ColorScheme cs) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: cs.surfaceContainerHighest,
          child: const Icon(Icons.hourglass_top, color: Colors.amber, size: 20),
        ),
        title: Text('Waiting for ${battle.challengedName}'),
        subtitle: const Text('Challenge sent • Awaiting opponent acceptance', style: TextStyle(fontSize: 12)),
        trailing: const Chip(label: Text('Pending', style: TextStyle(fontSize: 11))),
      ),
    );
  }

  Widget _buildCompletedBattleCard(BuildContext context, BattleModel battle, ColorScheme cs, String uid) {
    final isWinner = battle.winnerUid == uid;
    final isDeclined = battle.status == 'declined';
    final opponentName = battle.challengerUid == uid ? battle.challengedName : battle.challengerName;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        onTap: isDeclined ? null : () => context.push('/home/compete/duel/${battle.id}'),
        leading: CircleAvatar(
          backgroundColor: isDeclined
              ? Colors.grey.withOpacity(0.2)
              : (isWinner ? Colors.green.withOpacity(0.2) : cs.error.withOpacity(0.2)),
          child: Icon(
            isDeclined
                ? Icons.block
                : (isWinner ? Icons.emoji_events : Icons.close),
            color: isDeclined
                ? Colors.grey
                : (isWinner ? Colors.green : cs.error),
          ),
        ),
        title: Text(isDeclined ? 'Declined vs $opponentName' : 'Duel vs $opponentName'),
        subtitle: Text(
          isDeclined
              ? 'Challenge declined'
              : (isWinner ? '🎉 Victory! Earned +100 XP & +1 Battle IQ' : 'Defeat. Earned +20 XP'),
          style: TextStyle(
            fontSize: 12,
            color: isDeclined ? null : (isWinner ? Colors.green : cs.onSurface.withOpacity(0.6)),
          ),
        ),
        trailing: isDeclined
            ? const Chip(label: Text('Declined', style: TextStyle(fontSize: 10)))
            : const Icon(Icons.chevron_right),
      ),
    );
  }
}
