import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../../core/constants/app_language.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../data/models/academy_models.dart';
import '../../data/repositories/supabase_academy_repository.dart';
import 'pdf_embed_stub.dart' if (dart.library.html) 'pdf_embed_web.dart';
import 'student_web_bridge_stub.dart'
    if (dart.library.html) 'student_web_bridge_web.dart';
import 'twitter_community.dart';

enum _StudentTab { home, modules, progress, community, profile }

enum _ModuleFilter { all, open, locked, completed }

enum _LearningStage {
  moduleList,
  moduleDetail,
  topicIntro,
  pdfLesson,
  videoLesson,
  topicQuiz,
  quizResult,
  finalIntro,
  finalExam,
  finalResult,
  premiumPaywall,
}

class StudentShell extends StatefulWidget {
  const StudentShell({
    super.key,
    required this.themeMode,
    required this.language,
    required this.onLanguageChanged,
    required this.onThemeChanged,
    required this.onCheckForUpdate,
    required this.onSignOut,
  });

  final ThemeMode themeMode;
  final AppLanguage language;
  final ValueChanged<AppLanguage> onLanguageChanged;
  final ValueChanged<ThemeMode> onThemeChanged;
  final Future<bool> Function() onCheckForUpdate;
  final VoidCallback onSignOut;

  @override
  State<StudentShell> createState() => _StudentShellState();
}

class _StudentShellState extends State<StudentShell> {
  static const _repository = SupabaseAcademyRepository();
  static const _securityPinKey = 'student_security_pin';
  static const _appVersionName = String.fromEnvironment(
    'APP_VERSION_NAME',
    defaultValue: '1.2.0',
  );

  _StudentTab _tab = _StudentTab.home;
  int _prevTabIndex = 0;
  _LearningStage _stage = _LearningStage.moduleList;
  StudentDashboardData? _data;
  AcademyModule? _selectedModule;
  TopicLesson? _selectedTopic;
  int _quizQuestionIndex = 0;
  int _selectedOption = 0;
  int _topicScore = 0;
  Map<int, int> _topicAnswers = {};
  int _finalQuestionIndex = 0;
  int _finalSelectedOption = 0;
  int _finalScore = 0;
  bool _finalPassed = false;
  Map<int, int> _finalAnswers = {};
  _ModuleFilter _moduleFilter = _ModuleFilter.all;
  bool _notificationsEnabled = true;
  List<StudentNotification> _notifications = const [];
  Timer? _notificationPoller;
  bool _loading = true;
  bool _checkingSecurity = true;
  bool _lockedByPin = false;
  String _savedSecurityPin = '';
  String? _loadError;

  @override
  void initState() {
    super.initState();
    registerOpenSupportSheet(() {
      unawaited(_openAdminSupportSheet());
    });
    unawaited(_loadSecurityLock());
    _loadDashboard();
    _notificationPoller = Timer.periodic(
      const Duration(seconds: 45),
      (_) => _refreshNotifications(silent: true),
    );
  }

  Future<void> _loadSecurityLock() async {
    final prefs = await SharedPreferences.getInstance();
    final pin = prefs.getString(_securityPinKey) ?? '';
    if (!mounted) return;
    setState(() {
      _savedSecurityPin = pin;
      _lockedByPin = pin.isNotEmpty;
      _checkingSecurity = false;
    });
  }

  void _unlockWithPin(String pin) {
    if (pin == _savedSecurityPin) {
      setState(() => _lockedByPin = false);
      return;
    }
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(
        content: Text('PIN noto‘g‘ri kiritildi.'),
        backgroundColor: AppColors.errorRed,
      ),
    );
  }

  @override
  void dispose() {
    _notificationPoller?.cancel();
    super.dispose();
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
      final data = await _repository.loadStudentDashboard();
      final notificationsEnabled = await _repository
          .loadNotificationsEnabled()
          .catchError((_) => true);
      final notifications = notificationsEnabled
          ? await _repository.loadNotifications().catchError(
              (_) => const <StudentNotification>[],
            )
          : const <StudentNotification>[];
      if (!mounted) return;
      setState(() {
        _data = data;
        _selectedModule = data.continueModule;
        _selectedTopic = _firstOpenTopic(_selectedModule);
        _notificationsEnabled = notificationsEnabled;
        _notifications = notifications;
        _loading = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _data = null;
        _selectedModule = null;
        _selectedTopic = null;
        _notificationsEnabled = false;
        _notifications = const [];
        _loadError = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _refreshNotifications({bool silent = false}) async {
    if (!_notificationsEnabled) return;
    try {
      final notifications = await _repository.loadNotifications();
      if (!mounted) return;
      setState(() => _notifications = notifications);
    } on Object catch (error) {
      if (!silent) _showDataError(error);
    }
  }

  Future<void> _setNotificationsEnabled(bool value) async {
    final previousEnabled = _notificationsEnabled;
    final previousNotifications = _notifications;
    setState(() {
      _notificationsEnabled = value;
      if (!value) _notifications = const [];
    });

    try {
      await _repository.setNotificationsEnabled(value);
      if (value) {
        await _refreshNotifications(silent: true);
      }
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _notificationsEnabled = previousEnabled;
        _notifications = previousNotifications;
      });
      _showDataError(error);
    }
  }

  int get _unreadNotificationCount {
    if (!_notificationsEnabled) return 0;
    return _notifications.where((item) => !item.isRead).length;
  }

  Future<void> _markNotificationRead(String notificationId) async {
    final index = _notifications.indexWhere(
      (item) => item.id == notificationId,
    );
    if (index == -1 || _notifications[index].isRead) return;

    setState(() {
      _notifications = _notifications
          .map(
            (item) => item.id == notificationId
                ? StudentNotification(
                    id: item.id,
                    title: item.title,
                    body: item.body,
                    createdAt: item.createdAt,
                    isRead: true,
                    deepLink: item.deepLink,
                  )
                : item,
          )
          .toList();
    });

    try {
      await _repository.markNotificationRead(notificationId);
    } on Object catch (error) {
      _showDataError(error);
    }
  }

  Future<void> _markAllNotificationsRead() async {
    final unreadIds = _notifications
        .where((item) => !item.isRead)
        .map((item) => item.id)
        .toList();
    if (unreadIds.isEmpty) return;

    setState(() {
      _notifications = _notifications
          .map(
            (item) => StudentNotification(
              id: item.id,
              title: item.title,
              body: item.body,
              createdAt: item.createdAt,
              isRead: true,
              deepLink: item.deepLink,
            ),
          )
          .toList();
    });

    try {
      await _repository.markAllNotificationsRead(unreadIds);
    } on Object catch (error) {
      _showDataError(error);
    }
  }

  Future<void> _openNotifications() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _NotificationsSheet(
        language: widget.language,
        notificationsEnabled: _notificationsEnabled,
        notifications: _notifications,
        onMarkAllRead: _markAllNotificationsRead,
        onRead: _markNotificationRead,
      ),
    );
  }

  Future<void> _checkForUpdateManually() async {
    final found = await widget.onCheckForUpdate();
    if (!mounted || found) return;
    _showInfo('Yangi versiya topilmadi.');
  }

  Future<void> _openProfileEditor() async {
    if (_data == null) return;
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) =>
          _ProfileEditSheet(profile: _data!.profile, language: widget.language),
    );

    if (updated == true) {
      await _loadDashboard();
      if (mounted) {
        setState(() => _tab = _StudentTab.profile);
        _showInfo(studentText(widget.language, 'profile_updated'));
      }
    }
  }

  Future<void> _openAdminSupportSheet() async {
    final sent = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => _AdminSupportSheet(language: widget.language),
    );

    if (sent == true && mounted) {
      _showInfo(studentText(widget.language, 'message_sent'));
    }
  }

  TopicLesson? _firstOpenTopic(AcademyModule? module) {
    if (module == null || module.topics.isEmpty) return null;
    for (final topic in module.topics) {
      if (topic.status == TopicStatus.current) return topic;
    }
    for (final topic in module.topics) {
      if (topic.status != TopicStatus.locked) return topic;
    }
    return module.topics.first;
  }

  bool _topicHasVideoContent(TopicLesson topic) {
    return topic.videoUrl.trim().isNotEmpty || topic.videoMaterials.isNotEmpty;
  }

  void _openSelectedTopicLesson() {
    final topic = _selectedTopic;
    if (topic == null) return;

    setState(() {
      _stage = _topicHasVideoContent(topic)
          ? _LearningStage.videoLesson
          : _LearningStage.pdfLesson;
    });
  }

  void _openModulesTab({bool detail = false}) {
    setState(() {
      _prevTabIndex = _StudentTab.values.indexOf(_tab);
      _tab = _StudentTab.modules;
      if (_selectedModule == null && _data?.continueModule != null) {
        _selectedModule = _data!.continueModule;
        _selectedTopic = _firstOpenTopic(_selectedModule);
      }
      _stage = detail && _selectedModule != null
          ? _LearningStage.moduleDetail
          : _LearningStage.moduleList;
    });
  }

  void _openProgressTab() {
    setState(() {
      _prevTabIndex = _StudentTab.values.indexOf(_tab);
      _tab = _StudentTab.progress;
    });
  }

  void _openHomeTab() {
    setState(() {
      _prevTabIndex = _StudentTab.values.indexOf(_tab);
      _tab = _StudentTab.home;
      _stage = _LearningStage.moduleList;
    });
  }

  void _openQuickQuiz() {
    final module = _selectedModule ?? _data?.continueModule;
    final topic = _firstOpenTopic(module);
    if (module == null || topic == null) {
      _showInfo('Avval kurs va mavzu tanlang.');
      _openModulesTab();
      return;
    }

    setState(() {
      _prevTabIndex = _StudentTab.values.indexOf(_tab);
      _tab = _StudentTab.modules;
      _selectedModule = module;
      _selectedTopic = topic;
      _quizQuestionIndex = 0;
      _selectedOption = 0;
      _topicAnswers = {};
      _stage = topic.quizQuestions.isNotEmpty
          ? _LearningStage.topicQuiz
          : _LearningStage.pdfLesson;
    });

    if (topic.quizQuestions.isEmpty) {
      _showInfo('Bu mavzuda test hali yo‘q. Mavzu materiallari ochildi.');
    }
  }

  void _openBookmarks() {
    _openModulesTab();
    _showInfo(
      'Xatcho‘plar bo‘limi tayyorlanmoqda. Hozircha kurslar ro‘yxati ochildi.',
    );
  }

  void _openSelectedTopicQuiz() {
    final topic = _selectedTopic;
    if (topic == null || topic.quizQuestions.isEmpty) {
      _showInfo('Bu mavzu uchun test topilmadi.');
      return;
    }
    setState(() {
      _quizQuestionIndex = 0;
      _selectedOption = 0;
      _topicAnswers = {};
      _stage = _LearningStage.topicQuiz;
    });
  }

  List<QuizQuestion> _finalQuestionsForSelectedModule() {
    final module = _selectedModule;
    if (module == null) return const [];
    if (module.finalQuestions.isNotEmpty) return module.finalQuestions;
    for (final topic in module.topics) {
      if (topic.quizQuestions.isNotEmpty) return topic.quizQuestions;
    }
    return const [];
  }

  bool _allTopicsCompleted(AcademyModule module) {
    return module.topics.isNotEmpty &&
        module.topics.every((topic) => topic.status == TopicStatus.completed);
  }

  bool _canOpenFinalExamFromTopicResult() {
    final module = _selectedModule;
    final topic = _selectedTopic;
    if (module == null || topic == null || module.topics.isEmpty) return false;
    if (_topicScore < 70) return false;

    return module.topics.every(
      (item) => item.status == TopicStatus.completed || item.id == topic.id,
    );
  }

  Future<void> _completePdfLesson() async {
    final topic = _selectedTopic;
    if (topic == null) return;

    try {
      await _repository.markPdfCompleted(topic.id);
      if (mounted) {
        setState(() {
          if (topic.quizQuestions.isNotEmpty) {
            _quizQuestionIndex = 0;
            _selectedOption = 0;
            _topicAnswers = {};
            _stage = _LearningStage.topicQuiz;
          } else {
            _topicScore = 100;
            _stage = _LearningStage.quizResult;
          }
        });
      }
    } on Object catch (error) {
      _showDataError(error);
    }
  }

  Future<void> _completeVideoLesson() async {
    final topic = _selectedTopic;
    if (topic == null) return;

    try {
      await _repository.markVideoCompleted(topic.id);
      if (mounted) {
        setState(() {
          _stage = _LearningStage.pdfLesson;
        });
      }
    } on Object catch (error) {
      _showDataError(error);
    }
  }

  Future<void> _handleTopicQuizNext() async {
    final topic = _selectedTopic;
    if (topic == null || topic.quizQuestions.isEmpty) return;

    final answers = Map<int, int>.from(_topicAnswers)
      ..[_quizQuestionIndex] = _selectedOption;
    final isLastQuestion = _quizQuestionIndex >= topic.quizQuestions.length - 1;

    if (!isLastQuestion) {
      final nextIndex = _quizQuestionIndex + 1;
      setState(() {
        _topicAnswers = answers;
        _quizQuestionIndex = nextIndex;
        _selectedOption = answers[nextIndex] ?? 0;
      });
      return;
    }

    final score = _scoreQuiz(topic.quizQuestions, answers);
    try {
      await _repository.submitTopicQuiz(topicId: topic.id, score: score);
      if (mounted) {
        setState(() {
          _topicAnswers = answers;
          _topicScore = score;
          _quizQuestionIndex = 0;
          _selectedOption = 0;
          _stage = _LearningStage.quizResult;
        });
      }
    } on Object catch (error) {
      _showDataError(error);
    }
  }

  void _handleTopicQuizPrevious() {
    if (_quizQuestionIndex == 0) {
      setState(() => _stage = _LearningStage.pdfLesson);
      return;
    }

    final previousIndex = _quizQuestionIndex - 1;
    setState(() {
      _topicAnswers[_quizQuestionIndex] = _selectedOption;
      _quizQuestionIndex = previousIndex;
      _selectedOption = _topicAnswers[previousIndex] ?? 0;
    });
  }

  Future<void> _returnToModuleAfterQuiz() async {
    await _loadDashboard();
    if (mounted) {
      setState(() => _stage = _LearningStage.moduleDetail);
    }
  }

  void _startFinalExam() {
    setState(() {
      _finalQuestionIndex = 0;
      _finalSelectedOption = 0;
      _finalScore = 0;
      _finalPassed = false;
      _finalAnswers = {};
      _stage = _LearningStage.finalExam;
    });
  }

  Future<void> _handleFinalExamNext(List<QuizQuestion> questions) async {
    final module = _selectedModule;
    if (module == null || questions.isEmpty) return;

    final answers = Map<int, int>.from(_finalAnswers)
      ..[_finalQuestionIndex] = _finalSelectedOption;
    final isLastQuestion = _finalQuestionIndex >= questions.length - 1;

    if (!isLastQuestion) {
      final nextIndex = _finalQuestionIndex + 1;
      setState(() {
        _finalAnswers = answers;
        _finalQuestionIndex = nextIndex;
        _finalSelectedOption = answers[nextIndex] ?? 0;
      });
      return;
    }

    final score = _scoreQuiz(questions, answers);
    try {
      await _repository.submitFinalExam(moduleId: module.id, score: score);
      if (mounted) {
        setState(() {
          _finalAnswers = answers;
          _finalScore = score;
          _finalPassed = score >= 70;
          _stage = _LearningStage.finalResult;
        });
      }
    } on Object catch (error) {
      _showDataError(error);
    }
  }

  void _handleFinalExamPrevious() {
    if (_finalQuestionIndex == 0) {
      setState(() => _stage = _LearningStage.finalIntro);
      return;
    }

    final previousIndex = _finalQuestionIndex - 1;
    setState(() {
      _finalAnswers[_finalQuestionIndex] = _finalSelectedOption;
      _finalQuestionIndex = previousIndex;
      _finalSelectedOption = _finalAnswers[previousIndex] ?? 0;
    });
  }

  int _scoreQuiz(List<QuizQuestion> questions, Map<int, int> answers) {
    if (questions.isEmpty) return 0;
    var correct = 0;
    for (var index = 0; index < questions.length; index++) {
      if (answers[index] == questions[index].correctIndex) {
        correct++;
      }
    }
    return ((correct / questions.length) * 100).round();
  }

  void _showDataError(Object error) {
    if (!mounted) return;
    final message = error.toString().replaceFirst('Exception: ', '');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.errorRed),
    );
  }

  void _showInfo(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 760;
    final isDark = widget.themeMode == ThemeMode.dark;
    final baseTheme = Theme.of(context);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final mutedTextColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);
    final scaffoldBg = isDark
        ? const Color(0xFF030712)
        : const Color(0xFFF8F9FC);
    final surfaceColor = isDark ? const Color(0xFF0F172A) : Colors.white;
    final surfaceAltColor = isDark
        ? const Color(0xFF1E293B)
        : const Color(0xFFF1F5F9);
    final borderColor = isDark
        ? const Color(0xFF1F2937)
        : const Color(0xFFE2E8F0);

    final premiumText = baseTheme.textTheme
        .apply(bodyColor: textColor, displayColor: textColor)
        .copyWith(
          bodySmall: baseTheme.textTheme.bodySmall?.copyWith(
            color: mutedTextColor,
            height: 1.35,
          ),
          bodyMedium: baseTheme.textTheme.bodyMedium?.copyWith(
            color: mutedTextColor,
            height: 1.45,
          ),
          labelMedium: baseTheme.textTheme.labelMedium?.copyWith(
            color: mutedTextColor,
            fontWeight: FontWeight.w700,
          ),
          titleMedium: baseTheme.textTheme.titleMedium?.copyWith(
            color: textColor,
            fontWeight: FontWeight.w800,
          ),
          titleLarge: baseTheme.textTheme.titleLarge?.copyWith(
            color: textColor,
            fontWeight: FontWeight.w900,
          ),
          headlineSmall: baseTheme.textTheme.headlineSmall?.copyWith(
            color: textColor,
            fontWeight: FontWeight.w900,
            letterSpacing: -.2,
          ),
        );
    final premiumTheme = baseTheme.copyWith(
      brightness: isDark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: scaffoldBg,
      cardColor: surfaceColor,
      dividerColor: borderColor,
      iconTheme: IconThemeData(color: textColor),
      textTheme: premiumText,
      colorScheme: isDark
          ? const ColorScheme.dark(
              primary: AppColors.studentPrimary,
              secondary: AppColors.studentPink,
              surface: Color(0xFF0B1628),
              onSurface: Colors.white,
              error: AppColors.errorRed,
            )
          : const ColorScheme.light(
              primary: AppColors.studentPrimary,
              secondary: AppColors.studentPink,
              surface: Colors.white,
              onSurface: Color(0xFF0F172A),
              error: AppColors.errorRed,
            ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceAltColor,
        contentTextStyle: TextStyle(color: textColor),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      chipTheme: baseTheme.chipTheme.copyWith(
        backgroundColor: surfaceAltColor,
        selectedColor: AppColors.studentPrimary,
        disabledColor: surfaceColor,
        side: BorderSide(color: borderColor),
        labelStyle: TextStyle(
          color: mutedTextColor,
          fontWeight: FontWeight.w700,
        ),
        secondaryLabelStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
      inputDecorationTheme: baseTheme.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: surfaceAltColor.withValues(alpha: .72),
        hintStyle: TextStyle(color: mutedTextColor),
        labelStyle: TextStyle(color: mutedTextColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.studentPrimary),
        ),
      ),
    );

    final isDesktopProfile =
        _tab == _StudentTab.profile && MediaQuery.sizeOf(context).width > 900;
    final maxAppWidth = isDesktopProfile
        ? 1200.0
        : (isWide ? 470.0 : double.infinity);
    final isSecurityLocked = _checkingSecurity || _lockedByPin;

    return _StudentLanguageScope(
      language: widget.language,
      child: Theme(
        data: premiumTheme,
        child: Scaffold(
          backgroundColor: scaffoldBg,
          extendBody: true,
          body: _StudentAppBackground(
            isDark: isDark,
            child: SafeArea(
              bottom: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxAppWidth),
                  child: isSecurityLocked
                      ? _StudentPinLockScreen(
                          loading: _checkingSecurity,
                          onUnlock: _unlockWithPin,
                        )
                      : _data == null
                      ? _buildTabContent()
                      : _buildIndexedTabContent(_data!),
                ),
              ),
            ),
          ),
          bottomNavigationBar: isSecurityLocked
              ? null
              : Center(
                  heightFactor: 1,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxAppWidth),
                    child: _StudentBottomNav(
                      selectedIndex: _StudentTab.values.indexOf(_tab),
                      onTabChanged: (index) {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _prevTabIndex = _StudentTab.values.indexOf(_tab);
                          _tab = _StudentTab.values[index];
                          if (_tab == _StudentTab.modules) {
                            _stage = _LearningStage.moduleList;
                          }
                        });
                      },
                      isDark: widget.themeMode == ThemeMode.dark,
                      items: [
                        _NavItem(
                          icon: Icons.home_outlined,
                          activeIcon: Icons.home_rounded,
                          label: studentText(widget.language, 'home'),
                        ),
                        _NavItem(
                          icon: Icons.menu_book_outlined,
                          activeIcon: Icons.menu_book_rounded,
                          label: 'Kurslar',
                        ),
                        _NavItem(
                          icon: Icons.leaderboard_outlined,
                          activeIcon: Icons.leaderboard_rounded,
                          label: studentText(widget.language, 'progress'),
                        ),
                        _NavItem(
                          icon: Icons.forum_outlined,
                          activeIcon: Icons.forum_rounded,
                          label: 'Community',
                        ),
                        _NavItem(
                          icon: Icons.account_circle_outlined,
                          activeIcon: Icons.account_circle_rounded,
                          label: studentText(widget.language, 'profile'),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildIndexedTabContent(StudentDashboardData data) {
    final tabIndex = _StudentTab.values.indexOf(_tab);
    return IndexedStack(
      index: tabIndex,
      children: [
        // Home
        _StudentScrollScreen(
          child: _HomeDashboard(
            data: data,
            notificationCount: _unreadNotificationCount,
            onNotifications: _openNotifications,
            onContinue: () => _openModulesTab(detail: true),
            onCourses: () => _openModulesTab(),
            onProgress: _openProgressTab,
            onQuizzes: _openQuickQuiz,
            onBookmarks: _openBookmarks,
          ),
        ),
        // Modules
        _StudentScrollScreen(child: _buildLearningStage(data)),
        // Progress
        _StudentScrollScreen(
          child: _ProgressScreen(
            data: data,
            onRefresh: _loadDashboard,
            notificationCount: _unreadNotificationCount,
            onNotifications: _openNotifications,
          ),
        ),
        // Community
        _StudentScrollScreen(
          child: TwitterStyleCommunity(
            data: data,
            notificationCount: _unreadNotificationCount,
            onNotifications: _openNotifications,
          ),
        ),
        // Profile
        _StudentScrollScreen(
          child: _ProfileScreen(
            profile: data.profile,
            data: data,
            themeMode: widget.themeMode,
            language: widget.language,
            notificationsEnabled: _notificationsEnabled,
            onLanguageChanged: widget.onLanguageChanged,
            onThemeChanged: widget.onThemeChanged,
            onNotificationsChanged: (value) {
              unawaited(_setNotificationsEnabled(value));
            },
            onEditProfile: _openProfileEditor,
            onContactAdmin: _openAdminSupportSheet,
            onCheckForUpdate: _checkForUpdateManually,
            onSignOut: widget.onSignOut,
            appVersionName: _appVersionName,
            notificationCount: _unreadNotificationCount,
            onNotifications: _openNotifications,
          ),
        ),
      ],
    );
  }

  Widget _buildTabContent() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_loadError != null || _data == null) {
      return _StudentScrollScreen(
        child: _EmptyStateCard(
          icon: Icons.cloud_off_rounded,
          title: 'Ma’lumot yuklanmadi',
          message: _loadError ?? 'Supabase sessiya topilmadi.',
          actionLabel: 'Qayta urinish',
          onAction: _loadDashboard,
        ),
      );
    }

    final data = _data!;

    switch (_tab) {
      case _StudentTab.home:
        return _StudentScrollScreen(
          child: _HomeDashboard(
            data: data,
            notificationCount: _unreadNotificationCount,
            onNotifications: _openNotifications,
            onContinue: () => _openModulesTab(detail: true),
            onCourses: () => _openModulesTab(),
            onProgress: _openProgressTab,
            onQuizzes: _openQuickQuiz,
            onBookmarks: _openBookmarks,
          ),
        );
      case _StudentTab.modules:
        return _StudentScrollScreen(child: _buildLearningStage(data));
      case _StudentTab.community:
        return _StudentScrollScreen(
          child: TwitterStyleCommunity(
            data: data,
            notificationCount: _unreadNotificationCount,
            onNotifications: _openNotifications,
          ),
        );
      case _StudentTab.progress:
        return _StudentScrollScreen(
          child: _ProgressScreen(
            data: data,
            onRefresh: _loadDashboard,
            notificationCount: _unreadNotificationCount,
            onNotifications: _openNotifications,
          ),
        );
      case _StudentTab.profile:
        return _StudentScrollScreen(
          child: _ProfileScreen(
            profile: data.profile,
            data: data,
            themeMode: widget.themeMode,
            language: widget.language,
            notificationsEnabled: _notificationsEnabled,
            onLanguageChanged: widget.onLanguageChanged,
            onThemeChanged: widget.onThemeChanged,
            onNotificationsChanged: (value) {
              unawaited(_setNotificationsEnabled(value));
            },
            onEditProfile: _openProfileEditor,
            onContactAdmin: _openAdminSupportSheet,
            onCheckForUpdate: _checkForUpdateManually,
            onSignOut: widget.onSignOut,
            appVersionName: _appVersionName,
            notificationCount: _unreadNotificationCount,
            onNotifications: _openNotifications,
          ),
        );
    }
  }

  Widget _buildLearningStage(StudentDashboardData data) {
    switch (_stage) {
      case _LearningStage.moduleList:
        return _ModulesListScreen(
          modules: data.modules,
          filter: _moduleFilter,
          onRefresh: _loadDashboard,
          onFilterChanged: (filter) => setState(() => _moduleFilter = filter),
          onBackHome: _openHomeTab,
          onOpenModule: (module) {
            if (!module.isUnlocked) return;
            setState(() {
              _selectedModule = module;
              _selectedTopic = _firstOpenTopic(module);
              _stage = _LearningStage.moduleDetail;
            });
          },
        );
      case _LearningStage.moduleDetail:
        if (_selectedModule == null) {
          return _EmptyStateCard(
            icon: Icons.library_books_outlined,
            title: _t(context, 'module_not_found'),
            message: _t(context, 'no_modules_assigned'),
            actionLabel: _t(context, 'refresh'),
            onAction: _loadDashboard,
          );
        }
        return _ModuleDetailScreen(
          module: _selectedModule!,
          selectedTopic: _selectedTopic,
          canOpenFinalExam: _allTopicsCompleted(_selectedModule!),
          onBack: () => setState(() => _stage = _LearningStage.moduleList),
          onOpenTopic: (topic) {
            if (topic.requiresSubscription) {
              setState(() {
                _selectedTopic = topic;
                _stage = _LearningStage.premiumPaywall;
              });
              return;
            }
            if (topic.status == TopicStatus.locked) return;
            setState(() {
              _selectedTopic = topic;
              _stage = _LearningStage.topicIntro;
            });
          },
          onFinalExam: () => setState(() => _stage = _LearningStage.finalIntro),
        );
      case _LearningStage.topicIntro:
        if (_selectedModule == null || _selectedTopic == null) {
          return _EmptyStateCard(
            icon: Icons.topic_outlined,
            title: _t(context, 'topic_not_found'),
            message: _t(context, 'no_active_topic_in_module'),
            actionLabel: _t(context, 'back_to_module'),
            onAction: () =>
                setState(() => _stage = _LearningStage.moduleDetail),
          );
        }
        return _TopicIntroScreen(
          module: _selectedModule!,
          topic: _selectedTopic!,
          onBack: () => setState(() => _stage = _LearningStage.moduleDetail),
          onStart: _openSelectedTopicLesson,
        );
      case _LearningStage.pdfLesson:
        if (_selectedTopic == null) {
          return _EmptyStateCard(
            icon: Icons.topic_outlined,
            title: _t(context, 'topic_not_found'),
            message: _t(context, 'no_active_topic_in_module'),
            actionLabel: _t(context, 'back_to_module'),
            onAction: () =>
                setState(() => _stage = _LearningStage.moduleDetail),
          );
        }
        return _PdfLessonScreen(
          topic: _selectedTopic!,
          onBack: () => setState(
            () => _stage = _topicHasVideoContent(_selectedTopic!)
                ? _LearningStage.videoLesson
                : _LearningStage.topicIntro,
          ),
          onStartQuiz: _selectedTopic!.quizQuestions.isNotEmpty
              ? _openSelectedTopicQuiz
              : null,
          onComplete: _completePdfLesson,
        );
      case _LearningStage.videoLesson:
        if (_selectedTopic == null) {
          return _EmptyStateCard(
            icon: Icons.topic_outlined,
            title: _t(context, 'topic_not_found'),
            message: _t(context, 'no_active_topic_in_module'),
            actionLabel: _t(context, 'back_to_module'),
            onAction: () =>
                setState(() => _stage = _LearningStage.moduleDetail),
          );
        }
        return _VideoLessonScreen(
          topic: _selectedTopic!,
          onBack: () => setState(() => _stage = _LearningStage.topicIntro),
          onComplete: _completeVideoLesson,
        );
      case _LearningStage.topicQuiz:
        if (_selectedTopic == null || _selectedTopic!.quizQuestions.isEmpty) {
          return _EmptyStateCard(
            icon: Icons.quiz_outlined,
            title: _t(context, 'quiz_not_added'),
            message: _t(context, 'quiz_not_added_desc'),
            actionLabel: _t(context, 'back_to_topic'),
            onAction: () =>
                setState(() => _stage = _LearningStage.moduleDetail),
          );
        }
        return _TopicQuizScreen(
          topicTitle: _selectedTopic!.title,
          questions: _selectedTopic!.quizQuestions,
          questionIndex: _quizQuestionIndex,
          selectedOption: _selectedOption,
          onSelected: (index) => setState(() => _selectedOption = index),
          onNext: _handleTopicQuizNext,
          onPrevious: _handleTopicQuizPrevious,
          onBack: () => setState(() => _stage = _LearningStage.pdfLesson),
        );
      case _LearningStage.quizResult:
        if (_selectedTopic == null) {
          return _EmptyStateCard(
            icon: Icons.topic_outlined,
            title: _t(context, 'topic_not_found'),
            message: _t(context, 'no_active_topic_in_module'),
            actionLabel: _t(context, 'back_to_module'),
            onAction: () =>
                setState(() => _stage = _LearningStage.moduleDetail),
          );
        }
        return _QuizResultScreen(
          topic: _selectedTopic!,
          score: _topicScore,
          answers: _topicAnswers,
          canOpenFinalExam: _canOpenFinalExamFromTopicResult(),
          onContinue: _returnToModuleAfterQuiz,
          onFinalExam: () => setState(() => _stage = _LearningStage.finalIntro),
        );
      case _LearningStage.finalIntro:
        final moduleQuestions = _finalQuestionsForSelectedModule();
        return _FinalExamIntroScreen(
          module: _selectedModule,
          questionCount: moduleQuestions.length,
          onBack: () => setState(() => _stage = _LearningStage.moduleDetail),
          onStart: moduleQuestions.isEmpty ? null : _startFinalExam,
        );
      case _LearningStage.finalExam:
        final finalQuestions = _finalQuestionsForSelectedModule();
        if (finalQuestions.isEmpty) {
          return _EmptyStateCard(
            icon: Icons.emoji_events_outlined,
            title: _t(context, 'final_quiz_not_ready'),
            message: _t(context, 'final_quiz_not_ready_desc'),
            actionLabel: _t(context, 'back_to_module'),
            onAction: () =>
                setState(() => _stage = _LearningStage.moduleDetail),
          );
        }
        return _FinalExamScreen(
          questions: finalQuestions,
          questionIndex: _finalQuestionIndex,
          selectedOption: _finalSelectedOption,
          onSelected: (index) => setState(() => _finalSelectedOption = index),
          onNext: () => _handleFinalExamNext(finalQuestions),
          onPrevious: _handleFinalExamPrevious,
          onBack: () => setState(() => _stage = _LearningStage.finalIntro),
        );
      case _LearningStage.premiumPaywall:
        return _PremiumPaywallScreen(
          module: _selectedModule,
          topic: _selectedTopic,
          onBack: () => setState(() => _stage = _LearningStage.moduleDetail),
          onContactAdmin: _openAdminSupportSheet,
        );
      case _LearningStage.finalResult:
        return _FinalResultScreen(
          passed: _finalPassed,
          score: _finalScore,
          onBackToTopics: () async {
            await _loadDashboard();
            if (mounted) {
              setState(() => _stage = _LearningStage.moduleDetail);
            }
          },
          onRetake: () => setState(() {
            _finalQuestionIndex = 0;
            _finalSelectedOption = 0;
            _finalAnswers = {};
            _stage = _LearningStage.finalExam;
          }),
          onNextModule: () async {
            await _loadDashboard();
            if (mounted) {
              setState(() => _stage = _LearningStage.moduleList);
            }
          },
        );
    }
  }
}

