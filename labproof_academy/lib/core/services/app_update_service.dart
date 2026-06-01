import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

class AppRelease {
  const AppRelease({
    required this.versionName,
    required this.versionCode,
    required this.downloadUrl,
    required this.isRequired,
    this.releaseNotes,
  });

  final String versionName;
  final int versionCode;
  final Uri downloadUrl;
  final bool isRequired;
  final String? releaseNotes;

  factory AppRelease.fromJson(Map<String, dynamic> json) {
    return AppRelease(
      versionName: json['version_name']?.toString() ?? '',
      versionCode: (json['version_code'] as num?)?.toInt() ?? 0,
      downloadUrl: Uri.parse(json['download_url']?.toString() ?? ''),
      isRequired: json['is_required'] == true,
      releaseNotes: json['release_notes']?.toString(),
    );
  }
}

class AppReleaseLookup {
  const AppReleaseLookup({
    required this.reachedServer,
    this.release,
  });

  final bool reachedServer;
  final AppRelease? release;
}

class AppUpdateService {
  const AppUpdateService({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  SupabaseClient get _supabase => _client ?? SupabaseService.client;

  Future<AppReleaseLookup> findAvailableUpdate({
    required int currentVersionCode,
    String platform = 'android',
    String channel = 'student',
  }) async {
    try {
      final row = await _supabase
          .from('app_releases')
          .select()
          .eq('platform', platform)
          .eq('channel', channel)
          .eq('is_active', true)
          .order('version_code', ascending: false)
          .limit(1)
          .maybeSingle();

      if (row == null) {
        return const AppReleaseLookup(reachedServer: true);
      }
      final release = AppRelease.fromJson(row);
      if (release.versionCode <= currentVersionCode) {
        return const AppReleaseLookup(reachedServer: true);
      }
      if (!release.downloadUrl.hasScheme) {
        return const AppReleaseLookup(reachedServer: true);
      }
      return AppReleaseLookup(reachedServer: true, release: release);
    } on Object {
      return const AppReleaseLookup(reachedServer: false);
    }
  }
}
