import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import 'auth_service.dart';

// ─── Typed error ──────────────────────────────────────────────────────────────
class EventException implements Exception {
  final String message;
  const EventException(this.message);
}

// ─── Event model ──────────────────────────────────────────────────────────────
class Event {
  final int     id;
  final String  title;
  final String  description;
  final String  startDate;
  final String  endDate;
  final String  venue;
  final int     maxCapacity;
  final int     schoolId;
  final String? schoolName;
  final bool    active;

  const Event({
    required this.id,
    required this.title,
    required this.description,
    required this.startDate,
    required this.endDate,
    required this.venue,
    required this.maxCapacity,
    required this.schoolId,
    this.schoolName,
    required this.active,
  });

  factory Event.fromJson(Map<String, dynamic> j) => Event(
        id:          (j['id'] as num).toInt(),
        title:       j['title']       as String? ?? '',
        description: j['description'] as String? ?? '',
        startDate:   j['startDate']   as String? ?? '',
        endDate:     j['endDate']     as String? ?? '',
        venue:       j['venue']       as String? ?? '',
        maxCapacity: (j['maxCapacity'] as num?)?.toInt() ?? 0,
        schoolId:    (j['schoolId']   as num?)?.toInt() ?? 0,
        schoolName:  j['schoolName']  as String?,
        active:      j['active']      as bool?   ?? true,
      );
}

// ─── EventService ─────────────────────────────────────────────────────────────
class EventService {
  EventService._();

  static String get _baseUrl {
    final raw = dotenv.env['BACKEND_URL'] ?? '';
    if (raw.isEmpty) throw const EventException('App configuration error');
    return raw.startsWith('http') ? raw : 'http://$raw';
  }

