import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/api_endpoints.dart';
import '../constants/supabase_config.dart';
import 'supabase_service.dart';

class AuthService {
  const AuthService._();

  static Future<void> signInAdmin({
    required String login,
    required String password,
  }) async {
    await SupabaseService.client.auth.signInWithPassword(
      email: adminAuthEmail(login),
      password: password,
    );
  }

  static Future<void> signInWithPhone({
    required String phone,
    required String password,
  }) async {
    await SupabaseService.client.auth.signInWithPassword(
      email: phoneAuthEmail(phone),
      password: password,
    );
  }

  static Future<void> signOut() {
    return SupabaseService.client.auth.signOut();
  }

  static Future<bool?> isPhoneRegistered(String phone) async {
    try {
      final response = await http
          .post(
            Uri.parse('${ApiEndpoints.authBaseUrl}${ApiEndpoints.phoneStatus}'),
            headers: const {
              'Content-Type': 'application/json',
              'apikey': SupabaseConfig.anonKey,
              'Authorization': 'Bearer ${SupabaseConfig.anonKey}',
            },
            body: jsonEncode({'phone': phone}),
          )
          .timeout(const Duration(seconds: 10));

      final payload = jsonDecode(response.body);
      if (payload is Map<String, dynamic> && payload['exists'] is bool) {
        return payload['exists'] as bool;
      }
    } on TimeoutException {
      return null;
    } on Object {
      return null;
    }
    return null;
  }

  static Future<String> currentRoleName() async {
    final user = currentUser;
    if (user == null) return 'student';

    final row = await SupabaseService.client
        .from('profiles')
        .select('role')
        .eq('id', user.id)
        .maybeSingle();

    final metadata = user.userMetadata ?? {};
    return (row?['role'] ?? metadata['role'] ?? 'student').toString();
  }

  static User? get currentUser {
    try {
      return SupabaseService.client.auth.currentUser;
    } on Object {
      return null;
    }
  }

  static String phoneAuthEmail(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    return '$digits@phone.labproof.local';
  }

  static String adminAuthEmail(String login) {
    final normalized = login.trim().toLowerCase();
    if (normalized.contains('@')) return normalized;
    return '${normalized.replaceAll(RegExp(r'\s+'), '')}@admin.labproof.local';
  }
}
