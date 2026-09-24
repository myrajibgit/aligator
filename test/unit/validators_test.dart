import 'package:flutter_test/flutter_test.dart';
import 'package:studycompete/shared/utils/validators.dart';

void main() {
  group('Validators.isValidUsername', () {
    test('accepts valid usernames', () {
      expect(Validators.isValidUsername('alex_99'), isTrue);
      expect(Validators.isValidUsername('john_doe'), isTrue);
      expect(Validators.isValidUsername('abc'), isTrue);
      expect(Validators.isValidUsername('user_12345678901234'), isTrue);
    });

    test('rejects too short or too long usernames', () {
      expect(Validators.isValidUsername('ab'), isFalse);
      expect(Validators.isValidUsername('a' * 21), isFalse);
    });

    test('rejects usernames with invalid characters', () {
      expect(Validators.isValidUsername('alex@123'), isFalse);
      expect(Validators.isValidUsername('alex space'), isFalse);
      expect(Validators.isValidUsername('alex-doe'), isFalse);
    });
  });

  group('Validators.displayNameError', () {
    test('returns null for valid display name', () {
      expect(Validators.displayNameError('Alex Hunter'), isNull);
    });

    test('returns error for empty or too short display name', () {
      expect(Validators.displayNameError(''), isNotNull);
      expect(Validators.displayNameError('A'), isNotNull);
    });

    test('returns error for overly long display name', () {
      expect(Validators.displayNameError('A' * 51), isNotNull);
    });
  });

  group('Validators.bioError', () {
    test('returns null for valid bio or null bio', () {
      expect(Validators.bioError(null), isNull);
      expect(Validators.bioError('Leveling up my knowledge power!'), isNull);
    });

    test('returns error for bio longer than 160 characters', () {
      expect(Validators.bioError('A' * 161), isNotNull);
    });
  });
}
