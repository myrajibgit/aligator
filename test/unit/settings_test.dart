import 'package:flutter_test/flutter_test.dart';

// Test model representing settings state and compliance policy rules
class UserSettingsState {
  final bool notificationsEnabled;
  final bool hapticsEnabled;
  final bool soundEnabled;
  final String displayName;
  final String bio;

  const UserSettingsState({
    this.notificationsEnabled = true,
    this.hapticsEnabled = true,
    this.soundEnabled = true,
    this.displayName = '',
    this.bio = '',
  });

  UserSettingsState copyWith({
    bool? notificationsEnabled,
    bool? hapticsEnabled,
    bool? soundEnabled,
    String? displayName,
    String? bio,
  }) {
    return UserSettingsState(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      displayName: displayName ?? this.displayName,
      bio: bio ?? this.bio,
    );
  }
}

class ComplianceValidator {
  static const int minAge = 13;

  static bool isAgeEligible(int age) {
    return age >= minAge;
  }

  static bool validateDisplayName(String name) {
    return name.trim().isNotEmpty && name.trim().length <= 50;
  }

  static bool validateBio(String bio) {
    return bio.length <= 160;
  }

  static List<String> getPurgeCollections(String uid) {
    return [
      'users/$uid/streaks',
      'users/$uid/inventory',
      'users/$uid/studyHashes',
      'users/$uid',
      'profiles/$uid/avatar.jpg',
    ];
  }
}

void main() {
  group('Settings & App Store Compliance Suite', () {
    test('default settings have notifications, haptics, and sound enabled', () {
      const settings = UserSettingsState();
      expect(settings.notificationsEnabled, isTrue);
      expect(settings.hapticsEnabled, isTrue);
      expect(settings.soundEnabled, isTrue);
      expect(settings.displayName, isEmpty);
      expect(settings.bio, isEmpty);
    });

    test('updates preference toggles immutably', () {
      const initial = UserSettingsState();
      final updated = initial.copyWith(
        notificationsEnabled: false,
        hapticsEnabled: false,
        soundEnabled: false,
      );

      expect(updated.notificationsEnabled, isFalse);
      expect(updated.hapticsEnabled, isFalse);
      expect(updated.soundEnabled, isFalse);
      expect(initial.notificationsEnabled, isTrue); // immutability check
    });

    test('enforces 13+ age compliance policy (COPPA, GDPR-K, DPDP)', () {
      expect(ComplianceValidator.isAgeEligible(12), isFalse);
      expect(ComplianceValidator.isAgeEligible(13), isTrue);
      expect(ComplianceValidator.isAgeEligible(17), isTrue);
      expect(ComplianceValidator.isAgeEligible(21), isTrue);
    });

    test('validates display name rules for student safety', () {
      expect(ComplianceValidator.validateDisplayName(''), isFalse);
      expect(ComplianceValidator.validateDisplayName('   '), isFalse);
      expect(ComplianceValidator.validateDisplayName('Sung Jinwoo'), isTrue);
      expect(ComplianceValidator.validateDisplayName('A' * 51), isFalse);
    });

    test('validates bio length constraints', () {
      expect(ComplianceValidator.validateBio('Aspiring S-Rank Hunter'), isTrue);
      expect(ComplianceValidator.validateBio('X' * 160), isTrue);
      expect(ComplianceValidator.validateBio('X' * 161), isFalse);
    });

    test('generates comprehensive purge paths for App Store account deletion', () {
      const testUid = 'user_abc_789';
      final paths = ComplianceValidator.getPurgeCollections(testUid);

      expect(paths, contains('users/$testUid/streaks'));
      expect(paths, contains('users/$testUid/inventory'));
      expect(paths, contains('users/$testUid/studyHashes'));
      expect(paths, contains('users/$testUid'));
      expect(paths, contains('profiles/$testUid/avatar.jpg'));
      expect(paths.length, equals(5));
    });
  });
}