class _StudentLanguageScope extends InheritedWidget {
  const _StudentLanguageScope({required this.language, required super.child});

  final AppLanguage language;

  static AppLanguage of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_StudentLanguageScope>()!
        .language;
  }

  @override
  bool updateShouldNotify(covariant _StudentLanguageScope oldWidget) {
    return oldWidget.language != language;
  }
}

String _t(BuildContext context, String key) {
  return studentText(_StudentLanguageScope.of(context), key);
}

class _StudentPinLockScreen extends StatefulWidget {
  const _StudentPinLockScreen({required this.loading, required this.onUnlock});

  final bool loading;
  final ValueChanged<String> onUnlock;

  @override
  State<_StudentPinLockScreen> createState() => _StudentPinLockScreenState();
}

class _StudentPinLockScreenState extends State<_StudentPinLockScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final pin = _controller.text.trim();
    if (pin.length != 4) return;
    widget.onUnlock(pin);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 360),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: AppColors.navy.withValues(alpha: .08),
                blurRadius: 24,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const IconBadge(
                icon: Icons.lock_rounded,
                color: AppColors.studentPrimary,
                size: 58,
              ),
              const SizedBox(height: 16),
              Text(
                'PIN kiriting',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              Text(
                'Ilovaga kirish uchun 4 xonali parolni yozing.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _controller,
                autofocus: true,
                obscureText: true,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
                onChanged: (value) {
                  if (value.length == 4) _submit();
                },
                onSubmitted: (_) => _submit(),
                decoration: const InputDecoration(
                  hintText: '••••',
                  prefixIcon: Icon(Icons.pin_rounded),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.lock_open_rounded),
                  label: const Text('Kirish'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudentAppBackground extends StatelessWidget {
  const _StudentAppBackground({required this.isDark, required this.child});

  final bool isDark;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [Color(0xFF030712), Color(0xFF04101F), Color(0xFF020713)]
              : const [Color(0xFFF8F9FC), Color(0xFFEEF2F6), Color(0xFFF8F9FC)],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _LabBackgroundPainter(isDark: isDark)),
          ),
          child,
        ],
      ),
    );
  }
}

class _LabBackgroundPainter extends CustomPainter {
  const _LabBackgroundPainter({required this.isDark});

  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final glowPaint = Paint()
      ..shader =
          RadialGradient(
            colors: [
              AppColors.studentPrimary.withValues(alpha: isDark ? .22 : .08),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(center: Offset(size.width * .86, 96), radius: 210),
          );
    canvas.drawCircle(Offset(size.width * .86, 96), 210, glowPaint);

    final blueGlow = Paint()
      ..shader =
          RadialGradient(
            colors: [
              AppColors.studentBlue.withValues(alpha: isDark ? .16 : .06),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * .12, size.height * .36),
              radius: 190,
            ),
          );
    canvas.drawCircle(
      Offset(size.width * .12, size.height * .36),
      190,
      blueGlow,
    );

    final moleculePaint = Paint()
      ..color = (isDark ? AppColors.studentBlue : const Color(0xFF6C4DFF))
          .withValues(alpha: isDark ? .18 : .06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final dotPaint = Paint()
      ..color = (isDark ? AppColors.studentPrimary : const Color(0xFF6C4DFF))
          .withValues(alpha: isDark ? .35 : .12);

    for (var i = 0; i < 7; i++) {
      final x = size.width * (.52 + i * .07);
      final y = 108 + math.sin(i * 1.7) * 32;
      final nextX = size.width * (.52 + (i + 1) * .07);
      final nextY = 108 + math.sin((i + 1) * 1.7) * 32;
      canvas.drawCircle(Offset(x, y), 3, dotPaint);
      if (i < 6) {
        canvas.drawLine(Offset(x, y), Offset(nextX, nextY), moleculePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _NavItem {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
  final IconData icon;
  final IconData activeIcon;
  final String label;
}

class _StudentBottomNav extends StatefulWidget {
  const _StudentBottomNav({
    required this.items,
    required this.selectedIndex,
    required this.onTabChanged,
    required this.isDark,
  });

  final List<_NavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onTabChanged;
  final bool isDark;

  @override
  State<_StudentBottomNav> createState() => _StudentBottomNavState();
}

class _StudentBottomNavState extends State<_StudentBottomNav> {
  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final navBg = isDark
        ? const Color(0xFF0F172A).withValues(alpha: 0.5)
        : Colors.white.withValues(alpha: 0.85);
    final borderCol = isDark
        ? Colors.white.withValues(alpha: 0.15)
        : const Color(0xFF6C4DFF).withValues(alpha: 0.12);
    final shadowCol = isDark
        ? Colors.black.withValues(alpha: 0.2)
        : const Color(0xFF6C4DFF).withValues(alpha: 0.05);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(36),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              height: 76,
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
              decoration: BoxDecoration(
                color: navBg,
                borderRadius: BorderRadius.circular(36),
                border: Border.all(color: borderCol),
                boxShadow: [
                  BoxShadow(
                    color: shadowCol,
                    blurRadius: 30,
                    offset: const Offset(0, 18),
                  ),
                  BoxShadow(
                    color: const Color(
                      0xFF6C4DFF,
                    ).withValues(alpha: isDark ? 0.15 : 0.05),
                    blurRadius: 28,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const inactiveWidth = 38.0;
                  final maxActiveWidth =
                      constraints.maxWidth -
                      inactiveWidth * (widget.items.length - 1);

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(widget.items.length, (index) {
                      final item = widget.items[index];
                      final isSelected = index == widget.selectedIndex;
                      final inactiveColor = isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B);
                      final activeColor = isDark
                          ? Colors.white
                          : const Color(0xFF6C4DFF);
                      final desiredActiveWidth = math.min(
                        126.0,
                        math.max(94.0, item.label.length * 6.4 + 46),
                      );
                      final activeWidth = math.min(
                        desiredActiveWidth,
                        math.max(82.0, maxActiveWidth),
                      );

                      return Semantics(
                        selected: isSelected,
                        button: true,
                        label: item.label,
                        child: GestureDetector(
                          onTap: () => widget.onTabChanged(index),
                          behavior: HitTestBehavior.opaque,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 240),
                            curve: Curves.easeOutCubic,
                            width: isSelected ? activeWidth : inactiveWidth,
                            height: 54,
                            padding: EdgeInsets.symmetric(
                              horizontal: isSelected ? 10 : 0,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AnimatedScale(
                                  scale: isSelected ? 1.12 : 1.0,
                                  duration: const Duration(milliseconds: 220),
                                  curve: Curves.easeOutBack,
                                  child: Icon(
                                    isSelected ? item.activeIcon : item.icon,
                                    color: isSelected
                                        ? activeColor
                                        : inactiveColor,
                                    size: isSelected ? 28 : 26,
                                  ),
                                ),
                                AnimatedSize(
                                  duration: const Duration(milliseconds: 220),
                                  curve: Curves.easeOutCubic,
                                  alignment: Alignment.centerLeft,
                                  child: isSelected
                                      ? Padding(
                                          padding: const EdgeInsets.only(
                                            left: 7,
                                          ),
                                          child: ConstrainedBox(
                                            constraints: BoxConstraints(
                                              maxWidth: math.max(
                                                30.0,
                                                activeWidth - 39,
                                              ),
                                            ),
                                            child: Text(
                                              item.label,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                height: 1,
                                                fontWeight: FontWeight.w900,
                                                color: activeColor,
                                              ),
                                            ),
                                          ),
                                        )
                                      : const SizedBox.shrink(),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.borderColor,
    this.onTap,
    this.gradient,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;
  final VoidCallback? onTap;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark
        ? const Color(0xFF0F172A).withValues(alpha: .35)
        : Colors.white.withValues(alpha: .75);
    final borderCol = isDark
        ? Colors.white.withValues(alpha: .15)
        : const Color(0xFFE2E8F0);
    final radius = BorderRadius.circular(24);

    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: Ink(
              padding: padding,
              decoration: BoxDecoration(
                color: gradient == null ? cardBg : null,
                gradient: gradient,
                borderRadius: radius,
                border: Border.all(color: borderColor ?? borderCol),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? .15 : .03),
                    blurRadius: 24,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _LabHeroArt extends StatelessWidget {
  const _LabHeroArt({this.size = 112});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _LabHeroPainter()),
    );
  }
}

class _LabHeroPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * .58, size.height * .52);
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.studentPrimary.withValues(alpha: .65),
          AppColors.studentBlue.withValues(alpha: .2),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: size.width * .6));
    canvas.drawCircle(center, size.width * .55, glow);

    final glass = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF43B6FF), Color(0xFF7C3AED)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    final stroke = Paint()
      ..color = Colors.white.withValues(alpha: .72)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final flask = Path()
      ..moveTo(size.width * .42, size.height * .14)
      ..lineTo(size.width * .58, size.height * .14)
      ..lineTo(size.width * .58, size.height * .45)
      ..lineTo(size.width * .78, size.height * .82)
      ..lineTo(size.width * .22, size.height * .82)
      ..lineTo(size.width * .42, size.height * .45)
      ..close();
    canvas.drawPath(flask, glass);
    canvas.drawPath(flask, stroke);

    final liquid = Paint()
      ..color = AppColors.studentPink.withValues(alpha: .88);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * .27,
          size.height * .62,
          size.width * .46,
          size.height * .16,
        ),
        const Radius.circular(14),
      ),
      liquid,
    );

    final scopePaint = Paint()
      ..color = Colors.white.withValues(alpha: .9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * .16, size.height * .86),
      Offset(size.width * .86, size.height * .86),
      scopePaint,
    );
    canvas.drawLine(
      Offset(size.width * .68, size.height * .28),
      Offset(size.width * .83, size.height * .18),
      scopePaint,
    );
    canvas.drawLine(
      Offset(size.width * .6, size.height * .42),
      Offset(size.width * .75, size.height * .32),
      scopePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            child: Text(
              actionLabel!,
              style: const TextStyle(color: AppColors.studentPink),
            ),
          ),
      ],
    );
  }
}

class _StudentScrollScreen extends StatelessWidget {
  const _StudentScrollScreen({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(12, 16, 12, 160.0 + bottomInset),
      child: child,
    );
  }
}

