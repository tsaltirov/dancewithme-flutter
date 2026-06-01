import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../utils/api_error.dart';

// ─── Storage keys ─────────────────────────────────────────────────────────────
const _kAccessToken   = 'auth_access_token';
const _kRefreshToken  = 'auth_refresh_token';
const _kUserId        = 'auth_user_id';
const _kUserName      = 'auth_user_name';
const _kUserLastName  = 'auth_user_last_name';
const _kUserEmail     = 'auth_user_email';
const _kUserRole      = 'auth_user_role';

// ─── Typed error ──────────────────────────────────────────────────────────────
class AuthException implements Exception {
  final String trKey;
  const AuthException(this.trKey);
}

// ─── User model ───────────────────────────────────────────────────────────────
class AuthUser {
  final String id;
  final String name;
  final String lastName;
  final String email;
  final String role;

  const AuthUser({
    required this.id,
    required this.name,
    required this.lastName,
    required this.email,
    required this.role,
  });

  String get fullName => '$name $lastName'.trim();

  factory AuthUser.fromJson(Map<String, dynamic> j) => AuthUser(
        id:       j['id']       as String? ?? '',
        name:     j['name']     as String? ?? '',
        lastName: j['lastName'] as String? ?? '',
        email:    j['email']    as String? ?? '',
        role:     j['role']     as String? ?? '',
      );
}

// ─── AuthService ──────────────────────────────────────────────────────────────
class AuthService {
  AuthService._();

  static const _storage = FlutterSecureStorage();

  // Prevents concurrent refresh calls — only one in-flight at a time.
  static Completer<String?>? _refreshCompleter;

  static String get _baseUrl {
    final raw = dotenv.env['BACKEND_URL'] ?? '';
    if (raw.isEmpty) throw const AuthException('auth.errorConfig');
    return raw.startsWith('http') ? raw : 'http://$raw';
  }

  // ── POST /api/v1/auth/login ───────────────────────────────────────────────
  // Expected 200 body:
  // { "success": true, "data": { "accessToken": "...", "refreshToken": "...",
  //   "user": { "id", "name", "lastName", "email", "role", ... } } }
  static Future<AuthUser> login(String email, String password) async {
    final http.Response res;

    try {
      res = await http
          .post(
            Uri.parse('$_baseUrl/api/v1/auth/login'),
            headers: {'Content-Type': 'application/json; charset=UTF-8'},
            body: jsonEncode({
              'email': email.trim().toLowerCase(),
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const AuthException('auth.errorTimeout');
    } on SocketException {
      throw const AuthException('auth.errorNoConnection');
    }

    switch (res.statusCode) {
      case 200:
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final data  = body['data']  as Map<String, dynamic>?;
        final token = data?['accessToken']  as String?;
        final refresh = data?['refreshToken'] as String?;
        final userJson = data?['user'] as Map<String, dynamic>?;

        if (data == null || token == null || token.isEmpty) {
          throw const AuthException('auth.errorServer');
        }

        final user = AuthUser.fromJson(userJson ?? {});

        await Future.wait([
          _storage.write(key: _kAccessToken,  value: token),
          if (refresh != null)
            _storage.write(key: _kRefreshToken, value: refresh),
          _storage.write(key: _kUserId,       value: user.id),
          _storage.write(key: _kUserName,     value: user.name),
          _storage.write(key: _kUserLastName, value: user.lastName),
          _storage.write(key: _kUserEmail,    value: user.email),
          _storage.write(key: _kUserRole,     value: user.role),
        ]);

        // Web: force IndexedDB key-commit to finish before the caller navigates.
        // Without this, HomeScreen._loadData reads null and bounces back to login.
        if (kIsWeb) await _safeRead(_kAccessToken);

        return user;

      case 401:
      case 403:
        throw AuthException(ApiError.trKey(res.body, res.statusCode));

      case >= 500:
        throw AuthException(ApiError.trKey(res.body, res.statusCode));

      default:
        throw AuthException(ApiError.trKey(res.body, res.statusCode));
    }
  }

  // ── Safe storage read — returns null instead of throwing on web crypto errors
  static Future<String?> _safeRead(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AuthService] storage read "$key" failed: $e');
        debugPrint('[AuthService] Clear browser data (IndexedDB + localStorage) and re-login.');
      }
      return null;
    }
  }

