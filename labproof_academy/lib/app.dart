import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'core/constants/app_language.dart';
import 'core/constants/app_colors.dart';
import 'core/services/app_preferences_service.dart';
import 'core/services/app_update_service.dart';
import 'core/services/auth_service.dart';
import 'core/theme/app_theme.dart';
import 'data/models/academy_models.dart';
import 'modules/admin/admin_shell.dart';
import 'modules/auth/auth_screen.dart';
import 'modules/student/student_shell.dart';

class LabProofAcademyApp extends StatefulWidget {
  const LabProofAcademyApp({super.key});

  @override
  State<LabProofAcademyApp> createState() => _LabProofAcademyAppState();
}

class _LabProofAcademyAppState extends State<LabProofAcademyApp> {
  static const _studentOnlyApp = bool.fromEnvironment(
    'LABPROOF_STUDENT_APP_ONLY',
  );
  static const _defaultEntryRole = String.fromEnvironment(
    'LABPROOF_DEFAULT_ENTRY_ROLE',
    defaultValue: 'student',
  );
  static final _uriBase = Uri.base;
  static final _previewUpdateOnWeb =
      _uriBase.queryParameters['previewUpdate'] == '1';
  static const _currentVersionCode = int.fromEnvironment(
    'APP_VERSION_CODE',
    defaultValue: 1,
  );
  static const _releaseChannel = String.fromEnvironment(
    'APP_RELEASE_CHANNEL',
    defaultValue: 'student',
  );
  static const _updateService = AppUpdateService();

  bool _showSplash = true;
  bool _checkingSession = true;
  bool _updateCheckStarted = false;
  bool _updateDialogShown = false;
  int _updateRetryCount = 0;
  Timer? _updateRetryTimer;
  UserRole? _role;
  ThemeMode _themeMode = ThemeMode.light;
  AppLanguage _studentLanguage = AppLanguage.uzLatin;
  final _navigatorKey = GlobalKey<NavigatorState>();