class _MobileHeader extends StatelessWidget {
  const _MobileHeader({
    required this.title,
    this.subtitle,
    this.onBack,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final compact = MediaQuery.sizeOf(context).width < 380;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (onBack != null) ...[
          IconButton(
            tooltip: 'Back',
            onPressed: onBack,
            icon: Icon(Icons.arrow_back_rounded, color: textColor),
            style: IconButton.styleFrom(
              backgroundColor: isDark
                  ? Colors.white.withValues(alpha: .06)
                  : Colors.black.withValues(alpha: .04),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textColor,
                  fontSize: compact ? 21 : 24,
                  fontWeight: FontWeight.bold,
                  height: 1.1,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: TextStyle(
                    color: subColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _HomeDashboard extends StatelessWidget {
  const _HomeDashboard({
    required this.data,
    required this.onContinue,
    required this.onCourses,
    required this.onProgress,
    required this.onQuizzes,
    required this.onBookmarks,
    required this.notificationCount,
    required this.onNotifications,
  });

  final StudentDashboardData data;
  final VoidCallback onContinue;
  final VoidCallback onCourses;
  final VoidCallback onProgress;
  final VoidCallback onQuizzes;
  final VoidCallback onBookmarks;
  final int notificationCount;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) {
    final overallPercent = (data.overallProgress * 100).round();
    final overallValue = data.overallProgress.clamp(0.0, 1.0).toDouble();
    final firstName = data.profile.firstName;
    final continueModule = data.continueModule;
    String t(String key) => studentText(_StudentLanguageScope.of(context), key);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final iconColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final headerButtonBg = isDark
        ? Colors.white.withValues(alpha: .08)
        : AppColors.studentPrimary.withValues(alpha: .10);

    Widget headerCircleButton({
      required String tooltip,
      required VoidCallback onPressed,
      required IconData icon,
      double iconSize = 28,
    }) {
      return Tooltip(
        message: tooltip,
        child: SizedBox.square(
          dimension: 56,
          child: Material(
            color: headerButtonBg,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onPressed,
              child: Icon(icon, color: iconColor, size: iconSize),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Badge.count(
              isLabelVisible: notificationCount > 0,
              count: notificationCount,
              child: headerCircleButton(
                tooltip: 'Bildirishnomalar',
                onPressed: onNotifications,
                icon: Icons.notifications_none_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${t('hello')}, $firstName! 👋',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      fontSize: 27,
                      color: textColor,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    t('welcome_to'),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isDark
                          ? Colors.white.withValues(alpha: .68)
                          : const Color(0xFF64748B),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        _GlassCard(
          padding: const EdgeInsets.all(18),
          gradient: isDark
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF17123F), Color(0xFF080A1E)],
                )
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFF8F7FF), Color(0xFFEDEBFF)],
                ),
          borderColor: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : const Color(0xFF6C4DFF).withValues(alpha: 0.14),
          child: Stack(
            children: [
              Positioned(
                right: -18,
                top: -24,
                child: Container(
                  width: 132,
                  height: 132,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF6C4DFF).withValues(alpha: .08),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF22C55E,
                            ).withValues(alpha: .12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            t('today_plan'),
                            style: const TextStyle(
                              color: Color(0xFF16A34A),
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          t('keep_learning_growing'),
                          style: TextStyle(
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF17133D),
                            fontSize: 20,
                            height: 1.14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          t('journey_starts'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isDark
                                ? Colors.white.withValues(alpha: .66)
                                : const Color(0xFF5B4BC4),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(
                                  value: overallValue,
                                  minHeight: 7,
                                  backgroundColor: isDark
                                      ? Colors.white.withValues(alpha: .1)
                                      : Colors.white.withValues(alpha: .9),
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                        Color(0xFF6C4DFF),
                                      ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '$overallPercent%',
                              style: TextStyle(
                                color: isDark
                                    ? Colors.white.withValues(alpha: .82)
                                    : const Color(0xFF4338CA),
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        ElevatedButton(
                          onPressed: onContinue,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6C4DFF),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(100),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                t('continue'),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.arrow_forward_rounded, size: 16),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 104,
                    height: 112,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: .06)
                          : Colors.white.withValues(alpha: .74),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: isDark ? .1 : .9),
                      ),
                    ),
                    child: Image.asset(
                      'assets/images/flask_3d.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 30),
        Text(
          t('quick_access'),
          style: TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _QuickAccessItem(
                icon: Icons.school_rounded,
                label: t('courses'),
                color: const Color(0xFF6C4DFF),
                onTap: onCourses,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _QuickAccessItem(
                icon: Icons.bar_chart_rounded,
                label: t('my_progress'),
                color: const Color(0xFF10B981),
                onTap: onProgress,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _QuickAccessItem(
                icon: Icons.help_outline_rounded,
                label: t('quizzes'),
                color: const Color(0xFF3B82F6),
                onTap: onQuizzes,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _QuickAccessItem(
                icon: Icons.bookmark_rounded,
                label: t('bookmarks'),
                color: const Color(0xFFF59E0B),
                onTap: onBookmarks,
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        // Continue Learning
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              t('continue_learning'),
              style: TextStyle(
                color: textColor,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            GestureDetector(
              onTap: onContinue,
              child: Text(
                t('see_all'),
                style: const TextStyle(
                  color: Color(0xFF6C4DFF),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _ContinueCardCompact(
          module: continueModule,
          onTap: onContinue,
          overallPercent: overallPercent,
        ),
        const SizedBox(height: 28),
        // Statistikangiz
        Text(
          t('your_statistics'),
          style: TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 16),
        _StatsGrid(data: data),
      ],
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.data});

  final StudentDashboardData data;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String t(String key) => studentText(_StudentLanguageScope.of(context), key);

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            context,
            icon: Icons.menu_book_rounded,
            value: '${data.modules.length}',
            label: t('stat_courses'),
            color: const Color(0xFF6C4DFF),
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            context,
            icon: Icons.workspace_premium_rounded,
            value: '${data.averageScore}%',
            label: t('stat_average'),
            color: const Color(0xFF10B981),
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            context,
            icon: Icons.whatshot_rounded,
            value: '7',
            label: t('stat_streak'),
            color: const Color(0xFFF59E0B),
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            context,
            icon: Icons.emoji_events_rounded,
            value: '${data.certificateCount}',
            label: t('stat_achievements'),
            color: const Color(0xFFFFB020),
            isDark: isDark,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      height: 105,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0F172A).withValues(alpha: .4)
            : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: .08)
              : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const Spacer(),
          Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 2,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark
                  ? Colors.white.withValues(alpha: .5)
                  : const Color(0xFF64748B),
              fontSize: 9,
              fontWeight: FontWeight.w600,
              height: 1.15,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAccessItem extends StatelessWidget {
  const _QuickAccessItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: SizedBox(
          width: double.infinity,
          height: 98,
          child: Column(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isDark ? .16 : .1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withValues(alpha: .16)),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: isDark ? .08 : .06),
                      blurRadius: 14,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(icon, color: color, size: 27),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 32,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isDark
                          ? Colors.white.withValues(alpha: .9)
                          : const Color(0xFF0F172A),
                      fontSize: 11,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContinueCardCompact extends StatelessWidget {
  const _ContinueCardCompact({
    required this.module,
    required this.onTap,
    required this.overallPercent,
  });

  final AcademyModule? module;
  final VoidCallback onTap;
  final int overallPercent;

  @override
  Widget build(BuildContext context) {
    final m = module;
    final title = m?.title ?? 'Kardiologiya asoslari';
    final percent = m != null ? (m.progress * 100).round() : overallPercent;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final category = (m?.category.trim().isNotEmpty ?? false)
        ? m!.category
        : 'Kardiologiya';

    final topicCount = m?.topics.length ?? 8;
    int totalMinutes = 0;
    if (m != null) {
      for (final t in m.topics) {
        totalMinutes += t.duration.inMinutes;
      }
    }
    if (totalMinutes == 0) totalMinutes = 165;
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    final durationStr = hours > 0 ? '${hours}so ${minutes}dk' : '${minutes}dk';

    return _GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          m?.coverUrl.trim().isNotEmpty == true
              ? _CourseCoverBox(
                  imageUrl: m!.coverUrl,
                  icon: Icons.biotech_rounded,
                  color: const Color(0xFF6C4DFF),
                  size: 82,
                  radius: 18,
                )
              : Container(
                  width: 82,
                  height: 82,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFF1F5F9),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: .08)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  padding: const EdgeInsets.all(5),
                  child: Image.asset(
                    'assets/images/heart_3d.png',
                    fit: BoxFit.contain,
                  ),
                ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6C4DFF).withValues(alpha: .1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          category,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF6C4DFF),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    height: 1.16,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: module?.progress ?? (overallPercent / 100),
                          minHeight: 6,
                          backgroundColor: isDark
                              ? Colors.white.withValues(alpha: .08)
                              : const Color(0xFFE2E8F0),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF6C4DFF),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$percent%',
                      style: TextStyle(
                        color: isDark
                            ? Colors.white.withValues(alpha: .7)
                            : const Color(0xFF475569),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      Icons.book_outlined,
                      size: 14,
                      color: isDark
                          ? Colors.white.withValues(alpha: .5)
                          : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$topicCount dars',
                      style: TextStyle(
                        color: isDark
                            ? Colors.white.withValues(alpha: .6)
                            : const Color(0xFF64748B),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.access_time_rounded,
                      size: 14,
                      color: isDark
                          ? Colors.white.withValues(alpha: .5)
                          : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      durationStr,
                      style: TextStyle(
                        color: isDark
                            ? Colors.white.withValues(alpha: .6)
                            : const Color(0xFF64748B),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFF6C4DFF), Color(0xFF8B5CF6)],
              ),
            ),
            child: const Icon(
              Icons.play_arrow_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseCoverBox extends StatelessWidget {
  const _CourseCoverBox({
    required this.imageUrl,
    required this.icon,
    required this.color,
    required this.size,
    required this.radius,
  });

  final String imageUrl;
  final IconData icon;
  final Color color;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final trimmedUrl = imageUrl.trim();
    final borderRadius = BorderRadius.circular(radius);
    final fallback = Container(
      color: color.withValues(alpha: 0.08),
      alignment: Alignment.center,
      child: Icon(icon, size: size * .42, color: color),
    );

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        border: Border.all(color: color.withValues(alpha: 0.18), width: 1),
      ),
      child: trimmedUrl.isEmpty
          ? fallback
          : Image.network(
              trimmedUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => fallback,
            ),
    );
  }
}

class _CompactCourseCard extends StatelessWidget {
  const _CompactCourseCard({required this.module, required this.onTap});

  final AcademyModule module;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final progress = module.progress.clamp(0.0, 1.0).toDouble();
    final percent = (progress * 100).round();
    final totalLessons = math.max(1, module.topics.length);
    final completedLessons = math.min(
      module.topics
          .where((topic) => topic.status == TopicStatus.completed)
          .length,
      totalLessons,
    );

    final Color accent;
    switch (module.category) {
      case 'Kardiologiya':
        accent = const Color(0xFFFF2D55);
        break;
      case 'Biokimyo':
        accent = const Color(0xFF00B894);
        break;
      case 'Gemotologiya':
        accent = const Color(0xFF8B5CF6);
        break;
      case 'Mikrobiologiya':
        accent = const Color(0xFF34C759);
        break;
      default:
        accent = const Color(0xFF6C4DFF);
    }

    final visualAsset = _moduleVisualAsset(module);
    final subtitle = module.category.trim().isNotEmpty
        ? module.category
        : 'Boshlang‘ich kurs';
    final statusLabel = module.isPassed
        ? 'Yakunlandi'
        : module.isUnlocked
        ? 'Davom etmoqda'
        : 'Yopiq';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      height: 112,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.16),
            blurRadius: 18,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: module.isUnlocked ? onTap : null,
            child: Stack(
              children: [
                Positioned.fill(
                  child: _ModuleCoverBackground(
                    imageUrl: module.coverUrl,
                    assetPath: visualAsset,
                    color: accent,
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Colors.black.withValues(alpha: .82),
                          Colors.black.withValues(alpha: .54),
                          Colors.black.withValues(alpha: .22),
                        ],
                      ),
                    ),
                  ),
                ),
                if (!module.isUnlocked)
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: .38),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 13, 14, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  module.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    height: 1.1,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: .84),
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!module.isUnlocked)
                            Icon(
                              Icons.lock_rounded,
                              color: Colors.white.withValues(alpha: .9),
                              size: 18,
                            ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        'Jami progress',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .86),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 4,
                                backgroundColor: Colors.white.withValues(
                                  alpha: .24,
                                ),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  accent,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '$percent%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            '$completedLessons / $totalLessons dars',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            statusLabel,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: .82),
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _moduleVisualAsset(AcademyModule module) {
  final source = '${module.category} ${module.title} ${module.description}'
      .toLowerCase();
  if (source.contains('kardio') || source.contains('yurak')) {
    return 'assets/images/heart_3d.png';
  }
  if (source.contains('bio') || source.contains('kimyo')) {
    return 'assets/images/flask_3d.png';
  }
  if (source.contains('gem') || source.contains('qon')) {
    return 'assets/images/onboarding_2.png';
  }
  return 'assets/images/onboarding_1.png';
}

class _ModuleCoverBackground extends StatelessWidget {
  const _ModuleCoverBackground({
    required this.imageUrl,
    required this.assetPath,
    required this.color,
  });

  final String imageUrl;
  final String assetPath;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final trimmedUrl = imageUrl.trim();

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: .95),
            const Color(0xFF111827),
            const Color(0xFF020617),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(.75, -.2),
                  radius: 1.12,
                  colors: [
                    Colors.white.withValues(alpha: .22),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: double.infinity,
            child: trimmedUrl.isEmpty
                ? _AssetCourseVisual(assetPath: assetPath)
                : Image.network(
                    trimmedUrl,
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    errorBuilder: (_, __, ___) =>
                        _AssetCourseVisual(assetPath: assetPath),
                  ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    const Color(0xFF020617).withValues(alpha: .64),
                    color.withValues(alpha: .14),
                    const Color(0xFF020617).withValues(alpha: .34),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(child: CustomPaint(painter: _LabTilePainter(color))),
        ],
      ),
    );
  }
}

class _AssetCourseVisual extends StatelessWidget {
  const _AssetCourseVisual({required this.assetPath});

  final String assetPath;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(left: 130),
        child: Image.asset(
          assetPath,
          fit: BoxFit.contain,
          alignment: Alignment.centerRight,
        ),
      ),
    );
  }
}

class _LabTilePainter extends CustomPainter {
  const _LabTilePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: .16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var i = 0; i < 4; i++) {
      final y = size.height * (.25 + i * .16);
      canvas.drawLine(Offset(0, y), Offset(size.width, y + 10), paint);
    }
    final dotPaint = Paint()..color = color.withValues(alpha: .72);
    canvas.drawCircle(Offset(size.width * .78, size.height * .22), 5, dotPaint);
    canvas.drawCircle(Offset(size.width * .2, size.height * .74), 4, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _LabTilePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

// Old _ContinueCard removed to match the new UI layout

class _PremiumStatCard extends StatelessWidget {
  const _PremiumStatCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: Theme.of(context).textTheme.bodySmall?.color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModulesListScreen extends StatefulWidget {
  const _ModulesListScreen({
    required this.modules,
    required this.filter,
    required this.onRefresh,
    required this.onFilterChanged,
    required this.onBackHome,
    required this.onOpenModule,
  });

  final List<AcademyModule> modules;
  final _ModuleFilter filter;
  final Future<void> Function() onRefresh;
  final ValueChanged<_ModuleFilter> onFilterChanged;
  final VoidCallback onBackHome;
  final ValueChanged<AcademyModule> onOpenModule;

  @override
  State<_ModulesListScreen> createState() => _ModulesListScreenState();
}

class _ModulesListScreenState extends State<_ModulesListScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final statusFiltered = widget.modules.where((module) {
      switch (widget.filter) {
        case _ModuleFilter.open:
          return module.isUnlocked && !module.isPassed;
        case _ModuleFilter.locked:
          return !module.isUnlocked;
        case _ModuleFilter.completed:
          return module.isPassed;
        case _ModuleFilter.all:
          return true;
      }
    }).toList();

    final filteredModules = statusFiltered.where((module) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return module.title.toLowerCase().contains(q) ||
          module.description.toLowerCase().contains(q) ||
          module.category.toLowerCase().contains(q);
    }).toList();

    const statusTabs = [
      (_ModuleFilter.all, 'Barchasi'),
      (_ModuleFilter.open, 'Davom etilmoqda'),
      (_ModuleFilter.completed, 'Yakunlangan'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Bosh sahifaga qaytish',
              onPressed: widget.onBackHome,
              icon: Icon(
                Icons.arrow_back_rounded,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              style: IconButton.styleFrom(
                backgroundColor: Colors.transparent,
                minimumSize: const Size(36, 36),
                padding: EdgeInsets.zero,
              ),
            ),
            const SizedBox(width: 2),
            Expanded(
              child: Text(
                'Kurslar',
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF3F6FB),
            borderRadius: BorderRadius.circular(10),
          ),
          child: TextField(
            controller: _searchController,
            onChanged: (val) {
              setState(() {
                _searchQuery = val;
              });
            },
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              fontSize: 15,
            ),
            decoration: InputDecoration(
              hintText: 'Kurs izlash',
              hintStyle: TextStyle(
                color: isDark
                    ? const Color(0xFF64748B)
                    : const Color(0xFF94A3B8),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: isDark
                    ? const Color(0xFF64748B)
                    : const Color(0xFF94A3B8),
                size: 19,
              ),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 38,
                minHeight: 38,
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(
                        Icons.clear_rounded,
                        color: isDark
                            ? Colors.white70
                            : const Color(0xFF64748B),
                      ),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: statusTabs.map((item) {
              final isSelected = widget.filter == item.$1;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => widget.onFilterChanged(item.$1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF6C4DFF)
                          : (isDark
                                ? const Color(0xFF0F172A)
                                : const Color(0xFFF5F7FC)),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF6C4DFF)
                            : (isDark
                                  ? const Color(0xFF1E293B)
                                  : const Color(0xFFE9EEF8)),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      item.$2,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : (isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF64748B)),
                        fontSize: 11,
                        fontWeight: isSelected
                            ? FontWeight.w900
                            : FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 14),
        if (widget.modules.isEmpty)
          _EmptyStateCard(
            icon: Icons.library_books_outlined,
            title: 'Modullar hali yo‘q',
            message:
                'Sizga hali o‘quv bloklari biriktirilmagan. Xabarlar markazini kuzating yoki sahifani yangilang.',
            actionLabel: 'Yangilash',
            onAction: () => unawaited(widget.onRefresh()),
          )
        else if (filteredModules.isEmpty)
          _EmptyStateCard(
            icon: Icons.filter_alt_off_rounded,
            title: 'Natijalar topilmadi',
            message: _searchQuery.isNotEmpty
                ? 'Qidiruv bo‘yicha hech qanday kurs yoki dars topilmadi. Boshqa kalit so‘z yozib ko‘ring.'
                : 'Ushbu ruknda hozircha hech qanday modul mavjud emas.',
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredModules.length,
            itemBuilder: (context, index) {
              final module = filteredModules[index];
              return _CompactCourseCard(
                module: module,
                onTap: () => widget.onOpenModule(module),
              );
            },
          ),
      ],
    );
  }
}

class _ModuleDetailScreen extends StatelessWidget {
  const _ModuleDetailScreen({
    required this.module,
    required this.selectedTopic,
    required this.canOpenFinalExam,
    required this.onBack,
    required this.onOpenTopic,
    required this.onFinalExam,
  });

  final AcademyModule module;
  final TopicLesson? selectedTopic;
  final bool canOpenFinalExam;
  final VoidCallback onBack;
  final ValueChanged<TopicLesson> onOpenTopic;
  final VoidCallback onFinalExam;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final percent = (module.progress * 100).round();

    // Determine category accent color
    final Color categoryColor;
    switch (module.category) {
      case 'Kardiologiya':
        categoryColor = const Color(0xFFFF2D55); // Crimson Red
        break;
      case 'Biokimyo':
        categoryColor = const Color(0xFFFF9500); // Orange
        break;
      case 'Gemotologiya':
        categoryColor = const Color(0xFFAF52DE); // Purple
        break;
      case 'Mikrobiologiya':
        categoryColor = const Color(0xFF34C759); // Green
        break;
      default:
        categoryColor = const Color(0xFF6C4DFF); // Labproof Purple
    }

    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final mutedTextColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);
    final visualAsset = _moduleVisualAsset(module);
    final description = module.description.isEmpty
        ? 'Ushbu modul orqali tegishli yo‘nalish bo‘yicha nazariy va amaliy ko‘nikmalarni o‘rganasiz.'
        : module.description;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: onBack,
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: textColor,
                size: 20,
              ),
              style: IconButton.styleFrom(
                backgroundColor: isDark
                    ? Colors.white.withValues(alpha: .06)
                    : Colors.black.withValues(alpha: .04),
                padding: const EdgeInsets.all(12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    module.category.toUpperCase(),
                    style: TextStyle(
                      color: categoryColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Modul ${module.order}',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        Container(
          height: 194,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: categoryColor.withValues(alpha: isDark ? .24 : .16),
                blurRadius: 24,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Stack(
              children: [
                Positioned.fill(
                  child: _ModuleCoverBackground(
                    imageUrl: module.coverUrl,
                    assetPath: visualAsset,
                    color: categoryColor,
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: .18),
                          Colors.black.withValues(alpha: .82),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 17, 18, 15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: .18),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: .2),
                              ),
                            ),
                            child: Text(
                              module.category.isEmpty
                                  ? 'BARCHASI'
                                  : module.category.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: .4,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: .18),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${module.topics.length} dars',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        module.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                          height: 1.12,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .82),
                          fontSize: 12,
                          height: 1.28,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 13),
                      Row(
                        children: [
                          Text(
                            'Tugallanish ko‘rsatkichi',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: .86),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '$percent%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: module.progress.clamp(0.0, 1.0).toDouble(),
                          minHeight: 6,
                          backgroundColor: Colors.white.withValues(alpha: .22),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            categoryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Modul mavzulari',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E293B)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${module.topics.length} dars',
                style: TextStyle(
                  color: mutedTextColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        if (module.topics.isEmpty)
          const _EmptyStateCard(
            icon: Icons.topic_outlined,
            title: 'Mavzular mavjud emas',
            message:
                'Bu modulda hozircha darslar mavjud emas. Tez orada qo\'shiladi.',
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: module.topics.length,
            itemBuilder: (context, index) {
              final topic = module.topics[index];
              return _TopicTile(
                topic: topic,
                index: index + 1,
                categoryColor: categoryColor,
                moduleCoverUrl: module.coverUrl,
                moduleVisualAsset: visualAsset,
                onTap: () => onOpenTopic(topic),
              );
            },
          ),

        const SizedBox(height: 24),
        // Final exam button if module is completed or near completion
        if (canOpenFinalExam) ...[
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: const Color(0xFF6C4DFF),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6C4DFF).withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: module.topics.isEmpty ? null : onFinalExam,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.emoji_events_rounded, color: Colors.white),
              label: Text(
                _t(context, 'final_exam'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ],
    );
  }
}

class _TopicTile extends StatelessWidget {
  const _TopicTile({
    required this.topic,
    required this.index,
    required this.categoryColor,
    required this.moduleCoverUrl,
    required this.moduleVisualAsset,
    required this.onTap,
  });

  final TopicLesson topic;
  final int index;
  final Color categoryColor;
  final String moduleCoverUrl;
  final String moduleVisualAsset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final locked = topic.status == TopicStatus.locked;
    final completed = topic.status == TopicStatus.completed;
    final Color accent = completed
        ? AppColors.successGreen
        : locked
        ? const Color(0xFF94A3B8)
        : categoryColor;
    final imageUrl = topic.coverUrl.trim().isNotEmpty
        ? topic.coverUrl
        : moduleCoverUrl;
    final statusIcon = completed
        ? Icons.check_rounded
        : locked
        ? Icons.lock_rounded
        : Icons.play_arrow_rounded;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        height: 126,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: locked ? .07 : .14),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: locked && !topic.requiresSubscription ? null : onTap,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: _ModuleCoverBackground(
                      imageUrl: imageUrl,
                      assetPath: moduleVisualAsset,
                      color: accent,
                    ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: locked
                            ? Colors.black.withValues(alpha: .58)
                            : Colors.black.withValues(alpha: .22),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Colors.black.withValues(alpha: .78),
                            Colors.black.withValues(alpha: .52),
                            Colors.black.withValues(alpha: .26),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: completed
                                ? AppColors.successGreen.withValues(alpha: .18)
                                : Colors.white.withValues(alpha: .16),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: completed
                                  ? AppColors.successGreen.withValues(
                                      alpha: .36,
                                    )
                                  : Colors.white.withValues(alpha: .2),
                            ),
                          ),
                          child: Icon(
                            statusIcon,
                            color: completed
                                ? AppColors.successGreen
                                : Colors.white.withValues(
                                    alpha: locked ? .58 : .95,
                                  ),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${index.toString().padLeft(2, '0')}  ${topic.title}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(
                                    alpha: locked ? .56 : 1,
                                  ),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  height: 1.16,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                topic.summary.isEmpty
                                    ? 'Mavzu bo‘yicha dars va amaliy topshiriqlar.'
                                    : topic.summary,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(
                                    alpha: locked ? .46 : .76,
                                  ),
                                  fontSize: 12,
                                  height: 1.25,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        if (completed)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.successGreen.withValues(
                                alpha: .16,
                              ),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: AppColors.successGreen.withValues(
                                  alpha: .22,
                                ),
                              ),
                            ),
                            child: Text(
                              '${(topic.quizScore * 100).round()}% test',
                              style: const TextStyle(
                                color: AppColors.successGreen,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          )
                        else if (!locked)
                          Icon(
                            Icons.play_circle_fill_rounded,
                            color: Colors.white.withValues(alpha: .9),
                            size: 26,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopicIntroScreen extends StatelessWidget {
  const _TopicIntroScreen({
    required this.module,
    required this.topic,
    required this.onBack,
    required this.onStart,
  });

  final AcademyModule module;
  final TopicLesson topic;
  final VoidCallback onBack;
  final VoidCallback onStart;

  int get _topicNumber {
    final index = module.topics.indexWhere((item) => item.id == topic.id);
    return index >= 0 ? index + 1 : math.max(1, module.order);
  }

  int get _lessonSectionCount {
    var count = 0;
    if (topic.hasVideoMaterial || topic.videoUrl.trim().isNotEmpty) count += 1;
    if (topic.hasReadingMaterial || topic.formula.trim().isNotEmpty) count += 1;
    if (topic.pdfUrl.trim().isNotEmpty) count += 1;
    if (topic.quizQuestions.isNotEmpty) count += 1;
    return math.max(1, count);
  }

  String get _durationLabel {
    if (topic.duration.inMinutes > 0) return '${topic.duration.inMinutes} min';
    if (topic.duration.inSeconds > 0) {
      final minutes = topic.duration.inSeconds / 60;
      return '${minutes.toStringAsFixed(1)} min';
    }
    return '12:45 min';
  }

  String get _levelLabel {
    final value = module.category.trim();
    if (value.isEmpty || value.toLowerCase() == 'barchasi') {
      return "Boshlang'ich";
    }
    return value;
  }

  List<String> get _learningOutcomes {
    final source = topic.summary.trim().isNotEmpty
        ? topic.summary.trim()
        : topic.formula.trim();
    final parts = source
        .split(RegExp(r'[\n\r•\-\.]+'))
        .map((part) => part.trim())
        .where((part) => part.length > 8)
        .take(3)
        .toList();
    if (parts.length >= 3) return parts;
    return [
      '${topic.title} tushunchasi',
      'Asosiy vazifalar',
      "Bo'limlar va ularning ishlari",
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final mutedTextColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);
    final cardBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final subtleBg = isDark ? const Color(0xFF111827) : const Color(0xFFF8FAFC);
    final borderCol = isDark
        ? const Color(0xFF1E293B)
        : const Color(0xFFE2E8F0);
    final imageUrl = topic.coverUrl.trim().isNotEmpty
        ? topic.coverUrl.trim()
        : module.coverUrl.trim();
    final visualAsset = _moduleVisualAsset(module);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _TopicIntroIconBubble(
              icon: Icons.arrow_back_rounded,
              color: textColor,
              background: subtleBg,
              onTap: onBack,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Mavzu',
                style: TextStyle(
                  color: textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: borderCol),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TopicHeroImage(
                imageUrl: imageUrl,
                topicNumber: _topicNumber,
                title: topic.title,
                subtitle: topic.summary.isEmpty
                    ? module.description
                    : topic.summary,
                assetPath: visualAsset,
              ),
              const SizedBox(height: 16),
              _TopicIntroStatRow(
                icon: Icons.schedule_rounded,
                label: 'Dars vaqti',
                value: _durationLabel,
                accent: const Color(0xFF6C4DFF),
              ),
              _TopicIntroStatRow(
                icon: Icons.signal_cellular_alt_rounded,
                label: 'Sath',
                value: _levelLabel,
                accent: const Color(0xFF64748B),
              ),
              _TopicIntroStatRow(
                icon: Icons.menu_book_rounded,
                label: 'Darslar soni',
                value: '$_lessonSectionCount ta',
                accent: const Color(0xFF7C3AED),
              ),
              _TopicIntroStatRow(
                icon: Icons.percent_rounded,
                label: "O'tish balli",
                value: '70%',
                accent: const Color(0xFF22C55E),
                isLast: true,
              ),
              const SizedBox(height: 18),
              Text(
                "Nimani o'rganasiz?",
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              ..._learningOutcomes.map(
                (outcome) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.successGreen,
                        size: 17,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          outcome,
                          style: TextStyle(
                            color: mutedTextColor,
                            fontSize: 12.5,
                            height: 1.35,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: onStart,
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: const Color(0xFF6C4DFF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Darsga kirish',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TopicIntroIconBubble extends StatelessWidget {
  const _TopicIntroIconBubble({
    required this.icon,
    required this.color,
    required this.background,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final Color background;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 46,
          height: 46,
          child: Icon(icon, color: color, size: 24),
        ),
      ),
    );
  }
}

class _TopicHeroImage extends StatelessWidget {
  const _TopicHeroImage({
    required this.imageUrl,
    required this.topicNumber,
    required this.title,
    required this.subtitle,
    required this.assetPath,
  });

  final String imageUrl;
  final int topicNumber;
  final String title;
  final String subtitle;
  final String assetPath;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: AspectRatio(
        aspectRatio: 1.52,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _ModuleCoverBackground(
              imageUrl: imageUrl,
              assetPath: assetPath,
              color: const Color(0xFF6C4DFF),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.black.withValues(alpha: 0.08),
                    Colors.black.withValues(alpha: 0.42),
                    Colors.black.withValues(alpha: 0.84),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C4DFF).withValues(alpha: .92),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: .22),
                      ),
                    ),
                    child: Text(
                      '1.$topicNumber MAVZU',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      height: 1.1,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (subtitle.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.86),
                        fontSize: 12,
                        height: 1.3,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopicIntroStatRow extends StatelessWidget {
  const _TopicIntroStatRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final mutedTextColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);
    final borderCol = isDark
        ? const Color(0xFF1E293B)
        : const Color(0xFFE2E8F0);

    return Container(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10, top: 2),
      margin: EdgeInsets.only(bottom: isLast ? 0 : 10),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: borderCol, width: 1)),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accent, size: 17),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: mutedTextColor,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: textColor,
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _PdfLessonScreen extends StatefulWidget {
  const _PdfLessonScreen({
    required this.topic,
    required this.onBack,
    required this.onComplete,
    this.onStartQuiz,
  });

  final TopicLesson topic;
  final VoidCallback onBack;
  final Future<void> Function() onComplete;
  final VoidCallback? onStartQuiz;

  @override
  State<_PdfLessonScreen> createState() => _PdfLessonScreenState();
}

class _PdfLessonScreenState extends State<_PdfLessonScreen> {
  bool _textLessonCompleted = false;

  @override
  void initState() {
    super.initState();
    _textLessonCompleted = false;
  }

  @override
  void didUpdateWidget(covariant _PdfLessonScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.topic.id != widget.topic.id) {
      _textLessonCompleted = false;
    }
  }

  void _openMaterialViewer(LessonMaterial material) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _LessonPdfViewerScreen(material: material),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topic = widget.topic;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final borderCol = isDark
        ? const Color(0xFF1E293B)
        : const Color(0xFFE2E8F0);
    final cardBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final mutedTextColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);
    final readingMaterials = topic.readingMaterials
        .where((material) => !material.isVideo)
        .toList();
    final textMaterials = readingMaterials
        .where((material) => !material.isPdf && material.body.trim().isNotEmpty)
        .toList();
    final additionalMaterials = <LessonMaterial>[];
    final hasTextLesson =
        topic.formula.trim().isNotEmpty || textMaterials.isNotEmpty;

    void addAdditionalMaterial(LessonMaterial material) {
      final key = '${material.title.trim()}|${material.url.trim()}';
      final exists = additionalMaterials.any(
        (item) => '${item.title.trim()}|${item.url.trim()}' == key,
      );
      if (!exists) additionalMaterials.add(material);
    }

    void showTestLauncherSheet() {
      if (topic.quizQuestions.isEmpty) return;
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) {
          final sheetDark = Theme.of(context).brightness == Brightness.dark;
          return DraggableScrollableSheet(
            initialChildSize: .74,
            minChildSize: .46,
            maxChildSize: .92,
            builder: (context, scrollController) => Container(
              decoration: BoxDecoration(
                color: sheetDark ? const Color(0xFF020617) : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: ListView(
                controller: scrollController,
                padding: EdgeInsets.fromLTRB(
                  18,
                  12,
                  18,
                  MediaQuery.viewPaddingOf(context).bottom + 18,
                ),
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: sheetDark
                            ? Colors.white.withValues(alpha: .18)
                            : const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                        iconSize: 24,
                        style: IconButton.styleFrom(
                          fixedSize: const Size.square(44),
                          padding: EdgeInsets.zero,
                          backgroundColor: sheetDark
                              ? Colors.white.withValues(alpha: .08)
                              : const Color(0xFFF1F5F9),
                          foregroundColor: sheetDark
                              ? Colors.white
                              : const Color(0xFF0F172A),
                          shape: const CircleBorder(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Test',
                          style: TextStyle(
                            color: sheetDark
                                ? Colors.white
                                : const Color(0xFF0F172A),
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _PostVideoQuizLauncher(
                    topic: topic,
                    ready: true,
                    onStart: () {
                      Navigator.pop(context);
                      unawaited(widget.onComplete());
                    },
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    if (topic.pdfUrl.trim().isNotEmpty) {
      addAdditionalMaterial(
        LessonMaterial(
          kind: 'pdf',
          title: topic.pdfTitle.trim().isEmpty ? 'Mavzu PDF' : topic.pdfTitle,
          url: topic.pdfUrl,
        ),
      );
    }
    for (final material in readingMaterials) {
      if (material.isPdf || material.url.trim().isNotEmpty) {
        addAdditionalMaterial(material);
      }
    }

    Widget section({
      required IconData icon,
      required String title,
      required Widget child,
      String? subtitle,
    }) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: borderCol, width: 1.3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? .18 : .03),
              blurRadius: 14,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.studentPrimary.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: AppColors.studentPrimary, size: 19),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (subtitle != null && subtitle.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: mutedTextColor,
                            fontSize: 13,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MobileHeader(
          title: topic.title,
          subtitle: 'Matnli dars, qo‘shimcha materiallar va test',
          onBack: widget.onBack,
        ),
        const SizedBox(height: 16),
        section(
          icon: Icons.menu_book_rounded,
          title: 'Matnli dars',
          subtitle: 'Mavzuning asosiy tushunchalari va izohlari.',
          child: !hasTextLesson
              ? Text(
                  'Bu mavzu uchun matnli dars hali biriktirilmagan.',
                  style: TextStyle(color: mutedTextColor),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (topic.formula.trim().isNotEmpty) ...[
                      _InlineTextBlock(
                        title: topic.pdfTitle.trim().isEmpty
                            ? topic.title
                            : topic.pdfTitle,
                        body: topic.formula,
                      ),
                      if (textMaterials.isNotEmpty) const SizedBox(height: 12),
                    ],
                    for (final material in textMaterials) ...[
                      _InlineTextBlock(
                        title: material.title,
                        body: material.body,
                      ),
                      const SizedBox(height: 12),
                    ],
                    _LessonStepCompleteButton(
                      completed: _textLessonCompleted,
                      onPressed: () {
                        setState(() {
                          _textLessonCompleted = true;
                        });
                        showTestLauncherSheet();
                      },
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 16),
        section(
          icon: Icons.collections_bookmark_rounded,
          title: 'Qo‘shimcha materiallar',
          subtitle: 'PDF va foydali manbalarni ilova ichida ko‘ring.',
          child: additionalMaterials.isEmpty
              ? Text(
                  'Qo‘shimcha materiallar hali biriktirilmagan.',
                  style: TextStyle(color: mutedTextColor),
                )
              : Column(
                  children: [
                    for (
                      var index = 0;
                      index < additionalMaterials.length;
                      index++
                    ) ...[
                      _SupplementalMaterialTile(
                        material: additionalMaterials[index],
                        index: index + 1,
                        onView: () =>
                            _openMaterialViewer(additionalMaterials[index]),
                      ),
                      if (index != additionalMaterials.length - 1)
                        const SizedBox(height: 10),
                    ],
                  ],
                ),
        ),
        const SizedBox(height: 24),
        if (topic.quizQuestions.isEmpty)
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => unawaited(widget.onComplete()),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.successGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.check_rounded),
              label: Text(
                _t(context, 'finish_reading'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        const SizedBox(height: 32),
      ],
    );
  }
}

class _SupplementalMaterialTile extends StatelessWidget {
  const _SupplementalMaterialTile({
    required this.material,
    required this.index,
    required this.onView,
  });

  final LessonMaterial material;
  final int index;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = material.title.trim().isEmpty
        ? 'Qo‘shimcha material $index'
        : material.title.trim();
    final typeLabel = _lessonMaterialTypeLabel(material);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.studentPrimary.withValues(alpha: .13),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.errorRed.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.picture_as_pdf_rounded,
              color: AppColors.errorRed,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  typeLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            onPressed: material.url.trim().isEmpty ? null : onView,
            icon: const Icon(Icons.visibility_rounded, size: 20),
            tooltip: 'Ilova ichida ko‘rish',
          ),
        ],
      ),
    );
  }
}

String _lessonMaterialTypeLabel(LessonMaterial material) {
  final url = material.url.toLowerCase();
  if (material.isPdf || url.contains('.pdf')) return 'PDF hujjat';
  if (url.contains('docs.google.com')) return 'Google hujjat';
  if (url.contains('drive.google.com')) return 'Google Drive fayl';
  if (material.isLink) return 'Tashqi manba';
  return 'Qo‘shimcha fayl';
}

class _LessonPdfViewerScreen extends StatefulWidget {
  const _LessonPdfViewerScreen({required this.material});

  final LessonMaterial material;

  @override
  State<_LessonPdfViewerScreen> createState() => _LessonPdfViewerScreenState();
}

class _LessonPdfViewerScreenState extends State<_LessonPdfViewerScreen> {
  final PdfViewerController _controller = PdfViewerController();
  int _page = 1;
  int _pageCount = 0;
  String _error = '';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rawUrl = widget.material.url.trim();
    final viewerUrl = _normalizeLessonFileUrl(rawUrl);

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF020617)
          : const Color(0xFFF4F7FB),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              child: Row(
                children: [
                  IconButton.filledTonal(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.material.title.trim().isEmpty
                          ? 'PDF Viewer'
                          : widget.material.title.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.studentPrimary.withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _pageCount == 0 ? 'PDF' : '$_page / $_pageCount',
                      style: const TextStyle(
                        color: AppColors.studentPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : Colors.white,
                      border: Border.all(
                        color: AppColors.studentPrimary.withValues(alpha: .12),
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: _error.isNotEmpty || viewerUrl.isEmpty
                        ? _PdfViewerError(
                            message: viewerUrl.isEmpty
                                ? 'Bu material uchun PDF manzil kiritilmagan.'
                                : _error,
                          )
                        : SfPdfViewer.network(
                            viewerUrl,
                            controller: _controller,
                            canShowScrollHead: true,
                            canShowScrollStatus: false,
                            onDocumentLoaded: (details) {
                              setState(() {
                                _page = 1;
                                _pageCount = details.document.pages.count;
                                _error = '';
                              });
                            },
                            onPageChanged: (details) {
                              setState(() => _page = details.newPageNumber);
                            },
                            onDocumentLoadFailed: (details) {
                              setState(() {
                                _error = details.description.trim().isEmpty
                                    ? 'PDF yuklanmadi. Fayl public bo‘lishi yoki PDF manzili to‘g‘ri berilishi kerak.'
                                    : details.description;
                              });
                            },
                          ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppColors.studentPrimary.withValues(alpha: .12),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _page > 1
                            ? () => _controller.previousPage()
                            : null,
                        icon: const Icon(Icons.chevron_left_rounded),
                        label: const Text('Oldingi'),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Text(
                        _pageCount == 0 ? '—' : '$_page / $_pageCount',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _pageCount > 0 && _page < _pageCount
                            ? () => _controller.nextPage()
                            : null,
                        icon: const Icon(Icons.chevron_right_rounded),
                        label: const Text('Keyingi'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PdfViewerError extends StatelessWidget {
  const _PdfViewerError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.errorRed.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(
                Icons.picture_as_pdf_rounded,
                color: AppColors.errorRed,
                size: 34,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineLessonMaterial extends StatefulWidget {
  const _InlineLessonMaterial({required this.material});

  final LessonMaterial material;

  @override
  State<_InlineLessonMaterial> createState() => _InlineLessonMaterialState();
}

class _InlineLessonMaterialState extends State<_InlineLessonMaterial> {
  Timer? _pdfLoadTimer;
  bool _pdfLoaded = false;
  bool _pdfFailed = false;
  String _pdfError = '';

  @override
  void initState() {
    super.initState();
    _schedulePdfFallback();
  }

  @override
  void didUpdateWidget(covariant _InlineLessonMaterial oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.material.url != widget.material.url ||
        oldWidget.material.kind != widget.material.kind) {
      _pdfLoaded = false;
      _pdfFailed = false;
      _pdfError = '';
      _schedulePdfFallback();
    }
  }

  @override
  void dispose() {
    _pdfLoadTimer?.cancel();
    super.dispose();
  }

  void _schedulePdfFallback() {
    _pdfLoadTimer?.cancel();
    if (canUseEmbeddedPdfViewer) return;
    final url = widget.material.url.trim();
    final isPdfUrl =
        widget.material.isPdf || url.toLowerCase().contains('.pdf');
    if (!isPdfUrl || url.isEmpty) return;
    _pdfLoadTimer = Timer(const Duration(seconds: 8), () {
      if (!mounted || _pdfLoaded) return;
      setState(() {
        _pdfFailed = true;
        _pdfError =
            'PDF preview yuklanmadi. Fayl ruxsatini yoki link formatini tekshiring.';
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final material = widget.material;
    final rawUrl = material.url.trim();
    final url = _normalizeLessonFileUrl(rawUrl);
    final embeddedPdfUrl = _embeddedLessonPdfUrl(rawUrl, url);
    final isPdfUrl = material.isPdf || url.toLowerCase().contains('.pdf');
    final hasBody = material.body.trim().isNotEmpty;
    final hasUrl = url.isNotEmpty;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.studentPrimary.withValues(alpha: .14),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(
                  isPdfUrl
                      ? Icons.picture_as_pdf_rounded
                      : Icons.article_rounded,
                  color: isPdfUrl
                      ? AppColors.errorRed
                      : AppColors.studentPrimary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    material.title,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ),
          if (hasBody)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: _ExpandableLessonBody(body: material.body),
            ),
          if (isPdfUrl && hasUrl)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      height: math.min(
                        520,
                        math.max(340, MediaQuery.sizeOf(context).height * .52),
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ColoredBox(
                            color: isDark
                                ? const Color(0xFF0F172A)
                                : const Color(0xFFF1F5F9),
                            child: canUseEmbeddedPdfViewer
                                ? buildEmbeddedPdfViewer(embeddedPdfUrl)
                                : SfPdfViewer.network(
                                    url,
                                    canShowScrollHead: false,
                                    canShowScrollStatus: false,
                                    onDocumentLoaded: (_) {
                                      _pdfLoadTimer?.cancel();
                                      if (!mounted) return;
                                      setState(() {
                                        _pdfLoaded = true;
                                        _pdfFailed = false;
                                        _pdfError = '';
                                      });
                                    },
                                    onDocumentLoadFailed: (details) {
                                      _pdfLoadTimer?.cancel();
                                      if (!mounted) return;
                                      setState(() {
                                        _pdfFailed = true;
                                        _pdfError =
                                            details.description.trim().isEmpty
                                            ? 'PDF preview yuklanmadi.'
                                            : details.description;
                                      });
                                    },
                                  ),
                          ),
                          if (!canUseEmbeddedPdfViewer && _pdfFailed)
                            _PdfPreviewFallback(message: _pdfError),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (material.isPdf && !hasUrl)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: _PdfPreviewFallback(
                message: 'Bu PDF uchun link kiritilmagan.',
              ),
            )
          else if (hasUrl && !isPdfUrl)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: SelectableText(
                url,
                style: const TextStyle(
                  color: AppColors.studentPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PdfPreviewFallback extends StatelessWidget {
  const _PdfPreviewFallback({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: (isDark ? Colors.black : Colors.white).withValues(alpha: .88),
        border: Border.all(
          color: AppColors.studentPrimary.withValues(alpha: .2),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: AppColors.errorRed.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.picture_as_pdf_rounded,
                color: AppColors.errorRed,
                size: 30,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.white70 : AppColors.studentInk,
                fontWeight: FontWeight.w800,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _normalizeLessonFileUrl(String rawUrl) {
  final value = rawUrl.trim();
  if (value.isEmpty) return value;
  final withScheme = value.startsWith('www.') ? 'https://$value' : value;
  final uri = Uri.tryParse(withScheme);
  if (uri == null || !uri.hasScheme) return value;

  final host = uri.host.toLowerCase();
  if (host.contains('drive.google.com')) {
    final segments = uri.pathSegments;
    final fileIndex = segments.indexOf('d');
    final fileId = fileIndex >= 0 && fileIndex + 1 < segments.length
        ? segments[fileIndex + 1]
        : uri.queryParameters['id'];
    if (fileId != null && fileId.trim().isNotEmpty) {
      return Uri.https('drive.google.com', '/uc', {
        'export': 'download',
        'id': fileId,
      }).toString();
    }
  }

  if (host.contains('dropbox.com')) {
    final params = Map<String, String>.from(uri.queryParameters);
    params.remove('dl');
    params['raw'] = '1';
    return uri.replace(queryParameters: params).toString();
  }

  if (host == 'github.com' && uri.pathSegments.length >= 5) {
    final segments = uri.pathSegments;
    final blobIndex = segments.indexOf('blob');
    if (blobIndex >= 0 && blobIndex + 1 < segments.length) {
      final owner = segments[0];
      final repo = segments[1];
      final branch = segments[blobIndex + 1];
      final path = segments.skip(blobIndex + 2).join('/');
      return Uri.https(
        'raw.githubusercontent.com',
        '/$owner/$repo/$branch/$path',
      ).toString();
    }
  }

  if (host.contains('docs.google.com')) {
    final segments = uri.pathSegments;
    final documentTypes = {'document', 'presentation', 'spreadsheets'};
    if (segments.length >= 3 &&
        documentTypes.contains(segments[0]) &&
        segments[1] == 'd') {
      if (segments[0] == 'presentation') {
        return Uri.https(
          'docs.google.com',
          '/presentation/d/${segments[2]}/export/pdf',
        ).toString();
      }
      return Uri.https(
        'docs.google.com',
        '/${segments[0]}/d/${segments[2]}/export',
        {'format': 'pdf'},
      ).toString();
    }
  }

  return withScheme;
}

String _embeddedLessonPdfUrl(String rawUrl, String normalizedUrl) {
  final source = rawUrl.trim().isEmpty ? normalizedUrl : rawUrl.trim();
  final withScheme = source.startsWith('www.') ? 'https://$source' : source;
  final uri = Uri.tryParse(withScheme);
  if (uri == null || !uri.hasScheme) return normalizedUrl;

  final host = uri.host.toLowerCase();
  if (host.contains('drive.google.com')) {
    final segments = uri.pathSegments;
    final fileIndex = segments.indexOf('d');
    final fileId = fileIndex >= 0 && fileIndex + 1 < segments.length
        ? segments[fileIndex + 1]
        : uri.queryParameters['id'];
    if (fileId != null && fileId.trim().isNotEmpty) {
      return Uri.https(
        'drive.google.com',
        '/file/d/$fileId/preview',
      ).toString();
    }
  }

  if (host.contains('docs.google.com')) {
    final segments = uri.pathSegments;
    final documentTypes = {'document', 'presentation', 'spreadsheets'};
    if (segments.length >= 3 &&
        documentTypes.contains(segments[0]) &&
        segments[1] == 'd') {
      return Uri.https(
        'docs.google.com',
        '/${segments[0]}/d/${segments[2]}/preview',
      ).toString();
    }
  }

  final normalizedUri = Uri.tryParse(normalizedUrl);
  final normalizedHost = normalizedUri?.host.toLowerCase() ?? '';
  final isLocalFile =
      normalizedHost == 'localhost' ||
      normalizedHost == '127.0.0.1' ||
      normalizedHost == '0.0.0.0' ||
      normalizedHost.endsWith('.local');

  if (isLocalFile || normalizedUri?.scheme == 'data') {
    return normalizedUrl;
  }

  return normalizedUrl;
}

class _InlineTextBlock extends StatelessWidget {
  const _InlineTextBlock({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.trim().isEmpty ? 'Dars matni' : title.toUpperCase(),
          style: TextStyle(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: .62),
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: .2,
          ),
        ),
        const SizedBox(height: 10),
        _ExpandableLessonBody(body: body),
      ],
    );
  }
}

String _lessonPlainPreview(String body) {
  final lines = body.split('\n');
  final buffer = StringBuffer();
  for (final rawLine in lines) {
    final line = rawLine.trim();
    if (line.isEmpty) continue;
    if (_RichLessonBody.markdownImagePattern.hasMatch(line)) continue;
    if (_looksLikeImageUrl(line)) continue;
    if (buffer.isNotEmpty) buffer.write(' ');
    buffer.write(line);
  }
  return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

bool _looksLikeImageUrl(String value) {
  final lower = value.toLowerCase().trim();
  return (lower.startsWith('http://') || lower.startsWith('https://')) &&
      (lower.contains('.png') ||
          lower.contains('.jpg') ||
          lower.contains('.jpeg') ||
          lower.contains('.webp') ||
          lower.contains('.gif'));
}

class _ExpandableLessonBody extends StatefulWidget {
  const _ExpandableLessonBody({required this.body});

  final String body;

  @override
  State<_ExpandableLessonBody> createState() => _ExpandableLessonBodyState();
}

class _ExpandableLessonBodyState extends State<_ExpandableLessonBody> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final preview = _lessonPlainPreview(widget.body);
    final bodyLines = widget.body.split('\n').where((line) {
      return line.trim().isNotEmpty;
    }).length;
    final canCollapse =
        preview.length > 190 ||
        bodyLines > 4 ||
        _RichLessonBody.markdownImagePattern.hasMatch(widget.body) ||
        widget.body.split('\n').any(_looksLikeImageUrl);

    final collapsedText = preview.isEmpty
        ? 'Matnli dars ma’lumoti biriktirilgan.'
        : preview;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: _expanded
              ? _RichLessonBody(
                  key: const ValueKey('expanded-lesson-body'),
                  body: widget.body,
                )
              : Text(
                  collapsedText,
                  key: const ValueKey('collapsed-lesson-body'),
                  maxLines: canCollapse ? 5 : null,
                  overflow: canCollapse ? TextOverflow.ellipsis : null,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.58,
                    color: isDark
                        ? Colors.white.withValues(alpha: .84)
                        : AppColors.studentInk.withValues(alpha: .84),
                  ),
                ),
        ),
        if (canCollapse) ...[
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: () => setState(() => _expanded = !_expanded),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.studentPrimary,
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 34),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            iconAlignment: IconAlignment.end,
            icon: Icon(
              _expanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
            ),
            label: Text(
              _expanded ? 'Yig‘ish' : 'To‘liq ko‘rish',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ],
    );
  }
}

class _LessonStepCompleteButton extends StatelessWidget {
  const _LessonStepCompleteButton({
    required this.completed,
    required this.onPressed,
  });

  final bool completed;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (completed) return const SizedBox.shrink();

    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.successGreen,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        icon: const Icon(Icons.check_rounded),
        label: const Text(
          'Matnli darsni tugatdim',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

class _RichLessonBody extends StatelessWidget {
  const _RichLessonBody({super.key, required this.body});

  final String body;

  static final RegExp markdownImagePattern = RegExp(
    r'^!\[([^\]]*)\]\(([^\)]+)\)$',
  );

  bool _isImageUrl(String value) {
    return _looksLikeImageUrl(value);
  }

  @override
  Widget build(BuildContext context) {
    final lines = body.split('\n');
    final widgets = <Widget>[];
    final paragraph = <String>[];

    void flushParagraph() {
      final text = paragraph.join('\n').trim();
      if (text.isNotEmpty) {
        widgets.add(
          SelectableText(
            text,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(height: 1.6),
          ),
        );
        widgets.add(const SizedBox(height: 12));
      }
      paragraph.clear();
    }

    void addImage(String url, String alt) {
      widgets.add(
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.network(
            url,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.errorRed.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'Rasm yuklanmadi: $url',
                style: const TextStyle(color: AppColors.errorRed),
              ),
            ),
          ),
        ),
      );
      if (alt.trim().isNotEmpty) {
        widgets.add(const SizedBox(height: 6));
        widgets.add(
          Text(
            alt.trim(),
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        );
      }
      widgets.add(const SizedBox(height: 12));
    }

    for (final rawLine in lines) {
      final line = rawLine.trim();
      final match = markdownImagePattern.firstMatch(line);
      if (match != null) {
        flushParagraph();
        addImage(match.group(2)!.trim(), match.group(1) ?? '');
      } else if (_isImageUrl(line)) {
        flushParagraph();
        addImage(line, '');
      } else if (line.isEmpty) {
        flushParagraph();
      } else {
        paragraph.add(rawLine);
      }
    }
    flushParagraph();

    if (widgets.isNotEmpty && widgets.last is SizedBox) {
      widgets.removeLast();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets.isEmpty ? [const SizedBox.shrink()] : widgets,
    );
  }
}

class _PostVideoQuizLauncher extends StatelessWidget {
  const _PostVideoQuizLauncher({
    required this.topic,
    required this.ready,
    required this.onStart,
  });

  final TopicLesson topic;
  final bool ready;
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final questionCount = topic.quizQuestions.length;
    final minutes = math.max(5, questionCount * 2);
    final hasImage = topic.quizQuestions.any(
      (question) => question.isImageQuestion,
    );
    final hasVideo = topic.quizQuestions.any(
      (question) => question.isVideoQuestion,
    );

    if (!ready) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: .045)
              : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppColors.studentPrimary.withValues(alpha: .16),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.studentPrimary.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.lock_clock_rounded,
                color: AppColors.studentPrimary,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Test matnli darsdan keyin ochiladi',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Avval matnli darsni tugating, keyin mavzu testini boshlashingiz mumkin.',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.studentPrimary.withValues(alpha: isDark ? .20 : .09),
            AppColors.studentAccent.withValues(alpha: isDark ? .18 : .08),
            AppColors.successGreen.withValues(alpha: isDark ? .13 : .08),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.studentPrimary.withValues(alpha: .18),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: isDark ? .10 : .84),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: const Icon(
                  Icons.assignment_turned_in_rounded,
                  color: AppColors.successGreen,
                  size: 27,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Mavzu testi',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      topic.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: .62),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              _ReadyBadge(ready: ready),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _QuizLaunchStat(
                  icon: Icons.quiz_rounded,
                  value: '$questionCount ta',
                  label: 'Savol',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _QuizLaunchStat(
                  icon: Icons.schedule_rounded,
                  value: '$minutes daqiqa',
                  label: 'Vaqt',
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: _QuizLaunchStat(
                  icon: Icons.percent_rounded,
                  value: '70%',
                  label: 'O‘tish balli',
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              const _SoftChip(
                icon: Icons.short_text_rounded,
                label: 'Matnli savol',
              ),
              if (hasImage)
                const _SoftChip(
                  icon: Icons.image_rounded,
                  label: 'Rasmli savol',
                ),
              if (hasVideo)
                const _SoftChip(
                  icon: Icons.play_circle_outline_rounded,
                  label: 'Video savol',
                ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: isDark ? .08 : .72),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.amber.withValues(alpha: .22)),
            ),
            child: const Row(
              children: [
                Icon(Icons.star_rounded, color: AppColors.amber, size: 24),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '+20 XP test muvaffaqiyatli yakunlansa qo‘shiladi',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onStart,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.studentPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text(
                'Testni boshlash',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadyBadge extends StatelessWidget {
  const _ReadyBadge({required this.ready});

  final bool ready;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: (ready ? AppColors.successGreen : AppColors.studentPrimary)
            .withValues(alpha: .12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        ready ? 'Tayyor' : 'Video so‘ng',
        style: TextStyle(
          color: ready ? AppColors.successGreen : AppColors.studentPrimary,
          fontWeight: FontWeight.w900,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _QuizLaunchStat extends StatelessWidget {
  const _QuizLaunchStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .72),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.studentPrimary.withValues(alpha: .10),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.studentPrimary, size: 18),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: .58),
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineQuizPreview extends StatelessWidget {
  const _InlineQuizPreview({required this.questionCount, this.onStart});

  final int questionCount;
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 390;
        return Container(
          padding: EdgeInsets.all(compact ? 14 : 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.successGreen.withValues(alpha: isDark ? .20 : .13),
                AppColors.studentPrimary.withValues(alpha: isDark ? .18 : .10),
                AppColors.studentAccent.withValues(alpha: isDark ? .12 : .08),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.successGreen.withValues(alpha: .22),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.studentPrimary.withValues(alpha: .08),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _QuizPreviewHeader(questionCount: questionCount),
                    const SizedBox(height: 12),
                    _QuizPreviewMeta(),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: onStart,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.studentPrimary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Testni boshlash'),
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _QuizPreviewHeader(questionCount: questionCount),
                          const SizedBox(height: 12),
                          _QuizPreviewMeta(),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    FilledButton.icon(
                      onPressed: onStart,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.studentPrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Boshlash'),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _QuizPreviewHeader extends StatelessWidget {
  const _QuizPreviewHeader({required this.questionCount});

  final int questionCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .86),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.successGreen.withValues(alpha: .16),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.fact_check_rounded,
            color: AppColors.successGreen,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Mavzu testi',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
              ),
              const SizedBox(height: 3),
              Text(
                '$questionCount ta savol tayyor',
                style: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: .64),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuizPreviewMeta extends StatelessWidget {
  const _QuizPreviewMeta();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        const _SoftChip(icon: Icons.timer_rounded, label: 'Vaqt nazoratli'),
        const _SoftChip(icon: Icons.shuffle_rounded, label: 'Aralash savollar'),
        _SoftChip(
          icon: Icons.verified_rounded,
          label: 'Natija saqlanadi',
          color: AppColors.successGreen,
        ),
      ],
    );
  }
}

class _SoftChip extends StatelessWidget {
  const _SoftChip({
    required this.icon,
    required this.label,
    this.color = AppColors.studentPrimary,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .72),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppColors.studentPrimary.withValues(alpha: .12),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _InlineVideoPlayer extends StatefulWidget {
  const _InlineVideoPlayer({
    required this.url,
    required this.title,
    required this.duration,
    required this.watchedPercent,
    required this.topicLabel,
    this.onOpenFull,
    this.onCompleted,
    this.compact = false,
    this.showStats = true,
  });

  final String url;
  final String title;
  final Duration duration;
  final int watchedPercent;
  final String topicLabel;
  final VoidCallback? onOpenFull;
  final VoidCallback? onCompleted;
  final bool compact;
  final bool showStats;

  @override
  State<_InlineVideoPlayer> createState() => _InlineVideoPlayerState();
}

class _InlineVideoPlayerState extends State<_InlineVideoPlayer> {
  YoutubePlayerController? _youtubeController;
  StreamSubscription<YoutubePlayerValue>? _youtubeSubscription;
  Timer? _youtubeTicker;
  VideoPlayerController? _videoController;
  String? _youtubeVideoId;
  bool _initializing = false;
  bool _youtubeStarted = false;
  bool _refreshingYoutubeTime = false;
  Duration _youtubeDuration = Duration.zero;
  Duration _youtubePosition = Duration.zero;
  double _playbackSpeed = 1.0;
  bool _captionsEnabled = false;
  bool _completedReported = false;

  @override
  void initState() {
    super.initState();
    _configure();
  }

  @override
  void didUpdateWidget(covariant _InlineVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _completedReported = false;
      _disposeControllers();
      _configure();
    }
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  void _disposeControllers() {
    _youtubeSubscription?.cancel();
    _youtubeSubscription = null;
    _youtubeTicker?.cancel();
    _youtubeTicker = null;
    _youtubeController?.close();
    _youtubeController = null;
    _youtubeVideoId = null;
    _youtubeStarted = false;
    _youtubeDuration = Duration.zero;
    _youtubePosition = Duration.zero;
    _videoController?.removeListener(_handleVideoTick);
    _videoController?.dispose();
    _videoController = null;
  }

  void _configure() {
    final url = widget.url.trim();
    final youtubeId = YoutubePlayerController.convertUrlToId(url);
    if (youtubeId != null) {
      _youtubeVideoId = youtubeId;
      _youtubeController = YoutubePlayerController.fromVideoId(
        videoId: youtubeId,
        autoPlay: false,
        params: const YoutubePlayerParams(
          showControls: false,
          showFullscreenButton: false,
          enableJavaScript: true,
          pointerEvents: PointerEvents.none,
        ),
      );
      _youtubeSubscription = _youtubeController?.listen((value) {
        if (!mounted) return;
        if (value.playerState == PlayerState.paused ||
            value.playerState == PlayerState.ended) {
          _youtubeTicker?.cancel();
          _youtubeTicker = null;
          if (_youtubeStarted) setState(() => _youtubeStarted = false);
        }
        if (_completedReported || value.playerState != PlayerState.ended) {
          return;
        }
        _completedReported = true;
        widget.onCompleted?.call();
      });
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) return;
    _initializing = true;
    final controller = VideoPlayerController.networkUrl(uri);
    _videoController = controller;
    controller.addListener(_handleVideoTick);
    controller
        .initialize()
        .then((_) {
          if (!mounted) return;
          setState(() => _initializing = false);
        })
        .catchError((_) {
          if (!mounted) return;
          setState(() => _initializing = false);
        });
  }

  void _handleVideoTick() {
    if (!mounted) return;
    final video = _videoController;
    if (video != null &&
        video.value.isInitialized &&
        !_completedReported &&
        video.value.duration > Duration.zero) {
      final remaining = video.value.duration - video.value.position;
      if (!remaining.isNegative &&
          remaining <= const Duration(milliseconds: 900)) {
        _completedReported = true;
        widget.onCompleted?.call();
      }
    }
    setState(() {});
  }

  String _clock(Duration value) {
    final minutes = value.inMinutes;
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Duration get _displayDuration {
    if (_youtubeDuration > Duration.zero) return _youtubeDuration;
    final video = _videoController;
    if (video != null &&
        video.value.isInitialized &&
        video.value.duration > Duration.zero) {
      return video.value.duration;
    }
    return widget.duration > Duration.zero
        ? widget.duration
        : const Duration(minutes: 12, seconds: 45);
  }

  Duration get _displayPosition {
    if (_youtubePosition > Duration.zero) return _youtubePosition;
    final video = _videoController;
    if (video != null && video.value.isInitialized) {
      return video.value.position;
    }
    final percent = widget.watchedPercent.clamp(0, 100) / 100;
    return Duration(
      milliseconds: (_displayDuration.inMilliseconds * percent).round(),
    );
  }

  double get _displayProgress {
    final total = _displayDuration.inMilliseconds;
    if (total <= 0) return 0;
    return (_displayPosition.inMilliseconds / total).clamp(0.0, 1.0);
  }

  void _toggleNativeVideo() {
    final video = _videoController;
    if (video == null || !video.value.isInitialized) return;
    setState(() {
      video.value.isPlaying ? video.pause() : video.play();
    });
  }

  void _seekNativeVideo(double value) {
    final video = _videoController;
    if (video == null || !video.value.isInitialized) return;
    final total = video.value.duration.inMilliseconds;
    if (total <= 0) return;
    final next = Duration(
      milliseconds: (total * value.clamp(0.0, 1.0)).round(),
    );
    video.seekTo(next);
  }

  void _cycleNativePlaybackSpeed() {
    final video = _videoController;
    if (video == null || !video.value.isInitialized) return;
    const speeds = [1.0, 1.25, 1.5, 2.0, 0.75];
    final currentIndex = speeds.indexWhere(
      (speed) => (speed - _playbackSpeed).abs() < 0.01,
    );
    final nextSpeed = speeds[(currentIndex + 1) % speeds.length];
    video.setPlaybackSpeed(nextSpeed);
    setState(() => _playbackSpeed = nextSpeed);
  }

  void _toggleYoutubePlayback() {
    final youtube = _youtubeController;
    if (youtube == null) return;
    final shouldPlay = !_youtubeStarted;
    setState(() => _youtubeStarted = shouldPlay);
    if (shouldPlay) {
      unawaited(youtube.playVideo());
      _startYoutubeTicker();
    } else {
      unawaited(youtube.pauseVideo());
      _youtubeTicker?.cancel();
      _youtubeTicker = null;
    }
  }

  void _seekYoutubeVideo(double value) {
    final youtube = _youtubeController;
    if (youtube == null) return;
    final total = _displayDuration.inSeconds;
    if (total <= 0) return;
    final seconds = total * value.clamp(0.0, 1.0);
    unawaited(youtube.seekTo(seconds: seconds, allowSeekAhead: true));
    setState(() {
      _youtubePosition = Duration(milliseconds: (seconds * 1000).round());
    });
  }

  void _cycleYoutubePlaybackSpeed() {
    final youtube = _youtubeController;
    if (youtube == null) return;
    const speeds = [1.0, 1.25, 1.5, 2.0, 0.75];
    final currentIndex = speeds.indexWhere(
      (speed) => (speed - _playbackSpeed).abs() < 0.01,
    );
    final nextSpeed = speeds[(currentIndex + 1) % speeds.length];
    unawaited(youtube.setPlaybackRate(nextSpeed));
    setState(() => _playbackSpeed = nextSpeed);
  }

  void _startYoutubeTicker() {
    _youtubeTicker ??= Timer.periodic(const Duration(seconds: 1), (_) {
      unawaited(_refreshYoutubeTime());
    });
    unawaited(_refreshYoutubeTime());
  }

  Future<void> _refreshYoutubeTime() async {
    final youtube = _youtubeController;
    if (youtube == null || _refreshingYoutubeTime) return;
    _refreshingYoutubeTime = true;
    try {
      final positionSeconds = await youtube.currentTime;
      final durationSeconds = await youtube.duration;
      if (!mounted) return;
      final duration = Duration(
        milliseconds: math.max(0, durationSeconds * 1000).round(),
      );
      final position = Duration(
        milliseconds: math.max(0, positionSeconds * 1000).round(),
      );
      setState(() {
        if (duration > Duration.zero) _youtubeDuration = duration;
        _youtubePosition = position;
      });
      if (!_completedReported &&
          duration > Duration.zero &&
          duration - position <= const Duration(milliseconds: 900)) {
        _completedReported = true;
        widget.onCompleted?.call();
      }
    } catch (_) {
      // YouTube iframe may not be ready during the first second.
    } finally {
      _refreshingYoutubeTime = false;
    }
  }

  Future<void> _openFullscreenVideo() async {
    final url = widget.url.trim();
    if (url.isEmpty) return;
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    try {
      if (!mounted) return;
      await showGeneralDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Videoni yopish',
        barrierColor: Colors.black,
        transitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (context, _, __) => _FullscreenVideoDialog(
          url: url,
          title: widget.title,
          topicLabel: widget.topicLabel,
          initialSpeed: _playbackSpeed,
          onCompleted: widget.onCompleted,
        ),
      );
    } finally {
      await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  void _toggleCaptionsIndicator() {
    setState(() => _captionsEnabled = !_captionsEnabled);
    ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(
          _captionsEnabled
              ? 'Subtitr ko‘rsatkichi yoqildi.'
              : 'Subtitr ko‘rsatkichi o‘chirildi.',
        ),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  String get _speedLabel {
    final value = _playbackSpeed
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'\.?0+$'), '');
    return value == '1' ? '1.0x' : '${value}x';
  }

  @override
  Widget build(BuildContext context) {
    final youtube = _youtubeController;
    final video = _videoController;
    final youtubeId = _youtubeVideoId;
    final duration = _displayDuration;
    final position = _displayPosition;
    final progress = _displayProgress;
    final watched = progress > 0
        ? (progress * 100).round()
        : widget.watchedPercent.clamp(0, 100).toInt();

    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final playerHeight = widget.compact
                ? math.max(160.0, math.min(215.0, constraints.maxWidth * .56))
                : math.max(225.0, math.min(330.0, constraints.maxWidth * .64));
            return ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: double.infinity,
                height: playerHeight,
                child: video != null && video.value.isInitialized
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          ColoredBox(
                            color: Colors.black,
                            child: FittedBox(
                              fit: BoxFit.cover,
                              child: SizedBox(
                                width: video.value.size.width,
                                height: video.value.size.height,
                                child: VideoPlayer(video),
                              ),
                            ),
                          ),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(alpha: .08),
                                  Colors.black.withValues(alpha: .42),
                                ],
                              ),
                            ),
                          ),
                          _VideoPosterOverlay(
                            title: widget.title,
                            topicLabel: widget.topicLabel,
                            progress: progress,
                            position: _clock(position),
                            duration: _clock(duration),
                            playing: video.value.isPlaying,
                            speedLabel: _speedLabel,
                            captionsEnabled: _captionsEnabled,
                            onPlay: _toggleNativeVideo,
                            onSeek: _seekNativeVideo,
                            onSpeedTap: _cycleNativePlaybackSpeed,
                            onCaptionsTap: _toggleCaptionsIndicator,
                            onOpenFull: _openFullscreenVideo,
                          ),
                        ],
                      )
                    : youtubeId != null && youtube != null
                    ? _YoutubePoster(
                        controller: youtube,
                        videoId: youtubeId,
                        title: widget.title,
                        topicLabel: widget.topicLabel,
                        progress: progress,
                        position: _clock(position),
                        duration: _clock(duration),
                        playing: _youtubeStarted,
                        speedLabel: _speedLabel,
                        captionsEnabled: _captionsEnabled,
                        onPlay: _toggleYoutubePlayback,
                        onSeek: _seekYoutubeVideo,
                        onSpeedTap: _cycleYoutubePlaybackSpeed,
                        onCaptionsTap: _toggleCaptionsIndicator,
                        onOpenFull: _openFullscreenVideo,
                      )
                    : Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF111827), Color(0xFF3B1A72)],
                          ),
                        ),
                        alignment: Alignment.center,
                        child: _initializing
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 58,
                                    height: 58,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: .14,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.videocam_off_rounded,
                                      color: Colors.white,
                                      size: 30,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Video ilova ichida ochilmadi',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Link formatini yoki fayl ruxsatini tekshiring.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: .72,
                                      ),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                      ),
              ),
            );
          },
        ),
        if (widget.showStats) ...[
          const SizedBox(height: 10),
          _VideoStatsPanel(
            duration: duration,
            watchedPercent: watched,
            lastPosition: position,
          ),
        ],
      ],
    );
  }
}

class _YoutubePoster extends StatelessWidget {
  const _YoutubePoster({
    required this.controller,
    required this.videoId,
    required this.title,
    required this.topicLabel,
    required this.progress,
    required this.position,
    required this.duration,
    required this.playing,
    required this.speedLabel,
    required this.captionsEnabled,
    required this.onPlay,
    required this.onSeek,
    required this.onSpeedTap,
    required this.onCaptionsTap,
    required this.onOpenFull,
  });

  final YoutubePlayerController controller;
  final String videoId;
  final String title;
  final String topicLabel;
  final double progress;
  final String position;
  final String duration;
  final bool playing;
  final String speedLabel;
  final bool captionsEnabled;
  final VoidCallback onPlay;
  final ValueChanged<double> onSeek;
  final VoidCallback onSpeedTap;
  final VoidCallback onCaptionsTap;
  final VoidCallback? onOpenFull;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        AbsorbPointer(
          child: YoutubePlayer(
            controller: controller,
            aspectRatio: 16 / 9,
            backgroundColor: Colors.black,
          ),
        ),
        if (!playing)
          Image.network(
            'https://img.youtube.com/vi/$videoId/hqdefault.jpg',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF13213E), Color(0xFF1E1458)],
                ),
              ),
            ),
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: .18),
                Colors.black.withValues(alpha: .58),
              ],
            ),
          ),
        ),
        _VideoPosterOverlay(
          title: title,
          topicLabel: topicLabel,
          progress: progress,
          position: position,
          duration: duration,
          playing: playing,
          speedLabel: speedLabel,
          captionsEnabled: captionsEnabled,
          onPlay: onPlay,
          onSeek: onSeek,
          onSpeedTap: onSpeedTap,
          onCaptionsTap: onCaptionsTap,
          onOpenFull: onOpenFull,
        ),
      ],
    );
  }
}

