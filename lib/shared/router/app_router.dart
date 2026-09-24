import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:studycompete/features/auth/providers/auth_provider.dart';
import 'package:studycompete/features/auth/screens/login_screen.dart';
import 'package:studycompete/features/onboarding/screens/profile_setup_screen.dart';
import 'package:studycompete/features/onboarding/screens/school_selection_screen.dart';
import 'package:studycompete/features/onboarding/screens/class_selection_screen.dart';
import 'package:studycompete/features/onboarding/screens/subjects_confirm_screen.dart';
import 'package:studycompete/features/missions/screens/missions_screen.dart';
import 'package:studycompete/features/missions/screens/subject_quiz_screen.dart';
import 'package:studycompete/features/missions/screens/fitness_mission_screen.dart';
import 'package:studycompete/features/missions/screens/study_verification_screen.dart';
import 'package:studycompete/features/stats/screens/stats_screen.dart';
import 'package:studycompete/features/social/screens/social_hub_screen.dart';
import 'package:studycompete/features/social/screens/chat_screen.dart';
import 'package:studycompete/features/social/screens/parties_screen.dart';
import 'package:studycompete/features/competition/screens/competition_hub_screen.dart';
import 'package:studycompete/features/competition/screens/battle_duel_screen.dart';
import 'package:studycompete/features/competition/screens/new_challenge_screen.dart';
import 'package:studycompete/features/ai_assistant/screens/system_ai_screen.dart';
import 'package:studycompete/features/missions/screens/focus_session_screen.dart';
import 'package:studycompete/features/missions/screens/infinite_trial_screen.dart';
import 'package:studycompete/features/missions/screens/daily_agenda_screen.dart';
import 'package:studycompete/features/stats/screens/shadow_army_screen.dart';
import 'package:studycompete/features/stats/screens/relics_vault_screen.dart';
import 'package:studycompete/features/stats/screens/analytics_screen.dart';
import 'package:studycompete/features/settings/screens/settings_screen.dart';
import 'package:studycompete/features/social/screens/dungeon_gate_screen.dart';
import 'package:studycompete/features/missions/screens/offline_study_log_screen.dart';
import 'package:studycompete/features/stats/screens/subject_progress_screen.dart';
import 'package:studycompete/shared/widgets/bottom_nav.dart';


class OnboardingShell extends StatelessWidget {
  final Widget child;
  const OnboardingShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: child),
    );
  }
}

