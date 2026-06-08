import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_service.dart';
import '../utils/api_error.dart';

class CostumeException implements Exception {
  final String message;
  const CostumeException(this.message);
  @override String toString() => message;
}

// ─── Costume model ────────────────────────────────────────────────────────────
class Costume {
  final int     id;
  final int     schoolId;
  final String  name;
  final String  description;
  final String? imageUrl;
  final String? notes;
  final int     quantity;
  final bool    active;
  final String  createdAt;

  const Costume({
    required this.id,
    required this.schoolId,
    required this.name,
    required this.description,
    this.imageUrl,
    this.notes,
    required this.quantity,
    required this.active,
    required this.createdAt,
  });

  factory Costume.fromJson(Map<String, dynamic> j) => Costume(
        id:          (j['id']          as num).toInt(),
        schoolId:    (j['schoolId']    as num?)?.toInt()    ?? 0,
        name:        j['name']         as String?           ?? '',
        description: j['description']  as String?           ?? '',
        imageUrl:    j['imageUrl']     as String?,
        notes:       j['notes']        as String?,
        quantity:    (j['quantity']    as num?)?.toInt()    ?? 0,
        active:      j['active']       as bool?             ?? true,
        createdAt:   j['createdAt']    as String?           ?? '',
      );

  Costume copyWith({
    String? name, String? description, String? imageUrl,
    String? notes, int? quantity, bool? active,
  }) => Costume(
        id: id, schoolId: schoolId, createdAt: createdAt,
        name:        name        ?? this.name,
        description: description ?? this.description,
        imageUrl:    imageUrl    ?? this.imageUrl,
        notes:       notes       ?? this.notes,
        quantity:    quantity    ?? this.quantity,
        active:      active      ?? this.active,
      );
}

// ─── CostumeAssignment model ──────────────────────────────────────────────────
class CostumeAssignment {
  final int     id;
  final int     participationId;
  final String  studentName;
  final String  eventTitle;
  final int     costumeId;
  final String  costumeName;
  final String? costumeImageUrl;
  final String  status; // ENTREGADO | PENDIENTE_DEVOLUCION | DEVUELTO
  final String  deliveryDate;
  final String? returnDate;
  final String? observations;

  const CostumeAssignment({
    required this.id,
    required this.participationId,
    required this.studentName,
    required this.eventTitle,
    required this.costumeId,
    required this.costumeName,
    this.costumeImageUrl,
    required this.status,
    required this.deliveryDate,
    this.returnDate,
    this.observations,
  });

  bool get isDelivered     => status == 'ENTREGADO';
  bool get isPendingReturn => status == 'PENDIENTE_DEVOLUCION';
  bool get isReturned      => status == 'DEVUELTO';

  factory CostumeAssignment.fromJson(Map<String, dynamic> j) => CostumeAssignment(
    id:              (j['id']              as num).toInt(),
    participationId: (j['participationId'] as num?)?.toInt() ?? 0,
    studentName:     j['studentName']      as String? ?? '',
    eventTitle:      j['eventTitle']       as String? ?? '',
    costumeId:       (j['costumeId']       as num?)?.toInt() ?? 0,
    costumeName:     j['costumeName']      as String? ?? '',
    costumeImageUrl: j['costumeImageUrl']  as String?,
    status:          j['status']           as String? ?? 'ENTREGADO',
    deliveryDate:    j['deliveryDate']     as String? ?? '',
    returnDate:      j['returnDate']       as String?,
    observations:    j['observations']     as String?,
  );
}

// ─── CostumeService ───────────────────────────────────────────────────────────
class CostumeService {
  CostumeService._();

  static String get _baseUrl {
    final raw = dotenv.env['BACKEND_URL'] ?? '';
    if (raw.isEmpty) throw const CostumeException('App configuration error');
    return raw.startsWith('http') ? raw : 'http://$raw';
  }

  static const _bucket = 'dancewithme';
  static const _folder = 'costumes';

  static String _uuid() {
    final rng   = math.Random();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }

  // ── Upload image → Supabase Storage (bucket: dancewithme / costumes/) ─────
  static Future<String> uploadImage(Uint8List bytes, String ext) async {
    try {
      final supabase = Supabase.instance.client;
      final path     = '$_folder/${_uuid()}.$ext';
      if (kDebugMode) {
        debugPrint('[CostumeService] uploading → $_bucket/$path (${bytes.length} bytes)');
      }
      await supabase.storage.from(_bucket).uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(contentType: 'image/$ext', upsert: false),
      );
      final url = supabase.storage.from(_bucket).getPublicUrl(path);
      if (kDebugMode) debugPrint('[CostumeService] public URL → $url');
      return url;
    } on StorageException catch (e) {
      throw CostumeException('Image upload failed: ${e.message}');
    } catch (e) {
      throw CostumeException('Image upload failed: $e');
    }
  }

  static Future<http.Response> _req(
    Future<http.Response> Function() call,
  ) async {
    try {
      return await call().timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const CostumeException('Request timed out');
    } on SocketException {
      throw const CostumeException('No internet connection');
    }
  }

  static Map<String, String> _headers(String token, {bool json = false}) => {
        'Authorization': 'Bearer $token',
        if (json) 'Content-Type': 'application/json; charset=UTF-8',
      };

  // ── GET /api/v1/costumes?schoolId={id}[&active=true|false] ───────────────
  // active: null → backend default (only active), true → only active, false → only inactive
  static Future<List<Costume>> getCostumes({
    required int schoolId,
    bool?        active,
  }) async {
    final token = await AuthService.getAccessToken();
    if (token == null) throw const CostumeException('No authentication token');

    final params = <String, String>{'schoolId': '$schoolId'};
    if (active != null) params['active'] = '$active';
    final uri = Uri.parse('$_baseUrl/api/v1/costumes').replace(queryParameters: params);

    final res = await _req(() => http.get(uri, headers: _headers(token)));

    if (kDebugMode) {
      debugPrint('[CostumeService] GET /api/v1/costumes?schoolId=$schoolId'
          '${active != null ? "&active=$active" : ""} → ${res.statusCode}');
    }
    if (res.statusCode != 200) throw CostumeException(ApiError.userMessage(res.body, res.statusCode));

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final data = body['data'] as List<dynamic>? ?? [];
    return data.map((e) => Costume.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ── POST /api/v1/costumes ─────────────────────────────────────────────────
  static Future<Costume> createCostume({
    required int    schoolId,
    required String name,
    required String description,
    String?         imageUrl,
    String?         notes,
    required int    quantity,
  }) async {
    final token = await AuthService.getAccessToken();
    if (token == null) throw const CostumeException('No authentication token');

    final res = await _req(() => http.post(
          Uri.parse('$_baseUrl/api/v1/costumes'),
          headers: _headers(token, json: true),
          body: jsonEncode({
            'schoolId':    schoolId,
            'name':        name,
            'description': description,
            if (imageUrl != null && imageUrl.isNotEmpty) 'imageUrl': imageUrl,
            if (notes    != null && notes.isNotEmpty)    'notes':    notes,
            'quantity':    quantity,
          }),
        ));

    if (kDebugMode) debugPrint('[CostumeService] POST /api/v1/costumes → ${res.statusCode}');
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw CostumeException(ApiError.userMessage(res.body, res.statusCode));
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return Costume.fromJson(body['data'] as Map<String, dynamic>);
  }

  // ── PUT /api/v1/costumes/{id} ─────────────────────────────────────────────
  static Future<Costume> updateCostume({
    required int    id,
    required int    schoolId,
    required String name,
    required String description,
    String?         imageUrl,
    String?         notes,
    required int    quantity,
    required bool   active,
  }) async {
    final token = await AuthService.getAccessToken();
    if (token == null) throw const CostumeException('No authentication token');

    final res = await _req(() => http.put(
          Uri.parse('$_baseUrl/api/v1/costumes/$id'),
          headers: _headers(token, json: true),
          body: jsonEncode({
            'schoolId':    schoolId,
            'name':        name,
            'description': description,
            if (imageUrl != null && imageUrl.isNotEmpty) 'imageUrl': imageUrl,
            if (notes    != null && notes.isNotEmpty)    'notes':    notes,
            'quantity':    quantity,
            'active':      active,
          }),
        ));

    if (kDebugMode) debugPrint('[CostumeService] PUT /api/v1/costumes/$id → ${res.statusCode}');
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw CostumeException(ApiError.userMessage(res.body, res.statusCode));
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return Costume.fromJson(body['data'] as Map<String, dynamic>);
  }

  // ── DELETE /api/v1/costumes/{id} ──────────────────────────────────────────
  static Future<void> deleteCostume(int id) async {
    final token = await AuthService.getAccessToken();
    if (token == null) throw const CostumeException('No authentication token');

    final res = await _req(() => http.delete(
          Uri.parse('$_baseUrl/api/v1/costumes/$id'),
          headers: _headers(token),
        ));

    if (kDebugMode) debugPrint('[CostumeService] DELETE /api/v1/costumes/$id → ${res.statusCode}');
    if (res.statusCode != 200 && res.statusCode != 204) {
      throw CostumeException(ApiError.userMessage(res.body, res.statusCode));
    }
  }

  // ── PATCH /api/v1/costumes/{id}/activate ─────────────────────────────────
  static Future<Costume> activateCostume(int id) async {
    final token = await AuthService.getAccessToken();
    if (token == null) throw const CostumeException('No authentication token');

    final res = await _req(() => http.patch(
          Uri.parse('$_baseUrl/api/v1/costumes/$id/activate'),
          headers: _headers(token),
        ));

    if (kDebugMode) debugPrint('[CostumeService] PATCH /api/v1/costumes/$id/activate → ${res.statusCode}');
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw CostumeException(ApiError.userMessage(res.body, res.statusCode));
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return Costume.fromJson(body['data'] as Map<String, dynamic>);
  }

  // ── POST /api/v1/costumes/assign ─────────────────────────────────────────
  static Future<CostumeAssignment> assignCostume({
    required int    participationId,
    required int    costumeId,
    String?         observations,
  }) async {
    final token = await AuthService.getAccessToken();
    if (token == null) throw const CostumeException('No authentication token');

    final res = await _req(() => http.post(
          Uri.parse('$_baseUrl/api/v1/costumes/assign'),
          headers: _headers(token, json: true),
          body: jsonEncode({
            'participationId': participationId,
            'costumeId':       costumeId,
            if (observations != null && observations.isNotEmpty)
              'observations': observations,
          }),
        ));

    if (kDebugMode) debugPrint('[CostumeService] POST /api/v1/costumes/assign → ${res.statusCode}');
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw CostumeException(ApiError.userMessage(res.body, res.statusCode));
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return CostumeAssignment.fromJson(body['data'] as Map<String, dynamic>);
  }

  // ── GET /api/v1/costumes/assignments/participation/{id} ───────────────────
  static Future<List<CostumeAssignment>> getAssignmentsByParticipation(
      int participationId) async {
    final token = await AuthService.getAccessToken();
    if (token == null) throw const CostumeException('No authentication token');

    final res = await _req(() => http.get(
          Uri.parse('$_baseUrl/api/v1/costumes/assignments/participation/$participationId'),
          headers: _headers(token),
        ));

    if (kDebugMode) debugPrint('[CostumeService] GET .../participation/$participationId → ${res.statusCode}');
    if (res.statusCode != 200) throw CostumeException(ApiError.userMessage(res.body, res.statusCode));

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final data = body['data'] as List<dynamic>? ?? [];
    return data.map((e) => CostumeAssignment.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ── GET /api/v1/costumes/assignments/pending ──────────────────────────────
  static Future<List<CostumeAssignment>> getPendingAssignments() async {
    final token = await AuthService.getAccessToken();
    if (token == null) throw const CostumeException('No authentication token');

    final res = await _req(() => http.get(
          Uri.parse('$_baseUrl/api/v1/costumes/assignments/pending'),
          headers: _headers(token),
        ));

    if (kDebugMode) debugPrint('[CostumeService] GET /api/v1/costumes/assignments/pending → ${res.statusCode}');
    if (res.statusCode != 200) throw CostumeException(ApiError.userMessage(res.body, res.statusCode));

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final data = body['data'] as List<dynamic>? ?? [];
    return data.map((e) => CostumeAssignment.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ── PATCH /api/v1/costumes/assignments/{id}/return ────────────────────────
  static Future<CostumeAssignment> returnAssignment(int id) async {
    final token = await AuthService.getAccessToken();
    if (token == null) throw const CostumeException('No authentication token');

    final res = await _req(() => http.patch(
          Uri.parse('$_baseUrl/api/v1/costumes/assignments/$id/return'),
          headers: _headers(token),
        ));

    if (kDebugMode) debugPrint('[CostumeService] PATCH .../assignments/$id/return → ${res.statusCode}');
    if (res.statusCode != 200 && res.statusCode != 204) {
      throw CostumeException(ApiError.userMessage(res.body, res.statusCode));
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return CostumeAssignment.fromJson(body['data'] as Map<String, dynamic>);
  }
}