class _FullscreenVideoDialog extends StatefulWidget {
  const _FullscreenVideoDialog({
    required this.url,
    required this.title,
    required this.topicLabel,
    required this.initialSpeed,
    this.onCompleted,
  });

  final String url;
  final String title;
  final String topicLabel;
  final double initialSpeed;
  final VoidCallback? onCompleted;

  @override
  State<_FullscreenVideoDialog> createState() => _FullscreenVideoDialogState();
}

class _FullscreenVideoDialogState extends State<_FullscreenVideoDialog> {
  YoutubePlayerController? _youtubeController;
  StreamSubscription<YoutubePlayerValue>? _youtubeSubscription;
  VideoPlayerController? _videoController;
  double _speed = 1.0;
  bool _loading = true;
  bool _completedReported = false;

  @override
  void initState() {
    super.initState();
    _speed = widget.initialSpeed;
    _configure();
  }

  @override
  void dispose() {
    _youtubeSubscription?.cancel();
    _youtubeController?.close();
    _videoController?.removeListener(_handleNativeTick);
    _videoController?.dispose();
    super.dispose();
  }

  void _configure() {
    final youtubeId = YoutubePlayerController.convertUrlToId(widget.url);
    if (youtubeId != null) {
      final controller = YoutubePlayerController.fromVideoId(
        videoId: youtubeId,
        autoPlay: true,
        params: const YoutubePlayerParams(
          showControls: true,
          showFullscreenButton: false,
          enableJavaScript: true,
        ),
      );
      _youtubeController = controller;
      unawaited(controller.setPlaybackRate(_speed));
      _youtubeSubscription = controller.listen((value) {
        if (!mounted ||
            _completedReported ||
            value.playerState != PlayerState.ended) {
          return;
        }
        _completedReported = true;
        widget.onCompleted?.call();
      });
      setState(() => _loading = false);
      return;
    }

    final uri = Uri.tryParse(widget.url);
    if (uri == null || !uri.hasScheme) {
      setState(() => _loading = false);
      return;
    }
    final controller = VideoPlayerController.networkUrl(uri);
    _videoController = controller;
    controller.addListener(_handleNativeTick);
    controller
        .initialize()
        .then((_) {
          if (!mounted) return;
          unawaited(controller.setPlaybackSpeed(_speed));
          unawaited(controller.play());
          setState(() => _loading = false);
        })
        .catchError((_) {
          if (!mounted) return;
          setState(() => _loading = false);
        });
  }

  void _handleNativeTick() {
    final video = _videoController;
    if (!mounted || video == null || !video.value.isInitialized) return;
    if (!_completedReported && video.value.duration > Duration.zero) {
      final remaining = video.value.duration - video.value.position;
      if (!remaining.isNegative &&
          remaining <= const Duration(milliseconds: 900)) {
        _completedReported = true;
        widget.onCompleted?.call();
      }
    }
    setState(() {});
  }

  void _setSpeed(double value) {
    setState(() => _speed = value);
    unawaited(_youtubeController?.setPlaybackRate(value));
    unawaited(_videoController?.setPlaybackSpeed(value));
  }

