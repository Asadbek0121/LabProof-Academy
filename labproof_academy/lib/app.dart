import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'core/constants/app_language.dart';
import 'core/constants/app_colors.dart';
import 'core/services/app_preferences_service.dart';
import 'core/services/app_update_installer_service.dart';
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
  static const _updateInstaller = AppUpdateInstallerService();

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

  Future<AppUpdateCheckResult> _checkForUpdate({bool allowRetry = true}) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      if (_previewUpdateOnWeb) {
        final dialogContext = _navigatorKey.currentContext;
        if (!mounted ||
            _updateDialogShown ||
            dialogContext == null ||
            !dialogContext.mounted) {
          _updateCheckStarted = false;
          return AppUpdateCheckResult.skipped;
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
        return AppUpdateCheckResult.available;
      }
      return AppUpdateCheckResult.skipped;
    }

    final installedVersionCode =
        await _updateInstaller.installedVersionCode() ?? _currentVersionCode;
    final lookup = await _updateService.findAvailableUpdate(
      currentVersionCode: installedVersionCode,
      channel: _releaseChannel,
    );
    final release = lookup.release;
    final dialogContext = _navigatorKey.currentContext;

    if (!mounted || _updateDialogShown) {
      return AppUpdateCheckResult.available;
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
      return lookup.reachedServer
          ? AppUpdateCheckResult.unavailable
          : AppUpdateCheckResult.serverUnavailable;
    }

    if (dialogContext == null || !dialogContext.mounted) {
      _updateCheckStarted = false;
      return AppUpdateCheckResult.skipped;
    }

    _updateRetryCount = 0;
    _updateDialogShown = true;
    await _showUpdateDialog(dialogContext, release);
    return AppUpdateCheckResult.available;
  }

  Future<AppUpdateCheckResult> _checkForUpdateManually() async {
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
      builder: (context) {
        var installing = false;
        var progress = 0.0;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            icon: const Icon(
              Icons.system_update_alt_rounded,
              color: AppColors.primaryBlue,
            ),
            title: const Text('Yangi versiya mavjud'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  [
                    'LabProof Academy ${release.versionName} tayyor.',
                    if ((release.releaseNotes ?? '').trim().isNotEmpty)
                      release.releaseNotes!.trim(),
                    'APK ilova ichida yuklanadi va o‘rnatish oynasi ochiladi.',
                  ].join('\n\n'),
                ),
                if (installing) ...[
                  const SizedBox(height: 18),
                  LinearProgressIndicator(value: progress),
                  const SizedBox(height: 8),
                  Text(
                    progress >= 1
                        ? 'O‘rnatish oynasi ochilmoqda...'
                        : 'Yuklanmoqda ${(progress * 100).round()}%',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ],
            ),
            actions: [
              if (!release.isRequired)
                TextButton(
                  onPressed: installing
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text('Keyinroq'),
                ),
              FilledButton.icon(
                onPressed: installing
                    ? null
                    : () async {
                        setDialogState(() {
                          installing = true;
                          progress = 0;
                        });
                        try {
                          await _updateInstaller.downloadAndInstall(
                            release,
                            onProgress: (value) {
                              if (!context.mounted) return;
                              setDialogState(() => progress = value);
                            },
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'APK yuklandi. Android o‘rnatish oynasida “O‘rnatish” tugmasini bosing.',
                                ),
                              ),
                            );
                          }
                          if (context.mounted && !release.isRequired) {
                            Navigator.of(context).pop();
                          }
                        } on Object catch (error) {
                          if (!context.mounted) return;
                          setDialogState(() => installing = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                error.toString().replaceFirst(
                                  'Exception: ',
                                  '',
                                ),
                              ),
                            ),
                          );
                        }
                      },
                icon: const Icon(Icons.download_rounded),
                label: const Text('Ilova ichida yangilash'),
              ),
            ],
          ),
        );
      },
    );
  }

  UserRole _roleFromName(String roleName) {
    return roleName == 'admin' || roleName == 'teacher'
        ? UserRole.admin
        : UserRole.student;
  }
}