  // ── GET /api/v1/events/school/{schoolId} ─────────────────────────────────
  static Future<List<Event>> getBySchool(int schoolId) async {
    final token = await AuthService.getAccessToken();
    if (token == null) throw const EventException('No authentication token');

    final http.Response res;
    try {
      res = await http.get(
        Uri.parse('$_baseUrl/api/v1/events/school/$schoolId'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const EventException('Request timed out');
    } on SocketException {
      throw const EventException('No internet connection');
    }

    if (kDebugMode) {
      debugPrint('[EventService] GET /api/v1/events/school/$schoolId → ${res.statusCode}');
    }

    if (res.statusCode != 200) {
      throw EventException('Server error ${res.statusCode}');
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final data = body['data'] as List<dynamic>? ?? [];
    return data.map((e) => Event.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ── POST /api/v1/events ───────────────────────────────────────────────────
  static Future<Event> createEvent({
    required String title,
    required String description,
    required String startDate,
    required String endDate,
    required String venue,
    required int    maxCapacity,
    required int    schoolId,
  }) async {
    final token = await AuthService.getAccessToken();
    if (token == null) throw const EventException('No authentication token');

    final http.Response res;
    try {
      res = await http
          .post(
            Uri.parse('$_baseUrl/api/v1/events'),
            headers: {
              'Content-Type': 'application/json; charset=UTF-8',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'title':       title,
              'description': description,
              'startDate':   startDate,
              'endDate':     endDate,
              'venue':       venue,
              'maxCapacity': maxCapacity,
              'schoolId':    schoolId,
            }),
          )
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const EventException('Request timed out');
    } on SocketException {
      throw const EventException('No internet connection');
    }

    if (kDebugMode) {
      debugPrint('[EventService] POST /api/v1/events → ${res.statusCode}');
    }

    if (res.statusCode != 200 && res.statusCode != 201) {
      throw EventException('Server error ${res.statusCode}');
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return Event.fromJson(body['data'] as Map<String, dynamic>);
  }

  // ── PUT /api/v1/events/{id} ───────────────────────────────────────────────
  static Future<Event> updateEvent({
    required int    id,
    required String title,
    required String description,
    required String startDate,
    required String endDate,
    required String venue,
    required int    maxCapacity,
    required int    schoolId,
  }) async {
    final token = await AuthService.getAccessToken();
    if (token == null) throw const EventException('No authentication token');

    final http.Response res;
    try {
      res = await http
          .put(
            Uri.parse('$_baseUrl/api/v1/events/$id'),
            headers: {
              'Content-Type': 'application/json; charset=UTF-8',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'title':       title,
              'description': description,
              'startDate':   startDate,
              'endDate':     endDate,
              'venue':       venue,
              'maxCapacity': maxCapacity,
              'schoolId':    schoolId,
            }),
          )
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const EventException('Request timed out');
    } on SocketException {
      throw const EventException('No internet connection');
    }

    if (kDebugMode) {
      debugPrint('[EventService] PUT /api/v1/events/$id → ${res.statusCode}');
    }

    if (res.statusCode != 200 && res.statusCode != 201) {
      throw EventException('Server error ${res.statusCode}');
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return Event.fromJson(body['data'] as Map<String, dynamic>);
  }

  // ── GET /api/v1/events/{eventId}/prices ──────────────────────────────────
  static Future<List<EventPrice>> getEventPrices(int eventId) async {
    final token = await AuthService.getAccessToken();
    if (token == null) throw const EventException('No authentication token');

    final http.Response res;
    try {
      res = await http.get(
        Uri.parse('$_baseUrl/api/v1/events/$eventId/prices'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const EventException('Request timed out');
    } on SocketException {
      throw const EventException('No internet connection');
    }

    if (kDebugMode) {
      debugPrint('[EventService] GET /api/v1/events/$eventId/prices → ${res.statusCode}');
    }

    if (res.statusCode != 200) {
      throw EventException('Server error ${res.statusCode}');
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final data = body['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => EventPrice.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── PUT /api/v1/events/{eventId}/prices/{priceId} ────────────────────────
  static Future<EventPrice> updateEventPrice({
    required int    eventId,
    required int    priceId,
    required String type,
    required String label,
    required double amount,
    required bool   optional,
  }) async {
    final token = await AuthService.getAccessToken();
    if (token == null) throw const EventException('No authentication token');

    final http.Response res;
    try {
      res = await http
          .put(
            Uri.parse('$_baseUrl/api/v1/events/$eventId/prices/$priceId'),
            headers: {
              'Content-Type': 'application/json; charset=UTF-8',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'type':     type,
              'label':    label,
              'amount':   amount,
              'optional': optional,
            }),
          )
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const EventException('Request timed out');
    } on SocketException {
      throw const EventException('No internet connection');
    }

    if (kDebugMode) {
      debugPrint('[EventService] PUT /api/v1/events/$eventId/prices/$priceId → ${res.statusCode}');
    }

    if (res.statusCode != 200 && res.statusCode != 201) {
      throw EventException('Server error ${res.statusCode}');
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return EventPrice.fromJson(body['data'] as Map<String, dynamic>);
  }

  // ── GET /api/v1/events/{eventId}/participations ───────────────────────────
  static Future<List<EventParticipation>> getParticipations(int eventId) async {
    final token = await AuthService.getAccessToken();
    if (token == null) throw const EventException('No authentication token');

    final http.Response res;
    try {
      res = await http.get(
        Uri.parse('$_baseUrl/api/v1/events/$eventId/participations'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const EventException('Request timed out');
    } on SocketException {
      throw const EventException('No internet connection');
    }

    if (kDebugMode) {
      debugPrint('[EventService] GET /api/v1/events/$eventId/participations → ${res.statusCode}');
    }

    if (res.statusCode != 200) {
      throw EventException('Server error ${res.statusCode}');
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final data = body['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => EventParticipation.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── POST /api/v1/events/participations ────────────────────────────────────
  static Future<EventParticipation> addParticipation({
    required int eventId,
    required int studentId,
  }) async {
    final token = await AuthService.getAccessToken();
    if (token == null) throw const EventException('No authentication token');

    final http.Response res;
    try {
      res = await http
          .post(
            Uri.parse('$_baseUrl/api/v1/events/participations'),
            headers: {
              'Content-Type': 'application/json; charset=UTF-8',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'eventId': eventId, 'studentId': studentId}),
          )
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const EventException('Request timed out');
    } on SocketException {
      throw const EventException('No internet connection');
    }

    if (kDebugMode) {
      debugPrint('[EventService] POST /api/v1/events/participations → ${res.statusCode}');
    }

    if (res.statusCode != 200 && res.statusCode != 201) {
      throw EventException('Server error ${res.statusCode}');
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return EventParticipation.fromJson(body['data'] as Map<String, dynamic>);
  }
}

// ─── EventPrice model ─────────────────────────────────────────────────────────
class EventPrice {
  final int    id;
  final String type;
  final String label;
  final double amount;
  final bool   optional;
  final int    eventId;

  const EventPrice({
    required this.id,
    required this.type,
    required this.label,
    required this.amount,
    required this.optional,
    required this.eventId,
  });

  factory EventPrice.fromJson(Map<String, dynamic> j) => EventPrice(
        id:       (j['id']      as num).toInt(),
        type:     j['type']     as String? ?? '',
        label:    j['label']    as String? ?? '',
        amount:   (j['amount']  as num?)?.toDouble() ?? 0.0,
        optional: j['optional'] as bool?   ?? false,
        eventId:  (j['eventId'] as num?)?.toInt() ?? 0,
      );
}

// ─── EventPriceService ────────────────────────────────────────────────────────
extension EventPriceService on EventService {
  // ── POST /api/v1/events/{eventId}/prices ─────────────────────────────────
  static Future<EventPrice> createEventPrice({
    required int    eventId,
    required String type,
    required String label,
    required double amount,
    required bool   optional,
  }) async {
    final raw = dotenv.env['BACKEND_URL'] ?? '';
    if (raw.isEmpty) throw const EventException('App configuration error');
    final baseUrl = raw.startsWith('http') ? raw : 'http://$raw';

    final token = await AuthService.getAccessToken();
    if (token == null) throw const EventException('No authentication token');

    final http.Response res;
    try {
      res = await http
          .post(
            Uri.parse('$baseUrl/api/v1/events/$eventId/prices'),
            headers: {
              'Content-Type': 'application/json; charset=UTF-8',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'type':     type,
              'label':    label,
              'amount':   amount,
              'optional': optional,
            }),
          )
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const EventException('Request timed out');
    } on SocketException {
      throw const EventException('No internet connection');
    }

    if (kDebugMode) {
      debugPrint('[EventService] POST /api/v1/events/$eventId/prices → ${res.statusCode}');
    }

    if (res.statusCode != 200 && res.statusCode != 201) {
      throw EventException('Server error ${res.statusCode}');
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return EventPrice.fromJson(body['data'] as Map<String, dynamic>);
  }
}

// ─── EventParticipation model ─────────────────────────────────────────────────
class EventParticipation {
  final int    id;
  final int    eventId;
  final String eventTitle;
  final int    studentId;
  final String studentName;
  final String registrationDate;
  final String paymentStatus;
  final double paidAmount;

  const EventParticipation({
    required this.id,
    required this.eventId,
    required this.eventTitle,
    required this.studentId,
    required this.studentName,
    required this.registrationDate,
    required this.paymentStatus,
    required this.paidAmount,
  });

  factory EventParticipation.fromJson(Map<String, dynamic> j) =>
      EventParticipation(
        id:               (j['id']         as num).toInt(),
        eventId:          (j['eventId']    as num?)?.toInt()  ?? 0,
        eventTitle:       j['eventTitle']  as String?         ?? '',
        studentId:        (j['studentId']  as num?)?.toInt()  ?? 0,
        studentName:      j['studentName'] as String?         ?? '',
        registrationDate: j['registrationDate'] as String?    ?? '',
        paymentStatus:    j['paymentStatus']    as String?    ?? '',
        paidAmount:       (j['paidAmount'] as num?)?.toDouble() ?? 0.0,
      );
}