  String _clock(Duration value) {
    final minutes = value.inMinutes;
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final youtube = _youtubeController;
    final video = _videoController;
    final videoReady = video != null && video.value.isInitialized;

    return Material(
      color: Colors.black,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          widget.topicLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: .62),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: ColoredBox(
                        color: Colors.black,
                        child: _loading
                            ? const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                ),
                              )
                            : youtube != null
                            ? YoutubePlayer(
                                controller: youtube,
                                aspectRatio: 16 / 9,
                                backgroundColor: Colors.black,
                              )
                            : videoReady
                            ? Stack(
                                fit: StackFit.expand,
                                children: [
                                  FittedBox(
                                    fit: BoxFit.contain,
                                    child: SizedBox(
                                      width: video.value.size.width,
                                      height: video.value.size.height,
                                      child: VideoPlayer(video),
                                    ),
                                  ),
                                  Center(
                                    child: IconButton.filled(
                                      style: IconButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor:
                                            AppColors.studentPrimary,
                                        fixedSize: const Size(72, 72),
                                      ),
                                      onPressed: () {
                                        video.value.isPlaying
                                            ? video.pause()
                                            : video.play();
                                      },
                                      icon: Icon(
                                        video.value.isPlaying
                                            ? Icons.pause_rounded
                                            : Icons.play_arrow_rounded,
                                        size: 38,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    left: 18,
                                    right: 18,
                                    bottom: 14,
                                    child: Row(
                                      children: [
                                        Text(
                                          _clock(video.value.position),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: LinearProgressIndicator(
                                            value:
                                                video.value.duration >
                                                    Duration.zero
                                                ? (video
                                                          .value
                                                          .position
                                                          .inMilliseconds /
                                                      video
                                                          .value
                                                          .duration
                                                          .inMilliseconds)
                                                : 0,
                                            color: AppColors.studentAccent,
                                            backgroundColor: Colors.white
                                                .withValues(alpha: .28),
                                            minHeight: 4,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          _clock(video.value.duration),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            : const Center(
                                child: Text(
                                  'Video ochilmadi',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [0.75, 1.0, 1.25, 1.5, 2.0].map((value) {
                  final selected = (_speed - value).abs() < .01;
                  final label = value == 1 ? '1x' : '${value}x';
                  return ChoiceChip(
                    selected: selected,
                    label: Text(label),
                    onSelected: (_) => _setSpeed(value),
                    selectedColor: AppColors.studentPrimary,
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : Colors.white70,
                      fontWeight: FontWeight.w900,
                    ),
                    backgroundColor: Colors.white.withValues(alpha: .1),
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: .16),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VideoPosterOverlay extends StatelessWidget {
  const _VideoPosterOverlay({
    required this.title,
    required this.topicLabel,
    required this.progress,
    required this.position,
    required this.duration,
    required this.playing,
    required this.speedLabel,
    required this.captionsEnabled,
    required this.onPlay,
    this.onSeek,
    this.onSpeedTap,
    this.onCaptionsTap,
    required this.onOpenFull,
  });

  final String title;
  final String topicLabel;
  final double progress;
  final String position;
  final String duration;
  final bool playing;
  final String speedLabel;
  final bool captionsEnabled;
  final VoidCallback onPlay;
  final ValueChanged<double>? onSeek;
  final VoidCallback? onSpeedTap;
  final VoidCallback? onCaptionsTap;
  final VoidCallback? onOpenFull;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          left: 16,
          top: 16,
          right: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  height: 1.16,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                'Klinik laboratoriya va uning vazifalari',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .88),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  height: 1.32,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.studentPrimary,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  topicLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
        Center(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onPlay,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .94),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .22),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Icon(
                playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: AppColors.studentPrimary,
                size: 40,
              ),
            ),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 11,
          child: Column(
            children: [
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 4,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 5,
                  ),
                  overlayShape: SliderComponentShape.noOverlay,
                  activeTrackColor: AppColors.studentAccent,
                  inactiveTrackColor: Colors.white.withValues(alpha: .34),
                  thumbColor: Colors.white,
                ),
                child: Slider(
                  value: progress.clamp(0.0, 1.0),
                  onChanged: onSeek,
                ),
              ),
              Row(
                children: [
                  SizedBox(
                    width: 34,
                    height: 34,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onPlay,
                      child: Center(
                        child: Icon(
                          playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '$position / $duration',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onSpeedTap,
                    child: Container(
                      height: 32,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: .18),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        speedLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 13),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onCaptionsTap,
                    child: Container(
                      height: 30,
                      constraints: const BoxConstraints(minWidth: 34),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: captionsEnabled
                            ? AppColors.studentAccent
                            : Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'CC',
                        style: TextStyle(
                          color: captionsEnabled
                              ? Colors.white
                              : const Color(0xFF111827),
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 34,
                    height: 34,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onOpenFull,
                      child: const Center(
                        child: Icon(
                          Icons.fullscreen_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _VideoStatsPanel extends StatelessWidget {
  const _VideoStatsPanel({
    required this.duration,
    required this.watchedPercent,
    required this.lastPosition,
  });

  final Duration duration;
  final int watchedPercent;
  final Duration lastPosition;

  String _clock(Duration value) {
    final minutes = value.inMinutes;
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: .04)
            : AppColors.studentPrimary.withValues(alpha: .035),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: AppColors.studentPrimary.withValues(alpha: .13),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _VideoStatItem(
              icon: Icons.schedule_rounded,
              label: 'Davomiyligi',
              value: '${_clock(duration)} min',
            ),
          ),
          _VideoStatDivider(isDark: isDark),
          Expanded(
            child: _VideoStatItem(
              icon: Icons.trending_up_rounded,
              label: 'Ko‘rilgan',
              value: '$watchedPercent%',
            ),
          ),
          _VideoStatDivider(isDark: isDark),
          Expanded(
            child: _VideoStatItem(
              icon: Icons.bookmark_border_rounded,
              label: 'Oxirgi joy',
              value: _clock(lastPosition),
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoStatDivider extends StatelessWidget {
  const _VideoStatDivider({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 34,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: (isDark ? Colors.white : const Color(0xFFCBD5E1)).withValues(
        alpha: .6,
      ),
    );
  }
}

class _VideoStatItem extends StatelessWidget {
  const _VideoStatItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.studentPrimary.withValues(alpha: .10),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.studentPrimary, size: 18),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isDark
                      ? Colors.white.withValues(alpha: .64)
                      : const Color(0xFF64748B),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF111827),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _VideoLessonScreen extends StatefulWidget {
  const _VideoLessonScreen({
    required this.topic,
    required this.onBack,
    required this.onComplete,
  });

  final TopicLesson topic;
  final VoidCallback onBack;
  final VoidCallback onComplete;

  @override
  State<_VideoLessonScreen> createState() => _VideoLessonScreenState();
}

class _VideoLessonScreenState extends State<_VideoLessonScreen> {
  bool _showNotes = false;
  YoutubePlayerController? _youtubeController;

  @override
  void initState() {
    super.initState();
    _configureYoutubePlayer();
  }

  @override
  void didUpdateWidget(covariant _VideoLessonScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.topic.videoUrl != widget.topic.videoUrl) {
      _disposeYoutubePlayer();
      _configureYoutubePlayer();
    }
  }

  @override
  void dispose() {
    _disposeYoutubePlayer();
    super.dispose();
  }

  void _configureYoutubePlayer() {
    final videoId = YoutubePlayerController.convertUrlToId(
      widget.topic.videoUrl.trim(),
    );
    if (videoId == null) return;
    _youtubeController = YoutubePlayerController.fromVideoId(
      videoId: videoId,
      autoPlay: false,
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: true,
        enableJavaScript: true,
      ),
    );
  }

  void _disposeYoutubePlayer() {
    _youtubeController?.close();
    _youtubeController = null;
  }

  Future<void> _openVideo() async {
    final uri = Uri.tryParse(widget.topic.videoUrl.trim());
    if (uri == null || !uri.hasScheme) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_t(context, 'video_not_set'))));
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_t(context, 'video_not_open'))));
    }
  }

  Duration get _lessonDuration {
    final materialDuration = widget.topic.videoMaterials
        .where((item) => item.duration > Duration.zero)
        .map((item) => item.duration)
        .firstOrNull;
    if (materialDuration != null) return materialDuration;
    if (widget.topic.duration > Duration.zero) return widget.topic.duration;
    return const Duration(minutes: 12, seconds: 45);
  }

  String _clock(Duration value) {
    final minutes = value.inMinutes.toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  List<(Duration, String)> _chapters() {
    if (widget.topic.videoChapters.isNotEmpty) {
      return widget.topic.videoChapters
          .map((chapter) => (chapter.time, chapter.title))
          .toList(growable: false);
    }

    final materialChapters =
        widget.topic.videoMaterials
            .expand((material) => material.chapters)
            .toList()
          ..sort((a, b) => a.time.compareTo(b.time));
    if (materialChapters.isNotEmpty) {
      return materialChapters
          .map((chapter) => (chapter.time, chapter.title))
          .toList(growable: false);
    }

    final summaryLines = widget.topic.summary
        .split(RegExp(r'[\n•\-]+'))
        .map((line) => line.trim())
        .where((line) => line.length > 3)
        .take(4)
        .toList();
    final labels = summaryLines.isEmpty
        ? <String>[
            'Kirish',
            'Klinik laboratoriya ta’rifi',
            'Asosiy vazifalar',
            'Bo‘limlar',
            'Xulosa',
          ]
        : <String>['Kirish', ...summaryLines, 'Xulosa'];
    final duration = _lessonDuration;
    final step = duration.inMilliseconds <= 0
        ? const Duration(minutes: 2)
        : Duration(
            milliseconds: (duration.inMilliseconds / labels.length).floor(),
          );
    return [
      for (var index = 0; index < labels.length; index += 1)
        (step * index, labels[index]),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topic = widget.topic;
    final youtubeController = _youtubeController;
    final youtubeVideoId = YoutubePlayerController.convertUrlToId(
      topic.videoUrl.trim(),
    );

    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final borderCol = isDark
        ? const Color(0xFF1E293B)
        : const Color(0xFFE2E8F0);
    final cardBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final mutedTextColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MobileHeader(
          title: _t(context, 'video_lesson'),
          subtitle: topic.title,
          onBack: widget.onBack,
        ),
        const SizedBox(height: 18),
        Text(
          topic.title,
          style: TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 14),
        Container(
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderCol, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      topic.videoTitle.isEmpty
                          ? 'Video darslik'
                          : topic.videoTitle,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: youtubeController == null
                            ? AspectRatio(
                                aspectRatio: 16 / 9,
                                child: _VideoLaunchPreview(
                                  videoId: youtubeVideoId,
                                  onOpen: _openVideo,
                                  title: topic.videoTitle.isEmpty
                                      ? topic.title
                                      : topic.videoTitle,
                                ),
                              )
                            : YoutubePlayer(
                                controller: youtubeController,
                                aspectRatio: 16 / 9,
                              ),
                      ),
                    ),
                    if (!kIsWeb && youtubeVideoId != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.studentPrimary.withValues(
                            alpha: .08,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              color: AppColors.studentPrimary,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Video ilova ichida ochiladi. Agar YouTube embed bloklasa, pastdagi tugma orqali tashqi ochishingiz mumkin.',
                                style: TextStyle(
                                  color: mutedTextColor,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _VideoLessonTabButton(
                            label: 'Mavzu bo‘limlari',
                            selected: !_showNotes,
                            onPressed: () => setState(() => _showNotes = false),
                          ),
                        ),
                        Expanded(
                          child: _VideoLessonTabButton(
                            label: 'Izohlar',
                            selected: _showNotes,
                            onPressed: () => setState(() => _showNotes = true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: _showNotes
                          ? _VideoLessonNotes(
                              key: const ValueKey('video-notes'),
                              text: topic.summary,
                              textColor: textColor,
                              mutedTextColor: mutedTextColor,
                              borderColor: borderCol,
                            )
                          : _VideoLessonChapters(
                              key: const ValueKey('video-chapters'),
                              chapters: _chapters(),
                              activeColor: AppColors.studentPrimary,
                              textColor: textColor,
                              mutedTextColor: mutedTextColor,
                            ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
                child: InkWell(
                  onTap: _openVideo,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.studentPrimary.withValues(alpha: .06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.studentPrimary.withValues(alpha: .12),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 18,
                          color: AppColors.studentPrimary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _clock(_lessonDuration),
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'YouTube’da ochish',
                          style: TextStyle(
                            color: AppColors.studentPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.open_in_new_rounded,
                          color: AppColors.studentPrimary,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: widget.onComplete,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.studentPrimary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Video dars tugallandi',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
            ),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

class _VideoLaunchPreview extends StatelessWidget {
  const _VideoLaunchPreview({
    required this.videoId,
    required this.onOpen,
    required this.title,
  });

  final String? videoId;
  final VoidCallback onOpen;
  final String title;

  @override
  Widget build(BuildContext context) {
    final thumbnailUrl = videoId == null
        ? null
        : 'https://img.youtube.com/vi/$videoId/hqdefault.jpg';

    return Material(
      color: Colors.black,
      child: InkWell(
        onTap: onOpen,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (thumbnailUrl != null)
              Image.network(
                thumbnailUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: .15),
                    Colors.black.withValues(alpha: .72),
                  ],
                ),
              ),
            ),
            Center(
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF0033),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: .25),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 46,
                ),
              ),
            ),
            Positioned(
              left: 14,
              right: 14,
              bottom: 14,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .16),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: .2),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.open_in_new_rounded,
                          color: Colors.white,
                          size: 15,
                        ),
                        SizedBox(width: 5),
                        Text(
                          'YouTube',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoLessonTabButton extends StatelessWidget {
  const _VideoLessonTabButton({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: selected
            ? AppColors.studentPrimary
            : AppColors.studentMuted,
        padding: const EdgeInsets.symmetric(vertical: 10),
        shape: const RoundedRectangleBorder(),
      ),
      child: Column(
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 7),
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            height: 2.5,
            width: selected ? 82 : 0,
            decoration: BoxDecoration(
              color: AppColors.studentPrimary,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoLessonChapters extends StatelessWidget {
  const _VideoLessonChapters({
    super.key,
    required this.chapters,
    required this.activeColor,
    required this.textColor,
    required this.mutedTextColor,
  });

  final List<(Duration, String)> chapters;
  final Color activeColor;
  final Color textColor;
  final Color mutedTextColor;

  String _clock(Duration value) {
    final minutes = value.inMinutes.toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < chapters.length; index += 1)
          Padding(
            padding: EdgeInsets.only(
              bottom: index == chapters.length - 1 ? 0 : 10,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 46,
                  child: Text(
                    _clock(chapters[index].$1),
                    style: TextStyle(
                      color: index == 0 ? activeColor : mutedTextColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    chapters[index].$2,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 12,
                      fontWeight: index == 0
                          ? FontWeight.w900
                          : FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _VideoLessonNotes extends StatelessWidget {
  const _VideoLessonNotes({
    super.key,
    required this.text,
    required this.textColor,
    required this.mutedTextColor,
    required this.borderColor,
  });

  final String text;
  final Color textColor;
  final Color mutedTextColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final note = text.trim().isEmpty
        ? 'Bu video dars uchun izohlar hali kiritilmagan.'
        : text.trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        note,
        style: TextStyle(
          color: note == text.trim() ? textColor : mutedTextColor,
          fontSize: 12,
          height: 1.45,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

extension _FirstOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (iterator.moveNext()) return iterator.current;
    return null;
  }
}

class _TopicQuizScreen extends StatelessWidget {
  const _TopicQuizScreen({
    required this.topicTitle,
    required this.questions,
    required this.questionIndex,
    required this.selectedOption,
    required this.onSelected,
    required this.onNext,
    required this.onPrevious,
    required this.onBack,
  });

  final String topicTitle;
  final List<QuizQuestion> questions;
  final int questionIndex;
  final int selectedOption;
  final ValueChanged<int> onSelected;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final safeIndex = questionIndex.clamp(0, questions.length - 1).toInt();
    final question = questions[safeIndex];
    final questionKind = question.isVideoQuestion
        ? ('Video savol', Icons.videocam_rounded)
        : question.isImageQuestion
        ? ('Rasmli savol', Icons.image_rounded)
        : ('Matnli savol', Icons.article_rounded);
    final rawTitle = topicTitle.trim();
    final displayTitle = rawTitle.isEmpty ? 'Mavzu testi' : rawTitle;
    final quizTitle = displayTitle.toLowerCase().contains('test')
        ? displayTitle
        : '$displayTitle testi';

    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final borderCol = isDark
        ? const Color(0xFF1E293B)
        : const Color(0xFFE2E8F0);
    final cardBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final mutedTextColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MobileHeader(
          title: quizTitle,
          subtitle: '${safeIndex + 1}-savol / ${questions.length} ta',
          onBack: onBack,
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF6C4DFF).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFF6C4DFF).withValues(alpha: 0.2),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.timer_outlined, color: Color(0xFF6C4DFF), size: 16),
                const SizedBox(width: 6),
                Text(
                  '04:20',
                  style: TextStyle(
                    color: Color(0xFF6C4DFF),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: borderCol, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_t(context, 'question')} ${safeIndex + 1} / ${questions.length}',
                    style: TextStyle(
                      color: mutedTextColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    '${((safeIndex + 1) / questions.length * 100).toInt()}%',
                    style: const TextStyle(
                      color: Color(0xFF6C4DFF),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                height: 6,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: (safeIndex + 1) / questions.length,
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: const Color(0xFF6C4DFF),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: AppColors.studentPrimary.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.studentPrimary.withValues(alpha: .14),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      questionKind.$2,
                      size: 15,
                      color: AppColors.studentPrimary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      questionKind.$1,
                      style: const TextStyle(
                        color: AppColors.studentPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                question.question,
                style: TextStyle(
                  color: textColor,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),
              if (question.hasMedia) ...[
                _QuestionMediaBlock(question: question),
                const SizedBox(height: 18),
              ] else if (question.assetLabel != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E293B).withValues(alpha: 0.4)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderCol),
                  ),
                  child: Text(
                    question.assetLabel!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF6C4DFF),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
              ],
              ...List.generate(
                question.options.length,
                (index) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _OptionTile(
                    label: String.fromCharCode(65 + index),
                    text: question.options[index],
                    selected: selectedOption == index,
                    onTap: () => onSelected(index),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            SizedBox(
              width: 56,
              child: OutlinedButton(
                onPressed: safeIndex == 0 ? null : onPrevious,
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark
                      ? Colors.white
                      : const Color(0xFF64748B),
                  side: BorderSide(color: borderCol, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Icon(Icons.arrow_back_rounded, size: 20),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextButton.icon(
                onPressed: () {
                  final explanation = question.explanation.trim();
                  ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
                  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                    SnackBar(
                      content: Text(
                        explanation.isEmpty
                            ? 'Bu savol uchun izoh hali kiritilmagan.'
                            : explanation,
                      ),
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF64748B),
                  backgroundColor: isDark
                      ? Colors.white.withValues(alpha: .04)
                      : const Color(0xFFF8FAFC),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.visibility_outlined, size: 18),
                label: const Text(
                  'Izoh',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: onNext,
                style: FilledButton.styleFrom(
                  backgroundColor: safeIndex < questions.length - 1
                      ? const Color(0xFF6C4DFF)
                      : AppColors.successGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: Icon(
                  safeIndex < questions.length - 1
                      ? Icons.arrow_forward_rounded
                      : Icons.check_circle_rounded,
                  size: 20,
                ),
                label: Text(
                  safeIndex < questions.length - 1
                      ? _t(context, 'next')
                      : _t(context, 'submit'),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: MediaQuery.paddingOf(context).bottom + 96),
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.label,
    required this.text,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final borderCol = isDark
        ? const Color(0xFF1E293B)
        : const Color(0xFFE2E8F0);
    final cardBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final selectedColor = const Color(0xFF6C4DFF);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: selected ? null : cardBg,
              gradient: selected
                  ? LinearGradient(
                      colors: [
                        selectedColor.withValues(alpha: .18),
                        selectedColor.withValues(alpha: .08),
                      ],
                    )
                  : null,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected ? selectedColor : borderCol,
                width: selected ? 2.0 : 1.5,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: selectedColor.withValues(alpha: .14),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: selected
                        ? const LinearGradient(
                            colors: [
                              AppColors.studentPrimary,
                              AppColors.studentAccent,
                            ],
                          )
                        : null,
                    color: selected
                        ? null
                        : (isDark
                              ? const Color(0xFF1E293B)
                              : const Color(0xFFF1F5F9)),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: selected
                          ? Colors.white
                          : (isDark ? Colors.white70 : selectedColor),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuestionMediaBlock extends StatelessWidget {
  const _QuestionMediaBlock({required this.question});

  final QuizQuestion question;

  @override
  Widget build(BuildContext context) {
    final url = question.mediaUrl.trim();
    if (question.isImageQuestion) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              width: double.infinity,
              height: 190,
              child: Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _mediaFallback(
                  Icons.image_not_supported_rounded,
                  'Rasm ochilmadi',
                ),
              ),
            ),
          ),
          Positioned(
            right: 10,
            bottom: 10,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .92),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.fullscreen_rounded,
                color: AppColors.studentPrimary,
              ),
            ),
          ),
        ],
      );
    }
    if (question.isVideoQuestion) {
      return _InlineVideoPlayer(
        url: url,
        title: question.question.trim().isEmpty
            ? 'Savol videosi'
            : question.question,
        duration: Duration.zero,
        watchedPercent: 0,
        topicLabel: 'SAVOL',
        compact: true,
        showStats: false,
      );
    }
    return _mediaFallback(Icons.attach_file_rounded, url);
  }

  Widget _mediaFallback(IconData icon, String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.studentPrimary),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _QuizResultScreen extends StatelessWidget {
  const _QuizResultScreen({
    required this.topic,
    required this.score,
    required this.answers,
    required this.canOpenFinalExam,
    required this.onContinue,
    required this.onFinalExam,
  });

  final TopicLesson topic;
  final int score;
  final Map<int, int> answers;
  final bool canOpenFinalExam;
  final VoidCallback onContinue;
  final VoidCallback onFinalExam;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalQuestions = topic.quizQuestions.length;
    final correctAnswers = ((score / 100) * totalQuestions).round();
    final isSuccess = score >= 70;

    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final borderCol = isDark
        ? const Color(0xFF1E293B)
        : const Color(0xFFE2E8F0);
    final cardBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final mutedTextColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);

    return Column(
      children: [
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderCol, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: isSuccess
                      ? AppColors.successGreen.withValues(alpha: .1)
                      : AppColors.errorRed.withValues(alpha: .1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSuccess
                        ? AppColors.successGreen.withValues(alpha: .2)
                        : AppColors.errorRed.withValues(alpha: .2),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  isSuccess
                      ? Icons.emoji_events_rounded
                      : Icons.warning_rounded,
                  color: isSuccess
                      ? AppColors.successGreen
                      : AppColors.errorRed,
                  size: 44,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                isSuccess
                    ? _t(context, 'great')
                    : 'Yana bir bor urinib ko‘ring',
                style: TextStyle(
                  color: textColor,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${topic.title} ${_t(context, 'topic_done')}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: mutedTextColor,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              CircularScore(
                value: score / 100,
                label: '$score%',
                color: isSuccess ? AppColors.successGreen : AppColors.errorRed,
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E293B).withValues(alpha: 0.3)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderCol),
                ),
                child: Column(
                  children: [
                    _ResultStat(
                      label: 'To‘g‘ri javoblar',
                      value: '$correctAnswers / $totalQuestions',
                    ),
                    const Divider(height: 16),
                    const _ResultStat(
                      label: 'Hisoblash usuli',
                      value: 'Avtomatik',
                    ),
                    const Divider(height: 16),
                    _ResultStat(
                      label: 'Keyingi bosqich',
                      value: isSuccess && canOpenFinalExam
                          ? 'Yakuniy test'
                          : 'Mavzular ro‘yxati',
                    ),
                  ],
                ),
              ),
              if (topic.quizQuestions.isNotEmpty) ...[
                const SizedBox(height: 18),
                _QuestionAnalysisPanel(
                  questions: topic.quizQuestions,
                  answers: answers,
                ),
              ],
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.amber.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.amber.withValues(alpha: .22),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .70),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.star_rounded,
                        color: AppColors.amber,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isSuccess
                            ? '+20 XP hisobingizga qo‘shildi'
                            : '70% va undan yuqori natija bilan XP olasiz',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onContinue,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF6C4DFF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                  label: Text(
                    _t(context, 'back_topics'),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              if (isSuccess && canOpenFinalExam) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onFinalExam,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.amber,
                      side: BorderSide(
                        color: AppColors.amber.withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.emoji_events_rounded, size: 20),
                    label: Text(
                      _t(context, 'final_exam'),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _QuestionAnalysisPanel extends StatelessWidget {
  const _QuestionAnalysisPanel({
    required this.questions,
    required this.answers,
  });

  final List<QuizQuestion> questions;
  final Map<int, int> answers;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark
        ? const Color(0xFF1E293B)
        : const Color(0xFFE2E8F0);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: .035)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: Text(
              'Savollar tahlili',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
          ),
          for (var index = 0; index < questions.length; index++)
            _QuestionAnalysisRow(
              index: index,
              question: questions[index],
              selectedIndex: answers[index],
            ),
        ],
      ),
    );
  }
}

class _QuestionAnalysisRow extends StatefulWidget {
  const _QuestionAnalysisRow({
    required this.index,
    required this.question,
    required this.selectedIndex,
  });

  final int index;
  final QuizQuestion question;
  final int? selectedIndex;

  @override
  State<_QuestionAnalysisRow> createState() => _QuestionAnalysisRowState();
}

class _QuestionAnalysisRowState extends State<_QuestionAnalysisRow>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;

  bool get _isCorrect => widget.selectedIndex == widget.question.correctIndex;

  String _optionLabel(int index) => String.fromCharCode(65 + index);

  String _optionValue(int? optionIndex) {
    if (optionIndex == null ||
        optionIndex < 0 ||
        optionIndex >= widget.question.options.length) {
      return 'Javob tanlanmagan';
    }
    return '${_optionLabel(optionIndex)}. ${widget.question.options[optionIndex]}';
  }

  String _explanationText() {
    final customExplanation = widget.question.explanation.trim();
    final correctAnswer = _optionValue(widget.question.correctIndex);
    final selectedAnswer = _optionValue(widget.selectedIndex);

    if (_isCorrect) {
      if (customExplanation.isNotEmpty) {
        return 'To‘g‘ri javob: $correctAnswer.\n$customExplanation';
      }
      return 'Siz to‘g‘ri javobni tanlagansiz: $correctAnswer. Bu javob mavzu mazmuniga mos keladi.';
    }

    if (customExplanation.isNotEmpty) {
      return 'Sizning javobingiz: $selectedAnswer.\nTo‘g‘ri javob: $correctAnswer.\n$customExplanation';
    }
    return 'Sizning javobingiz: $selectedAnswer. To‘g‘ri javob: $correctAnswer. Shu savol bo‘yicha mavzudagi asosiy izohni qayta ko‘rib chiqing.';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final kindIcon = widget.question.isVideoQuestion
        ? Icons.videocam_rounded
        : widget.question.isImageQuestion
        ? Icons.image_rounded
        : Icons.article_rounded;
    final kindLabel = widget.question.isVideoQuestion
        ? 'Video savol'
        : widget.question.isImageQuestion
        ? 'Rasmli savol'
        : 'Matnli savol';
    final answerColor = _isCorrect
        ? AppColors.successGreen
        : AppColors.errorRed;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: .10),
          ),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: AppColors.studentPrimary.withValues(alpha: .10),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        kindIcon,
                        size: 16,
                        color: AppColors.studentPrimary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${widget.index + 1}-savol',
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            kindLabel,
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: .58),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: .42),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      _isCorrect
                          ? Icons.check_circle_rounded
                          : Icons.cancel_rounded,
                      color: answerColor,
                    ),
                  ],
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  child: !_expanded
                      ? const SizedBox.shrink()
                      : Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(top: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: .055)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: answerColor.withValues(alpha: .22),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isCorrect ? 'Nega to‘g‘ri?' : 'Nega xato?',
                                style: TextStyle(
                                  color: answerColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _explanationText(),
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: .72),
                                  fontSize: 13,
                                  height: 1.35,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FinalExamIntroScreen extends StatelessWidget {
  const _FinalExamIntroScreen({
    required this.module,
    required this.questionCount,
    required this.onBack,
    required this.onStart,
  });

  final AcademyModule? module;
  final int questionCount;
  final VoidCallback onBack;
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final borderCol = isDark
        ? const Color(0xFF1E293B)
        : const Color(0xFFE2E8F0);
    final cardBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final mutedTextColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MobileHeader(
          title: module == null
              ? _t(context, 'final_exam')
              : '${module!.order}-modul yakuniy testi',
          subtitle: 'Barcha mavzulardan yig‘ilgan aralash savollar',
          onBack: onBack,
        ),
        const SizedBox(height: 24),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderCol, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.amber.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.amber.withValues(alpha: 0.2),
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  color: AppColors.amber,
                  size: 54,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _t(context, 'final_exam'),
                style: TextStyle(
                  color: textColor,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Barcha mavzular savollaridan yakuniy test tuziladi. 70% va undan yuqori natija keyingi modulni ochadi.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: mutedTextColor,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),
              Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E293B).withValues(alpha: 0.3)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderCol),
                ),
                child: Column(
                  children: [
                    _ExamRule(
                      icon: Icons.help_rounded,
                      label: 'Savollar',
                      value: questionCount.toString(),
                    ),
                    Divider(height: 1, color: borderCol),
                    const _ExamRule(
                      icon: Icons.timer_rounded,
                      label: 'Vaqt limiti',
                      value: '45:00',
                    ),
                    Divider(height: 1, color: borderCol),
                    const _ExamRule(
                      icon: Icons.verified_rounded,
                      label: 'O‘tish bali',
                      value: '70%',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onStart,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF6C4DFF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded, size: 20),
                  label: Text(
                    _t(context, 'start_test'),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FinalExamScreen extends StatelessWidget {
  const _FinalExamScreen({
    required this.questions,
    required this.questionIndex,
    required this.selectedOption,
    required this.onSelected,
    required this.onNext,
    required this.onPrevious,
    required this.onBack,
  });

  final List<QuizQuestion> questions;
  final int questionIndex;
  final int selectedOption;
  final ValueChanged<int> onSelected;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final safeIndex = questionIndex.clamp(0, questions.length - 1).toInt();
    final question = questions[safeIndex];

    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final borderCol = isDark
        ? const Color(0xFF1E293B)
        : const Color(0xFFE2E8F0);
    final cardBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final mutedTextColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MobileHeader(
          title: _t(context, 'final_exam'),
          subtitle:
              '${_t(context, 'question')} ${safeIndex + 1} / ${questions.length}',
          onBack: onBack,
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF6C4DFF).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFF6C4DFF).withValues(alpha: 0.2),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.timer_rounded, color: Color(0xFF6C4DFF), size: 16),
                SizedBox(width: 6),
                Text(
                  '45:20',
                  style: TextStyle(
                    color: Color(0xFF6C4DFF),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderCol, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_t(context, 'question')} ${safeIndex + 1} / ${questions.length}',
                    style: TextStyle(
                      color: mutedTextColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    '${((safeIndex + 1) / questions.length * 100).toInt()}%',
                    style: const TextStyle(
                      color: Color(0xFF6C4DFF),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                height: 6,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: (safeIndex + 1) / questions.length,
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: const Color(0xFF6C4DFF),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              if (question.hasMedia) ...[
                _QuestionMediaBlock(question: question),
                const SizedBox(height: 24),
              ] else if (question.assetLabel != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E293B).withValues(alpha: 0.4)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderCol),
                  ),
                  child: Text(
                    question.assetLabel!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF6C4DFF),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
              Text(
                question.question,
                style: TextStyle(
                  color: textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),
              ...List.generate(
                question.options.length,
                (index) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _OptionTile(
                    label: String.fromCharCode(65 + index),
                    text: question.options[index],
                    selected: selectedOption == index,
                    onTap: () => onSelected(index),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onPrevious,
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark
                      ? Colors.white
                      : const Color(0xFF64748B),
                  side: BorderSide(color: borderCol, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.arrow_back_rounded, size: 20),
                label: Text(
                  _t(context, 'previous'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: FilledButton.icon(
                onPressed: onNext,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF6C4DFF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.fact_check_rounded, size: 20),
                label: Text(
                  safeIndex < questions.length - 1
                      ? _t(context, 'next')
                      : _t(context, 'see_result'),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

class _PremiumPaywallScreen extends StatelessWidget {
  const _PremiumPaywallScreen({
    required this.module,
    required this.topic,
    required this.onBack,
    required this.onContactAdmin,
  });

  final AcademyModule? module;
  final TopicLesson? topic;
  final VoidCallback onBack;
  final Future<void> Function() onContactAdmin;

  @override
  Widget build(BuildContext context) {
    final moduleTitle = module?.title ?? 'Premium kurs';
    final price = module?.subscriptionPriceLabel.trim().isNotEmpty == true
        ? module!.subscriptionPriceLabel
        : 'Admin belgilagan tarif';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MobileHeader(
          title: 'Premium kontent',
          subtitle: topic?.title ?? moduleTitle,
          onBack: onBack,
        ),
        const SizedBox(height: 24),
        _GlassCard(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2A106B), Color(0xFF0B1220)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.lock_rounded, color: Colors.white, size: 48),
              const SizedBox(height: 16),
              const Text(
                'Kursning qolgan qismi obuna orqali ochiladi',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '$moduleTitle uchun birinchi dars bepul. Davom etish uchun obuna rejasini tanlang.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .78),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _PlanChip(title: '1 oy', price: price),
                  _PlanChip(title: '3 oy', price: price),
                  _PlanChip(title: '12 oy', price: price),
                ],
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: () => unawaited(onContactAdmin()),
                icon: const Icon(Icons.workspace_premium_rounded),
                label: const Text('Obuna bo‘lish'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PlanChip extends StatelessWidget {
  const _PlanChip({required this.title, required this.price});

  final String title;
  final String price;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: .18)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            price,
            style: TextStyle(
              color: Colors.white.withValues(alpha: .75),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _FinalResultScreen extends StatelessWidget {
  const _FinalResultScreen({
    required this.passed,
    required this.score,
    required this.onBackToTopics,
    required this.onRetake,
    required this.onNextModule,
  });

  final bool passed;
  final int score;
  final VoidCallback onBackToTopics;
  final VoidCallback onRetake;
  final VoidCallback onNextModule;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = passed ? AppColors.successGreen : AppColors.errorRed;
    final scoreValue = score / 100;

    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final borderCol = isDark
        ? const Color(0xFF1E293B)
        : const Color(0xFFE2E8F0);
    final cardBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final mutedTextColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MobileHeader(
          title: passed ? _t(context, 'passed') : _t(context, 'failed'),
          subtitle: passed
              ? _t(context, 'next_module')
              : _t(context, 'review_retake'),
        ),
        const SizedBox(height: 24),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderCol, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: color.withValues(alpha: 0.2),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      passed ? Icons.lock_open_rounded : Icons.lock_rounded,
                      color: color,
                      size: 38,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          passed
                              ? _t(context, 'passed')
                              : _t(context, 'failed'),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          passed
                              ? 'Siz modul yakuniy testidan o‘tdingiz.'
                              : '70% yoki undan yuqori ball talab qilinadi.',
                          style: TextStyle(color: mutedTextColor, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              CircularScore(
                value: scoreValue,
                label: '$score%',
                color: color,
                size: 120,
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E293B).withValues(alpha: 0.3)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderCol),
                ),
                child: _ResultChecklist(
                  color: color,
                  items: [
                    'O‘tish balli: 70%',
                    'Sizning ballingiz: $score%',
                    passed ? 'Natija: O‘tdingiz' : 'Natija: O‘ta olmadingiz',
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: passed ? onNextModule : onRetake,
                  style: FilledButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: Icon(
                    passed
                        ? Icons.lock_open_rounded
                        : Icons.restart_alt_rounded,
                    size: 20,
                  ),
                  label: Text(
                    passed
                        ? _t(context, 'go_module_2')
                        : _t(context, 'restudy'),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onBackToTopics,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark
                        ? Colors.white
                        : const Color(0xFF64748B),
                    side: BorderSide(color: borderCol, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.list_alt_rounded, size: 20),
                  label: Text(
                    _t(context, 'back_topics'),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ResultChecklist extends StatelessWidget {
  const _ResultChecklist({required this.items, required this.color});

  final List<String> items;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: color, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _CommunityScreen extends StatelessWidget {
  const _CommunityScreen({
    required this.data,
    required this.onAskAdmin,
    required this.onRefresh,
    required this.notificationCount,
    required this.onNotifications,
  });

  final StudentDashboardData data;
  final Future<void> Function() onAskAdmin;
  final Future<void> Function() onRefresh;
  final int notificationCount;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) {
    final activeModules = data.modules.where((module) => module.isUnlocked);
    final topicCount = data.modules.fold<int>(
      0,
      (sum, module) => sum + module.topics.length,
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MobileHeader(
          title: 'Community',
          subtitle: 'Savol-javob, guruhlar va mentorlar bilan aloqa',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Yangilash',
                onPressed: () => unawaited(onRefresh()),
                icon: const Icon(Icons.refresh_rounded),
                style: IconButton.styleFrom(
                  fixedSize: const Size.square(52),
                  padding: EdgeInsets.zero,
                  backgroundColor: isDark
                      ? Colors.white.withValues(alpha: .06)
                      : Colors.black.withValues(alpha: .04),
                  foregroundColor: isDark
                      ? Colors.white
                      : const Color(0xFF0F172A),
                  shape: const CircleBorder(),
                ),
              ),
              const SizedBox(width: 16),
              Badge.count(
                isLabelVisible: notificationCount > 0,
                count: notificationCount,
                child: IconButton(
                  onPressed: onNotifications,
                  style: IconButton.styleFrom(
                    fixedSize: const Size.square(52),
                    padding: EdgeInsets.zero,
                    backgroundColor: isDark
                        ? Colors.white.withValues(alpha: .06)
                        : Colors.black.withValues(alpha: .04),
                    shape: const CircleBorder(),
                  ),
                  icon: Icon(
                    Icons.notifications_none_rounded,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    size: 28,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _GlassCard(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2610A4), Color(0xFF0B1628)],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Birga o‘rganamiz',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Laboratoriya mavzulari bo‘yicha savol bering, admin javoblari va muhokamalar shu yerda jamlanadi.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .72),
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => unawaited(onAskAdmin()),
                      icon: const Icon(Icons.edit_rounded),
                      label: const Text('Savol yuborish'),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.groups_3_rounded, color: Colors.white, size: 76),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _PremiumStatCard(
                icon: Icons.group_rounded,
                title: 'Faol guruhlar',
                value: '${math.max(1, activeModules.length)}',
                color: AppColors.studentPrimary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _PremiumStatCard(
                icon: Icons.question_answer_rounded,
                title: 'Mavzular',
                value: '$topicCount',
                color: AppColors.studentPink,
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        const _SectionTitle(title: 'Trend muhokamalar'),
        const SizedBox(height: 12),
        _CommunityPostCard(
          avatar: 'DS',
          name: 'Dr. Sarah Johnson',
          badge: 'Mentor',
          title:
              'Gemoglobin vazifasini klinik misolda tushuntirib bera olasizmi?',
          tag: 'Hematology',
          likes: 24,
          comments: 12,
          color: AppColors.errorRed,
        ),
        const SizedBox(height: 12),
        _CommunityPostCard(
          avatar: data.profile.initials,
          name: data.profile.fullName,
          badge: 'Student',
          title:
              'Mikroskopiya darsida olingan eslatmalarimni guruh bilan ulashmoqchiman.',
          tag: 'Microscopy',
          likes: 18,
          comments: 6,
          color: AppColors.studentBlue,
        ),
        const SizedBox(height: 22),
        _SectionTitle(
          title: 'Study groups',
          actionLabel: 'Admin bilan bog‘lanish',
          onAction: () => unawaited(onAskAdmin()),
        ),
        const SizedBox(height: 12),
        ...data.modules
            .take(3)
            .map(
              (module) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _GlassCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: AppColors.studentPrimary.withValues(
                            alpha: .18,
                          ),
                        ),
                        child: const Icon(
                          Icons.biotech_rounded,
                          color: AppColors.studentPrimary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${module.title} guruhi',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${module.studentCount} ishtirokchi • Active',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => unawaited(onAskAdmin()),
                        child: const Text('Join'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
      ],
    );
  }
}

class _CommunityPostCard extends StatelessWidget {
  const _CommunityPostCard({
    required this.avatar,
    required this.name,
    required this.badge,
    required this.title,
    required this.tag,
    required this.likes,
    required this.comments,
    required this.color,
  });

  final String avatar;
  final String name;
  final String badge;
  final String title;
  final String tag;
  final int likes;
  final int comments;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: .2),
                foregroundColor: color,
                child: Text(
                  avatar.characters.take(2).toString(),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(badge, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              Icon(
                Icons.more_vert_rounded,
                color: Colors.white.withValues(alpha: .6),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              StatusChip(label: tag, color: color),
              const Spacer(),
              Icon(
                Icons.thumb_up_alt_outlined,
                size: 18,
                color: Colors.white.withValues(alpha: .7),
              ),
              const SizedBox(width: 5),
              Text('$likes', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(width: 14),
              Icon(
                Icons.chat_bubble_outline_rounded,
                size: 18,
                color: Colors.white.withValues(alpha: .7),
              ),
              const SizedBox(width: 5),
              Text('$comments', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProgressScreen extends StatelessWidget {
  const _ProgressScreen({
    required this.data,
    required this.onRefresh,
    required this.notificationCount,
    required this.onNotifications,
  });

  final StudentDashboardData data;
  final Future<void> Function() onRefresh;
  final int notificationCount;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) {
    final overallPercent = (data.overallProgress * 100).round();
    final totalTopics = data.modules.fold<int>(
      0,
      (sum, module) => sum + module.topics.length,
    );
    final completedTopics = data.modules.fold<int>(
      0,
      (sum, module) =>
          sum +
          module.topics
              .where((topic) => topic.status == TopicStatus.completed)
              .length,
    );
    final passedModules = data.modules
        .where((module) => module.isPassed)
        .length;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor = dark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final cardColor = Theme.of(context).cardColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MobileHeader(
          title: _t(context, 'progress'),
          subtitle: 'Modul progressi, yutuqlar va sertifikatlar markazi',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Badge.count(
                isLabelVisible: notificationCount > 0,
                count: notificationCount,
                child: _ProgressCircleAction(
                  tooltip: 'Bildirishnomalar',
                  onPressed: onNotifications,
                  icon: const Icon(Icons.notifications_none_rounded),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: AppColors.studentPrimary.withValues(alpha: 0.12),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.studentPrimary.withValues(alpha: 0.08),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircularScore(
                    value: data.overallProgress,
                    label:
                        '${data.completedModules}/${data.modules.length} modul',
                    size: 112,
                    color: AppColors.studentPrimary,
                  ),
                  const SizedBox(width: 22),
                  Expanded(
                    child: Column(
                      children: [
                        _ProgressMetricRow(
                          icon: Icons.trending_up_rounded,
                          label: 'Umumiy',
                          value: '$overallPercent%',
                          color: AppColors.studentPrimary,
                        ),
                        const SizedBox(height: 10),
                        _ProgressMetricRow(
                          icon: Icons.menu_book_rounded,
                          label: 'Mavzular',
                          value: '$completedTopics/$totalTopics',
                          color: AppColors.studentBlue,
                        ),
                        const SizedBox(height: 10),
                        _ProgressMetricRow(
                          icon: Icons.workspace_premium_rounded,
                          label: 'Sertifikat',
                          value: data.certificateCount.toString(),
                          color: AppColors.amber,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: _ProgressCompactTile(
                      icon: Icons.school_rounded,
                      label: 'Faol',
                      value: data.activeModuleCount.toString(),
                      color: AppColors.studentPrimary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ProgressCompactTile(
                      icon: Icons.check_circle_rounded,
                      label: 'Yopildi',
                      value: passedModules.toString(),
                      color: AppColors.successGreen,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ProgressCompactTile(
                      icon: Icons.emoji_events_rounded,
                      label: 'Yutuq',
                      value: data.completedModules.toString(),
                      color: AppColors.amber,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        if (data.modules.isEmpty)
          _EmptyStateCard(
            icon: Icons.track_changes_outlined,
            title: 'Progress hali yo‘q',
            message:
                'Modullar biriktirilib o‘qish boshlanganidan keyin, bu yerda real o‘sish va yutuqlar ko‘rinadi.',
            actionLabel: 'Yangilash',
            onAction: () => unawaited(onRefresh()),
          )
        else ...[
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Modullar',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              Text(
                '${data.modules.length} ta',
                style: TextStyle(
                  color: mutedColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...data.modules.map(
            (module) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: module.isPassed
                        ? AppColors.successGreen.withValues(alpha: 0.2)
                        : AppColors.studentPrimary.withValues(alpha: 0.1),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: dark ? .18 : .04),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            color: module.isPassed
                                ? AppColors.successGreen.withValues(alpha: 0.1)
                                : AppColors.studentPrimary.withValues(
                                    alpha: 0.1,
                                  ),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            module.isPassed
                                ? Icons.check_circle_rounded
                                : Icons.timelapse_rounded,
                            color: module.isPassed
                                ? AppColors.successGreen
                                : AppColors.studentPrimary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${module.order}-modul',
                                style: TextStyle(
                                  color: mutedColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                module.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  height: 1.15,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color:
                                (module.isPassed
                                        ? AppColors.successGreen
                                        : AppColors.studentPrimary)
                                    .withValues(alpha: .10),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${(module.progress * 100).round()}%',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: module.isPassed
                                  ? AppColors.successGreen
                                  : AppColors.studentPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    ProgressLine(
                      value: module.progress,
                      color: module.isPassed
                          ? AppColors.successGreen
                          : AppColors.studentPrimary,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _ProgressPill(
                          icon: Icons.task_alt_rounded,
                          label:
                              '${module.topics.where((topic) => topic.status == TopicStatus.completed).length}/${module.topics.length} mavzu',
                          color: AppColors.studentPrimary,
                        ),
                        const SizedBox(width: 8),
                        _ProgressPill(
                          icon: module.isPassed
                              ? Icons.verified_rounded
                              : Icons.lock_clock_rounded,
                          label: module.isPassed
                              ? 'Yakunlandi'
                              : 'Davom etmoqda',
                          color: module.isPassed
                              ? AppColors.successGreen
                              : AppColors.amber,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _PremiumStatCard(
                icon: Icons.workspace_premium_rounded,
                title: _t(context, 'certificate'),
                value: '${data.certificateCount} ta tayyor',
                color: AppColors.amber,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _PremiumStatCard(
                icon: Icons.military_tech_rounded,
                title: _t(context, 'achievements'),
                value: '${data.completedModules} ta yopildi',
                color: AppColors.successGreen,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ProgressCircleAction extends StatelessWidget {
  const _ProgressCircleAction({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
  });

  final Widget icon;
  final VoidCallback onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Tooltip(
      message: tooltip,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: dark
              ? Colors.white.withValues(alpha: .08)
              : AppColors.studentPrimary.withValues(alpha: .10),
          shape: BoxShape.circle,
        ),
        child: SizedBox.square(
          dimension: 52,
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onPressed,
              child: IconTheme(
                data: IconThemeData(
                  color: dark ? Colors.white : const Color(0xFF0F172A),
                  size: 28,
                ),
                child: Center(child: icon),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressMetricRow extends StatelessWidget {
  const _ProgressMetricRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = dark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: muted,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: dark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }
}

class _ProgressCompactTile extends StatelessWidget {
  const _ProgressCompactTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: dark
            ? Colors.white.withValues(alpha: .04)
            : color.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: .14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              color: dark ? Colors.white : const Color(0xFF0F172A),
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: dark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressPill extends StatelessWidget {
  const _ProgressPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .09),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 15),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileScreen extends StatelessWidget {
  const _ProfileScreen({
    required this.profile,
    required this.data,
    required this.themeMode,
    required this.language,
    required this.notificationsEnabled,
    required this.onLanguageChanged,
    required this.onThemeChanged,
    required this.onNotificationsChanged,
    required this.onEditProfile,
    required this.onContactAdmin,
    required this.onCheckForUpdate,
    required this.onSignOut,
    required this.appVersionName,
    required this.notificationCount,
    required this.onNotifications,
  });

  final StudentProfile profile;
  final StudentDashboardData data;
  final ThemeMode themeMode;
  final AppLanguage language;
  final bool notificationsEnabled;
  final ValueChanged<AppLanguage> onLanguageChanged;
  final ValueChanged<ThemeMode> onThemeChanged;
  final ValueChanged<bool> onNotificationsChanged;
  final Future<void> Function() onEditProfile;
  final Future<void> Function() onContactAdmin;
  final Future<void> Function() onCheckForUpdate;
  final VoidCallback onSignOut;
  final String appVersionName;
  final int notificationCount;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) {
    final isDark = themeMode == ThemeMode.dark;
    final profileText = isDark ? Colors.white : const Color(0xFF0F172A);
    final profileMuted = isDark
        ? const Color(0xFF9CA3AF)
        : const Color(0xFF64748B);
    final profileGradient = isDark
        ? const [Color(0xFF020A17), Color(0xFF071426), Color(0xFF0B1322)]
        : const [Colors.white, Color(0xFFF8FAFC), Color(0xFFF1F5F9)];
    final profileBorder = isDark
        ? Colors.white.withValues(alpha: .06)
        : const Color(0xFFE2E8F0);
    final profileShadow = isDark
        ? const Color(0xFF020617).withValues(alpha: .22)
        : AppColors.studentPrimary.withValues(alpha: .07);
    final profileCode = _profileDisplayCode(profile);
    final activeCourses = data.modules
        .where((module) => module.isUnlocked)
        .length;
    final totalXp =
        data.completedModules * 500 +
        data.averageScore * 25 +
        data.certificateCount * 1000;
    final level = math.max(1, data.completedModules + data.averageScore ~/ 20);
    String pt(String key) => _profileText(language, key);

    Future<void> openSecurity() {
      return showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => _ProfileSecuritySheet(language: language),
      );
    }

    Future<void> openBilling() {
      return showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => _ProfileBillingSheet(
          data: data,
          language: language,
          onContactAdmin: onContactAdmin,
        ),
      );
    }

    Future<void> openAbout() {
      return showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => _ProfileAboutSheet(
          language: language,
          appVersionName: appVersionName,
          onCheckForUpdate: onCheckForUpdate,
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(6, 14, 6, 126),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: profileGradient,
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: profileBorder),
            boxShadow: [
              BoxShadow(
                color: profileShadow,
                blurRadius: 30,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 44,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Center(
                      child: Text(
                        pt('profile_title'),
                        style: TextStyle(
                          color: profileText,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -.2,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      child: Badge.count(
                        isLabelVisible: notificationCount > 0,
                        count: notificationCount,
                        child: _ProfileCircleButton(
                          icon: Icons.notifications_none_rounded,
                          tooltip: _t(context, 'notifications'),
                          onTap: onNotifications,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _ProfileHeroCard(
                profile: profile,
                studentCode: profileCode,
                activeCourses: activeCourses,
                totalXp: totalXp,
                level: level,
                onEditProfile: onEditProfile,
              ),
              const SizedBox(height: 18),
              _ProfileSectionTitle(pt('account_settings')),
              const SizedBox(height: 10),
              _ProfileSettingsGridCard(
                items: [
                  _ProfileSettingsAction(
                    icon: Icons.person_outline_rounded,
                    title: pt('personal_info'),
                    subtitle: pt('personal_info_subtitle'),
                    onTap: () => unawaited(onEditProfile()),
                  ),
                  _ProfileSettingsAction(
                    icon: Icons.language_rounded,
                    title: studentText(language, 'language'),
                    subtitle: pt('language_subtitle'),
                    trailing: _ProfileInlineValue(value: language.label),
                    onTap: () async {
                      final picked = await _showSelectionSheet<AppLanguage>(
                        context,
                        title: _t(context, 'language'),
                        items: AppLanguage.values,
                        initialValue: language,
                        labelBuilder: (item) => item.label,
                        subtitleBuilder: (item) =>
                            languageOptionDescription(language, item),
                      );
                      if (picked != null) onLanguageChanged(picked);
                    },
                  ),
                  _ProfileSettingsAction(
                    icon: Icons.lock_outline_rounded,
                    title: pt('security'),
                    subtitle: pt('security_subtitle'),
                    onTap: () => unawaited(openSecurity()),
                  ),
                  _ProfileSettingsAction(
                    icon: isDark
                        ? Icons.dark_mode_rounded
                        : Icons.light_mode_rounded,
                    title: studentText(language, 'dark_mode'),
                    subtitle: pt('dark_mode_subtitle'),
                    trailing: Switch.adaptive(
                      value: isDark,
                      onChanged: (value) => onThemeChanged(
                        value ? ThemeMode.dark : ThemeMode.light,
                      ),
                      activeThumbColor: AppColors.studentPrimary,
                      activeTrackColor: AppColors.studentPrimary.withValues(
                        alpha: .35,
                      ),
                    ),
                  ),
                  _ProfileSettingsAction(
                    icon: Icons.credit_card_rounded,
                    title: pt('billing'),
                    subtitle: pt('billing_subtitle'),
                    onTap: () => unawaited(openBilling()),
                  ),
                  _ProfileSettingsAction(
                    icon: Icons.support_agent_rounded,
                    title: pt('support'),
                    subtitle: pt('support_subtitle'),
                    onTap: () => unawaited(onContactAdmin()),
                  ),
                  _ProfileSettingsAction(
                    icon: Icons.notifications_none_rounded,
                    title: studentText(language, 'notifications'),
                    subtitle: pt('notifications_subtitle'),
                    trailing: Switch.adaptive(
                      value: notificationsEnabled,
                      onChanged: onNotificationsChanged,
                      activeThumbColor: AppColors.studentPrimary,
                      activeTrackColor: AppColors.studentPrimary.withValues(
                        alpha: .35,
                      ),
                    ),
                  ),
                  _ProfileSettingsAction(
                    icon: Icons.info_outline_rounded,
                    title: pt('about'),
                    subtitle:
                        '${studentText(language, 'version_label')} v$appVersionName',
                    onTap: () => unawaited(openAbout()),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: onSignOut,
                  style: TextButton.styleFrom(
                    backgroundColor: isDark
                        ? const Color(0xFF0D1B2D)
                        : const Color(0xFFFFF1F2),
                    foregroundColor: const Color(0xFFFF5F57),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: isDark
                            ? Colors.white.withValues(alpha: .05)
                            : AppColors.errorRed.withValues(alpha: .12),
                      ),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  child: Text(_t(context, 'logout')),
                ),
              ),
              const SizedBox(height: 14),
              Center(
                child: Text(
                  '${_t(context, 'version_label')} v$appVersionName',
                  style: TextStyle(
                    color: profileMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _profileText(AppLanguage language, String key) {
  const uz = {
    'profile_title': 'Talaba profili',
    'account_settings': 'Hisob va sozlamalar',
    'personal_info': 'Shaxsiy ma’lumotlar',
    'personal_info_subtitle': 'Profil va shaxsiy ma’lumotlarni boshqarish',
    'language_subtitle': 'Ilova tili va mintaqa',
    'security': 'Xavfsizlik',
    'security_subtitle': 'Parol va xavfsizlik sozlamalari',
    'dark_mode_subtitle': 'Ilova ko‘rinishini almashtirish',
    'billing': 'To‘lovlar va obuna',
    'billing_subtitle': 'Obuna holati va to‘lov tarixi',
    'support': 'Yordam va qo‘llab-quvvatlash',
    'support_subtitle': 'Yordam markazi va aloqa',
    'notifications_subtitle': 'Bildirishnoma sozlamalari',
    'about': 'Ilova haqida',
    'security_title': 'Xavfsizlik',
    'pin_title': '4 xonali parol',
    'pin_subtitle': 'Ilovaga kirishda PIN so‘ralsin',
    'pin_hint': '4 ta raqam kiriting',
    'pin_save': 'PIN saqlash',
    'pin_saved': '4 xonali parol saqlandi.',
    'biometric_title': 'Biometrik qulf',
    'biometric_subtitle': 'Qurilma biometrik himoyasidan foydalanish',
    'biometric_note':
        'APK qurilmada barmoq izi yoki Face ID mavjud bo‘lsa, keyingi bosqichda shu sozlama orqali tekshiruv yoqiladi.',
    'billing_title': 'To‘lovlar va obuna',
    'active_subscription': 'Faol obuna',
    'available_plans': 'Mavjud tariflar',
    'payment_history': 'To‘lov tarixi',
    'no_subscription': 'Faol obuna topilmadi.',
    'no_payments': 'To‘lov tarixi hali yo‘q.',
    'manage_with_admin': 'To‘lovni boshqarish',
    'about_goal': 'Maqsad',
    'about_goal_text':
        'LabProof Academy laboratoriya sohasi bo‘yicha darslar, testlar, progress va sertifikatlarni bitta mobil ilovada jamlaydi.',
    'about_how': 'Qanday ishlaydi',
    'about_how_text':
        'Student modullarni ketma-ket o‘rganadi, matn/video darslarni tugatadi, test topshiradi va natijasi profil hamda progress bo‘limida saqlanadi.',
    'terms': 'Foydalanish shartlari',
    'terms_text':
        'Akkauntdan faqat egasi foydalanadi. O‘quv materiallarini ruxsatsiz tarqatish va tizimdan noto‘g‘ri foydalanish taqiqlanadi.',
    'privacy': 'Maxfiylik siyosati',
    'privacy_text':
        'Telefon raqam, profil ma’lumotlari, progress va to‘lov holati faqat ta’lim jarayonini yuritish va xavfsizlik uchun ishlatiladi.',
    'payment_policy': 'To‘lov siyosati',
    'payment_policy_text':
        'Pullik modullar va obunalar admin panelda belgilangan tariflar asosida ochiladi. To‘lov holati tasdiqlangandan so‘ng kontentga ruxsat beriladi.',
    'check_update': 'Yangilanishni tekshirish',
  };
  const ru = {
    'profile_title': 'Профиль студента',
    'account_settings': 'Аккаунт и настройки',
    'personal_info': 'Личные данные',
    'personal_info_subtitle': 'Управление профилем и личными данными',
    'language_subtitle': 'Язык приложения и регион',
    'security': 'Безопасность',
    'security_subtitle': 'Пароль и настройки безопасности',
    'dark_mode_subtitle': 'Изменение внешнего вида приложения',
    'billing': 'Платежи и подписка',
    'billing_subtitle': 'Статус подписки и история платежей',
    'support': 'Помощь и поддержка',
    'support_subtitle': 'Центр помощи и связь',
    'notifications_subtitle': 'Настройки уведомлений',
    'about': 'О приложении',
    'security_title': 'Безопасность',
    'pin_title': '4-значный пароль',
    'pin_subtitle': 'Запрашивать PIN при входе в приложение',
    'pin_hint': 'Введите 4 цифры',
    'pin_save': 'Сохранить PIN',
    'pin_saved': '4-значный пароль сохранён.',
    'biometric_title': 'Биометрическая блокировка',
    'biometric_subtitle': 'Использовать защиту устройства',
    'biometric_note':
        'В APK при наличии отпечатка или Face ID эта настройка будет включать проверку.',
    'billing_title': 'Платежи и подписка',
    'active_subscription': 'Активная подписка',
    'available_plans': 'Доступные тарифы',
    'payment_history': 'История платежей',
    'no_subscription': 'Активная подписка не найдена.',
    'no_payments': 'Истории платежей пока нет.',
    'manage_with_admin': 'Управлять оплатой',
    'about_goal': 'Цель',
    'about_goal_text':
        'LabProof Academy объединяет уроки, тесты, прогресс и сертификаты по лабораторному направлению в одном мобильном приложении.',
    'about_how': 'Как работает',
    'about_how_text':
        'Студент проходит модули по порядку, завершает текстовые и видеоуроки, сдаёт тесты, а результат сохраняется в профиле и прогрессе.',
    'terms': 'Условия использования',
    'terms_text':
        'Аккаунтом пользуется только владелец. Запрещено распространять учебные материалы без разрешения и злоупотреблять системой.',
    'privacy': 'Политика конфиденциальности',
    'privacy_text':
        'Телефон, профиль, прогресс и платежный статус используются только для обучения и безопасности.',
    'payment_policy': 'Политика оплаты',
    'payment_policy_text':
        'Платные модули и подписки открываются по тарифам из админ-панели. Доступ предоставляется после подтверждения оплаты.',
    'check_update': 'Проверить обновление',
  };
  const cyr = {
    'profile_title': 'Талаба профили',
    'account_settings': 'Ҳисоб ва созламалар',
    'personal_info': 'Шахсий маълумотлар',
    'personal_info_subtitle': 'Профил ва шахсий маълумотларни бошқариш',
    'language_subtitle': 'Илова тили ва минтақа',
    'security': 'Хавфсизлик',
    'security_subtitle': 'Парол ва хавфсизлик созламалари',
    'dark_mode_subtitle': 'Илова кўринишини алмаштириш',
    'billing': 'Тўловлар ва обуна',
    'billing_subtitle': 'Обуна ҳолати ва тўлов тарихи',
    'support': 'Ёрдам ва қўллаб-қувватлаш',
    'support_subtitle': 'Ёрдам маркази ва алоқа',
    'notifications_subtitle': 'Билдиришнома созламалари',
    'about': 'Илова ҳақида',
    'security_title': 'Хавфсизлик',
    'pin_title': '4 хонали парол',
    'pin_subtitle': 'Иловага киришда PIN сўралсин',
    'pin_hint': '4 та рақам киритинг',
    'pin_save': 'PIN сақлаш',
    'pin_saved': '4 хонали парол сақланди.',
    'biometric_title': 'Биометрик қулф',
    'biometric_subtitle': 'Қурилма биометрик ҳимоясидан фойдаланиш',
    'biometric_note':
        'APK қурилмада бармоқ изи ёки Face ID мавжуд бўлса, кейинги босқичда шу созлама орқали текширув ёқилади.',
    'billing_title': 'Тўловлар ва обуна',
    'active_subscription': 'Фаол обуна',
    'available_plans': 'Мавжуд тарифлар',
    'payment_history': 'Тўлов тарихи',
    'no_subscription': 'Фаол обуна топилмади.',
    'no_payments': 'Тўлов тарихи ҳали йўқ.',
    'manage_with_admin': 'Тўловни бошқариш',
    'about_goal': 'Мақсад',
    'about_goal_text':
        'LabProof Academy лаборатория соҳаси бўйича дарслар, тестлар, progress ва сертификатларни битта мобил иловада жамлайди.',
    'about_how': 'Қандай ишлайди',
    'about_how_text':
        'Талаба модулларни кетма-кет ўрганади, матн/видео дарсларни тугатади, тест топширади ва натижаси профил ҳамда progress бўлимида сақланади.',
    'terms': 'Фойдаланиш шартлари',
    'terms_text':
        'Аккаунтдан фақат эгаси фойдаланади. Ўқув материалларини рухсатсиз тарқатиш ва тизимдан нотўғри фойдаланиш тақиқланади.',
    'privacy': 'Махфийлик сиёсати',
    'privacy_text':
        'Телефон рақам, профил маълумотлари, progress ва тўлов ҳолати фақат таълим жараёнини юритиш ва хавфсизлик учун ишлатилади.',
    'payment_policy': 'Тўлов сиёсати',
    'payment_policy_text':
        'Пуллик модуллар ва обуналар admin panelда белгиланган тарифлар асосида очилади. Тўлов ҳолати тасдиқлангандан сўнг контентга рухсат берилади.',
    'check_update': 'Янгиланишни текшириш',
  };
  return switch (language) {
    AppLanguage.ru => ru[key] ?? uz[key] ?? key,
    AppLanguage.uzCyrillic => cyr[key] ?? uz[key] ?? key,
    AppLanguage.uzLatin => uz[key] ?? key,
  };
}

class _ProfileSecuritySheet extends StatefulWidget {
  const _ProfileSecuritySheet({required this.language});

  final AppLanguage language;

  @override
  State<_ProfileSecuritySheet> createState() => _ProfileSecuritySheetState();
}

class _ProfileSecuritySheetState extends State<_ProfileSecuritySheet> {
  static const _pinKey = 'student_security_pin';
  static const _biometricKey = 'student_biometric_lock';

  final _pinController = TextEditingController();
  bool _pinEnabled = false;
  bool _biometricEnabled = false;
  bool _loading = true;
  bool _saving = false;

  String t(String key) => _profileText(widget.language, key);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final savedPin = prefs.getString(_pinKey) ?? '';
    setState(() {
      _pinController.text = savedPin;
      _pinEnabled = savedPin.isNotEmpty;
      _biometricEnabled = prefs.getBool(_biometricKey) ?? false;
      _loading = false;
    });
  }

  Future<void> _savePin() async {
    final pin = _pinController.text.trim();
    if (!RegExp(r'^\d{4}$').hasMatch(pin)) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('PIN 4 ta raqamdan iborat bo‘lishi kerak.'),
          backgroundColor: AppColors.errorRed,
        ),
      );
      return;
    }
    setState(() => _saving = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pinKey, pin);
    if (!mounted) return;
    setState(() {
      _pinEnabled = true;
      _saving = false;
    });
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(t('pin_saved'))));
  }

  Future<void> _removePin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pinKey);
    await prefs.setBool(_biometricKey, false);
    if (!mounted) return;
    setState(() {
      _pinController.clear();
      _pinEnabled = false;
      _biometricEnabled = false;
    });
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(content: Text('PIN va biometrik qulf o‘chirildi.')),
    );
  }

  Future<void> _setBiometric(bool value) async {
    if (value && !_pinEnabled) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('Avval 4 xonali PIN saqlang.'),
          backgroundColor: AppColors.errorRed,
        ),
      );
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricKey, value);
    if (mounted) setState(() => _biometricEnabled = value);
  }

  @override
  Widget build(BuildContext context) {
    return _ProfileModalScaffold(
      title: t('security_title'),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _ProfileStatusCard(
                        icon: Icons.pin_rounded,
                        title: 'PIN',
                        value: _pinEnabled ? 'Yoqilgan' : 'O‘chiq',
                        color: _pinEnabled
                            ? const Color(0xFF22C55E)
                            : AppColors.studentPrimary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ProfileStatusCard(
                        icon: Icons.fingerprint_rounded,
                        title: 'Biometrik',
                        value: _biometricEnabled ? 'Faol' : 'O‘chiq',
                        color: _biometricEnabled
                            ? const Color(0xFF22C55E)
                            : const Color(0xFFF59E0B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _ProfileSectionPanel(
                  icon: Icons.password_rounded,
                  title: t('pin_title'),
                  subtitle: t('pin_subtitle'),
                  child: Column(
                    children: [
                      TextField(
                        controller: _pinController,
                        keyboardType: TextInputType.number,
                        obscureText: true,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(4),
                        ],
                        decoration: InputDecoration(
                          labelText: t('pin_hint'),
                          prefixIcon: const Icon(Icons.pin_rounded),
                          suffixIcon: _pinEnabled
                              ? const Icon(
                                  Icons.verified_rounded,
                                  color: Color(0xFF22C55E),
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _saving ? null : _savePin,
                              icon: Icon(
                                _saving
                                    ? Icons.hourglass_top_rounded
                                    : Icons.lock_rounded,
                              ),
                              label: Text(t('pin_save')),
                            ),
                          ),
                          if (_pinEnabled) ...[
                            const SizedBox(width: 10),
                            IconButton.filledTonal(
                              tooltip: 'PINni o‘chirish',
                              onPressed: _removePin,
                              icon: const Icon(Icons.delete_outline_rounded),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _ProfileToggleRow(
                  icon: Icons.fingerprint_rounded,
                  title: t('biometric_title'),
                  subtitle: t('biometric_subtitle'),
                  value: _biometricEnabled,
                  onChanged: _setBiometric,
                ),
                const SizedBox(height: 12),
                _ProfileNoticeBox(
                  icon: Icons.info_outline_rounded,
                  text: t('biometric_note'),
                ),
              ],
            ),
    );
  }
}

class _ProfileBillingSheet extends StatefulWidget {
  const _ProfileBillingSheet({
    required this.data,
    required this.language,
    required this.onContactAdmin,
  });

  final StudentDashboardData data;
  final AppLanguage language;
  final Future<void> Function() onContactAdmin;

  @override
  State<_ProfileBillingSheet> createState() => _ProfileBillingSheetState();
}

class _ProfileBillingSheetState extends State<_ProfileBillingSheet> {
  static const _repository = SupabaseAcademyRepository();
  Map<String, List<Map<String, dynamic>>>? _billing;
  Object? _error;

  String t(String key) => _profileText(widget.language, key);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _billing = null;
      _error = null;
    });
    try {
      final data = await _repository.loadStudentBilling();
      if (mounted) setState(() => _billing = data);
    } on Object catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  Future<void> _openSupport() async {
    Navigator.of(context).pop();
    await widget.onContactAdmin();
  }

  String _subscriptionTitle(Map<String, dynamic> row) {
    final plan = row['subscription_plans'];
    if (plan is Map && (plan['title'] ?? '').toString().trim().isNotEmpty) {
      return plan['title'].toString();
    }
    return (row['plan_key'] ?? 'Premium').toString();
  }

  String _money(Map<String, dynamic> row) {
    final amount = row['amount'];
    final currency = (row['currency'] ?? 'UZS').toString();
    if (amount == null) return '';
    return '$amount $currency';
  }

  DateTime? _dateValue(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final raw = row[key];
      if (raw == null) continue;
      if (raw is DateTime) return raw;
      final parsed = DateTime.tryParse(raw.toString());
      if (parsed != null) return parsed.toLocal();
    }
    return null;
  }

  String _formatBillingDate(DateTime? value) {
    if (value == null) return '--.--.----';
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day.$month.${value.year}';
  }

  int? _daysLeft(DateTime? endDate) {
    if (endDate == null) return null;
    final now = DateTime.now();
    return math.max(0, endDate.difference(now).inDays + 1);
  }

  Map<String, dynamic>? _activeSubscription(
    List<Map<String, dynamic>> subscriptions,
  ) {
    for (final row in subscriptions) {
      if ((row['status'] ?? '').toString().toLowerCase() == 'active') {
        return row;
      }
    }
    return subscriptions.isEmpty ? null : subscriptions.first;
  }

  List<_BillingPlanData> _planCards(
    List<Map<String, dynamic>> plans,
    List<AcademyModule> paidModules,
  ) {
    if (plans.isNotEmpty) {
      return plans.take(6).map((plan) {
        final months = (plan['duration_months'] as num?)?.round() ?? 1;
        final title = months <= 1 ? '1 oy' : '$months oy';
        final price = (plan['price_label'] ?? '').toString().trim();
        final perMonth = months > 1 && price.isNotEmpty
            ? '$price / $months oy'
            : '/ oy';
        return _BillingPlanData(
          title: title,
          price: price.isEmpty ? 'Admin tarif' : price,
          perMonth: perMonth,
          discount: months >= 12
              ? '30% chegirma'
              : months >= 3
              ? '10% chegirma'
              : '',
        );
      }).toList();
    }

    final fallbackPrice = paidModules
        .map((module) => module.subscriptionPriceLabel.trim())
        .firstWhere((value) => value.isNotEmpty, orElse: () => 'Admin tarif');
    return [
      _BillingPlanData(title: '1 oy', price: fallbackPrice, perMonth: '/ oy'),
      _BillingPlanData(
        title: '3 oy',
        price: fallbackPrice == 'Admin tarif' ? 'Admin tarif' : fallbackPrice,
        perMonth: '/ 3 oy',
        discount: '10% chegirma',
      ),
      _BillingPlanData(
        title: '12 oy',
        price: fallbackPrice == 'Admin tarif' ? 'Admin tarif' : fallbackPrice,
        perMonth: '/ yil',
        discount: '30% chegirma',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final paidModules = widget.data.modules
        .where((module) => module.requiresSubscription)
        .toList();
    final billing = _billing;
    final error = _error;
    final subscriptions = <Map<String, dynamic>>[
      ...(billing?['subscriptions'] ?? const <Map<String, dynamic>>[]),
      ...(billing?['legacySubscriptions'] ?? const <Map<String, dynamic>>[]),
    ];
    final transactions =
        billing?['transactions'] ?? const <Map<String, dynamic>>[];
    final plans = billing?['plans'] ?? const <Map<String, dynamic>>[];
    final activeSubscription = _activeSubscription(subscriptions);
    final planCards = _planCards(plans, paidModules);
    return _ProfileBillingScaffold(
      child: error != null
          ? _ProfileErrorState(
              icon: Icons.credit_card_off_rounded,
              title: 'To‘lov ma’lumotlari yuklanmadi',
              message: error.toString().replaceFirst('Exception: ', ''),
              onRetry: _load,
            )
          : billing == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _BillingSubscriptionHero(
                  title: activeSubscription == null
                      ? 'Bepul a’zo'
                      : _subscriptionTitle(activeSubscription),
                  isActive:
                      (activeSubscription?['status'] ?? '')
                          .toString()
                          .toLowerCase() ==
                      'active',
                  startDate: _dateValue(
                    activeSubscription ?? const <String, dynamic>{},
                    ['current_period_start', 'starts_at', 'created_at'],
                  ),
                  endDate: _dateValue(
                    activeSubscription ?? const <String, dynamic>{},
                    ['current_period_end', 'ends_at'],
                  ),
                  daysLeft: _daysLeft(
                    _dateValue(
                      activeSubscription ?? const <String, dynamic>{},
                      ['current_period_end', 'ends_at'],
                    ),
                  ),
                  onAction: () => unawaited(_openSupport()),
                ),
                const SizedBox(height: 22),
                const _BillingSectionHeader(title: 'Mavjud tariflar'),
                const SizedBox(height: 10),
                if (planCards.isEmpty)
                  _ProfileEmptyPanel(
                    icon: Icons.price_check_rounded,
                    title: 'Tariflar hali kiritilmagan',
                    subtitle:
                        'Tariflar admin paneldagi to‘lov sozlamasidan keladi.',
                  )
                else
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        for (var index = 0; index < planCards.length; index++)
                          Padding(
                            padding: EdgeInsets.only(
                              right: index == planCards.length - 1 ? 0 : 10,
                            ),
                            child: _BillingPlanCard(
                              data: planCards[index],
                              selected: index == 0,
                              onTap: () => unawaited(_openSupport()),
                            ),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 14),
                const _BillingInfoBanner(),
                const SizedBox(height: 22),
                _BillingSectionHeader(title: t('payment_history')),
                const SizedBox(height: 10),
                if (transactions.isEmpty)
                  _ProfileEmptyPanel(
                    icon: Icons.receipt_long_outlined,
                    title: t('no_payments'),
                    subtitle:
                        'To‘lov amalga oshirilsa, holati va sanasi shu yerda chiqadi.',
                  )
                else
                  _BillingHistoryList(
                    rows: transactions,
                    dateBuilder: (row) => _formatBillingDate(
                      _dateValue(row, ['created_at', 'paid_at']),
                    ),
                    moneyBuilder: _money,
                  ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: _BillingGradientButton(
                    onPressed: () => unawaited(_openSupport()),
                    icon: const Icon(Icons.diamond_outlined),
                    label: Text(
                      activeSubscription == null
                          ? 'Premium obuna olish'
                          : 'Obunani uzaytirish',
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _ProfileAboutSheet extends StatelessWidget {
  const _ProfileAboutSheet({
    required this.language,
    required this.appVersionName,
    required this.onCheckForUpdate,
  });

  final AppLanguage language;
  final String appVersionName;
  final Future<void> Function() onCheckForUpdate;

  @override
  Widget build(BuildContext context) {
    String t(String key) => _profileText(language, key);
    return _ProfileModalScaffold(
      title: t('about'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProfileSectionPanel(
            icon: Icons.science_rounded,
            title: 'LabProof Academy',
            subtitle:
                '${studentText(language, 'version_label')} v$appVersionName',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: const [
                _ProfileChip(label: 'Student app', icon: Icons.school_rounded),
                _ProfileChip(label: 'Progress', icon: Icons.bar_chart_rounded),
                _ProfileChip(label: 'Sertifikat', icon: Icons.verified_rounded),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _ProfileSheetTitle('Asosiy imkoniyatlar'),
          const _ProfileFeatureList(
            items: [
              (
                Icons.menu_book_rounded,
                'Modullar va mavzularni ketma-ket o‘rganish',
              ),
              (Icons.quiz_rounded, 'Test natijalarini progressga yozish'),
              (
                Icons.workspace_premium_rounded,
                'Pullik kontentni obuna orqali ochish',
              ),
              (
                Icons.support_agent_rounded,
                'Admin bilan ilova ichida bog‘lanish',
              ),
            ],
          ),
          const SizedBox(height: 16),
          _AboutBlock(title: t('about_goal'), body: t('about_goal_text')),
          _AboutBlock(title: t('about_how'), body: t('about_how_text')),
          _ProfilePolicyCard(
            blocks: [
              (t('terms'), t('terms_text')),
              (t('privacy'), t('privacy_text')),
              (t('payment_policy'), t('payment_policy_text')),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => unawaited(onCheckForUpdate()),
              icon: const Icon(Icons.system_update_alt_rounded),
              label: Text(t('check_update')),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileModalScaffold extends StatelessWidget {
  const _ProfileModalScaffold({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          8,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 16),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileBillingScaffold extends StatelessWidget {
  const _ProfileBillingScaffold({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(18, 6, 18, bottomInset + 18),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  _BillingHeaderButton(
                    icon: Icons.arrow_back_rounded,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Expanded(
                    child: Text(
                      'To‘lovlar va obuna',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  _BillingHeaderButton(
                    icon: Icons.help_outline_rounded,
                    onPressed: () {
                      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                        const SnackBar(
                          content: Text(
                            'To‘lov va obuna bo‘yicha yordam admin orqali beriladi.',
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _BillingHeaderButton extends StatelessWidget {
  const _BillingHeaderButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        fixedSize: const Size(48, 48),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFFE4E6F4)),
        ),
      ),
    );
  }
}

class _BillingSubscriptionHero extends StatelessWidget {
  const _BillingSubscriptionHero({
    required this.title,
    required this.isActive,
    required this.startDate,
    required this.endDate,
    required this.daysLeft,
    required this.onAction,
  });

  final String title;
  final bool isActive;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? daysLeft;
  final VoidCallback onAction;

  static String _date(DateTime? value) {
    if (value == null) return '--.--.----';
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day.$month.${value.year}';
  }

  @override
  Widget build(BuildContext context) {
    final days = daysLeft;
    final ringValue = days == null ? .0 : (days / 30).clamp(.05, 1.0);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Color(0xFFFBFAFF), Color(0xFFF8F5FF)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Color(0xFFE1D9FF)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6D4AFF).withValues(alpha: .08),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF7C4DFF), Color(0xFF4F35E8)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6D4AFF).withValues(alpha: .26),
                      blurRadius: 16,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: Colors.white,
                  size: 34,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        _BillingStatusPill(isActive: isActive),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      isActive
                          ? 'Sizning obunangiz faol'
                          : 'Premium obuna hali ulanmagan',
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 86,
                height: 86,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 78,
                      height: 78,
                      child: CircularProgressIndicator(
                        value: ringValue,
                        strokeWidth: 8,
                        backgroundColor: const Color(0xFFEDE8FF),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isActive
                              ? AppColors.studentPrimary
                              : const Color(0xFFCBD5E1),
                        ),
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          days == null ? '0' : '$days',
                          style: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          isActive ? 'kun qoldi' : 'kun',
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _BillingDateTile(
                  title: 'Boshlangan sana',
                  value: _date(startDate),
                ),
              ),
              Container(width: 1, height: 42, color: const Color(0xFFE4E6F4)),
              Expanded(
                child: _BillingDateTile(
                  title: 'Tugash sanasi',
                  value: _date(endDate),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _BillingGradientButton(
            onPressed: onAction,
            icon: Icon(isActive ? Icons.sync_rounded : Icons.diamond_outlined),
            label: Text(
              isActive ? 'Obunani uzaytirish' : 'Premium obuna olish',
            ),
          ),
        ],
      ),
    );
  }
}

class _BillingStatusPill extends StatelessWidget {
  const _BillingStatusPill({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFEAFBF0) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: isActive ? const Color(0xFFBBF7D0) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive
                  ? const Color(0xFF16A34A)
                  : const Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isActive ? 'Faol' : 'Faol emas',
            style: TextStyle(
              color: isActive
                  ? const Color(0xFF15803D)
                  : const Color(0xFF64748B),
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _BillingDateTile extends StatelessWidget {
  const _BillingDateTile({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              const Icon(
                Icons.calendar_month_rounded,
                color: AppColors.studentPrimary,
                size: 17,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BillingSectionHeader extends StatelessWidget {
  const _BillingSectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.w900,
              fontSize: 20,
            ),
          ),
        ),
        TextButton(
          onPressed: () {},
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Barchasi'),
              SizedBox(width: 2),
              Icon(Icons.chevron_right_rounded, size: 18),
            ],
          ),
        ),
      ],
    );
  }
}

class _BillingPlanData {
  const _BillingPlanData({
    required this.title,
    required this.price,
    required this.perMonth,
    this.discount = '',
  });

  final String title;
  final String price;
  final String perMonth;
  final String discount;
}

class _BillingPlanCard extends StatelessWidget {
  const _BillingPlanCard({
    required this.data,
    required this.selected,
    required this.onTap,
  });

  final _BillingPlanData data;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 136,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? AppColors.studentPrimary
                : const Color(0xFFE2E8F0),
            width: selected ? 1.6 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.navy.withValues(alpha: .04),
              blurRadius: 16,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            if (selected)
              const Positioned(
                right: 0,
                top: 0,
                child: CircleAvatar(
                  radius: 13,
                  backgroundColor: AppColors.studentPrimary,
                  child: Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 17,
                  ),
                ),
              ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.title,
                  style: const TextStyle(
                    color: Color(0xFF334155),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  data.price,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 19,
                    height: 1.08,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  data.perMonth,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                if (data.discount.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.studentPrimary.withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      data.discount,
                      style: const TextStyle(
                        color: AppColors.studentPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                for (final feature in const [
                  'Barcha kurslar',
                  'Sertifikat',
                  'Progress kuzatuv',
                  'Reklamasiz',
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_rounded,
                          color: AppColors.studentPrimary,
                          size: 16,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            feature,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF475569),
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BillingInfoBanner extends StatelessWidget {
  const _BillingInfoBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFAFF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE1D9FF)),
      ),
      child: const Row(
        children: [
          IconBadge(
            icon: Icons.local_offer_rounded,
            color: AppColors.studentPrimary,
            size: 46,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bir martalik to‘lov',
                  style: TextStyle(
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'To‘lov tasdiqlangandan so‘ng obunangiz darhol faollashadi.',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BillingHistoryList extends StatelessWidget {
  const _BillingHistoryList({
    required this.rows,
    required this.dateBuilder,
    required this.moneyBuilder,
  });

  final List<Map<String, dynamic>> rows;
  final String Function(Map<String, dynamic>) dateBuilder;
  final String Function(Map<String, dynamic>) moneyBuilder;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          for (var index = 0; index < rows.length; index++) ...[
            _BillingHistoryRow(
              row: rows[index],
              date: dateBuilder(rows[index]),
              amount: moneyBuilder(rows[index]),
            ),
            if (index != rows.length - 1)
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
          ],
        ],
      ),
    );
  }
}

class _BillingHistoryRow extends StatelessWidget {
  const _BillingHistoryRow({
    required this.row,
    required this.date,
    required this.amount,
  });

  final Map<String, dynamic> row;
  final String date;
  final String amount;

  @override
  Widget build(BuildContext context) {
    final status = (row['status'] ?? 'paid').toString();
    final isPaid =
        status.toLowerCase().contains('paid') ||
        status.toLowerCase().contains('success') ||
        status.toLowerCase().contains('to‘langan');
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFFEAFBF0),
            child: Icon(
              isPaid ? Icons.verified_rounded : Icons.schedule_rounded,
              color: isPaid ? const Color(0xFF16A34A) : const Color(0xFFF59E0B),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  date,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  (row['provider'] ?? 'Premium Student').toString(),
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                amount.isEmpty ? '—' : amount,
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                isPaid ? 'To‘langan' : status,
                style: TextStyle(
                  color: isPaid
                      ? const Color(0xFF16A34A)
                      : const Color(0xFFF59E0B),
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
        ],
      ),
    );
  }
}

class _BillingGradientButton extends StatelessWidget {
  const _BillingGradientButton({
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  final VoidCallback onPressed;
  final Widget icon;
  final Widget label;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(15),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            gradient: const LinearGradient(
              colors: [Color(0xFF6D4AFF), Color(0xFF5738E8)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6D4AFF).withValues(alpha: .22),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: IconTheme(
            data: const IconThemeData(color: Colors.white, size: 22),
            child: DefaultTextStyle(
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  icon,
                  const SizedBox(width: 10),
                  Flexible(child: label),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileSheetTitle extends StatelessWidget {
  const _ProfileSheetTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _ProfileStatusCard extends StatelessWidget {
  const _ProfileStatusCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: .18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 10),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _ProfileSectionPanel extends StatelessWidget {
  const _ProfileSectionPanel({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: .04),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBadge(icon: icon, color: AppColors.studentPrimary, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _ProfileToggleRow extends StatelessWidget {
  const _ProfileToggleRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.navy, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(color: Color(0xFF64748B), height: 1.3),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeThumbColor: const Color(0xFF22C55E),
          ),
        ],
      ),
    );
  }
}

class _ProfileNoticeBox extends StatelessWidget {
  const _ProfileNoticeBox({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF2563EB), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Color(0xFF475569), height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileErrorState extends StatelessWidget {
  const _ProfileErrorState({
    required this.icon,
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.errorRed.withValues(alpha: .18)),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.errorRed, size: 34),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF64748B), height: 1.35),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Qayta urinish'),
          ),
        ],
      ),
    );
  }
}

class _ProfileEmptyPanel extends StatelessWidget {
  const _ProfileEmptyPanel({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF64748B), size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileChip extends StatelessWidget {
  const _ProfileChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.studentPrimary.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppColors.studentPrimary.withValues(alpha: .14),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.studentPrimary, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.studentPrimary,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileFeatureList extends StatelessWidget {
  const _ProfileFeatureList({required this.items});

  final List<(IconData, String)> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(items[i].$1, color: AppColors.studentPrimary, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      items[i].$2,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
            if (i != items.length - 1)
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
          ],
        ],
      ),
    );
  }
}

class _ProfilePolicyCard extends StatelessWidget {
  const _ProfilePolicyCard({required this.blocks});

  final List<(String, String)> blocks;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < blocks.length; i++) ...[
            Text(
              blocks[i].$1,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              blocks[i].$2,
              style: const TextStyle(color: Color(0xFF64748B), height: 1.45),
            ),
            if (i != blocks.length - 1) const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

class _AboutBlock extends StatelessWidget {
  const _AboutBlock({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(
            body,
            style: const TextStyle(color: Color(0xFF64748B), height: 1.45),
          ),
        ],
      ),
    );
  }
}

String _profileDisplayCode(StudentProfile profile) {
  final code = profile.studentCode.trim();
  if (code.isNotEmpty) return code;
  final hash = profile.id.codeUnits.fold<int>(
    0,
    (value, unit) => (value + unit) % 99999,
  );
  return 'LPA-${math.max(1, hash).toString().padLeft(5, '0')}';
}

String _profileMemberDate(StudentProfile profile) {
  final value = profile.createdAt;
  if (value == null) return 'Faol';
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  final year = (value.year % 100).toString().padLeft(2, '0');
  return '$day.$month.$year';
}

class _ProfileHeroCard extends StatelessWidget {
  const _ProfileHeroCard({
    required this.profile,
    required this.studentCode,
    required this.activeCourses,
    required this.totalXp,
    required this.level,
    required this.onEditProfile,
  });

  final StudentProfile profile;
  final String studentCode;
  final int activeCourses;
  final int totalXp;
  final int level;
  final Future<void> Function() onEditProfile;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2434A8),
            Color(0xFF4822B8),
            Color(0xFF7C22D8),
            Color(0xFF150A59),
          ],
          stops: [0, .34, .68, 1],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: .24)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4C1D95).withValues(alpha: .28),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 560;
          final avatarSize = compact ? 84.0 : 108.0;
          final medalWidth = compact ? 70.0 : 118.0;
          final medalHeight = compact ? 64.0 : 92.0;
          final cardHeight = compact ? 150.0 : 166.0;
          final leftInfo = compact ? avatarSize + 18 : avatarSize + 26;
          final rightInfo = compact ? medalWidth + 8 : medalWidth + 18;

          return SizedBox(
            height: cardHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  right: -20,
                  top: -34,
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: .08),
                    ),
                  ),
                ),
                Positioned(
                  left: compact ? 8 : 8,
                  top: compact ? 10 : 8,
                  child: _ProfileHeroAvatar(
                    profile: profile,
                    onEditProfile: onEditProfile,
                    size: avatarSize,
                  ),
                ),
                Positioned(
                  right: compact ? -2 : 2,
                  top: compact ? 8 : 0,
                  child: SizedBox(
                    width: medalWidth,
                    height: medalHeight,
                    child: const FittedBox(child: _ProfileAchievementMedal()),
                  ),
                ),
                Positioned(
                  left: leftInfo,
                  right: rightInfo,
                  top: compact ? 14 : 22,
                  child: _ProfileHeroInfo(
                    profile: profile,
                    studentCode: studentCode,
                    activeCourses: activeCourses,
                    totalXp: totalXp,
                    level: level,
                    compact: compact,
                    showMetrics: false,
                  ),
                ),
                Positioned(
                  left: compact ? 4 : leftInfo,
                  right: compact ? 4 : medalWidth + 16,
                  bottom: compact ? 8 : 10,
                  child: _ProfileHeroMetricStrip(
                    profile: profile,
                    activeCourses: activeCourses,
                    totalXp: totalXp,
                    level: level,
                    compact: compact,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ProfileHeroAvatar extends StatelessWidget {
  const _ProfileHeroAvatar({
    required this.profile,
    required this.onEditProfile,
    this.size = 116,
  });

  final StudentProfile profile;
  final Future<void> Function() onEditProfile;
  final double size;

  @override
  Widget build(BuildContext context) {
    final editSize = (size * .32).clamp(28.0, 38.0);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFFE9D5FF), Color(0xFF7C3AED)],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .22),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipOval(
            child: profile.hasAvatar
                ? Image.network(
                    profile.avatarUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const _ProfileHeroIllustration(),
                  )
                : const _ProfileHeroIllustration(),
          ),
        ),
        Positioned(
          right: -5,
          bottom: size * .10,
          child: InkWell(
            onTap: () => unawaited(onEditProfile()),
            borderRadius: BorderRadius.circular(999),
            child: Container(
              width: editSize,
              height: editSize,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .22),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: const Icon(
                Icons.edit_rounded,
                color: AppColors.studentPrimary,
                size: 17,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileHeroIllustration extends StatelessWidget {
  const _ProfileHeroIllustration();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _ProfileHeroIllustrationPainter());
  }
}

class _ProfileHeroIllustrationPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;

    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFD8B4FE), Color(0xFF6D28D9)],
      ).createShader(Offset.zero & size);
    canvas.drawCircle(center, radius, bgPaint);

    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: .18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx, size.height * .83),
        width: size.width * .58,
        height: size.height * .12,
      ),
      shadow,
    );

    final hoodie = Paint()..color = const Color(0xFF5B21B6);
    final hoodiePath = Path()
      ..moveTo(size.width * .20, size.height)
      ..quadraticBezierTo(
        size.width * .24,
        size.height * .68,
        size.width * .50,
        size.height * .66,
      )
      ..quadraticBezierTo(
        size.width * .76,
        size.height * .68,
        size.width * .82,
        size.height,
      )
      ..close();
    canvas.drawPath(hoodiePath, hoodie);

    final neck = Paint()..color = const Color(0xFFE8A17B);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(center.dx, size.height * .64),
          width: size.width * .19,
          height: size.height * .17,
        ),
        Radius.circular(size.width * .08),
      ),
      neck,
    );

    final face = Paint()..color = const Color(0xFFF3B28D);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx, size.height * .43),
        width: size.width * .46,
        height: size.height * .50,
      ),
      face,
    );

    final earPaint = Paint()..color = const Color(0xFFE9A27F);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * .26, size.height * .44),
        width: size.width * .09,
        height: size.height * .14,
      ),
      earPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * .74, size.height * .44),
        width: size.width * .09,
        height: size.height * .14,
      ),
      earPaint,
    );

    final hair = Paint()..color = const Color(0xFF21112F);
    final hairPath = Path()
      ..moveTo(size.width * .23, size.height * .33)
      ..cubicTo(
        size.width * .25,
        size.height * .12,
        size.width * .44,
        size.height * .10,
        size.width * .55,
        size.height * .15,
      )
      ..cubicTo(
        size.width * .67,
        size.height * .10,
        size.width * .82,
        size.height * .23,
        size.width * .72,
        size.height * .40,
      )
      ..cubicTo(
        size.width * .58,
        size.height * .31,
        size.width * .44,
        size.height * .35,
        size.width * .31,
        size.height * .40,
      )
      ..close();
    canvas.drawPath(hairPath, hair);

    final curlPaint = Paint()
      ..color = const Color(0xFF2D1745)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * .045
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromLTWH(
        size.width * .30,
        size.height * .12,
        size.width * .28,
        size.height * .22,
      ),
      math.pi * .08,
      math.pi * 1.25,
      false,
      curlPaint,
    );

    final eye = Paint()..color = const Color(0xFF111827);
    canvas.drawCircle(Offset(size.width * .41, size.height * .45), 2.8, eye);
    canvas.drawCircle(Offset(size.width * .59, size.height * .45), 2.8, eye);

    final brow = Paint()
      ..color = const Color(0xFF21112F)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * .35, size.height * .39),
      Offset(size.width * .45, size.height * .38),
      brow,
    );
    canvas.drawLine(
      Offset(size.width * .55, size.height * .38),
      Offset(size.width * .65, size.height * .39),
      brow,
    );

    final nose = Paint()
      ..color = const Color(0xFFD98468)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * .50, size.height * .47),
      Offset(size.width * .48, size.height * .54),
      nose,
    );

    final smile = Paint()
      ..color = const Color(0xFF9F2F45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.1
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(size.width * .50, size.height * .55),
        width: size.width * .18,
        height: size.height * .11,
      ),
      math.pi * .12,
      math.pi * .78,
      false,
      smile,
    );

    final drawString = Paint()
      ..color = const Color(0xFFDDD6FE)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * .43, size.height * .72),
      Offset(size.width * .38, size.height * .93),
      drawString,
    );
    canvas.drawLine(
      Offset(size.width * .57, size.height * .72),
      Offset(size.width * .62, size.height * .93),
      drawString,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ProfileHeroInitials extends StatelessWidget {
  const _ProfileHeroInitials({required this.profile});

  final StudentProfile profile;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF5D0FE), Color(0xFF8B5CF6)],
        ),
      ),
      child: Center(
        child: Text(
          profile.initials,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 34,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _ProfileHeroInfo extends StatelessWidget {
  const _ProfileHeroInfo({
    required this.profile,
    required this.studentCode,
    required this.activeCourses,
    required this.totalXp,
    required this.level,
    required this.compact,
    required this.showMetrics,
  });

  final StudentProfile profile;
  final String studentCode;
  final int activeCourses;
  final int totalXp;
  final int level;
  final bool compact;
  final bool showMetrics;

  @override
  Widget build(BuildContext context) {
    final subscriptionLabel = profile.premiumLabel.trim().isEmpty
        ? 'Bepul a’zo'
        : profile.premiumLabel.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                profile.fullName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: compact ? 18 : 23,
                  height: 1.08,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.verified_rounded,
              color: Color(0xFFB7A7FF),
              size: 22,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          studentCode,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withValues(alpha: .78),
            fontSize: compact ? 12 : 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: compact ? 7 : 10),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 12,
            vertical: compact ? 5 : 7,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .16),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: .18)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.workspace_premium_rounded,
                color: Color(0xFFFFD166),
                size: 16,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  subscriptionLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: compact ? 11.5 : 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showMetrics) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 18,
            runSpacing: 12,
            children: [
              _ProfileHeroMetric(
                icon: Icons.calendar_month_rounded,
                label: 'A’zo bo‘lgan sana',
                value: _profileMemberDate(profile),
              ),
              _ProfileHeroMetric(
                icon: Icons.menu_book_rounded,
                label: 'O‘qiyotgan kurslar',
                value: '$activeCourses ta',
              ),
              _ProfileHeroMetric(
                icon: Icons.emoji_events_rounded,
                label: 'Jami XP',
                value: '${_compactNumber(totalXp)} XP',
              ),
              _ProfileHeroMetric(
                icon: Icons.leaderboard_rounded,
                label: 'Daraja',
                value: 'Level $level',
              ),
            ],
          ),
        ],
      ],
    );
  }

  static String _compactNumber(int value) {
    if (value < 1000) return value.toString();
    final compactValue = value / 1000;
    final text = compactValue.toStringAsFixed(compactValue >= 10 ? 0 : 1);
    return '${text.replaceAll('.0', '')}k';
  }
}

class _ProfileHeroMetricStrip extends StatelessWidget {
  const _ProfileHeroMetricStrip({
    required this.profile,
    required this.activeCourses,
    required this.totalXp,
    required this.level,
    required this.compact,
  });

  final StudentProfile profile;
  final int activeCourses;
  final int totalXp;
  final int level;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ProfileHeroMiniMetric(
            icon: Icons.calendar_month_rounded,
            label: 'Sana',
            value: _profileMemberDate(profile),
          ),
        ),
        _ProfileHeroMetricSeparator(compact: compact),
        Expanded(
          child: _ProfileHeroMiniMetric(
            icon: Icons.menu_book_rounded,
            label: 'Kurslar',
            value: '$activeCourses ta',
          ),
        ),
        _ProfileHeroMetricSeparator(compact: compact),
        Expanded(
          child: _ProfileHeroMiniMetric(
            icon: Icons.emoji_events_rounded,
            label: 'Jami XP',
            value: '${_ProfileHeroInfo._compactNumber(totalXp)} XP',
          ),
        ),
        _ProfileHeroMetricSeparator(compact: compact),
        Expanded(
          child: _ProfileHeroMiniMetric(
            icon: Icons.leaderboard_rounded,
            label: 'Daraja',
            value: 'Level $level',
          ),
        ),
      ],
    );
  }
}

class _ProfileHeroMetricSeparator extends StatelessWidget {
  const _ProfileHeroMetricSeparator({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: compact ? 6 : 14,
      height: 28,
      child: VerticalDivider(
        width: 1,
        color: Colors.white.withValues(alpha: .13),
      ),
    );
  }
}

class _ProfileHeroMiniMetric extends StatelessWidget {
  const _ProfileHeroMiniMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .13),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(icon, color: const Color(0xFFC4B5FD), size: 15),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .58),
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileHeroMetricGrid extends StatelessWidget {
  const _ProfileHeroMetricGrid({
    required this.activeCourses,
    required this.totalXp,
    required this.level,
  });

  final int activeCourses;
  final int totalXp;
  final int level;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      const _ProfileHeroMetric(
        icon: Icons.calendar_month_rounded,
        label: 'A’zo bo‘lgan sana',
        value: 'Faol profil',
      ),
      _ProfileHeroMetric(
        icon: Icons.menu_book_rounded,
        label: 'O‘qiyotgan kurslar',
        value: '$activeCourses ta',
      ),
      _ProfileHeroMetric(
        icon: Icons.emoji_events_rounded,
        label: 'Jami XP',
        value: '${_ProfileHeroInfo._compactNumber(totalXp)} XP',
      ),
      _ProfileHeroMetric(
        icon: Icons.leaderboard_rounded,
        label: 'Daraja',
        value: 'Level $level',
      ),
    ];

    return Wrap(spacing: 14, runSpacing: 12, children: metrics);
  }
}

class _ProfileHeroMetric extends StatelessWidget {
  const _ProfileHeroMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .14),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFFC4B5FD), size: 16),
        ),
        const SizedBox(width: 7),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: .58),
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ProfileAchievementMedal extends StatelessWidget {
  const _ProfileAchievementMedal();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned(
          bottom: 0,
          child: Container(
            width: 112,
            height: 22,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: .18),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
        Container(
          width: 104,
          height: 104,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF9F7AEA), Color(0xFF4C1D95)],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: .22)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .25),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(
            Icons.school_rounded,
            color: Color(0xFFC4B5FD),
            size: 54,
          ),
        ),
        Positioned(
          left: 0,
          bottom: 12,
          child: Icon(
            Icons.eco_rounded,
            color: const Color(0xFFFFD166).withValues(alpha: .92),
            size: 42,
          ),
        ),
        Positioned(
          right: 0,
          bottom: 12,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.rotationY(math.pi),
            child: Icon(
              Icons.eco_rounded,
              color: const Color(0xFFFFD166).withValues(alpha: .92),
              size: 42,
            ),
          ),
        ),
        const Positioned(
          right: 12,
          top: 8,
          child: Icon(
            Icons.auto_awesome_rounded,
            color: Color(0xFFFFD166),
            size: 18,
          ),
        ),
      ],
    );
  }
}

class _ProfileSettingsGridCard extends StatelessWidget {
  const _ProfileSettingsGridCard({required this.items});

  final List<_ProfileSettingsAction> items;

  @override
  Widget build(BuildContext context) {
    return _ProfileSettingsCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final twoColumns = constraints.maxWidth >= 640;
          if (!twoColumns) {
            return Column(
              children: [
                for (var index = 0; index < items.length; index++) ...[
                  items[index],
                  if (index != items.length - 1)
                    const _ProfileSettingsDivider(),
                ],
              ],
            );
          }

          final left = [for (var i = 0; i < items.length; i += 2) items[i]];
          final right = [for (var i = 1; i < items.length; i += 2) items[i]];
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _ProfileSettingsColumn(items: left)),
                VerticalDivider(
                  width: 1,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withValues(alpha: .07)
                      : const Color(0xFFE2E8F0),
                ),
                Expanded(child: _ProfileSettingsColumn(items: right)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ProfileSettingsColumn extends StatelessWidget {
  const _ProfileSettingsColumn({required this.items});

  final List<_ProfileSettingsAction> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < items.length; index++) ...[
          items[index],
          if (index != items.length - 1) const _ProfileSettingsDivider(),
        ],
      ],
    );
  }
}

class _ProfileSettingsAction extends StatelessWidget {
  const _ProfileSettingsAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: .08)
                  : Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppColors.studentPrimary.withValues(alpha: .10),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Icon(icon, color: AppColors.studentPrimary, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          trailing ?? const _ProfileChevron(),
        ],
      ),
    );

    if (onTap == null) return content;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: content,
    );
  }
}

class _ProfileSectionTitle extends StatelessWidget {
  const _ProfileSectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      title,
      style: TextStyle(
        color: isDark ? Colors.white : const Color(0xFF0F172A),
        fontSize: 16,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _ProfileSettingsCard extends StatelessWidget {
  const _ProfileSettingsCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0A1627).withValues(alpha: .92)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: .06)
              : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: .16)
                : AppColors.studentPrimary.withValues(alpha: .05),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _ProfileCircleButton extends StatelessWidget {
  const _ProfileCircleButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: .07)
                : const Color(0xFFF1F5F9),
            shape: BoxShape.circle,
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: .08)
                  : const Color(0xFFE2E8F0),
            ),
          ),
          child: Icon(
            icon,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            size: 25,
          ),
        ),
      ),
    );
  }
}

class _ProfileSettingsTile extends StatelessWidget {
  const _ProfileSettingsTile({
    required this.icon,
    required this.title,
    required this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: Icon(
              icon,
              color: isDark ? const Color(0xFFB7C2D6) : const Color(0xFF64748B),
              size: 23,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          trailing,
        ],
      ),
    );

    if (onTap == null) return content;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: content,
    );
  }
}

class _ProfileSettingsDivider extends StatelessWidget {
  const _ProfileSettingsDivider();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Divider(
      height: 1,
      indent: 58,
      color: isDark
          ? Colors.white.withValues(alpha: .06)
          : const Color(0xFFE2E8F0),
    );
  }
}

class _ProfileInlineValue extends StatelessWidget {
  const _ProfileInlineValue({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 116),
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 4),
        const _ProfileChevron(),
      ],
    );
  }
}

