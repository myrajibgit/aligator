import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:studycompete/features/auth/models/user_model.dart';
import 'package:studycompete/features/auth/providers/auth_provider.dart';
import 'package:studycompete/features/competition/models/leaderboard_entry_model.dart';
import 'package:studycompete/features/competition/services/leaderboard_service.dart';
import 'package:studycompete/features/competition/providers/competition_provider.dart';
import 'package:studycompete/shared/constants/app_constants.dart';
import 'package:studycompete/shared/theme/app_theme.dart';

class NewChallengeScreen extends ConsumerStatefulWidget {
  const NewChallengeScreen({super.key});

  @override
  ConsumerState<NewChallengeScreen> createState() => _NewChallengeScreenState();
}

class _NewChallengeScreenState extends ConsumerState<NewChallengeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Map<String, int> _weeklyCounts = {};
  bool _isIssuing = false;

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

  Future<int> _getBattleCount(String opponentUid) async {
    if (_weeklyCounts.containsKey(opponentUid)) {
      return _weeklyCounts[opponentUid]!;
    }
    final currentUid = ref.read(currentUserProvider)?.uid ?? '';
    final service = ref.read(battleServiceProvider);
    final count = await service.weeklyBattleCount(userA: currentUid, userB: opponentUid);
    _weeklyCounts[opponentUid] = count;
    return count;
  }

  Future<void> _issueChallenge(UserModel challenger, UserModel challenged) async {
    setState(() => _isIssuing = true);
    try {
      final service = ref.read(battleServiceProvider);
      await service.createChallenge(
        challenger: challenger,
        challenged: challenged,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚔️ Challenge sent to ${challenged.displayName}!'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$e'.replaceAll('Exception: ', '')),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isIssuing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final currentUser = ref.watch(currentUserProfileProvider).value;
    final scoutAsync = ref.watch(scoutStatusProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Issue Challenge', style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Classmates'),
            Tab(text: 'Cross-School Rivals'),
          ],
        ),
      ),
      body: currentUser == null
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildClassmatesTab(context, currentUser, cs),
                _buildCrossSchoolTab(context, currentUser, scoutAsync, cs),
              ],
            ),
    );
  }

  Widget _buildClassmatesTab(BuildContext context, UserModel user, ColorScheme cs) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(AppConstants.usersCollection)
          .where('schoolId', isEqualTo: user.schoolId)
          .where('classId', isEqualTo: user.classId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final classmates = snapshot.data!.docs
            .map((doc) => UserModel.fromFirestore(doc))
            .where((u) => u.uid != user.uid)
            .toList();

        if (classmates.isEmpty) {
          return Center(
            child: Text(
              'No other classmates found in your class yet.',
              style: TextStyle(color: cs.onSurface.withOpacity(0.6)),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: classmates.length,
          itemBuilder: (context, index) {
            final opponent = classmates[index];
            return _buildOpponentTile(context, user, opponent, cs);
          },
        );
      },
    );
  }

  Widget _buildCrossSchoolTab(
    BuildContext context,
    UserModel user,
    AsyncValue<ScoutStatusResult> scoutAsync,
    ColorScheme cs,
  ) {
    return scoutAsync.when(
      data: (scout) {
        if (!scout.isScout) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.lock, size: 54, color: Colors.purple),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Cross-School Battles Locked',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Rank in the Top 10% of your class to unlock the "Cross-School Scout" badge and challenge students from other institutes.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: cs.onSurface.withOpacity(0.65), fontSize: 13),
                  ),
                ],
              ),
            ),
          );
        }

        // Scout unlocked -> show rivals
        final rivalsAsync = ref.watch(crossSchoolOpponentsProvider);
        return rivalsAsync.when(
          data: (rivals) {
            if (rivals.isEmpty) {
              return Center(
                child: Text('No rival schools found in your area yet.',
                    style: TextStyle(color: cs.onSurface.withOpacity(0.6))),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: rivals.length,
              itemBuilder: (context, index) {
                final r = rivals[index];
                final opponent = UserModel(
                  uid: r.uid,
                  displayName: r.displayName,
                  username: r.username,
                  photoUrl: r.photoUrl,
                  bio: '',
                  schoolId: r.schoolId ?? '',
                  classId: r.classId ?? '',
                  streamId: '',
                  area: r.area ?? '',
                  subjectIds: const [],
                  xp: r.xp,
                  stats: user.stats, // fallback
                  createdAt: DateTime.now(),
                  lastActive: DateTime.now(),
                );
                return _buildOpponentTile(context, user, opponent, cs, isCrossSchool: true);
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Error: $err')),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error checking scout status: $err')),
    );
  }

  Widget _buildOpponentTile(
    BuildContext context,
    UserModel currentUser,
    UserModel opponent,
    ColorScheme cs, {
    bool isCrossSchool = false,
  }) {
    return FutureBuilder<int>(
      future: _getBattleCount(opponent.uid),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        final maxReached = count >= 2;

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isCrossSchool ? Colors.purple.withOpacity(0.3) : cs.outlineVariant.withOpacity(0.3),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: (isCrossSchool ? Colors.purple : AppColors.primary).withOpacity(0.15),
                  child: Text(
                    opponent.displayName.isNotEmpty ? opponent.displayName[0].toUpperCase() : 'S',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isCrossSchool ? Colors.purple : AppColors.primary,
                    ),
                  ),
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
                              opponent.displayName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isCrossSchool)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.purple.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text('RIVAL', style: TextStyle(color: Colors.purple, fontSize: 9, fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                      Text('@${opponent.username} • ${opponent.xp} XP',
                          style: TextStyle(color: cs.onSurface.withOpacity(0.6), fontSize: 11)),
                      const SizedBox(height: 4),
                      Text(
                        'Battles this week: $count/2',
                        style: TextStyle(
                          fontSize: 11,
                          color: maxReached ? cs.error : Colors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: maxReached || _isIssuing
                      ? null
                      : () => _issueChallenge(currentUser, opponent),
                  style: FilledButton.styleFrom(
                    backgroundColor: isCrossSchool ? Colors.purple : AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  child: Text(maxReached ? 'Max (2/2)' : 'Challenge'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