/// Dynamic provider watching user's onboarding completion status in Firestore
final onboardingCompleteProvider = StreamProvider<bool>((ref) {
  final authState = ref.watch(authStateProvider);
  final user = authState.value;
  if (user == null) return Stream.value(false);

  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .snapshots()
      .map((doc) => doc.data()?['onboardingComplete'] == true);
});

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final onboardingState = ref.watch(onboardingCompleteProvider);

  return GoRouter(
    initialLocation: '/home/missions',
    redirect: (context, state) {
      if (authState.isLoading) return null;

      final isAuth = authState.value != null;
      final isLoginLocation = state.uri.path == '/login';
      final isSplash = state.uri.path == '/';
      final onboardingComplete = onboardingState.value ?? false;

      if (!isAuth) {
        return isLoginLocation ? null : '/login';
      }

      if (isAuth && (isLoginLocation || isSplash)) {
        if (!onboardingComplete) {
          return '/onboarding/profile';
        } else {
          return '/home/missions';
        }
      }

      final isOnboardingLocation = state.uri.path.startsWith('/onboarding');

      if (isAuth && !onboardingComplete && !isOnboardingLocation) {
        return '/onboarding/profile';
      }

      if (isAuth && onboardingComplete && isOnboardingLocation) {
        return '/home/missions';
      }

      if (state.uri.path == '/home') {
        return '/home/missions';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => OnboardingShell(child: child),
        routes: [
          GoRoute(
            path: '/onboarding/profile',
            builder: (context, state) => const ProfileSetupScreen(),
          ),
          GoRoute(
            path: '/onboarding/school',
            builder: (context, state) => const SchoolSelectionScreen(),
          ),
          GoRoute(
            path: '/onboarding/class',
            builder: (context, state) => const ClassSelectionScreen(),
          ),
          GoRoute(
            path: '/onboarding/subjects',
            builder: (context, state) => const SubjectsConfirmScreen(),
          ),
        ],
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return Scaffold(
            body: navigationShell,
            bottomNavigationBar: AppBottomNav(navigationShell: navigationShell),
          );
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home/missions',
                builder: (context, state) {
                  final uid = ref.watch(currentUserProvider)?.uid ?? '';
                  return MissionsScreen(uid: uid);
                },
                routes: [
                  GoRoute(
                    path: 'quiz/:subjectId',
                    builder: (context, state) {
                      final uid = ref.watch(currentUserProvider)?.uid ?? '';
                      final subjectId = state.pathParameters['subjectId'] ?? '';
                      final subjectName = state.uri.queryParameters['subjectName'] ?? 'Subject';
                      return SubjectQuizScreen(
                        uid: uid,
                        subjectId: subjectId,
                        subjectName: subjectName,
                      );
                    },
                  ),
                  GoRoute(
                    path: 'fitness',
                    builder: (context, state) => const FitnessMissionScreen(),
                  ),
                  GoRoute(
                    path: 'study-verification',
                    builder: (context, state) => const StudyVerificationScreen(),
                  ),
                  GoRoute(
                    path: 'focus',
                    builder: (context, state) => const FocusSessionScreen(),
                  ),
                  GoRoute(
                    path: 'infinite-trial',
                    builder: (context, state) => const InfiniteTrialScreen(),
                  ),
                  GoRoute(
                    path: 'agenda',
                    builder: (context, state) {
                      final uid = ref.watch(currentUserProvider)?.uid ?? '';
                      return DailyAgendaScreen(uid: uid);
                    },
                  ),
                  GoRoute(
                    path: 'offline-log',
                    builder: (context, state) {
                      final uid = ref.watch(currentUserProvider)?.uid ?? '';
                      return OfflineStudyLogScreen(uid: uid);
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home/stats',
                builder: (context, state) {
                  final uid = ref.watch(currentUserProvider)?.uid ?? '';
                  return StatsScreen(uid: uid);
                },
                routes: [
                  GoRoute(
                    path: 'shadow-army',
                    builder: (context, state) => const ShadowArmyScreen(),
                  ),
                  GoRoute(
                    path: 'vault',
                    builder: (context, state) => const RelicsVaultScreen(),
                  ),
                  GoRoute(
                    path: 'analytics',
                    builder: (context, state) {
                      final uid = ref.watch(currentUserProvider)?.uid ?? '';
                      return AnalyticsScreen(uid: uid);
                    },
                  ),
                  GoRoute(
                    path: 'subject-progress',
                    builder: (context, state) {
                      final uid = ref.watch(currentUserProvider)?.uid ?? '';
                      return SubjectProgressScreen(uid: uid);
                    },
                  ),
                  GoRoute(
                    path: 'settings',
                    builder: (context, state) {
                      final uid = ref.watch(currentUserProvider)?.uid ?? '';
                      return SettingsScreen(uid: uid);
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home/social',
                builder: (context, state) => const SocialHubScreen(),
                routes: [
                  GoRoute(
                    path: 'chat/:chatId',
                    builder: (context, state) {
                      final extra = state.extra as Map<String, String>? ?? {};
                      return ChatScreen(
                        chatId: state.pathParameters['chatId'] ?? '',
                        chatTitle: extra['chatTitle'] ?? 'Chat',
                        chatType: extra['type'] ?? 'dm',
                      );
                    },
                  ),
                  GoRoute(
                    path: 'parties',
                    builder: (context, state) => const PartiesScreen(),
                  ),
                  GoRoute(
                    path: 'dungeon-gate/:partyId',
                    builder: (context, state) => DungeonGateScreen(
                      partyId: state.pathParameters['partyId'] ?? '',
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home/compete',
                builder: (context, state) => const CompetitionHubScreen(),
                routes: [
                  GoRoute(
                    path: 'duel/:battleId',
                    builder: (context, state) => BattleDuelScreen(
                      battleId: state.pathParameters['battleId'] ?? '',
                    ),
                  ),
                  GoRoute(
                    path: 'new-challenge',
                    builder: (context, state) => const NewChallengeScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home/system-ai',
                builder: (context, state) => const SystemAiScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
