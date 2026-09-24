import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/onboarding_service.dart';
import '../models/school_model.dart';
import '../models/class_model.dart';
import '../models/subject_model.dart';

class OnboardingState {
  final String displayName;
  final String username;
  final String bio;
  final String? photoUrl;
  final SchoolModel? selectedSchool;
  final ClassModel? selectedClass;
  final String? selectedStream;
  final List<SubjectModel> selectedSubjects;
  final bool isLoading;
  final String? error;

  const OnboardingState({
    this.displayName = '',
    this.username = '',
    this.bio = '',
    this.photoUrl,
    this.selectedSchool,
    this.selectedClass,
    this.selectedStream,
    this.selectedSubjects = const [],
    this.isLoading = false,
    this.error,
  });

  OnboardingState copyWith({
    String? displayName,
    String? username,
    String? bio,
    String? photoUrl,
    SchoolModel? selectedSchool,
    ClassModel? selectedClass,
    String? selectedStream,
    List<SubjectModel>? selectedSubjects,
    bool? isLoading,
    String? error,
  }) {
    return OnboardingState(
      displayName: displayName ?? this.displayName,
      username: username ?? this.username,
      bio: bio ?? this.bio,
      photoUrl: photoUrl ?? this.photoUrl,
      selectedSchool: selectedSchool ?? this.selectedSchool,
      selectedClass: selectedClass ?? this.selectedClass,
      selectedStream: selectedStream ?? this.selectedStream,
      selectedSubjects: selectedSubjects ?? this.selectedSubjects,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

final onboardingServiceProvider = Provider<OnboardingService>((ref) {
  return OnboardingService(FirebaseFirestore.instance);
});

final schoolSearchProvider = FutureProvider.family<List<SchoolModel>, String>((ref, query) {
  final service = ref.watch(onboardingServiceProvider);
  return service.searchSchools(query);
});

final classesForSchoolProvider = FutureProvider.family<List<ClassModel>, String>((ref, schoolId) {
  final service = ref.watch(onboardingServiceProvider);
  return service.getClassesForSchool(schoolId);
});

final subjectsForClassProvider = FutureProvider.family<List<SubjectModel>, String>((ref, classId) {
  final service = ref.watch(onboardingServiceProvider);
  return service.getSubjectsForClass(classId);
});

class OnboardingNotifier extends StateNotifier<OnboardingState> {
  final Ref ref;

  OnboardingNotifier(this.ref) : super(const OnboardingState());

  void updateProfileData({
    required String displayName,
    required String username,
    required String bio,
    String? photoUrl,
  }) {
    state = state.copyWith(
      displayName: displayName,
      username: username,
      bio: bio,
      photoUrl: photoUrl ?? state.photoUrl,
    );
  }

  void selectSchool(SchoolModel school) {
    state = state.copyWith(selectedSchool: school);
  }

  void selectClass(ClassModel classModel, String stream) {
    state = state.copyWith(selectedClass: classModel, selectedStream: stream);
  }

  void toggleSubject(SubjectModel subject) {
    final subjects = List<SubjectModel>.from(state.selectedSubjects);
    if (subjects.any((s) => s.id == subject.id)) {
      subjects.removeWhere((s) => s.id == subject.id);
    } else {
      subjects.add(subject);
    }
    state = state.copyWith(selectedSubjects: subjects);
  }

  void selectAllSubjects(List<SubjectModel> subjects) {
    state = state.copyWith(selectedSubjects: subjects);
  }

  Future<void> saveProfile(String uid) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await ref.read(onboardingServiceProvider).saveUserProfile(
        uid: uid,
        displayName: state.displayName,
        username: state.username,
        bio: state.bio,
        photoUrl: state.photoUrl,
      );
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> submitRequest({
    required String name,
    required String city,
    required String country,
    required String submittedBy,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await ref.read(onboardingServiceProvider).submitSchoolRequest(
        name: name,
        city: city,
        country: country,
        submittedBy: submittedBy,
      );
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> complete(String uid) async {
    if (state.selectedSchool == null || state.selectedClass == null || state.selectedStream == null) {
      state = state.copyWith(error: 'Missing required selections');
      return;
    }

    state = state.copyWith(isLoading: true, error: null);
    try {
      await ref.read(onboardingServiceProvider).completeOnboarding(
        uid: uid,
        schoolId: state.selectedSchool!.id,
        classId: state.selectedClass!.id,
        streamId: state.selectedStream!,
        area: state.selectedSchool!.city,
        subjectIds: state.selectedSubjects.map((s) => s.id).toList(),
      );
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }
}

final onboardingNotifierProvider =
    StateNotifierProvider<OnboardingNotifier, OnboardingState>((ref) {
  return OnboardingNotifier(ref);
});
