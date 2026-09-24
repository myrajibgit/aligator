import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:studycompete/features/auth/providers/auth_provider.dart';
import 'package:studycompete/features/missions/models/gemini_verification_result.dart';
import 'package:studycompete/features/missions/services/fitness_service.dart';
import 'package:studycompete/features/missions/services/ocr_service.dart';
import 'package:studycompete/shared/constants/app_constants.dart';
import 'package:studycompete/shared/theme/app_theme.dart';
import 'package:studycompete/features/social/providers/social_provider.dart';

// ─── Provider ─────────────────────────────────────────────────────────────────
final ocrServiceProvider = Provider<OcrService>((ref) => OcrService());

// ─── Screen state machine ─────────────────────────────────────────────────────
enum _StudyStep { capture, processing, coverage, quiz, result }

// ─── Processing sub-step label ────────────────────────────────────────────────
enum _ProcessingPhase { reading, comparing }

class StudyVerificationScreen extends ConsumerStatefulWidget {
  const StudyVerificationScreen({super.key});

  @override
  ConsumerState<StudyVerificationScreen> createState() =>
      _StudyVerificationScreenState();
}

class _StudyVerificationScreenState
    extends ConsumerState<StudyVerificationScreen>
    with SingleTickerProviderStateMixin {
  _StudyStep _step = _StudyStep.capture;
  _ProcessingPhase _processingPhase = _ProcessingPhase.reading;

  Uint8List? _imageBytes;
  GeminiVerificationResult? _geminiResult;
  String? _matchedSubjectId;

  // Quiz state (loaded from Firestore question bank)
  List<dynamic> _questions = [];
  List<int?> _userAnswers = [];
  int _currentQ = 0;
  double? _finalScore;
  String? _errorMsg;

  // Animation
  late AnimationController _progressAnimController;
  late Animation<double> _progressAnim;

  @override
  void initState() {
    super.initState();
    _progressAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _progressAnim = CurvedAnimation(
      parent: _progressAnimController,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _progressAnimController.dispose();
    super.dispose();
  }

  // ─── Pick photo ─────────────────────────────────────────────────────────────
  Future<void> _pickPhoto(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      imageQuality: 82,
      maxWidth: 1440,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    setState(() {
      _imageBytes = bytes;
      _step = _StudyStep.processing;
      _processingPhase = _ProcessingPhase.reading;
      _errorMsg = null;
    });

    await _runGeminiVerification(bytes);
  }

  // ─── Gemini verification flow ────────────────────────────────────────────────
  Future<void> _runGeminiVerification(Uint8List bytes) async {
    final ocrSvc = ref.read(ocrServiceProvider);
    final profile = ref.read(currentUserProfileProvider).value;
    final subjectIds = profile?.subjectIds ?? [];

    if (subjectIds.isEmpty) {
      setState(() {
        _errorMsg = 'No subjects found. Please complete your profile setup.';
        _step = _StudyStep.capture;
      });
      return;
    }

    // Phase 1: reading photo
    setState(() => _processingPhase = _ProcessingPhase.reading);
    await Future.delayed(const Duration(milliseconds: 600));

    // Phase 2: comparing syllabus
    setState(() => _processingPhase = _ProcessingPhase.comparing);

    // Try each subject until one matches
    GeminiVerificationResult? bestResult;
    String? matchedSubjectId;
    for (final subjectId in subjectIds) {
      final result = await ocrSvc.verifyWithGemini(
        imageBytes: bytes,
        subjectId: subjectId,
      );
      if (result.success && result.hasMatch) {
        bestResult = result;
        matchedSubjectId = subjectId;
        break;
      }
      bestResult ??= result; // keep first result for error message
    }

    if (bestResult == null || !bestResult.success || !bestResult.hasMatch) {
      // Offline fallback: On-Device ML Kit OCR keyword matching
      try {
        setState(() => _processingPhase = _ProcessingPhase.reading);
        final extractedText = await ocrSvc.extractTextFromBytes(bytes);
        if (extractedText.isNotEmpty) {
          final chapters = await ocrSvc.getChaptersForSubjects(subjectIds);
          final match = ocrSvc.matchChapter(
            extractedText: extractedText,
            chapters: chapters,
          );
          if (match.matched && match.chapter != null) {
            final verifiedSubjectId = match.chapter!.subjectId;
            final questions = await ocrSvc.getChapterQuestions(
              subjectId: verifiedSubjectId,
              chapterId: match.chapter!.chapterId,
            );
            final fallbackResult = GeminiVerificationResult(
              success: true,
              syllabusAvailable: false,
              matchedChapterId: match.chapter!.chapterId,
              matchedChapterName: match.chapter!.chapterName,
              extractedText: 'Verified via On-Device ML Kit Neural OCR (${(match.confidence * 100).toInt()}% match).',
              coverage: SyllabusCoverage(
                completedPercent: (match.confidence * 100).toInt().clamp(25, 95),
                topicsCovered: match.chapter!.keywords.take(4).toList(),
                topicsRemaining: match.chapter!.keywords.skip(4).take(3).toList(),
              ),
            );

            final targetPercent =
                (fallbackResult.coverage?.completedPercent ?? 50).clamp(0, 100) / 100.0;
            _progressAnim = Tween<double>(begin: 0, end: targetPercent.toDouble())
                .animate(CurvedAnimation(
              parent: _progressAnimController,
              curve: Curves.easeOutCubic,
            ));
            _progressAnimController.forward(from: 0);

            setState(() {
              _geminiResult = fallbackResult;
              _matchedSubjectId = verifiedSubjectId;
              _questions = questions;
              _userAnswers = List.filled(questions.length, null);
              _step = _StudyStep.coverage;
            });
            return;
          }
        }
      } catch (fallbackError) {
        debugPrint('On-device OCR fallback error: $fallbackError');
      }

      setState(() {
        _errorMsg = bestResult?.error ?? 'Could not match your notes to a chapter. Ensure your photo is clear and contains readable textbook text.';
        _step = _StudyStep.capture;
      });
      return;
    }

    final result = bestResult!;

    // Load questions from Firestore question bank
    // Keep the subject that actually matched rather than defaulting to the
    // first subject in the user's profile.
    final verifiedSubjectId = matchedSubjectId ?? subjectIds.first;
    final questions = await ocrSvc.getChapterQuestions(
      subjectId: verifiedSubjectId,
      chapterId: result.matchedChapterId ?? '',
    );

    // Animate progress bar
    final targetPercent =
        (result.coverage?.completedPercent ?? 0).clamp(0, 100) / 100.0;
    _progressAnim = Tween<double>(begin: 0, end: targetPercent.toDouble())
        .animate(CurvedAnimation(
      parent: _progressAnimController,
      curve: Curves.easeOutCubic,
    ));
    _progressAnimController.forward(from: 0);

    setState(() {
      _geminiResult = result;
      _matchedSubjectId = verifiedSubjectId;
      _questions = questions;
      _userAnswers = List.filled(questions.length, null);
      _step = _StudyStep.coverage;
    });
  }

  // ─── Quiz logic ──────────────────────────────────────────────────────────────
  void _selectAnswer(int answerIndex) {
    setState(() => _userAnswers[_currentQ] = answerIndex);
  }

  void _nextQuestion() {
    if (_currentQ < _questions.length - 1) {
      setState(() => _currentQ++);
    } else {
      _submitQuiz();
    }
  }

  Future<void> _submitQuiz() async {
    int correct = 0;
    for (int i = 0; i < _questions.length; i++) {
      if (_userAnswers[i] == _questions[i].correctIndex) correct++;
    }
    final score = _questions.isNotEmpty ? correct / _questions.length : 0.0;
    _finalScore = score;

    if (score >= AppConstants.quizPassThreshold && _geminiResult != null) {
      final uid = ref.read(currentUserProvider)?.uid ?? '';
      final fitSvc = ref.read(fitnessServiceProvider);
      final ocrSvc = ref.read(ocrServiceProvider);

      String? photoRef;
      if (_imageBytes != null) {
        try {
          photoRef = await fitSvc.uploadStudyPhoto(
            uid: uid,
            imageBytes: _imageBytes!,
            subjectId: _geminiResult!.matchedChapterId ?? 'unknown',
          );
        } catch (_) {}
      }

      await fitSvc.completeStudyMission(
        uid: uid,
        subjectId: _matchedSubjectId ?? 'unknown',
        chapterId: _geminiResult!.matchedChapterId ?? '',
        quizScore: score,
        photoStorageRef: photoRef,
      );

      // Finalize anti-cheat hash
      if (_imageBytes != null) {
        try {
          await ocrSvc.recordAntiCheatVerification(
            uid: uid,
            subjectId: _matchedSubjectId ?? 'unknown',
            chapterId: _geminiResult!.matchedChapterId ?? '',
            imageBytes: _imageBytes!,
          );
        } catch (_) {}
      }
    }

    setState(() => _step = _StudyStep.result);
  }

  // ─── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(_appBarTitle,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
        elevation: 0,
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          transitionBuilder: (child, anim) =>
              FadeTransition(opacity: anim, child: child),
          child: switch (_step) {
            _StudyStep.capture => _buildCaptureView(),
            _StudyStep.processing => _buildProcessingView(),
            _StudyStep.coverage => _buildCoverageView(),
            _StudyStep.quiz => _buildQuizView(),
            _StudyStep.result => _buildResultView(),
          },
        ),
      ),
    );
  }

  String get _appBarTitle => switch (_step) {
        _StudyStep.capture => 'Study Verification',
        _StudyStep.processing => 'Analysing…',
        _StudyStep.coverage => 'Syllabus Progress',
        _StudyStep.quiz => 'Knowledge Check',
        _StudyStep.result => 'Mission Result',
      };

  // ─── 1. Capture View ─────────────────────────────────────────────────────────
  Widget _buildCaptureView() {
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      key: const ValueKey('capture'),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Hero instruction card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.secondary.withOpacity(0.12),
                  AppColors.primary.withOpacity(0.06),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: AppColors.secondary.withOpacity(0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.auto_awesome_rounded,
                        color: AppColors.secondary, size: 26),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Gemini AI Verification',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('Smart syllabus tracking',
                          style: TextStyle(
                              color: cs.onSurface.withOpacity(0.55),
                              fontSize: 12)),
                    ],
                  ),
                ]),
                const SizedBox(height: 16),
                _StepRow(n: '1', text: 'Open your textbook or notebook to the chapter you studied'),
                _StepRow(n: '2', text: 'Capture a clear photo of the page text'),
                _StepRow(n: '3', text: 'AI reads and maps it against your official syllabus'),
                _StepRow(n: '4', text: 'See your progress — then answer 3-5 questions for +${AppConstants.studyMissionXP} XP'),
              ],
            ),
          ),

          if (_errorMsg != null) ...[
            const SizedBox(height: 16),
            _ErrorBanner(message: _errorMsg!),
          ],

          const SizedBox(height: 28),

          if (_imageBytes != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.memory(_imageBytes!,
                  height: 180, width: double.infinity, fit: BoxFit.cover),
            ),
            const SizedBox(height: 16),
          ],

          // Camera button
          FilledButton.icon(
            onPressed: () => _pickPhoto(ImageSource.camera),
            icon: const Icon(Icons.camera_alt_rounded),
            label: Text(
              _imageBytes == null ? 'Capture Study Page' : 'Retake Photo',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: AppColors.secondary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _pickPhoto(ImageSource.gallery),
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Choose from Gallery'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ─── 2. Processing View ──────────────────────────────────────────────────────
  Widget _buildProcessingView() {
    final cs = Theme.of(context).colorScheme;
    final isComparing = _processingPhase == _ProcessingPhase.comparing;

    return Center(
      key: const ValueKey('processing'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_imageBytes != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.memory(_imageBytes!,
                    height: 200, width: double.infinity, fit: BoxFit.cover),
              ),
            const SizedBox(height: 36),

            // Pulsing Gemini icon
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.9, end: 1.05),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeInOut,
              builder: (_, scale, child) =>
                  Transform.scale(scale: scale, child: child),
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary, AppColors.secondary],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.auto_awesome_rounded,
                    color: Colors.white, size: 32),
              ),
            ),
            const SizedBox(height: 20),

            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: Text(
                isComparing
                    ? 'Checking your syllabus…'
                    : 'Reading your study page…',
                key: ValueKey(isComparing),
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              isComparing
                  ? 'Comparing your notes to the official syllabus PDF'
                  : 'Gemini AI is extracting text from your photo',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: cs.onSurface.withOpacity(0.55), fontSize: 13),
            ),
            const SizedBox(height: 28),

            // Step dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ProcessDot(active: true, done: isComparing, label: 'Reading'),
                _ProcessConnector(done: isComparing),
                _ProcessDot(active: isComparing, done: false, label: 'Checking'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── 3. Coverage View (NEW — syllabus progress) ──────────────────────────────
  Widget _buildCoverageView() {
    final cs = Theme.of(context).colorScheme;
    final result = _geminiResult!;
    final coverage = result.coverage;
    final percent = coverage?.completedPercent ?? 0;
    final covered = coverage?.topicsCovered ?? [];
    final remaining = coverage?.topicsRemaining ?? [];

    return SingleChildScrollView(
      key: const ValueKey('coverage'),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Chapter identified card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child:
                      const Icon(Icons.check_circle_rounded, color: Colors.green, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Chapter Identified!',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.green)),
                      const SizedBox(height: 3),
                      Text(
                        result.matchedChapterName ?? 'Chapter Match',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                      if (result.syllabusAvailable)
                        const Text('✓ Verified against your textbook',
                            style: TextStyle(fontSize: 12, color: Colors.green)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Completion progress
          Text('Syllabus Completion',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: cs.onSurface)),
          const SizedBox(height: 10),

          AnimatedBuilder(
            animation: _progressAnim,
            builder: (_, __) {
              final pct = _progressAnim.value;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(100),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 12,
                      backgroundColor: cs.outlineVariant.withOpacity(0.25),
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppColors.secondary),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${(pct * 100).round()}% complete',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.secondary),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 24),

          // Topics covered
          if (covered.isNotEmpty) ...[
            Row(children: [
              Icon(Icons.check_circle_rounded,
                  color: Colors.green, size: 18),
              const SizedBox(width: 8),
              Text('Topics You Covered',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: cs.onSurface)),
            ]),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: covered
                  .map((t) => _TopicPill(label: t, type: _PillType.covered))
                  .toList(),
            ),
            const SizedBox(height: 20),
          ],

          // Topics remaining
          if (remaining.isNotEmpty) ...[
            Row(children: [
              Icon(Icons.schedule_rounded,
                  color: Colors.orange.shade700, size: 18),
              const SizedBox(width: 8),
              Text('Still To Study',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: cs.onSurface)),
            ]),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: remaining
                  .map((t) => _TopicPill(label: t, type: _PillType.remaining))
                  .toList(),
            ),
            const SizedBox(height: 24),
          ],

          // XP reward banner
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.amber.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.star_rounded, color: Colors.amber, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _questions.isEmpty
                        ? 'No questions available for this chapter yet.'
                        : 'Answer ${_questions.length} questions to earn +${AppConstants.studyMissionXP} XP',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.amber,
                        fontSize: 13),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          if (_questions.isNotEmpty)
            FilledButton.icon(
              onPressed: () => setState(() => _step = _StudyStep.quiz),
              icon: const Icon(Icons.quiz_outlined),
              label: const Text('Start Knowledge Check',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            )
          else
            FilledButton(
              onPressed: () => context.pop(),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Back to Missions'),
            ),

          const SizedBox(height: 12),
          TextButton(
            onPressed: () => setState(() {
              _step = _StudyStep.capture;
              _errorMsg = null;
            }),
            child: const Text('Retake Photo'),
          ),
        ],
      ),
    );
  }

  // ─── 4. Quiz View ────────────────────────────────────────────────────────────
  Widget _buildQuizView() {
    final cs = Theme.of(context).colorScheme;
    final q = _questions[_currentQ];
    final selected = _userAnswers[_currentQ];

    return Column(
      key: const ValueKey('quiz'),
      children: [
        LinearProgressIndicator(
          value: (_currentQ + 1) / _questions.length,
          minHeight: 5,
          backgroundColor: cs.outlineVariant.withOpacity(0.3),
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.secondary),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Question counter
                Text('Question ${_currentQ + 1} of ${_questions.length}',
                    style: TextStyle(
                        color: cs.onSurface.withOpacity(0.5), fontSize: 13)),
                const SizedBox(height: 12),
                Text(
                  q.text,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 17, height: 1.4),
                ),
                const SizedBox(height: 24),

                ...List.generate(q.options.length, (i) {
                  final isSelected = selected == i;
                  return GestureDetector(
                    onTap: () => _selectAnswer(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 14),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary.withOpacity(0.1)
                            : cs.surfaceVariant.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : cs.outlineVariant.withOpacity(0.4),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected
                                  ? AppColors.primary
                                  : cs.outlineVariant.withOpacity(0.25),
                            ),
                            child: Center(
                              child: isSelected
                                  ? const Icon(Icons.check_rounded,
                                      size: 16, color: Colors.white)
                                  : Text(
                                      String.fromCharCode(65 + i),
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color:
                                              cs.onSurface.withOpacity(0.5)),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(q.options[i],
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal)),
                          ),
                        ],
                      ),
                    ),
                  );
                }),

                const SizedBox(height: 16),
                FilledButton(
                  onPressed: selected != null ? _nextQuestion : null,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    _currentQ < _questions.length - 1
                        ? 'Next Question'
                        : 'Submit Answers',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── 5. Result View ──────────────────────────────────────────────────────────
  Widget _buildResultView() {
    final cs = Theme.of(context).colorScheme;
    final score = _finalScore ?? 0.0;
    final passed = score >= AppConstants.quizPassThreshold;
    final correct = (_questions.isNotEmpty)
        ? (_questions.length * score).round()
        : 0;
    final percent =
        _geminiResult?.coverage?.completedPercent ?? 0;

    return SingleChildScrollView(
      key: const ValueKey('result'),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),

          // Result icon
          Center(
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (passed ? Colors.green : cs.error).withOpacity(0.1),
              ),
              child: Icon(
                passed
                    ? Icons.emoji_events_rounded
                    : Icons.replay_rounded,
                size: 60,
                color: passed ? Colors.green : cs.error,
              ),
            ),
          ),
          const SizedBox(height: 20),

          Center(
            child: Text(
              passed ? '🎉 Study Verified!' : 'Almost There!',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: passed ? Colors.green : cs.error),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              passed
                  ? 'You answered $correct/${_questions.length} correctly.\n+${AppConstants.studyMissionXP} XP added to your profile!'
                  : 'You got $correct/${_questions.length} correct.\nYou need 60% to pass. Review and try again tomorrow.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: cs.onSurface.withOpacity(0.65),
                  fontSize: 14,
                  height: 1.5),
            ),
          ),

          const SizedBox(height: 28),

          // Stats row: quiz score + syllabus %
          Row(
            children: [
              Expanded(
                child: _ResultStatCard(
                  label: 'Quiz Score',
                  value: '${(score * 100).round()}%',
                  icon: Icons.quiz_rounded,
                  color: passed ? Colors.green : cs.error,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ResultStatCard(
                  label: 'Syllabus',
                  value: '$percent%',
                  icon: Icons.menu_book_rounded,
                  color: AppColors.secondary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 28),

          // Back button
          FilledButton(
            onPressed: () => context.pop(),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 15),
              backgroundColor: passed ? Colors.green : AppColors.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Back to Missions',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─── Helper Widgets ───────────────────────────────────────────────────────────

class _StepRow extends StatelessWidget {
  const _StepRow({required this.n, required this.text});
  final String n;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            margin: const EdgeInsets.only(right: 10, top: 1),
            decoration: BoxDecoration(
              color: AppColors.secondary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(n,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
            ),
          ),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    color:
                        Theme.of(context).colorScheme.onSurface.withOpacity(0.75),
                    fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.error.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.error.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: cs.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: TextStyle(color: cs.error, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

enum _PillType { covered, remaining }

class _TopicPill extends StatelessWidget {
  const _TopicPill({required this.label, required this.type});
  final String label;
  final _PillType type;

  @override
  Widget build(BuildContext context) {
    final isCovered = type == _PillType.covered;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isCovered
            ? Colors.green.withOpacity(0.1)
            : Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: isCovered
              ? Colors.green.withOpacity(0.4)
              : Colors.orange.withOpacity(0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isCovered ? Icons.check_circle_rounded : Icons.schedule_rounded,
            size: 14,
            color: isCovered ? Colors.green : Colors.orange.shade700,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isCovered ? Colors.green.shade800 : Colors.orange.shade800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProcessDot extends StatelessWidget {
  const _ProcessDot(
      {required this.active, required this.done, required this.label});
  final bool active;
  final bool done;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = done
        ? Colors.green
        : active
            ? AppColors.primary
            : Theme.of(context).colorScheme.outlineVariant;
    return Column(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done
                ? Colors.green
                : active
                    ? AppColors.primary
                    : Theme.of(context).colorScheme.outlineVariant.withOpacity(0.4),
          ),
          child: Center(
            child: done
                ? const Icon(Icons.check_rounded,
                    color: Colors.white, size: 16)
                : active
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const SizedBox(),
          ),
        ),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _ProcessConnector extends StatelessWidget {
  const _ProcessConnector({required this.done});
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 2,
      margin: const EdgeInsets.only(bottom: 20, left: 6, right: 6),
      color: done
          ? Colors.green
          : Theme.of(context).colorScheme.outlineVariant.withOpacity(0.3),
    );
  }
}

class _ResultStatCard extends StatelessWidget {
  const _ResultStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 24, color: color)),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55))),
        ],
      ),
    );
  }
}
