import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../data/repositories/supabase_academy_repository.dart';

@pragma('vm:entry-point')
Future<void> labproofFirebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  try {
    await Firebase.initializeApp();
  } on Object {
    // Firebase config may be absent on local/web builds; background delivery is
    // still registered once Android Firebase options are bundled.
  }
}

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  bool _backgroundHandlerRegistered = false;
  bool _initialized = false;
  StreamSubscription<String>? _tokenRefreshSubscription;

  void registerBackgroundHandler() {
    if (_backgroundHandlerRegistered || kIsWeb) return;
    FirebaseMessaging.onBackgroundMessage(
      labproofFirebaseMessagingBackgroundHandler,
    );
    _backgroundHandlerRegistered = true;
  }

  Future<bool> configure({
    required SupabaseAcademyRepository repository,
    required bool enabled,
    bool requestPermission = false,
  }) async {
    if (kIsWeb) return false;

    try {
      await _ensureInitialized();
      final messaging = FirebaseMessaging.instance;

      if (!enabled) {
        final token = await messaging.getToken();
        if (token != null && token.isNotEmpty) {
          await repository.setPushTokenActive(token: token, isActive: false);
        }
        return true;
      }

      if (requestPermission) {
        final settings = await messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
        final granted =
            settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional;
        if (!granted) return false;
      }

      await _saveCurrentToken(repository);
      _tokenRefreshSubscription ??= messaging.onTokenRefresh.listen((token) {
        if (token.isEmpty) return;
        repository.savePushToken(
          token: token,
          platform: defaultTargetPlatform.name,
        );
      });
      return true;
    } on Object {
      return false;
    }
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    registerBackgroundHandler();
    await Firebase.initializeApp();
    _initialized = true;
  }

  Future<void> _saveCurrentToken(SupabaseAcademyRepository repository) async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty) return;
    final info = await PackageInfo.fromPlatform();
    await repository.savePushToken(
      token: token,
      platform: defaultTargetPlatform.name,
      appVersion: '${info.version}+${info.buildNumber}',
    );
  }
}
