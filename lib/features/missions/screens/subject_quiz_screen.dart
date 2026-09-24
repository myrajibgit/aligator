import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:studycompete/features/auth/providers/auth_provider.dart';
import 'package:studycompete/shared/theme/app_theme.dart';
import '../providers/missions_provider.dart';
import '../models/question_model.dart';

/// Seconds per question for the countdown timer.
const _kSecondsPerQuestion = 30;

class SubjectQuizScreen extends ConsumerStatefulWidget {
  final String subjectId;
  final String subjectName;
  final String uid;

  const SubjectQuizScreen({
    Key? key,
    required this.subjectId,
    required this.subjectName,
    required this.uid,
  }) : super(key: key);

  @override
  ConsumerState<SubjectQuizScreen> createState() => _SubjectQuizScreenState();
}

class _SubjectQuizScreenState extends ConsumerState<SubjectQuizScreen>
    with SingleTickerProviderStateMixin {
  List<Question>? _questions;
  int _currentIndex = 0;
  List<int> _answers = [];
  bool _isFinished = false;
  double? _score;
  bool _isLoading = true;
  bool _isSubmitting = false;

  // Timer
  int _secondsLeft = _kSecondsPerQuestion;
  Timer? _timer;

  // Animation
  late AnimationController _cardAnimCtrl;
  late Animation<Offset> _cardSlide;
  late Animation<double> _cardFade;

  @override
  void initState() {
    super.initState();
    _cardAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _cardSlide = Tween<Offset>(
      begin: const Offset(0.08, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _cardAnimCtrl, curve: Curves.easeOutCubic));
    _cardFade = CurvedAnimation(parent: _cardAnimCtrl, curve: Curves.easeOut);

    _loadQuestions();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cardAnimCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadQuestions() async {
    final questions = await ref
        .read(missionsNotifierProvider.notifier)
        .startSubjectQuiz(widget.subjectId);
    if (!mounted) return;
    setState(() {
      _questions = questions;
      _answers = List.filled(questions.length, -1);
      _isLoading = false;
    });
    _startTimer();
    _cardAnimCtrl.forward();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = _kSecondsPerQuestion);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) {
        t.cancel();
        // Auto-advance; if no answer selected, record -1 (wrong)
        _advanceOrSubmit();
      }
    });
  }

  void _selectAnswer(int index) {
    if (_answers[_currentIndex] != -1) return; // Already answered
    setState(() => _answers[_currentIndex] = index);
    // Brief pause to let user see selection, then advance
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _advanceOrSubmit();
    });
  }

  void _advanceOrSubmit() {
    _timer?.cancel();
    if (_currentIndex < _questions!.length - 1) {
      setState(() => _currentIndex++);
      _cardAnimCtrl.forward(from: 0);
      _startTimer();
    } else {
      _submitQuiz();
    }
  }

  Future<void> _submitQuiz() async {
    setState(() => _isSubmitting = true);
    final userModel = ref.read(currentUserProfileProvider).value;
    final score = await ref
        .read(missionsNotifierProvider.notifier)
        .submitSubjectQuiz(
          uid: widget.uid,
          subjectId: widget.subjectId,
          questions: _questions!,
          answers: _answers,
          userModel: userModel,
        );
    if (!mounted) return;
    setState(() {
      _score = score;
      _isFinished = true;
      _isSubmitting = false;
    });
  }

  Color _timerColor() {
    if (_secondsLeft > 15) return Colors.green;
    if (_secondsLeft > 8) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.subjectName)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_questions == null || _questions!.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.subjectName)),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.help_outline, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('No questions available yet.',
                  style: TextStyle(fontSize: 16)),
              const SizedBox(height: 8),
              Text(
                'Questions for ${widget.subjectName} will be added soon.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: () => context.pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    if (_isSubmitting) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(
                'Calculating your score...',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_isFinished) {
      return _buildScoreScreen(context);
    }

    return _buildQuizScreen(context);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // QUIZ SCREEN
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildQuizScreen(BuildContext context) {
    final question = _questions![_currentIndex];
    final cs = Theme.of(context).colorScheme;
    final total = _questions!.length;
    final progress = (_currentIndex + 1) / total;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Text(
          '${widget.subjectName} Quiz',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4.0),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: AppColors.primary.withOpacity(0.12),
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      ),
      body: Column(
        children: [
          // ── Question header strip ────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            color: cs.surface,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Q ${_currentIndex + 1} of $total',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface.withOpacity(0.6),
                    fontSize: 13,
                  ),
                ),
                // Countdown timer
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: _timerColor().withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _timerColor().withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.timer_outlined, size: 15, color: _timerColor()),
                      const SizedBox(width: 4),
                      Text(
                        '$_secondsLeft s',
                        style: TextStyle(
                          color: _timerColor(),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: SlideTransition(
              position: _cardSlide,
              child: FadeTransition(
                opacity: _cardFade,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Question text ─────────────────────────────────────
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primary.withOpacity(0.08),
                              AppColors.secondary.withOpacity(0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.primary.withOpacity(0.15),
                          ),
                        ),
                        child: Text(
                          question.text,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            height: 1.5,
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ── Answer options ────────────────────────────────────
                      ...List.generate(question.options.length, (i) {
                        return _AnswerOption(
                          label: String.fromCharCode(65 + i), // A, B, C, D
                          text: question.options[i],
                          state: _answers[_currentIndex] == -1
                              ? _OptionState.idle
                              : (_answers[_currentIndex] == i
                                  ? _OptionState.selected
                                  : _OptionState.dimmed),
                          onTap: _answers[_currentIndex] == -1
                              ? () => _selectAnswer(i)
                              : null,
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SCORE SCREEN
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildScoreScreen(BuildContext context) {
    final passed = _score! >= 0.6;
    final pct = (_score! * 100).round();
    final correctCount = (_score! * _questions!.length).round();
    final total = _questions!.length;
    final cs = Theme.of(context).colorScheme;

    final Color resultColor = passed ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    final String resultEmoji = passed ? '🏆' : '💡';
    final String resultTitle = passed ? 'Mission Complete!' : 'Keep Practicing!';
    final String resultSub = passed
        ? '+${50} XP added to your stats'
        : 'You need 60% to pass. Try again tomorrow.';

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 24),

              // Score ring
              SizedBox(
                width: 160,
                height: 160,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 160,
                      height: 160,
                      child: CircularProgressIndicator(
                        value: _score!,
                        strokeWidth: 12,
                        backgroundColor: resultColor.withOpacity(0.12),
                        valueColor: AlwaysStoppedAnimation<Color>(resultColor),
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          resultEmoji,
                          style: const TextStyle(fontSize: 32),
                        ),
                        Text(
                          '$pct%',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: resultColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              Text(
                resultTitle,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: resultColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                resultSub,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: cs.onSurface.withOpacity(0.6),
                  fontSize: 14,
                ),
              ),

              const SizedBox(height: 28),

              // Stats row
              Row(
                children: [
                  Expanded(
                    child: _ResultStatBox(
                      icon: Icons.check_circle_outline,
                      value: '$correctCount',
                      label: 'Correct',
                      color: const Color(0xFF10B981),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ResultStatBox(
                      icon: Icons.cancel_outlined,
                      value: '${total - correctCount}',
                      label: 'Wrong',
                      color: const Color(0xFFEF4444),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ResultStatBox(
                      icon: Icons.quiz_outlined,
                      value: '$total',
                      label: 'Total',
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),
              const Divider(),
              const SizedBox(height: 16),

              // Answer review
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Answer Review',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              ..._questions!.asMap().entries.map((entry) {
                final i = entry.key;
                final q = entry.value;
                final userAnswer = _answers[i];
                final isCorrect = userAnswer == q.correctIndex;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isCorrect
                        ? const Color(0xFF10B981).withOpacity(0.07)
                        : const Color(0xFFEF4444).withOpacity(0.07),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isCorrect
                          ? const Color(0xFF10B981).withOpacity(0.3)
                          : const Color(0xFFEF4444).withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            isCorrect ? Icons.check_circle : Icons.cancel,
                            color: isCorrect
                                ? const Color(0xFF10B981)
                                : const Color(0xFFEF4444),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Q${i + 1}. ${q.text}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (!isCorrect) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Your answer: ${userAnswer >= 0 ? q.options[userAnswer] : "Not answered"}',
                          style: const TextStyle(
                            color: Color(0xFFEF4444),
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          'Correct: ${q.options[q.correctIndex]}',
                          style: const TextStyle(
                            color: Color(0xFF10B981),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => context.pop(),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    'Back to Missions',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// ANSWER OPTION WIDGET
// ═════════════════════════════════════════════════════════════════════════════
enum _OptionState { idle, selected, dimmed }

class _AnswerOption extends StatelessWidget {
  final String label; // 'A', 'B', etc.
  final String text;
  final _OptionState state;
  final VoidCallback? onTap;

  const _AnswerOption({
    required this.label,
    required this.text,
    required this.state,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final Color bg;
    final Color border;
    final Color labelBg;
    final Color labelText;
    final Color textColor;

    switch (state) {
      case _OptionState.selected:
        bg = AppColors.primary.withOpacity(0.08);
        border = AppColors.primary;
        labelBg = AppColors.primary;
        labelText = Colors.white;
        textColor = cs.onSurface;
        break;
      case _OptionState.dimmed:
        bg = cs.surface;
        border = cs.outline.withOpacity(0.2);
        labelBg = cs.surfaceContainerHighest;
        labelText = cs.onSurface.withOpacity(0.35);
        textColor = cs.onSurface.withOpacity(0.35);
        break;
      case _OptionState.idle:
        bg = cs.surface;
        border = cs.outline.withOpacity(0.35);
        labelBg = AppColors.primary.withOpacity(0.1);
        labelText = AppColors.primary;
        textColor = cs.onSurface;
        break;
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            // Label bubble
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: labelBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    color: labelText,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 14,
                  color: textColor,
                  fontWeight: state == _OptionState.selected
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// RESULT STAT BOX
// ═════════════════════════════════════════════════════════════════════════════
class _ResultStatBox extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _ResultStatBox({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55),
            ),
          ),
        ],
      ),
    );
  }
}
