/// Result returned by the [verifyStudyNotes] Cloud Function (Gemini-powered).
class GeminiVerificationResult {
  /// Whether the Cloud Function call succeeded.
  final bool success;

  /// Raw text extracted from the student's photo by Gemini Vision.
  final String? extractedText;

  /// Syllabus coverage analytics — only present when a syllabus PDF exists.
  final SyllabusCoverage? coverage;

  /// Best-matching chapter ID from either the PDF or Firestore keyword bank.
  final String? matchedChapterId;

  /// Human-readable chapter name.
  final String? matchedChapterName;

  /// Whether the admin has uploaded a PDF syllabus for this subject.
  final bool syllabusAvailable;

  /// Error message when [success] is false.
  final String? error;

  const GeminiVerificationResult({
    required this.success,
    this.extractedText,
    this.coverage,
    this.matchedChapterId,
    this.matchedChapterName,
    required this.syllabusAvailable,
    this.error,
  });

  factory GeminiVerificationResult.fromMap(Map<String, dynamic> map) {
    final coverageMap = map['coverage'] as Map<String, dynamic>?;
    return GeminiVerificationResult(
      success: map['success'] as bool? ?? false,
      extractedText: map['extractedText'] as String?,
      coverage:
          coverageMap != null ? SyllabusCoverage.fromMap(coverageMap) : null,
      matchedChapterId: map['matchedChapterId'] as String?,
      matchedChapterName: map['matchedChapterName'] as String?,
      syllabusAvailable: map['syllabusAvailable'] as bool? ?? false,
      error: map['error'] as String?,
    );
  }

  /// Convenience: true if a chapter was identified and coverage data is present.
  bool get hasMatch =>
      success && matchedChapterId != null && matchedChapterId!.isNotEmpty;
}

/// Syllabus coverage breakdown returned by the AI.
class SyllabusCoverage {
  /// Estimated completion percentage (0–100).
  final int completedPercent;

  /// List of topics the student's notes cover.
  final List<String> topicsCovered;

  /// List of topics not yet covered.
  final List<String> topicsRemaining;

  const SyllabusCoverage({
    required this.completedPercent,
    required this.topicsCovered,
    required this.topicsRemaining,
  });

  factory SyllabusCoverage.fromMap(Map<String, dynamic> map) {
    return SyllabusCoverage(
      completedPercent:
          (map['completedPercent'] as num?)?.toInt() ?? 0,
      topicsCovered:
          List<String>.from(map['topicsCovered'] as List? ?? []),
      topicsRemaining:
          List<String>.from(map['topicsRemaining'] as List? ?? []),
    );
  }
}
