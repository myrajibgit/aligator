import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studycompete/features/auth/providers/auth_provider.dart';
import 'package:studycompete/shared/utils/hunter_rank.dart';

// -----------------------------------------------------------------------------
// SOLO INFINITE TRIAL — Hunter Wave Combat
//
// WHY THIS EXISTS: Standard quiz missions are capped at 5 questions.
// The Infinite Trial gives top hunters an endless gauntlet — a "survival mode"
// where each consecutive correct answer builds a combo multiplier and XP
// multiplies geometrically. One wrong answer collapses the run. This creates
// real tension and reward asymmetry, the core driver of "just one more" habit.
// -----------------------------------------------------------------------------

const _kTimerSeconds = 20;
const _kXpPerCorrect = 15;

class _TrialQuestion {
  final String text;
  final List<String> options;
  /// Index into [options] that is the correct answer (before any shuffling).
  final int correct;
  final String subject;
  const _TrialQuestion({
    required this.text,
    required this.options,
    required this.correct,
    required this.subject,
  });
}

/// Runtime wrapper that holds one question with its options randomly
/// permuted. Tracks the shuffled index of the correct answer so
/// the comparison in [_onAnswer] stays valid each run.
class _ShuffledQuestion {
  final String text;
  final String subject;
  final List<String> options; // shuffled copy
  final int correctIndex;     // index into the shuffled [options]

  _ShuffledQuestion({
    required this.text,
    required this.subject,
    required this.options,
    required this.correctIndex,
  });

  int get correct => correctIndex;

  factory _ShuffledQuestion.from(_TrialQuestion q) {
    final rng = Random();
    // Build an indexed list so we can track where correct goes
    final indexed = List.generate(q.options.length, (i) => MapEntry(i, q.options[i]));
    indexed.shuffle(rng);
    final newOptions = indexed.map((e) => e.value).toList();
    final newCorrect = indexed.indexWhere((e) => e.key == q.correct);
    return _ShuffledQuestion(
      text: q.text,
      subject: q.subject,
      options: newOptions,
      correctIndex: newCorrect,
    );
  }
}

