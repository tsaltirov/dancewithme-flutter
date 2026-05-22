import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_service.dart';

// ─── School model ─────────────────────────────────────────────────────────────
class School {
  final int    id;
  final String name;
  final String address;
  final String phone;
  final String email;
  final String imageUrl;
  final String userId;
  final bool   active;

  const School({
    required this.id,
    required this.name,
    required this.address,
    required this.phone,
    required this.email,
    required this.imageUrl,
    required this.userId,
    required this.active,
  });

  bool get hasImage => imageUrl.isNotEmpty;

  factory School.fromJson(Map<String, dynamic> j) => School(
        id:       (j['id'] as num?)?.toInt() ?? 0,
        name:     j['name']     as String? ?? '',
        address:  j['address']  as String? ?? '',
        phone:    j['phone']    as String? ?? '',
        email:    j['email']    as String? ?? '',
        imageUrl: j['imageUrl'] as String? ?? '',
        userId:   j['userId']   as String? ?? '',
        active:   j['active']   as bool?   ?? true,
      );
}

// ─── Typed error ──────────────────────────────────────────────────────────────
class SchoolException implements Exception {
  final String message;
  const SchoolException(this.message);
  @override String toString() => message;
}

// ─── SchoolService ────────────────────────────────────────────────────────────
class SchoolService {
  SchoolService._();

  static const _bucket = 'dancewithme';
  static const _folder = 'schools';

  static String get _baseUrl {
    final raw = dotenv.env['BACKEND_URL'] ?? '';
    if (raw.isEmpty) throw const SchoolException('App configuration error');
    return raw.startsWith('http') ? raw : 'http://$raw';
  }

  // ── Filename-safe unique ID (timestamp + random, no Web Crypto needed) ────
  static String _uuid() {
    final rng = math.Random();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant
    final hex =
        bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }

  // ── Upload image → Supabase Storage → returns public URL ─────────────────
  // Bucket: dancewithme   Path: schools/{uuid}.{ext}
  static Future<String> uploadImage(Uint8List bytes, String ext) async {
    try {
      final supabase = Supabase.instance.client;
      final path = '$_folder/${_uuid()}.$ext';
      if (kDebugMode) debugPrint('[SchoolService] uploading image → $_bucket/$path (${bytes.length} bytes)');
      await supabase.storage.from(_bucket).uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(
          contentType: 'image/$ext',
          upsert: false,
        ),
      );
      final url = supabase.storage.from(_bucket).getPublicUrl(path);
      if (kDebugMode) debugPrint('[SchoolService] image public URL → $url');
      return url;
    } on StorageException catch (e) {
      throw SchoolException('Image upload failed: ${e.message}');
    } catch (e) {
      throw SchoolException('Image upload failed: $e');
    }
  }

  // ── GET /api/v1/schools/user/{userId} ────────────────────────────────────
  // Returns the list of schools owned by the authenticated user.
  static Future<List<School>> getUserSchools(String userId) async {
    final token = await AuthService.getAccessToken();
    if (token == null) throw const SchoolException('No authentication token found');

    final http.Response res;
    try {
      res = await http.get(
        Uri.parse('$_baseUrl/api/v1/schools/user/$userId'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const SchoolException('Request timed out');
    } catch (e) {
      throw SchoolException('Connection error: ${e.runtimeType}');
    }

    if (res.statusCode != 200) {
      throw SchoolException('Server returned ${res.statusCode}');
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final data = body['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => School.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── POST /api/v1/schools ──────────────────────────────────────────────────
  // Requires Bearer token from AuthService.
  // Body matches backend contract exactly.
  static Future<void> addSchool({
    required String name,
    required String address,
    required String phone,
    required String email,
    required String userId,
    String? imageUrl,
  }) async {
    final token = await AuthService.getAccessToken();
    if (token == null) {
      throw const SchoolException('No authentication token found');
    }

    final body = jsonEncode({
      'name': name.trim(),
      'address': address.trim(),
      'phone': phone.trim(),
      'email': email.trim().toLowerCase(),
      'imageUrl': imageUrl ?? '',
      'userId': userId,
    });
    if (kDebugMode) {
      debugPrint('[SchoolService] POST $_baseUrl/api/v1/schools');
      debugPrint('[SchoolService] body → $body');
    }

    final http.Response res;
    try {
      res = await http
          .post(
            Uri.parse('$_baseUrl/api/v1/schools'),
            headers: {
              'Content-Type': 'application/json; charset=UTF-8',
              'Authorization': 'Bearer $token',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const SchoolException('Request timed out — check your connection');
    } catch (e) {
      throw SchoolException('Connection error: ${e.runtimeType}');
    }

    if (kDebugMode) debugPrint('[SchoolService] response ${res.statusCode} → ${res.body}');

    if (res.statusCode != 200 && res.statusCode != 201) {
      throw SchoolException('Server returned ${res.statusCode}: ${res.body}');
    }
  }
}
