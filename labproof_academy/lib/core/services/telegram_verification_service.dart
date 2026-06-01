import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../constants/api_endpoints.dart';
import '../constants/supabase_config.dart';

class TelegramCodeRequest {
  const TelegramCodeRequest({
    required this.sessionId,
    required this.botLink,
  });

  final String sessionId;
  final Uri botLink;
}

class TelegramCodeVerification {
  const TelegramCodeVerification({required this.verified, this.error});

  final bool verified;
  final String? error;
}

class TelegramVerificationService {
  const TelegramVerificationService();

  static const _headers = {
    'Content-Type': 'application/json',
    'apikey': SupabaseConfig.anonKey,
    'Authorization': 'Bearer ${SupabaseConfig.anonKey}',
  };

  Future<TelegramCodeRequest> requestCode({
    required String fullName,
    required String phone,
    required String password,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse(
              '${ApiEndpoints.authBaseUrl}${ApiEndpoints.requestTelegramCode}',
            ),
            headers: _headers,
            body: jsonEncode({
              'fullName': fullName,
              'phone': phone,
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final payload = _decodeMap(response.body);
        if (payload == null) {
          throw Exception('Server javobi noto‘g‘ri formatda.');
        }
        return TelegramCodeRequest(
          sessionId: payload['sessionId'] as String,
          botLink: Uri.parse(payload['botLink'] as String),
        );
      }

      throw Exception(
        _errorMessage(response.body) ?? 'Kod so‘rovi bajarilmadi.',
      );
    } on TimeoutException {
      throw Exception('Server javob bermadi. Internetni tekshiring.');
    }
  }

  Future<TelegramCodeVerification> verifyCode({
    required String sessionId,
    required String code,
    required String password,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse(
              '${ApiEndpoints.authBaseUrl}${ApiEndpoints.verifyTelegramCode}',
            ),
            headers: _headers,
            body: jsonEncode({
              'sessionId': sessionId,
              'code': code.trim(),
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final payload = _decodeMap(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return TelegramCodeVerification(
          verified: payload?['verified'] == true,
          error: payload?['error']?.toString(),
        );
      }

      return TelegramCodeVerification(
        verified: false,
        error: _errorMessage(response.body) ?? 'Kod tasdiqlanmadi.',
      );
    } on TimeoutException {
      return const TelegramCodeVerification(
        verified: false,
        error: 'Server javob bermadi. Iltimos, qayta urinib ko‘ring.',
      );
    } on Object catch (error) {
      return TelegramCodeVerification(
        verified: false,
        error: 'Kod tasdiqlashda xatolik: $error',
      );
    }
  }

  Future<TelegramCodeRequest> requestPasswordReset({
    required String phone,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse(
              '${ApiEndpoints.authBaseUrl}${ApiEndpoints.requestTelegramResetCode}',
            ),
            headers: _headers,
            body: jsonEncode({'phone': phone}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final payload = _decodeMap(response.body);
        if (payload == null) {
          throw Exception('Server javobi noto‘g‘ri formatda.');
        }
        return TelegramCodeRequest(
          sessionId: payload['sessionId'] as String,
          botLink: Uri.parse(payload['botLink'] as String),
        );
      }

      throw Exception(
        _errorMessage(response.body) ?? 'Parolni tiklash kodi yuborilmadi.',
      );
    } on TimeoutException {
      throw Exception('Server javob bermadi. Internetni tekshiring.');
    }
  }

  String? _errorMessage(String body) {
    return _decodeMap(body)?['error']?.toString();
  }

  Map<String, dynamic>? _decodeMap(String body) {
    try {
      final payload = jsonDecode(body);
      if (payload is Map<String, dynamic>) {
        return payload;
      }
    } on Object {
      return null;
    }
    return null;
  }
}