  UserRole get _entryRole {
    if (_studentOnlyApp) return UserRole.student;

    final uri = Uri.base;
    final isAdminEntry =
        _defaultEntryRole == 'admin' ||
        uri.queryParameters['admin'] == '1' ||
        uri.pathSegments.contains('admin');
    return isAdminEntry ? UserRole.admin : UserRole.student;
  }

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await Future.wait([
      Future<void>.delayed(const Duration(seconds: 5)),
      _restorePreferences(),
      _restoreSession(),
    ]);
    if (mounted) {
      setState(() {
        _showSplash = false;
        _checkingSession = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_checkForUpdate());
      });
    }
  }

  Future<void> _restoreSession() async {
    final currentUser = AuthService.currentUser;
    if (currentUser != null) {
      _role = _studentOnlyApp
          ? UserRole.student
          : _roleFromName(await AuthService.currentRoleName());
    }
  }

  Future<void> _restorePreferences() async {
    _studentLanguage = await AppPreferencesService.loadStudentLanguage();
  }

  @override
  void dispose() {
    _updateRetryTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'LabProof Academy',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _themeMode,
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 420),
        child: _buildHome(),
      ),
    );
  }

  void _scheduleUpdateCheck() {
    if (_showSplash ||
        _checkingSession ||
        _updateCheckStarted ||
        _updateDialogShown) {
      return;
    }

    _updateCheckStarted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_checkForUpdate());
    });
  }

  Widget _buildHome() {
    if (_showSplash || _checkingSession) {
      return const SplashScreen(key: ValueKey('splash'));
    }

    if (_role == null) {
      _scheduleUpdateCheck();
      return AuthScreen(
        key: const ValueKey('auth'),
        entryRole: _entryRole,
        language: _studentLanguage,
        onLanguageChanged: _setStudentLanguage,
        onSignedIn: (_) => _handleSignedIn(),
      );
    }

    if (_role == UserRole.admin && !_studentOnlyApp) {
      return AdminShell(
        key: const ValueKey('admin'),
        themeMode: _themeMode,
        onThemeChanged: (mode) => setState(() => _themeMode = mode),
        onSignOut: _signOut,
        onOpenStudent: () => setState(() => _role = UserRole.student),
      );
    }

    _scheduleUpdateCheck();
    return StudentShell(
      key: const ValueKey('student'),
      themeMode: _themeMode,
      language: _studentLanguage,
      onLanguageChanged: _setStudentLanguage,
      onThemeChanged: (mode) => setState(() => _themeMode = mode),
      onCheckForUpdate: _checkForUpdateManually,
      onSignOut: _signOut,
    );
  }

  Future<void> _signOut() async {
    await AuthService.signOut();
    if (mounted) {
      setState(() => _role = null);
    }
  }

  Future<void> _handleSignedIn() async {
    final role = _studentOnlyApp
        ? UserRole.student
        : _roleFromName(await AuthService.currentRoleName());
    if (mounted) {
      setState(() => _role = role);
    }
  }

  void _setStudentLanguage(AppLanguage language) {
    if (_studentLanguage == language) return;
    setState(() => _studentLanguage = language);
    unawaited(AppPreferencesService.saveStudentLanguage(language));
  }

  Future<bool> _checkForUpdate({bool allowRetry = true}) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      if (_previewUpdateOnWeb) {
        final dialogContext = _navigatorKey.currentContext;
        if (!mounted ||
            _updateDialogShown ||
            dialogContext == null ||
            !dialogContext.mounted) {
          _updateCheckStarted = false;
          return false;
        }

        _updateDialogShown = true;
        _updateRetryCount = 0;
        await _showUpdateDialog(
          dialogContext,
          AppRelease(
            versionName: '1.0.6',
            versionCode: 7,
            downloadUrl: Uri.parse(
              '${_uriBase.origin}/downloads/labproof-academy-student.apk',
            ),
            isRequired: true,
            releaseNotes:
                'Bu local preview. Telefonda shunga o‘xshash yangilanish oynasi chiqadi.',
          ),
        );
        return true;
      }
      return false;
    }

    final lookup = await _updateService.findAvailableUpdate(
      currentVersionCode: _currentVersionCode,
      channel: _releaseChannel,
    );
    final release = lookup.release;
    final dialogContext = _navigatorKey.currentContext;

    if (!mounted || _updateDialogShown) {
      return false;
    }

    if (release == null) {
      _updateCheckStarted = false;
      if (allowRetry && !lookup.reachedServer && _updateRetryCount < 3) {
        _updateRetryCount += 1;
        _updateRetryTimer?.cancel();
        _updateRetryTimer = Timer(Duration(seconds: _updateRetryCount + 1), () {
          if (mounted) {
            _scheduleUpdateCheck();
          }
        });
      } else {
        _updateRetryCount = 0;
      }
      return false;
    }

    if (dialogContext == null || !dialogContext.mounted) {
      _updateCheckStarted = false;
      return false;
    }

    _updateRetryCount = 0;
    _updateDialogShown = true;
    await _showUpdateDialog(dialogContext, release);
    return true;
  }

  Future<bool> _checkForUpdateManually() async {
    _updateDialogShown = false;
    _updateCheckStarted = true;
    return _checkForUpdate(allowRetry: false);
  }

  Future<void> _showUpdateDialog(
    BuildContext dialogContext,
    AppRelease release,
  ) {
    return showDialog<void>(
      context: dialogContext,
      barrierDismissible: !release.isRequired,
      builder: (context) => AlertDialog(
        icon: const Icon(
          Icons.system_update_alt_rounded,
          color: AppColors.primaryBlue,
        ),
        title: const Text('Yangi versiya mavjud'),
        content: Text(
          [
            'LabProof Academy ${release.versionName} tayyor.',
            if ((release.releaseNotes ?? '').trim().isNotEmpty)
              release.releaseNotes!.trim(),
            'Yangilash uchun APK yuklab olinadi.',
          ].join('\n\n'),
        ),
        actions: [
          if (!release.isRequired)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Keyinroq'),
            ),
          FilledButton.icon(
            onPressed: () async {
              await launchUrl(
                release.downloadUrl,
                mode: LaunchMode.externalApplication,
              );
            },
            icon: const Icon(Icons.download_rounded),
            label: const Text('Yangilash'),
          ),
        ],
      ),
    );
  }

  UserRole _roleFromName(String roleName) {
    return roleName == 'admin' || roleName == 'teacher'
        ? UserRole.admin
        : UserRole.student;
  }
}
