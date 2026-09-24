import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:studycompete/features/auth/providers/auth_provider.dart';
import 'package:studycompete/shared/constants/app_constants.dart';
import 'package:studycompete/shared/theme/app_theme.dart';
import 'package:studycompete/shared/utils/haptic_feedback_utils.dart';

// -----------------------------------------------------------------------------
// OFFLINE STUDY LOG SCREEN
//
// WHY THIS EXISTS:
// Students don't always study with the app open. Textbook reading, written
// homework, group sessions, and mock exams all happen offline. Without this,
// hunters lose XP they legitimately earned. This screen lets them declare
// offline study activity and earn fair XP — capped at 60 XP/day to prevent
// farming, with a 1-log-per-day anti-cheat limit. All logs are stored in
// Firestore for audit and visible in their analytics.
// -----------------------------------------------------------------------------

// ── Provider: today's offline study log ──────────────────────────────────────

final todayOfflineLogProvider =
    StreamProvider.autoDispose<Map<String, dynamic>?>((ref) {
  final uid = ref.watch(currentUserProvider)?.uid ?? '';
  if (uid.isEmpty) return Stream.value(null);

  final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());

  return FirebaseFirestore.instance
      .collection(AppConstants.usersCollection)
      .doc(uid)
      .collection('offlineLogs')
      .doc(todayKey)
      .snapshots()
      .map((snap) => snap.data());
});

// ── Offline Study Log Screen ─────────────────────────────────────────────────

class OfflineStudyLogScreen extends ConsumerStatefulWidget {
  final String uid;

  const OfflineStudyLogScreen({super.key, required this.uid});

  @override
  ConsumerState<OfflineStudyLogScreen> createState() =>
      _OfflineStudyLogScreenState();
}