class _ProfileChevron extends StatelessWidget {
  const _ProfileChevron();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Icon(
      Icons.chevron_right_rounded,
      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B),
      size: 24,
    );
  }
}

class _ProfileLocalSwitch extends StatefulWidget {
  const _ProfileLocalSwitch({required this.initialValue});

  final bool initialValue;

  @override
  State<_ProfileLocalSwitch> createState() => _ProfileLocalSwitchState();
}

class _ProfileLocalSwitchState extends State<_ProfileLocalSwitch> {
  late bool _value = widget.initialValue;

  @override
  Widget build(BuildContext context) {
    return Switch.adaptive(
      value: _value,
      onChanged: (value) => setState(() => _value = value),
      activeThumbColor: AppColors.studentPrimary,
      activeTrackColor: AppColors.studentPrimary.withValues(alpha: .35),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.profile, this.size = 64});

  final StudentProfile profile;
  final double size;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size * .4);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.studentPrimary.withValues(alpha: 0.1),
        borderRadius: radius,
        border: Border.all(
          color: AppColors.studentPrimary.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: profile.hasAvatar
          ? ClipRRect(
              borderRadius: BorderRadius.circular(size * .4 - 2),
              child: Image.network(
                profile.avatarUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _fallbackAvatarText(),
              ),
            )
          : _fallbackAvatarText(),
    );
  }

  Widget _fallbackAvatarText() {
    return Center(
      child: Text(
        profile.initials,
        style: TextStyle(
          color: AppColors.studentPrimary,
          fontWeight: FontWeight.w900,
          fontSize: size * .32,
        ),
      ),
    );
  }
}

