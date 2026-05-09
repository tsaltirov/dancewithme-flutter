import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import 'auth_service.dart';

// ─── Typed error ──────────────────────────────────────────────────────────────
class GroupException implements Exception {
  final String message;
  const GroupException(this.message);
}

// ─── Group model ──────────────────────────────────────────────────────────────
class Group {
  final int     id;
  final String  name;
  final String  danceStyle;
  final String  level;
  final int     maxCapacity;
  final String  schedule;
  final int     schoolId;
  final String  schoolName;
  final bool    active;
  final String? createdAt;

  const Group({
    required this.id,
    required this.name,
    required this.danceStyle,
    required this.level,
    required this.maxCapacity,
    required this.schedule,
    required this.schoolId,
    required this.schoolName,
    required this.active,
    this.createdAt,
  });

  factory Group.fromJson(Map<String, dynamic> j) => Group(
        id:          (j['id'] as num).toInt(),
        name:        j['name']        as String? ?? '',
        danceStyle:  j['danceStyle']  as String? ?? '',
        level:       j['level']       as String? ?? '',
        maxCapacity: (j['maxCapacity'] as num?)?.toInt() ?? 0,
        schedule:    j['schedule']    as String? ?? '',
        schoolId:    (j['schoolId']   as num?)?.toInt() ?? 0,
        schoolName:  j['schoolName']  as String? ?? '',
        active:      j['active']      as bool?   ?? true,
        createdAt:   j['createdAt']   as String?,
      );
}

// ─── GroupService ─────────────────────────────────────────────────────────────
class GroupService {
  GroupService._();

  static String get _baseUrl {
    final raw = dotenv.env['BACKEND_URL'] ?? '';
    if (raw.isEmpty) throw const GroupException('App configuration error');
    return raw.startsWith('http') ? raw : 'http://$raw';
  }

  // ── GET /api/v1/groups/school/{schoolId} ─────────────────────────────────
  static Future<List<Group>> getBySchool(int schoolId) async {
    final token = await AuthService.getAccessToken();
    if (token == null) throw const GroupException('No authentication token');

    final http.Response res;
    try {
      res = await http.get(
        Uri.parse('$_baseUrl/api/v1/groups/school/$schoolId'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const GroupException('Request timed out');
    } on SocketException {
      throw const GroupException('No internet connection');
    }

    if (kDebugMode) {
      debugPrint('[GroupService] GET /api/v1/groups/school/$schoolId → ${res.statusCode}');
    }

    if (res.statusCode != 200) {
      throw GroupException('Server error ${res.statusCode}');
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final data = body['data'] as List<dynamic>? ?? [];
    return data.map((e) => Group.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ── PUT /api/v1/groups/{id} ──────────────────────────────────────────────
  static Future<Group> updateGroup({
    required int    id,
    required String name,
    required String danceStyle,
    required String level,
    required int    maxCapacity,
    required String schedule,
    required int schoolId,
  }) async {
    final token = await AuthService.getAccessToken();
    if (token == null) throw const GroupException('No authentication token');

    final http.Response res;
    try {
      res = await http
          .put(
            Uri.parse('$_baseUrl/api/v1/groups/$id'),
            headers: {
              'Content-Type': 'application/json; charset=UTF-8',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'name':        name,
              'danceStyle':  danceStyle,
              'level':       level,
              'maxCapacity': maxCapacity,
              'schedule':    schedule,
              'schoolId':    schoolId,
            }),
          )
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const GroupException('Request timed out');
    } on SocketException {
      throw const GroupException('No internet connection');
    }

    if (kDebugMode) {
      debugPrint('[GroupService] PUT /api/v1/groups/$id → ${res.statusCode}');
    }

    if (res.statusCode != 200 && res.statusCode != 201) {
      throw GroupException('Server error ${res.statusCode}');
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return Group.fromJson(body['data'] as Map<String, dynamic>);
  }

  // ── POST /api/v1/groups ───────────────────────────────────────────────────
  static Future<Group> createGroup({
    required String name,
    required String danceStyle,
    required String level,
    required int    maxCapacity,
    required String schedule,
    required int    schoolId,
  }) async {
    final token = await AuthService.getAccessToken();
    if (token == null) throw const GroupException('No authentication token');

    final http.Response res;
    try {
      res = await http
          .post(
            Uri.parse('$_baseUrl/api/v1/groups'),
            headers: {
              'Content-Type': 'application/json; charset=UTF-8',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'name':        name,
              'danceStyle':  danceStyle,
              'level':       level,
              'maxCapacity': maxCapacity,
              'schedule':    schedule,
              'schoolId':    schoolId,
            }),
          )
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const GroupException('Request timed out');
    } on SocketException {
      throw const GroupException('No internet connection');
    }

    if (kDebugMode) {
      debugPrint('[GroupService] POST /api/v1/groups → ${res.statusCode}');
    }

    if (res.statusCode != 200 && res.statusCode != 201) {
      throw GroupException('Server error ${res.statusCode}');
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return Group.fromJson(body['data'] as Map<String, dynamic>);
  }
}
