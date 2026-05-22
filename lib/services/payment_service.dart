import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import 'auth_service.dart';

// ─── Typed error ──────────────────────────────────────────────────────────────
class PaymentException implements Exception {
  final String message;
  const PaymentException(this.message);
  @override String toString() => message;
}

// ─── Payment model ────────────────────────────────────────────────────────────
class Payment {
  final int     id;
  final int     studentId;
  final int     schoolId;
  final int     year;
  final int     month;
  final double  amount;
  final String  status;
  final String? paymentDate;
  final String? paymentMethod;
  final String? notes;

  const Payment({
    required this.id,
    required this.studentId,
    required this.schoolId,
    required this.year,
    required this.month,
    required this.amount,
    required this.status,
    this.paymentDate,
    this.paymentMethod,
    this.notes,
  });

  bool get isPaid => status.toUpperCase() == 'PAGADO';

  factory Payment.fromJson(Map<String, dynamic> j) => Payment(
        id:            (j['id']        as num).toInt(),
        studentId:     (j['studentId'] as num?)?.toInt()  ?? 0,
        schoolId:      (j['schoolId']  as num?)?.toInt()  ?? 0,
        year:          (j['year']      as num?)?.toInt()  ?? 0,
        month:         (j['month']     as num?)?.toInt()  ?? 0,
        amount:        (j['amount']    as num?)?.toDouble() ?? 0.0,
        status:        j['status']         as String? ?? 'PENDIENTE',
        paymentDate:   j['paymentDate']    as String?,
        paymentMethod: j['paymentMethod']  as String?,
        notes:         j['notes']          as String?,
      );
}

// ─── PaymentService ───────────────────────────────────────────────────────────
class PaymentService {
  PaymentService._();

  static String get _baseUrl {
    final raw = dotenv.env['BACKEND_URL'] ?? '';
    if (raw.isEmpty) throw const PaymentException('App configuration error');
    return raw.startsWith('http') ? raw : 'http://$raw';
  }

  // ── GET /api/v1/payments/student/{studentId} ─────────────────────────────
  static Future<List<Payment>> getStudentPayments(int studentId) async {
    final token = await AuthService.getAccessToken();
    if (token == null) throw const PaymentException('No authentication token');

    final http.Response res;
    try {
      res = await http.get(
        Uri.parse('$_baseUrl/api/v1/payments/student/$studentId'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const PaymentException('Request timed out');
    } on SocketException {
      throw const PaymentException('No internet connection');
    }

    if (kDebugMode) {
      debugPrint('[PaymentService] GET /api/v1/payments/student/$studentId → ${res.statusCode}');
    }

    if (res.statusCode != 200) {
      throw PaymentException('Server error ${res.statusCode}');
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final data = body['data'] as List<dynamic>? ?? [];
    return data.map((e) => Payment.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ── POST /api/v1/payments ─────────────────────────────────────────────────
  static Future<Payment> createPayment({
    required int    studentId,
    required int    schoolId,
    required int    year,
    required int    month,
    required double amount,
    String?         paymentDate,
    String?         paymentMethod,
    String?         notes,
  }) async {
    final token = await AuthService.getAccessToken();
    if (token == null) throw const PaymentException('No authentication token');

    final http.Response res;
    try {
      res = await http
          .post(
            Uri.parse('$_baseUrl/api/v1/payments'),
            headers: {
              'Content-Type': 'application/json; charset=UTF-8',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'studentId': studentId,
              'schoolId':  schoolId,
              'year':      year,
              'month':     month,
              'amount':    amount,
              if (paymentDate   != null) 'paymentDate':   paymentDate,
              if (paymentMethod != null) 'paymentMethod': paymentMethod,
              if (notes         != null) 'notes':         notes,
            }),
          )
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const PaymentException('Request timed out');
    } on SocketException {
      throw const PaymentException('No internet connection');
    }

    if (kDebugMode) {
      debugPrint('[PaymentService] POST /api/v1/payments → ${res.statusCode}');
    }

    if (res.statusCode != 200 && res.statusCode != 201) {
      throw PaymentException('Server error ${res.statusCode}');
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return Payment.fromJson(body['data'] as Map<String, dynamic>);
  }

  // ── PATCH /api/v1/payments/{id}/pay?paymentMethod=... ────────────────────
  static Future<Payment> markAsPaid({
    required int    id,
    required String paymentMethod,
  }) async {
    final token = await AuthService.getAccessToken();
    if (token == null) throw const PaymentException('No authentication token');

    final http.Response res;
    try {
      res = await http
          .patch(
            Uri.parse('$_baseUrl/api/v1/payments/$id/pay')
                .replace(queryParameters: {'paymentMethod': paymentMethod}),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const PaymentException('Request timed out');
    } on SocketException {
      throw const PaymentException('No internet connection');
    }

    if (kDebugMode) {
      debugPrint('[PaymentService] PATCH /api/v1/payments/$id/pay → ${res.statusCode}');
    }

    if (res.statusCode != 200 && res.statusCode != 201) {
      throw PaymentException('Server error ${res.statusCode}');
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return Payment.fromJson(body['data'] as Map<String, dynamic>);
  }
}
