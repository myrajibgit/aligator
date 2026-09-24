import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:studycompete/features/auth/providers/auth_provider.dart';
import 'package:studycompete/features/competition/models/battle_model.dart';
import 'package:studycompete/shared/constants/app_constants.dart';
import 'package:studycompete/shared/theme/app_theme.dart';
import 'package:studycompete/shared/utils/haptic_feedback_utils.dart';
import 'package:studycompete/shared/utils/hunter_rank.dart';

class BattleDuelScreen extends ConsumerStatefulWidget {
  final String battleId;

  const BattleDuelScreen({super.key, required this.battleId});

  @override
  ConsumerState<BattleDuelScreen> createState() => _BattleDuelScreenState();
}

class _BattleDuelScreenState extends ConsumerState<BattleDuelScreen>
    with SingleTickerProviderStateMixin {
  BattleModel? _battle;
  bool _isLoading = true;
  String? _error;

  int _revealedRounds = 0;
  bool _isSimulating = false;
  Timer? _simTimer;

  late AnimationController _sparkleCtrl;

  @override
  void initState() {
    super.initState();
    _sparkleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _loadBattle();
  }

  @override
  void dispose() {
    _simTimer?.cancel();
    _sparkleCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBattle() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection(AppConstants.battlesCollection)
          .doc(widget.battleId)
          .get();

      if (!doc.exists) {
        setState(() {
          _error = 'Battle not found';
          _isLoading = false;
        });
        return;
      }

      final b = BattleModel.fromFirestore(doc);
      setState(() {
        _battle = b;
        _isLoading = false;
        // Start simulation if rounds are available
        if (b.rounds.isNotEmpty) {
          _startClashSimulation();
        } else {
          _revealedRounds = 0;
        }
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load duel: $e';
        _isLoading = false;
      });
    }
  }

  void _startClashSimulation() {
    setState(() {
      _revealedRounds = 0;
      _isSimulating = true;
    });

    _simTimer?.cancel();
    _simTimer = Timer.periodic(const Duration(milliseconds: 950), (timer) {
      if (_battle == null) return;
      if (_revealedRounds < _battle!.rounds.length) {
        setState(() {
          _revealedRounds++;
        });
        HapticFeedbackUtils.mediumImpact();
      } else {
        timer.cancel();
        setState(() {
          _isSimulating = false;
        });
        HapticFeedbackUtils.levelUp();
      }
    });
  }

  void _fastForward() {
    _simTimer?.cancel();
    setState(() {
      _revealedRounds = _battle?.rounds.length ?? 3;
      _isSimulating = false;
    });
    HapticFeedbackUtils.questComplete();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final currentUid = ref.watch(currentUserProvider)?.uid ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        title: const Text('RPG Stat Duel', style: TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (_isSimulating)
            TextButton.icon(
              onPressed: _fastForward,
              icon: const Icon(Icons.fast_forward, color: Colors.amber, size: 18),
              label: const Text('SKIP', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.white70)))
              : _buildDuelContent(context, cs, currentUid),
    );
  }

  Widget _buildDuelContent(BuildContext context, ColorScheme cs, String currentUid) {
    final b = _battle!;
    final isWinner = b.winnerUid == currentUid;
    final isChallenger = b.challengerUid == currentUid;

    final visibleRounds = b.rounds.take(_revealedRounds).toList();
    int winsA = visibleRounds.where((r) => r.winnerUid == b.challengerUid).length;
    int winsB = visibleRounds.where((r) => r.winnerUid == b.challengedUid).length;
    final clashComplete = _revealedRounds >= b.rounds.length && b.rounds.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Matchup VS Banner ──
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: !clashComplete
                  ? [const Color(0xFF1E1B4B), const Color(0xFF0F172A)]
                  : (isWinner
                      ? [Colors.green.shade900, Colors.teal.shade800]
                      : [const Color(0xFF4A0E17), const Color(0xFF1E1B4B)]),
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: !clashComplete
                  ? Colors.white24
                  : (isWinner ? Colors.greenAccent : Colors.redAccent.withOpacity(0.6)),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: (!clashComplete ? Colors.purple : (isWinner ? Colors.green : Colors.red))
                    .withOpacity(0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              if (!clashComplete) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.flash_on, color: Colors.amber, size: 22),
                    const SizedBox(width: 6),
                    Text(
                      _isSimulating
                          ? 'CLASH IN PROGRESS (ROUND $_revealedRounds / ${b.rounds.length})...'
                          : 'CLASH READY',
                      style: const TextStyle(
                        color: Colors.amber,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Calculating Subject XP, IQ Precision & Knowledge Power...',
                  style: TextStyle(color: Colors.white60, fontSize: 11),
                ),
              ] else ...[
                Text(
                  isWinner ? '🏆 VICTORY!' : '⚡ DEFEAT',
                  style: TextStyle(
                    color: isWinner ? const Color(0xFFFFD700) : Colors.redAccent,
                    fontWeight: FontWeight.w900,
                    fontSize: 26,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isWinner ? '+100 XP Earned • +1 Battle IQ!' : '+20 Consolation XP Earned',
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // Challenger
                  _buildFighterBadge(
                    b.challengerName,
                    winsA,
                    clashComplete && b.winnerUid == b.challengerUid,
                    isChallenger ? 'YOU' : null,
                  ),
                  // VS Badge
                  Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: const Text('VS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$winsA - $winsB',
                        style: const TextStyle(color: Colors.amber, fontSize: 20, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                  // Challenged
                  _buildFighterBadge(
                    b.challengedName,
                    winsB,
                    clashComplete && b.winnerUid == b.challengedUid,
                    !isChallenger ? 'YOU' : null,
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '3-Round Clash Breakdown',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 1.0,
                  ),
            ),
            if (!_isSimulating && clashComplete)
              TextButton.icon(
                onPressed: _startClashSimulation,
                icon: const Icon(Icons.replay, size: 16, color: Color(0xFF38BDF8)),
                label: const Text('Replay', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 12)),
              ),
          ],
        ),
        const SizedBox(height: 12),

        // ── Rounds Breakdown ──
        if (b.rounds.isEmpty)
          const Center(child: Text('Duel rounds not resolved yet.', style: TextStyle(color: Colors.white60)))
        else
          ...List.generate(b.rounds.length, (index) {
            final round = b.rounds[index];
            final isRevealed = index < _revealedRounds;

            if (!isRevealed) {
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 6),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A).withOpacity(0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock_clock, color: Colors.white38, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      'Round ${round.roundNumber}: ${round.label}',
                      style: const TextStyle(color: Colors.white38, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    const Text('AWAITING CLASH', style: TextStyle(color: Colors.white24, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              );
            }

            return _buildRoundCard(context, round, b, currentUid, cs);
          }),

        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => context.pop(),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Return to Competition Hub', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildFighterBadge(String name, int wins, bool isMatchWinner, String? youBadge) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.topRight,
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: isMatchWinner
                      ? [const Color(0xFFFFD700), const Color(0xFFFFA000)]
                      : [Colors.white38, Colors.white12],
                ),
                boxShadow: isMatchWinner
                    ? [
                        BoxShadow(
                          color: const Color(0xFFFFD700).withOpacity(0.5),
                          blurRadius: 12,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: CircleAvatar(
                radius: 28,
                backgroundColor: const Color(0xFF1E1B4B),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'S',
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            if (isMatchWinner)
              const Positioned(
                right: 0,
                child: Icon(Icons.stars, color: Colors.amber, size: 22),
              ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 95,
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
        if (youBadge != null)
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(4)),
            child: Text(youBadge, style: const TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.bold)),
          ),
      ],
    );
  }

  Widget _buildRoundCard(
    BuildContext context,
    BattleRound r,
    BattleModel b,
    String currentUid,
    ColorScheme cs,
  ) {
    final bool roundWonByA = r.winnerUid == b.challengerUid;
    final bool currentUserWonRound = r.winnerUid == currentUid;

    IconData roundIcon;
    switch (r.statCategory) {
      case 'iq':
        roundIcon = Icons.psychology;
        break;
      case 'knowledgePower':
        roundIcon = Icons.bolt;
        break;
      default:
        roundIcon = Icons.menu_book;
        break;
    }

    final totalScore = r.scoreA + r.scoreB;
    final ratioA = totalScore > 0 ? (r.scoreA / totalScore).clamp(0.05, 0.95) : 0.5;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: currentUserWonRound ? Colors.green.withOpacity(0.5) : Colors.white12,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(roundIcon, color: const Color(0xFF38BDF8), size: 22),
                const SizedBox(width: 8),
                Text('Round ${r.roundNumber}: ${r.label}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: currentUserWonRound ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: currentUserWonRound ? Colors.greenAccent : Colors.redAccent,
                    ),
                  ),
                  child: Text(
                    currentUserWonRound ? 'ROUND WON' : 'ROUND LOST',
                    style: TextStyle(
                      color: currentUserWonRound ? Colors.greenAccent : Colors.redAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Visual stat duel balance bar
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Row(
                children: [
                  Expanded(
                    flex: (ratioA * 100).toInt(),
                    child: Container(
                      height: 12,
                      color: roundWonByA ? const Color(0xFFFFD700) : const Color(0xFF334155),
                    ),
                  ),
                  Expanded(
                    flex: ((1 - ratioA) * 100).toInt(),
                    child: Container(
                      height: 12,
                      color: !roundWonByA ? const Color(0xFFFFD700) : const Color(0xFF334155),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${b.challengerName}: ${r.scoreA}',
                  style: TextStyle(
                    fontWeight: roundWonByA ? FontWeight.bold : FontWeight.normal,
                    color: roundWonByA ? const Color(0xFFFFD700) : Colors.white60,
                    fontSize: 12,
                  ),
                ),
                Text(
                  '${b.challengedName}: ${r.scoreB}',
                  style: TextStyle(
                    fontWeight: !roundWonByA ? FontWeight.bold : FontWeight.normal,
                    color: !roundWonByA ? const Color(0xFFFFD700) : Colors.white60,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
