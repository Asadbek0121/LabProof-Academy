import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/api_endpoints.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/supabase_config.dart';
import '../../core/services/supabase_service.dart';
import '../models/academy_models.dart';

class SupabaseAcademyRepository {
  const SupabaseAcademyRepository({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  SupabaseClient get _supabase => _client ?? SupabaseService.client;

  Future<User> _currentUserOrThrow() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw const AuthException('Avval tizimga kiring.');
    }
    return user;
  }

  Future<StudentDashboardData> loadStudentDashboard() async {
    final user = await _currentUserOrThrow();

    final baseProfile = await _loadProfile(user);
    final profile = baseProfile.copyWith(
      premiumLabel: await _loadActivePremiumLabel(user.id),
    );
    final modules = await _loadModules(user.id);
    final results = await _supabase
        .from('module_results')
        .select('score, passed')
        .eq('user_id', user.id);
    final certificates = await _supabase
        .from('certificates')
        .select('id')
        .eq('user_id', user.id);

    final resultRows = (results as List<dynamic>).cast<Map<String, dynamic>>();
    final certificateRows = (certificates as List<dynamic>);
    final averageScore = resultRows.isEmpty
        ? 0
        : (resultRows.fold<int>(
                    0,
                    (sum, item) =>
                        sum + ((item['score'] as num?)?.round() ?? 0),
                  ) /
                  resultRows.length)
              .round();

    return StudentDashboardData(
      profile: profile,
      modules: modules,
      completedModules: resultRows
          .where((item) => item['passed'] == true)
          .length,
      averageScore: averageScore,
      certificateCount: certificateRows.length,
    );
  }

  Future<void> markPdfCompleted(String topicId) {
    return _upsertTopicProgress(topicId, {'pdf_completed': true});
  }

  Future<void> markVideoCompleted(String topicId) {
    return _upsertTopicProgress(topicId, {'video_completed': true});
  }

