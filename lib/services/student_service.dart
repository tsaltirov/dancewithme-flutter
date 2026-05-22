import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import 'auth_service.dart';

// ─── Typed error ──────────────────────────────────────────────────────────────
class StudentException implements Exception {
  final String message;
  const StudentException(this.message);
  @override String toString() => message;
}

// ─── Student model ────────────────────────────────────────────────────────────
class Student {
  final int     id;
  final String  name;
  final String  lastName;
  final String  email;
  final String  phone;
  final String? birthDate;
  final int     schoolId;
  final String  schoolName;
  final String? enrollmentDate;
  final bool    active;
  final bool    isPaid;

  const Student({
    required this.id,
    required this.name,
    required this.lastName,
    required this.email,
    required this.phone,
    this.birthDate,
    required this.schoolId,
    required this.schoolName,
    this.enrollmentDate,
    required this.active,
    this.isPaid = false,
  });

  String get fullName => '$name $lastName'.trim();

  String get initials {
    final n = name.trim();
    final l = lastName.trim();
    if (n.isNotEmpty && l.isNotEmpty) return '${n[0]}${l[0]}'.toUpperCase();
    if (n.isNotEmpty) return n.substring(0, n.length.clamp(1, 2)).toUpperCase();
    return '?';
  }

  factory Student.fromJson(Map<String, dynamic> j) => Student(
        id:             (j['id'] as num).toInt(),
        name:           j['name']           as String? ?? '',
        lastName:       j['lastName']       as String? ?? '',
        email:          j['email']          as String? ?? '',
        phone:          j['phone']          as String? ?? '',
        birthDate:      j['birthDate']      as String?,
        schoolId:       (j['schoolId'] as num?)?.toInt() ?? 0,
        schoolName:     j['schoolName']     as String? ?? '',
        enrollmentDate: j['enrollmentDate'] as String?,
        active:         j['active']         as bool?   ?? true,
      );

  Student copyWith({bool? isPaid}) => Student(
        id: id, name: name, lastName: lastName, email: email, phone: phone,
        birthDate: birthDate, schoolId: schoolId, schoolName: schoolName,
        enrollmentDate: enrollmentDate, active: active,
        isPaid: isPaid ?? this.isPaid,
      );
}

// ─── StudentService ───────────────────────────────────────────────────────────
class StudentService {
  StudentService._();

  static String get _baseUrl {
    final raw = dotenv.env['BACKEND_URL'] ?? '';
    if (raw.isEmpty) throw const StudentException('App configuration error');
    return raw.startsWith('http') ? raw : 'http://$raw';
  }