final List<_TrialQuestion> _localBank = [
  // MATHEMATICS — correct indices reflect the right option position in the options list
  _TrialQuestion(text: 'What is the derivative of sin(x)?', options: ['cos(x)', '-cos(x)', 'tan(x)', '-sin(x)'], correct: 0, subject: 'Mathematics'),
  _TrialQuestion(text: 'Solve: ∫ 2x dx', options: ['2 + C', 'x + C', '2x² + C', 'x² + C'], correct: 3, subject: 'Mathematics'),
  _TrialQuestion(text: 'If f(x) = x³ - 3x, find f\'(2)', options: ['3', '12', '9', '6'], correct: 2, subject: 'Mathematics'),
  _TrialQuestion(text: 'Sum of interior angles of a hexagon?', options: ['360°', '900°', '540°', '720°'], correct: 3, subject: 'Mathematics'),
  _TrialQuestion(text: 'What is log₁₀(1000)?', options: ['100', '10', '1000', '3'], correct: 3, subject: 'Mathematics'),
  _TrialQuestion(text: 'Solve: 2x + 5 = 17', options: ['x = 5', 'x = 7', 'x = 11', 'x = 6'], correct: 3, subject: 'Mathematics'),
  _TrialQuestion(text: 'Quadratic formula denominator?', options: ['a', 'b', '2b', '2a'], correct: 3, subject: 'Mathematics'),
  _TrialQuestion(text: 'How many edges does a cube have?', options: ['6', '16', '8', '12'], correct: 3, subject: 'Mathematics'),
  _TrialQuestion(text: 'What is 5! (5 factorial)?', options: ['24', '100', '60', '120'], correct: 3, subject: 'Mathematics'),
  _TrialQuestion(text: 'The value of sin(90°) is:', options: ['-1', '√2/2', '0', '1'], correct: 3, subject: 'Mathematics'),
  _TrialQuestion(text: 'What is the value of π (pi) to 2 decimal places?', options: ['3.41', '3.14', '3.41', '3.24'], correct: 1, subject: 'Mathematics'),
  _TrialQuestion(text: 'How many sides does a pentagon have?', options: ['4', '6', '5', '7'], correct: 2, subject: 'Mathematics'),
  // PHYSICS
  _TrialQuestion(text: 'Newton\'s 2nd law: F = m × ?', options: ['v', 'g', 'd', 'a'], correct: 3, subject: 'Physics'),
  _TrialQuestion(text: 'SI unit of electric charge?', options: ['Ohm', 'Volt', 'Ampere', 'Coulomb'], correct: 3, subject: 'Physics'),
  _TrialQuestion(text: 'Speed of light in vacuum?', options: ['9×10⁸ m/s', '3×10¹° m/s', '3×10⁶ m/s', '3×10⁸ m/s'], correct: 3, subject: 'Physics'),
  _TrialQuestion(text: 'Law: energy cannot be created or destroyed?', options: ['Archimedes', 'Ohm\'s Law', 'Newton\'s 1st Law', 'Conservation of Energy'], correct: 3, subject: 'Physics'),
  _TrialQuestion(text: 'Sound is what type of wave?', options: ['Electromagnetic', 'Surface', 'Transverse', 'Longitudinal'], correct: 3, subject: 'Physics'),
  _TrialQuestion(text: 'Work done is measured in:', options: ['Pascals', 'Newtons', 'Watts', 'Joules'], correct: 3, subject: 'Physics'),
  _TrialQuestion(text: 'Formula for gravitational potential energy?', options: ['½mv²', 'F×d', 'mv', 'mgh'], correct: 3, subject: 'Physics'),
  _TrialQuestion(text: 'Which colour has the highest frequency?', options: ['Red', 'Yellow', 'Green', 'Violet'], correct: 3, subject: 'Physics'),
  _TrialQuestion(text: 'Unit of electric resistance?', options: ['Ampere', 'Volt', 'Watt', 'Ohm'], correct: 3, subject: 'Physics'),
  // CHEMISTRY
  _TrialQuestion(text: 'Atomic number of Carbon?', options: ['12', '8', '4', '6'], correct: 3, subject: 'Chemistry'),
  _TrialQuestion(text: 'H₂O is the formula for:', options: ['Hydro Acid', 'Oxygen', 'Hydrogen Peroxide', 'Water'], correct: 3, subject: 'Chemistry'),
  _TrialQuestion(text: 'pH of a neutral solution?', options: ['0', '14', '1', '7'], correct: 3, subject: 'Chemistry'),
  _TrialQuestion(text: 'Element with symbol Na?', options: ['Neon', 'Nickel', 'Nitrogen', 'Sodium'], correct: 3, subject: 'Chemistry'),
  _TrialQuestion(text: 'Avogadro\'s number is approximately:', options: ['9.8 × 10⁸', '6.022 × 10¹°', '3.14 × 10¹°', '6.022 × 10²³'], correct: 3, subject: 'Chemistry'),
  _TrialQuestion(text: 'Bond involving electron sharing?', options: ['Hydrogen', 'Metallic', 'Ionic', 'Covalent'], correct: 3, subject: 'Chemistry'),
  // BIOLOGY
  _TrialQuestion(text: 'Powerhouse of the cell?', options: ['Vacuole', 'Ribosome', 'Nucleus', 'Mitochondria'], correct: 3, subject: 'Biology'),
  _TrialQuestion(text: 'DNA stands for?', options: ['Double Nucleic Acid', 'Deoxyribose Nucleus Amino', 'Dinitrogen Acid', 'Deoxyribonucleic Acid'], correct: 3, subject: 'Biology'),
  _TrialQuestion(text: 'Organelle for protein synthesis?', options: ['Vacuole', 'Mitochondria', 'Golgi body', 'Ribosome'], correct: 3, subject: 'Biology'),
  _TrialQuestion(text: 'Chambers in the human heart?', options: ['6', '3', '2', '4'], correct: 3, subject: 'Biology'),
  _TrialQuestion(text: 'Photosynthesis primarily occurs in the:', options: ['Ribosome', 'Nucleus', 'Mitochondria', 'Chloroplast'], correct: 3, subject: 'Biology'),
  _TrialQuestion(text: 'Basic unit of life?', options: ['Organ', 'Tissue', 'Atom', 'Cell'], correct: 3, subject: 'Biology'),
  _TrialQuestion(text: 'How many bones in the adult human body?', options: ['300', '214', '186', '206'], correct: 3, subject: 'Biology'),
];