class _ChatAttachmentDraft {
  const _ChatAttachmentDraft({
    required this.bytes,
    required this.fileName,
    required this.extension,
    required this.mimeType,
    required this.messageKind,
  });

  final Uint8List bytes;
  final String fileName;
  final String extension;
  final String mimeType;
  final String messageKind;

  int get size => bytes.lengthInBytes;
}

List<String> _attachmentExtensionsForKind(String kind) {
  switch (kind) {
    case 'image':
      return ['png', 'jpg', 'jpeg', 'webp', 'gif'];
    case 'video':
    case 'video_note':
      return ['mp4', 'mov'];
    case 'voice':
    case 'audio':
      return ['ogg', 'oga', 'mp3', 'wav', 'm4a'];
    default:
      return ['pdf', 'doc', 'docx', 'txt'];
  }
}

String _attachmentKindLabel(String kind) {
  switch (kind) {
    case 'image':
      return 'Rasm';
    case 'video':
      return 'Video';
    case 'video_note':
      return 'Dumaloq video';
    case 'voice':
      return 'Ovozli xabar';
    case 'audio':
      return 'Audio';
    default:
      return 'Fayl';
  }
}

String _attachmentMimeType(String extension) {
  switch (extension.toLowerCase()) {
    case 'png':
      return 'image/png';
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'webp':
      return 'image/webp';
    case 'gif':
      return 'image/gif';
    case 'mp4':
      return 'video/mp4';
    case 'mov':
      return 'video/quicktime';
    case 'ogg':
    case 'oga':
      return 'audio/ogg';
    case 'mp3':
      return 'audio/mpeg';
    case 'wav':
      return 'audio/wav';
    case 'm4a':
      return 'audio/x-m4a';
    case 'pdf':
      return 'application/pdf';
    case 'doc':
      return 'application/msword';
    case 'docx':
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    default:
      return 'text/plain';
  }
}

Future<_ChatAttachmentDraft?> _pickChatAttachment(String kind) async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowMultiple: false,
    withData: true,
    allowedExtensions: _attachmentExtensionsForKind(kind),
  );
  if (result == null || result.files.isEmpty) return null;
  final file = result.files.single;
  if (file.bytes == null) return null;
  final extension = (file.extension ?? 'bin').toLowerCase();
  return _ChatAttachmentDraft(
    bytes: file.bytes!,
    fileName: file.name,
    extension: extension,
    mimeType: _attachmentMimeType(extension),
    messageKind: kind,
  );
}

String _fileExtensionFromName(String name, String fallback) {
  final index = name.lastIndexOf('.');
  if (index == -1 || index == name.length - 1) return fallback;
  return name.substring(index + 1).toLowerCase();
}