  Future<void> submitTopicQuiz({required String topicId, required int score}) {
    return _upsertTopicProgress(topicId, {
      'quiz_completed': true,
      'quiz_score': score.clamp(0, 100),
      'completed_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> submitFinalExam({
    required String moduleId,
    required int score,
  }) async {
    final user = await _currentUserOrThrow();

    await _supabase.from('module_results').upsert({
      'user_id': user.id,
      'module_id': moduleId,
      'score': score.clamp(0, 100),
      'passed': score >= 70,
      'created_at': DateTime.now().toIso8601String(),
    }, onConflict: 'user_id,module_id');
  }

  Future<void> _upsertTopicProgress(
    String topicId,
    Map<String, Object?> values,
  ) async {
    final user = await _currentUserOrThrow();

    await _supabase.from('topic_progress').upsert({
      'user_id': user.id,
      'topic_id': topicId,
      ...values,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'user_id,topic_id');
  }

  Future<bool> loadNotificationsEnabled() async {
    final user = await _currentUserOrThrow();
    final row = await _supabase
        .from('notification_settings')
        .select('enabled')
        .eq('user_id', user.id)
        .maybeSingle();

    return row?['enabled'] != false;
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    final user = await _currentUserOrThrow();
    await _supabase.from('notification_settings').upsert({
      'user_id': user.id,
      'enabled': enabled,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> saveAdminSetting({
    required String section,
    required String key,
    required Map<String, Object?> value,
  }) async {
    final user = await _currentUserOrThrow();
    await _supabase.from('admin_settings').upsert({
      'section': section,
      'key': key,
      'value': value,
      'updated_by': user.id,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'section,key');
  }

  Future<List<Map<String, dynamic>>> loadAdminSubscriptionPlans() async {
    final rows = await _supabase
        .from('subscription_plans')
        .select(
          'id, title, name, duration_months, duration_days, price_label, price, discount_percent, is_popular, is_active, features, sort_order, created_at, updated_at',
        )
        .order('sort_order')
        .order('created_at');
    return (rows as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<void> saveAdminSubscriptionPlan({
    String? id,
    required String name,
    required int durationDays,
    required num price,
    required int discountPercent,
    required bool isPopular,
    required bool isActive,
    required List<String> features,
    required int sortOrder,
  }) async {
    final safePrice = price < 0 ? 0 : price;
    final payload = <String, Object?>{
      'title': name.trim(),
      'name': name.trim(),
      'duration_months': (durationDays / 30).ceil().clamp(1, 120),
      'duration_days': durationDays.clamp(1, 3650),
      'price': safePrice,
      'price_label': '${_compactNumber(safePrice.round())} so‘m',
      'discount_percent': discountPercent.clamp(0, 100),
      'is_popular': isPopular,
      'is_active': isActive,
      'features': features
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList(),
      'sort_order': sortOrder,
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (id == null || id.trim().isEmpty) {
      await _supabase.from('subscription_plans').insert(payload);
      return;
    }

    await _supabase.from('subscription_plans').update(payload).eq('id', id);
  }

  Future<List<Map<String, dynamic>>> loadAdminPaymentMethods() async {
    final rows = await _supabase
        .from('payment_methods')
        .select('id, name, code, is_active, sort_order, created_at, updated_at')
        .order('sort_order')
        .order('created_at');
    return (rows as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<void> saveAdminPaymentMethod({
    String? id,
    required String name,
    required String code,
    required bool isActive,
    required int sortOrder,
  }) async {
    final payload = <String, Object?>{
      'name': name.trim(),
      'code': code.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]+'), '_'),
      'is_active': isActive,
      'sort_order': sortOrder,
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (id == null || id.trim().isEmpty) {
      await _supabase.from('payment_methods').insert(payload);
      return;
    }

    await _supabase.from('payment_methods').update(payload).eq('id', id);
  }

  static String _compactNumber(int value) {
    final raw = value.toString();
    final buffer = StringBuffer();
    for (var index = 0; index < raw.length; index++) {
      final left = raw.length - index;
      buffer.write(raw[index]);
      if (left > 1 && left % 3 == 1) buffer.write(' ');
    }
    return buffer.toString();
  }

  Future<List<StudentNotification>> loadNotifications({int limit = 20}) async {
    final user = await _currentUserOrThrow();
    final rows = await _supabase
        .from('notifications')
        .select(
          'id, title, body, deep_link, created_at, target_user_id, message_kind, attachment_url, attachment_name, attachment_mime, reply_to_inbox_message_id',
        )
        .eq('target_role', 'student')
        .eq('is_active', true)
        .or('target_user_id.is.null,target_user_id.eq.${user.id}')
        .order('created_at', ascending: false)
        .limit(limit);

    final notificationRows = (rows as List<dynamic>)
        .cast<Map<String, dynamic>>();
    if (notificationRows.isEmpty) return const [];

    final ids = notificationRows.map((row) => row['id'].toString()).toList();
    final readRows = await _supabase
        .from('notification_reads')
        .select('notification_id')
        .eq('user_id', user.id)
        .inFilter('notification_id', ids);
    final readIds = {
      for (final row
          in (readRows as List<dynamic>).cast<Map<String, dynamic>>())
        row['notification_id'].toString(),
    };

    return notificationRows
        .map(
          (row) => StudentNotification(
            id: row['id'].toString(),
            title: row['title'].toString(),
            body: row['body'].toString(),
            createdAt: _parseDate(row['created_at']) ?? DateTime.now(),
            isRead: readIds.contains(row['id'].toString()),
            deepLink: row['deep_link']?.toString(),
            targetUserId: row['target_user_id']?.toString(),
            messageKind: (row['message_kind'] ?? 'text').toString(),
            attachmentUrl: row['attachment_url']?.toString(),
            attachmentName: row['attachment_name']?.toString(),
            attachmentMime: row['attachment_mime']?.toString(),
            replyToInboxMessageId: row['reply_to_inbox_message_id']?.toString(),
          ),
        )
        .toList();
  }

  Future<void> markNotificationRead(String notificationId) async {
    final accessToken = _supabase.auth.currentSession?.accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      throw const AuthException('Sessiya topilmadi. Qayta kiring.');
    }

    final response = await http.post(
      Uri.parse(
        '${ApiEndpoints.authBaseUrl}${ApiEndpoints.markNotificationRead}',
      ),
      headers: {
        'Content-Type': 'application/json',
        'apikey': SupabaseConfig.anonKey,
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({'notificationId': notificationId}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _errorMessage(response.body) ??
            'Xabarnoma o‘qildi deb belgilab bo‘lmadi.',
      );
    }
  }

  Future<void> markAllNotificationsRead(List<String> notificationIds) async {
    if (notificationIds.isEmpty) return;
    for (final id in notificationIds) {
      await markNotificationRead(id);
    }
  }

  Future<void> sendNotification({
    required String title,
    required String body,
    String targetRole = 'student',
    String? targetUserId,
    String messageKind = 'text',
    String? attachmentUrl,
    String? attachmentName,
    String? attachmentMime,
    int? attachmentSize,
    String? replyToInboxMessageId,
  }) async {
    final user = await _currentUserOrThrow();
    await _supabase.from('notifications').insert({
      'title': title.trim(),
      'body': body.trim(),
      'target_role': targetRole,
      'target_user_id': targetUserId,
      'message_kind': messageKind,
      'attachment_url': attachmentUrl,
      'attachment_name': attachmentName,
      'attachment_mime': attachmentMime,
      'attachment_size': attachmentSize,
      'reply_to_inbox_message_id': replyToInboxMessageId,
      'created_by': user.id,
    });
  }

  Future<void> sendAdminInboxMessage({
    required String subject,
    required String body,
    String messageKind = 'text',
    String? attachmentUrl,
    String? attachmentName,
    String? attachmentMime,
    int? attachmentSize,
  }) async {
    final user = await _currentUserOrThrow();
    final profile = await _loadProfile(user);
    await _supabase.from('admin_inbox_messages').insert({
      'source': 'student_app',
      'sender_user_id': user.id,
      'sender_name': profile.fullName.trim(),
      'sender_phone': profile.phone.trim(),
      'subject': subject.trim(),
      'body': body.trim(),
      'message_kind': messageKind,
      'attachment_url': attachmentUrl,
      'attachment_name': attachmentName,
      'attachment_mime': attachmentMime,
      'attachment_size': attachmentSize,
      'metadata': {
        'app_user_id': user.id,
        'full_name': profile.fullName.trim(),
        'phone': profile.phone.trim(),
        'last_seen_at': DateTime.now().toIso8601String(),
        'source_device': 'student_app',
      },
    });
  }

  Future<List<AdminInboxMessage>> loadAdminInboxMessages({
    int limit = 20,
  }) async {
    final rows = await _supabase
        .from('admin_inbox_messages')
        .select(
          'id, source, sender_user_id, sender_name, sender_phone, telegram_chat_id, subject, body, is_read, admin_reply, replied_at, created_at, message_kind, attachment_url, attachment_name, attachment_mime, attachment_size, admin_read_at, recipient_read_at',
        )
        .order('created_at', ascending: false)
        .limit(limit);

    return (rows as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(AdminInboxMessage.fromMap)
        .toList();
  }

  Future<List<AdminInboxMessage>> loadStudentSupportMessages({
    int limit = 12,
  }) async {
    final user = await _currentUserOrThrow();
    final rows = await _supabase
        .from('admin_inbox_messages')
        .select(
          'id, source, sender_user_id, sender_name, sender_phone, telegram_chat_id, subject, body, is_read, admin_reply, replied_at, created_at, message_kind, attachment_url, attachment_name, attachment_mime, attachment_size, admin_read_at, recipient_read_at',
        )
        .eq('sender_user_id', user.id)
        .eq('source', 'student_app')
        .order('created_at', ascending: false)
        .limit(limit);

    return (rows as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(AdminInboxMessage.fromMap)
        .toList();
  }

  Future<int> loadAdminUnreadInboxCount() async {
    final rows = await _supabase
        .from('admin_inbox_messages')
        .select('id')
        .eq('is_read', false);
    return (rows as List<dynamic>).length;
  }

  Future<void> markAdminInboxMessageRead(String id) async {
    final accessToken = _supabase.auth.currentSession?.accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      throw const AuthException('Sessiya topilmadi. Qayta kiring.');
    }

    final response = await http.post(
      Uri.parse(
        '${ApiEndpoints.authBaseUrl}${ApiEndpoints.markAdminInboxRead}',
      ),
      headers: {
        'Content-Type': 'application/json',
        'apikey': SupabaseConfig.anonKey,
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({'messageId': id}),
    );

    final payload = response.body.isEmpty
        ? const <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      throw Exception(
        (payload['error'] ?? 'Inbox xabarini o‘qildi qilish bo‘lmadi.')
            .toString(),
      );
    }
  }

  Future<void> markAllAdminInboxMessagesRead() async {
    final unreadRows = await _supabase
        .from('admin_inbox_messages')
        .select('id')
        .eq('is_read', false);
    for (final row
        in (unreadRows as List<dynamic>).cast<Map<String, dynamic>>()) {
      await markAdminInboxMessageRead(row['id'].toString());
    }
  }

  Future<void> sendAdminReply({
    required String messageId,
    required String replyText,
    String messageKind = 'text',
    String? attachmentUrl,
    String? attachmentName,
    String? attachmentMime,
    int? attachmentSize,
  }) async {
    final accessToken = _supabase.auth.currentSession?.accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      throw const AuthException('Sessiya topilmadi. Qayta kiring.');
    }

    final response = await http.post(
      Uri.parse('${ApiEndpoints.authBaseUrl}${ApiEndpoints.sendAdminReply}'),
      headers: {
        'Content-Type': 'application/json',
        'apikey': SupabaseConfig.anonKey,
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({
        'messageId': messageId,
        'replyText': replyText.trim(),
        'messageKind': messageKind,
        'attachmentUrl': attachmentUrl,
        'attachmentName': attachmentName,
        'attachmentMime': attachmentMime,
        'attachmentSize': attachmentSize,
      }),
    );

    final payload = response.body.isEmpty
        ? const <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      throw Exception(
        (payload['error'] ?? 'Admin javobini yuborib bo‘lmadi.').toString(),
      );
    }
  }

  Future<List<StudentNotification>> loadAdminNotifications({
    int limit = 10,
  }) async {
    final rows = await _supabase
        .from('notifications')
        .select(
          'id, title, body, deep_link, created_at, target_user_id, message_kind, attachment_url, attachment_name, attachment_mime, reply_to_inbox_message_id',
        )
        .order('created_at', ascending: false)
        .limit(limit);

    final notificationRows = (rows as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final ids = notificationRows.map((row) => row['id'].toString()).toList();
    final readRows = ids.isEmpty
        ? const <Map<String, dynamic>>[]
        : ((await _supabase
                      .from('notification_reads')
                      .select('notification_id')
                      .inFilter('notification_id', ids))
                  as List<dynamic>)
              .cast<Map<String, dynamic>>();
    final readIds = {
      for (final row in readRows) row['notification_id'].toString(),
    };

    return notificationRows
        .map(
          (row) => StudentNotification(
            id: row['id'].toString(),
            title: row['title'].toString(),
            body: row['body'].toString(),
            createdAt: _parseDate(row['created_at']) ?? DateTime.now(),
            isRead: readIds.contains(row['id'].toString()),
            deepLink: row['deep_link']?.toString(),
            targetUserId: row['target_user_id']?.toString(),
            messageKind: (row['message_kind'] ?? 'text').toString(),
            attachmentUrl: row['attachment_url']?.toString(),
            attachmentName: row['attachment_name']?.toString(),
            attachmentMime: row['attachment_mime']?.toString(),
            replyToInboxMessageId: row['reply_to_inbox_message_id']?.toString(),
          ),
        )
        .toList();
  }

  Future<StudentProfile> updateStudentProfile(
    StudentProfileUpdate profile,
  ) async {
    final user = await _currentUserOrThrow();
    final accessToken = _supabase.auth.currentSession?.accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      throw const AuthException('Sessiya topilmadi. Qayta kiring.');
    }

    final response = await http.post(
      Uri.parse('${ApiEndpoints.authBaseUrl}${ApiEndpoints.updateProfile}'),
      headers: {
        'Content-Type': 'application/json',
        'apikey': SupabaseConfig.anonKey,
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({
        'firstName': profile.firstName.trim(),
        'lastName': profile.lastName.trim(),
        'phone': profile.phone.trim(),
        'gender': profile.gender.trim(),
        'age': profile.age,
        'region': profile.region.trim(),
        'district': profile.district.trim(),
        'mahalla': profile.mahalla.trim(),
        'street': profile.street.trim(),
        'avatarUrl': profile.avatarUrl?.trim(),
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthException(_errorMessage(response.body) ?? 'Profil saqlanmadi.');
    }

    return _loadProfile(user);
  }

  Future<StudentProfile> loadCurrentProfile() async {
    final user = await _currentUserOrThrow();
    return _loadProfile(user);
  }

  Future<StudentProfile> updateOwnProfile(StudentProfileUpdate profile) async {
    final user = await _currentUserOrThrow();
    final phone = profile.phone.trim().isEmpty
        ? (user.phone ?? '').trim()
        : profile.phone.trim();
    final current = await _loadProfile(user);
    final fullName = profile.fullName.trim().isEmpty
        ? current.fullName.trim()
        : profile.fullName.trim();
    final avatarUrl = profile.avatarUrl?.trim();

    final payload = {
      'id': user.id,
      'full_name': fullName.isEmpty ? 'Student' : fullName,
      'phone': phone.isEmpty ? null : phone,
      'role': current.role.name,
      'avatar_url': avatarUrl == null || avatarUrl.isEmpty
          ? current.avatarUrl.trim()
          : avatarUrl,
      'gender': profile.gender.trim(),
      'age': profile.age,
      'region': profile.region.trim(),
      'district': profile.district.trim(),
      'mahalla': profile.mahalla.trim(),
      'street': profile.street.trim(),
      'updated_at': DateTime.now().toIso8601String(),
    };

    final updated = await _supabase
        .from('profiles')
        .update(payload)
        .eq('id', user.id)
        .select('id')
        .maybeSingle();

    if (updated == null) {
      await _supabase.from('profiles').insert(payload);
    }

    return _loadProfile(user);
  }

  Future<Map<String, List<Map<String, dynamic>>>> loadStudentBilling() async {
    final user = await _currentUserOrThrow();

    Future<List<Map<String, dynamic>>> readRows(
      String table,
      String select,
    ) async {
      try {
        final rows = await _supabase.from(table).select(select);
        return (rows as List<dynamic>).cast<Map<String, dynamic>>();
      } on Object {
        return const <Map<String, dynamic>>[];
      }
    }

    Future<List<Map<String, dynamic>>> readUserRows(
      String table,
      String select,
    ) async {
      try {
        final rows = await _supabase
            .from(table)
            .select(select)
            .eq('user_id', user.id)
            .order('created_at', ascending: false);
        return (rows as List<dynamic>).cast<Map<String, dynamic>>();
      } on Object {
        return const <Map<String, dynamic>>[];
      }
    }

    Future<Map<String, dynamic>?> readProfileSubscription() async {
      try {
        final row = await _supabase
            .from('profiles')
            .select(
              'is_premium, premium_plan_id, premium_start_date, premium_end_date, subscription_plans(name, title, price, duration_days)',
            )
            .eq('id', user.id)
            .maybeSingle();
        if (row == null) return null;
        return row;
      } on Object {
        return null;
      }
    }

    final profileSubscription = await readProfileSubscription();
    final activeProfileSubscription = profileSubscription == null
        ? <Map<String, dynamic>>[]
        : <Map<String, dynamic>>[
            {
              'id': profileSubscription['premium_plan_id'],
              'plan_key':
                  profileSubscription['subscription_plans']?['name'] ??
                  profileSubscription['subscription_plans']?['title'] ??
                  'Premium',
              'status': profileSubscription['is_premium'] == true
                  ? 'active'
                  : 'inactive',
              'current_period_start': profileSubscription['premium_start_date'],
              'current_period_end': profileSubscription['premium_end_date'],
              'subscription_plans': profileSubscription['subscription_plans'],
            },
          ];

    final subscriptions = await readUserRows(
      'subscriptions',
      'id, plan_key, billing_interval, status, amount, currency, current_period_start, current_period_end, created_at',
    );
    final legacySubscriptions = await readUserRows(
      'user_subscriptions',
      'id, status, starts_at, ends_at, created_at, subscription_plans(title, price_label, duration_months)',
    );
    final transactions = await readUserRows(
      'subscription_payments',
      'id, amount, currency, status, created_at, paid_at, subscription_plans(name, title), payment_methods(name, code)',
    );
    final plans = await readRows(
      'subscription_plans',
      'id, title, name, duration_months, duration_days, price_label, price, discount_percent, is_popular, is_active, features, sort_order, created_at',
    );
    final paymentMethods = await readRows(
      'payment_methods',
      'id, name, code, is_active, sort_order, created_at',
    );

    return {
      'subscriptions': [...activeProfileSubscription, ...subscriptions],
      'legacySubscriptions': legacySubscriptions,
      'transactions': transactions,
      'plans': plans.where((row) => row['is_active'] != false).toList()
        ..sort(
          (a, b) => ((a['sort_order'] as num?)?.toInt() ?? 0).compareTo(
            (b['sort_order'] as num?)?.toInt() ?? 0,
          ),
        ),
      'paymentMethods':
          paymentMethods.where((row) => row['is_active'] != false).toList()
            ..sort(
              (a, b) => ((a['sort_order'] as num?)?.toInt() ?? 0).compareTo(
                (b['sort_order'] as num?)?.toInt() ?? 0,
              ),
            ),
    };
  }

  Future<String> purchaseSubscription({
    required String planId,
    required String paymentMethodId,
  }) async {
    final response = await _supabase.rpc<String>(
      'purchase_subscription',
      params: {'p_plan_id': planId, 'p_payment_method_id': paymentMethodId},
    );
    return response;
  }

  Future<Map<String, List<Map<String, dynamic>>>>
  loadStudentSecurityAudit() async {
    final user = await _currentUserOrThrow();

    Future<List<Map<String, dynamic>>> readRows(
      String table,
      String select,
    ) async {
      try {
        final rows = await _supabase
            .from(table)
            .select(select)
            .eq('user_id', user.id)
            .order('created_at', ascending: false)
            .limit(12);
        return (rows as List<dynamic>).cast<Map<String, dynamic>>();
      } on Object {
        return const <Map<String, dynamic>>[];
      }
    }

    final devices = await readRows(
      'devices',
      'id, device_name, platform, browser, ip_address, location, last_seen_at, revoked_at, created_at',
    );
    final legacySessions = devices.isEmpty
        ? await readRows(
            'active_sessions',
            'id, device_name, browser, ip_address, location, last_seen_at, revoked_at, created_at',
          )
        : const <Map<String, dynamic>>[];

    return {
      'devices': devices.isNotEmpty ? devices : legacySessions,
      'loginHistory': await readRows(
        'login_history',
        'id, ip_address, user_agent, location, success, created_at',
      ),
    };
  }

  Future<void> saveStudentSecurityPreferences({
    required bool pinEnabled,
    required bool biometricEnabled,
  }) async {
    final user = await _currentUserOrThrow();
    try {
      await _supabase.from('user_security').upsert({
        'user_id': user.id,
        'pin_enabled': pinEnabled,
        'biometric_enabled': biometricEnabled,
        'pin_updated_at': pinEnabled ? DateTime.now().toIso8601String() : null,
        'biometric_updated_at': biometricEnabled
            ? DateTime.now().toIso8601String()
            : null,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } on Object {
      // The secure PIN itself is local-only. If the remote metadata table is not
      // applied yet, keep the local security setting working.
    }
  }

  Future<void> signOutEverywhere() async {
    await _currentUserOrThrow();
    await _supabase.auth.signOut(scope: SignOutScope.global);
  }

  Future<String> uploadProfileAvatar({
    required Uint8List bytes,
    required String extension,
  }) async {
    final user = await _currentUserOrThrow();
    final safeExtension = extension.toLowerCase().replaceAll('.', '');
    final path =
        '${user.id}/avatar_${DateTime.now().millisecondsSinceEpoch}.$safeExtension';

    await _supabase.storage
        .from('avatars')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            upsert: true,
            contentType: _contentTypeForExtension(safeExtension),
          ),
        );

    return _supabase.storage.from('avatars').getPublicUrl(path);
  }

  Future<String> uploadModuleCover({
    required Uint8List bytes,
    required String extension,
  }) async {
    final cloudinaryUrl = await _tryCloudinaryUpload(
      bytes: bytes,
      extension: extension,
      kind: 'image',
      fileName: 'module-cover.$extension',
      folder: 'labproof-academy/modules',
    );
    if (cloudinaryUrl != null) return cloudinaryUrl;

    final user = await _currentUserOrThrow();
    final safeExtension = extension.toLowerCase().replaceAll('.', '');
    final path =
        '${user.id}/module_cover_${DateTime.now().millisecondsSinceEpoch}.$safeExtension';

    await _supabase.storage
        .from('module-covers')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            upsert: true,
            contentType: _contentTypeForExtension(safeExtension),
          ),
        );

    return _supabase.storage.from('module-covers').getPublicUrl(path);
  }

  Future<String> uploadTopicCover({
    required Uint8List bytes,
    required String extension,
  }) async {
    final cloudinaryUrl = await _tryCloudinaryUpload(
      bytes: bytes,
      extension: extension,
      kind: 'image',
      fileName: 'topic-cover.$extension',
      folder: 'labproof-academy/topics',
    );
    if (cloudinaryUrl != null) return cloudinaryUrl;

    final user = await _currentUserOrThrow();
    final safeExtension = extension.toLowerCase().replaceAll('.', '');
    final path =
        '${user.id}/topic_cover_${DateTime.now().millisecondsSinceEpoch}.$safeExtension';

    await _supabase.storage
        .from('module-covers')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            upsert: true,
            contentType: _contentTypeForExtension(safeExtension),
          ),
        );

    return _supabase.storage.from('module-covers').getPublicUrl(path);
  }

  Future<String> uploadChatAttachment({
    required Uint8List bytes,
    required String extension,
    String? fileName,
    String kind = 'file',
  }) async {
    final cloudinaryUrl = await _tryCloudinaryUpload(
      bytes: bytes,
      extension: extension,
      kind: kind,
      fileName: fileName,
      folder: 'labproof-academy/chat',
    );
    if (cloudinaryUrl != null) return cloudinaryUrl;

    final user = await _currentUserOrThrow();
    final safeExtension = extension.toLowerCase().replaceAll('.', '');
    final rawName = (fileName ?? 'attachment').replaceAll(
      RegExp(r'[^a-zA-Z0-9._-]'),
      '_',
    );
    final sanitizedName = rawName.endsWith('.$safeExtension')
        ? rawName.substring(0, rawName.length - safeExtension.length - 1)
        : rawName;
    final path =
        '${user.id}/chat_${DateTime.now().millisecondsSinceEpoch}_$sanitizedName.$safeExtension';

    await _supabase.storage
        .from('chat-attachments')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            upsert: true,
            contentType: _contentTypeForExtension(safeExtension),
          ),
        );

    return _supabase.storage.from('chat-attachments').getPublicUrl(path);
  }

  Future<String> uploadCommunityImage({
    required Uint8List bytes,
    required String extension,
    String? fileName,
  }) async {
    final user = await _currentUserOrThrow();
    final safeExtension = extension.toLowerCase().replaceAll('.', '');
    final rawName = (fileName ?? 'community-image').replaceAll(
      RegExp(r'[^a-zA-Z0-9._-]'),
      '_',
    );
    final sanitizedName = rawName.endsWith('.$safeExtension')
        ? rawName.substring(0, rawName.length - safeExtension.length - 1)
        : rawName;
    final path =
        '${user.id}/community_${DateTime.now().millisecondsSinceEpoch}_$sanitizedName.$safeExtension';

    await _supabase.storage
        .from('chat-attachments')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            upsert: true,
            contentType: _contentTypeForExtension(safeExtension),
          ),
        );

    return _supabase.storage.from('chat-attachments').getPublicUrl(path);
  }

  Future<String?> _tryCloudinaryUpload({
    required Uint8List bytes,
    required String extension,
    required String kind,
    String? fileName,
    String? folder,
  }) async {
    try {
      final normalizedKind = _normalizeCloudinaryKind(kind);
      final response = await _supabase.functions.invoke(
        'cloudinary-upload',
        body: {
          'fileBase64': base64Encode(bytes),
          'extension': extension.toLowerCase().replaceAll('.', ''),
          'kind': normalizedKind,
          'fileName': fileName,
          'folder': folder,
        },
      );
      final data = response.data;
      if (response.status >= 200 &&
          response.status < 300 &&
          data is Map &&
          data['secure_url'] != null) {
        return data['secure_url'].toString();
      }
    } on Object {
      // If the Cloudinary edge function is not deployed yet, keep the app usable
      // with the existing Supabase Storage path.
    }
    return null;
  }

  String _normalizeCloudinaryKind(String kind) {
    switch (kind) {
      case 'image':
      case 'video':
      case 'round_video':
      case 'voice':
      case 'pdf':
      case 'document':
      case 'text':
        return kind;
      case 'video_note':
        return 'round_video';
      case 'audio':
        return 'voice';
      default:
        return 'file';
    }
  }

  Future<StudentProfile> _loadProfile(User user) async {
    final row = await _loadProfileRow(user.id);

    final metadata = user.userMetadata ?? {};
    final roleName = (row?['role'] ?? 'student').toString();
    final rowPhone = (row?['phone'] ?? '').toString().trim();
    final authPhone = (user.phone ?? '').trim();

    return StudentProfile(
      id: user.id,
      fullName: (row?['full_name'] ?? metadata['full_name'] ?? 'Student')
          .toString(),
      phone: rowPhone.isNotEmpty ? rowPhone : authPhone,
      role: roleName == 'admin' ? UserRole.admin : UserRole.student,
      studentCode: (row?['student_code'] ?? '').toString(),
      avatarUrl: (row?['avatar_url'] ?? '').toString(),
      createdAt: _parseDate(row?['created_at']),
      gender: (row?['gender'] ?? '').toString(),
      age: (row?['age'] as num?)?.round(),
      region: (row?['region'] ?? '').toString(),
      district: (row?['district'] ?? '').toString(),
      mahalla: (row?['mahalla'] ?? '').toString(),
      street: (row?['street'] ?? '').toString(),
    );
  }

  Future<Map<String, dynamic>?> _loadProfileRow(String userId) async {
    const fullColumns =
        'id, full_name, phone, role, student_code, avatar_url, gender, age, region, district, mahalla, street, created_at';
    const fallbackColumns =
        'id, full_name, phone, role, avatar_url, gender, age, region, district, mahalla, street, created_at';

    try {
      return await _supabase
          .from('profiles')
          .select(fullColumns)
          .eq('id', userId)
          .maybeSingle();
    } on PostgrestException catch (error) {
      if (!error.message.toLowerCase().contains('student_code')) rethrow;
      return _supabase
          .from('profiles')
          .select(fallbackColumns)
          .eq('id', userId)
          .maybeSingle();
    }
  }

  Future<String> _loadActivePremiumLabel(String userId) async {
    try {
      final subscription = await _supabase
          .from('subscriptions')
          .select('plan_key, billing_interval, status')
          .eq('user_id', userId)
          .eq('status', 'active')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (subscription != null) {
        final plan = (subscription['plan_key'] ?? 'Premium').toString().trim();
        final interval = (subscription['billing_interval'] ?? '').toString();
        return interval.isEmpty ? plan : '$plan · $interval';
      }
    } on Object {
      // Older databases may only have the legacy subscription tables.
    }

    try {
      final legacy = await _supabase
          .from('user_subscriptions')
          .select('status, subscription_plans(title)')
          .eq('user_id', userId)
          .eq('status', 'active')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (legacy != null) {
        return (legacy['subscription_plans']?['title'] ?? 'Premium')
            .toString()
            .trim();
      }
    } on Object {
      // Keep profile usable if subscription tables are not exposed yet.
    }

    return '';
  }

  Future<List<AcademyModule>> _loadModules(String userId) async {
    final moduleRows = await _fetchStudentModuleRows();

    final topicRows = await _fetchStudentTopicRows();

    final lessonRows = await _fetchStudentLessonRows();

    final progressRows = await _supabase
        .from('topic_progress')
        .select(
          'topic_id, pdf_completed, video_completed, quiz_completed, quiz_score',
        )
        .eq('user_id', userId);

    final questionRows = await _fetchStudentQuestionRows();

    final moduleResultRows = await _supabase
        .from('module_results')
        .select('module_id, passed')
        .eq('user_id', userId);

    final topicsByModule = <String, List<Map<String, dynamic>>>{};
    for (final row
        in (topicRows as List<dynamic>).cast<Map<String, dynamic>>()) {
      final moduleId = row['module_id'].toString();
      topicsByModule.putIfAbsent(moduleId, () => []).add(row);
    }

    final lessonsByTopic = <String, List<Map<String, dynamic>>>{};
    for (final row
        in (lessonRows as List<dynamic>).cast<Map<String, dynamic>>()) {
      final topicId = row['topic_id'].toString();
      lessonsByTopic.putIfAbsent(topicId, () => []).add(row);
    }

    final progressByTopic = <String, Map<String, dynamic>>{};
    for (final row
        in (progressRows as List<dynamic>).cast<Map<String, dynamic>>()) {
      progressByTopic[row['topic_id'].toString()] = row;
    }

    final questionsByTopic = <String, List<QuizQuestion>>{};
    final finalQuestionsByModule = <String, List<QuizQuestion>>{};
    for (final row
        in (questionRows as List<dynamic>).cast<Map<String, dynamic>>()) {
      final topicId = row['topic_id']?.toString();
      final moduleId = row['module_id']?.toString();
      if (topicId != null && topicId != 'null') {
        questionsByTopic
            .putIfAbsent(topicId, () => [])
            .add(_quizQuestionFromRow(row, topicId));
      } else if (moduleId != null && moduleId != 'null') {
        finalQuestionsByModule
            .putIfAbsent(moduleId, () => [])
            .add(_quizQuestionFromRow(row, moduleId));
      }
    }

    final passedModules = <String>{
      for (final row
          in (moduleResultRows as List<dynamic>).cast<Map<String, dynamic>>())
        if (row['passed'] == true) row['module_id'].toString(),
    };

    final sortedModules =
        (moduleRows as List<dynamic>).cast<Map<String, dynamic>>().toList()
          ..sort(
            (a, b) => ((a['order_index'] as num?)?.round() ?? 0).compareTo(
              (b['order_index'] as num?)?.round() ?? 0,
            ),
          );

    final modules = <AcademyModule>[];
    var previousModulePassed = true;

    for (final row in sortedModules) {
      final moduleId = row['id'].toString();
      final rawTopics =
          List<Map<String, dynamic>>.from(topicsByModule[moduleId] ?? const [])
            ..sort(
              (a, b) => ((a['order_index'] as num?)?.round() ?? 0).compareTo(
                (b['order_index'] as num?)?.round() ?? 0,
              ),
            );
      final orderIndex = (row['order_index'] as num?)?.round() ?? 1;
      const freeTopicLimit = 1;
      final isUnlocked = orderIndex == 1 || previousModulePassed;
      var firstIncompleteMarked = false;

      final topics = rawTopics.asMap().entries.map((entry) {
        final topicIndex = entry.key;
        final topicRow = entry.value;
        final topicId = topicRow['id'].toString();
        final progress = progressByTopic[topicId];
        final lessons = lessonsByTopic[topicId] ?? const [];
        final materials = lessons.map(_lessonMaterialFromRow).toList();
        final pdfLesson = _firstLesson(lessons, {'pdf', 'text', 'link'});
        final videoLesson = _firstLesson(lessons, {'video'});
        final topicQuestions =
            questionsByTopic[topicId] ?? const <QuizQuestion>[];
        final hasReadingContent =
            pdfLesson != null ||
            materials.any((item) => item.isPdf || item.isText || item.isLink);
        final hasVideoContent =
            videoLesson != null || materials.any((item) => item.isVideo);
        final readingDone =
            !hasReadingContent || progress?['pdf_completed'] == true;
        final videoDone =
            !hasVideoContent || progress?['video_completed'] == true;
        final quizDone =
            topicQuestions.isEmpty || progress?['quiz_completed'] == true;
        final topicCompleted = readingDone && videoDone && quizDone;
        final isFreePreview = topicIndex < freeTopicLimit;
        final requiresSubscription = !isFreePreview;
        final status = !isUnlocked || requiresSubscription
            ? TopicStatus.locked
            : topicCompleted
            ? TopicStatus.completed
            : firstIncompleteMarked
            ? TopicStatus.locked
            : TopicStatus.current;
        if (status == TopicStatus.current) firstIncompleteMarked = true;

        return TopicLesson(
          id: topicId,
          moduleId: moduleId,
          title: topicRow['title'].toString(),
          summary: (topicRow['description'] ?? '').toString(),
          coverUrl: (topicRow['cover_url'] ?? '').toString(),
          pdfTitle: (pdfLesson?['title'] ?? 'PDF/Text dars').toString(),
          videoTitle: (videoLesson?['title'] ?? 'Video dars').toString(),
          duration: Duration(
            seconds: (videoLesson?['duration_seconds'] as num?)?.round() ?? 0,
          ),
          status: status,
          quizScore: ((progress?['quiz_score'] as num?) ?? 0).toDouble() / 100,
          formula: (pdfLesson?['body'] ?? '').toString(),
          pdfUrl: (pdfLesson?['file_url'] ?? '').toString(),
          videoUrl: (videoLesson?['file_url'] ?? '').toString(),
          videoChapters: _lessonChaptersFromValue(videoLesson?['chapters']),
          quizQuestions: topicQuestions,
          materials: materials,
          isFreePreview: isFreePreview,
          requiresSubscription: requiresSubscription,
        );
      }).toList();

      final completedTopics = topics
          .where((topic) => topic.status == TopicStatus.completed)
          .length;
      final progress = topics.isEmpty ? 0.0 : completedTopics / topics.length;

      final title = row['title'].toString();
      String category = 'Barchasi';
      final lowerTitle = title.toLowerCase();
      if (lowerTitle.contains('kardio')) {
        category = 'Kardiologiya';
      } else if (lowerTitle.contains('biokim')) {
        category = 'Biokimyo';
      } else if (lowerTitle.contains('gemat') || lowerTitle.contains('gemot')) {
        category = 'Gemotologiya';
      } else if (lowerTitle.contains('mikrob')) {
        category = 'Mikrobiologiya';
      }

      final module = AcademyModule(
        id: moduleId,
        title: title,
        description: (row['description'] ?? '').toString(),
        order: orderIndex,
        coverUrl: (row['cover_url'] ?? '').toString(),
        progress: progress,
        isUnlocked: isUnlocked,
        isPassed: passedModules.contains(moduleId),
        studentCount: 0,
        completionRate: progress,
        topics: topics,
        category: category,
        finalQuestions: finalQuestionsByModule[moduleId] ?? const [],
        freeTopicLimit: freeTopicLimit,
        requiresSubscription: topics.any((topic) => topic.requiresSubscription),
        subscriptionPriceLabel: (row['subscription_price_label'] ?? '')
            .toString(),
      );

      modules.add(module);
      previousModulePassed = module.isPassed;
    }

    return modules;
  }

  Future<List<Map<String, dynamic>>> _fetchStudentModuleRows() async {
    const baseColumns =
        'id, title, description, order_index, cover_url, is_locked, is_published';
    const extendedColumns =
        '$baseColumns, free_topic_limit, requires_subscription, subscription_price_label';
    try {
      final rows = await _supabase
          .from('modules')
          .select(extendedColumns)
          .order('order_index');
      return (rows as List<dynamic>).cast<Map<String, dynamic>>();
    } on Object catch (error) {
      if (!_isTopicMetadataColumnError(error)) rethrow;
      final rows = await _supabase
          .from('modules')
          .select(baseColumns)
          .order('order_index');
      return (rows as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(
            (row) => {
              ...row,
              'free_topic_limit': 1,
              'requires_subscription': false,
              'subscription_price_label': '',
            },
          )
          .toList();
    }
  }

  Future<List<Map<String, dynamic>>> _fetchStudentTopicRows() async {
    const baseColumns =
        'id, module_id, title, description, order_index, cover_url';
    const extendedColumns = '$baseColumns, is_free, requires_subscription';
    try {
      final rows = await _supabase
          .from('topics')
          .select(extendedColumns)
          .order('order_index');
      return (rows as List<dynamic>).cast<Map<String, dynamic>>();
    } on Object catch (error) {
      if (!_isTopicMetadataColumnError(error)) rethrow;
      final rows = await _supabase
          .from('topics')
          .select(baseColumns)
          .order('order_index');
      return (rows as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(
            (row) => {...row, 'is_free': false, 'requires_subscription': false},
          )
          .toList();
    }
  }

  Future<List<Map<String, dynamic>>> _fetchStudentQuestionRows() async {
    const baseColumns =
        'topic_id, module_id, question, option_a, option_b, option_c, option_d, correct_option';
    const extendedColumns =
        '$baseColumns, question_type, media_url, media_kind, explanation';
    try {
      final rows = await _supabase
          .from('quiz_questions')
          .select(extendedColumns);
      return (rows as List<dynamic>).cast<Map<String, dynamic>>();
    } on Object catch (error) {
      if (!_isTopicMetadataColumnError(error)) rethrow;
      final rows = await _supabase.from('quiz_questions').select(baseColumns);
      return (rows as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(
            (row) => {
              ...row,
              'question_type': 'text',
              'media_url': '',
              'media_kind': '',
              'explanation': '',
            },
          )
          .toList();
    }
  }

  Future<List<Map<String, dynamic>>> _fetchStudentLessonRows() async {
    const baseColumns = 'topic_id, kind, title, body, file_url, order_index';
    const extendedColumns =
        '$baseColumns, duration_seconds, source_type, chapters';

    try {
      final rows = await _supabase
          .from('lessons')
          .select(extendedColumns)
          .order('order_index');
      return (rows as List<dynamic>).cast<Map<String, dynamic>>();
    } on Object catch (error) {
      if (!_isTopicMetadataColumnError(error)) rethrow;
      final rows = await _supabase
          .from('lessons')
          .select(baseColumns)
          .order('order_index');
      return (rows as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(
            (row) => {
              ...row,
              'duration_seconds': 0,
              'source_type': '',
              'chapters': const [],
            },
          )
          .toList();
    }
  }

  Map<String, dynamic>? _firstLesson(
    List<Map<String, dynamic>> lessons,
    Set<String> kinds,
  ) {
    for (final lesson in lessons) {
      final kind = (lesson['kind'] ?? '').toString().toLowerCase();
      if (kinds.contains(kind)) return lesson;
    }
    return null;
  }

  LessonMaterial _lessonMaterialFromRow(Map<String, dynamic> row) {
    final kind = (row['kind'] ?? '').toString().toLowerCase();
    return LessonMaterial(
      kind: kind,
      title: (row['title'] ?? _defaultLessonTitle(kind)).toString(),
      body: (row['body'] ?? '').toString(),
      url: (row['file_url'] ?? '').toString(),
      duration: Duration(
        seconds: (row['duration_seconds'] as num?)?.round() ?? 0,
      ),
      sourceType: (row['source_type'] ?? '').toString(),
      chapters: _lessonChaptersFromValue(row['chapters']),
    );
  }

  List<VideoLessonChapter> _lessonChaptersFromValue(Object? value) {
    if (value is! List) return const [];

    final chapters = <VideoLessonChapter>[];
    for (final item in value) {
      if (item is! Map) continue;
      final title = (item['title'] ?? item['label'] ?? '').toString().trim();
      if (title.isEmpty) continue;

      final seconds = _chapterSecondsFromValue(
        item['time_seconds'] ??
            item['seconds'] ??
            item['start_seconds'] ??
            item['time'],
      );
      chapters.add(
        VideoLessonChapter(
          time: Duration(seconds: seconds),
          title: title,
        ),
      );
    }

    chapters.sort((a, b) => a.time.compareTo(b.time));
    return List.unmodifiable(chapters);
  }

  int _chapterSecondsFromValue(Object? value) {
    if (value is num) return _clampChapterSeconds(value.round());

    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) return 0;

    final numeric = int.tryParse(text);
    if (numeric != null) return _clampChapterSeconds(numeric);

    final parts = text.split(':').map((part) => int.tryParse(part.trim()));
    if (parts.any((part) => part == null)) return 0;

    final values = parts.cast<int>().toList(growable: false);
    if (values.length == 2) {
      return _clampChapterSeconds(values[0] * 60 + values[1]);
    }
    if (values.length == 3) {
      return _clampChapterSeconds(
        values[0] * 3600 + values[1] * 60 + values[2],
      );
    }

    return 0;
  }

  int _clampChapterSeconds(int value) => value.clamp(0, 24 * 60 * 60).toInt();

  String _defaultLessonTitle(String kind) {
    switch (kind) {
      case 'pdf':
        return 'PDF dars';
      case 'text':
        return 'Matn dars';
      case 'video':
        return 'Video dars';
      case 'link':
        return 'Havola';
      default:
        return 'Dars materiali';
    }
  }

  QuizQuestion _quizQuestionFromRow(Map<String, dynamic> row, String ownerId) {
    final options = <String>[
      row['option_a'].toString(),
      row['option_b'].toString(),
      row['option_c'].toString(),
      if ((row['option_d'] ?? '').toString().trim().isNotEmpty)
        row['option_d'].toString(),
    ];
    final rawCorrect = _correctOptionIndex(row['correct_option'].toString());
    final correctIndex = rawCorrect >= options.length ? 0 : rawCorrect;
    return QuizQuestion(
      topic: ownerId,
      question: row['question'].toString(),
      options: options,
      correctIndex: correctIndex,
      questionType: (row['question_type'] ?? 'text').toString(),
      mediaUrl: (row['media_url'] ?? '').toString(),
      mediaKind: (row['media_kind'] ?? '').toString(),
      explanation: (row['explanation'] ?? '').toString(),
    );
  }

  int _correctOptionIndex(String option) {
    switch (option.toLowerCase()) {
      case 'b':
        return 1;
      case 'c':
        return 2;
      case 'd':
        return 3;
      case 'a':
      default:
        return 0;
    }
  }

  Future<AdminDashboardData> loadAdminDashboard() async {
    final modules = await loadAdminModules();
    final students = await loadAdminStudents();
    final notifications = await loadAdminNotifications(limit: 20);

    final profileRows = await _fetchProfileRows();
    final topicRows = await _fetchTopicRows();
    final questionRows = await _fetchQuestionRows();
    final progressRows = await _fetchProgressRows();
    final resultRows = await _fetchModuleResultRows();
    final certificateRows = await _fetchCertificateRows();

    final studentProfiles = profileRows
        .where((row) => row['role'].toString() == 'student')
        .toList();

    final now = DateTime.now();
    final growthChart = List<double>.generate(7, (index) {
      final day = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: 6 - index));
      return studentProfiles
          .where((row) => _isSameDay(_parseDate(row['created_at']) ?? now, day))
          .length
          .toDouble();
    });

    final activeRecentUsers = _uniqueUserCountByRange(
      progressRows: progressRows,
      resultRows: resultRows,
      start: DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(const Duration(days: 29)),
      end: now,
    );
    final activePreviousUsers = _uniqueUserCountByRange(
      progressRows: progressRows,
      resultRows: resultRows,
      start: DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(const Duration(days: 59)),
      end: DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(const Duration(days: 30)),
    );

    final recentStudentsCount = studentProfiles
        .where(
          (row) => (_parseDate(row['created_at']) ?? now).isAfter(
            DateTime(
              now.year,
              now.month,
              now.day,
            ).subtract(const Duration(days: 7)),
          ),
        )
        .length;
    final previousStudentsCount = studentProfiles.where((row) {
      final createdAt = _parseDate(row['created_at']) ?? now;
      final start = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(const Duration(days: 14));
      final end = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(const Duration(days: 7));
      return createdAt.isAfter(start) && createdAt.isBefore(end);
    }).length;

    final recentModulesCount = modules
        .where(
          (row) => row.createdAt.isAfter(
            DateTime(
              now.year,
              now.month,
              now.day,
            ).subtract(const Duration(days: 30)),
          ),
        )
        .length;
    final recentTopicsCount = topicRows
        .where(
          (row) => (_parseDate(row['created_at']) ?? now).isAfter(
            DateTime(
              now.year,
              now.month,
              now.day,
            ).subtract(const Duration(days: 30)),
          ),
        )
        .length;
    final recentQuestionsCount = questionRows
        .where(
          (row) => (_parseDate(row['created_at']) ?? now).isAfter(
            DateTime(
              now.year,
              now.month,
              now.day,
            ).subtract(const Duration(days: 30)),
          ),
        )
        .length;

    final completionValues = modules
        .map((module) => module.completionRate * 100)
        .toList(growable: false);
    final completionPercent = modules.isEmpty
        ? 0.0
        : modules.fold<double>(
                0,
                (sum, module) => sum + module.completionRate,
              ) /
              modules.length;
    final completedCount = modules
        .where((module) => module.completionRate >= 0.7)
        .length;
    final inProgressCount = modules
        .where(
          (module) => module.completionRate > 0 && module.completionRate < 0.7,
        )
        .length;
    final notStartedCount = modules
        .where((module) => module.completionRate == 0)
        .length;

    final metrics = [
      AdminMetric(
        title: 'Jami talabalar',
        value: studentProfiles.length.toString(),
        delta: _percentDeltaText(recentStudentsCount, previousStudentsCount),
        icon: Icons.people_alt_rounded,
        color: AppColors.primaryBlue,
      ),
      AdminMetric(
        title: 'Faol foydalanuvchilar',
        value: activeRecentUsers.toString(),
        delta: _percentDeltaText(activeRecentUsers, activePreviousUsers),
        icon: Icons.person_pin_rounded,
        color: AppColors.successGreen,
      ),
      AdminMetric(
        title: 'Modullar soni',
        value: modules.length.toString(),
        delta: _countDeltaText(recentModulesCount),
        icon: Icons.view_module_rounded,
        color: AppColors.violet,
      ),
      AdminMetric(
        title: 'Mavzular soni',
        value: topicRows.length.toString(),
        delta: _countDeltaText(recentTopicsCount),
        icon: Icons.topic_rounded,
        color: AppColors.amber,
      ),
      AdminMetric(
        title: 'Testlar soni',
        value: questionRows.length.toString(),
        delta: _countDeltaText(recentQuestionsCount),
        icon: Icons.fact_check_rounded,
        color: AppColors.errorRed,
      ),
    ];

    final topModules = [...modules]
      ..sort((a, b) => b.studentCount.compareTo(a.studentCount));

    final activities = <ActivityItem>[
      ...notifications
          .take(3)
          .map(
            (item) => ActivityItem(
              title: item.title,
              subtitle: item.body,
              icon: Icons.notifications_active_rounded,
              color: AppColors.primaryBlue,
            ),
          ),
      ...certificateRows
          .take(2)
          .map(
            (_) => const ActivityItem(
              title: 'Sertifikat yaratildi',
              subtitle: 'Yakuniy imtihondan o‘tgan talabaga sertifikat berildi',
              icon: Icons.workspace_premium_rounded,
              color: AppColors.violet,
            ),
          ),
      ...resultRows
          .where((row) => row['passed'] == false)
          .take(2)
          .map(
            (_) => const ActivityItem(
              title: 'Yakuniy imtihon qayta topshirilishi kerak',
              subtitle: 'Ba’zi talabalar modulni qayta o‘qish bosqichida',
              icon: Icons.restart_alt_rounded,
              color: AppColors.amber,
            ),
          ),
    ];

    return AdminDashboardData(
      metrics: metrics,
      growthChart: growthChart,
      completionChart: completionValues.isEmpty ? const [0] : completionValues,
      activities: activities,
      topModules: topModules.take(4).toList(),
      recentStudents: students.take(5).toList(),
      completionPercent: completionPercent,
      completedCount: completedCount,
      inProgressCount: inProgressCount,
      notStartedCount: notStartedCount,
      notificationCount: notifications.length,
      recentStudentsCount: recentStudentsCount,
      activeUsersCount: activeRecentUsers,
      certificateCount: certificateRows.length,
    );
  }

  Future<List<double>> loadAdminGrowthChart({int days = 7}) async {
    final profileRows = await _fetchProfileRows();
    final studentProfiles = profileRows
        .where((row) => row['role'].toString() == 'student')
        .toList();
    final now = DateTime.now();

    return List<double>.generate(days, (index) {
      final day = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: (days - 1) - index));
      return studentProfiles
          .where((row) => _isSameDay(_parseDate(row['created_at']) ?? now, day))
          .length
          .toDouble();
    });
  }

  Future<List<AdminModuleSummary>> loadAdminModules() async {
    final moduleRows = await _fetchModuleRows();
    final topicRows = await _fetchTopicRows();
    final resultRows = await _fetchModuleResultRows();

    final topicsByModule = <String, int>{};
    for (final row in topicRows) {
      final moduleId = row['module_id'].toString();
      topicsByModule[moduleId] = (topicsByModule[moduleId] ?? 0) + 1;
    }

    final studentsByModule = <String, Set<String>>{};
    final passedByModule = <String, int>{};
    final attemptsByModule = <String, int>{};
    for (final row in resultRows) {
      final moduleId = row['module_id'].toString();
      studentsByModule
          .putIfAbsent(moduleId, () => <String>{})
          .add(row['user_id'].toString());
      attemptsByModule[moduleId] = (attemptsByModule[moduleId] ?? 0) + 1;
      if (row['passed'] == true) {
        passedByModule[moduleId] = (passedByModule[moduleId] ?? 0) + 1;
      }
    }

    final modules = moduleRows.map((row) {
      final moduleId = row['id'].toString();
      final attempts = attemptsByModule[moduleId] ?? 0;
      final passed = passedByModule[moduleId] ?? 0;
      return AdminModuleSummary(
        id: moduleId,
        title: row['title'].toString(),
        description: (row['description'] ?? '').toString(),
        orderIndex: (row['order_index'] as num?)?.round() ?? 0,
        coverUrl: (row['cover_url'] ?? '').toString(),
        levelLabel: (row['level_label'] ?? '').toString(),
        durationLabel: (row['duration_label'] ?? '').toString(),
        isPublished: row['is_published'] == true,
        isLocked: row['is_locked'] == true,
        isSequential: row['is_sequential'] == true,
        passingScore: (row['passing_score'] as num?)?.round() ?? 70,
        topicCount: topicsByModule[moduleId] ?? 0,
        studentCount: studentsByModule[moduleId]?.length ?? 0,
        completionRate: attempts == 0 ? 0 : passed / attempts,
        createdAt: _parseDate(row['created_at']) ?? DateTime.now(),
        updatedAt: _parseDate(row['updated_at']) ?? DateTime.now(),
      );
    }).toList()..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

    return modules;
  }

  Future<List<AdminTopicSummary>> loadAdminTopics({String? moduleId}) async {
    final moduleRows = await _fetchModuleRows();
    final topicRows = await _fetchTopicRows(moduleId: moduleId);
    final lessonRows = await _fetchLessonRows();
    final questionRows = await _fetchQuestionRows();
    final progressRows = await _fetchProgressRows();

    final moduleTitles = {
      for (final row in moduleRows)
        row['id'].toString(): row['title'].toString(),
    };
    final lessonsByTopic = <String, List<Map<String, dynamic>>>{};
    for (final row in lessonRows) {
      lessonsByTopic.putIfAbsent(row['topic_id'].toString(), () => []).add(row);
    }
    final quizCountByTopic = <String, int>{};
    for (final row in questionRows) {
      final topicId = row['topic_id']?.toString();
      if (topicId == null || topicId == 'null') continue;
      quizCountByTopic[topicId] = (quizCountByTopic[topicId] ?? 0) + 1;
    }
    final completedCountByTopic = <String, int>{};
    for (final row in progressRows) {
      if (row['quiz_completed'] == true) {
        final topicId = row['topic_id'].toString();
        completedCountByTopic[topicId] =
            (completedCountByTopic[topicId] ?? 0) + 1;
      }
    }

    return topicRows.map((row) {
      final topicId = row['id'].toString();
      final lessons = lessonsByTopic[topicId] ?? const [];
      final lessonDurationSeconds = lessons.fold<int>(
        0,
        (sum, item) => sum + ((item['duration_seconds'] as num?)?.round() ?? 0),
      );
      return AdminTopicSummary(
        id: topicId,
        moduleId: row['module_id'].toString(),
        moduleTitle: moduleTitles[row['module_id'].toString()] ?? 'Modul',
        title: row['title'].toString(),
        description: (row['description'] ?? '').toString(),
        orderIndex: (row['order_index'] as num?)?.round() ?? 0,
        coverUrl: (row['cover_url'] ?? '').toString(),
        isPublished: row['is_published'] == true,
        lessonCount: lessons.length,
        hasPdfOrText: lessons.any(
          (item) => item['kind'] == 'pdf' || item['kind'] == 'text',
        ),
        hasVideo: lessons.any((item) => item['kind'] == 'video'),
        quizCount: quizCountByTopic[topicId] ?? 0,
        completedStudentCount: completedCountByTopic[topicId] ?? 0,
        durationSeconds: lessonDurationSeconds > 0
            ? lessonDurationSeconds
            : 600,
        createdAt: _parseDate(row['created_at']) ?? DateTime.now(),
        updatedAt: _parseDate(row['updated_at']) ?? DateTime.now(),
      );
    }).toList()..sort((a, b) {
      final moduleCompare = a.moduleTitle.compareTo(b.moduleTitle);
      if (moduleCompare != 0) return moduleCompare;
      return a.orderIndex.compareTo(b.orderIndex);
    });
  }

  Future<List<AdminLessonSummary>> loadAdminLessons({
    String? moduleId,
    String? topicId,
    String? kind,
  }) async {
    final moduleRows = await _fetchModuleRows();
    final topicRows = await _fetchTopicRows(moduleId: moduleId);
    final topicIds = topicRows.map((row) => row['id'].toString()).toSet();
    final lessonRows = await _fetchLessonRows();

    final moduleTitles = {
      for (final row in moduleRows)
        row['id'].toString(): row['title'].toString(),
    };
    final topicById = {for (final row in topicRows) row['id'].toString(): row};

    return lessonRows
        .where((row) {
          final matchesTopic =
              topicId == null || row['topic_id'].toString() == topicId;
          final matchesKind = kind == null || row['kind'].toString() == kind;
          final matchesModule =
              moduleId == null || topicIds.contains(row['topic_id'].toString());
          return matchesTopic && matchesKind && matchesModule;
        })
        .map((row) {
          final topic = topicById[row['topic_id'].toString()];
          final moduleKey = topic?['module_id']?.toString() ?? '';
          return AdminLessonSummary(
            id: row['id'].toString(),
            topicId: row['topic_id'].toString(),
            topicTitle: topic?['title']?.toString() ?? 'Mavzu',
            moduleId: moduleKey,
            moduleTitle: moduleTitles[moduleKey] ?? 'Modul',
            kind: row['kind'].toString(),
            title: row['title'].toString(),
            body: (row['body'] ?? '').toString(),
            fileUrl: (row['file_url'] ?? '').toString(),
            durationSeconds: (row['duration_seconds'] as num?)?.round() ?? 0,
            orderIndex: (row['order_index'] as num?)?.round() ?? 0,
            createdAt: _parseDate(row['created_at']) ?? DateTime.now(),
            updatedAt: _parseDate(row['updated_at']) ?? DateTime.now(),
          );
        })
        .toList()
      ..sort((a, b) {
        final moduleCompare = a.moduleTitle.compareTo(b.moduleTitle);
        if (moduleCompare != 0) return moduleCompare;
        final topicCompare = a.topicTitle.compareTo(b.topicTitle);
        if (topicCompare != 0) return topicCompare;
        return a.orderIndex.compareTo(b.orderIndex);
      });
  }

  Future<List<AdminQuestionSummary>> loadAdminQuestions({
    required bool finalExamOnly,
    String? moduleId,
    String? topicId,
  }) async {
    final moduleRows = await _fetchModuleRows();
    final topicRows = await _fetchTopicRows(moduleId: moduleId);
    final questionRows = await _fetchQuestionRows();
    final moduleTitles = {
      for (final row in moduleRows)
        row['id'].toString(): row['title'].toString(),
    };
    final topicTitles = {
      for (final row in topicRows)
        row['id'].toString(): row['title'].toString(),
    };

    return questionRows
        .where((row) {
          final isFinal = row['module_id'] != null && row['topic_id'] == null;
          if (finalExamOnly != isFinal) return false;
          if (topicId != null && row['topic_id']?.toString() != topicId) {
            return false;
          }
          if (moduleId != null) {
            if (isFinal) return row['module_id']?.toString() == moduleId;
            final topicModuleId = topicRows
                .firstWhere(
                  (topic) =>
                      topic['id'].toString() == row['topic_id'].toString(),
                  orElse: () => <String, dynamic>{},
                )['module_id']
                ?.toString();
            return topicModuleId == moduleId;
          }
          return true;
        })
        .map((row) {
          final isFinal = row['module_id'] != null && row['topic_id'] == null;
          final scopeId = (isFinal ? row['module_id'] : row['topic_id'])
              .toString();
          return AdminQuestionSummary(
            id: row['id'].toString(),
            scopeType: isFinal ? 'module' : 'topic',
            scopeId: scopeId,
            scopeTitle: isFinal
                ? moduleTitles[scopeId] ?? 'Modul yakuniy testi'
                : topicTitles[scopeId] ?? 'Mavzu testi',
            question: row['question'].toString(),
            optionA: row['option_a'].toString(),
            optionB: row['option_b'].toString(),
            optionC: row['option_c'].toString(),
            optionD: (row['option_d'] ?? '').toString(),
            correctOption: row['correct_option'].toString(),
            difficulty: (row['difficulty'] ?? 'medium').toString(),
            points: (row['points'] as num?)?.round() ?? 1,
            createdAt: _parseDate(row['created_at']) ?? DateTime.now(),
            questionType: (row['question_type'] ?? 'text').toString(),
            mediaUrl: (row['media_url'] ?? '').toString(),
            mediaKind: (row['media_kind'] ?? '').toString(),
            explanation: (row['explanation'] ?? '').toString(),
          );
        })
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<List<AdminStudentSummary>> loadAdminStudents() async {
    final profileRows = await _fetchProfileRows();
    final moduleRows = await _fetchModuleRows();
    final topicRows = await _fetchTopicRows();
    final progressRows = await _fetchProgressRows();
    final resultRows = await _fetchModuleResultRows();
    final certificateRows = await _fetchCertificateRows();

    final modulesById = {
      for (final row in moduleRows)
        row['id'].toString(): row['title'].toString(),
    };
    final topicModuleById = {
      for (final row in topicRows)
        row['id'].toString(): row['module_id'].toString(),
    };
    final totalTopics = topicRows.length;

    final progressByUser = <String, List<Map<String, dynamic>>>{};
    for (final row in progressRows) {
      progressByUser.putIfAbsent(row['user_id'].toString(), () => []).add(row);
    }
    final resultsByUser = <String, List<Map<String, dynamic>>>{};
    for (final row in resultRows) {
      resultsByUser.putIfAbsent(row['user_id'].toString(), () => []).add(row);
    }
    final certificatesByUser = <String, int>{};
    for (final row in certificateRows) {
      certificatesByUser[row['user_id'].toString()] =
          (certificatesByUser[row['user_id'].toString()] ?? 0) + 1;
    }

    return profileRows.where((row) => row['role'].toString() == 'student').map((
      row,
    ) {
      final userId = row['id'].toString();
      final progress = progressByUser[userId] ?? const [];
      final results = resultsByUser[userId] ?? const [];
      final completedTopics = progress
          .where((item) => item['quiz_completed'] == true)
          .length;
      final moduleIdFromProgress = progress.isEmpty
          ? null
          : topicModuleById[progress.last['topic_id'].toString()];
      final latestResult = results.isEmpty
          ? null
          : (results.toList()..sort(
                  (a, b) => (_parseDate(b['created_at']) ?? DateTime.now())
                      .compareTo(_parseDate(a['created_at']) ?? DateTime.now()),
                ))
                .first;
      final activeModuleTitle = moduleIdFromProgress != null
          ? modulesById[moduleIdFromProgress]
          : latestResult == null
          ? 'Modul biriktirilmagan'
          : modulesById[latestResult['module_id'].toString()];
      final score = results.isEmpty
          ? 0
          : (results.fold<int>(
                      0,
                      (sum, item) =>
                          sum + ((item['score'] as num?)?.round() ?? 0),
                    ) /
                    results.length)
                .round();
      final status = score >= 70
          ? 'Yaxshi'
          : score >= 50
          ? 'O‘rtacha'
          : results.isEmpty
          ? 'Jarayonda'
          : 'Qoniqarsiz';

      return AdminStudentSummary(
        id: userId,
        fullName: row['full_name'].toString(),
        phone: (row['phone'] ?? '').toString(),
        moduleTitle: activeModuleTitle ?? 'Modul biriktirilmagan',
        score: score,
        progress: totalTopics == 0 ? 0 : completedTopics / totalTopics,
        status: status,
        certificateCount: certificatesByUser[userId] ?? 0,
        createdAt: _parseDate(row['created_at']) ?? DateTime.now(),
      );
    }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<List<AdminCertificateSummary>> loadAdminCertificates() async {
    final certificateRows = await _fetchCertificateRows();
    final profileRows = await _fetchProfileRows();
    final moduleRows = await _fetchModuleRows();

    final profileNames = {
      for (final row in profileRows)
        row['id'].toString(): row['full_name'].toString(),
    };
    final moduleTitles = {
      for (final row in moduleRows)
        row['id'].toString(): row['title'].toString(),
    };

    return certificateRows.map((row) {
      return AdminCertificateSummary(
        id: row['id'].toString(),
        studentName: profileNames[row['user_id'].toString()] ?? 'Student',
        moduleTitle: moduleTitles[row['module_id'].toString()] ?? 'Modul',
        certificateUrl: (row['certificate_url'] ?? '').toString(),
        issuedAt: _parseDate(row['issued_at']) ?? DateTime.now(),
        certificateCode: (row['certificate_code'] ?? row['id']).toString(),
        verifyUrl: (row['verify_url'] ?? '').toString(),
        qrCodeUrl: (row['qr_code_url'] ?? '').toString(),
        status: (row['status'] ?? 'issued').toString(),
      );
    }).toList()..sort((a, b) => b.issuedAt.compareTo(a.issuedAt));
  }

  Future<List<AdminMediaSummary>> loadAdminMediaItems() async {
    final mediaLibraryRows = await _fetchMediaLibraryRows();
    final lessonRows = await _fetchLessonRows();
    final profileRows = await _fetchProfileRows();
    final certificateRows = await _fetchCertificateRows();
    final items = <AdminMediaSummary>[];

    for (final row in mediaLibraryRows) {
      final url = (row['secure_url'] ?? '').toString().trim();
      if (url.isEmpty) continue;
      items.add(
        AdminMediaSummary(
          title: (row['original_filename'] ?? row['public_id'] ?? 'Media fayl')
              .toString(),
          kind: (row['kind'] ?? _kindFromResource(row)).toString(),
          url: url,
          updatedAt: _parseDate(row['created_at']) ?? DateTime.now(),
          publicId: (row['public_id'] ?? '').toString(),
          resourceType: (row['resource_type'] ?? '').toString(),
          format: (row['format'] ?? '').toString(),
          bytes: (row['bytes'] as num?)?.round() ?? 0,
          durationSeconds: (row['duration'] as num?)?.round(),
          width: (row['width'] as num?)?.round(),
          height: (row['height'] as num?)?.round(),
          source: 'cloudinary',
          usedIn: _usedInFromMetadata(row['metadata']),
        ),
      );
    }

    for (final row in lessonRows) {
      final url = (row['file_url'] ?? '').toString().trim();
      if (url.isEmpty) continue;
      items.add(
        AdminMediaSummary(
          title: row['title'].toString(),
          kind: row['kind'].toString(),
          url: url,
          updatedAt: _parseDate(row['updated_at']) ?? DateTime.now(),
          format: _extensionFromUrl(url).toUpperCase(),
          source: 'lesson',
          usedIn: [row['title'].toString()],
        ),
      );
    }
    for (final row in profileRows) {
      final url = (row['avatar_url'] ?? '').toString().trim();
      if (url.isEmpty) continue;
      items.add(
        AdminMediaSummary(
          title: '${row['full_name']} avatar',
          kind: 'avatar',
          url: url,
          updatedAt: _parseDate(row['updated_at']) ?? DateTime.now(),
          format: _extensionFromUrl(url).toUpperCase(),
          source: 'profile',
          usedIn: ['Profil'],
        ),
      );
    }
    for (final row in certificateRows) {
      final url = (row['certificate_url'] ?? '').toString().trim();
      if (url.isEmpty) continue;
      items.add(
        AdminMediaSummary(
          title: 'Certificate ${row['id']}',
          kind: 'certificate',
          url: url,
          updatedAt: _parseDate(row['issued_at']) ?? DateTime.now(),
          format: _extensionFromUrl(url).toUpperCase(),
          source: 'certificate',
          usedIn: ['Sertifikatlar'],
        ),
      );
    }

    items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return items;
  }

  String _kindFromResource(Map<String, dynamic> row) {
    final resourceType = (row['resource_type'] ?? '').toString();
    final format = (row['format'] ?? '').toString().toLowerCase();
    if (resourceType == 'image') return 'image';
    if (resourceType == 'video') {
      if ({'mp3', 'wav', 'ogg', 'm4a'}.contains(format)) return 'voice';
      return 'video';
    }
    if (format == 'pdf') return 'pdf';
    if (format == 'txt') return 'text';
    return 'document';
  }

  List<String> _usedInFromMetadata(Object? value) {
    if (value is Map<String, dynamic>) {
      final usedIn = value['used_in'];
      if (usedIn is List) {
        return usedIn.map((item) => item.toString()).toList();
      }
      final source = value['source'];
      if (source != null) return [source.toString()];
    }
    return const [];
  }

  String _extensionFromUrl(String url) {
    final path = Uri.tryParse(url)?.path ?? url.split('?').first;
    final name = path.split('/').last;
    if (!name.contains('.')) return '';
    return name.split('.').last;
  }

  Future<List<AdminRoleSummary>> loadAdminRoles() async {
    final profileRows = await _fetchProfileRows();
    final counts = <String, int>{};
    for (final row in profileRows) {
      final role = row['role'].toString();
      counts[role] = (counts[role] ?? 0) + 1;
    }
    return counts.entries
        .map((entry) => AdminRoleSummary(role: entry.key, count: entry.value))
        .toList()
      ..sort((a, b) => a.role.compareTo(b.role));
  }

  Future<void> saveModule({
    String? id,
    required String title,
    required String description,
    required int orderIndex,
    required String coverUrl,
    required String levelLabel,
    required String durationLabel,
    required bool isPublished,
    required bool isLocked,
    required bool isSequential,
    required int passingScore,
    int freeTopicLimit = 1,
    bool requiresSubscription = false,
    String subscriptionPriceLabel = '',
  }) async {
    final payload = {
      'title': title.trim(),
      'description': description.trim(),
      'order_index': orderIndex,
      'cover_url': coverUrl.trim(),
      'level_label': levelLabel.trim(),
      'duration_label': durationLabel.trim(),
      'is_published': isPublished,
      'is_locked': isLocked,
      'is_sequential': isSequential,
      'passing_score': passingScore,
      'free_topic_limit': freeTopicLimit,
      'requires_subscription': requiresSubscription,
      'subscription_price_label': subscriptionPriceLabel.trim(),
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (id == null) {
      await _supabase.from('modules').insert(payload);
    } else {
      await _supabase.from('modules').update(payload).eq('id', id);
    }
  }

  Future<void> deleteModule(String id) {
    return _supabase.from('modules').delete().eq('id', id);
  }

  Future<String> saveTopic({
    String? id,
    required String moduleId,
    required String title,
    required String description,
    required int orderIndex,
    required bool isPublished,
    int? durationSeconds,
    String? coverUrl,
  }) async {
    final payload = {
      'module_id': moduleId,
      'title': title.trim(),
      'description': description.trim(),
      'order_index': orderIndex,
      'is_published': isPublished,
      'updated_at': DateTime.now().toIso8601String(),
    };
    // The live topics table does not currently include duration_seconds.
    // Duration is derived from attached lessons/videos until that schema exists.
    if (coverUrl != null) {
      payload['cover_url'] = coverUrl.trim();
    }
    try {
      if (id == null) {
        final inserted = await _supabase
            .from('topics')
            .insert(payload)
            .select('id')
            .single();
        return inserted['id'].toString();
      } else {
        await _supabase.from('topics').update(payload).eq('id', id);
        return id;
      }
    } on Object catch (error) {
      if (!_isTopicMetadataColumnError(error)) rethrow;
      payload.remove('duration_seconds');
      payload.remove('cover_url');
      if (id == null) {
        final inserted = await _supabase
            .from('topics')
            .insert(payload)
            .select('id')
            .single();
        return inserted['id'].toString();
      }
      await _supabase.from('topics').update(payload).eq('id', id);
      return id;
    }
  }

  Future<void> deleteTopic(String id) {
    return _supabase.from('topics').delete().eq('id', id);
  }

  Future<void> saveLesson({
    String? id,
    required String topicId,
    required String kind,
    required String title,
    required String body,
    required String fileUrl,
    required int durationSeconds,
    required int orderIndex,
  }) async {
    final payload = {
      'topic_id': topicId,
      'kind': kind,
      'title': title.trim(),
      'body': body.trim().isEmpty ? null : body.trim(),
      'file_url': fileUrl.trim().isEmpty ? null : fileUrl.trim(),
      'duration_seconds': durationSeconds,
      'order_index': orderIndex,
      'updated_at': DateTime.now().toIso8601String(),
    };
    try {
      if (id == null) {
        await _supabase.from('lessons').insert(payload);
      } else {
        await _supabase.from('lessons').update(payload).eq('id', id);
      }
    } on Object catch (error) {
      if (!_isTopicMetadataColumnError(error)) rethrow;
      final fallbackPayload = Map<String, dynamic>.from(payload)
        ..remove('duration_seconds');
      if (id == null) {
        await _supabase.from('lessons').insert(fallbackPayload);
      } else {
        await _supabase.from('lessons').update(fallbackPayload).eq('id', id);
      }
    }
  }

  Future<void> deleteLesson(String id) {
    return _supabase.from('lessons').delete().eq('id', id);
  }

  Future<void> saveQuestion({
    String? id,
    String? topicId,
    String? moduleId,
    required String question,
    required String optionA,
    required String optionB,
    required String optionC,
    required String optionD,
    required String correctOption,
    required String difficulty,
    required int points,
    String questionType = 'text',
    String mediaUrl = '',
    String mediaKind = '',
    String explanation = '',
  }) async {
    final payload = {
      'topic_id': topicId,
      'module_id': moduleId,
      'question': question.trim(),
      'option_a': optionA.trim(),
      'option_b': optionB.trim(),
      'option_c': optionC.trim(),
      'option_d': optionD.trim().isEmpty ? null : optionD.trim(),
      'correct_option': correctOption,
      'difficulty': difficulty,
      'points': points,
      'question_type': questionType,
      'media_url': mediaUrl.trim().isEmpty ? null : mediaUrl.trim(),
      'media_kind': mediaKind.trim().isEmpty ? null : mediaKind.trim(),
      'explanation': explanation.trim().isEmpty ? null : explanation.trim(),
    };
    try {
      if (id == null) {
        await _supabase.from('quiz_questions').insert(payload);
      } else {
        await _supabase.from('quiz_questions').update(payload).eq('id', id);
      }
    } on Object catch (error) {
      if (!_isTopicMetadataColumnError(error)) rethrow;
      final fallbackPayload = Map<String, dynamic>.from(payload)
        ..remove('question_type')
        ..remove('media_url')
        ..remove('media_kind')
        ..remove('explanation');
      if (id == null) {
        await _supabase.from('quiz_questions').insert(fallbackPayload);
      } else {
        await _supabase
            .from('quiz_questions')
            .update(fallbackPayload)
            .eq('id', id);
      }
    }
  }

  Future<void> deleteQuestion(String id) {
    return _supabase.from('quiz_questions').delete().eq('id', id);
  }

  Future<List<Map<String, dynamic>>> _fetchProfileRows() async {
    final rows = await _supabase
        .from('profiles')
        .select(
          'id, full_name, phone, role, avatar_url, gender, age, region, district, mahalla, street, created_at, updated_at',
        );
    return (rows as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> _fetchModuleRows() async {
    final rows = await _supabase
        .from('modules')
        .select(
          'id, title, description, order_index, cover_url, level_label, duration_label, is_published, is_locked, is_sequential, passing_score, created_at, updated_at',
        )
        .order('order_index');
    return (rows as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> _fetchTopicRows({String? moduleId}) async {
    const baseColumns =
        'id, module_id, title, description, order_index, is_published, created_at, updated_at';
    const extendedColumns = '$baseColumns, cover_url';
    try {
      return await _fetchTopicRowsWithColumns(
        moduleId: moduleId,
        columns: extendedColumns,
      );
    } on Object catch (error) {
      if (!_isTopicMetadataColumnError(error)) rethrow;
      return await _fetchTopicRowsWithColumns(
        moduleId: moduleId,
        columns: baseColumns,
      );
    }
  }

  Future<List<Map<String, dynamic>>> _fetchTopicRowsWithColumns({
    required String columns,
    String? moduleId,
  }) async {
    final rows = moduleId == null
        ? await _supabase.from('topics').select(columns).order('order_index')
        : await _supabase
              .from('topics')
              .select(columns)
              .eq('module_id', moduleId)
              .order('order_index');
    return (rows as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> _fetchLessonRows() async {
    const baseColumns =
        'id, topic_id, kind, title, body, file_url, order_index, created_at, updated_at';
    const extendedColumns = '$baseColumns, duration_seconds';

    try {
      final rows = await _supabase
          .from('lessons')
          .select(extendedColumns)
          .order('order_index');
      return (rows as List<dynamic>).cast<Map<String, dynamic>>();
    } on Object catch (error) {
      if (!_isTopicMetadataColumnError(error)) rethrow;
      final rows = await _supabase
          .from('lessons')
          .select(baseColumns)
          .order('order_index');
      return (rows as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map((row) => {...row, 'duration_seconds': 0})
          .toList();
    }
  }

  Future<List<Map<String, dynamic>>> _fetchQuestionRows() async {
    const baseColumns =
        'id, topic_id, module_id, question, option_a, option_b, option_c, option_d, correct_option, difficulty, points, created_at';
    const extendedColumns =
        '$baseColumns, question_type, media_url, media_kind, explanation';
    try {
      final rows = await _supabase
          .from('quiz_questions')
          .select(extendedColumns);
      return (rows as List<dynamic>).cast<Map<String, dynamic>>();
    } on Object catch (error) {
      if (!_isTopicMetadataColumnError(error)) rethrow;
      final rows = await _supabase.from('quiz_questions').select(baseColumns);
      return (rows as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(
            (row) => {
              ...row,
              'question_type': 'text',
              'media_url': '',
              'media_kind': '',
              'explanation': '',
            },
          )
          .toList();
    }
  }

  Future<List<Map<String, dynamic>>> _fetchProgressRows() async {
    final rows = await _supabase
        .from('topic_progress')
        .select(
          'user_id, topic_id, pdf_completed, video_completed, quiz_completed, quiz_score, updated_at, completed_at',
        );
    return (rows as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> _fetchModuleResultRows() async {
    final rows = await _supabase
        .from('module_results')
        .select('user_id, module_id, score, passed, created_at, attempt_count');
    return (rows as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> _fetchCertificateRows() async {
    const baseColumns = 'id, user_id, module_id, certificate_url, issued_at';
    const extendedColumns =
        '$baseColumns, certificate_code, qr_code_url, verify_url, status';
    try {
      final rows = await _supabase.from('certificates').select(extendedColumns);
      return (rows as List<dynamic>).cast<Map<String, dynamic>>();
    } on Object catch (error) {
      if (!_isTopicMetadataColumnError(error)) rethrow;
      final rows = await _supabase.from('certificates').select(baseColumns);
      return (rows as List<dynamic>).cast<Map<String, dynamic>>();
    }
  }

  Future<List<Map<String, dynamic>>> _fetchMediaLibraryRows() async {
    try {
      final rows = await _supabase
          .from('media_library')
          .select(
            'public_id, secure_url, resource_type, format, kind, bytes, duration, width, height, original_filename, metadata, created_at',
          )
          .order('created_at', ascending: false);
      return (rows as List<dynamic>).cast<Map<String, dynamic>>();
    } on Object catch (error) {
      final message = error.toString().toLowerCase();
      if (message.contains('media_library') ||
          message.contains('could not find') ||
          message.contains('does not exist')) {
        return const [];
      }
      rethrow;
    }
  }

  int _uniqueUserCountByRange({
    required List<Map<String, dynamic>> progressRows,
    required List<Map<String, dynamic>> resultRows,
    required DateTime start,
    required DateTime end,
  }) {
    final userIds = <String>{};
    for (final row in progressRows) {
      final updatedAt =
          _parseDate(row['updated_at']) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      if (updatedAt.isAfter(start) &&
          updatedAt.isBefore(end.add(const Duration(days: 1)))) {
        userIds.add(row['user_id'].toString());
      }
    }
    for (final row in resultRows) {
      final createdAt =
          _parseDate(row['created_at']) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      if (createdAt.isAfter(start) &&
          createdAt.isBefore(end.add(const Duration(days: 1)))) {
        userIds.add(row['user_id'].toString());
      }
    }
    return userIds.length;
  }

  String _percentDeltaText(int current, int previous) {
    if (previous <= 0) return current == 0 ? '0%' : '+100%';
    final delta = (((current - previous) / previous) * 100).round();
    return '${delta >= 0 ? '+' : ''}$delta%';
  }

  String _countDeltaText(int current) {
    return current == 0 ? '+0' : '+$current';
  }

  bool _isSameDay(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  DateTime? _parseDate(Object? value) {
    if (value == null) return null;
    final parsed = DateTime.tryParse(value.toString());
    if (parsed == null) return null;
    return parsed.toLocal();
  }

  String? _errorMessage(String body) {
    final payload = _decodeMap(body);
    return payload?['error']?.toString();
  }

  Map<String, dynamic>? _decodeMap(String body) {
    try {
      final payload = jsonDecode(body);
      if (payload is Map<String, dynamic>) return payload;
    } on Object {
      return null;
    }
    return null;
  }

  bool _isTopicMetadataColumnError(Object error) {
    final message = error.toString().toLowerCase();
    final knownOptionalColumn = [
      'duration_seconds',
      'source_type',
      'cover_url',
      'certificate_code',
      'qr_code_url',
      'verify_url',
      'status',
      'chapters',
      'question_type',
      'media_url',
      'media_kind',
      'explanation',
    ].any(message.contains);
    return knownOptionalColumn &&
        (message.contains('column') ||
            message.contains('schema cache') ||
            message.contains('pgrst204') ||
            message.contains('42703'));
  }

  String _contentTypeForExtension(String extension) {
    switch (extension) {
      case 'pdf':
        return 'application/pdf';
      case 'txt':
        return 'text/plain';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'webm':
        return 'video/webm';
      case 'mp3':
        return 'audio/mpeg';
      case 'wav':
        return 'audio/wav';
      case 'ogg':
      case 'oga':
        return 'audio/ogg';
      case 'm4a':
        return 'audio/x-m4a';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'jpg':
      case 'jpeg':
      default:
        return 'image/jpeg';
    }
  }

  // Community Methods
  Future<List<CommunityPost>> loadCommunityPosts({String? category}) async {
    try {
      final user = await _currentUserOrThrow();

      var query = _supabase
          .from('community_posts')
          .select()
          .order('created_at', ascending: false);

      final response = await query;
      var rows = (response as List<dynamic>).cast<Map<String, dynamic>>();
      final profilesById = await _loadCommunityProfiles(
        rows.map((row) => row['author_id'].toString()),
      );

      // Filter by category if needed
      if (category != null && category.isNotEmpty && category != 'Barchasi') {
        rows = rows
            .where((row) => row['category'].toString() == category)
            .toList();
      }

      // Check user's likes
      final userLikes = await _supabase
          .from('post_likes')
          .select('post_id')
          .eq('user_id', user.id);

      final likedPostIds = (userLikes as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map((row) => row['post_id'] as String)
          .toSet();

      return rows.map((row) {
        final profile = profilesById[row['author_id'].toString()];
        return CommunityPost(
          id: row['id'].toString(),
          authorId: row['author_id'].toString(),
          authorName: (profile?['full_name'] ?? 'Noma\'lum').toString(),
          authorAvatar: (profile?['avatar_url'] ?? '').toString(),
          authorBadge: _getRoleBadge(profile?['role']?.toString()),
          content: row['content'].toString(),
          likes: (row['likes_count'] as num?)?.toInt() ?? 0,
          reposts: (row['reposts_count'] as num?)?.toInt() ?? 0,
          replies:
              ((row['replies_count'] ?? row['comments_count']) as num?)
                  ?.toInt() ??
              0,
          isLiked: likedPostIds.contains(row['id'].toString()),
          isReposted: false,
          isBookmarked: false,
          createdAt: DateTime.parse(row['created_at'].toString()),
          attachments:
              (row['attachments'] as List<dynamic>?)
                  ?.map((a) => a.toString())
                  .toList() ??
              [],
          isPinned: row['is_pinned'] as bool? ?? false,
        );
      }).toList();
    } catch (error) {
      // If table doesn't exist, return empty list
      return [];
    }
  }

  Future<CommunityPost?> createPost({
    required String content,
    required String category,
    List<String>? attachments,
    String? moduleId,
    String? topicId,
  }) async {
    final user = await _currentUserOrThrow();

    final response = await _supabase
        .from('community_posts')
        .insert({
          'author_id': user.id,
          'title': _communityPostTitle(content),
          'content': content,
          'category': category,
          'attachments': attachments ?? [],
          'module_id': moduleId,
          'topic_id': topicId,
          'likes_count': 0,
          'comments_count': 0,
        })
        .select()
        .single();

    final profile = await _loadProfile(user);

    return CommunityPost(
      id: response['id'].toString(),
      authorId: user.id,
      authorName: profile.fullName,
      authorAvatar: profile.avatarUrl,
      authorBadge: _getRoleBadge(profile.role.name),
      content: response['content'].toString(),
      likes: 0,
      reposts: 0,
      replies: 0,
      isLiked: false,
      isReposted: false,
      isBookmarked: false,
      createdAt: DateTime.parse(response['created_at'].toString()),
      attachments:
          (response['attachments'] as List<dynamic>?)
              ?.map((a) => a.toString())
              .toList() ??
          [],
    );
  }

  Future<void> toggleLike(String postId) async {
    final user = await _currentUserOrThrow();

    // Check if already liked
    final existingLike = await _supabase
        .from('post_likes')
        .select()
        .eq('post_id', postId)
        .eq('user_id', user.id)
        .maybeSingle();

    if (existingLike != null) {
      // Unlike
      await _supabase.from('post_likes').delete().eq('id', existingLike['id']);
      // Note: We'll need to implement proper count updates via RPC or separate queries
    } else {
      // Like
      await _supabase.from('post_likes').insert({
        'post_id': postId,
        'user_id': user.id,
      });
      // Note: We'll need to implement proper count updates via RPC or separate queries
    }
  }

  Future<Map<String, Map<String, dynamic>>> _loadCommunityProfiles(
    Iterable<String> authorIds,
  ) async {
    final ids = authorIds
        .where((id) => id.isNotEmpty && id != 'null')
        .toSet()
        .toList(growable: false);
    if (ids.isEmpty) return const {};

    try {
      final rows = await _supabase
          .from('profiles')
          .select('id, full_name, avatar_url, role')
          .inFilter('id', ids);

      return {
        for (final row in (rows as List<dynamic>).cast<Map<String, dynamic>>())
          row['id'].toString(): row,
      };
    } on Object {
      return const {};
    }
  }

  String _getRoleBadge(String? role) {
    switch (role?.toLowerCase()) {
      case 'admin':
        return 'Admin';
      case 'teacher':
        return 'Mentor';
      case 'student':
      default:
        return 'Student';
    }
  }

  // Twitter-style Community Methods
  Future<List<CommunityPost>> loadTwitterPosts() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return [];

      var postsQuery = _supabase
          .from('community_posts')
          .select()
          .order('created_at', ascending: false)
          .limit(50);

      final postsResponse = await postsQuery;
      var posts = (postsResponse as List<dynamic>).cast<Map<String, dynamic>>();
      final profilesById = await _loadCommunityProfiles(
        posts.map((row) => row['author_id'].toString()),
      );

      final postIds = posts.map((row) => row['id'].toString()).toList();

      // Get user's reactions
      final likesResponse = await _supabase
          .from('post_likes')
          .select('post_id,reaction_type')
          .eq('user_id', user.id);

      final userReactions = <String, String>{};
      for (final row
          in (likesResponse as List<dynamic>).cast<Map<String, dynamic>>()) {
        userReactions[row['post_id'].toString()] =
            (row['reaction_type'] ?? 'like').toString();
      }

      final reactionCounts = <String, ({int likes, int dislikes})>{};
      if (postIds.isNotEmpty) {
        final reactionsResponse = await _supabase
            .from('post_likes')
            .select('post_id,reaction_type')
            .inFilter('post_id', postIds);
        for (final row
            in (reactionsResponse as List<dynamic>)
                .cast<Map<String, dynamic>>()) {
          final postId = row['post_id'].toString();
          final reaction = (row['reaction_type'] ?? 'like').toString();
          final current = reactionCounts[postId] ?? (likes: 0, dislikes: 0);
          reactionCounts[postId] = reaction == 'dislike'
              ? (likes: current.likes, dislikes: current.dislikes + 1)
              : (likes: current.likes + 1, dislikes: current.dislikes);
        }
      }

      // Get user's reposts
      final repostsResponse = await _supabase
          .from('post_reposts')
          .select('post_id')
          .eq('user_id', user.id);

      final repostedPostIds = (repostsResponse as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map((row) => row['post_id'] as String)
          .toSet();

      // Get user's bookmarks
      final bookmarksResponse = await _supabase
          .from('post_bookmarks')
          .select('post_id')
          .eq('user_id', user.id);

      final bookmarkedPostIds = (bookmarksResponse as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map((row) => row['post_id'] as String)
          .toSet();

      return posts.map((row) {
        final profile = profilesById[row['author_id'].toString()];
        final postId = row['id'].toString();
        final counts = reactionCounts[postId];
        final userReaction = userReactions[postId];
        return CommunityPost(
          id: postId,
          authorId: row['author_id'].toString(),
          authorName: (profile?['full_name'] ?? 'Noma\'lum').toString(),
          authorAvatar: (profile?['avatar_url'] ?? '').toString(),
          authorBadge: _getRoleBadge(profile?['role']?.toString()),
          content: row['content'].toString(),
          likes: counts?.likes ?? (row['likes_count'] as num?)?.toInt() ?? 0,
          dislikes: counts?.dislikes ?? 0,
          reposts: (row['reposts_count'] as num?)?.toInt() ?? 0,
          replies: (row['replies_count'] as num?)?.toInt() ?? 0,
          isLiked: userReaction == 'like',
          isDisliked: userReaction == 'dislike',
          isReposted: repostedPostIds.contains(row['id'].toString()),
          isBookmarked: bookmarkedPostIds.contains(row['id'].toString()),
          createdAt: DateTime.parse(row['created_at'].toString()),
          attachments:
              (row['attachments'] as List<dynamic>?)
                  ?.map((a) => a.toString())
                  .toList() ??
              [],
          isPinned: row['is_pinned'] as bool? ?? false,
        );
      }).toList();
    } catch (error) {
      rethrow;
    }
  }

  Future<CommunityPost> createTwitterPost({
    required String content,
    List<String>? attachments,
    String? replyToPostId,
  }) async {
    final user = await _currentUserOrThrow();

    final response = await _supabase
        .from('community_posts')
        .insert({
          'author_id': user.id,
          'title': _communityPostTitle(content),
          'content': content,
          'attachments': attachments ?? [],
          'likes_count': 0,
          'reposts_count': 0,
          'replies_count': 0,
          'views_count': 0,
        })
        .select()
        .single();

    final profile = await _loadProfile(user);

    return CommunityPost(
      id: response['id'].toString(),
      authorId: user.id,
      authorName: profile.fullName,
      authorAvatar: profile.avatarUrl,
      authorBadge: _getRoleBadge(profile.role.name),
      content: response['content'].toString(),
      likes: 0,
      reposts: 0,
      replies: 0,
      isLiked: false,
      isReposted: false,
      isBookmarked: false,
      createdAt: DateTime.parse(response['created_at'].toString()),
      attachments:
          (response['attachments'] as List<dynamic>?)
              ?.map((a) => a.toString())
              .toList() ??
          [],
    );
  }

  String _communityPostTitle(String content) {
    final normalized = content.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.isEmpty) return 'Community post';
    return normalized.length <= 80
        ? normalized
        : '${normalized.substring(0, 77)}...';
  }

  Future<void> updateTwitterPost(
    String postId, {
    required String content,
  }) async {
    await _currentUserOrThrow();
    await _supabase
        .from('community_posts')
        .update({
          'content': content,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', postId);
  }

  Future<void> deleteTwitterPost(String postId) async {
    await _currentUserOrThrow();
    await _supabase.from('community_posts').delete().eq('id', postId);
  }

  Future<void> toggleTwitterLike(String postId) async {
    await toggleTwitterReaction(postId: postId, reactionType: 'like');
  }

  Future<void> toggleTwitterDislike(String postId) async {
    await toggleTwitterReaction(postId: postId, reactionType: 'dislike');
  }

  Future<void> toggleTwitterReaction({
    required String postId,
    required String reactionType,
  }) async {
    final user = await _currentUserOrThrow();

    final existingLike = await _supabase
        .from('post_likes')
        .select()
        .eq('post_id', postId)
        .eq('user_id', user.id)
        .maybeSingle();

    if (existingLike != null &&
        (existingLike['reaction_type'] ?? 'like').toString() == reactionType) {
      await _supabase.from('post_likes').delete().eq('id', existingLike['id']);
    } else if (existingLike != null) {
      await _supabase
          .from('post_likes')
          .update({'reaction_type': reactionType})
          .eq('id', existingLike['id']);
    } else {
      await _supabase.from('post_likes').insert({
        'post_id': postId,
        'user_id': user.id,
        'reaction_type': reactionType,
      });
    }
  }

  Future<void> repostTweet(String postId) async {
    final user = await _currentUserOrThrow();

    final existingRepost = await _supabase
        .from('post_reposts')
        .select()
        .eq('post_id', postId)
        .eq('user_id', user.id)
        .maybeSingle();

    if (existingRepost != null) {
      await _supabase
          .from('post_reposts')
          .delete()
          .eq('id', existingRepost['id']);
    } else {
      await _supabase.from('post_reposts').insert({
        'post_id': postId,
        'user_id': user.id,
      });
    }
  }

  Future<void> toggleBookmark(String postId) async {
    final user = await _currentUserOrThrow();

    final existingBookmark = await _supabase
        .from('post_bookmarks')
        .select()
        .eq('post_id', postId)
        .eq('user_id', user.id)
        .maybeSingle();

    if (existingBookmark != null) {
      await _supabase
          .from('post_bookmarks')
          .delete()
          .eq('id', existingBookmark['id']);
    } else {
      await _supabase.from('post_bookmarks').insert({
        'post_id': postId,
        'user_id': user.id,
      });
    }
  }

  Future<List<CommunityReply>> loadReplies(String postId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return [];

      final response = await _supabase
          .from('post_replies')
          .select()
          .eq('post_id', postId)
          .order('created_at', ascending: true);

      final rows = (response as List<dynamic>).cast<Map<String, dynamic>>();
      final profilesById = await _loadCommunityProfiles(
        rows.map((row) => row['author_id'].toString()),
      );

      // Get user's likes for replies
      final likesResponse = await _supabase
          .from('reply_likes')
          .select('reply_id')
          .eq('user_id', user.id);

      final likedReplyIds = (likesResponse as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map((row) => row['reply_id'] as String)
          .toSet();

      return rows.map((row) {
        final profile = profilesById[row['author_id'].toString()];
        return CommunityReply(
          id: row['id'].toString(),
          postId: postId,
          authorId: row['author_id'].toString(),
          authorName: (profile?['full_name'] ?? 'Noma\'lum').toString(),
          authorAvatar: (profile?['avatar_url'] ?? '').toString(),
          authorBadge: _getRoleBadge(profile?['role']?.toString()),
          content: row['content'].toString(),
          likes: (row['likes_count'] as num?)?.toInt() ?? 0,
          isLiked: likedReplyIds.contains(row['id'].toString()),
          createdAt: DateTime.parse(row['created_at'].toString()),
          parentReplyId: row['parent_reply_id']?.toString(),
          attachments:
              (row['attachments'] as List<dynamic>?)
                  ?.map((a) => a.toString())
                  .toList() ??
              [],
        );
      }).toList();
    } catch (error) {
      return [];
    }
  }

  Future<CommunityReply> createReply({
    required String postId,
    required String content,
    String? parentReplyId,
    List<String>? attachments,
  }) async {
    final user = await _currentUserOrThrow();

    final response = await _supabase
        .from('post_replies')
        .insert({
          'post_id': postId,
          'author_id': user.id,
          'content': content,
          'parent_reply_id': parentReplyId,
          'attachments': attachments ?? [],
          'likes_count': 0,
          'replies_count': 0,
        })
        .select()
        .single();

    final profile = await _loadProfile(user);

    return CommunityReply(
      id: response['id'].toString(),
      postId: postId,
      authorId: user.id,
      authorName: profile.fullName,
      authorAvatar: profile.avatarUrl,
      authorBadge: _getRoleBadge(profile.role.name),
      content: response['content'].toString(),
      likes: 0,
      isLiked: false,
      createdAt: DateTime.parse(response['created_at'].toString()),
      parentReplyId: parentReplyId,
      attachments:
          (response['attachments'] as List<dynamic>?)
              ?.map((a) => a.toString())
              .toList() ??
          [],
    );
  }
}
