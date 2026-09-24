import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studycompete/features/auth/providers/auth_provider.dart';
import 'shared/router/app_router.dart';
import 'shared/services/notification_service.dart';
import 'shared/theme/app_theme.dart';

class StudyCompeteApp extends ConsumerStatefulWidget {
  const StudyCompeteApp({super.key});

  @override
  ConsumerState<StudyCompeteApp> createState() => _StudyCompeteAppState();
}

class _StudyCompeteAppState extends ConsumerState<StudyCompeteApp> {
  bool _notificationsInitialized = false;

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final authState = ref.watch(authStateProvider);

    // Initialize notifications once the user is signed in and we have a context
    if (!_notificationsInitialized && authState.value != null) {
      _notificationsInitialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (mounted) {
          await NotificationService().init(context);
        }
      });
    }

    return MaterialApp.router(
      title: 'StudyCompete',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
