import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:studycompete/features/auth/providers/auth_provider.dart';
import 'package:studycompete/features/missions/providers/missions_provider.dart';
import 'package:studycompete/shared/utils/haptic_feedback_utils.dart';
import 'package:studycompete/shared/constants/app_constants.dart';

class FocusSessionScreen extends ConsumerStatefulWidget {
  const FocusSessionScreen({super.key});

  @override
  ConsumerState<FocusSessionScreen> createState() => _FocusSessionScreenState();
}

class _FocusSessionScreenState extends ConsumerState<FocusSessionScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  int _focusMinutes = 25;
  late int _totalSeconds;
  int _secondsRemaining = 25 * 60;
  bool _isRunning = false;
  bool _isCompleted = false;
  bool _isClaiming = false; // true while writing reward to Firestore
  int _distractionBreaches = 0;
  String _selectedSubject = 'General Deep Focus';

  Timer? _timer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _totalSeconds = _focusMinutes * 60;
    _secondsRemaining = _totalSeconds;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  // ─── Anti-Distraction Lifecycle Observer ──────────────────────────────────
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isRunning && (state == AppLifecycleState.paused || state == AppLifecycleState.inactive)) {
      // User left the app while timer was running!
      HapticFeedbackUtils.alertWarning();
      setState(() {
        _distractionBreaches++;
      });
    }
  }

  void _selectInterval(int minutes) {
    if (_isRunning) return;
    HapticFeedbackUtils.lightClick();
    setState(() {
      _focusMinutes = minutes;
      _totalSeconds = minutes * 60;
      _secondsRemaining = _totalSeconds;
      _isCompleted = false;
      _distractionBreaches = 0;
    });
  }

  void _startTimer() {
    HapticFeedbackUtils.questComplete();
    setState(() {
      _isRunning = true;
      _isCompleted = false;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining <= 1) {
        timer.cancel();
        HapticFeedbackUtils.levelUp();
        setState(() {
          _secondsRemaining = 0;
          _isRunning = false;
          _isCompleted = true;
        });
      } else {
        setState(() {
          _secondsRemaining--;
        });
      }
    });
  }

  void _pauseTimer() {
    HapticFeedbackUtils.lightClick();
    _timer?.cancel();
    setState(() => _isRunning = false);
  }

  void _resetTimer() {
    HapticFeedbackUtils.lightClick();
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _secondsRemaining = _totalSeconds;
      _isCompleted = false;
      _distractionBreaches = 0;
    });
  }

  String get _timeDisplay {
    final m = (_secondsRemaining ~/ 60).toString().padLeft(2, '0');
    final s = (_secondsRemaining % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  double get _progress => (_totalSeconds - _secondsRemaining) / _totalSeconds;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProfileProvider).value;
    final subjects = user?.subjectIds.isNotEmpty == true
        ? user!.subjectIds
        : ['Mathematics', 'Physics', 'Chemistry', 'Biology', 'General Deep Focus'];

    return Scaffold(
      backgroundColor: const Color(0xFF020617), // Solo Leveling Abyss Dark
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1329),
        title: const Row(
          children: [
            Icon(Icons.self_improvement, color: Color(0xFF38BDF8), size: 22),
            SizedBox(width: 10),
            Text(
              'DEEP FOCUS PROTOCOL',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                fontSize: 15,
              ),
            ),
          ],
        ),
        actions: [
          if (_distractionBreaches > 0)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.redAccent),
                  ),
                  child: Text(
                    '⚠️ $_distractionBreaches Breaches',
                    style: const TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              // ── INTERVAL SELECTOR ──
              if (!_isRunning && !_isCompleted) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [15, 25, 50].map((mins) {
                    final isSel = _focusMinutes == mins;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6.0),
                      child: ChoiceChip(
                        label: Text('$mins Min'),
                        selected: isSel,
                        selectedColor: const Color(0xFF38BDF8),
                        backgroundColor: const Color(0xFF0F172A),
                        labelStyle: TextStyle(
                          color: isSel ? Colors.black : Colors.white70,
                          fontWeight: FontWeight.bold,
                        ),
                        onSelected: (_) => _selectInterval(mins),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
              ],

              // ── SUBJECT SELECTOR ──
              if (!_isRunning && !_isCompleted) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.4)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: subjects.contains(_selectedSubject) ? _selectedSubject : subjects.first,
                      dropdownColor: const Color(0xFF0F172A),
                      isExpanded: true,
                      icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF38BDF8)),
                      items: subjects.map((s) {
                        return DropdownMenuItem(
                          value: s,
                          child: Text(s, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedSubject = val);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              const Spacer(),

              // ── HOLOGRAPHIC FOCUS TIMER RING ──
              ScaleTransition(
                scale: _isRunning ? _pulseAnim : const AlwaysStoppedAnimation(1.0),
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF38BDF8).withOpacity(_isRunning ? 0.25 : 0.08),
                        blurRadius: 36,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox.expand(
                        child: CircularProgressIndicator(
                          value: _progress,
                          strokeWidth: 8,
                          backgroundColor: Colors.white12,
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF38BDF8)),
                        ),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _selectedSubject.toUpperCase(),
                            style: const TextStyle(
                              color: Color(0xFF38BDF8),
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _timeDisplay,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 60,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                              fontFamily: 'monospace',
                            ),
                          ),
                          Text(
                            _isCompleted
                                ? 'FOCUS COMPLETED! 🏆'
                                : _isRunning
                                    ? 'DEEP SENSE ACTIVE'
                                    : 'AWAITING HUNTER',
                            style: TextStyle(
                              color: _isCompleted
                                  ? Colors.greenAccent
                                  : (_isRunning ? const Color(0xFF38BDF8) : Colors.white38),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ── HUNTER FOCUS MOTTO ──
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A).withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: const Text(
                  '💡 "The System rewards unshakable mental focus. Leaving the app triggers Focus Breach warnings."',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, fontSize: 11, fontStyle: FontStyle.italic),
                ),
              ),

              const Spacer(),

              // ── REWARDS BANNER (ON COMPLETION) ──
              if (_isCompleted) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.greenAccent),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle, color: Colors.greenAccent, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            '+${AppConstants.focusSessionXP} XP • +$_focusMinutes Focus Min • -${AppConstants.focusFatigueReduction}% FATIGUE',
                            style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                        ],
                      ),
                      if (_distractionBreaches > 0) ...[
                        const SizedBox(height: 6),
                        Text(
                          '⚠️ $_distractionBreaches distraction breach(es) detected — XP penalty applied.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.orangeAccent, fontSize: 10),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ── CONTROLS ──
              if (!_isCompleted) ...[
                if (!_isRunning)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _startTimer,
                      icon: const Icon(Icons.play_arrow_rounded, size: 24),
                      label: Text('START $_focusMinutes-MIN DEEP WORK', style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF38BDF8),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pauseTimer,
                          icon: const Icon(Icons.pause),
                          label: const Text('PAUSE'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white30),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _resetTimer,
                          icon: const Icon(Icons.refresh),
                          label: const Text('RESET'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            side: const BorderSide(color: Colors.redAccent),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                    ],
                  ),
              ] else
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    // WHY: This button was previously a no-op (just popped the screen).
                    // Now it calls rewardFocusSession which persists XP and focus minutes
                    // to Firestore, making Deep Focus Protocol a real progression mechanic.
                    onPressed: _isClaiming
                        ? null
                        : () async {
                            final uid = ref.read(currentUserProvider)?.uid ?? '';
                            if (uid.isEmpty) {
                              if (context.mounted) context.pop();
                              return;
                            }
                            setState(() => _isClaiming = true);
                            try {
                              final result = await ref
                                  .read(missionsNotifierProvider.notifier)
                                  .rewardFocusSession(
                                    uid: uid,
                                    focusMinutes: _focusMinutes,
                                    distractionBreaches: _distractionBreaches,
                                  );
                              if (context.mounted) {
                                final xpEarned = result['xpAwarded'] as int? ?? 0;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      xpEarned > 0
                                          ? '⚡ Focus Rewards Claimed: +$xpEarned XP • +$_focusMinutes focus min'
                                          : '📊 Session logged: +$_focusMinutes focus min (XP reduced by distraction penalties)',
                                    ),
                                    backgroundColor: xpEarned > 0
                                        ? Colors.green.shade700
                                        : Colors.orange.shade700,
                                    duration: const Duration(seconds: 3),
                                  ),
                                );
                                context.pop();
                              }
                            } catch (e) {
                              setState(() => _isClaiming = false);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Failed to claim rewards: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isClaiming ? Colors.grey : Colors.greenAccent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _isClaiming
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black54),
                          )
                        : const Text('CLAIM FOCUS REWARDS', style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
