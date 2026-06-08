import 'dart:convert';

// ─── Centralised backend-error → translation-key mapping ─────────────────────
//
// Every 4xx/5xx response body has the shape:
//   { "success": false, "message": "...", "errorCode": "SOME_CODE", "data": null }
//
// Add a new entry here whenever the backend introduces a new errorCode.
// Keys must match your assets/translations/*.json structure.

const Map<String, String> _kErrorMap = {
  // ── Generic backend codes ─────────────────────────────────────────────────
  'AUTH_ERROR':               'auth.errorInvalidCredentials',
  'NOT_FOUND':                'auth.errorServer',
  'VALIDATION_ERROR':         'auth.errorServer',
  'INTERNAL_ERROR':           'auth.errorServer',

  // ── Auth ──────────────────────────────────────────────────────────────────
  'INVALID_CREDENTIALS':      'auth.errorInvalidCredentials',
  'USER_NOT_FOUND':           'auth.errorInvalidCredentials',
  'ACCOUNT_DISABLED':         'auth.errorAccountDisabled',
  'TOKEN_EXPIRED':            'auth.errorTimeout',
  'INVALID_TOKEN':            'auth.errorInvalidCredentials',
  'INVALID_CODE':             'auth.errorInvalidCode',
  'CODE_EXPIRED':             'auth.errorInvalidCode',

  // ── Profile ───────────────────────────────────────────────────────────────
  'EMAIL_ALREADY_IN_USE':     'profile.errorEmailInUse',
  'PROFILE_UPDATE_FAILED':    'profile.updateError',

  // ── Students ──────────────────────────────────────────────────────────────
  'STUDENT_NOT_FOUND':        'student.updateError',
  'STUDENT_ALREADY_EXISTS':   'student.createError',

  // ── Events ────────────────────────────────────────────────────────────────
  'EVENT_NOT_FOUND':          'eventForm.updateError',
  'EVENT_CAPACITY_EXCEEDED':  'school.seatsFmt',

  // ── Wardrobe / Costumes ───────────────────────────────────────────────────
  'COSTUME_NOT_FOUND':        'wardrobe.loadError',
  'COSTUME_ALREADY_ASSIGNED': 'wardrobe.alreadyAssigned',
  'COSTUME_NO_STOCK':         'wardrobe.noStock',
  'COSTUME_DUPLICATE_NAME':   'wardrobe.duplicateName',
  'COSTUME_INVALID_STATUS':   'wardrobe.invalidStatus',
  'ASSIGNMENT_NOT_FOUND':     'wardrobe.returnError',
};

/// Parses a backend error response body and returns the best translation key.
///
/// Usage in any service:
/// ```dart
/// if (res.statusCode >= 400) {
///   throw SomeException(ApiError.trKey(res.body, res.statusCode));
/// }
/// ```
class ApiError {
  ApiError._();

  /// Extracts `errorCode` from the JSON body and maps it to a translation key.
  /// Falls back to a generic key derived from [statusCode] if the code is
  /// unknown or the body cannot be parsed.
  static String trKey(String body, int statusCode) {
    final code = _extractCode(body);
    if (code != null && _kErrorMap.containsKey(code)) {
      return _kErrorMap[code]!;
    }
    return _fallback(statusCode);
  }

  /// Returns the raw `errorCode` string from the body, or null.
  static String? errorCode(String body) => _extractCode(body);

  /// Returns the best user-facing message string (not a translation key).
  ///
  /// For codes where the backend `message` carries specific detail
  /// (e.g. COSTUME_NO_STOCK includes the item name), we use it directly.
  /// Otherwise falls back to [trKey] so the caller can call `.tr()`.
  static String userMessage(String body, int statusCode) {
    const useRawMessage = {
      'COSTUME_NO_STOCK',
      'COSTUME_DUPLICATE_NAME',
      'COSTUME_INVALID_STATUS',
      'VALIDATION_ERROR',
    };
    final code = _extractCode(body);
    if (code != null && useRawMessage.contains(code)) {
      final raw = message(body);
      if (raw != null && raw.isNotEmpty) return raw;
    }
    return trKey(body, statusCode);
  }

  /// Returns the `message` string from the body, or null.
  static String? message(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      return json['message'] as String?;
    } catch (_) {
      return null;
    }
  }

  // ── Internals ──────────────────────────────────────────────────────────────
  static String? _extractCode(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final code = json['errorCode'];
      if (code is String && code.isNotEmpty) return code;
      return null;
    } catch (_) {
      return null;
    }
  }

  static String _fallback(int statusCode) {
    if (statusCode == 401 || statusCode == 403) return 'auth.errorInvalidCredentials';
    if (statusCode == 404) return 'form.noResults';
    if (statusCode == 409) return 'auth.errorServer';
    if (statusCode >= 500) return 'auth.errorServer';
    return 'auth.errorServer';
  }
}
