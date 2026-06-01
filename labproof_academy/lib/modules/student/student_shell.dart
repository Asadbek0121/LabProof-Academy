import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:math' as math;
import 'dart:ui';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../../core/constants/app_language.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../data/models/academy_models.dart';
import '../../data/repositories/supabase_academy_repository.dart';
import 'shared_widgets.dart' as student_shared;
import 'twitter_community.dart';

enum _StudentTab { home, modules, progress, community, profile }

enum _ModuleFilter { all, open, locked, completed }

enum _LearningStage {
  moduleList,
  moduleDetail,
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
  static const _appVersionName = String.fromEnvironment(
    'APP_VERSION_NAME',
    defaultValue: 'dev',
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
  String? _loadError;

  @override
  void initState() {
    super.initState();
    try {
      globalContext.setProperty(
        'openSupportSheet'.toJS,
        (() {
          unawaited(_openAdminSupportSheet());
        }).toJS,
      );
    } catch (_) {}
    _loadDashboard();
    _notificationPoller = Timer.periodic(
      const Duration(seconds: 45),
      (_) => _refreshNotifications(silent: true),
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

  void _openProfileTab() {
    setState(() {
      _prevTabIndex = _StudentTab.values.indexOf(_tab);
      _tab = _StudentTab.profile;
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

  Future<void> _completePdfLesson() async {
    final topic = _selectedTopic;
    if (topic == null) return;

    try {
      await _repository.markPdfCompleted(topic.id);
      if (mounted) {
        setState(() {
          if (_topicHasVideoContent(topic)) {
            _stage = _LearningStage.videoLesson;
          } else if (topic.quizQuestions.isNotEmpty) {
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

  Future<void> _openTopicFile({
    required String url,
    required String missingMessage,
  }) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !uri.hasScheme) {
      _showInfo(missingMessage);
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) {
      _showInfo('Faylni ochib bo‘lmadi. Linkni admin panelda tekshiring.');
    }
  }

  Future<void> _completeVideoLesson() async {
    final topic = _selectedTopic;
    if (topic == null) return;

    try {
      await _repository.markVideoCompleted(topic.id);
      if (mounted) {
        setState(() {
          _quizQuestionIndex = 0;
          _selectedOption = 0;
          _topicAnswers = {};
          if (topic.quizQuestions.isNotEmpty) {
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
      setState(() => _stage = _LearningStage.videoLesson);
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
                  child: _data == null
                      ? _buildTabContent()
                      : _buildIndexedTabContent(_data!),
                ),
              ),
            ),
          ),
          bottomNavigationBar: Center(
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
                    icon: Icons.school_outlined,
                    activeIcon: Icons.school_rounded,
                    label: 'Kurslar',
                  ),
                  _NavItem(
                    icon: Icons.bar_chart_rounded,
                    activeIcon: Icons.bar_chart_rounded,
                    label: studentText(widget.language, 'progress'),
                  ),
                  _NavItem(
                    icon: Icons.forum_outlined,
                    activeIcon: Icons.forum_rounded,
                    label: 'Community',
                  ),
                  _NavItem(
                    icon: Icons.person_outline_rounded,
                    activeIcon: Icons.person_rounded,
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
            onRefresh: _loadDashboard,
            notificationCount: _unreadNotificationCount,
            onNotifications: _openNotifications,
            onMenu: _openProfileTab,
            onContinue: () => _openModulesTab(detail: true),
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
            onRefresh: _loadDashboard,
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
            onRefresh: _loadDashboard,
            notificationCount: _unreadNotificationCount,
            onNotifications: _openNotifications,
            onMenu: _openProfileTab,
            onContinue: () => _openModulesTab(detail: true),
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
            onRefresh: _loadDashboard,
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
          onOpenModule: (module) {
            if (!module.isUnlocked) return;
            setState(() {
              _selectedModule = module;
              _selectedTopic = _firstOpenTopic(module);
              _stage = _LearningStage.moduleDetail;
            });
          },
          notificationCount: _unreadNotificationCount,
          onNotifications: _openNotifications,
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
          onBack: () => setState(() => _stage = _LearningStage.moduleList),
          onOpenTopic: (topic) {
            if (topic.status == TopicStatus.locked) return;
            setState(() {
              _selectedTopic = topic;
              _stage = topic.requiresSubscription
                  ? _LearningStage.premiumPaywall
                  : _LearningStage.pdfLesson;
            });
          },
          onFinalExam: () => setState(() => _stage = _LearningStage.finalIntro),
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
          onBack: () => setState(() => _stage = _LearningStage.moduleDetail),
          onStartQuiz: _selectedTopic!.quizQuestions.isNotEmpty
              ? _openSelectedTopicQuiz
              : null,
          onOpenVideo: _topicHasVideoContent(_selectedTopic!)
              ? () => setState(() => _stage = _LearningStage.videoLesson)
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
          onBack: () => setState(() => _stage = _LearningStage.pdfLesson),
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
          questions: _selectedTopic!.quizQuestions,
          questionIndex: _quizQuestionIndex,
          selectedOption: _selectedOption,
          onSelected: (index) => setState(() => _selectedOption = index),
          onNext: _handleTopicQuizNext,
          onPrevious: _handleTopicQuizPrevious,
          onBack: () => setState(() => _stage = _LearningStage.videoLesson),
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
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
              child: Row(
                children: List.generate(widget.items.length, (index) {
                  final item = widget.items[index];
                  final isSelected = index == widget.selectedIndex;
                  final inactiveColor = isDark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF64748B);
                  final activeColor = isDark
                      ? Colors.white
                      : const Color(0xFF6C4DFF);

                  return Expanded(
                    child: GestureDetector(
                      onTap: () => widget.onTabChanged(index),
                      behavior: HitTestBehavior.opaque,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isSelected ? item.activeIcon : item.icon,
                            color: isSelected ? activeColor : inactiveColor,
                            size: 24,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: isSelected ? activeColor : inactiveColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
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
      padding: EdgeInsets.fromLTRB(20, 18, 20, 160.0 + bottomInset),
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
                style: TextStyle(
                  color: textColor,
                  fontSize: 24,
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
    required this.onProgress,
    required this.onQuizzes,
    required this.onBookmarks,
    required this.onMenu,
    required this.onRefresh,
    required this.notificationCount,
    required this.onNotifications,
  });

  final StudentDashboardData data;
  final VoidCallback onContinue;
  final VoidCallback onProgress;
  final VoidCallback onQuizzes;
  final VoidCallback onBookmarks;
  final VoidCallback onMenu;
  final Future<void> Function() onRefresh;
  final int notificationCount;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) {
    final overallPercent = (data.overallProgress * 100).round();
    final firstName = data.profile.firstName;
    final continueModule = data.continueModule;
    String t(String key) => studentText(_StudentLanguageScope.of(context), key);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final iconColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header — space-between with menu and notification bell
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            IconButton(
              tooltip: 'Profil va sozlamalar',
              onPressed: onMenu,
              icon: const Icon(Icons.menu_rounded, size: 28),
              color: iconColor,
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Yangilash',
                  onPressed: () => unawaited(onRefresh()),
                  icon: const Icon(Icons.refresh_rounded, size: 24),
                  color: iconColor,
                ),
                Badge.count(
                  isLabelVisible: notificationCount > 0,
                  count: notificationCount,
                  child: IconButton(
                    onPressed: onNotifications,
                    icon: const Icon(
                      Icons.notifications_none_rounded,
                      size: 28,
                    ),
                    color: iconColor,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),
        // Greeting
        Text(
          '${t('hello')}, $firstName! 👋',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
            fontSize: 28,
            color: textColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          t('welcome_to'),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: isDark
                ? Colors.white.withValues(alpha: .7)
                : const Color(0xFF64748B),
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 24),
        // Hero Banner
        _GlassCard(
          padding: const EdgeInsets.all(20),
          gradient: isDark
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF13103D), Color(0xFF0B0D21)],
                )
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFF3F2FF), Color(0xFFEBE9FF)],
                ),
          borderColor: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFF6C4DFF).withValues(alpha: 0.15),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t('keep_learning_growing'),
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF1E1B4B),
                        fontSize: 19,
                        height: 1.25,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      t('journey_starts'),
                      style: TextStyle(
                        color: isDark
                            ? Colors.white.withValues(alpha: .7)
                            : const Color(0xFF6C4DFF).withValues(alpha: .8),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
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
                          vertical: 8,
                        ),
                      ),
                      icon: Text(
                        t('continue'),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      label: const Icon(Icons.arrow_forward_rounded, size: 16),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Image.asset(
                'assets/images/flask_3d.png',
                width: 95,
                height: 95,
                fit: BoxFit.contain,
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        // Quick Access
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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _QuickAccessItem(
              icon: Icons.school_rounded,
              label: t('courses'),
              color: const Color(0xFF6C4DFF),
              onTap: onContinue,
            ),
            _QuickAccessItem(
              icon: Icons.bar_chart_rounded,
              label: t('my_progress'),
              color: const Color(0xFF10B981),
              onTap: onProgress,
            ),
            _QuickAccessItem(
              icon: Icons.help_outline_rounded,
              label: t('quizzes'),
              color: const Color(0xFF3B82F6),
              onTap: onQuizzes,
            ),
            _QuickAccessItem(
              icon: Icons.bookmark_rounded,
              label: t('bookmarks'),
              color: const Color(0xFFF59E0B),
              onTap: onBookmarks,
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

    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? .15 : .1),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: color.withValues(alpha: .1)),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: isDark
                  ? Colors.white.withValues(alpha: .9)
                  : const Color(0xFF0F172A),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
            ),
            padding: const EdgeInsets.all(4),
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
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6C4DFF).withValues(alpha: .1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Kardiologiya',
                        style: TextStyle(
                          color: Color(0xFF6C4DFF),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final percent = (module.progress * 100).round();

    // Choose category color and icon
    final Color categoryColor;
    final IconData categoryIcon;
    switch (module.category) {
      case 'Kardiologiya':
        categoryColor = const Color(0xFFFF2D55); // Crimson Red
        categoryIcon = Icons.favorite_rounded;
        break;
      case 'Biokimyo':
        categoryColor = const Color(0xFFFF9500); // Orange
        categoryIcon = Icons.science_rounded;
        break;
      case 'Gemotologiya':
        categoryColor = const Color(0xFFAF52DE); // Purple
        categoryIcon = Icons.bloodtype_rounded;
        break;
      case 'Mikrobiologiya':
        categoryColor = const Color(0xFF34C759); // Green
        categoryIcon = Icons.bug_report_rounded;
        break;
      default:
        categoryColor = const Color(0xFF6C4DFF); // Labproof Purple
        categoryIcon = Icons.school_rounded;
    }

    final String studentText = module.studentCount >= 1000
        ? '${(module.studentCount / 1000).toStringAsFixed(1)}k o\'quvchi'
        : '${module.studentCount} o\'quvchi';

    final cardBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final borderCol = isDark
        ? const Color(0xFF1E293B)
        : const Color(0xFFE2E8F0);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final mutedTextColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: module.isUnlocked ? onTap : null,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left side 3D/glass icon block
                  _CourseCoverBox(
                    imageUrl: module.coverUrl,
                    icon: categoryIcon,
                    color: module.isUnlocked
                        ? categoryColor
                        : mutedTextColor.withValues(alpha: 0.5),
                    size: 76,
                    radius: 16,
                  ),
                  const SizedBox(width: 16),
                  // Right side details block
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Category tag and bookmark icon
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: categoryColor.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: Text(
                                module.category,
                                style: TextStyle(
                                  color: categoryColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.bookmark_border_rounded,
                              size: 18,
                              color: isDark ? Colors.white30 : Colors.black26,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Title
                        Text(
                          module.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: module.isUnlocked
                                ? textColor
                                : textColor.withValues(alpha: 0.5),
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Lesson & Student Stats Row
                        Row(
                          children: [
                            Icon(
                              Icons.menu_book_rounded,
                              size: 13,
                              color: mutedTextColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${module.topics.length} ta dars',
                              style: TextStyle(
                                color: mutedTextColor,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Icon(
                              Icons.people_outline_rounded,
                              size: 13,
                              color: mutedTextColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              studentText,
                              style: TextStyle(
                                color: mutedTextColor,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        if (module.isUnlocked) ...[
                          const SizedBox(height: 12),
                          // Progress Row
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF1E293B)
                                        : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: FractionallySizedBox(
                                      widthFactor: module.progress,
                                      child: Container(
                                        height: 5,
                                        decoration: BoxDecoration(
                                          color: categoryColor,
                                          borderRadius: BorderRadius.circular(
                                            3,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '$percent%',
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ] else ...[
                          const SizedBox(height: 12),
                          // Locked text
                          Row(
                            children: [
                              Icon(
                                Icons.lock_outline_rounded,
                                size: 13,
                                color: mutedTextColor.withValues(alpha: 0.6),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Yopiq modul',
                                style: TextStyle(
                                  color: mutedTextColor.withValues(alpha: 0.6),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
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
    required this.onOpenModule,
    required this.notificationCount,
    required this.onNotifications,
  });

  final List<AcademyModule> modules;
  final _ModuleFilter filter;
  final Future<void> Function() onRefresh;
  final ValueChanged<_ModuleFilter> onFilterChanged;
  final ValueChanged<AcademyModule> onOpenModule;
  final int notificationCount;
  final VoidCallback onNotifications;

  @override
  State<_ModulesListScreen> createState() => _ModulesListScreenState();
}

class _ModulesListScreenState extends State<_ModulesListScreen> {
  String _searchQuery = '';
  String _selectedCategory = 'Barchasi';
  bool _showFilters = false;
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

    final categoryFiltered = statusFiltered.where((module) {
      if (_selectedCategory == 'Barchasi') return true;
      return module.category == _selectedCategory;
    }).toList();

    final filteredModules = categoryFiltered.where((module) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return module.title.toLowerCase().contains(q) ||
          module.description.toLowerCase().contains(q) ||
          module.category.toLowerCase().contains(q);
    }).toList();

    final categories = [
      'Barchasi',
      'Kardiologiya',
      'Biokimyo',
      'Gemotologiya',
      'Mikrobiologiya',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MobileHeader(
          title: 'Kurslar',
          subtitle: 'Bilimingizni yangi bosqichga olib chiqing',
          trailing: Badge.count(
            isLabelVisible: widget.notificationCount > 0,
            count: widget.notificationCount,
            child: IconButton(
              onPressed: widget.onNotifications,
              icon: Icon(
                Icons.notifications_none_rounded,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                size: 28,
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        // Search & Filter Row
        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFE2E8F0),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.2 : 0.02,
                      ),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
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
                    hintText: 'Kurs yoki darslarni qidirish...',
                    hintStyle: TextStyle(
                      color: isDark
                          ? const Color(0xFF64748B)
                          : const Color(0xFF94A3B8),
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: isDark
                          ? const Color(0xFF64748B)
                          : const Color(0xFF94A3B8),
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
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () {
                setState(() {
                  _showFilters = !_showFilters;
                });
              },
              child: Container(
                height: 52,
                width: 52,
                decoration: BoxDecoration(
                  color: _showFilters
                      ? const Color(0xFF6C4DFF)
                      : (isDark ? const Color(0xFF0F172A) : Colors.white),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _showFilters
                        ? const Color(0xFF6C4DFF)
                        : (isDark
                              ? const Color(0xFF1E293B)
                              : const Color(0xFFE2E8F0)),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.2 : 0.02,
                      ),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    Icons.tune_rounded,
                    color: _showFilters
                        ? Colors.white
                        : (isDark ? Colors.white70 : const Color(0xFF64748B)),
                    size: 22,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        // Horizontal Categories List
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: categories.map((cat) {
              final isSelected = _selectedCategory == cat;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedCategory = cat;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF6C4DFF)
                          : (isDark
                                ? const Color(0xFF1E293B)
                                : const Color(0xFFF1F5F9)),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF6C4DFF)
                            : Colors.transparent,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      cat,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : (isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF64748B)),
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        if (_showFilters) ...[
          const SizedBox(height: 18),
          // Filter sub-tabs
          Row(
            children: [
              for (final item in const [
                (_ModuleFilter.all, 'Barchasi'),
                (_ModuleFilter.open, 'Aktiv'),
                (_ModuleFilter.completed, 'Tugallangan'),
                (_ModuleFilter.locked, 'Yopiq'),
              ])
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal:
                          item.$1 == _ModuleFilter.all ||
                              item.$1 == _ModuleFilter.locked
                          ? 2.0
                          : 4.0,
                    ),
                    child: InkWell(
                      onTap: () => widget.onFilterChanged(item.$1),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: widget.filter == item.$1
                              ? const Color(0xFF6C4DFF).withValues(alpha: 0.12)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: widget.filter == item.$1
                                ? const Color(0xFF6C4DFF).withValues(alpha: 0.3)
                                : Colors.transparent,
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            item.$2,
                            style: TextStyle(
                              color: widget.filter == item.$1
                                  ? (isDark
                                        ? Colors.white
                                        : const Color(0xFF6C4DFF))
                                  : (isDark
                                        ? const Color(0xFF94A3B8)
                                        : const Color(0xFF64748B)),
                              fontSize: 12,
                              fontWeight: widget.filter == item.$1
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: 20),
        // Modules List View
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

class _JourneyItem {
  const _JourneyItem(this.label, this.icon);

  final String label;
  final IconData icon;
}

class _JourneyNoteCard extends StatelessWidget {
  const _JourneyNoteCard({
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.items,
  });

  final String title;
  final String subtitle;
  final Color accent;
  final List<_JourneyItem> items;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: accent.withValues(alpha: .06),
      borderColor: accent.withValues(alpha: .14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBadge(icon: Icons.route_rounded, color: accent, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in items)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: accent.withValues(alpha: .12)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(item.icon, size: 14, color: accent),
                      const SizedBox(width: 6),
                      Text(
                        item.label,
                        style: TextStyle(
                          color: accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModuleDetailScreen extends StatelessWidget {
  const _ModuleDetailScreen({
    required this.module,
    required this.selectedTopic,
    required this.onBack,
    required this.onOpenTopic,
    required this.onFinalExam,
  });

  final AcademyModule module;
  final TopicLesson? selectedTopic;
  final VoidCallback onBack;
  final ValueChanged<TopicLesson> onOpenTopic;
  final VoidCallback onFinalExam;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final percent = (module.progress * 100).round();

    // Determine category accent color and icon
    final Color categoryColor;
    final IconData categoryIcon;
    switch (module.category) {
      case 'Kardiologiya':
        categoryColor = const Color(0xFFFF2D55); // Crimson Red
        categoryIcon = Icons.favorite_rounded;
        break;
      case 'Biokimyo':
        categoryColor = const Color(0xFFFF9500); // Orange
        categoryIcon = Icons.science_rounded;
        break;
      case 'Gemotologiya':
        categoryColor = const Color(0xFFAF52DE); // Purple
        categoryIcon = Icons.bloodtype_rounded;
        break;
      case 'Mikrobiologiya':
        categoryColor = const Color(0xFF34C759); // Green
        categoryIcon = Icons.bug_report_rounded;
        break;
      default:
        categoryColor = const Color(0xFF6C4DFF); // Labproof Purple
        categoryIcon = Icons.school_rounded;
    }

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

        // Gorgeous Premium Hero Header Card
        Container(
          width: double.infinity,
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
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CourseCoverBox(
                      imageUrl: module.coverUrl,
                      icon: categoryIcon,
                      color: categoryColor,
                      size: 64,
                      radius: 14,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            module.title,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            module.description.isEmpty
                                ? 'Ushbu modul orqali tegishli yo\'nalish bo\'yicha nazariy va amaliy ko\'nikmalarni o\'rganasiz.'
                                : module.description,
                            style: TextStyle(
                              color: mutedTextColor,
                              fontSize: 12,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(color: borderCol, height: 1),
                const SizedBox(height: 16),

                // Progress Bar Inside Hero
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Tugallanish ko‘rsatkichi',
                      style: TextStyle(
                        color: mutedTextColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '$percent%',
                      style: TextStyle(
                        color: categoryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
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
                      widthFactor: module.progress,
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: categoryColor,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
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
                onTap: () => onOpenTopic(topic),
              );
            },
          ),

        const SizedBox(height: 24),
        // Final exam button if module is completed or near completion
        if (module.progress >= 0.75) ...[
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
    required this.onTap,
  });

  final TopicLesson topic;
  final int index;
  final Color categoryColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final locked = topic.status == TopicStatus.locked;
    final completed = topic.status == TopicStatus.completed;

    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final borderCol = isDark
        ? const Color(0xFF1E293B)
        : const Color(0xFFE2E8F0);
    final cardBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final mutedTextColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);

    final Color accent = completed
        ? AppColors.successGreen
        : locked
        ? mutedTextColor.withOpacity(0.4)
        : categoryColor;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderCol, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: locked ? null : onTap,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Topic cover / status indicator
                    if (topic.coverUrl.trim().isNotEmpty)
                      _CourseCoverBox(
                        imageUrl: topic.coverUrl,
                        icon: locked
                            ? Icons.lock_rounded
                            : completed
                            ? Icons.check_rounded
                            : Icons.play_arrow_rounded,
                        color: accent,
                        size: 44,
                        radius: 14,
                      )
                    else
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: completed
                              ? AppColors.successGreen.withValues(alpha: 0.08)
                              : locked
                              ? (isDark
                                    ? const Color(0xFF1E293B)
                                    : const Color(0xFFF1F5F9))
                              : categoryColor.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: completed
                                ? AppColors.successGreen.withValues(alpha: 0.18)
                                : locked
                                ? Colors.transparent
                                : categoryColor.withValues(alpha: 0.18),
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: completed
                              ? const Icon(
                                  Icons.check_rounded,
                                  color: AppColors.successGreen,
                                  size: 18,
                                )
                              : locked
                              ? Icon(
                                  Icons.lock_rounded,
                                  color: mutedTextColor.withValues(alpha: 0.5),
                                  size: 16,
                                )
                              : Text(
                                  index.toString().padLeft(2, '0'),
                                  style: TextStyle(
                                    color: categoryColor,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    const SizedBox(width: 16),
                    // Topic details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            topic.title,
                            style: TextStyle(
                              color: locked
                                  ? textColor.withValues(alpha: 0.5)
                                  : textColor,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            topic.summary.isEmpty
                                ? 'Mavzu bo‘yicha dars va amaliy topshiriqlar.'
                                : topic.summary,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: mutedTextColor,
                              fontSize: 12,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Right status action label / score
                    if (completed)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.successGreen.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${(topic.quizScore * 100).round()}% test',
                          style: const TextStyle(
                            color: AppColors.successGreen,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    else if (!locked)
                      Icon(
                        Icons.play_circle_filled_rounded,
                        color: categoryColor,
                        size: 24,
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

class _PdfLessonScreen extends StatelessWidget {
  const _PdfLessonScreen({
    required this.topic,
    required this.onBack,
    required this.onComplete,
    this.onStartQuiz,
    this.onOpenVideo,
  });

  final TopicLesson topic;
  final VoidCallback onBack;
  final Future<void> Function() onComplete;
  final VoidCallback? onStartQuiz;
  final VoidCallback? onOpenVideo;

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
    final readingMaterials = topic.readingMaterials;
    final video = topic.videoMaterials.isNotEmpty
        ? topic.videoMaterials.first
        : null;
    final videoUrl = video?.url.trim().isNotEmpty == true
        ? video!.url
        : topic.videoUrl;

    Widget section(String title, Widget child) {
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
            Text(
              title,
              style: TextStyle(
                color: textColor,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
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
          subtitle: 'Matn, PDF, video va test bitta sahifada',
          onBack: onBack,
        ),
        const SizedBox(height: 18),
        _GlassCard(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF24116D), Color(0xFF0B1220)],
          ),
          child: Text(
            topic.summary.isEmpty
                ? 'Bu mavzuga biriktirilgan barcha materiallar quyida ketma-ket ko‘rinadi.'
                : topic.summary,
            style: TextStyle(
              color: Colors.white.withValues(alpha: .8),
              height: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 16),
        section(
          '📄 Dars matni / PDF',
          readingMaterials.isEmpty && topic.formula.trim().isEmpty
              ? Text(
                  'Bu mavzu uchun matn yoki PDF hali biriktirilmagan.',
                  style: TextStyle(color: mutedTextColor),
                )
              : Column(
                  children: [
                    for (final material in readingMaterials) ...[
                      _InlineLessonMaterial(material: material),
                      const SizedBox(height: 12),
                    ],
                    if (readingMaterials.isEmpty &&
                        topic.formula.trim().isNotEmpty)
                      _InlineTextBlock(
                        title: topic.pdfTitle,
                        body: topic.formula,
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 16),
        section(
          '🎥 Video dars',
          videoUrl.trim().isEmpty
              ? Text(
                  'Bu mavzu uchun video hali biriktirilmagan.',
                  style: TextStyle(color: mutedTextColor),
                )
              : _InlineVideoPlayer(
                  url: videoUrl,
                  title:
                      video?.title ??
                      (topic.videoTitle.isEmpty
                          ? 'Video dars'
                          : topic.videoTitle),
                  onOpenFull: onOpenVideo,
                ),
        ),
        const SizedBox(height: 16),
        section(
          '📝 Test',
          topic.quizQuestions.isEmpty
              ? Text(
                  'Bu mavzu uchun test hali qo‘shilmagan.',
                  style: TextStyle(color: mutedTextColor),
                )
              : _InlineQuizPreview(
                  questionCount: topic.quizQuestions.length,
                  onStart: onStartQuiz,
                ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => unawaited(onComplete()),
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
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

class _InlineLessonMaterial extends StatelessWidget {
  const _InlineLessonMaterial({required this.material});

  final LessonMaterial material;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final url = material.url.trim();
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
              child: _RichLessonBody(body: material.body),
            ),
          if (isPdfUrl && hasUrl)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 520, 
                  child: SfPdfViewer.network(url),
                ),
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

class _InlineTextBlock extends StatelessWidget {
  const _InlineTextBlock({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.studentPrimary.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.studentPrimary.withValues(alpha: .14),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.trim().isEmpty ? 'Dars matni' : title,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          _RichLessonBody(body: body),
        ],
      ),
    );
  }
}

class _RichLessonBody extends StatelessWidget {
  const _RichLessonBody({required this.body});

  final String body;

  static final RegExp _markdownImagePattern = RegExp(
    r'^!\[([^\]]*)\]\(([^\)]+)\)$',
  );

  bool _isImageUrl(String value) {
    final lower = value.toLowerCase().trim();
    return (lower.startsWith('http://') || lower.startsWith('https://')) &&
        (lower.contains('.png') ||
            lower.contains('.jpg') ||
            lower.contains('.jpeg') ||
            lower.contains('.webp') ||
            lower.contains('.gif'));
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
      final match = _markdownImagePattern.firstMatch(line);
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

class _InlineQuizPreview extends StatelessWidget {
  const _InlineQuizPreview({required this.questionCount, this.onStart});

  final int questionCount;
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.successGreen.withValues(alpha: .12),
            AppColors.studentPrimary.withValues(alpha: .08),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.successGreen.withValues(alpha: .2)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.quiz_rounded,
            color: AppColors.successGreen,
            size: 34,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              '$questionCount ta savoldan iborat kreativ test tayyor.',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          FilledButton.icon(
            onPressed: onStart,
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Boshlash'),
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
    this.onOpenFull,
  });

  final String url;
  final String title;
  final VoidCallback? onOpenFull;

  @override
  State<_InlineVideoPlayer> createState() => _InlineVideoPlayerState();
}

class _InlineVideoPlayerState extends State<_InlineVideoPlayer> {
  YoutubePlayerController? _youtubeController;
  VideoPlayerController? _videoController;
  bool _initializing = false;

  @override
  void initState() {
    super.initState();
    _configure();
  }

  @override
  void didUpdateWidget(covariant _InlineVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
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
    _youtubeController?.close();
    _youtubeController = null;
    _videoController?.dispose();
    _videoController = null;
  }

  void _configure() {
    final url = widget.url.trim();
    final youtubeId = YoutubePlayerController.convertUrlToId(url);
    if (youtubeId != null) {
      _youtubeController = YoutubePlayerController.fromVideoId(
        videoId: youtubeId,
        autoPlay: false,
        params: const YoutubePlayerParams(
          showControls: true,
          showFullscreenButton: true,
          enableJavaScript: true,
        ),
      );
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) return;
    _initializing = true;
    final controller = VideoPlayerController.networkUrl(uri);
    _videoController = controller;
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

  @override
  Widget build(BuildContext context) {
    final youtube = _youtubeController;
    final video = _videoController;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: youtube != null
                ? YoutubePlayer(controller: youtube)
                : video != null && video.value.isInitialized
                ? Stack(
                    alignment: Alignment.center,
                    children: [
                      VideoPlayer(video),
                      IconButton.filled(
                        onPressed: () {
                          setState(() {
                            video.value.isPlaying
                                ? video.pause()
                                : video.play();
                          });
                        },
                        icon: Icon(
                          video.value.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                        ),
                      ),
                    ],
                  )
                : Container(
                    color: Colors.black12,
                    alignment: Alignment.center,
                    child: _initializing
                        ? const CircularProgressIndicator()
                        : const Text('Video URL ilova ichida ochilmadi.'),
                  ),
          ),
        ),
        if (widget.onOpenFull != null) ...[
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: widget.onOpenFull,
              icon: const Icon(Icons.fullscreen_rounded),
              label: const Text('Katta ekranda ko‘rish'),
            ),
          ),
        ],
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
  double _speed = 1;
  bool _playing = false;
  YoutubePlayerController? _youtubeController;
  String? _youtubeVideoId;

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
    _youtubeVideoId = videoId;
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
    _youtubeVideoId = null;
  }

  void _setPlaybackSpeed(double speed) {
    setState(() => _speed = speed);
    unawaited(_youtubeController?.setPlaybackRate(speed));
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topic = widget.topic;
    final progress = _playing ? .45 : .2;
    final youtubeController = _youtubeController;

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
          title: topic.title,
          subtitle: _t(context, 'video_lesson'),
          onBack: widget.onBack,
        ),
        const SizedBox(height: 24),
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
              youtubeController == null
                  ? Container(
                      height: 210,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E293B).withValues(alpha: 0.3)
                            : const Color(0xFFF8FAFC),
                      ),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: CustomPaint(painter: _CircuitPainter()),
                          ),
                          Center(
                            child: IconButton(
                              tooltip: _playing ? 'Pause' : 'Play',
                              onPressed: () =>
                                  setState(() => _playing = !_playing),
                              style: IconButton.styleFrom(
                                backgroundColor: const Color(0xFF6C4DFF),
                                foregroundColor: Colors.white,
                                fixedSize: const Size(64, 64),
                                shadowColor: const Color(
                                  0xFF6C4DFF,
                                ).withValues(alpha: 0.3),
                                elevation: 8,
                                shape: const CircleBorder(),
                              ),
                              icon: Icon(
                                _playing
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                size: 36,
                              ),
                            ),
                          ),
                          Positioned(
                            left: 14,
                            right: 14,
                            bottom: 14,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: cardBg.withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: borderCol),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    '00:00',
                                    style: TextStyle(
                                      color: textColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Container(
                                      height: 4,
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? const Color(0xFF334155)
                                            : const Color(0xFFE2E8F0),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: FractionallySizedBox(
                                          widthFactor: progress,
                                          child: Container(
                                            height: 4,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF6C4DFF),
                                              borderRadius:
                                                  BorderRadius.circular(2),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    '${topic.duration.inMinutes}:${(topic.duration.inSeconds % 60).toString().padLeft(2, '0')}',
                                    style: TextStyle(
                                      color: textColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : YoutubePlayer(
                      controller: youtubeController,
                      aspectRatio: 16 / 9,
                    ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      topic.videoTitle.isEmpty
                          ? 'Video dars'
                          : topic.videoTitle,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      youtubeController == null
                          ? _t(context, 'video_external_hint')
                          : _t(context, 'video_inapp_hint'),
                      style: TextStyle(
                        color: mutedTextColor,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _t(context, 'playback_speed'),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final speed in const [.75, 1.0, 1.25, 1.5])
                          ChoiceChip(
                            label: Text(
                              '${speed}x',
                              style: TextStyle(
                                color: _speed == speed
                                    ? const Color(0xFF6C4DFF)
                                    : textColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            selected: _speed == speed,
                            onSelected: (_) => _setPlaybackSpeed(speed),
                            selectedColor: const Color(
                              0xFF6C4DFF,
                            ).withValues(alpha: 0.12),
                            checkmarkColor: const Color(0xFF6C4DFF),
                            side: BorderSide(
                              color: _speed == speed
                                  ? const Color(
                                      0xFF6C4DFF,
                                    ).withValues(alpha: 0.3)
                                  : borderCol,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (youtubeController == null)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _openVideo,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF6C4DFF),
                            side: const BorderSide(
                              color: Color(0xFF6C4DFF),
                              width: 1.5,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: const Icon(Icons.open_in_new_rounded),
                          label: Text(
                            _t(context, 'open_external_video'),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF6C4DFF,
                          ).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(
                              0xFF6C4DFF,
                            ).withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.play_circle_outline_rounded,
                              color: Color(0xFF6C4DFF),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'YouTube ID: $_youtubeVideoId',
                              style: const TextStyle(
                                color: Color(0xFF6C4DFF),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
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
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: widget.onComplete,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.successGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(Icons.check_circle_rounded),
            label: Text(
              _t(context, 'finish_video'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

class _TopicQuizScreen extends StatelessWidget {
  const _TopicQuizScreen({
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
          title: '${question.topic} testi',
          subtitle: _t(context, 'topic_quiz'),
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
        const SizedBox(height: 32),
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

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: selected
                  ? const Color(0xFF6C4DFF).withValues(alpha: 0.12)
                  : cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? const Color(0xFF6C4DFF) : borderCol,
                width: selected ? 2.0 : 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFF6C4DFF)
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
                          : (isDark ? Colors.white70 : const Color(0xFF6C4DFF)),
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
                      fontSize: 15,
                      fontWeight: selected ? FontWeight.bold : FontWeight.w600,
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
      return ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Image.network(
          url,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _mediaFallback(
            Icons.image_not_supported_rounded,
            'Rasm ochilmadi',
          ),
        ),
      );
    }
    if (question.isVideoQuestion) {
      return _InlineVideoPlayer(url: url, title: 'Savol videosi');
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
    required this.onContinue,
    required this.onFinalExam,
  });

  final TopicLesson topic;
  final int score;
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
                      label: 'Natija manbasi',
                      value: 'Supabase',
                    ),
                    const Divider(height: 16),
                    const _ResultStat(
                      label: 'Keyingi bosqich',
                      value: 'Mavzular',
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
              if (isSuccess) ...[
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
                  backgroundColor: isDark
                      ? Colors.white.withValues(alpha: .06)
                      : Colors.black.withValues(alpha: .04),
                  foregroundColor: isDark
                      ? Colors.white
                      : const Color(0xFF0F172A),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Badge.count(
                isLabelVisible: notificationCount > 0,
                count: notificationCount,
                child: IconButton(
                  onPressed: onNotifications,
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MobileHeader(
          title: _t(context, 'progress'),
          subtitle: 'Modul progressi, yutuqlar va sertifikatlar markazi',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton.filledTonal(
                tooltip: 'Yangilash',
                onPressed: () => unawaited(onRefresh()),
                icon: const Icon(Icons.refresh_rounded),
              ),
              const SizedBox(width: 8),
              Badge.count(
                isLabelVisible: notificationCount > 0,
                count: notificationCount,
                child: IconButton(
                  onPressed: onNotifications,
                  icon: Icon(
                    Icons.notifications_none_rounded,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : const Color(0xFF0F172A),
                    size: 28,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _JourneyNoteCard(
          title: 'Progress logikasi',
          subtitle:
              'Progress faqat kirilgan ekran bilan emas, bosqichlar yakunlanganda oshadi.',
          accent: AppColors.amber,
          items: const [
            _JourneyItem('PDF tugashi', Icons.picture_as_pdf_rounded),
            _JourneyItem('Video tugashi', Icons.play_circle_outline_rounded),
            _JourneyItem('Quiz', Icons.quiz_outlined),
            _JourneyItem(
              'Final / Sertifikat',
              Icons.workspace_premium_outlined,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: AppColors.studentPrimary.withValues(alpha: 0.1),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.studentPrimary.withValues(alpha: 0.05),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  CircularScore(
                    value: data.overallProgress,
                    label:
                        '${data.completedModules} / ${data.modules.length} modul',
                    size: 100,
                    color: AppColors.studentPrimary,
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      children: [
                        _ProfileStat(
                          icon: Icons.flag_rounded,
                          label: 'Umumiy progress',
                          value: '$overallPercent%',
                        ),
                        const SizedBox(height: 12),
                        _ProfileStat(
                          icon: Icons.menu_book_rounded,
                          label: 'Faol modullar',
                          value: data.activeModuleCount.toString(),
                        ),
                        const SizedBox(height: 12),
                        _ProfileStat(
                          icon: Icons.workspace_premium_rounded,
                          label: 'Sertifikatlar',
                          value: data.certificateCount.toString(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (data.modules.isNotEmpty) ...[
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.studentPrimary.withValues(alpha: .15),
                    ),
                  ),
                  child: Text(
                    'Real progress mavzular bajarilishi, yakuniy test va sertifikatlar bilan birga hisoblanadi.',
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodySmall?.color,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (data.modules.isEmpty)
          _EmptyStateCard(
            icon: Icons.track_changes_outlined,
            title: 'Progress hali yo‘q',
            message:
                'Modullar biriktirilib o‘qish boshlanganidan keyin, bu yerda real o‘sish va yutuqlar ko‘rinadi.',
            actionLabel: 'Yangilash',
            onAction: () => unawaited(onRefresh()),
          )
        else
          ...data.modules.map(
            (module) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: module.isPassed
                        ? AppColors.successGreen.withValues(alpha: 0.2)
                        : AppColors.studentPrimary.withValues(alpha: 0.1),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: module.isPassed
                                ? AppColors.successGreen.withValues(alpha: 0.1)
                                : AppColors.studentPrimary.withValues(
                                    alpha: 0.1,
                                  ),
                            borderRadius: BorderRadius.circular(16),
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
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            '${module.order}-modul: ${module.title}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          '${(module.progress * 100).round()}%',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: module.isPassed
                                ? AppColors.successGreen
                                : AppColors.studentPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    ProgressLine(
                      value: module.progress,
                      color: module.isPassed
                          ? AppColors.successGreen
                          : AppColors.studentPrimary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      module.isPassed
                          ? 'Modul yakunlandi va keyingi blok ochilgan.'
                          : '${module.topics.where((topic) => topic.status == TopicStatus.completed).length} ta mavzu tugallangan, final test kutilmoqda.',
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodySmall?.color,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
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
    final dark = themeMode == ThemeMode.dark;
    final iconColor = dark ? Colors.white : const Color(0xFF0F172A);
    final completionPercent = profile.profileCompletionPercent;
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 900;

    // Header Widget
    final headerWidget = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _t(context, 'profile'),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _t(context, 'profile_subtitle'),
                style: TextStyle(
                  fontSize: 13,
                  color: dark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Badge.count(
          isLabelVisible: notificationCount > 0,
          count: notificationCount,
          child: IconButton(
            onPressed: onNotifications,
            tooltip: _t(context, 'notifications'),
            icon: Icon(
              Icons.notifications_none_rounded,
              color: iconColor,
              size: 26,
            ),
          ),
        ),
        IconButton(
          onPressed: () => unawaited(onEditProfile()),
          tooltip: _t(context, 'edit_profile'),
          icon: Icon(Icons.settings_outlined, color: iconColor, size: 26),
        ),
      ],
    );

    // User Card
    final userCardWidget = Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.studentPrimary.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.studentPrimary.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              _ProfileAvatar(profile: profile, size: 80),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: AppColors.studentPrimary,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).cardColor,
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.camera_alt_rounded,
                    size: 13,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.fullName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  profile.phone.isEmpty
                      ? _t(context, 'phone_not_set')
                      : profile.displayPhone,
                  style: TextStyle(
                    fontSize: 13,
                    color: dark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.studentPrimary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.school_rounded,
                        size: 14,
                        color: AppColors.studentPrimary,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Student',
                        style: TextStyle(
                          color: AppColors.studentPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => unawaited(onEditProfile()),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.studentPrimary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.edit_rounded,
                size: 17,
                color: AppColors.studentPrimary,
              ),
            ),
          ),
        ],
      ),
    );

    // Profile Completeness Card
    final completenessCardWidget = GestureDetector(
      onTap: () => unawaited(onEditProfile()),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppColors.studentPrimary.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 72,
              height: 72,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: completionPercent / 100,
                    strokeWidth: 6,
                    backgroundColor: AppColors.studentPrimary.withValues(
                      alpha: 0.12,
                    ),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.studentPrimary,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$completionPercent%',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'profil',
                        style: TextStyle(
                          fontSize: 10,
                          color: dark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Profil to\'liqligi',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Rasm, manzil va shaxsiy ma\'lumotlar to\'liq bo\'lsa admin va tizim sizni aniqroq taniydi.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: dark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 15,
              color: dark ? const Color(0xFF94A3B8) : const Color(0xFF94A3B8),
            ),
          ],
        ),
      ),
    );

    // Stat Cards
    final statCardsWidget = Row(
      children: [
        Expanded(
          child: _ProfileStatCard(
            icon: Icons.menu_book_rounded,
            value: data.activeModuleCount.toString(),
            label: 'O\'rganayotgan\nmodullar',
            color: AppColors.studentPrimary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ProfileStatCard(
            icon: Icons.check_circle_outline_rounded,
            value: data.completedModules.toString(),
            label: 'Tugatilgan\nmodullar',
            color: AppColors.successGreen,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ProfileStatCard(
            icon: Icons.bar_chart_rounded,
            value: '${data.averageScore}%',
            label: 'Umumiy\nnatija',
            color: AppColors.amber,
          ),
        ),
      ],
    );

    // Settings Card
    final settingsCardWidget = Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.studentPrimary.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        children: [
          _SettingsRow(
            icon: Icons.language_rounded,
            label: _t(context, 'language'),
            subtitle: language.label,
            trailing: _CompactLanguageSelector(
              language: language,
              onChanged: onLanguageChanged,
            ),
          ),
          const Divider(height: 1, indent: 64),
          _SettingsRow(
            icon: Icons.notifications_none_rounded,
            label: _t(context, 'notifications'),
            subtitle: notificationsEnabled
                ? _t(context, 'notifications_enabled_hint')
                : _t(context, 'notifications_disabled_hint'),
            trailing: Switch(
              value: notificationsEnabled,
              onChanged: onNotificationsChanged,
              activeTrackColor: AppColors.studentPrimary.withValues(alpha: 0.5),
              activeThumbColor: AppColors.studentPrimary,
            ),
          ),
          const Divider(height: 1, indent: 64),
          _SettingsRow(
            icon: Icons.dark_mode_outlined,
            label: _t(context, 'dark_mode'),
            subtitle: dark
                ? _t(context, 'dark_mode_enabled')
                : _t(context, 'light_mode_enabled'),
            trailing: Switch(
              value: dark,
              onChanged: (value) =>
                  onThemeChanged(value ? ThemeMode.dark : ThemeMode.light),
              activeTrackColor: AppColors.studentPrimary.withValues(alpha: 0.5),
              activeThumbColor: AppColors.studentPrimary,
            ),
          ),
          const Divider(height: 1, indent: 64),
          _SettingsRow(
            icon: Icons.support_agent_rounded,
            label: _t(context, 'contact_admin'),
            subtitle: _t(context, 'contact_admin_subtitle'),
            trailing: IconButton(
              tooltip: _t(context, 'send_message'),
              onPressed: () => unawaited(onContactAdmin()),
              icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
            ),
          ),
          const Divider(height: 1, indent: 64),
          _SettingsRow(
            icon: Icons.system_update_alt_rounded,
            label: _t(context, 'check_updates'),
            subtitle: _t(context, 'check_updates_subtitle'),
            trailing: IconButton(
              tooltip: _t(context, 'check_updates'),
              onPressed: () => unawaited(onCheckForUpdate()),
              icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
            ),
          ),
          const Divider(height: 1, indent: 64),
          _SettingsRow(
            icon: Icons.logout_rounded,
            label: _t(context, 'logout'),
            subtitle: _t(context, 'close_session'),
            iconColor: AppColors.errorRed,
            trailing: IconButton(
              tooltip: _t(context, 'logout'),
              onPressed: onSignOut,
              icon: const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: AppColors.errorRed,
              ),
            ),
          ),
        ],
      ),
    );

    // Module Progress column contents (Column 2)
    final moduleProgressList = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Modul progressi',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 16),
        if (data.modules.isEmpty)
          _EmptyStateCard(
            icon: Icons.track_changes_outlined,
            title: 'Progress hali yo‘q',
            message:
                'Modullar biriktirilib o‘qish boshlanganidan keyin, bu yerda real o‘sish va yutuqlar ko‘rinadi.',
            actionLabel: 'Yangilash',
            onAction: () => unawaited(Future.value()),
          )
        else
          ...data.modules.map(
            (module) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: module.isPassed
                        ? AppColors.successGreen.withValues(alpha: 0.2)
                        : AppColors.studentPrimary.withValues(alpha: 0.1),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: module.isPassed
                                ? AppColors.successGreen.withValues(alpha: 0.1)
                                : AppColors.studentPrimary.withValues(
                                    alpha: 0.1,
                                  ),
                            borderRadius: BorderRadius.circular(16),
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
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            '${module.order}-modul: ${module.title}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          '${(module.progress * 100).round()}%',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: module.isPassed
                                ? AppColors.successGreen
                                : AppColors.studentPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    ProgressLine(
                      value: module.progress,
                      color: module.isPassed
                          ? AppColors.successGreen
                          : AppColors.studentPrimary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      module.isPassed
                          ? 'Modul yakunlandi va keyingi blok ochilgan.'
                          : '${module.topics.where((topic) => topic.status == TopicStatus.completed).length} ta mavzu tugallangan.',
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodySmall?.color,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );

    // Certificates column contents (Column 3)
    final passedModules = data.modules.where((m) => m.isPassed).toList();
    final certificatesList = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sertifikatlar',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 16),
        if (passedModules.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppColors.studentPrimary.withValues(alpha: 0.1),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.workspace_premium_outlined,
                  color: AppColors.studentPrimary.withValues(alpha: 0.4),
                  size: 48,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Sertifikatlar mavjud emas',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Kurs modullarini to\'liq tugatib, yakuniy imtihondan o\'ting va rasmiy sertifikatga ega bo\'ling.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: dark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          ...passedModules.map((module) {
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppColors.amber.withValues(alpha: 0.2),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.amber.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.amber.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.workspace_premium_rounded,
                      color: AppColors.amber,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${module.title} kursi sertifikati',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'ID: LP-${module.id.toUpperCase()}-${(profile.fullName.hashCode % 1000000).toString().padLeft(6, '0')}',
                          style: TextStyle(
                            fontSize: 12,
                            color: dark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Sertifikat yuklab olinmoqda...'),
                              ),
                            );
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.download_rounded,
                                size: 14,
                                color: AppColors.studentPrimary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Yuklab olish',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.studentPrimary,
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
            );
          }),
      ],
    );

    if (isDesktop) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          headerWidget,
          const SizedBox(height: 20),
          statCardsWidget,
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Column 1: Profile Info
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    userCardWidget,
                    const SizedBox(height: 14),
                    completenessCardWidget,
                    const SizedBox(height: 14),
                    settingsCardWidget,
                    const SizedBox(height: 14),
                    Center(
                      child: Text(
                        '${_t(context, 'version_label')} v$appVersionName',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              // Column 2: Module Progress List
              Expanded(flex: 4, child: moduleProgressList),
              const SizedBox(width: 24),
              // Column 3: Certificates
              Expanded(flex: 3, child: certificatesList),
            ],
          ),
        ],
      );
    }

    // Fallback: Mobile Layout
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        headerWidget,
        const SizedBox(height: 20),
        userCardWidget,
        const SizedBox(height: 14),
        completenessCardWidget,
        const SizedBox(height: 14),
        statCardsWidget,
        const SizedBox(height: 20),
        settingsCardWidget,
        const SizedBox(height: 14),
        Center(
          child: Text(
            '${_t(context, 'version_label')} v$appVersionName',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
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

class _ProfileCompletionCard extends StatelessWidget {
  const _ProfileCompletionCard({required this.profile});

  final StudentProfile profile;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.studentPrimary.withValues(alpha: .15),
        ),
      ),
      child: Row(
        children: [
          CircularScore(
            value: profile.profileCompletionPercent / 100,
            label: 'profil',
            size: 74,
            color: AppColors.studentPrimary,
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Profil to‘liqligi',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  'Rasm, manzil va shaxsiy ma’lumotlar to‘liq bo‘lsa admin va tizim sizni aniqroq taniydi.',
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodySmall?.color,
                    fontSize: 13,
                    height: 1.4,
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

class _ProfileStatCard extends StatelessWidget {
  const _ProfileStatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.trailing,
    this.iconColor = AppColors.studentPrimary,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final Widget trailing;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: iconColor == AppColors.errorRed ? iconColor : null,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodySmall?.color,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          trailing,
        ],
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

  @override
  void initState() {
    super.initState();
    try {
      globalContext.setProperty(
        'triggerSupportSubmit'.toJS,
        ((JSString subject, JSString body) {
          _subjectController.text = subject.toDart;
          _messageController.text = body.toDart;
          _submit();
        }).toJS,
      );
    } catch (_) {}
  }

  final _audioRecorder = AudioRecorder();
  Timer? _voiceTimer;
  bool _sending = false;
  bool _showAttachmentTray = false;
  bool _recordingVoice = false;
  int _voiceSeconds = 0;
  String _voiceExtension = 'wav';
  String _voiceMimeType = 'audio/wav';
  _ChatAttachmentDraft? _attachment;

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
      Navigator.of(context).pop(true);
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

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({
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
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryBlue, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _CompactLanguageSelector extends StatelessWidget {
  const _CompactLanguageSelector({
    required this.language,
    required this.onChanged,
  });

  final AppLanguage language;
  final ValueChanged<AppLanguage> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () async {
        final picked = await _showSelectionSheet<AppLanguage>(
          context,
          title: _t(context, 'language'),
          items: AppLanguage.values,
          initialValue: language,
          labelBuilder: (item) => item.label,
          subtitleBuilder: (item) => languageOptionDescription(language, item),
          leadingBuilder: (item, selected) => Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.primaryBlue.withValues(alpha: .12)
                  : AppColors.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                item.shortLabel,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: selected ? AppColors.primaryBlue : AppColors.navy,
                ),
              ),
            ),
          ),
        );
        if (picked != null) onChanged(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.primaryBlue.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.primaryBlue.withValues(alpha: .12),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.language_rounded, size: 18),
            const SizedBox(width: 8),
            Text(
              language.shortLabel,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
          ],
        ),
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

  @override
  void initState() {
    super.initState();
    _firstNameController.text = widget.profile.firstName;
    _lastNameController.text = widget.profile.lastName;
    _phoneController.text = widget.profile.phone.replaceFirst('+998', '');
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

    if (firstName.length < 2 || lastName.length < 2) {
      _showError(_text('name_complete_error'));
      return;
    }
    if (!RegExp(r'^\d{9}$').hasMatch(phoneDigits)) {
      _showError(_text('phone_invalid'));
      return;
    }
    if (_gender.isEmpty) {
      _showError(_text('choose_gender_error'));
      return;
    }
    if (_region.isEmpty || _district.isEmpty) {
      _showError(_text('choose_region_district_error'));
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

      await _repository.updateStudentProfile(
        StudentProfileUpdate(
          firstName: firstName,
          lastName: lastName,
          phone: '+998$phoneDigits',
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
