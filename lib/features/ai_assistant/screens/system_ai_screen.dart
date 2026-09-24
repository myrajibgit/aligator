import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studycompete/features/auth/providers/auth_provider.dart';
import 'package:studycompete/shared/utils/haptic_feedback_utils.dart';
import 'package:studycompete/shared/utils/hunter_rank.dart';
import 'package:studycompete/shared/widgets/notification_bell.dart';

class SystemAiMessage {
  final String text;
  final bool isSystem;
  final DateTime timestamp;

  SystemAiMessage({
    required this.text,
    required this.isSystem,
    required this.timestamp,
  });
}

class SystemAiScreen extends ConsumerStatefulWidget {
  const SystemAiScreen({super.key});

  @override
  ConsumerState<SystemAiScreen> createState() => _SystemAiScreenState();
}

class _SystemAiScreenState extends ConsumerState<SystemAiScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<SystemAiMessage> _messages = [];
  bool _isTyping = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  static const List<String> _quickPrompts = [
    '💡 Explain Calculus derivatives',
    "⚡ Summarize Newton's 3 Laws",
    '🧬 How does DNA replicate?',
    '⏱️ Optimal Pomodoro focus strategy',
    '👑 How do I ascend to S-Rank?',
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Initial System Message
    _messages.add(
      SystemAiMessage(
        text: '[SYSTEM INITIALIZED // NEURAL LINK STABLE]\n\n'
            'Greetings, Hunter. The System Architect is online. Biometrics, academic IQ, and daily streak parameters are synchronized.\n\n'
            'Select a diagnostic protocol or input any STEM, study technique, or ascension query below.',
        isSystem: true,
        timestamp: DateTime.now(),
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleProtocol(String query, String protocolType) {
    setState(() {
      _messages.add(
        SystemAiMessage(text: query, isSystem: false, timestamp: DateTime.now()),
      );
      _isTyping = true;
    });
    _scrollToBottom();
    HapticFeedbackUtils.selectionClick();

    final user = ref.read(currentUserProfileProvider).value;
    final level = user != null ? (user.xp ~/ 200) + 1 : 1;
    final rank = HunterRankUtils.getRankInfo(level);
    final derived = user != null
        ? HunterRankUtils.calculateDerivedStats(user)
        : const DerivedRpgStats(
            intelligence: 20, sense: 20, strength: 20, vitality: 16, agility: 24, fatigue: 0);

    String responseText = '';

    if (protocolType == 'STATS') {
      responseText =
          'DIAGNOSTIC REPORT for Hunter ${user?.displayName ?? "Player"}:\n'
          '• Current Rank: ${rank.name} (${rank.title})\n'
          '• Intelligence (INT): ${derived.intelligence.toStringAsFixed(1)} / 100\n'
          '• Sense / Focus (SEN): ${derived.sense.toStringAsFixed(1)} / 100\n'
          '• Physical Strength (STR): ${derived.strength.toStringAsFixed(1)} / 100\n'
          '• Fatigue Level: ${derived.fatigue}%\n\n'
          'ANALYSIS: Your ${derived.intelligence > derived.strength ? "academic IQ leads physical training" : "physical stats are peaking"}. Maintain consistency across subject quizzes to sustain attribute balance.';
    } else if (protocolType == 'TRAINING') {
      responseText =
          'OPTIMAL DAILY PROTOCOL ASSIGNMENT:\n'
          '1. Complete 2 Daily Subject Quizzes (Minimum 60% accuracy required for Knowledge Power).\n'
          '2. Finish the 30-min Fitness / Rep Protocol (Push-ups, Squats, or Cardio) to earn +30 XP and boost Strength.\n'
          '3. Review notes via AI Study Verification to expand Grimoire Mastery.\n'
          '• Estimated XP Yield: +180 XP (Guarantees Daily Goal streak completion).';
    } else if (protocolType == 'BATTLE') {
      responseText =
          'TACTICAL DUEL ALGORITHM:\n'
          'Stat duels resolve across 3 rounds:\n'
          '• Round 1 (Subject Duel): Win probability scales with Subject XP vs opponent.\n'
          '• Round 2 (IQ Clash): Quiz accuracy dictates precision variance (±5%).\n'
          '• Round 3 (Knowledge Power): Raw cumulative power clash.\n'
          'TACTIC: Challenge peers whose Battle IQ is within ±5 points of yours to maximize win equity without risk.';
    } else if (protocolType == 'FATIGUE') {
      responseText =
          'FATIGUE & PENALTY COUNTERMEASURE:\n'
          'Current Fatigue: ${derived.fatigue}%\n'
          '• If fatigue reaches 70%+, XP gain from missions decreases by up to 50%.\n'
          '• RECOVERY METHODS:\n'
          '  1. Leveling up instantly purges fatigue to 0%.\n'
          '  2. Completing daily fitness sessions promotes natural recovery.\n'
          '  3. Maintain streak continuity: 7+ day streak grants permanent peak condition immunity.\n'
          '  4. Equip "Kasaka\'s Venom Dagger" in your Vault to suppress fatigue accumulation.';
    } else if (protocolType == 'ASCENSION') {
      final nextLevelTarget = level < 10
          ? 10
          : (level < 20
              ? 20
              : (level < 30
                  ? 30
                  : (level < 40
                      ? 40
                      : (level < 50 ? 50 : 100))));
      final nextRank = HunterRankUtils.getRankInfo(nextLevelTarget);

      responseText =
          'ASCENSION BLUEPRINT:\n'
          '• Target: ${nextRank.name} (${nextRank.title})\n'
          '• Required Level: Level $nextLevelTarget (Currently Level $level)\n'
          '• Levels Remaining: ${nextLevelTarget - level}\n'
          '• XP Needed: ${(nextLevelTarget - level) * 200} XP\n'
          'Upon reaching Level $nextLevelTarget, the System will trigger an automated Ascension Ceremony and unlock higher tier duel visibility.';
    }

    Future.delayed(const Duration(milliseconds: 650), () {
      if (!mounted) return;
      setState(() {
        _messages.add(
          SystemAiMessage(text: responseText, isSystem: true, timestamp: DateTime.now()),
        );
        _isTyping = false;
      });
      _scrollToBottom();
      HapticFeedbackUtils.mediumImpact();
    });
  }

  Future<void> _handleCustomQuery(String query) async {
    final text = query.trim();
    if (text.isEmpty) return;
    _inputController.clear();

    setState(() {
      _messages.add(
        SystemAiMessage(text: text, isSystem: false, timestamp: DateTime.now()),
      );
      _isTyping = true;
    });
    _scrollToBottom();
    HapticFeedbackUtils.selectionClick();

    final user = ref.read(currentUserProfileProvider).value;
    final level = user != null ? (user.xp ~/ 200) + 1 : 1;
    final rank = HunterRankUtils.getRankInfo(level);
    final derived = user != null
        ? HunterRankUtils.calculateDerivedStats(user)
        : const DerivedRpgStats(
            intelligence: 20, sense: 20, strength: 20, vitality: 16, agility: 24, fatigue: 0);

    String responseText = '';

    try {
      final callable = FirebaseFunctions.instance.httpsCallable('askSystemAi');
      final res = await callable.call({
        'query': text,
        'hunterContext': {
          'rank': rank.name,
          'level': level,
          'intelligence': derived.intelligence,
          'fatigue': derived.fatigue,
          'streak': user?.stats.streak ?? 0,
          'displayName': user?.displayName ?? 'Hunter',
        },
      }).timeout(const Duration(seconds: 12));

      final data = res.data as Map?;
      responseText = data?['reply'] as String? ?? '';
    } catch (_) {
      // Graceful local heuristic engine
      responseText = _generateLocalHeuristicReply(text, user?.displayName ?? 'Hunter', rank.name, level);
    }

    if (!mounted) return;
    setState(() {
      _messages.add(
        SystemAiMessage(text: responseText, isSystem: true, timestamp: DateTime.now()),
      );
      _isTyping = false;
    });
    _scrollToBottom();
    HapticFeedbackUtils.questComplete();
  }

  String _generateLocalHeuristicReply(String query, String name, String rank, int level) {
    final q = query.toLowerCase();

    if (q.contains('derivative') || q.contains('calculus') || q.contains('integral') || q.contains('math')) {
      return '[SYSTEM COGNITIVE ANALYSIS // MATHEMATICS PROTOCOL]\n\n'
          '• Calculus Core Principle: The derivative d/dx[f(x)] represents the instantaneous rate of change (tangent slope).\n'
          '• Primary Differentiation Rules:\n'
          '  - Power Rule: d/dx(xⁿ) = n·xⁿ⁻¹\n'
          '  - Product Rule: (u·v)\' = u\'v + uv\'\n'
          '  - Chain Rule: d/dx[f(g(x))] = f\'(g(x))·g\'(x)\n\n'
          '[TACTICAL DIRECTIVE]: Clear the C-Rank Math Labyrinth Dungeon Gate to hone your analytical reflexes.';
    }

    if (q.contains('newton') || q.contains('physics') || q.contains('force') || q.contains('velocity') || q.contains('energy')) {
      return '[SYSTEM COGNITIVE ANALYSIS // PHYSICS DYNAMICS]\n\n'
          '• Newton\'s 3 Laws of Motion:\n'
          '  1. Inertia: An object remains at rest or in uniform straight-line motion unless compelled by a net force.\n'
          '  2. Acceleration: F = m·a (Force equals mass times acceleration).\n'
          '  3. Reciprocity: Every action has an equal and opposite reaction (F_AB = -F_BA).\n\n'
          '[TACTICAL DIRECTIVE]: Kinematics mastery elevates your Sense (SEN) and Agility (AGI) RPG attributes.';
    }

    if (q.contains('dna') || q.contains('cell') || q.contains('biology') || q.contains('mitochondria') || q.contains('mitosis')) {
      return '[SYSTEM COGNITIVE ANALYSIS // CELLULAR BIOLOGY]\n\n'
          '• Mitochondria: Synthesizes ATP via cellular respiration and proton gradients.\n'
          '• DNA Replication: Helicase unwinds the double helix while DNA Polymerase synthesizes complementary daughter strands.\n'
          '• Mitosis Phases: Prophase → Metaphase → Anaphase → Telophase.\n\n'
          '[TACTICAL DIRECTIVE]: Upload notes to AI Study Verification to claim grimoire mastery XP.';
    }

    if (q.contains('pomodoro') || q.contains('study') || q.contains('focus') || q.contains('exam')) {
      return '[SYSTEM PROTOCOL // DEEP FOCUS STRATEGY]\n\n'
          '1. Activate a 25-minute Pomodoro protocol with zero distractions.\n'
          '2. Employ Active Recall: Close study materials and reconstruct key formulas from memory.\n'
          '3. Equip "Orb of Avarice" in your Monarch\'s Vault to earn +30% bonus Focus XP.\n\n'
          '[TACTICAL DIRECTIVE]: Complete 2 deep focus blocks daily to reinforce academic endurance.';
    }

    if (q.contains('rank') || q.contains('level') || q.contains('ascend') || q.contains('monarch')) {
      return '[SYSTEM STATUS REPORT // ASCENSION BLUEPRINT]\n\n'
          'Hunter $name, your current rank is $rank (Level $level).\n'
          '• Progression: Each level requires 200 XP.\n'
          '• Awakening Streaks multiply mission XP up to 2.0x.\n'
          '• S-Rank is reached upon conquering High-Tier Dungeon Gates and mastering all core subjects.';
    }

    return '[SYSTEM COGNITION QUERY RESOLVED]\n\n'
        'Inquiry: "$query"\n\n'
        'The System has registered your inquiry. To maximize retention and stat gains, maintain balance between STEM practice quizzes, physical stamina reps, and deep focus sessions. The path to sovereignty is forged daily.';
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProfileProvider).value;
    final uid = ref.watch(currentUserProvider)?.uid ?? '';
    final level = user != null ? (user.xp ~/ 200) + 1 : 1;
    final rank = HunterRankUtils.getRankInfo(level);
    final derived = user != null
        ? HunterRankUtils.calculateDerivedStats(user)
        : const DerivedRpgStats(
            intelligence: 20, sense: 20, strength: 20, vitality: 16, agility: 24, fatigue: 0);

    return Scaffold(
      backgroundColor: const Color(0xFF020617), // Solo Leveling Abyss Dark
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1329),
        elevation: 0,
        title: Row(
          children: [
            ScaleTransition(
              scale: _pulseAnim,
              child: Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF38BDF8),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFF38BDF8),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'SYSTEM A.I. CORE',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                fontSize: 16,
              ),
            ),
          ],
        ),
        actions: [
          NotificationBell(uid: uid),
        ],
      ),
      body: Column(
        children: [
          // ── SYSTEM HUD STATUS BAR ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF0B1329),
              border: Border(bottom: BorderSide(color: Color(0xFF1E293B))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildHudChip('RANK', rank.name, rank.color),
                _buildHudChip('LEVEL', 'LVL $level', const Color(0xFF38BDF8)),
                _buildHudChip('INT', derived.intelligence.toStringAsFixed(0), const Color(0xFF0EA5E9)),
                _buildHudChip('FATIGUE', '${derived.fatigue}%', derived.fatigue > 50 ? Colors.redAccent : Colors.greenAccent),
                _buildHudChip('STATUS', 'OPTIMAL', const Color(0xFF22C55E)),
              ],
            ),
          ),

          // ── QUICK PROTOCOL SHORTCUTS ───────────────────────────────────────
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            color: const Color(0xFF080E1E),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildProtocolChip('📊 STATS', 'Run diagnostic scan on my stats', 'STATS'),
                _buildProtocolChip('⚔️ TRAINING', 'What is my optimal study routine today?', 'TRAINING'),
                _buildProtocolChip('🛡️ DUEL IQ', 'How do I win Stat Battles in the Arena?', 'BATTLE'),
                _buildProtocolChip('⚡ FATIGUE', 'How do I purge fatigue?', 'FATIGUE'),
                _buildProtocolChip('👑 ASCENSION', 'How do I reach the next rank?', 'ASCENSION'),
              ],
            ),
          ),

          // ── CONVERSATION STREAM ───────────────────────────────────────────
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return _buildMessageBubble(msg);
              },
            ),
          ),

          // ── TYPING INDICATOR ──────────────────────────────────────────────
          if (_isTyping)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF38BDF8)),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '[SYSTEM COGNITION ENGINE ACTIVE...]',
                    style: TextStyle(
                      color: const Color(0xFF38BDF8).withOpacity(0.8),
                      fontSize: 11,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
              ),
            ),

          // ── QUICK SUGGESTION CHIPS ─────────────────────────────────────────
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _quickPrompts.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final prompt = _quickPrompts[index];
                return ActionChip(
                  padding: EdgeInsets.zero,
                  backgroundColor: const Color(0xFF0F172A),
                  side: const BorderSide(color: Color(0xFF334155), width: 0.8),
                  label: Text(
                    prompt,
                    style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600),
                  ),
                  onPressed: () => _handleCustomQuery(prompt),
                );
              },
            ),
          ),

          // ── QUERY INPUT BAR ───────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            decoration: const BoxDecoration(
              color: Color(0xFF0B1329),
              border: Border(top: BorderSide(color: Color(0xFF1E293B))),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Input query to The System...',
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 13),
                        filled: true,
                        fillColor: const Color(0xFF020617),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFF334155)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFF334155)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFF38BDF8)),
                        ),
                      ),
                      onSubmitted: (text) => _handleCustomQuery(text),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: () => _handleCustomQuery(_inputController.text),
                    icon: const Icon(Icons.send_rounded, size: 18),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF38BDF8),
                      foregroundColor: Colors.black,
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

  Widget _buildHudChip(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white38, fontSize: 8, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }

  Widget _buildProtocolChip(String title, String query, String protocolType) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ActionChip(
        backgroundColor: const Color(0xFF1E293B),
        side: const BorderSide(color: Color(0xFF38BDF8), width: 0.7),
        label: Text(
          title,
          style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.bold),
        ),
        onPressed: () => _handleProtocol(query, protocolType),
      ),
    );
  }

  Widget _buildMessageBubble(SystemAiMessage msg) {
    if (msg.isSystem) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.4)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF38BDF8).withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.memory, color: Color(0xFF38BDF8), size: 16),
                SizedBox(width: 8),
                Text(
                  'SYSTEM A.I. HOLOGRAM',
                  style: TextStyle(
                    color: Color(0xFF38BDF8),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              msg.text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      );
    } else {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white24),
          ),
          child: Text(
            msg.text,
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ),
      );
    }
  }
}