  // ── Extract user-id from JWT payload (no crypto needed — just base64) ─────
  // Fallback when FlutterSecureStorage read fails due to Web Crypto mismatch.
  static String? _idFromJwt(String token) {
    try {
      final parts = token.split('.');
      if (parts.length < 2) return null;
      // base64url → properly padded base64
      final padded = base64Url.normalize(parts[1]);
      final payload =
          jsonDecode(utf8.decode(base64Url.decode(padded))) as Map<String, dynamic>;
      // Try common claim names: sub, id, userId, uid
      return (payload['sub'] ?? payload['id'] ?? payload['userId'] ?? payload['uid'])
          ?.toString();
    } catch (_) {
      return null;
    }
  }

  // ── JWT expiry check ──────────────────────────────────────────────────────
  // Decodes the exp claim without verifying signature (no crypto needed).
  // Returns true when the token is expired or will expire within 60 seconds.
  static bool _isExpiredOrSoon(String token) {
    try {
      final parts = token.split('.');
      if (parts.length < 2) return true;
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      ) as Map<String, dynamic>;
      final exp = (payload['exp'] as num?)?.toInt();
      if (exp == null) return false;
      final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      return nowSec >= exp - 60; // 60-second buffer before actual expiry
    } catch (_) {
      return false;
    }
  }

  // ── Refresh — POST /api/v1/auth/refresh ───────────────────────────────────
  // Uses a Completer so that concurrent callers all wait for the same
  // in-flight request instead of each firing a separate refresh.
  static Future<String?> _tryRefresh() async {
    // If a refresh is already in progress, wait for its result.
    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }

    _refreshCompleter = Completer<String?>();
    String? result;

    try {
      final refreshToken = await _safeRead(_kRefreshToken);
      if (refreshToken == null || refreshToken.isEmpty) {
        if (kDebugMode) debugPrint('[AuthService] No refresh token — logging out');
        await logout();
        _refreshCompleter!.complete(null);
        return null;
      }

      final http.Response res;
      try {
        res = await http.post(
          Uri.parse('$_baseUrl/api/v1/auth/refresh'),
          headers: {'Content-Type': 'application/json; charset=UTF-8'},
          body: jsonEncode({'refreshToken': refreshToken}),
        ).timeout(const Duration(seconds: 15));
      } on TimeoutException {
        if (kDebugMode) debugPrint('[AuthService] Refresh timed out');
        _refreshCompleter!.complete(null);
        return null;
      } on SocketException {
        if (kDebugMode) debugPrint('[AuthService] Refresh — no connection');
        _refreshCompleter!.complete(null);
        return null;
      }

      if (kDebugMode) {
        debugPrint('[AuthService] POST /api/v1/auth/refresh → ${res.statusCode}');
      }

      if (res.statusCode == 200 || res.statusCode == 201) {
        final body      = jsonDecode(res.body) as Map<String, dynamic>;
        final data      = body['data'] as Map<String, dynamic>?;
        final newAccess  = data?['accessToken']  as String?;
        final newRefresh = data?['refreshToken'] as String?;

        if (newAccess == null || newAccess.isEmpty) {
          if (kDebugMode) debugPrint('[AuthService] Refresh returned empty token — logging out');
          await logout();
          _refreshCompleter!.complete(null);
          return null;
        }

        await Future.wait([
          _storage.write(key: _kAccessToken, value: newAccess),
          if (newRefresh != null && newRefresh.isNotEmpty)
            _storage.write(key: _kRefreshToken, value: newRefresh),
        ]);

        if (kDebugMode) debugPrint('[AuthService] Token refreshed successfully');
        result = newAccess;
      } else {
        // 401/403 means refresh token is also expired → force logout
        if (kDebugMode) {
          debugPrint('[AuthService] Refresh rejected (${res.statusCode}) — logging out');
        }
        await logout();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[AuthService] Refresh unexpected error: $e');
    } finally {
      _refreshCompleter!.complete(result);
      _refreshCompleter = null;
    }

    return result;
  }

  // ── Accessors ─────────────────────────────────────────────────────────────
  // getAccessToken() proactively refreshes when the JWT is about to expire.
  // All services call this method — refresh is fully transparent to them.
  static Future<String?> getAccessToken() async {
    final token = await _safeRead(_kAccessToken);
    if (token == null) return null;
    if (_isExpiredOrSoon(token)) {
      if (kDebugMode) debugPrint('[AuthService] Access token expired/near-expiry — refreshing');
      return _tryRefresh();
    }
    return token;
  }

  static Future<String?> getRefreshToken() => _safeRead(_kRefreshToken);
  static Future<bool>    isLoggedIn() async => (await getAccessToken()) != null;

  static Future<AuthUser?> getUser() async {
    var id = await _safeRead(_kUserId);

    // Fallback: decode JWT when storage read failed
    if (id == null) {
      final token = await _safeRead(_kAccessToken);
      if (token != null) {
        id = _idFromJwt(token);
        if (kDebugMode && id != null) {
          debugPrint('[AuthService] userId resolved from JWT: $id');
        }
      }
    }
    if (id == null) return null;

    return AuthUser(
      id:       id,
      name:     await _safeRead(_kUserName)     ?? '',
      lastName: await _safeRead(_kUserLastName) ?? '',
      email:    await _safeRead(_kUserEmail)    ?? '',
      role:     await _safeRead(_kUserRole)     ?? '',
    );
  }

  // ── POST /api/v1/auth/forgot-password — no Bearer required ──────────────
  // Sends a verification code to the given email.
  // Returns normally on 200/201; throws AuthException on failure.
  static Future<void> requestPasswordCode(String email) async {
    final http.Response res;
    try {
      res = await http
          .post(
            Uri.parse('$_baseUrl/api/v1/auth/forgot-password'),
            headers: {'Content-Type': 'application/json; charset=UTF-8'},
            body: jsonEncode({'email': email.trim().toLowerCase()}),
          )
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const AuthException('auth.errorTimeout');
    } on SocketException {
      throw const AuthException('auth.errorNoConnection');
    }

    // 200 / 201 → success.
    // Many backends return 200 even for unknown emails (security — no user enumeration).
    // Only treat 5xx (and unexpected 4xx) as errors.
    if (res.statusCode >= 400) {
      throw AuthException(ApiError.trKey(res.body, res.statusCode));
    }
  }

  // ── POST /api/v1/auth/reset-password — no Bearer required ───────────────
  // Body: { email, code, newPassword }
  static Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final http.Response res;
    try {
      res = await http
          .post(
            Uri.parse('$_baseUrl/api/v1/auth/reset-password'),
            headers: {'Content-Type': 'application/json; charset=UTF-8'},
            body: jsonEncode({
              'email':       email.trim().toLowerCase(),
              'code':        code.trim(),
              'newPassword': newPassword,
            }),
          )
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const AuthException('auth.errorTimeout');
    } on SocketException {
      throw const AuthException('auth.errorNoConnection');
    }

    if (res.statusCode == 200 || res.statusCode == 201) return;
    throw AuthException(ApiError.trKey(res.body, res.statusCode));
  }

  // ── Logout — wipes all stored credentials ─────────────────────────────────
  static Future<void> logout() async {
    await Future.wait([
      _storage.delete(key: _kAccessToken),
      _storage.delete(key: _kRefreshToken),
      _storage.delete(key: _kUserId),
      _storage.delete(key: _kUserName),
      _storage.delete(key: _kUserLastName),
      _storage.delete(key: _kUserEmail),
      _storage.delete(key: _kUserRole),
    ]);
  }

  // ── PATCH /api/v1/users/{id}/profile — update display name ──────────────
  // Updates name + lastName both on the backend and in local secure storage.
  // If the server call fails the local storage is still updated so the UI
  // reflects the change immediately (eventual consistency is acceptable here).
  static Future<void> updateProfile({
    required String userId,
    required String name,
    required String lastName,
    String?         imageUrl,
  }) async {
    final token = await getAccessToken();
    if (token == null) throw const AuthException('auth.errorConfig');

    try {
      final res = await http
          .patch(
            Uri.parse('$_baseUrl/api/v1/users/$userId/profile'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json; charset=UTF-8',
            },
            body: jsonEncode({
              'name':     name,
              'lastName': lastName,
              if (imageUrl != null && imageUrl.isNotEmpty) 'imageUrl': imageUrl,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (kDebugMode) {
        debugPrint('[AuthService] PATCH /api/v1/users/$userId/profile → ${res.statusCode}');
      }

      if (res.statusCode >= 400) throw AuthException(ApiError.trKey(res.body, res.statusCode));
    } on TimeoutException {
      throw const AuthException('auth.errorTimeout');
    } on SocketException {
      throw const AuthException('auth.errorNoConnection');
    }

    // Always persist to local storage regardless of server response code.
    await Future.wait([
      _storage.write(key: _kUserName,     value: name),
      _storage.write(key: _kUserLastName, value: lastName),
    ]);
  }
}
