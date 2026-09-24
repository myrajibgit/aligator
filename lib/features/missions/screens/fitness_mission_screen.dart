import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:studycompete/features/auth/providers/auth_provider.dart';
import 'package:studycompete/features/missions/services/fitness_service.dart';
import 'package:studycompete/features/missions/providers/missions_provider.dart';
import 'package:studycompete/shared/constants/app_constants.dart';
import 'package:studycompete/shared/theme/app_theme.dart';

// ─── FitnessMissionScreen ─────────────────────────────────────────────

class FitnessMissionScreen extends ConsumerStatefulWidget {
  const FitnessMissionScreen({super.key});

  @override
  ConsumerState<FitnessMissionScreen> createState() =>
      _FitnessMissionScreenState();
}

class _FitnessMissionScreenState extends ConsumerState<FitnessMissionScreen>
    with TickerProviderStateMixin {
  static const _totalSeconds = 30 * 60; // 30 minutes

  late TabController _tabController;

  // Cardio Timer State
  Timer? _timer;
  int _secondsRemaining = _totalSeconds;
  bool _isRunning = false;
  bool _isCompleted = false;
  bool _isVerifying = false;
  bool _permissionDenied = false;
  DateTime? _workoutStart;
  FitnessVerificationResult? _result;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  // Bodyweight Rep Training State
  String _selectedExercise = 'Push Ups';
  int _targetReps = 30;
  int _currentReps = 0;
  bool _repMissionComplete = false;

  final List<Map<String, dynamic>> _exercises = [
    {
      'name': 'Push Ups',
      'icon': '💪',
      'tip': 'Lower chest to ground (elbow < 90°), push up to full extension (> 160°).',
      'defaultTarget': 30,
    },
    {
      'name': 'Bodyweight Squats',
      'icon': '🦵',
      'tip': 'Descend until thighs are parallel to ground (knees < 100°), stand tall.',
      'defaultTarget': 40,
    },
    {
      'name': 'Walking Lunges',
      'icon': '🏃',
      'tip': 'Step forward with controlled balance; back knee almost touching floor.',
      'defaultTarget': 30,
    },
    {
      'name': 'Plank Hold (Sec)',
      'icon': '🛡️',
      'tip': 'Lock core, maintain straight body alignment (Shoulder-Hip-Ankle > 150°).',
      'defaultTarget': 60,
    },
    {
      'name': 'Burpees',
      'icon': '⚡',
      'tip': 'Explosive jump from squat thrust; full body high-intensity conditioning.',
      'defaultTarget': 20,
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tabController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // ─── Timer logic ───────────────────────────────────────────────────────────

  Future<void> _startTimer() async {
    final service = ref.read(fitnessServiceProvider);
    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return;

    final hasPermission = await service.requestHealthPermissions();
    if (!hasPermission) {
      setState(() => _permissionDenied = true);
    }

    await service.startFitnessTimer(uid);
    _workoutStart = DateTime.now();

    setState(() => _isRunning = true);
    _pulseController.repeat(reverse: true);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining <= 1) {
        timer.cancel();
        _pulseController.stop();
        setState(() {
          _secondsRemaining = 0;
          _isRunning = false;
          _isCompleted = true;
        });
        _verifyActivity();
      } else {
        setState(() => _secondsRemaining--);
      }
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    _pulseController.stop();
    setState(() => _isRunning = false);
  }

  void _resumeTimer() {
    _pulseController.repeat(reverse: true);
    setState(() => _isRunning = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining <= 1) {
        timer.cancel();
        _pulseController.stop();
        setState(() {
          _secondsRemaining = 0;
          _isRunning = false;
          _isCompleted = true;
        });
        _verifyActivity();
      } else {
        setState(() => _secondsRemaining--);
      }
    });
  }

  Future<void> _verifyActivity() async {
    setState(() => _isVerifying = true);
    final service = ref.read(fitnessServiceProvider);
    final uid = ref.read(currentUserProvider)?.uid ?? '';
    final end = DateTime.now();
    final start = _workoutStart ?? end.subtract(const Duration(minutes: 30));

    final result = await service.verifyFitnessActivity(
      workoutStart: start,
      workoutEnd: end,
    );

    if (result.verified) {
      await service.completeFitnessMission(
        uid: uid,
        fitStepsVerified: true,
      );
    }

    setState(() {
      _result = result;
      _isVerifying = false;
    });
  }

  Future<void> _manualComplete() async {
    final uid = ref.read(currentUserProvider)?.uid ?? '';
    final service = ref.read(fitnessServiceProvider);
    await service.completeFitnessMission(uid: uid, fitStepsVerified: false);
    setState(() {
      _result = const FitnessVerificationResult(
        verified: true,
        steps: 0,
        activeMinutes: 30,
        reason: 'Manually verified — health data unavailable.',
      );
    });
  }

  // ─── Rep Training Logic ───────────────────────────────────────────────────

  void _incrementReps(int amount) {
    setState(() {
      _currentReps = (_currentReps + amount).clamp(0, 999);
      if (_currentReps >= _targetReps) {
        _repMissionComplete = true;
      }
    });
  }

  Future<void> _submitRepWorkout() async {
    final uid = ref.read(currentUserProvider)?.uid ?? '';
    final service = ref.read(fitnessServiceProvider);
    await service.completeFitnessMission(uid: uid, fitStepsVerified: false);
    setState(() {
      _result = FitnessVerificationResult(
        verified: true,
        steps: _currentReps * 15,
        activeMinutes: 20,
        reason: 'Completed $_currentReps reps of $_selectedExercise! Training registered.',
      );
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
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Physical Conditioning', style: TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        bottom: _result == null
            ? TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFF22C55E),
                labelColor: const Color(0xFF22C55E),
                unselectedLabelColor: Colors.grey,
                tabs: const [
                  Tab(icon: Icon(Icons.directions_run), text: '30-Min Cardio'),
                  Tab(icon: Icon(Icons.fitness_center), text: 'Hunter Reps'),
                ],
              )
            : null,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _result != null
              ? _buildResultView(cs)
              : _isVerifying
                  ? _buildVerifyingView(cs)
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildTimerView(cs),
                        _buildRepTrainingView(cs),
                      ],
                    ),
        ),
      ),
    );
  }

  // ─── TAB 1: Cardio Timer View ─────────────────────────────────────────────
  Widget _buildTimerView(ColorScheme cs) {
    return Column(
      children: [
        // Header card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary.withOpacity(0.12), AppColors.secondary.withOpacity(0.08)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.directions_run, color: Color(0xFF22C55E), size: 36),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('30-Minute Sensor Conditioning',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(
                      'Outdoor jog or brisk walk verified with Google Fit or Apple HealthKit sensors.',
                      style: TextStyle(color: cs.onSurface.withOpacity(0.6), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        if (_permissionDenied) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withOpacity(0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber, color: Colors.orange, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Health permissions not granted. Timer will run; manual completion allowed.',
                    style: TextStyle(color: Colors.orange.shade700, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ],

        const Spacer(),

        // Circular timer
        ScaleTransition(
          scale: _isRunning ? _pulseAnim : const AlwaysStoppedAnimation(1.0),
          child: SizedBox(
            width: 220,
            height: 220,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: _progress,
                    strokeWidth: 9,
                    backgroundColor: cs.outlineVariant.withOpacity(0.3),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _isRunning ? const Color(0xFF22C55E) : AppColors.primary,
                    ),
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _timeDisplay,
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: _isRunning ? const Color(0xFF22C55E) : cs.onSurface,
                      ),
                    ),
                    Text(
                      _isCompleted
                          ? 'Completed!'
                          : _isRunning
                              ? 'Active Conditioning 💪'
                              : _secondsRemaining == _totalSeconds
                                  ? 'Ready to start'
                                  : 'Paused',
                      style: TextStyle(color: cs.onSurface.withOpacity(0.55), fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 14),
        Text(
          '${(_progress * 100).toInt()}% complete',
          style: TextStyle(color: cs.onSurface.withOpacity(0.45), fontSize: 13),
        ),

        const Spacer(),

        // XP reward badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.star, color: Colors.amber, size: 18),
              const SizedBox(width: 6),
              Text(
                '+${AppConstants.fitnessMissionXP} XP on completion',
                style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        if (!_isCompleted) ...[
          if (!_isRunning && _secondsRemaining == _totalSeconds)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _startTimer,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Start 30-Min Workout', style: TextStyle(fontSize: 16)),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: const Color(0xFF22C55E),
                  foregroundColor: Colors.black,
                ),
              ),
            )
          else if (_isRunning)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _pauseTimer,
                icon: const Icon(Icons.pause),
                label: const Text('Pause'),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _resumeTimer,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Resume'),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  ),
                ),
                if (_permissionDenied) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _manualComplete,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: Colors.orange,
                      ),
                      child: const Text('Mark Done Manually'),
                    ),
                  ),
                ],
              ],
            ),
        ],
      ],
    );
  }

  // ─── TAB 2: Bodyweight Rep Training (Solo-Leveling Gym Mechanics) ──────────
  Widget _buildRepTrainingView(ColorScheme cs) {
    final currentExData = _exercises.firstWhere(
      (e) => e['name'] == _selectedExercise,
      orElse: () => _exercises[0],
    );

    return SingleChildScrollView(
      child: Column(
        children: [
          // EXERCISE SELECTOR DROPDOWN
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF22C55E).withOpacity(0.4)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedExercise,
                isExpanded: true,
                dropdownColor: const Color(0xFF0F172A),
                icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF22C55E)),
                items: _exercises.map((e) {
                  return DropdownMenuItem<String>(
                    value: e['name'] as String,
                    child: Row(
                      children: [
                        Text(e['icon'] as String, style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: 10),
                        Text(
                          e['name'] as String,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedExercise = val;
                      final ex = _exercises.firstWhere((e) => e['name'] == val);
                      _targetReps = ex['defaultTarget'] as int;
                      _currentReps = 0;
                      _repMissionComplete = false;
                    });
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 12),

          // FORM TIP CARD
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black38,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                const Icon(Icons.lightbulb, color: Colors.amber, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    currentExData['tip'] as String,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // REP TARGET PILL SELECTOR
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Target Goal:', style: TextStyle(color: Colors.white60, fontSize: 12)),
              const SizedBox(width: 10),
              Wrap(
                spacing: 8,
                children: [15, 30, 50, 100].map((t) {
                  final isSel = _targetReps == t;
                  return ChoiceChip(
                    label: Text('$t'),
                    selected: isSel,
                    selectedColor: const Color(0xFF22C55E),
                    backgroundColor: const Color(0xFF1E293B),
                    labelStyle: TextStyle(
                      color: isSel ? Colors.black : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                    onSelected: (_) {
                      setState(() {
                        _targetReps = t;
                        _repMissionComplete = _currentReps >= _targetReps;
                      });
                    },
                  );
                }).toList(),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // BIG REP DISPLAY
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF0F172A),
              border: Border.all(
                color: _repMissionComplete ? const Color(0xFF22C55E) : Colors.white24,
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: (_repMissionComplete ? const Color(0xFF22C55E) : Colors.transparent)
                      .withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$_currentReps',
                    style: TextStyle(
                      fontSize: 64,
                      fontWeight: FontWeight.w900,
                      color: _repMissionComplete ? const Color(0xFF22C55E) : Colors.white,
                      height: 1.0,
                    ),
                  ),
                  Text(
                    '/ $_targetReps REPS',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_repMissionComplete)
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF22C55E),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'GOAL MET ✓',
                        style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 10),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // REP INCREMENT BUTTONS
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () => _incrementReps(1),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF22C55E),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text(
                  '+1 REP',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ),
              const SizedBox(width: 14),
              ElevatedButton(
                onPressed: () => _incrementReps(5),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text(
                  '+5 REPS',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.outlined(
                tooltip: 'Reset',
                onPressed: () => setState(() {
                  _currentReps = 0;
                  _repMissionComplete = false;
                }),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // COMPLETE REPS MISSION BUTTON
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _repMissionComplete ? _submitRepWorkout : null,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: const Color(0xFF22C55E),
                foregroundColor: Colors.black,
                disabledBackgroundColor: Colors.white12,
              ),
              child: Text(
                _repMissionComplete ? 'CLAIM WORKOUT XP (+30 XP)' : 'REACH TARGET TO COMPLETE',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Verifying View ────────────────────────────────────────────────────────
  Widget _buildVerifyingView(ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text('Verifying your activity…', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Checking Google Fit / Apple Health data',
            style: TextStyle(color: cs.onSurface.withOpacity(0.55)),
          ),
        ],
      ),
    );
  }

  // ─── Result View ───────────────────────────────────────────────────────────
  Widget _buildResultView(ColorScheme cs) {
    final result = _result!;
    final success = result.verified;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 600),
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: (success ? Colors.green : cs.error).withOpacity(0.12),
          ),
          child: Icon(
            success ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 64,
            color: success ? Colors.green : cs.error,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          success ? '🎉 Physical Conditioning Cleared!' : 'Not Quite There',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: success ? Colors.green : cs.error),
        ),
        const SizedBox(height: 10),
        Text(
          result.reason,
          textAlign: TextAlign.center,
          style: TextStyle(color: cs.onSurface.withOpacity(0.65), fontSize: 13),
        ),
        if (success) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatChip('${result.steps}', 'Equivalent Steps', Icons.directions_walk),
                _StatChip('${result.activeMinutes} min', 'Conditioning', Icons.timer),
                _StatChip('+${AppConstants.fitnessMissionXP}', 'XP Awarded', Icons.star),
              ],
            ),
          ),
        ],
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => context.pop(),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: success ? Colors.green : AppColors.primary,
            ),
            child: Text(success ? 'Back to Daily Quests' : 'Try Again'),
          ),
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip(this.value, this.label, this.icon);
  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.green, size: 22),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
        Text(label,
            style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55))),
      ],
    );
  }
}
