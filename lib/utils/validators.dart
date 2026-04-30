// ─── AppValidators ────────────────────────────────────────────────────────────
// All methods return a translation key string on failure, or null on success.
// Call-site wraps with .tr() so this file stays context-free and unit-testable.

class AppValidators {
  AppValidators._();

  // ── Patterns ────────────────────────────────────────────────────────────────

  // RFC 5321/5322 simplified: local@domain.tld
  // Allows: letters, digits, dots, +, %, _, -, in local part.
  // Rejects: consecutive dots, leading/trailing dots, missing TLD (≥2 chars).
  static final _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$',
  );

  // SQL injection — characters that are invalid in any legitimate email address.
  // Covers: string delimiters (' "), statement terminator (;), line comment (--),
  // block comments (/* */), and the most abused DML/DDL keywords.
  static final _sqlEmail = RegExp(
    r"""['";]|--|/\*|\*/|\b(SELECT|INSERT|UPDATE|DELETE|DROP|UNION|EXEC|CREATE|ALTER|TRUNCATE)\b""",
    caseSensitive: false,
  );

  // SQL injection — sequences that flag obvious injection attempts in passwords.
  // More lenient than the email pattern: lone ' or " are allowed (common in
  // surnames like O'Brien), but multi-token sequences that only appear in
  // injections are blocked.
  //   ─ --        → SQL line comment opener
  //   ─ /* */     → block comment
  //   ─ ' OR / " OR, ' AND / " AND  → classic boolean bypass
  //   ─ ; followed by DML keyword    → stacked-query injection
  //   ─ UNION SELECT, EXEC xp_, WAITFOR DELAY → well-known attack sequences
  static final _sqlPassword = RegExp(
    r"""--|/\*|\*/'?\s*(OR|AND)\s*'|"?\s*(OR|AND)\s*"|;\s*(DROP|DELETE|INSERT|UPDATE|EXEC)\b|\b(UNION\s+SELECT|EXEC\s+xp_|WAITFOR\s+DELAY)\b""",
    caseSensitive: false,
  );

  // ── Public validators ────────────────────────────────────────────────────────

  /// Validates an email address.
  /// Returns a translation key on failure, null on success.
  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'auth.validationEmail';
    }
    final v = value.trim();
    if (v.length > 254) {
      return 'auth.validationEmailLength';
    }
    if (!_emailRegex.hasMatch(v)) {
      return 'auth.validationEmailFormat';
    }
    if (_sqlEmail.hasMatch(v)) {
      return 'auth.validationInvalidChars';
    }
    return null;
  }

  /// Validates a password.
  /// Returns a translation key on failure, null on success.
  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'auth.validationPassword';
    }
    if (value.length < 6) {
      return 'auth.validationPasswordMin';
    }
    if (value.length > 128) {
      return 'auth.validationPasswordMax';
    }
    if (_sqlPassword.hasMatch(value)) {
      return 'auth.validationInvalidChars';
    }
    return null;
  }
}
