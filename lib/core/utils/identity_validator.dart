class IdentityValidator {
  /// Returns true if the string is a valid email (contains '@' and isn't empty)
  static bool isValidEmail(String? email) {
    if (email == null || email.trim().isEmpty) return false;
    return email.contains('@');
  }

  /// Returns true if the string is a valid phone number (not an email, no '@', not empty)
  static bool isValidPhone(String? phone) {
    if (phone == null || phone.trim().isEmpty) return false;
    if (phone.contains('@')) return false;
    return true;
  }
}
