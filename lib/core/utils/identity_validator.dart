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
    if (phone.toLowerCase().contains('shadow_')) return false;
    // Allow digits, spaces, plus, minus, parentheses
    final validChars = RegExp(r'^[\+0-9\s\-\(\)]+$');
    return validChars.hasMatch(phone.trim());
  }
}