class _OfflineStudyLogScreenState
    extends ConsumerState<OfflineStudyLogScreen> {
  final _formKey = GlobalKey<FormState>();

  // Form fields
  String? _selectedSubject;
  String _activityType = 'textbook';
  int _durationMinutes = 30;
  final _notesCtrl = TextEditingController();
  bool _isSubmitting = false;

  static const List<Map<String, dynamic>> _activityTypes = [
    {
      'id': 'textbook',
      'label': 'Textbook Reading',
      'emoji': '📖',
      'color': Color(0xFF38BDF8),
      'xpPerHour': 40,
    },
    {
      'id': 'homework',
      'label': 'Written Homework',
      'emoji': '✏️',
      'color': Color(0xFFA855F7),
      'xpPerHour': 50,
    },
    {
      'id': 'revision',
      'label': 'Notes Revision',
      'emoji': '📝',
      'color': Color(0xFF10B981),
      'xpPerHour': 45,
    },
    {
      'id': 'mock_exam',
      'label': 'Mock / Practice Test',
      'emoji': '📋',
      'color': Color(0xFFFFD700),
      'xpPerHour': 60,
    },
    {
      'id': 'group_study',
      'label': 'Group Study Session',
      'emoji': '👥',
      'color': Color(0xFFF59E0B),
      'xpPerHour': 35,
    },
    {
      'id': 'flashcards',
      'label': 'Flashcard Drill',
      'emoji': '🃏',
      'color': Color(0xFFEF4444),
      'xpPerHour': 40,
    },
  ];

  Map<String, dynamic> get _selectedActivity =>
      _activityTypes.firstWhere((a) => a['id'] == _activityType,
          orElse: () => _activityTypes[0]);

  // XP calculation: (xpPerHour / 60) * minutes, capped at 60 total per day
  int get _calculatedXp {
    final xpPerHour = _selectedActivity['xpPerHour'] as int;
    final raw = ((xpPerHour / 60) * _durationMinutes).round();
    return min(raw, 60); // hard cap
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitLog(List<String> subjectIds) async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSubject == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a subject.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    HapticFeedbackUtils.mediumImpact();

    try {
      final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final firestore = FirebaseFirestore.instance;
      final uid = widget.uid;

      final logRef = firestore
          .collection(AppConstants.usersCollection)
          .doc(uid)
          .collection('offlineLogs')
          .doc(todayKey);

      final existing = await logRef.get();
      if (existing.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  '⚠️ Offline log already submitted for today. Max 1 per day.'),
              backgroundColor: Color(0xFFF59E0B),
            ),
          );
        }
        return;
      }

      final xpAwarded = _calculatedXp;

      // Write offline log document
      await logRef.set({
        'date': todayKey,
        'subjectId': _selectedSubject,
        'activityType': _activityType,
        'durationMinutes': _durationMinutes,
        'notes': _notesCtrl.text.trim(),
        'xpAwarded': xpAwarded,
        'submittedAt': FieldValue.serverTimestamp(),
      });

      // Award XP to user document
      await firestore
          .collection(AppConstants.usersCollection)
          .doc(uid)
          .update({'xp': FieldValue.increment(xpAwarded)});

      // Write to streak's active-days map so it counts towards streak
      final streakRef = firestore
          .collection(AppConstants.usersCollection)
          .doc(uid)
          .collection('streaks')
          .doc('current');

      await streakRef.set({
        'activeDays': {todayKey: true},
        'lastActiveDate': todayKey,
      }, SetOptions(merge: true));

      if (mounted) {
        await _showSuccessDialog(xpAwarded);
        if (mounted) Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _showSuccessDialog(int xpAwarded) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('📖', style: TextStyle(fontSize: 52)),
              const SizedBox(height: 12),
              const Text(
                'STUDY LOG RECORDED',
                style: TextStyle(
                  color: Color(0xFF10B981),
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '+$xpAwarded XP',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 36,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Offline session XP has been added to your hunter profile.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 20),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('ACKNOWLEDGED'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProfileProvider);
    final todayLogAsync = ref.watch(todayOfflineLogProvider);
    final user = userAsync.value;
    final subjectIds = user?.subjectIds ?? [];

    final todayLog = todayLogAsync.value;
    final alreadyLogged = todayLog != null;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'OFFLINE STUDY LOG',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 14,
                letterSpacing: 1.2,
                color: Color(0xFF10B981),
              ),
            ),
            Text(
              'Log study done away from the app',
              style: TextStyle(fontSize: 11, color: Colors.white54),
            ),
          ],
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ── Already submitted banner ───────────────────────────────────
            if (alreadyLogged) ...[
              _buildAlreadyLoggedBanner(todayLog),
              const SizedBox(height: 20),
            ],

            // ── Info card ─────────────────────────────────────────────────
            _buildInfoCard(),
            const SizedBox(height: 24),

            // ── Subject selector ──────────────────────────────────────────
            _buildSectionHeader('📚 Subject'),
            const SizedBox(height: 10),
            if (subjectIds.isEmpty)
              const Text(
                'No subjects found. Complete onboarding to log study sessions.',
                style: TextStyle(color: Colors.white54),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: subjectIds.map((id) {
                  final isSelected = _selectedSubject == id;
                  return ChoiceChip(
                    label: Text(
                      id.replaceAll('_', ' ').toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : Colors.white60,
                        fontSize: 11,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: alreadyLogged
                        ? null
                        : (_) => setState(() => _selectedSubject = id),
                    selectedColor: AppColors.primary.withOpacity(0.3),
                    backgroundColor: Colors.white.withOpacity(0.05),
                    side: BorderSide(
                      color: isSelected
                          ? AppColors.primary
                          : Colors.white.withOpacity(0.1),
                    ),
                  );
                }).toList(),
              ),
            const SizedBox(height: 24),

            // ── Activity type ─────────────────────────────────────────────
            _buildSectionHeader('🎯 Activity Type'),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 2.8,
              children: _activityTypes.map((activity) {
                final isSelected = _activityType == activity['id'];
                final color = activity['color'] as Color;
                return GestureDetector(
                  onTap: alreadyLogged
                      ? null
                      : () => setState(
                          () => _activityType = activity['id'] as String),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? color.withOpacity(0.15)
                          : Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? color
                            : Colors.white.withOpacity(0.1),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(activity['emoji'] as String,
                            style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            activity['label'] as String,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isSelected ? color : Colors.white60,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // ── Duration slider ───────────────────────────────────────────
            _buildSectionHeader(
                '⏱️ Duration: $_durationMinutes min  →  $_calculatedXp XP'),
            const SizedBox(height: 4),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppColors.primary,
                thumbColor: AppColors.primary,
                inactiveTrackColor: Colors.white12,
                overlayColor: AppColors.primary.withOpacity(0.2),
              ),
              child: Slider(
                value: _durationMinutes.toDouble(),
                min: 15,
                max: 180,
                divisions: 11,
                label: '$_durationMinutes min',
                onChanged: alreadyLogged
                    ? null
                    : (val) => setState(
                        () => _durationMinutes = val.round()),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('15 min', style: TextStyle(color: Colors.white38, fontSize: 11)),
                Text('180 min', style: TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
            const SizedBox(height: 24),

            // ── Optional notes ────────────────────────────────────────────
            _buildSectionHeader('📋 Notes (Optional)'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notesCtrl,
              enabled: !alreadyLogged,
              maxLines: 3,
              maxLength: 200,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
              decoration: InputDecoration(
                hintText:
                    'What did you study? (e.g. Chapter 5 Newton\'s Laws, Past Paper 2023)',
                hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
                counterStyle: const TextStyle(color: Colors.white38),
              ),
            ),
            const SizedBox(height: 28),

            // ── XP preview ────────────────────────────────────────────────
            _buildXpPreviewCard(),
            const SizedBox(height: 24),

            // ── Submit button ─────────────────────────────────────────────
            FilledButton.icon(
              onPressed:
                  alreadyLogged || _isSubmitting || subjectIds.isEmpty
                      ? null
                      : () => _submitLog(subjectIds),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                disabledBackgroundColor: Colors.white12,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check_circle_outline, color: Colors.white),
              label: Text(
                alreadyLogged ? 'Log Already Submitted Today' : 'SUBMIT LOG',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  letterSpacing: 0.8,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Anti-cheat notice
            const Text(
              '⚠️  Maximum 1 offline log per day  •  Max +60 XP per session  •  All logs are auditable',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white30, fontSize: 10, height: 1.5),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildAlreadyLoggedBanner(Map<String, dynamic> log) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Text('✅', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'OFFLINE LOG SUBMITTED',
                  style: TextStyle(
                    color: Color(0xFF10B981),
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${log['activityType']?.toString().replaceAll('_', ' ').toUpperCase() ?? 'Unknown'} • '
                  '${log['durationMinutes']} min • '
                  '+${log['xpAwarded']} XP awarded',
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('💡', style: TextStyle(fontSize: 20)),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Studied offline today? Log your session here to earn XP and maintain your streak. '
              'This covers textbook reading, homework, group study, and mock tests done without the app.',
              style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String label) {
    return Text(
      label,
      style: const TextStyle(
        color: Colors.white70,
        fontWeight: FontWeight.w700,
        fontSize: 13,
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _buildXpPreviewCard() {
    final activity = _selectedActivity;
    final color = activity['color'] as Color;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(activity['emoji'] as String,
                style: const TextStyle(fontSize: 24)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity['label'] as String,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$_durationMinutes min  •  ${activity['xpPerHour']} XP/hour',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '+$_calculatedXp',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: 28,
                ),
              ),
              const Text(
                'XP',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
