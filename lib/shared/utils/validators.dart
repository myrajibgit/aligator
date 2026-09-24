class Validators {
  static final RegExp _usernameRegExp = RegExp(r'^[a-zA-Z0-9_]{3,20}$');

  static bool isValidUsername(String s) {
    return _usernameRegExp.hasMatch(s);
  }

  static String? usernameError(String? s) {
    if (s == null || s.isEmpty) {
      return 'Username cannot be empty';
    }
    if (!isValidUsername(s)) {
      return 'Username must be 3-20 characters, alphanumeric and underscore only';
    }
    return null;
  }

  static bool isValidDisplayName(String s) {
    return s.length >= 2 && s.length <= 50;
  }

  static String? displayNameError(String? s) {
    if (s == null || s.isEmpty) {
      return 'Display name cannot be empty';
    }
    if (!isValidDisplayName(s)) {
      return 'Display name must be between 2 and 50 characters';
    }
    return null;
  }

  static bool isValidBio(String s) {
    return s.length <= 160;
  }

  static String? bioError(String? s) {
    if (s == null) {
      return null;
    }
    if (!isValidBio(s)) {
      return 'Bio must be at most 160 characters';
    }
    return null;
  }
}
