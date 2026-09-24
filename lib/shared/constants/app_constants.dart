class AppConstants {
  // Collection Names
  static const String usersCollection = 'users';
  static const String schoolsCollection = 'schools';
  static const String classesCollection = 'classes';
  static const String subjectsCollection = 'subjects';
  static const String questionBankCollection = 'questionBank';
  static const String missionsCollection = 'missions';
  static const String chatsCollection = 'chats';
  static const String partiesCollection = 'parties';
  static const String leaderboardsCollection = 'leaderboards';
  static const String battlesCollection = 'battles';
  static const String schoolRequestsCollection = 'schoolRequests';
  static const String syllabiCollection = 'syllabi';
  static const String verifyStudyNotesFunction = 'verifyStudyNotes';

  // App Config
  static const int maxPartySize = 6;
  static const int minPartySize = 2;
  static const int dailyFitnessMinutes = 30;
  static const int quizQuestionsPerMission = 5;
  static const double quizPassThreshold = 0.6;

  // XP Values
  static const int subjectMissionXP = 50;
  static const int fitnessMissionXP = 30;
  static const int studyMissionXP = 80;
  static const int dailyCrateXP = 30;
  /// XP awarded per completed Focus Session interval (e.g. 25-min Pomodoro).
  static const int focusSessionXP = 20;
  /// Bonus XP added when a hunter's INT stat is high (>= 60) on knowledge tasks.
  static const int intStatBonusXP = 10;
  /// Fatigue reduction (%) granted after completing a full focus session.
  static const int focusFatigueReduction = 10;
}