class InfiniteTrialScreen extends ConsumerStatefulWidget {
  const InfiniteTrialScreen({super.key});

  @override
  ConsumerState<InfiniteTrialScreen> createState() => _InfiniteTrialScreenState();
}

class _InfiniteTrialScreenState extends ConsumerState<InfiniteTrialScreen>
    with TickerProviderStateMixin {
  late List<_ShuffledQuestion> _shuffled;
  int _wave = 0;
  int _combo = 0;
  int _totalXp = 0;
  int _highScore = 0;
  bool _gameOver = false;
  bool _correct = false;
  int? _selectedIndex;
  bool _answered = false;
  int _secondsLeft = _kTimerSeconds;
  Timer? _timer;

  late AnimationController _pulseCtrl;
  late AnimationController _slideCtrl;
  late Animation<Offset> _slideAnim;
  late AnimationController _comboCtrl;
  late Animation<double> _comboScale;
  late AnimationController _flashCtrl;
  late Animation<Color?> _flashColor;

  static const Map<String, Color> _subjectColors = {
    'Mathematics': Color(0xFF38BDF8),
    'Physics': Color(0xFFFBBF24),
    'Chemistry': Color(0xFF34D399),
    'Biology': Color(0xFFA78BFA),
  };

  @override
  void initState() {
    super.initState();
    // Shuffle question order AND randomise each question's option positions
    // so the correct answer index varies each run (prevents pattern memorisation).
    _shuffled = (List.from(_localBank)..shuffle(Random()))
        .map((q) => _ShuffledQuestion.from(q as _TrialQuestion))
        .toList();

    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);

    _slideCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _slideAnim = Tween<Offset>(begin: const Offset(0.12, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));

    _comboCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _comboScale = Tween<double>(begin: 1.0, end: 1.5)
        .animate(CurvedAnimation(parent: _comboCtrl, curve: Curves.elasticOut));

    _flashCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _flashColor = ColorTween(
      begin: Colors.transparent,
      end: Colors.greenAccent.withOpacity(0.08),
    ).animate(_flashCtrl);

    _startTimer();
    _slideCtrl.forward();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseCtrl.dispose();
    _slideCtrl.dispose();
    _comboCtrl.dispose();
    _flashCtrl.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _secondsLeft = _kTimerSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) {
        t.cancel();
        _handleTimeout();
      }
    });
  }

  void _handleTimeout() {
    if (_answered) return;
    setState(() { _answered = true; _correct = false; });
    Future.delayed(const Duration(milliseconds: 1200), _triggerGameOver);
  }

  void _onAnswer(int index) {
    if (_answered || _gameOver) return;
    _timer?.cancel();
    final q = _shuffled[_wave % _shuffled.length];
    final isCorrect = index == q.correctIndex;
    setState(() { _selectedIndex = index; _answered = true; _correct = isCorrect; });
    if (isCorrect) {
      _combo++;
      _totalXp += (_kXpPerCorrect * _comboMultiplier).round();
      if (_combo > _highScore) _highScore = _combo;
      _comboCtrl.forward(from: 0);
      _flashCtrl.forward(from: 0);
      Future.delayed(const Duration(milliseconds: 900), _nextWave);
    } else {
      Future.delayed(const Duration(milliseconds: 1200), _triggerGameOver);
    }
  }

  void _nextWave() {
    if (!mounted) return;
    setState(() { _wave++; _answered = false; _selectedIndex = null; });
    _slideCtrl.forward(from: 0);
    _startTimer();
  }

  void _triggerGameOver() {
    if (!mounted) return;
    setState(() => _gameOver = true);
  }

  double get _comboMultiplier {
    if (_combo >= 20) return 4.0;
    if (_combo >= 15) return 3.0;
    if (_combo >= 10) return 2.5;
    if (_combo >= 7)  return 2.0;
    if (_combo >= 5)  return 1.5;
    if (_combo >= 3)  return 1.25;
    return 1.0;
  }

  String get _comboLabel {
    if (_combo >= 20) return 'MONARCH SLAUGHTER';
    if (_combo >= 15) return 'S-CLASS DOMINANCE';
    if (_combo >= 10) return 'UNSTOPPABLE';
    if (_combo >= 7)  return 'CRITICAL COMBO';
    if (_combo >= 5)  return 'COMBO RISING';
    if (_combo >= 3)  return 'ON FIRE';
    return 'STRIKE';
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProfileProvider).value;
    final level = user != null ? (user.xp ~/ 200) + 1 : 1;
    final rankInfo = HunterRankUtils.getRankInfo(level);

    if (_gameOver) return _buildGameOver(rankInfo);

    final q = _shuffled[_wave % _shuffled.length];
    final subjectColor = _subjectColors[q.subject] ?? const Color(0xFF38BDF8);
    final timerFrac = _secondsLeft / _kTimerSeconds;

    return Scaffold(
      backgroundColor: const Color(0xFF060B14),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _flashColor,
          builder: (context, child) => Container(color: _flashColor.value, child: child),
          child: Column(
            children: [
              _buildTopHud(rankInfo, subjectColor, timerFrac),
              if (_combo >= 3) _buildComboBanner(rankInfo),
              const SizedBox(height: 8),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SlideTransition(
                    position: _slideAnim,
                    child: _buildQuestionCard(q, subjectColor),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComboBanner(HunterRankInfo rankInfo) {
    return AnimatedBuilder(
      animation: _comboScale,
      builder: (_, __) => Transform.scale(
        scale: _comboScale.value,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [rankInfo.color.withOpacity(0.3), Colors.transparent]),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: rankInfo.color.withOpacity(0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$_combo× COMBO', style: TextStyle(color: rankInfo.color, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.2)),
              const SizedBox(width: 8),
              Text(_comboLabel, style: const TextStyle(color: Colors.white70, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopHud(HunterRankInfo rankInfo, Color subjectColor, double timerFrac) {
    final isWarning = _secondsLeft <= 7;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        border: Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(onTap: () => Navigator.of(context).pop(), child: const Icon(Icons.close, color: Colors.white54, size: 22)),
              const SizedBox(width: 12),
              const Text('INFINITE TRIAL', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.5)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: rankInfo.color.withOpacity(0.12), borderRadius: BorderRadius.circular(20), border: Border.all(color: rankInfo.color.withOpacity(0.3))),
                child: Text('+$_totalXp XP', style: TextStyle(color: rankInfo.color, fontWeight: FontWeight.w900, fontSize: 12)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(20)),
                child: Text('WAVE $_wave', style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              AnimatedBuilder(
                animation: _pulseCtrl,
                builder: (_, __) => Icon(Icons.timer_outlined, size: 14, color: isWarning ? Color.lerp(Colors.red, Colors.orange, _pulseCtrl.value)! : Colors.white38),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(value: timerFrac, minHeight: 6, backgroundColor: Colors.white10, valueColor: AlwaysStoppedAnimation<Color>(isWarning ? Colors.redAccent : subjectColor)),
                ),
              ),
              const SizedBox(width: 8),
              Text('${_secondsLeft}s', style: TextStyle(fontSize: 11, color: isWarning ? Colors.redAccent : Colors.white38, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(_ShuffledQuestion q, Color subjectColor) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(color: subjectColor.withOpacity(0.12), borderRadius: BorderRadius.circular(20), border: Border.all(color: subjectColor.withOpacity(0.3))),
            child: Text(q.subject.toUpperCase(), style: TextStyle(color: subjectColor, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.2)),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(20), border: Border.all(color: subjectColor.withOpacity(0.2))),
            child: Text(q.text, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700, height: 1.4)),
          ),
          const SizedBox(height: 20),
          if (_comboMultiplier > 1.0)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('${_comboMultiplier}× XP MULTIPLIER ACTIVE', style: TextStyle(color: subjectColor, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.0)),
            ),
          ...List.generate(q.options.length, (i) => _buildOptionTile(q, i, subjectColor)),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildOptionTile(_ShuffledQuestion q, int i, Color subjectColor) {
    Color borderColor = Colors.white12;
    Color bgColor = const Color(0xFF0F172A);
    Color textColor = Colors.white70;
    IconData? trailingIcon;
    if (_answered) {
      if (i == q.correctIndex) {
        borderColor = Colors.greenAccent; bgColor = Colors.greenAccent.withOpacity(0.1); textColor = Colors.greenAccent; trailingIcon = Icons.check_circle_rounded;
      } else if (i == _selectedIndex && !_correct) {
        borderColor = Colors.redAccent; bgColor = Colors.redAccent.withOpacity(0.1); textColor = Colors.redAccent; trailingIcon = Icons.cancel_rounded;
      }
    }
    return GestureDetector(
      onTap: () => _onAnswer(i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: (_selectedIndex == i && !_answered) ? subjectColor : borderColor, width: 1.4),
        ),
        child: Row(
          children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (_answered && i == q.correct) ? Colors.greenAccent.withOpacity(0.15) : subjectColor.withOpacity(0.08),
                border: Border.all(color: (_answered && i == q.correct) ? Colors.greenAccent : subjectColor.withOpacity(0.3)),
              ),
              child: Center(child: Text(String.fromCharCode(65 + i), style: TextStyle(color: (_answered && i == q.correct) ? Colors.greenAccent : subjectColor, fontWeight: FontWeight.w900, fontSize: 12))),
            ),
            const SizedBox(width: 14),
            Expanded(child: Text(q.options[i], style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w500))),
            if (trailingIcon != null) Icon(trailingIcon, color: i == q.correct ? Colors.greenAccent : Colors.redAccent, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildGameOver(HunterRankInfo rankInfo) {
    final isElite = _combo >= 10;
    final isMid = _combo >= 5;
    return Scaffold(
      backgroundColor: const Color(0xFF060B14),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 96, height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: isElite ? [const Color(0xFFFFD700), const Color(0xFFFFA000)]
                          : isMid ? [const Color(0xFFA855F7), const Color(0xFF6D28D9)]
                          : [const Color(0xFF475569), const Color(0xFF1E293B)],
                    ),
                    boxShadow: [BoxShadow(color: (isElite ? const Color(0xFFFFD700) : isMid ? const Color(0xFFA855F7) : Colors.white30).withOpacity(0.4), blurRadius: 30, spreadRadius: 4)],
                  ),
                  child: Center(child: Text(isElite ? '??' : isMid ? '??' : '??', style: const TextStyle(fontSize: 44))),
                ),
                const SizedBox(height: 24),
                Text(
                  isElite ? 'MONARCH-TIER PERFORMANCE' : isMid ? 'HUNTER DEFEATED' : 'GATES COLLAPSED',
                  style: TextStyle(color: isElite ? const Color(0xFFFFD700) : isMid ? const Color(0xFFA855F7) : Colors.white38, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 2),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  isElite ? '"Only the worthy stand where others fall."' : '"Rise again, hunter. The gates do not wait."',
                  style: const TextStyle(color: Colors.white38, fontSize: 12, fontStyle: FontStyle.italic),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(20), border: Border.all(color: rankInfo.color.withOpacity(0.3))),
                  child: Column(
                    children: [
                      Text('TRIAL DEBRIEF', style: TextStyle(color: rankInfo.color, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.5)),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _ResultStat(label: 'WAVES CLEARED', value: '$_combo', icon: Icons.waves),
                          const SizedBox(width: 12),
                          _ResultStat(label: 'XP EARNED', value: '+$_totalXp', icon: Icons.auto_awesome, color: rankInfo.color),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _ResultStat(label: 'BEST COMBO', value: 'x$_highScore', icon: Icons.local_fire_department, color: Colors.orangeAccent),
                          const SizedBox(width: 12),
                          _ResultStat(label: 'MULTIPLIER', value: '${_comboMultiplier}x', icon: Icons.bolt, color: Colors.purpleAccent),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _shuffled = List.from(_localBank)..shuffle(Random());
                        _wave = 0; _combo = 0; _totalXp = 0; _highScore = 0;
                        _gameOver = false; _answered = false; _selectedIndex = null;
                      });
                      _slideCtrl.forward(from: 0);
                      _startTimer();
                    },
                    icon: const Icon(Icons.replay),
                    label: const Text('ENTER GATES AGAIN', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                    style: ElevatedButton.styleFrom(backgroundColor: rankInfo.color, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Return to Missions', style: TextStyle(color: Colors.white38))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _ResultStat({required this.label, required this.value, required this.icon, this.color = Colors.white54});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(color: color.withOpacity(0.07), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withOpacity(0.18))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 22)),
            Text(label, style: const TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
          ],
        ),
      ),
    );
  }
}

