import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'app_update_service.dart';

class AppUpdateInstallerService {
  const AppUpdateInstallerService();

  static const _channel = MethodChannel('com.labproof.academy/app_update');

  Future<int?> installedVersionCode() async {
    if (kIsWeb || !Platform.isAndroid) return null;
    try {
      return await _channel.invokeMethod<int>('getVersionCode');
    } on Object {
      return null;
    }
  }

  Future<void> downloadAndInstall(
    AppRelease release, {
    required ValueChanged<double> onProgress,
  }) async {
    if (kIsWeb || !Platform.isAndroid) {
      throw const AppUpdateInstallException(
        'Yangilanish faqat Android APK ichida o‘rnatiladi.',
      );
    }

    final directory = await getTemporaryDirectory();
    final file = File(
      '${directory.path}/labproof-academy-${release.versionCode}.apk',
    );
    if (await file.exists()) {
      await file.delete();
    }

    final request = http.Request('GET', release.downloadUrl);
    final response = await http.Client().send(request);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AppUpdateInstallException(
        'APK yuklab olinmadi. Status: ${response.statusCode}',
      );
    }

    final sink = file.openWrite();
    final total = response.contentLength ?? 0;
    var received = 0;
    try {
      await for (final chunk in response.stream) {
        received += chunk.length;
        sink.add(chunk);
        if (total > 0) {
          onProgress((received / total).clamp(0.0, 1.0));
        }
      }
    } finally {
      await sink.close();
    }

    onProgress(1);

    try {
      await _channel.invokeMethod<void>('installApk', {'path': file.path});
    } on PlatformException catch (error) {
      throw AppUpdateInstallException(
        error.message ?? 'APK o‘rnatish oynasi ochilmadi.',
      );
    }
  }
}

class AppUpdateInstallException implements Exception {
  const AppUpdateInstallException(this.message);

  final String message;

  @override
  String toString() => message;
}