  // ── POST /api/v1/students/import?schoolId={schoolId} ────────────────────
  // Multipart upload — returns number of imported students (0 if server
  // doesn't expose a count field).
  static Future<int> importFromCsv({
    required int       schoolId,
    required Uint8List bytes,
    required String    filename,
  }) async {
    final token = await AuthService.getAccessToken();
    if (token == null) throw const StudentException('No authentication token');

    final uri = Uri.parse('$_baseUrl/api/v1/students/import')
        .replace(queryParameters: {'schoolId': '$schoolId'});

    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename,
      ));

    final http.StreamedResponse streamedRes;
    try {
      streamedRes =
          await request.send().timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw const StudentException('Request timed out');
    } on SocketException {
      throw const StudentException('No internet connection');
    }

    final res = await http.Response.fromStream(streamedRes);

    if (kDebugMode) {
      debugPrint(
          '[StudentService] POST /api/v1/students/import → ${res.statusCode}');
    }

    if (res.statusCode != 200 && res.statusCode != 201) {
      throw StudentException('Server error ${res.statusCode}');
    }

    try {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final data = body['data'];
      if (data is List)  return data.length;
      if (data is Map && data.containsKey('count')) {
        return (data['count'] as num?)?.toInt() ?? 0;
      }
    } catch (_) {}
    return 0;
  }

  // ── GET /api/v1/students/school/{schoolId} ───────────────────────────────
  static Future<List<Student>> getBySchool(int schoolId) async {
    final token = await AuthService.getAccessToken();
    if (token == null) throw const StudentException('No authentication token');

    final http.Response res;
    try {
      res = await http.get(
        Uri.parse('$_baseUrl/api/v1/students/school/$schoolId'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const StudentException('Request timed out');
    } on SocketException {
      throw const StudentException('No internet connection');
    }

    if (kDebugMode) {
      debugPrint('[StudentService] GET students/school/$schoolId → ${res.statusCode}');
    }

    if (res.statusCode != 200) {
      throw StudentException('Server error ${res.statusCode}');
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final data = body['data'] as List<dynamic>? ?? [];
    return data.map((e) => Student.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ── GET /api/v1/payments/student/{studentId} ─────────────────────────────
  // Returns true if the student has at least one payment record.
  static Future<bool> isPaid(int studentId) async {
    final token = await AuthService.getAccessToken();
    if (token == null) return false;

    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/api/v1/payments/student/$studentId'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) return false;

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final data = body['data'] as List<dynamic>? ?? [];
      return data.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // ── Check if student has a paid payment for a specific month/year ──────────
  static Future<bool> isPaidForPeriod(int studentId, int year, int month) async {
    final token = await AuthService.getAccessToken();
    if (token == null) return false;
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/api/v1/payments/student/$studentId'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return false;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final data = body['data'] as List<dynamic>? ?? [];
      return data.any((p) {
        final m = p as Map<String, dynamic>;
        return (m['year'] as num?)?.toInt() == year &&
               (m['month'] as num?)?.toInt() == month &&
               (m['status'] as String?)?.toUpperCase() == 'PAGADO';
      });
    } catch (_) {
      return false;
    }
  }

  // ── POST /api/v1/students ────────────────────────────────────────────────
  static Future<Student> createStudent({
    required String  name,
    required String  lastName,
    required String  email,
    required String  phone,
    required int     schoolId,
    String?          birthDate,
  }) async {
    final token = await AuthService.getAccessToken();
    if (token == null) throw const StudentException('No authentication token');

    final http.Response res;
    try {
      res = await http
          .post(
            Uri.parse('$_baseUrl/api/v1/students'),
            headers: {
              'Content-Type': 'application/json; charset=UTF-8',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'name':     name,
              'lastName': lastName,
              'email':    email,
              'phone':    phone,
              if (birthDate != null) 'birthDate': birthDate,
              'schoolId': schoolId,
            }),
          )
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const StudentException('Request timed out');
    } on SocketException {
      throw const StudentException('No internet connection');
    }

    if (kDebugMode) {
      debugPrint('[StudentService] POST /api/v1/students → ${res.statusCode}');
    }

    if (res.statusCode != 200 && res.statusCode != 201) {
      throw StudentException('Server error ${res.statusCode}');
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return Student.fromJson(body['data'] as Map<String, dynamic>);
  }

  // ── PUT /api/v1/students/{id} ────────────────────────────────────────────
  static Future<Student> updateStudent({
    required int     id,
    required String  name,
    required String  lastName,
    required String  email,
    required String  phone,
    required int     schoolId,
    String?          birthDate,
  }) async {
    final token = await AuthService.getAccessToken();
    if (token == null) throw const StudentException('No authentication token');

    final http.Response res;
    try {
      res = await http
          .put(
            Uri.parse('$_baseUrl/api/v1/students/$id'),
            headers: {
              'Content-Type': 'application/json; charset=UTF-8',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'name':     name,
              'lastName': lastName,
              'email':    email,
              'phone':    phone,
              if (birthDate != null) 'birthDate': birthDate,
              'schoolId': schoolId,
            }),
          )
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const StudentException('Request timed out');
    } on SocketException {
      throw const StudentException('No internet connection');
    }

    if (kDebugMode) {
      debugPrint('[StudentService] PUT /api/v1/students/$id → ${res.statusCode}');
    }

    if (res.statusCode != 200 && res.statusCode != 201) {
      throw StudentException('Server error ${res.statusCode}');
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return Student.fromJson(body['data'] as Map<String, dynamic>);
  }

  // ── DELETE /api/v1/students/{id} ─────────────────────────────────────────
  static Future<void> deleteStudent(int id) async {
    final token = await AuthService.getAccessToken();
    if (token == null) throw const StudentException('No authentication token');

    final http.Response res;
    try {
      res = await http
          .delete(
            Uri.parse('$_baseUrl/api/v1/students/$id'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const StudentException('Request timed out');
    } on SocketException {
      throw const StudentException('No internet connection');
    }

    if (kDebugMode) {
      debugPrint('[StudentService] DELETE /api/v1/students/$id → ${res.statusCode}');
    }

    if (res.statusCode != 200 && res.statusCode != 204) {
      throw StudentException('Server error ${res.statusCode}');
    }
  }

  // ── Load students + payment status in one call ───────────────────────────
  // Fetches students list, then checks each student's payment in parallel.
  static Future<List<Student>> getBySchoolWithPayments(int schoolId) async {
    final students = await getBySchool(schoolId);
    if (students.isEmpty) return students;

    final payments = await Future.wait(
      students.map((s) => isPaid(s.id)),
    );

    return [
      for (var i = 0; i < students.length; i++)
        students[i].copyWith(isPaid: payments[i]),
    ];
  }
}
