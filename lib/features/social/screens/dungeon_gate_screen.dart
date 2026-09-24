import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:studycompete/features/auth/providers/auth_provider.dart';
import 'package:studycompete/features/social/models/dungeon_gate_model.dart';
import 'package:studycompete/features/stats/services/hunter_relic_service.dart';
import 'package:studycompete/shared/utils/haptic_feedback_utils.dart';
import 'package:studycompete/shared/widgets/notification_bell.dart';

class DungeonGateScreen extends ConsumerStatefulWidget {
  final String partyId;

  const DungeonGateScreen({super.key, required this.partyId});

  @override
  ConsumerState<DungeonGateScreen> createState() => _DungeonGateScreenState();
}

class _DungeonGateScreenState extends ConsumerState<DungeonGateScreen>
    with SingleTickerProviderStateMixin {
  late List<DungeonGateModel> _availableGates;
  late int _selectedGateIndex;
  int _userDamageDealt = 45;
  int _comboStreak = 0;
  int _questionIndex = 0;
  bool _isBossDefeated = false;

  late AnimationController _shakeController;

  DungeonGateModel get _gate => _availableGates[_selectedGateIndex];

  @override
  void initState() {
    super.initState();
    _availableGates = DungeonGateModel.getDefaultGates();
    _selectedGateIndex = 0;
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _switchGate(int index) {
    if (_selectedGateIndex == index) return;
    setState(() {
      _selectedGateIndex = index;
      _questionIndex = 0;
      _comboStreak = 0;
      _isBossDefeated = _gate.currentHp == 0;
    });
    HapticFeedbackUtils.selectionClick();
  }

  void _triggerQuizAttack(String uid, ActiveHunterBuffs buffs) {
    final questions = _gate.questions;
    if (questions.isEmpty) return;

    final q = questions[_questionIndex % questions.length];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF0F172A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: _gate.rankColor, width: 1.5),
            ),
            title: Row(
              children: [
                Icon(Icons.bolt, color: _gate.rankColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${_gate.subjectTheme} Raid Strike',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (_comboStreak > 1)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber),
                    ),
                    child: Text(
                      '${_comboStreak}x COMBO 🔥',
                      style: const TextStyle(
                        color: Colors.amber,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Solve correctly to inflict Boss Raid Damage:',
                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Text(
                    q.question,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      height: 1.3,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ...List.generate(q.options.length, (optIdx) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E293B),
                        foregroundColor: Colors.white,
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        side: const BorderSide(color: Colors.white24),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _handleAnswer(optIdx, q, uid, buffs);
                      },
                      child: Text(
                        q.options[optIdx],
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ),
                  );
                }),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Retreat / Cancel', style: TextStyle(color: Colors.white54)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _handleAnswer(int chosenIdx, RaidQuestion q, String uid, ActiveHunterBuffs buffs) {
    if (chosenIdx == q.correctIndex) {
      // Correct!
      final newStreak = _comboStreak + 1;
      final comboMultiplier = newStreak >= 3 ? 2.0 : (newStreak >= 2 ? 1.5 : 1.0);
      final relicMultiplier = buffs.gateDamageMultiplier;
      final totalDamage = (q.baseDamage * comboMultiplier * relicMultiplier).round();

      setState(() {
        _comboStreak = newStreak;
        _questionIndex++;
      });

      _executeAttackDamage(totalDamage, uid, isCritical: comboMultiplier > 1.0);
    } else {
      // Incorrect strike
      setState(() {
        _comboStreak = 0;
        _questionIndex++;
      });
      HapticFeedbackUtils.alertWarning();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Strike Deflected! ${q.explanation}'),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _executeAttackDamage(int damage, String uid, {bool isCritical = false}) {
    HapticFeedbackUtils.questComplete();
    _shakeController.forward(from: 0.0);

    setState(() {
      _gate.currentHp = (_gate.currentHp - damage).clamp(0, _gate.maxHp);
      _userDamageDealt += damage;
      if (_gate.currentHp == 0) {
        _isBossDefeated = true;
        _onBossDefeated(uid);
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isCritical
            ? '💥 CRITICAL MONARCH STRIKE! Inflicted -$damage DMG!'
            : '⚡ Raid Strike! Inflicted -$damage DMG!',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: isCritical ? const Color(0xFFA855F7) : const Color(0xFF0284C7),
        duration: const Duration(milliseconds: 1400),
      ),
    );
  }

  Future<void> _onBossDefeated(String uid) async {
    HapticFeedbackUtils.levelUp();

    // Award Relic to Vault if logged in
    if (uid.isNotEmpty && _gate.relicId.isNotEmpty) {
      final relicService = ref.read(hunterRelicServiceProvider);
      await relicService.awardRelic(uid, _gate.relicId);

      // Increment XP
      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'xp': FieldValue.increment(_gate.xpReward),
        });
      } catch (_) {}
    }

    _showVictoryDialog();
  }

  void _showVictoryDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFFFFD700), width: 2),
        ),
        title: Column(
          children: [
            const Icon(Icons.emoji_events, color: Color(0xFFFFD700), size: 48),
            const SizedBox(height: 8),
            const Text(
              'GATE CONQUERED!',
              style: TextStyle(
                color: Color(0xFFFFD700),
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${_gate.bossName} has fallen before your study party.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF311042), Color(0xFF1E1B4B)],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFA855F7)),
              ),
              child: Column(
                children: [
                  const Text(
                    '💎 LEGENDARY RELIC DROP',
                    style: TextStyle(color: Color(0xFFFFD700), fontSize: 11, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _gate.relicDrop,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '+${_gate.xpReward} XP Awarded • Deposited into Monarch\'s Vault',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Return to Gate', style: TextStyle(color: Colors.white60)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFFD700)),
            onPressed: () {
              Navigator.pop(ctx);
              context.push('/home/stats/vault');
            },
            child: const Text('EQUIP IN VAULT →', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProfileProvider).value;
    final uid = ref.watch(currentUserProvider)?.uid ?? '';
    final buffs = ref.watch(activeHunterBuffsProvider(uid));
    final hpPercent = _gate.currentHp / _gate.maxHp;

    return Scaffold(
      backgroundColor: const Color(0xFF020617), // Solo Leveling Abyss
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1329),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _gate.rankColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _gate.rankColor),
              ),
              child: Text(
                '${_gate.rank}-RANK GATE',
                style: TextStyle(color: _gate.rankColor, fontSize: 10, fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'DUNGEON BOSS RAID',
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          NotificationBell(uid: uid),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── GATE SELECTOR CAROUSEL ──
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _availableGates.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final g = _availableGates[index];
                final isSelected = _selectedGateIndex == index;
                return InkWell(
                  onTap: () => _switchGate(index),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? g.rankColor.withOpacity(0.25) : const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? g.rankColor : Colors.white12,
                        width: isSelected ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(g.bossEmoji, style: const TextStyle(fontSize: 14)),
                        const SizedBox(width: 6),
                        Text(
                          '${g.rank}: ${g.subjectTheme}',
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white60,
                            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // ── BOSS ARENA CARD ──
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E1B4B), Color(0xFF0F172A)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _gate.rankColor.withOpacity(0.5)),
              boxShadow: [
                BoxShadow(
                  color: _gate.rankColor.withOpacity(0.25),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // BOSS EMOJI AVATAR
                Text(
                  _gate.bossEmoji,
                  style: const TextStyle(fontSize: 72),
                ),
                const SizedBox(height: 10),
                Text(
                  _gate.bossName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  '${_gate.name} • ${_gate.subjectTheme} Class',
                  style: TextStyle(color: _gate.rankColor, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 18),

                // BOSS HP BAR
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'BOSS HP:',
                      style: TextStyle(color: Colors.redAccent.shade100, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${_gate.currentHp} / ${_gate.maxHp} HP (${(hpPercent * 100).toInt()}%)',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: hpPercent,
                    minHeight: 12,
                    backgroundColor: Colors.white12,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      hpPercent > 0.5
                          ? Colors.greenAccent
                          : (hpPercent > 0.2 ? Colors.orangeAccent : Colors.redAccent),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.stars, color: Color(0xFFFFD700), size: 14),
                    const SizedBox(width: 4),
                    Text(
                      'Target Relic: ${_gate.relicDrop}',
                      style: const TextStyle(color: Color(0xFFFFD700), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── RAID ATTACK CONTROLS ──
          if (!_isBossDefeated)
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _triggerQuizAttack(uid, buffs),
                    icon: const Icon(Icons.flash_on, color: Colors.amber, size: 24),
                    label: Text(
                      _comboStreak > 1
                          ? 'EXECUTE ${_comboStreak}x COMBO STRIKE!'
                          : 'EXECUTE ${_gate.subjectTheme.toUpperCase()} STRIKE',
                      style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _gate.rankColor,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
                if (buffs.gateDamageMultiplier > 1.0)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      '🛡️ Relic Buff Active: +${((buffs.gateDamageMultiplier - 1.0) * 100).toInt()}% Raid Strike Power',
                      style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            )
          else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.greenAccent),
              ),
              child: Column(
                children: [
                  const Text('🏆 DUNGEON GATE CONQUERED!', style: TextStyle(color: Colors.greenAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('+${_gate.xpReward} XP Awarded! Relic Unlocked: ${_gate.relicDrop}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 12)),
                  const SizedBox(height: 10),
                  FilledButton(
                    onPressed: () => context.push('/home/stats/vault'),
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFFD700)),
                    child: const Text('OPEN MONARCH\'S VAULT', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),

          // ── SQUAD DAMAGE LEADERBOARD ──
          const Text(
            'Party Strike Contributions',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              children: [
                _buildSquadRow(user?.displayName ?? 'You (Hunter)', _userDamageDealt, true),
                const Divider(color: Colors.white10, height: 16),
                _buildSquadRow('Alex (Raid Member)', 65, false),
                const Divider(color: Colors.white10, height: 16),
                _buildSquadRow('Sarah (Raid Member)', 40, false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSquadRow(String name, int damage, bool isUser) {
    return Row(
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: isUser ? const Color(0xFF38BDF8) : Colors.white24,
          child: Text(name[0], style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            name,
            style: TextStyle(
              color: isUser ? const Color(0xFF38BDF8) : Colors.white,
              fontWeight: isUser ? FontWeight.w900 : FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
        Text(
          '$damage DMG',
          style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12),
        ),
      ],
    );
  }
}