String _timestampedAttachmentName(String prefix, String extension) {
  return '$prefix-${DateTime.now().millisecondsSinceEpoch}.$extension';
}

Future<_ChatAttachmentDraft?> _captureVideoNoteAttachment() async {
  final video = await ImagePicker().pickVideo(
    source: ImageSource.camera,
    preferredCameraDevice: CameraDevice.front,
    maxDuration: const Duration(seconds: 60),
  );
  if (video == null) return null;
  final bytes = await video.readAsBytes();
  final fileName = video.name.isEmpty
      ? _timestampedAttachmentName('labproof-dumaloq-video', 'mp4')
      : video.name;
  final extension = _fileExtensionFromName(fileName, 'mp4');
  return _ChatAttachmentDraft(
    bytes: bytes,
    fileName: fileName,
    extension: extension,
    mimeType: _attachmentMimeType(extension),
    messageKind: 'video_note',
  );
}

Future<void> _openChatAttachment(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

class _AdminSupportSheet extends StatefulWidget {
  const _AdminSupportSheet({required this.language});

  final AppLanguage language;

  @override
  State<_AdminSupportSheet> createState() => _AdminSupportSheetState();
}

class _AdminSupportSheetState extends State<_AdminSupportSheet> {
  static const _repository = SupabaseAcademyRepository();

  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  List<AdminInboxMessage> _history = const [];

  @override
  void initState() {
    super.initState();
    registerTriggerSupportSubmit((subject, body) {
      _subjectController.text = subject;
      _messageController.text = body;
      _submit();
    });
    unawaited(_loadHistory());
  }

  final _audioRecorder = AudioRecorder();
  Timer? _voiceTimer;
  bool _sending = false;
  bool _historyLoading = true;
  bool _showAttachmentTray = false;
  bool _recordingVoice = false;
  int _voiceSeconds = 0;
  String _voiceExtension = 'wav';
  String _voiceMimeType = 'audio/wav';
  _ChatAttachmentDraft? _attachment;

  Future<void> _loadHistory() async {
    try {
      final history = await _repository.loadStudentSupportMessages();
      if (!mounted) return;
      setState(() {
        _history = history;
        _historyLoading = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() => _historyLoading = false);
    }
  }

  Future<void> _pickAttachment(String kind) async {
    if (kind == 'voice') {
      if (_recordingVoice) {
        await _stopVoiceRecording();
      } else {
        await _startVoiceRecording();
      }
      return;
    }

    final picked = kind == 'video_note'
        ? await _captureVideoNoteAttachment()
        : await _pickChatAttachment(kind);
    if (picked == null || !mounted) return;
    setState(() {
      _attachment = picked;
      _showAttachmentTray = false;
    });
  }

  void _showSupportError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.errorRed),
    );
  }

  String _voiceDurationLabel() {
    final minutes = (_voiceSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_voiceSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _startVoiceRecording() async {
    try {
      final allowed = await _audioRecorder.hasPermission();
      if (!allowed) {
        if (!mounted) return;
        _showSupportError('Mikrofon uchun ruxsat berilmadi.');
        return;
      }

      final supported = await _audioRecorder.isEncoderSupported(
        AudioEncoder.wav,
      );
      final extension = supported ? 'wav' : 'm4a';
      final encoder = supported ? AudioEncoder.wav : AudioEncoder.aacLc;
      _voiceExtension = extension;
      _voiceMimeType = _attachmentMimeType(extension);
      var path = '';
      if (!kIsWeb) {
        final directory = await getTemporaryDirectory();
        path =
            '${directory.path}/${_timestampedAttachmentName('labproof-voice', extension)}';
      }

      await _audioRecorder.start(
        RecordConfig(
          encoder: encoder,
          numChannels: 1,
          echoCancel: true,
          noiseSuppress: true,
        ),
        path: path,
      );

      _voiceTimer?.cancel();
      _voiceTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _voiceSeconds += 1);
      });

      if (!mounted) return;
      setState(() {
        _recordingVoice = true;
        _voiceSeconds = 0;
        _showAttachmentTray = true;
      });
    } on Object catch (error) {
      if (!mounted) return;
      _showSupportError(
        'Mikrofonni ishga tushirib bo‘lmadi: ${error.toString().replaceFirst('Exception: ', '')}',
      );
    }
  }

  Future<void> _stopVoiceRecording() async {
    try {
      final path = await _audioRecorder.stop();
      _voiceTimer?.cancel();
      _voiceTimer = null;
      if (!mounted) return;
      setState(() => _recordingVoice = false);

      if (path == null || path.isEmpty) {
        _showSupportError('Ovozli xabar yozilmadi.');
        return;
      }

      final voiceFile = XFile(
        path,
        name: _timestampedAttachmentName('labproof-voice', _voiceExtension),
        mimeType: _voiceMimeType,
      );
      final bytes = await voiceFile.readAsBytes();
      if (!mounted) return;
      setState(() {
        _attachment = _ChatAttachmentDraft(
          bytes: bytes,
          fileName: voiceFile.name.isEmpty
              ? _timestampedAttachmentName('labproof-voice', _voiceExtension)
              : voiceFile.name,
          extension: _voiceExtension,
          mimeType: _voiceMimeType,
          messageKind: 'voice',
        );
        _showAttachmentTray = false;
      });
    } on Object catch (error) {
      _voiceTimer?.cancel();
      _voiceTimer = null;
      if (!mounted) return;
      setState(() => _recordingVoice = false);
      _showSupportError(
        'Ovozli xabarni saqlab bo‘lmadi: ${error.toString().replaceFirst('Exception: ', '')}',
      );
    }
  }

  @override
  void dispose() {
    _voiceTimer?.cancel();
    if (_recordingVoice) unawaited(_audioRecorder.cancel());
    unawaited(_audioRecorder.dispose());
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final subject = _subjectController.text.trim();
    final body = _messageController.text.trim();
    if (subject.isEmpty && body.isEmpty && _attachment == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Hech bo‘lmasa matn yoki biriktirma yuboring.'),
          backgroundColor: AppColors.errorRed,
        ),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      String? attachmentUrl;
      if (_attachment != null) {
        attachmentUrl = await _repository.uploadChatAttachment(
          bytes: _attachment!.bytes,
          extension: _attachment!.extension,
          fileName: _attachment!.fileName,
        );
      }
      await _repository.sendAdminInboxMessage(
        subject: subject.isEmpty
            ? '${_attachmentKindLabel(_attachment?.messageKind ?? 'document')} yuborildi'
            : subject,
        body: body.isEmpty
            ? '${_attachmentKindLabel(_attachment?.messageKind ?? 'document')} biriktirildi.'
            : body,
        messageKind: _attachment?.messageKind ?? 'text',
        attachmentUrl: attachmentUrl,
        attachmentName: _attachment?.fileName,
        attachmentMime: _attachment?.mimeType,
        attachmentSize: _attachment?.size,
      );
      if (!mounted) return;
      _subjectController.clear();
      _messageController.clear();
      setState(() {
        _attachment = null;
        _showAttachmentTray = false;
      });
      await _loadHistory();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Murojaat yuborildi.')));
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.errorRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = widget.language;
    final theme = Theme.of(context);
    final screenSize = MediaQuery.sizeOf(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final compactWidth = screenSize.width <= 24
        ? screenSize.width
        : screenSize.width - 24;
    final width = screenSize.width > 584 ? 560.0 : compactWidth;
    final availableHeight = screenSize.height - bottomInset - 24;
    final height = availableHeight > 720 ? 720.0 : availableHeight;

    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.fromLTRB(12, 12, 12, bottomInset + 12),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              width: width,
              height: height < 360 ? availableHeight : height,
              child: Material(
                elevation: 18,
                shadowColor: AppColors.navy.withValues(alpha: .18),
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(30),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.muted.withValues(alpha: .45),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 14, 12),
                      child: Row(
                        children: [
                          const IconBadge(
                            icon: Icons.support_agent_rounded,
                            color: AppColors.primaryBlue,
                            size: 52,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  studentText(language, 'contact_admin'),
                                  style: theme.textTheme.titleLarge,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  studentText(
                                    language,
                                    'contact_admin_subtitle',
                                  ),
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Yopish',
                            onPressed: _sending
                                ? null
                                : () => Navigator.of(context).pop(false),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ColoredBox(
                        color: AppColors.background.withValues(alpha: .65),
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                constraints: const BoxConstraints(
                                  maxWidth: 420,
                                ),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryBlue.withValues(
                                    alpha: .08,
                                  ),
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(18),
                                    topRight: Radius.circular(18),
                                    bottomRight: Radius.circular(18),
                                    bottomLeft: Radius.circular(6),
                                  ),
                                  border: Border.all(
                                    color: AppColors.primaryBlue.withValues(
                                      alpha: .14,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  'Xabaringiz adminga yuboriladi. Rasm, video, ovozli xabar yoki fayl biriktirishingiz mumkin.',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    height: 1.45,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Container(
                                constraints: const BoxConstraints(
                                  maxWidth: 360,
                                ),
                                padding: const EdgeInsets.all(13),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryBlue,
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(18),
                                    topRight: Radius.circular(18),
                                    bottomLeft: Radius.circular(18),
                                    bottomRight: Radius.circular(6),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primaryBlue.withValues(
                                        alpha: .16,
                                      ),
                                      blurRadius: 16,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  'Murojaatingiz bitta chatda saqlanadi va admin javobi shu yerga keladi.',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: Colors.white,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (_historyLoading)
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(24),
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            else if (_history.isEmpty)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surface,
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.mark_chat_unread_outlined,
                                      color: AppColors.muted.withValues(
                                        alpha: .7,
                                      ),
                                      size: 34,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Hali murojaat yo‘q',
                                      style: theme.textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Birinchi xabaringizni pastdan yuboring.',
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                  ],
                                ),
                              )
                            else
                              for (final message in _history)
                                _SupportHistoryBubble(
                                  message: message,
                                  language: language,
                                ),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        border: const Border(
                          top: BorderSide(color: AppColors.border),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: _subjectController,
                            enabled: !_sending,
                            decoration: InputDecoration(
                              labelText: studentText(
                                language,
                                'support_subject',
                              ),
                              prefixIcon: const Icon(Icons.title_rounded),
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (_showAttachmentTray) ...[
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final kind in const [
                                  ('image', Icons.image_outlined),
                                  ('video', Icons.videocam_outlined),
                                  (
                                    'video_note',
                                    Icons.radio_button_checked_rounded,
                                  ),
                                  ('voice', Icons.mic_none_rounded),
                                  ('document', Icons.attach_file_rounded),
                                ])
                                  OutlinedButton.icon(
                                    onPressed: _sending
                                        ? null
                                        : () => _pickAttachment(kind.$1),
                                    icon: Icon(
                                      kind.$1 == 'voice' && _recordingVoice
                                          ? Icons.stop_circle_outlined
                                          : kind.$2,
                                      size: 18,
                                    ),
                                    label: Text(
                                      kind.$1 == 'voice' && _recordingVoice
                                          ? 'Yozishni tugatish ${_voiceDurationLabel()}'
                                          : _attachmentKindLabel(kind.$1),
                                    ),
                                  ),
                              ],
                            ),
                            if (_recordingVoice) ...[
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.errorRed.withValues(
                                    alpha: .08,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: AppColors.errorRed.withValues(
                                      alpha: .22,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.mic_rounded,
                                      color: AppColors.errorRed,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Mikrofon yozmoqda: ${_voiceDurationLabel()}',
                                        style: theme.textTheme.labelLarge
                                            ?.copyWith(
                                              color: AppColors.errorRed,
                                            ),
                                      ),
                                    ),
                                    TextButton.icon(
                                      onPressed: _sending
                                          ? null
                                          : _stopVoiceRecording,
                                      icon: const Icon(
                                        Icons.stop_rounded,
                                        size: 18,
                                      ),
                                      label: const Text('To‘xtatish'),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 10),
                          ],
                          if (_attachment != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primaryBlue.withValues(
                                  alpha: .07,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: AppColors.primaryBlue.withValues(
                                    alpha: .16,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    switch (_attachment!.messageKind) {
                                      'image' => Icons.image_outlined,
                                      'video' => Icons.videocam_outlined,
                                      'video_note' =>
                                        Icons.radio_button_checked_rounded,
                                      'voice' => Icons.mic_none_rounded,
                                      _ => Icons.attach_file_rounded,
                                    },
                                    color: AppColors.primaryBlue,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _attachment!.fileName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.labelLarge,
                                    ),
                                  ),
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    onPressed: _sending
                                        ? null
                                        : () => setState(
                                            () => _attachment = null,
                                          ),
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      size: 18,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              IconButton.filledTonal(
                                tooltip: 'Biriktirma',
                                onPressed: _sending
                                    ? null
                                    : () => setState(
                                        () => _showAttachmentTray =
                                            !_showAttachmentTray,
                                      ),
                                icon: Icon(
                                  _showAttachmentTray
                                      ? Icons.close_rounded
                                      : Icons.add_rounded,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _messageController,
                                  enabled: !_sending,
                                  minLines: 1,
                                  maxLines: 4,
                                  decoration: InputDecoration(
                                    hintText: studentText(
                                      language,
                                      'support_message_hint',
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 14,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              FilledButton(
                                onPressed: _sending || _recordingVoice
                                    ? null
                                    : _submit,
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 16,
                                  ),
                                ),
                                child: _sending
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.send_rounded),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _formatSupportMessageTime(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(local.day)}.${two(local.month)}.${local.year} ${two(local.hour)}:${two(local.minute)}';
}

class _SupportHistoryBubble extends StatelessWidget {
  const _SupportHistoryBubble({required this.message, required this.language});

  final AdminInboxMessage message;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasReply = (message.adminReply ?? '').trim().isNotEmpty;
    final subject = message.subject.trim().isEmpty
        ? _attachmentKindLabel(message.messageKind)
        : message.subject.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(6),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryBlue.withValues(alpha: .14),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          subject,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        hasReply
                            ? Icons.mark_chat_read_rounded
                            : Icons.schedule_rounded,
                        color: Colors.white.withValues(alpha: .82),
                        size: 18,
                      ),
                    ],
                  ),
                  if (message.body.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      message.body,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: .92),
                        height: 1.35,
                      ),
                    ),
                  ],
                  if (message.hasAttachment) ...[
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: () => unawaited(
                        _openChatAttachment(message.attachmentUrl!),
                      ),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .14),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: .16),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              message.isImage
                                  ? Icons.image_outlined
                                  : message.isVideo
                                  ? Icons.videocam_outlined
                                  : message.isAudio
                                  ? Icons.mic_none_rounded
                                  : Icons.attach_file_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                message.attachmentName?.trim().isNotEmpty ==
                                        true
                                    ? message.attachmentName!
                                    : _attachmentKindLabel(message.messageKind),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.open_in_new_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    _formatSupportMessageTime(message.createdAt),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white.withValues(alpha: .66),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (hasReply) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 420),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                    bottomRight: Radius.circular(18),
                    bottomLeft: Radius.circular(6),
                  ),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.support_agent_rounded,
                          color: AppColors.primaryBlue,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Admin javobi',
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (message.repliedAt != null)
                          Text(
                            _formatSupportMessageTime(message.repliedAt!),
                            style: theme.textTheme.labelSmall,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      message.adminReply!.trim(),
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProfileEditSheet extends StatefulWidget {
  const _ProfileEditSheet({required this.profile, required this.language});

  final StudentProfile profile;
  final AppLanguage language;

  @override
  State<_ProfileEditSheet> createState() => _ProfileEditSheetState();
}

class _ProfileEditSheetState extends State<_ProfileEditSheet> {
  static const _repository = SupabaseAcademyRepository();
  static final Map<String, List<String>> _districtsByRegion = {
    'Toshkent shahri': [
      'Yunusobod',
      'Mirzo Ulug‘bek',
      'Olmazor',
      'Chilonzor',
      'Sergeli',
      'Yakkasaroy',
    ],
    'Toshkent вилояти': [
      'Chirchiq',
      'Angren',
      'Bekobod',
      'Yangiyo‘l',
      'Parkent',
      'Zangiota',
    ],
    'Andijon': [
      'Andijon shahri',
      'Asaka',
      'Xonobod',
      'Marhamat',
      'Buloqboshi',
      'Izboskan',
    ],
    'Namangan': [
      'Namangan shahri',
      'Chortoq',
      'Kosonsoy',
      'Pop',
      'To‘raqo‘rg‘on',
      'Uychi',
    ],
    'Farg‘ona': [
      'Farg‘ona shahri',
      'Qo‘qon',
      'Marg‘ilon',
      'Quva',
      'Rishton',
      'Oltiariq',
    ],
    'Samarqand': [
      'Samarqand shahri',
      'Urgut',
      'Kattaqo‘rg‘on',
      'Pastdarg‘om',
      'Narpay',
      'Bulung‘ur',
    ],
    'Buxoro': [
      'Buxoro shahri',
      'G‘ijduvon',
      'Kogon',
      'Jondor',
      'Qorako‘l',
      'Vobkent',
    ],
    'Xorazm': ['Urganch', 'Xiva', 'Hazorasp', 'Shovot', 'Yangibozor', 'Bog‘ot'],
    'Qashqadaryo': [
      'Qarshi',
      'Shahrisabz',
      'Koson',
      'Kitob',
      'Yakkabog‘',
      'G‘uzor',
    ],
    'Surxondaryo': [
      'Termiz',
      'Denov',
      'Boysun',
      'Sherobod',
      'Sariosiyo',
      'Jarqo‘rg‘on',
    ],
    'Jizzax': [
      'Jizzax shahri',
      'G‘allaorol',
      'Zomin',
      'Do‘stlik',
      'Paxtakor',
      'Forish',
    ],
    'Sirdaryo': [
      'Guliston',
      'Yangiyer',
      'Shirin',
      'Sardoba',
      'Boyovut',
      'Xovos',
    ],
    'Navoiy': [
      'Navoiy shahri',
      'Zarafshon',
      'Karmana',
      'Qiziltepa',
      'Konimex',
      'Xatirchi',
    ],
    'Qoraqalpog‘iston': [
      'Nukus',
      'Xo‘jayli',
      'Beruniy',
      'To‘rtko‘l',
      'Chimboy',
      'Qo‘ng‘irot',
    ],
  };

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _ageController = TextEditingController();
  final _mahallaController = TextEditingController();
  final _streetController = TextEditingController();
  final _picker = ImagePicker();

  String _gender = '';
  String _region = '';
  String _district = '';
  String _avatarUrl = '';
  XFile? _selectedImage;
  Uint8List? _selectedAvatarBytes;
  bool _saving = false;

  AppLanguage get _language => widget.language;

  String _text(String key) => studentText(_language, key);

  String _phoneDigitsFromProfile() {
    final rawPhone = widget.profile.phone.trim();
    if (rawPhone.isEmpty) return '';
    final digits = rawPhone.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('998') && digits.length >= 12) {
      return digits.substring(3, 12);
    }
    if (digits.length >= 9) {
      return digits.substring(digits.length - 9);
    }
    return digits;
  }

  @override
  void initState() {
    super.initState();
    _firstNameController.text = widget.profile.firstName;
    _lastNameController.text = widget.profile.lastName;
    _phoneController.text = _phoneDigitsFromProfile();
    _ageController.text = widget.profile.age?.toString() ?? '';
    _mahallaController.text = widget.profile.mahalla;
    _streetController.text = widget.profile.street;
    _gender = widget.profile.gender;
    _region = widget.profile.region;
    _district = widget.profile.district;
    _avatarUrl = widget.profile.avatarUrl;
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _ageController.dispose();
    _mahallaController.dispose();
    _streetController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 85,
    );
    if (image == null || !mounted) return;
    final bytes = await image.readAsBytes();
    if (!mounted) return;
    setState(() {
      _selectedImage = image;
      _selectedAvatarBytes = bytes;
    });
  }

  Future<void> _saveProfile() async {
    if (_saving) return;

    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final phoneDigits = _phoneController.text.trim();
    final age = int.tryParse(_ageController.text.trim());

    if (firstName.isNotEmpty && firstName.length < 2) {
      _showError(_text('name_complete_error'));
      return;
    }
    if (lastName.isNotEmpty && lastName.length < 2) {
      _showError(_text('name_complete_error'));
      return;
    }
    if (phoneDigits.isNotEmpty && !RegExp(r'^\d{9}$').hasMatch(phoneDigits)) {
      _showError(_text('phone_invalid'));
      return;
    }
    if (age != null && (age < 10 || age > 120)) {
      _showError(_text('age_range_error'));
      return;
    }

    setState(() => _saving = true);

    try {
      var uploadedAvatar = _avatarUrl;
      if (_selectedImage != null) {
        final bytes = await _selectedImage!.readAsBytes();
        final extension = _selectedImage!.name.split('.').last;
        uploadedAvatar = await _repository.uploadProfileAvatar(
          bytes: bytes,
          extension: extension,
        );
      }

      final fallbackFirstName = widget.profile.firstName.trim();
      final fallbackLastName = widget.profile.lastName.trim();
      final savedPhone = phoneDigits.isEmpty
          ? widget.profile.phone.trim()
          : '+998$phoneDigits';

      await _repository.updateOwnProfile(
        StudentProfileUpdate(
          firstName: firstName.isEmpty ? fallbackFirstName : firstName,
          lastName: lastName.isEmpty ? fallbackLastName : lastName,
          phone: savedPhone,
          gender: _gender,
          age: age,
          region: _region,
          district: _district,
          mahalla: _mahallaController.text.trim(),
          street: _streetController.text.trim(),
          avatarUrl: uploadedAvatar,
        ),
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on Object catch (error) {
      _showError(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickGender() async {
    final picked = await _showSelectionSheet<String>(
      context,
      title: _text('choose_gender'),
      items: const ['erkak', 'ayol'],
      initialValue: _gender,
      labelBuilder: (item) => _genderTitle(item, _language),
    );
    if (picked != null && mounted) {
      setState(() => _gender = picked);
    }
  }

  Future<void> _pickRegion() async {
    final picked = await _showSelectionSheet<String>(
      context,
      title: _text('choose_region'),
      items: _districtsByRegion.keys.toList(),
      initialValue: _region,
      labelBuilder: (item) => item,
    );
    if (picked != null && mounted) {
      setState(() {
        _region = picked;
        if (!_districtsByRegion[picked]!.contains(_district)) {
          _district = '';
        }
      });
    }
  }

  Future<void> _pickDistrict() async {
    final districts = _districtsByRegion[_region];
    if (districts == null) {
      _showError(_text('select_region_first'));
      return;
    }

    final picked = await _showSelectionSheet<String>(
      context,
      title: _text('choose_district'),
      items: districts,
      initialValue: _district,
      labelBuilder: (item) => item,
    );
    if (picked != null && mounted) {
      setState(() => _district = picked);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.errorRed),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          8,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _text('profile_edit_title'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                _text('profile_edit_subtitle'),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 18),
              Center(
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _pickAvatar,
                      child: Stack(
                        children: [
                          if (_selectedAvatarBytes != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(28),
                              child: Image.memory(
                                _selectedAvatarBytes!,
                                width: 96,
                                height: 96,
                                fit: BoxFit.cover,
                              ),
                            )
                          else
                            _ProfileAvatar(
                              profile: widget.profile.copyWith(
                                avatarUrl: _avatarUrl,
                              ),
                              size: 96,
                            ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: const BoxDecoration(
                                color: AppColors.primaryBlue,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _pickAvatar,
                      icon: const Icon(Icons.upload_rounded),
                      label: Text(_text('upload_profile_photo')),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _firstNameController,
                      decoration: InputDecoration(
                        labelText: _text('first_name'),
                        prefixIcon: const Icon(Icons.person_outline_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _lastNameController,
                      decoration: InputDecoration(
                        labelText: _text('last_name'),
                        prefixIcon: const Icon(Icons.badge_outlined),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _EditablePhoneField(
                controller: _phoneController,
                label: _text('phone'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _SelectionField(
                      label: _text('gender'),
                      value: _gender.isEmpty
                          ? _text('choose')
                          : _genderTitle(_gender, _language),
                      icon: Icons.wc_rounded,
                      onTap: _pickGender,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _ageController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: _text('age_suffix'),
                        prefixIcon: const Icon(Icons.cake_outlined),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _SelectionField(
                      label: _text('region'),
                      value: _region.isEmpty ? _text('choose') : _region,
                      icon: Icons.map_outlined,
                      onTap: _pickRegion,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SelectionField(
                      label: _text('district'),
                      value: _district.isEmpty ? _text('choose') : _district,
                      icon: Icons.location_city_outlined,
                      onTap: _pickDistrict,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _mahallaController,
                decoration: InputDecoration(
                  labelText: _text('mahalla'),
                  prefixIcon: const Icon(Icons.home_work_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _streetController,
                decoration: InputDecoration(
                  labelText: _text('street_house'),
                  prefixIcon: const Icon(Icons.route_outlined),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _saveProfile,
                  icon: Icon(
                    _saving ? Icons.hourglass_top_rounded : Icons.save_rounded,
                  ),
                  label: Text(_saving ? _text('saving') : _text('save')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectionField extends StatelessWidget {
  const _SelectionField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF0F172A)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF334155)
                : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.muted),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: 4),
                  Text(value, style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded),
          ],
        ),
      ),
    );
  }
}

class _EditablePhoneField extends StatelessWidget {
  const _EditablePhoneField({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          Icon(
            Icons.phone_rounded,
            size: 20,
            color: isDark ? const Color(0xFFCBD5E1) : AppColors.muted,
          ),
          const SizedBox(width: 10),
          const Text(
            '+998',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
          ),
          Container(
            width: 1,
            height: 26,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            color: isDark ? const Color(0xFF334155) : AppColors.border,
          ),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(9),
              ],
              decoration: InputDecoration(
                hintText: label,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          const SizedBox(width: 14),
        ],
      ),
    );
  }
}

class _NotificationsSheet extends StatelessWidget {
  const _NotificationsSheet({
    required this.notificationsEnabled,
    required this.notifications,
    required this.onMarkAllRead,
    required this.onRead,
    required this.language,
  });

  final bool notificationsEnabled;
  final List<StudentNotification> notifications;
  final Future<void> Function() onMarkAllRead;
  final Future<void> Function(String id) onRead;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    final unreadCount = notifications.where((item) => !item.isRead).length;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        studentText(language, 'notifications_title'),
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notificationsEnabled
                            ? '$unreadCount ${studentText(language, 'new_messages_count_suffix')}'
                            : studentText(
                                language,
                                'notifications_disabled_profile',
                              ),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                if (notificationsEnabled)
                  TextButton.icon(
                    onPressed: unreadCount == 0
                        ? null
                        : () => unawaited(onMarkAllRead()),
                    icon: const Icon(Icons.done_all_rounded),
                    label: Text(studentText(language, 'mark_all_read')),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: MediaQuery.sizeOf(context).height * .58,
              child: notificationsEnabled
                  ? notifications.isEmpty
                        ? _EmptyStateCard(
                            icon: Icons.notifications_off_outlined,
                            title: studentText(
                              language,
                              'notifications_empty_title',
                            ),
                            message: studentText(
                              language,
                              'notifications_empty_message',
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            itemCount: notifications.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final item = notifications[index];
                              return AppCard(
                                color: item.isRead
                                    ? null
                                    : AppColors.primaryBlue.withValues(
                                        alpha: .06,
                                      ),
                                borderColor: item.isRead
                                    ? null
                                    : AppColors.primaryBlue.withValues(
                                        alpha: .18,
                                      ),
                                onTap: () => unawaited(onRead(item.id)),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        IconBadge(
                                          icon: item.isRead
                                              ? Icons.mark_email_read_rounded
                                              : Icons
                                                    .notifications_active_rounded,
                                          color: item.isRead
                                              ? AppColors.successGreen
                                              : AppColors.primaryBlue,
                                          size: 38,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            item.title,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.titleMedium,
                                          ),
                                        ),
                                        if (!item.isRead)
                                          Container(
                                            width: 10,
                                            height: 10,
                                            decoration: const BoxDecoration(
                                              color: AppColors.primaryBlue,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      item.body,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(height: 1.55),
                                    ),
                                    if (item.hasAttachment) ...[
                                      const SizedBox(height: 12),
                                      if (item.isImage)
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          child: Image.network(
                                            item.attachmentUrl!,
                                            height: 160,
                                            width: double.infinity,
                                            fit: BoxFit.cover,
                                          ),
                                        )
                                      else
                                        FilledButton.tonalIcon(
                                          onPressed: () => _openChatAttachment(
                                            item.attachmentUrl!,
                                          ),
                                          icon: Icon(
                                            item.isVideo
                                                ? Icons.videocam_outlined
                                                : item.isAudio
                                                ? Icons.graphic_eq_rounded
                                                : Icons.attach_file_rounded,
                                            size: 18,
                                          ),
                                          label: Text(
                                            item.attachmentName
                                                        ?.trim()
                                                        .isNotEmpty ==
                                                    true
                                                ? item.attachmentName!
                                                : 'Biriktirmani ochish',
                                          ),
                                        ),
                                    ],
                                    const SizedBox(height: 12),
                                    Text(
                                      _formatNotificationTime(
                                        item.createdAt,
                                        language,
                                      ),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.labelMedium,
                                    ),
                                  ],
                                ),
                              );
                            },
                          )
                  : _EmptyStateCard(
                      icon: Icons.notifications_paused_rounded,
                      title: studentText(language, 'notifications_off_title'),
                      message: studentText(
                        language,
                        'notifications_off_message',
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatNotificationTime(DateTime value, AppLanguage language) {
    final now = DateTime.now();
    final difference = now.difference(value);
    if (difference.inMinutes < 1) return studentText(language, 'just_now');
    if (difference.inHours < 1) {
      return '${difference.inMinutes} ${studentText(language, 'minutes_ago')}';
    }
    if (difference.inDays < 1) {
      return '${difference.inHours} ${studentText(language, 'hours_ago')}';
    }
    if (difference.inDays < 7) {
      return '${difference.inDays} ${studentText(language, 'days_ago')}';
    }
    return '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';
  }
}

Future<T?> _showSelectionSheet<T>(
  BuildContext context, {
  required String title,
  required List<T> items,
  required String Function(T item) labelBuilder,
  String Function(T item)? subtitleBuilder,
  Widget Function(T item, bool selected)? leadingBuilder,
  T? initialValue,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          6,
          16,
          MediaQuery.viewPaddingOf(context).bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            SizedBox(
              height: MediaQuery.sizeOf(context).height * .68,
              child: ListView.separated(
                padding: const EdgeInsets.only(bottom: 20),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final selected = item == initialValue;
                  return AppCard(
                    color: selected
                        ? AppColors.primaryBlue.withValues(alpha: .06)
                        : null,
                    borderColor: selected
                        ? AppColors.primaryBlue.withValues(alpha: .18)
                        : null,
                    onTap: () => Navigator.of(context).pop(item),
                    child: Row(
                      children: [
                        if (leadingBuilder != null)
                          leadingBuilder(item, selected)
                        else
                          Icon(
                            selected
                                ? Icons.check_circle_rounded
                                : Icons.circle_outlined,
                            color: selected
                                ? AppColors.primaryBlue
                                : AppColors.muted,
                          ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                labelBuilder(item),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              if (subtitleBuilder != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  subtitleBuilder(item),
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: AppColors.muted),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

String _genderTitle(String value, AppLanguage language) {
  switch (value.trim().toLowerCase()) {
    case 'male':
    case 'erkak':
      return studentText(language, 'male');
    case 'female':
    case 'ayol':
      return studentText(language, 'female');
    default:
      return value;
  }
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.primaryBlue.withValues(alpha: .035),
      borderColor: AppColors.primaryBlue.withValues(alpha: .1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBadge(icon: icon, color: AppColors.primaryBlue),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            message,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(height: 1.6),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(actionLabel!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ResultStat extends StatelessWidget {
  const _ResultStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _ExamRule extends StatelessWidget {
  const _ExamRule({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryBlue),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _BulletLine extends StatelessWidget {
  const _BulletLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 7, right: 9),
            decoration: const BoxDecoration(
              color: AppColors.primaryBlue,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _CircuitPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = Colors.white.withValues(alpha: .7)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final glow = Paint()
      ..color = AppColors.cyan.withValues(alpha: .2)
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(size.width * .15, size.height * .35)
      ..lineTo(size.width * .75, size.height * .35)
      ..lineTo(size.width * .75, size.height * .68)
      ..lineTo(size.width * .25, size.height * .68)
      ..lineTo(size.width * .25, size.height * .48);
    canvas.drawPath(path, glow);
    canvas.drawPath(path, line);

    final nodePaint = Paint()..color = AppColors.cyan;
    for (final offset in [
      Offset(size.width * .25, size.height * .35),
      Offset(size.width * .52, size.height * .35),
      Offset(size.width * .75, size.height * .5),
      Offset(size.width * .42, size.height * .68),
    ]) {
      canvas.drawCircle(offset, 5, nodePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
