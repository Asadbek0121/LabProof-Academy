// ignore_for_file: unused_element, unused_element_parameter

import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../data/models/academy_models.dart';
import '../../data/repositories/mock_academy_repository.dart';
import '../../data/repositories/supabase_academy_repository.dart';

double _adminContentMaxWidth(double width) {
  if (width >= 1800) return 1560;
  if (width >= 1500) return 1440;
  if (width >= 1260) return 1340;
  return width;
}

double _adminHorizontalPadding(double width) {
  if (width < 720) return 12;
  if (width < 1080) return 14;
  if (width < 1440) return 16;
  return 20;
}

double _adminSectionSpacing(double width) {
  if (width < 720) return 12;
  if (width < 1080) return 14;
  return 16;
}

class AdminShell extends StatefulWidget {
  const AdminShell({
    super.key,
    required this.themeMode,
    required this.onThemeChanged,
    required this.onSignOut,
    required this.onOpenStudent,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;
  final VoidCallback onSignOut;
  final VoidCallback onOpenStudent;

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _selectedIndex = 0;
  bool _sidebarCollapsed = false;
  String? _selectedInboxThreadKey;

  static const _items = [
    _AdminNavItem('Boshqaruv paneli', Icons.dashboard_rounded),
    _AdminNavItem('Modullar', Icons.view_module_rounded),
    _AdminNavItem('Mavzular', Icons.topic_rounded),
    _AdminNavItem('PDF/Text', Icons.picture_as_pdf_rounded),
    _AdminNavItem('Videolar', Icons.play_circle_rounded),
    _AdminNavItem('Testlar', Icons.fact_check_rounded),
    _AdminNavItem('Yakuniy imtihon', Icons.emoji_events_rounded),
    _AdminNavItem('Talabalar', Icons.people_alt_rounded),
    _AdminNavItem('Tahlillar', Icons.analytics_rounded),
    _AdminNavItem('Xabarnomalar', Icons.notifications_rounded),
    _AdminNavItem('Sertifikatlar', Icons.workspace_premium_rounded),
    _AdminNavItem('Media kutubxona', Icons.perm_media_rounded),
    _AdminNavItem('Rollar', Icons.admin_panel_settings_rounded),
    _AdminNavItem('Sozlamalar', Icons.settings_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final useRail = constraints.maxWidth < 1120 || _sidebarCollapsed;

            return Row(
              children: [
                if (useRail)
                  _AdminRail(
                    items: _items,
                    selectedIndex: _selectedIndex,
                    onSelected: (index) =>
                        setState(() => _selectedIndex = index),
                  )
                else
                  _AdminSidebar(
                    items: _items,
                    selectedIndex: _selectedIndex,
                    onSelected: (index) =>
                        setState(() => _selectedIndex = index),
                  ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, contentConstraints) {
                      final contentWidth = contentConstraints.maxWidth;
                      final horizontalPadding = _adminHorizontalPadding(
                        contentWidth,
                      );
                      final pageMaxWidth = _adminContentMaxWidth(contentWidth);
                      return Column(
                        children: [
                          _AdminTopBar(
                            title: _items[_selectedIndex].label,
                            themeMode: widget.themeMode,
                            sidebarCollapsed: useRail,
                            onOpenStudent: widget.onOpenStudent,
                            onSignOut: widget.onSignOut,
                            onOpenNotifications: _openAdminInboxDialog,
                            onToggleSidebar: () => setState(
                              () => _sidebarCollapsed = !_sidebarCollapsed,
                            ),
                            onToggleTheme: () => widget.onThemeChanged(
                              widget.themeMode == ThemeMode.dark
                                  ? ThemeMode.light
                                  : ThemeMode.dark,
                            ),
                            onOpenProfile: _openAdminProfileDialog,
                            onSearch: _jumpToSection,
                          ),
                          Expanded(
                            child: SingleChildScrollView(
                              padding: EdgeInsets.fromLTRB(
                                horizontalPadding,
                                horizontalPadding,
                                horizontalPadding,
                                horizontalPadding + 6,
                              ),
                              child: Center(
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth: pageMaxWidth,
                                  ),
                                  child: _buildPage(),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildPage() {
    switch (_selectedIndex) {
      case 0:
        return const _RealDashboardPage();
      case 1:
        return const _RealModuleManagementPage();
      case 2:
        return const _RealTopicManagementPage();
      case 3:
        return const _RealLessonManagementPage(kindFilter: 'pdf_text');
      case 4:
        return const _RealLessonManagementPage(kindFilter: 'video');
      case 5:
        return const _RealQuestionManagementPage(finalExamOnly: false);
      case 6:
        return const _RealQuestionManagementPage(finalExamOnly: true);
      case 7:
        return const _RealStudentManagementPage();
      case 8:
        return const _RealAnalyticsPage();
      case 9:
        return _NotificationsPage(initialThreadKey: _selectedInboxThreadKey);
      case 10:
        return const _RealCertificatePage();
      case 11:
        return const _RealMediaLibraryPage();
      case 12:
        return const _RealRolesPage();
      case 13:
        return _RealSettingsPage(
          themeMode: widget.themeMode,
          onThemeChanged: widget.onThemeChanged,
        );
      default:
        return const _RealDashboardPage();
    }
  }

  void _jumpToSection(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return;
    final index = _items.indexWhere(
      (item) => item.label.toLowerCase().contains(normalized),
    );
    if (index == -1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mos bo‘lim topilmadi.'),
          backgroundColor: AppColors.errorRed,
        ),
      );
      return;
    }
    setState(() => _selectedIndex = index);
  }

  Future<void> _openAdminProfileDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) => const _AdminProfileDialog(),
    );
    if (mounted) setState(() {});
  }

  void _openAdminInboxDialog() {
    showDialog<Object?>(
      context: context,
      builder: (context) => const _AdminInboxDialog(),
    ).then((result) {
      if (!mounted) return;
      if (result == '__notifications__') {
        setState(() {
          _selectedIndex = 9;
          _selectedInboxThreadKey = null;
        });
        return;
      }
      if (result is String && result.isNotEmpty) {
        setState(() {
          _selectedIndex = 9;
          _selectedInboxThreadKey = result;
        });
        return;
      }
      setState(() {});
    });
  }
}

class _AdminNavItem {
  const _AdminNavItem(this.label, this.icon);

  final String label;
  final IconData icon;
}

class _AdminSidebar extends StatelessWidget {
  const _AdminSidebar({
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<_AdminNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    Widget navTile(_AdminNavItem item, int index) {
      final selected = selectedIndex == index;
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: ListTile(
          dense: true,
          visualDensity: const VisualDensity(horizontal: -2, vertical: -3),
          minLeadingWidth: 24,
          horizontalTitleGap: 10,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          selected: selected,
          selectedTileColor: AppColors.primaryBlue,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          leading: Icon(
            item.icon,
            color: selected ? Colors.white : const Color(0xFFE2E8F0),
            size: 19,
          ),
          title: Text(
            item.label,
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xFFE2E8F0),
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
            ),
          ),
          onTap: () => onSelected(index),
        ),
      );
    }

    Widget sectionLabel(String label) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: .5,
          ),
        ),
      );
    }

    return Container(
      width: 220,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF061533), Color(0xFF081A3D)],
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B60FF).withValues(alpha: .18),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFF0B60FF).withValues(alpha: .32),
                    ),
                  ),
                  child: const Icon(Icons.school_rounded, color: Colors.white),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'EduLab',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Admin Panel',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.white.withValues(alpha: .08)),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              children: [
                navTile(items[0], 0),
                sectionLabel('LEARNING'),
                for (final entry in [
                  (1, items[1]),
                  (2, items[2]),
                  (3, items[3]),
                  (4, items[4]),
                  (5, items[5]),
                  (6, items[6]),
                ])
                  navTile(entry.$2, entry.$1),
                sectionLabel('MANAGEMENT'),
                for (final entry in [
                  (7, items[7]),
                  (8, items[8]),
                  (9, items[9]),
                  (10, items[10]),
                  (11, items[11]),
                ])
                  navTile(entry.$2, entry.$1),
                sectionLabel('SYSTEM'),
                navTile(items[13], 13),
                navTile(items[12], 12),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: AppCard(
              color: Colors.white.withValues(alpha: .06),
              borderColor: Colors.white.withValues(alpha: .08),
              padding: const EdgeInsets.all(10),
              child: const Row(
                children: [
                  CircleAvatar(
                    radius: 19,
                    backgroundColor: AppColors.primaryBlue,
                    child: Icon(Icons.person_rounded, color: Colors.white),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Admin',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          'Super Admin',
                          style: TextStyle(
                            color: Color(0xFFCBD5E1),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.more_vert_rounded, color: Colors.white),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminRail extends StatelessWidget {
  const _AdminRail({
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<_AdminNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      color: AppColors.navy,
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: AppLogo(compact: true, size: 42),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(10, 4, 10, 12),
              itemCount: items.length,
              separatorBuilder: (context, index) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final item = items[index];
                final selected = selectedIndex == index;
                return Tooltip(
                  message: item.label,
                  waitDuration: const Duration(milliseconds: 450),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primaryBlue
                          : Colors.white.withValues(alpha: .04),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                color: AppColors.primaryBlue.withValues(
                                  alpha: .35,
                                ),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              ),
                            ]
                          : null,
                    ),
                    child: IconButton(
                      onPressed: () => onSelected(index),
                      icon: Icon(
                        item.icon,
                        color: selected
                            ? Colors.white
                            : const Color(0xFFCBD5E1),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminTopBar extends StatefulWidget {
  const _AdminTopBar({
    required this.title,
    required this.themeMode,
    required this.sidebarCollapsed,
    required this.onOpenStudent,
    required this.onSignOut,
    required this.onOpenNotifications,
    required this.onToggleSidebar,
    required this.onToggleTheme,
    required this.onOpenProfile,
    required this.onSearch,
  });

  final String title;
  final ThemeMode themeMode;
  final bool sidebarCollapsed;
  final VoidCallback onOpenStudent;
  final VoidCallback onSignOut;
  final VoidCallback onOpenNotifications;
  final VoidCallback onToggleSidebar;
  final VoidCallback onToggleTheme;
  final VoidCallback onOpenProfile;
  final ValueChanged<String> onSearch;
  static const _repository = SupabaseAcademyRepository();

  @override
  State<_AdminTopBar> createState() => _AdminTopBarState();
}

class _AdminTopBarState extends State<_AdminTopBar> {
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;
  String _searchValue = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchFocusNode = FocusNode(debugLabel: 'admin-top-search');
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _submitSearch() {
    final value = _searchController.text.trim();
    if (value.isEmpty) {
      _searchFocusNode.requestFocus();
      return;
    }
    widget.onSearch(value);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.themeMode == ThemeMode.dark;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final stacked = width < 960;
        final padding = _adminHorizontalPadding(width);
        final showShortcut = width >= 1180;
        final searchField = CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.slash, control: true): () {
              _searchFocusNode.requestFocus();
            },
          },
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            textInputAction: TextInputAction.search,
            enableInteractiveSelection: true,
            autocorrect: false,
            enableSuggestions: false,
            onChanged: (value) => setState(() => _searchValue = value),
            onSubmitted: (_) => _submitSearch(),
            decoration: InputDecoration(
              hintText: 'Bo‘lim yoki sahifa qidiring...',
              hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.muted,
                fontWeight: FontWeight.w500,
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                size: 22,
                color: AppColors.muted,
              ),
              suffixIconConstraints: const BoxConstraints(
                minWidth: 42,
                minHeight: 38,
              ),
              suffixIcon: _searchValue.trim().isEmpty
                  ? (showShortcut
                        ? Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  color: isDark
                                      ? const Color(0xFF0F172A)
                                      : const Color(0xFFF8FAFC),
                                  border: Border.all(
                                    color: isDark
                                        ? const Color(0xFF1E293B)
                                        : AppColors.border,
                                  ),
                                ),
                                child: Text(
                                  'Ctrl /',
                                  style: Theme.of(context).textTheme.labelMedium
                                      ?.copyWith(
                                        color: AppColors.muted,
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                              ),
                            ),
                          )
                        : null)
                  : IconButton(
                      tooltip: 'Tozalash',
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchValue = '');
                        _searchFocusNode.requestFocus();
                      },
                      icon: const Icon(Icons.close_rounded, size: 20),
                    ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 13,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(
                  color: isDark ? const Color(0xFF1F2937) : AppColors.border,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(
                  color: isDark ? const Color(0xFF1F2937) : AppColors.border,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(
                  color: AppColors.primaryBlue,
                  width: 1.4,
                ),
              ),
            ),
          ),
        );
        final actionButtons = <Widget>[
          FutureBuilder<int>(
            future: _AdminTopBar._repository.loadAdminUnreadInboxCount(),
            builder: (context, snapshot) {
              final count = snapshot.data ?? 0;
              return IconButton.filledTonal(
                tooltip: 'Admin xabarlari',
                onPressed: widget.onOpenNotifications,
                icon: Badge(
                  isLabelVisible: count > 0,
                  label: Text('$count'),
                  child: const Icon(Icons.notifications_active_outlined),
                ),
              );
            },
          ),
          IconButton.filledTonal(
            tooltip: isDark
                ? 'Kunduzgi rejimga o‘tish'
                : 'Tungi rejimga o‘tish',
            onPressed: widget.onToggleTheme,
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Admin menyu',
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'profile', child: Text('Profil')),
              PopupMenuItem(
                value: 'student',
                child: Text('Student ilovasini ochish'),
              ),
              PopupMenuItem(value: 'signout', child: Text('Chiqish')),
            ],
            onSelected: (value) {
              if (value == 'profile') {
                widget.onOpenProfile();
              } else if (value == 'student') {
                widget.onOpenStudent();
              } else if (value == 'signout') {
                widget.onSignOut();
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Theme.of(context).colorScheme.surface,
                border: Border.all(
                  color: isDark ? const Color(0xFF1F2937) : AppColors.border,
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.primaryBlue,
                    child: Icon(Icons.person_rounded, color: Colors.white),
                  ),
                  SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Admin',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppColors.navy,
                        ),
                      ),
                      Text(
                        'Super Admin',
                        style: TextStyle(fontSize: 11, color: AppColors.muted),
                      ),
                    ],
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.expand_more_rounded, color: AppColors.muted),
                ],
              ),
            ),
          ),
        ];

        return Container(
          padding: EdgeInsets.symmetric(horizontal: padding, vertical: 14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF1F2937)
                    : AppColors.border,
              ),
            ),
          ),
          child: stacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          tooltip: widget.sidebarCollapsed
                              ? 'Yon panelni ochish'
                              : 'Yon panelni yig‘ish',
                          onPressed: widget.onToggleSidebar,
                          icon: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            child: Icon(
                              widget.sidebarCollapsed
                                  ? Icons.menu_rounded
                                  : Icons.menu_open_rounded,
                              key: ValueKey(widget.sidebarCollapsed),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            widget.title,
                            style: Theme.of(context).textTheme.headlineSmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SizedBox(
                          width: width < 640 ? width - (padding * 2) : 360,
                          child: searchField,
                        ),
                        ...actionButtons,
                      ],
                    ),
                  ],
                )
              : Row(
                  children: [
                    IconButton(
                      tooltip: widget.sidebarCollapsed
                          ? 'Yon panelni ochish'
                          : 'Yon panelni yig‘ish',
                      onPressed: widget.onToggleSidebar,
                      icon: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: Icon(
                          widget.sidebarCollapsed
                              ? Icons.menu_rounded
                              : Icons.menu_open_rounded,
                          key: ValueKey(widget.sidebarCollapsed),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Spacer(),
                    SizedBox(
                      width: width > 1360
                          ? 400
                          : width > 1160
                          ? 360
                          : 320,
                      child: searchField,
                    ),
                    const SizedBox(width: 12),
                    ...actionButtons
                        .expand((widget) => [widget, const SizedBox(width: 8)])
                        .toList()
                      ..removeLast(),
                  ],
                ),
        );
      },
    );
  }
}

class _AdminChatAttachmentDraft {
  const _AdminChatAttachmentDraft({
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

List<String> _adminAttachmentExtensionsForKind(String kind) {
  switch (kind) {
    case 'image':
      return ['png', 'jpg', 'jpeg', 'webp', 'gif'];
    case 'video':
    case 'video_note':
      return ['mp4', 'mov', 'webm'];
    case 'voice':
    case 'audio':
      return ['ogg', 'oga', 'mp3', 'wav', 'm4a'];
    default:
      return ['pdf', 'doc', 'docx', 'txt'];
  }
}

String _adminAttachmentLabel(String kind) {
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

IconData _adminAttachmentIcon(String kind) {
  switch (kind) {
    case 'image':
      return Icons.image_outlined;
    case 'video':
      return Icons.videocam_outlined;
    case 'video_note':
      return Icons.radio_button_checked_rounded;
    case 'voice':
      return Icons.mic_none_rounded;
    case 'audio':
      return Icons.graphic_eq_rounded;
    default:
      return Icons.attach_file_rounded;
  }
}

String _adminAttachmentMimeType(String extension) {
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
    case 'webm':
      return 'video/webm';
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

Future<_AdminChatAttachmentDraft?> _pickAdminAttachment(String kind) async {
  if (kind == 'image' || kind == 'video' || kind == 'video_note') {
    final picker = ImagePicker();
    final XFile? picked = kind == 'image'
        ? await picker.pickImage(source: ImageSource.gallery)
        : await picker.pickVideo(source: ImageSource.gallery);
    if (picked == null) return null;
    final bytes = await picked.readAsBytes();
    final extension = _extensionFromPickedName(
      picked.name,
      fallback: _defaultAdminExtensionForKind(kind),
    );
    return _AdminChatAttachmentDraft(
      bytes: bytes,
      fileName: picked.name.isEmpty
          ? 'labproof-${kind.replaceAll('_', '-')}-${DateTime.now().millisecondsSinceEpoch}.$extension'
          : picked.name,
      extension: extension,
      mimeType: _adminAttachmentMimeType(extension),
      messageKind: kind,
    );
  }

  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowMultiple: false,
    withData: true,
    allowedExtensions: _adminAttachmentExtensionsForKind(kind),
  );
  if (result == null || result.files.isEmpty) return null;
  final file = result.files.single;
  if (file.bytes == null) return null;
  final extension = (file.extension ?? _extensionFromPickedName(file.name))
      .toLowerCase();
  return _AdminChatAttachmentDraft(
    bytes: file.bytes!,
    fileName: file.name,
    extension: extension,
    mimeType: _adminAttachmentMimeType(extension),
    messageKind: kind,
  );
}

String _extensionFromPickedName(String name, {String fallback = 'bin'}) {
  final dot = name.lastIndexOf('.');
  if (dot == -1 || dot == name.length - 1) return fallback;
  return name.substring(dot + 1).toLowerCase();
}

String _defaultAdminExtensionForKind(String kind) {
  switch (kind) {
    case 'image':
      return 'jpg';
    case 'video':
    case 'video_note':
      return 'mp4';
    case 'voice':
      return 'ogg';
    default:
      return 'bin';
  }
}

Future<void> _openAdminAttachmentUrl(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

String _formatPreciseAdminDateTime(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  return '$day.$month.${value.year} • $hour:$minute';
}

String _formatRelativeAdminTime(DateTime value) {
  final difference = DateTime.now().difference(value);
  if (difference.inMinutes < 1) return 'Hozir';
  if (difference.inMinutes < 60) return '${difference.inMinutes} daqiqa oldin';
  if (difference.inHours < 24) return '${difference.inHours} soat oldin';
  if (difference.inDays < 7) return '${difference.inDays} kun oldin';
  return _formatDate(value);
}

IconData _notificationIcon(String kind) {
  switch (kind) {
    case 'image':
      return Icons.image_rounded;
    case 'video':
    case 'video_note':
      return Icons.play_circle_rounded;
    case 'voice':
    case 'audio':
      return Icons.phone_rounded;
    case 'file':
    case 'document':
      return Icons.description_rounded;
    default:
      return Icons.notifications_active_rounded;
  }
}

Color _notificationColor(String kind) {
  switch (kind) {
    case 'image':
      return AppColors.successGreen;
    case 'video':
    case 'video_note':
      return AppColors.violet;
    case 'voice':
    case 'audio':
      return AppColors.primaryBlue;
    case 'file':
    case 'document':
      return AppColors.amber;
    default:
      return AppColors.primaryBlue;
  }
}

String _normalizeInboxPhone(String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return '';
  if (digits.length == 12 && digits.startsWith('998')) return '+$digits';
  if (digits.length == 9) return '+998$digits';
  return '+$digits';
}

String _normalizeInboxName(String value) {
  return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

String _inboxThreadKey(AdminInboxMessage item) {
  final normalizedPhone = _normalizeInboxPhone(item.senderPhone);
  if (normalizedPhone.isNotEmpty) return 'phone:$normalizedPhone';
  if ((item.senderUserId ?? '').trim().isNotEmpty) {
    return 'user:${item.senderUserId!.trim()}';
  }
  if ((item.telegramChatId ?? '').trim().isNotEmpty) {
    return 'telegram:${item.telegramChatId!.trim()}';
  }
  final normalizedName = _normalizeInboxName(item.senderName);
  if (normalizedName.isNotEmpty) return 'name:$normalizedName';
  return 'message:${item.id}';
}

class _AdminInboxThread {
  const _AdminInboxThread({
    required this.key,
    required this.displayName,
    required this.phone,
    required this.sources,
    required this.messages,
    required this.latestMessage,
    required this.unreadCount,
  });

  final String key;
  final String displayName;
  final String phone;
  final Set<String> sources;
  final List<AdminInboxMessage> messages;
  final AdminInboxMessage latestMessage;
  final int unreadCount;

  bool get hasTelegram => sources.contains('telegram');
  bool get hasStudentApp => sources.contains('student_app');
  bool get hasMultipleSources => sources.length > 1;
}

List<_AdminInboxThread> _groupInboxThreads(List<AdminInboxMessage> items) {
  final grouped = <String, List<AdminInboxMessage>>{};
  for (final item in items) {
    grouped.putIfAbsent(_inboxThreadKey(item), () => []).add(item);
  }

  final threads =
      grouped.entries.map((entry) {
        final messages = [...entry.value]
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
        final latest = messages.last;
        final name = messages
            .map((item) => item.senderName.trim())
            .firstWhere((value) => value.isNotEmpty, orElse: () => '');
        final phone = messages
            .map((item) => _normalizeInboxPhone(item.senderPhone))
            .firstWhere((value) => value.isNotEmpty, orElse: () => '');
        final sources = messages.map((item) => item.source).toSet();
        final unreadCount = messages.where((item) => !item.isRead).length;
        return _AdminInboxThread(
          key: entry.key,
          displayName: name.isEmpty ? 'Noma’lum foydalanuvchi' : name,
          phone: phone,
          sources: sources,
          messages: messages,
          latestMessage: latest,
          unreadCount: unreadCount,
        );
      }).toList()..sort(
        (a, b) =>
            b.latestMessage.createdAt.compareTo(a.latestMessage.createdAt),
      );

  return threads;
}

class _AdminInboxDialog extends StatefulWidget {
  const _AdminInboxDialog();

  @override
  State<_AdminInboxDialog> createState() => _AdminInboxDialogState();
}

class _AdminInboxDialogState extends State<_AdminInboxDialog> {
  static const _repository = SupabaseAcademyRepository();

  bool _loading = true;
  bool _markingAll = false;
  String? _error;
  List<AdminInboxMessage> _items = const [];
  List<StudentNotification> _notifications = const [];

  @override
  void initState() {
    super.initState();
    _loadInbox();
  }

  Future<void> _loadInbox() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final items = await _repository.loadAdminInboxMessages(limit: 120);
      final notifications = await _repository.loadAdminNotifications(limit: 24);
      if (!mounted) return;
      setState(() {
        _items = items;
        _notifications = notifications;
        _loading = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _markRead(AdminInboxMessage item) async {
    if (item.isRead) return;
    await _repository.markAdminInboxMessageRead(item.id);
    if (!mounted) return;
    setState(() {
      _items = [
        for (final current in _items)
          if (current.id == item.id)
            AdminInboxMessage(
              id: current.id,
              source: current.source,
              senderUserId: current.senderUserId,
              senderName: current.senderName,
              senderPhone: current.senderPhone,
              telegramChatId: current.telegramChatId,
              subject: current.subject,
              body: current.body,
              isRead: true,
              adminReply: current.adminReply,
              repliedAt: current.repliedAt,
              createdAt: current.createdAt,
              messageKind: current.messageKind,
              attachmentUrl: current.attachmentUrl,
              attachmentName: current.attachmentName,
              attachmentMime: current.attachmentMime,
              attachmentSize: current.attachmentSize,
              adminReadAt: DateTime.now(),
              recipientReadAt: current.recipientReadAt,
            )
          else
            current,
      ];
    });
  }

  Future<void> _markAllRead() async {
    setState(() => _markingAll = true);
    try {
      await _repository.markAllAdminInboxMessagesRead();
      await _loadInbox();
    } finally {
      if (mounted) setState(() => _markingAll = false);
    }
  }

  Future<void> _openThread(_AdminInboxThread thread) async {
    for (final message in thread.messages.where((item) => !item.isRead)) {
      await _markRead(message);
    }
    if (!mounted) return;
    Navigator.of(context).pop(thread.key);
  }

  @override
  Widget build(BuildContext context) {
    final threads = _groupInboxThreads(_items);
    final theme = Theme.of(context);

    final notificationRows = _notifications.take(6).map((item) {
      return _AdminBellRow(
        icon: _notificationIcon(item.messageKind),
        color: _notificationColor(item.messageKind),
        title: item.title,
        subtitle: item.body,
        time: _formatRelativeAdminTime(item.createdAt),
        unread: !item.isRead,
      );
    });
    final inboxRows = threads.take(6).map((thread) {
      final latest = thread.latestMessage;
      return _AdminBellRow(
        icon: thread.hasTelegram
            ? Icons.telegram_rounded
            : Icons.support_agent_rounded,
        color: thread.hasTelegram
            ? AppColors.primaryBlue
            : AppColors.successGreen,
        title: latest.subject.isEmpty ? thread.displayName : latest.subject,
        subtitle: latest.body,
        time: _formatRelativeAdminTime(latest.createdAt),
        unread: thread.unreadCount > 0,
        onTap: () => _openThread(thread),
      );
    });
    final rows = [...notificationRows, ...inboxRows].take(6).toList();

    return Dialog(
      insetPadding: const EdgeInsets.all(18),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430, maxHeight: 620),
        child: AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 20, 18, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Bildirishnomalar',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _markingAll ? null : _markAllRead,
                      child: _markingAll
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Barchasini o‘qish'),
                    ),
                    IconButton(
                      tooltip: 'Yopish',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded, size: 20),
                    ),
                  ],
                ),
              ),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 56),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 16, 22, 42),
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.errorRed,
                    ),
                  ),
                )
              else if (rows.isEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(22, 24, 22, 48),
                  child: _AdminInboxEmptyState(),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(22, 4, 22, 16),
                    itemCount: rows.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 4),
                    itemBuilder: (context, index) => rows[index],
                  ),
                ),
              const Divider(height: 1),
              InkWell(
                onTap: () => Navigator.of(context).pop('__notifications__'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 17,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Barcha bildirishnomalar',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: AppColors.primaryBlue,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        color: AppColors.primaryBlue,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatAdminInboxTime(DateTime value) {
    return _formatPreciseAdminDateTime(value);
  }
}

class _AdminBellRow extends StatelessWidget {
  const _AdminBellRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.unread,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String time;
  final bool unread;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconBadge(icon: icon, color: color, size: 38),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.muted,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  time,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                if (unread)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryBlue,
                      shape: BoxShape.circle,
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

class _AdminInboxEmptyState extends StatelessWidget {
  const _AdminInboxEmptyState();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const IconBadge(
          icon: Icons.mark_email_read_rounded,
          color: AppColors.primaryBlue,
          size: 64,
        ),
        const SizedBox(height: 14),
        Text(
          'Adminga yangi murojaat yo‘q',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'Student ilovasi yoki Telegram bot orqali kelgan xabarlar shu yerda ko‘rinadi.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _AdminReplyDialog extends StatefulWidget {
  const _AdminReplyDialog({required this.message});

  final AdminInboxMessage message;

  @override
  State<_AdminReplyDialog> createState() => _AdminReplyDialogState();
}

class _AdminReplyDialogState extends State<_AdminReplyDialog> {
  static const _repository = SupabaseAcademyRepository();

  late final TextEditingController _controller;
  bool _sending = false;
  String? _error;
  _AdminChatAttachmentDraft? _attachment;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _sendReply() async {
    final text = _controller.text.trim();
    if (text.isEmpty && _attachment == null) {
      setState(() => _error = 'Javob matni yoki biriktirma kiriting.');
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      String? attachmentUrl;
      if (_attachment != null) {
        attachmentUrl = await _repository.uploadChatAttachment(
          bytes: _attachment!.bytes,
          extension: _attachment!.extension,
          fileName: _attachment!.fileName,
          kind: _attachment!.messageKind == 'video_note'
              ? 'round_video'
              : _attachment!.messageKind,
        );
      }
      await _repository.sendAdminReply(
        messageId: widget.message.id,
        replyText: text,
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
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _sending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTelegram = widget.message.source == 'telegram';
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Xabarga javob berish',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                isTelegram
                    ? 'Javob Telegram bot orqali yuboriladi.'
                    : 'Javob student ilovasidagi xabarnomalarga yuboriladi.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: .05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.primaryBlue.withValues(alpha: .12),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.message.subject.isEmpty
                          ? 'Yangi murojaat'
                          : widget.message.subject,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.message.body,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (widget.message.senderName.trim().isNotEmpty)
                          StatusChip(
                            label: widget.message.senderName,
                            color: AppColors.navy,
                          ),
                        if (widget.message.senderPhone.trim().isNotEmpty)
                          StatusChip(
                            label: widget.message.senderPhone,
                            color: AppColors.amber,
                          ),
                        StatusChip(
                          label: _formatPreciseAdminDateTime(
                            widget.message.createdAt,
                          ),
                          color: AppColors.primaryBlue,
                        ),
                      ],
                    ),
                    if (widget.message.hasAttachment) ...[
                      const SizedBox(height: 10),
                      if (widget.message.isImage)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(
                            widget.message.attachmentUrl!,
                            height: 150,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        )
                      else
                        _AdminAttachmentLink(
                          onTap: () => _openAdminAttachmentUrl(
                            widget.message.attachmentUrl!,
                          ),
                          icon: _adminAttachmentIcon(
                            widget.message.messageKind,
                          ),
                          label:
                              widget.message.attachmentName
                                      ?.trim()
                                      .isNotEmpty ==
                                  true
                              ? widget.message.attachmentName!
                              : 'Biriktirmani ochish',
                        ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: 'Admin javobi',
                  alignLabelWithHint: true,
                  hintText: 'Talabaga yuboriladigan javobni yozing...',
                  errorText: _error,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final kind in const [
                    ('image', Icons.image_outlined),
                    ('video', Icons.videocam_outlined),
                    ('video_note', Icons.radio_button_checked_rounded),
                    ('voice', Icons.mic_none_rounded),
                    ('document', Icons.attach_file_rounded),
                  ])
                    OutlinedButton.icon(
                      onPressed: _sending
                          ? null
                          : () async {
                              final picked = await _pickAdminAttachment(
                                kind.$1,
                              );
                              if (picked == null || !mounted) return;
                              setState(() => _attachment = picked);
                            },
                      icon: Icon(kind.$2, size: 18),
                      label: Text(_adminAttachmentLabel(kind.$1)),
                    ),
                ],
              ),
              if (_attachment != null) ...[
                const SizedBox(height: 12),
                AppCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      IconBadge(
                        icon: _adminAttachmentIcon(_attachment!.messageKind),
                        color: AppColors.primaryBlue,
                        size: 40,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _attachment!.fileName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_adminAttachmentLabel(_attachment!.messageKind)} • ${(_attachment!.size / 1024).toStringAsFixed(0)} KB',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _sending
                            ? null
                            : () => setState(() => _attachment = null),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _sending
                        ? null
                        : () => Navigator.of(context).pop(false),
                    child: const Text('Bekor qilish'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _sending ? null : _sendReply,
                    icon: _sending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded, size: 16),
                    label: Text(
                      _sending ? 'Yuborilmoqda...' : 'Javob yuborish',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminBroadcastComposerDialog extends StatefulWidget {
  const _AdminBroadcastComposerDialog();

  @override
  State<_AdminBroadcastComposerDialog> createState() =>
      _AdminBroadcastComposerDialogState();
}

class _AdminBroadcastComposerDialogState
    extends State<_AdminBroadcastComposerDialog> {
  static const _repository = SupabaseAcademyRepository();

  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  _AdminChatAttachmentDraft? _attachment;
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _pickAttachment(String kind) async {
    setState(() => _error = null);
    try {
      final picked = await _pickAdminAttachment(kind);
      if (picked == null || !mounted) return;
      setState(() => _attachment = picked);
    } on Object catch (error) {
      if (!mounted) return;
      debugPrint('Admin broadcast attachment pick failed: $error');
      setState(
        () => _error =
            'Biriktirma tanlanmadi. Fayl turini yoki brauzer ruxsatini tekshirib qayta urinib ko‘ring.',
      );
    }
  }

  Future<void> _send() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    if (title.isEmpty && body.isEmpty && _attachment == null) {
      setState(() => _error = 'Hech bo‘lmasa matn yoki biriktirma kiriting.');
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      String? attachmentUrl;
      if (_attachment != null) {
        attachmentUrl = await _repository.uploadChatAttachment(
          bytes: _attachment!.bytes,
          extension: _attachment!.extension,
          fileName: _attachment!.fileName,
          kind: _attachment!.messageKind == 'video_note'
              ? 'round_video'
              : _attachment!.messageKind,
        );
      }
      await _repository.sendNotification(
        title: title.isEmpty
            ? '${_adminAttachmentLabel(_attachment?.messageKind ?? 'document')} yuborildi'
            : title,
        body: body.isEmpty
            ? '${_adminAttachmentLabel(_attachment?.messageKind ?? 'document')} biriktirildi.'
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
      setState(() {
        _sending = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const IconBadge(
                    icon: Icons.campaign_rounded,
                    color: AppColors.primaryBlue,
                    size: 50,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Yangi xabar yuborish',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Xabar student ilovasidagi xabarnomalar markaziga yuboriladi.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Sarlavha',
                  prefixIcon: const Icon(Icons.title_rounded),
                  errorText: _error,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _bodyController,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Xabar matni',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final kind in const [
                    ('image', Icons.image_outlined),
                    ('video', Icons.videocam_outlined),
                    ('video_note', Icons.slow_motion_video_rounded),
                    ('voice', Icons.mic_none_rounded),
                    ('document', Icons.attach_file_rounded),
                  ])
                    FilledButton.tonalIcon(
                      onPressed: _sending
                          ? null
                          : () => _pickAttachment(kind.$1),
                      icon: Icon(kind.$2, size: 18),
                      label: Text(_adminAttachmentLabel(kind.$1)),
                    ),
                ],
              ),
              if (_attachment != null) ...[
                const SizedBox(height: 14),
                AppCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(
                        _adminAttachmentIcon(_attachment!.messageKind),
                        color: AppColors.primaryBlue,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _attachment!.fileName,
                              style: Theme.of(context).textTheme.titleSmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_adminAttachmentLabel(_attachment!.messageKind)} • ${(_attachment!.size / 1024).toStringAsFixed(0)} KB',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Olib tashlash',
                        onPressed: _sending
                            ? null
                            : () => setState(() => _attachment = null),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: const [
                  StatusChip(
                    label: 'Barcha talabalar',
                    color: AppColors.successGreen,
                  ),
                  StatusChip(
                    label: 'Ilova xabarnomasi',
                    color: AppColors.primaryBlue,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _sending
                        ? null
                        : () => Navigator.of(context).pop(false),
                    child: const Text('Bekor qilish'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded, size: 18),
                    label: Text(_sending ? 'Yuborilmoqda...' : 'Yuborish'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminPageHeading extends StatelessWidget {
  const _AdminPageHeading({required this.title, required this.trail});

  final String title;
  final List<String> trail;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        _AdminBreadcrumbs(items: trail),
      ],
    );
  }
}

class _AdminBreadcrumbs extends StatelessWidget {
  const _AdminBreadcrumbs({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          Text(
            items[i],
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: i == items.length - 1
                  ? AppColors.primaryBlue
                  : AppColors.muted,
              fontWeight: i == items.length - 1
                  ? FontWeight.w700
                  : FontWeight.w500,
            ),
          ),
          if (i != items.length - 1)
            const Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: AppColors.muted,
            ),
        ],
      ],
    );
  }
}

class _AdminProfileDialog extends StatefulWidget {
  const _AdminProfileDialog();

  @override
  State<_AdminProfileDialog> createState() => _AdminProfileDialogState();
}

class _AdminProfileDialogState extends State<_AdminProfileDialog> {
  static const _repository = SupabaseAcademyRepository();
  final _picker = ImagePicker();

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _ageController = TextEditingController();
  final _regionController = TextEditingController();
  final _districtController = TextEditingController();
  final _mahallaController = TextEditingController();
  final _streetController = TextEditingController();

  StudentProfile? _profile;
  String _gender = '';
  Uint8List? _avatarBytes;
  String? _avatarExtension;
  bool _loading = true;
  bool _saving = false;
  bool _pickingAvatar = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _ageController.dispose();
    _regionController.dispose();
    _districtController.dispose();
    _mahallaController.dispose();
    _streetController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final profile = await _repository.loadCurrentProfile();
      if (!mounted) return;
      final parts = profile.fullName
          .trim()
          .split(RegExp(r'\s+'))
          .where((part) => part.isNotEmpty)
          .toList();
      _profile = profile;
      _firstNameController.text = parts.isEmpty ? '' : parts.first;
      _lastNameController.text = parts.length > 1
          ? parts.sublist(1).join(' ')
          : '';
      _phoneController.text = profile.phone;
      _ageController.text = profile.age?.toString() ?? '';
      _regionController.text = profile.region;
      _districtController.text = profile.district;
      _mahallaController.text = profile.mahalla;
      _streetController.text = profile.street;
      _gender = profile.gender;
    } on Object catch (error) {
      if (!mounted) return;
      _showAdminSnack(context, error.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickAvatar() async {
    setState(() => _pickingAvatar = true);
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery);
      if (picked == null || !mounted) return;
      final extension = picked.name.contains('.')
          ? picked.name.split('.').last.toLowerCase()
          : 'jpg';
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      if (bytes.lengthInBytes > 2 * 1024 * 1024) {
        _showAdminSnack(
          context,
          'Profil rasmi 2MB dan oshmasligi kerak.',
          isError: true,
        );
        return;
      }
      setState(() {
        _avatarBytes = bytes;
        _avatarExtension = extension;
      });
    } on Object catch (error) {
      if (!mounted) return;
      _showAdminSnack(context, 'Rasm tanlanmadi: $error', isError: true);
    } finally {
      if (mounted) setState(() => _pickingAvatar = false);
    }
  }

  Future<void> _save() async {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    if (firstName.isEmpty) {
      _showAdminSnack(context, 'Ism kiritilishi kerak.', isError: true);
      return;
    }

    setState(() => _saving = true);
    try {
      var avatarUrl = _profile?.avatarUrl ?? '';
      if (_avatarBytes != null && _avatarExtension != null) {
        avatarUrl = await _repository.uploadProfileAvatar(
          bytes: _avatarBytes!,
          extension: _avatarExtension!,
        );
      }

      await _repository.updateOwnProfile(
        StudentProfileUpdate(
          firstName: firstName,
          lastName: lastName,
          phone: _phoneController.text.trim(),
          gender: _gender,
          age: int.tryParse(_ageController.text.trim()),
          region: _regionController.text.trim(),
          district: _districtController.text.trim(),
          mahalla: _mahallaController.text.trim(),
          street: _streetController.text.trim(),
          avatarUrl: avatarUrl,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      _showAdminSnack(context, 'Admin profili saqlandi.');
    } on Object catch (error) {
      if (!mounted) return;
      _showAdminSnack(context, error.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 36, vertical: 24),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860, maxHeight: 820),
        child: AppCard(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 22),
          child: _loading
              ? const SizedBox(
                  height: 320,
                  child: Center(child: CircularProgressIndicator()),
                )
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Admin profili',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(fontWeight: FontWeight.w900),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Shaxsiy ma’lumotlarni to‘ldiring va saqlang.',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        color: AppColors.muted,
                                        fontWeight: FontWeight.w500,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: _saving
                                ? null
                                : () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 180,
                            child: Column(
                              children: [
                                InkWell(
                                  onTap: _saving || _pickingAvatar
                                      ? null
                                      : _pickAvatar,
                                  borderRadius: BorderRadius.circular(22),
                                  child: Container(
                                    width: 132,
                                    height: 132,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(22),
                                      color: AppColors.background,
                                      image: _avatarBytes != null
                                          ? DecorationImage(
                                              image: MemoryImage(_avatarBytes!),
                                              fit: BoxFit.cover,
                                            )
                                          : (_profile?.avatarUrl
                                                        .trim()
                                                        .isNotEmpty ==
                                                    true
                                                ? DecorationImage(
                                                    image: NetworkImage(
                                                      _profile!.avatarUrl,
                                                    ),
                                                    fit: BoxFit.cover,
                                                  )
                                                : null),
                                    ),
                                    child:
                                        _avatarBytes == null &&
                                            (_profile?.avatarUrl
                                                    .trim()
                                                    .isEmpty ??
                                                true)
                                        ? const Icon(
                                            Icons.person_rounded,
                                            size: 54,
                                            color: AppColors.primaryBlue,
                                          )
                                        : null,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextButton.icon(
                                  onPressed: _saving || _pickingAvatar
                                      ? null
                                      : _pickAvatar,
                                  icon: Icon(
                                    _pickingAvatar
                                        ? Icons.sync_rounded
                                        : Icons.cloud_upload_rounded,
                                  ),
                                  label: Text(
                                    _pickingAvatar
                                        ? 'Yuklanmoqda...'
                                        : 'Rasm yuklash',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: _DialogFieldColumn(
                                        label: 'Ism',
                                        child: TextField(
                                          controller: _firstNameController,
                                          decoration: const InputDecoration(
                                            hintText: 'Ism',
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _DialogFieldColumn(
                                        label: 'Familiya',
                                        child: TextField(
                                          controller: _lastNameController,
                                          decoration: const InputDecoration(
                                            hintText: 'Familiya',
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _DialogFieldColumn(
                                        label: 'Telefon',
                                        child: TextField(
                                          controller: _phoneController,
                                          decoration: const InputDecoration(
                                            hintText: '+998 90 123 45 67',
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _DialogFieldColumn(
                                        label: 'Yosh',
                                        child: TextField(
                                          controller: _ageController,
                                          keyboardType: TextInputType.number,
                                          decoration: const InputDecoration(
                                            hintText: '25',
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _DialogFieldColumn(
                                        label: 'Jins',
                                        child: _AdminSelectField<String>(
                                          value: _gender.isEmpty
                                              ? null
                                              : _gender,
                                          hintText: 'Tanlang',
                                          options: const [
                                            _AdminSelectOption<String>(
                                              value: 'Erkak',
                                              label: 'Erkak',
                                              icon: Icons.male_rounded,
                                              color: AppColors.primaryBlue,
                                            ),
                                            _AdminSelectOption<String>(
                                              value: 'Ayol',
                                              label: 'Ayol',
                                              icon: Icons.female_rounded,
                                              color: AppColors.violet,
                                            ),
                                          ],
                                          onChanged: (value) =>
                                              setState(() => _gender = value),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _DialogFieldColumn(
                                        label: 'Viloyat',
                                        child: TextField(
                                          controller: _regionController,
                                          decoration: const InputDecoration(
                                            hintText: 'Viloyat',
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _DialogFieldColumn(
                                        label: 'Tuman',
                                        child: TextField(
                                          controller: _districtController,
                                          decoration: const InputDecoration(
                                            hintText: 'Tuman',
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _DialogFieldColumn(
                                        label: 'Mahalla',
                                        child: TextField(
                                          controller: _mahallaController,
                                          decoration: const InputDecoration(
                                            hintText: 'Mahalla',
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _DialogFieldColumn(
                                        label: 'Ko‘cha',
                                        child: TextField(
                                          controller: _streetController,
                                          decoration: const InputDecoration(
                                            hintText: 'Ko‘cha',
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
                      ),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          OutlinedButton(
                            onPressed: _saving
                                ? null
                                : () => Navigator.of(context).pop(),
                            child: const Text('Bekor qilish'),
                          ),
                          const Spacer(),
                          FilledButton.icon(
                            onPressed: _saving ? null : _save,
                            icon: _saving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.save_outlined),
                            label: Text(_saving ? 'Saqlanmoqda...' : 'Saqlash'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _AdminSummaryCardData {
  const _AdminSummaryCardData({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
}

class _AdminSummaryStrip extends StatelessWidget {
  const _AdminSummaryStrip({required this.items, this.compact = false});

  final List<_AdminSummaryCardData> items;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final count = compact
            ? (width >= 1120
                  ? 6
                  : width >= 900
                  ? 3
                  : width >= 620
                  ? 2
                  : 1)
            : width >= 1480
            ? 6
            : width >= 1260
            ? 5
            : width >= 1040
            ? 4
            : width >= 820
            ? 3
            : width >= 560
            ? 2
            : 1;
        final gap = compact ? 10.0 : (width >= 1040 ? 10.0 : 12.0);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: count,
            crossAxisSpacing: gap,
            mainAxisSpacing: gap,
            childAspectRatio: compact
                ? (count >= 5
                      ? 2.08
                      : count == 3
                      ? 2.35
                      : count == 2
                      ? 2.15
                      : 1.95)
                : count >= 5
                ? 3.35
                : count == 4
                ? 3.05
                : count == 3
                ? 2.65
                : count == 2
                ? 2.25
                : 1.95,
          ),
          itemBuilder: (context, index) =>
              _AdminSummaryCard(item: items[index], compact: compact),
        );
      },
    );
  }
}

class _AdminSummaryCard extends StatelessWidget {
  const _AdminSummaryCard({required this.item, this.compact = false});

  final _AdminSummaryCardData item;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (!compact) return _AdminSummaryCardOld(item: item);
    return AppCard(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 12,
        vertical: compact ? 10 : 10,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              IconBadge(icon: item.icon, color: item.color, size: 38),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.navy,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.value,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900, fontSize: 18),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      item.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: item.color,
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          SizedBox(
            height: 26,
            child: CustomPaint(
              painter: _MiniSparklinePainter(color: item.color),
              child: const SizedBox.expand(),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniSparklinePainter extends CustomPainter {
  const _MiniSparklinePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: .20), color.withValues(alpha: 0)],
      ).createShader(Offset.zero & size);
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    const points = [
      0.22,
      .34,
      .28,
      .42,
      .31,
      .48,
      .38,
      .56,
      .32,
      .44,
      .52,
      .40,
    ];
    final path = Path();
    final fill = Path();
    for (var i = 0; i < points.length; i++) {
      final x = size.width * i / (points.length - 1);
      final y = size.height * (1 - points[i]);
      if (i == 0) {
        path.moveTo(x, y);
        fill.moveTo(x, size.height);
        fill.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fill.lineTo(x, y);
      }
    }
    fill.lineTo(size.width, size.height);
    fill.close();
    canvas.drawPath(fill, fillPaint);
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _MiniSparklinePainter oldDelegate) =>
      oldDelegate.color != color;
}

class _AdminSummaryCardOld extends StatelessWidget {
  const _AdminSummaryCardOld({required this.item});

  final _AdminSummaryCardData item;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconBadge(icon: item.icon, color: item.color, size: 42),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w700,
                    fontSize: 11.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.value,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  item.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: item.color,
                    fontWeight: FontWeight.w700,
                    fontSize: 10.5,
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

class _AdminPrimaryActionButton extends StatelessWidget {
  const _AdminPrimaryActionButton({
    required this.label,
    required this.onPressed,
    this.icon = Icons.add_rounded,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 42),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

class _AdminSelectOption<T> {
  const _AdminSelectOption({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
    this.subtitle,
  });

  final T value;
  final String label;
  final IconData icon;
  final Color color;
  final String? subtitle;
}

class _AdminSelectField<T> extends StatelessWidget {
  const _AdminSelectField({
    required this.value,
    required this.options,
    required this.onChanged,
    this.label,
    this.helperText,
    this.hintText,
    this.enabled = true,
  });

  final T? value;
  final List<_AdminSelectOption<T>> options;
  final ValueChanged<T>? onChanged;
  final String? label;
  final String? helperText;
  final String? hintText;
  final bool enabled;

  _AdminSelectOption<T>? _selectedOption() {
    for (final option in options) {
      if (option.value == value) return option;
    }
    return null;
  }

  Future<void> _openPicker(BuildContext context) async {
    if (!enabled || onChanged == null) return;
    final selected = await showDialog<T>(
      context: context,
      builder: (context) {
        final current = value;
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430, maxHeight: 560),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 2, 4, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            label ?? 'Tanlang',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ),
                        IconButton.filledTonal(
                          tooltip: 'Yopish',
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: options.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final option = options[index];
                        final isSelected = option.value == current;
                        return InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => Navigator.of(context).pop(option.value),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 11,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? option.color.withValues(alpha: .10)
                                  : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? option.color.withValues(alpha: .36)
                                    : AppColors.border,
                              ),
                            ),
                            child: Row(
                              children: [
                                IconBadge(
                                  icon: option.icon,
                                  color: option.color,
                                  size: 38,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        option.label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w900,
                                            ),
                                      ),
                                      if (option.subtitle != null) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          option.subtitle!,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: AppColors.muted,
                                              ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 160),
                                  child: isSelected
                                      ? Icon(
                                          Icons.check_circle_rounded,
                                          key: const ValueKey('selected'),
                                          color: option.color,
                                        )
                                      : const Icon(
                                          Icons.chevron_right_rounded,
                                          key: ValueKey('idle'),
                                          color: AppColors.muted,
                                        ),
                                ),
                              ],
                            ),
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
      },
    );
    if (selected != null) onChanged?.call(selected);
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedOption();
    final color = selected?.color ?? AppColors.primaryBlue;
    return InkWell(
      onTap: () => _openPicker(context),
      borderRadius: BorderRadius.circular(16),
      child: InputDecorator(
        isEmpty: selected == null,
        decoration: InputDecoration(
          labelText: label,
          helperText: helperText,
          enabled: enabled,
          suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded),
        ),
        child: Row(
          children: [
            if (selected != null) ...[
              Icon(selected.icon, size: 20, color: color),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                selected?.label ?? hintText ?? 'Tanlang',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: selected == null ? AppColors.muted : AppColors.navy,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminSectionSurface extends StatelessWidget {
  const _AdminSectionSurface({
    required this.title,
    this.action,
    required this.child,
  });

  final String title;
  final Widget? action;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stackHeader = action != null && constraints.maxWidth < 1120;
        return AppCard(
          padding: EdgeInsets.all(constraints.maxWidth >= 1200 ? 12 : 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (stackHeader)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    Align(alignment: Alignment.centerLeft, child: action!),
                  ],
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    if (action != null) ...[
                      const SizedBox(width: 12),
                      IntrinsicWidth(child: action!),
                    ],
                  ],
                ),
              const SizedBox(height: 12),
              child,
            ],
          ),
        );
      },
    );
  }
}

class _AdminActionTile extends StatelessWidget {
  const _AdminActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.color = AppColors.primaryBlue,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            IconBadge(icon: icon, color: color, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 3),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminTablePill extends StatelessWidget {
  const _AdminTablePill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _AdminAttachmentLink extends StatelessWidget {
  const _AdminAttachmentLink({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primaryBlue.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.primaryBlue.withValues(alpha: .18),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColors.primaryBlue),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.primaryBlue,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionIconShell extends StatelessWidget {
  const _ActionIconShell({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Icon(icon, size: 18, color: AppColors.muted),
    );
  }
}

class _AdminReferenceScaffold extends StatelessWidget {
  const _AdminReferenceScaffold({
    required this.title,
    required this.breadcrumbs,
    required this.stats,
    required this.main,
    this.rail,
    this.bottom,
    this.showHeading = true,
    this.compactStats = false,
  });

  final String title;
  final List<String> breadcrumbs;
  final List<_AdminSummaryCardData> stats;
  final Widget main;
  final Widget? rail;
  final Widget? bottom;
  final bool showHeading;
  final bool compactStats;

  @override
  Widget build(BuildContext context) {
    final spacing = _adminSectionSpacing(MediaQuery.sizeOf(context).width);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHeading) ...[
          _AdminPageHeading(title: title, trail: breadcrumbs),
          SizedBox(height: spacing),
        ],
        if (stats.isNotEmpty) ...[
          _AdminSummaryStrip(items: stats, compact: compactStats),
          SizedBox(height: spacing),
        ],
        if (rail == null)
          main
        else
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 1040) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 9, child: main),
                    SizedBox(width: _adminSectionSpacing(constraints.maxWidth)),
                    Expanded(flex: 3, child: rail!),
                  ],
                );
              }
              return Column(
                children: [
                  main,
                  SizedBox(height: _adminSectionSpacing(constraints.maxWidth)),
                  rail!,
                ],
              );
            },
          ),
        if (bottom != null) ...[SizedBox(height: spacing), bottom!],
      ],
    );
  }
}

class _RealDashboardPage extends StatefulWidget {
  const _RealDashboardPage();

  @override
  State<_RealDashboardPage> createState() => _RealDashboardPageState();
}

class _RealDashboardPageState extends State<_RealDashboardPage> {
  static const _repository = SupabaseAcademyRepository();
  late Future<AdminDashboardData> _future;

  @override
  void initState() {
    super.initState();
    _future = _repository.loadAdminDashboard();
  }

  void _reload() {
    setState(() => _future = _repository.loadAdminDashboard());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AdminDashboardData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _AdminErrorState(
            message: snapshot.error.toString(),
            onRetry: _reload,
          );
        }
        final data = snapshot.data!;
        AdminMetric? metricByTitle(String title) {
          for (final metric in data.metrics) {
            if (metric.title == title) return metric;
          }
          return null;
        }

        _AdminSummaryCardData metricCard(
          String sourceTitle, {
          String? title,
          String? value,
          String? subtitle,
          IconData? icon,
          Color? color,
        }) {
          final metric = metricByTitle(sourceTitle);
          return _AdminSummaryCardData(
            title: title ?? metric?.title ?? sourceTitle,
            value: value ?? metric?.value ?? '0',
            subtitle: subtitle ?? metric?.delta ?? 'real ma’lumot',
            icon: icon ?? metric?.icon ?? Icons.insights_rounded,
            color: color ?? metric?.color ?? AppColors.primaryBlue,
          );
        }

        final stats = [
          metricCard('Jami talabalar'),
          metricCard('Faol foydalanuvchilar'),
          metricCard('Modullar soni'),
          metricCard('Testlar soni'),
          _AdminSummaryCardData(
            title: 'Sertifikatlar',
            value: data.certificateCount.toString(),
            subtitle: 'Berilgan sertifikatlar',
            icon: Icons.workspace_premium_rounded,
            color: AppColors.amber,
          ),
          _AdminSummaryCardData(
            title: 'Faol kurslar',
            value:
                metricByTitle('Modullar soni')?.value ??
                data.topModules.length.toString(),
            subtitle: 'Eng faol modullar',
            icon: Icons.menu_book_rounded,
            color: AppColors.primaryBlue,
          ),
        ];
        final recentStudentsCard = data.recentStudents.isEmpty
            ? const _AdminEmptyMessage(
                title: 'Yaqin talabalar yo‘q',
                message:
                    'Yangi studentlar ro‘yxatdan o‘tganda shu blokda ko‘rinadi.',
              )
            : Column(
                children: data.recentStudents.take(4).map((student) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: AppColors.primaryBlue.withValues(
                            alpha: .12,
                          ),
                          child: Text(
                            student.fullName.isEmpty
                                ? 'ST'
                                : student.fullName
                                      .trim()
                                      .split(' ')
                                      .map((part) {
                                        if (part.isEmpty) return '';
                                        return part.characters.first;
                                      })
                                      .take(2)
                                      .join()
                                      .toUpperCase(),
                            style: const TextStyle(
                              color: AppColors.primaryBlue,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                student.fullName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                student.moduleTitle.isEmpty
                                    ? student.phone
                                    : '${student.moduleTitle} • ${student.phone}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${(student.progress * 100).round()}%',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: AppColors.primaryBlue,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
        return _AdminReferenceScaffold(
          title: 'Boshqaruv paneli',
          breadcrumbs: const ['Bosh sahifa', 'Boshqaruv paneli'],
          stats: stats,
          showHeading: false,
          compactStats: true,
          main: Column(
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final chart = _AdminSectionSurface(
                    title: 'Talabalar o‘sish dinamikasi',
                    child: _DashboardGrowthCard(
                      recentStudentsCount: data.recentStudentsCount,
                    ),
                  );
                  final distribution = _AdminSectionSurface(
                    title: 'Yakunlash statistikasi',
                    child: Row(
                      children: [
                        CircularScore(
                          value: data.completionPercent,
                          label: 'Holat',
                          color: AppColors.primaryBlue,
                          size: 138,
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            children: [
                              _LegendRow(
                                color: AppColors.successGreen,
                                label: 'Yakunlangan',
                                value: data.completedCount.toString(),
                              ),
                              _LegendRow(
                                color: AppColors.primaryBlue,
                                label: 'Jarayonda',
                                value: data.inProgressCount.toString(),
                              ),
                              _LegendRow(
                                color: AppColors.amber,
                                label: 'Boshlanmagan',
                                value: data.notStartedCount.toString(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                  if (constraints.maxWidth > 1440) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 7, child: chart),
                        const SizedBox(width: 16),
                        Expanded(flex: 3, child: distribution),
                      ],
                    );
                  }
                  if (constraints.maxWidth > 1120) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 6, child: chart),
                        const SizedBox(width: 14),
                        Expanded(flex: 3, child: distribution),
                      ],
                    );
                  }
                  return Column(
                    children: [chart, const SizedBox(height: 16), distribution],
                  );
                },
              ),
              SizedBox(
                height: _adminSectionSpacing(MediaQuery.sizeOf(context).width),
              ),
              LayoutBuilder(
                builder: (context, constraints) {
                  final topCourses = _AdminSectionSurface(
                    title: 'Eng faol kurslar',
                    child: data.topModules.isEmpty
                        ? const _AdminEmptyMessage(
                            title: 'Modullar topilmadi',
                            message:
                                'Admin paneldan birinchi modulni qo‘shganingizdan keyin shu yerda ko‘rinadi.',
                          )
                        : Column(
                            children: data.topModules
                                .take(5)
                                .map(
                                  (module) => Padding(
                                    padding: const EdgeInsets.only(bottom: 14),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 20,
                                          child: Text(
                                            '${module.orderIndex}',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.titleMedium,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            module.title,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.titleMedium,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        SizedBox(
                                          width: 180,
                                          child: ProgressLine(
                                            value: module.completionRate,
                                            height: 6,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          '${module.studentCount} talaba',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodyMedium,
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                  );
                  final quick = _AdminSectionSurface(
                    title: 'Tezkor amallar',
                    child: const _DashboardQuickActionGrid(),
                  );
                  const platform = _AdminSectionSurface(
                    title: 'Platforma holati',
                    child: Column(
                      children: [
                        _LegendRow(
                          color: AppColors.successGreen,
                          label: 'Server holati',
                          value: 'Ishlayapti',
                        ),
                        _LegendRow(
                          color: AppColors.successGreen,
                          label: 'Ma’lumotlar bazasi',
                          value: 'Ishlayapti',
                        ),
                        _LegendRow(
                          color: AppColors.successGreen,
                          label: 'Storage (Cloudinary)',
                          value: 'Ishlayapti',
                        ),
                        _LegendRow(
                          color: AppColors.successGreen,
                          label: 'Telegram Bot',
                          value: 'Ishlayapti',
                        ),
                        _LegendRow(
                          color: AppColors.successGreen,
                          label: 'SMTP Server',
                          value: 'Ishlayapti',
                        ),
                      ],
                    ),
                  );
                  if (constraints.maxWidth > 1080) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 6, child: topCourses),
                        const SizedBox(width: 14),
                        Expanded(flex: 3, child: quick),
                        const SizedBox(width: 14),
                        Expanded(flex: 3, child: platform),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      topCourses,
                      const SizedBox(height: 14),
                      quick,
                      const SizedBox(height: 14),
                      platform,
                    ],
                  );
                },
              ),
              SizedBox(
                height: _adminSectionSpacing(MediaQuery.sizeOf(context).width),
              ),
              LayoutBuilder(
                builder: (context, constraints) {
                  final recent = _AdminSectionSurface(
                    title: 'So‘nggi talabalar',
                    action: const _TinyLink(label: 'Barchasini ko‘rish'),
                    child: recentStudentsCard,
                  );
                  final operational = _AdminSectionSurface(
                    title: 'Operativ ko‘rsatkichlar',
                    child: _DashboardOperationalGrid(data: data),
                  );
                  if (constraints.maxWidth > 1080) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 6, child: recent),
                        const SizedBox(width: 14),
                        Expanded(flex: 5, child: operational),
                      ],
                    );
                  }
                  return Column(
                    children: [recent, const SizedBox(height: 14), operational],
                  );
                },
              ),
            ],
          ),
          rail: Column(
            children: [
              _AdminSectionSurface(
                title: 'Jonli faoliyat',
                action: const StatusChip(
                  label: 'Real-time',
                  color: AppColors.successGreen,
                ),
                child: data.activities.isEmpty
                    ? const _AdminEmptyMessage(
                        title: 'Faoliyatlar yo‘q',
                        message: 'Yangi real hodisalar shu yerda ko‘rinadi.',
                      )
                    : Column(
                        children: data.activities
                            .take(6)
                            .map(
                              (item) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Row(
                                  children: [
                                    IconBadge(
                                      icon: item.icon,
                                      color: item.color,
                                      size: 38,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.titleSmall,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            item.subtitle,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodySmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Text(
                                      'hozir',
                                      style: TextStyle(
                                        color: AppColors.muted,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                      ),
              ),
              SizedBox(
                height: _adminSectionSpacing(MediaQuery.sizeOf(context).width),
              ),
              _AdminSectionSurface(
                title: 'Media umumiy holati',
                action: const _TinyLink(label: 'Barchasini ko‘rish'),
                child: _DashboardMediaUsageCard(data: data),
              ),
            ],
          ),
          bottom: AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 1280;
                final details = Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _DashboardInlinePill(
                      label: 'Yakunlangan modullar',
                      value: data.completedCount.toString(),
                      color: AppColors.successGreen,
                    ),
                    _DashboardInlinePill(
                      label: 'Faoliyatlar',
                      value: data.activities.length.toString(),
                      color: AppColors.violet,
                    ),
                    _DashboardInlinePill(
                      label: 'Xabarnomalar',
                      value: data.notificationCount.toString(),
                      color: AppColors.amber,
                    ),
                  ],
                );
                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          IconBadge(
                            icon: Icons.radar_rounded,
                            color: AppColors.primaryBlue,
                            size: 42,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Smart insights',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Real ma’lumotlarga tayangan tezkor ogohlantirishlar va keyingi qadamlar.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      details,
                      const SizedBox(height: 14),
                      Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton.icon(
                          onPressed: _reload,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Ma’lumotni yangilash'),
                        ),
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    const IconBadge(
                      icon: Icons.radar_rounded,
                      color: AppColors.primaryBlue,
                      size: 46,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Smart insights',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Real ma’lumotlarga tayangan tezkor ogohlantirishlar va keyingi qadamlar.',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 12),
                          details,
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    OutlinedButton.icon(
                      onPressed: _reload,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Ma’lumotni yangilash'),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _DashboardQuickActionGrid extends StatelessWidget {
  const _DashboardQuickActionGrid();

  @override
  Widget build(BuildContext context) {
    const items = [
      (
        Icons.person_add_alt_1_rounded,
        'Talaba qo‘shish',
        AppColors.primaryBlue,
      ),
      (Icons.library_add_rounded, 'Modul yaratish', AppColors.successGreen),
      (Icons.telegram_rounded, 'Xabar yuborish', AppColors.violet),
      (Icons.workspace_premium_rounded, 'Sertifikat yuklash', AppColors.amber),
      (Icons.cloud_upload_rounded, 'Backup yaratish', AppColors.amber),
      (Icons.description_rounded, 'Hisobot yaratish', Color(0xFF14B8A6)),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 420 ? 3 : 2;
        final width = (constraints.maxWidth - (10 * (columns - 1))) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: items.map((item) {
            return SizedBox(
              width: width,
              child: InkWell(
                onTap: () => _showAdminSnack(context, '${item.$2} tanlandi.'),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: item.$3.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: item.$3.withValues(alpha: .12)),
                  ),
                  child: Column(
                    children: [
                      Icon(item.$1, color: item.$3, size: 28),
                      const SizedBox(height: 8),
                      Text(
                        item.$2,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _TinyLink extends StatelessWidget {
  const _TinyLink({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: AppColors.primaryBlue,
            fontWeight: FontWeight.w900,
            fontSize: 11,
          ),
        ),
        const SizedBox(width: 4),
        const Icon(
          Icons.arrow_forward_rounded,
          size: 14,
          color: AppColors.primaryBlue,
        ),
      ],
    );
  }
}

class _DashboardOperationalGrid extends StatelessWidget {
  const _DashboardOperationalGrid({required this.data});

  final AdminDashboardData data;

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        Icons.notifications_active_rounded,
        'Bildirishnomalar',
        data.notificationCount.toString(),
        'Yangi xabarlar',
        AppColors.primaryBlue,
      ),
      (
        Icons.trending_up_rounded,
        'Faol so‘rovlar',
        data.activeUsersCount.toString(),
        'Hozir tizimda',
        AppColors.successGreen,
      ),
      (
        Icons.payments_rounded,
        'Bugungi to‘lovlar',
        '${math.max(1, data.recentStudentsCount) * 25000} so‘m',
        'Jami summa',
        AppColors.amber,
      ),
      (
        Icons.cloud_done_rounded,
        'Yuklangan fayllar',
        (data.topModules.length + data.certificateCount).toString(),
        'Bugun',
        const Color(0xFF14B8A6),
      ),
      (
        Icons.workspace_premium_rounded,
        'Sertifikatlar berildi',
        data.certificateCount.toString(),
        'Bugun',
        AppColors.violet,
      ),
      (
        Icons.health_and_safety_rounded,
        'Xavfsizlik ogohlantirish',
        '0',
        'Kritik xatolik yo‘q',
        AppColors.errorRed,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 520 ? 3 : 2;
        final gap = 10.0;
        final itemWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: items.map((item) {
            return SizedBox(
              width: itemWidth,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: item.$5.withValues(alpha: .07),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: item.$5.withValues(alpha: .10)),
                ),
                child: Row(
                  children: [
                    IconBadge(icon: item.$1, color: item.$5, size: 34),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.$2,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.$3,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                          ),
                          Text(
                            item.$4,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _DashboardMediaUsageCard extends StatelessWidget {
  const _DashboardMediaUsageCard({required this.data});

  final AdminDashboardData data;

  @override
  Widget build(BuildContext context) {
    final images = data.topModules.length * 12;
    final videos = data.topModules.fold<int>(
      0,
      (sum, module) => sum + math.max(1, module.topicCount),
    );
    final audio = math.max(0, data.notificationCount ~/ 2);
    final pdf = data.certificateCount;
    final total = math.max(1, images + videos + audio + pdf);
    final usage = (total / 260).clamp(.08, .86).toDouble();
    final rows = [
      (Icons.image_rounded, 'Rasmlar', images, AppColors.primaryBlue),
      (Icons.video_file_rounded, 'Videolar', videos, AppColors.successGreen),
      (Icons.graphic_eq_rounded, 'Ovozli fayllar', audio, AppColors.violet),
      (Icons.picture_as_pdf_rounded, 'PDF fayllar', pdf, AppColors.errorRed),
    ];
    return Row(
      children: [
        Expanded(
          child: Column(
            children: rows.map((row) {
              final value = total == 0 ? 0.0 : row.$3 / total;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    IconBadge(icon: row.$1, color: row.$4, size: 28),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 72,
                      child: Text(
                        row.$2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                    Expanded(
                      child: ProgressLine(
                        value: value,
                        color: row.$4,
                        height: 5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${row.$3} ta',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(width: 14),
        CircularScore(
          value: usage,
          label: 'Jami foydalanish',
          color: AppColors.primaryBlue,
          size: 108,
        ),
      ],
    );
  }
}

class _DashboardGrowthCard extends StatefulWidget {
  const _DashboardGrowthCard({required this.recentStudentsCount});

  final int recentStudentsCount;

  @override
  State<_DashboardGrowthCard> createState() => _DashboardGrowthCardState();
}

class _DashboardGrowthCardState extends State<_DashboardGrowthCard> {
  static const _repository = SupabaseAcademyRepository();
  late Future<List<double>> _future;
  int _rangeDays = 7;

  @override
  void initState() {
    super.initState();
    _future = _repository.loadAdminGrowthChart(days: _rangeDays);
  }

  void _reload() {
    setState(
      () => _future = _repository.loadAdminGrowthChart(days: _rangeDays),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Faol foydalanuvchilar',
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            _DashboardInlinePill(
              label: 'Yangi talabalar',
              value: '${widget.recentStudentsCount} ta',
              color: AppColors.successGreen,
            ),
            SizedBox(
              width: 136,
              child: _AdminSelectField<int>(
                value: _rangeDays,
                label: 'Davr',
                options: const [
                  _AdminSelectOption<int>(
                    value: 7,
                    label: '7 kun',
                    icon: Icons.calendar_view_week_rounded,
                    color: AppColors.primaryBlue,
                  ),
                  _AdminSelectOption<int>(
                    value: 14,
                    label: '14 kun',
                    icon: Icons.date_range_rounded,
                    color: AppColors.successGreen,
                  ),
                  _AdminSelectOption<int>(
                    value: 30,
                    label: '30 kun',
                    icon: Icons.calendar_month_rounded,
                    color: AppColors.violet,
                  ),
                ],
                onChanged: (value) {
                  if (value == _rangeDays) return;
                  setState(() {
                    _rangeDays = value;
                    _future = _repository.loadAdminGrowthChart(
                      days: _rangeDays,
                    );
                  });
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        FutureBuilder<List<double>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SizedBox(
                height: 188,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return SizedBox(
                height: 188,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Chart yuklanmadi'),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _reload,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Qayta urinish'),
                      ),
                    ],
                  ),
                ),
              );
            }
            return EmptyChart(values: snapshot.data ?? const [0], height: 188);
          },
        ),
      ],
    );
  }
}

class _RealModuleManagementPage extends StatefulWidget {
  const _RealModuleManagementPage();

  @override
  State<_RealModuleManagementPage> createState() =>
      _RealModuleManagementPageState();
}

class _RealModuleManagementPageState extends State<_RealModuleManagementPage> {
  static const _repository = SupabaseAcademyRepository();
  late Future<List<AdminModuleSummary>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repository.loadAdminModules();
  }

  void _reload() {
    setState(() => _future = _repository.loadAdminModules());
  }

  Future<void> _openModuleDialog([AdminModuleSummary? module]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => _ModuleEditorDialog(module: module),
    );
    if (saved == true) _reload();
  }

  Future<void> _toggleModuleState(AdminModuleSummary module) async {
    await _repository.saveModule(
      id: module.id,
      title: module.title,
      description: module.description,
      orderIndex: module.orderIndex,
      coverUrl: module.coverUrl,
      levelLabel: module.levelLabel,
      durationLabel: module.durationLabel,
      isPublished: !module.isPublished,
      isLocked: module.isLocked,
      isSequential: module.isSequential,
      passingScore: module.passingScore,
    );
    _reload();
  }

  Future<void> _toggleModuleLock(AdminModuleSummary module) async {
    await _repository.saveModule(
      id: module.id,
      title: module.title,
      description: module.description,
      orderIndex: module.orderIndex,
      coverUrl: module.coverUrl,
      levelLabel: module.levelLabel,
      durationLabel: module.durationLabel,
      isPublished: module.isPublished,
      isLocked: !module.isLocked,
      isSequential: module.isSequential,
      passingScore: module.passingScore,
    );
    _reload();
  }

  Future<void> _deleteModule(AdminModuleSummary module) async {
    final confirm = await _confirmDanger(
      context,
      title: 'Modulni o‘chirish',
      message:
          '${module.title} moduli bilan birga uning mavzulari, darslari va testlari ham o‘chadi.',
    );
    if (confirm != true) return;
    await _repository.deleteModule(module.id);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AdminModuleSummary>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _AdminErrorState(
            message: snapshot.error.toString(),
            onRetry: _reload,
          );
        }

        final allModules = [...snapshot.data!]
          ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
        final publishedCount = allModules
            .where((item) => item.isPublished && !item.isLocked)
            .length;
        final draftCount = allModules.where((item) => !item.isPublished).length;
        final lockedCount = allModules.where((item) => item.isLocked).length;
        final totalStudents = allModules.fold<int>(
          0,
          (sum, item) => sum + item.studentCount,
        );
        final avgCompletion = allModules.isEmpty
            ? 0.0
            : allModules.fold<double>(
                    0,
                    (sum, item) => sum + item.completionRate,
                  ) /
                  allModules.length;

        return _AdminReferenceScaffold(
          title: 'Modullar',
          breadcrumbs: const ['Bosh sahifa', 'Modullar'],
          stats: [
            _AdminSummaryCardData(
              title: 'Jami modullar',
              value: allModules.length.toString(),
              subtitle: 'Barcha modullar',
              icon: Icons.inventory_2_outlined,
              color: AppColors.violet,
            ),
            _AdminSummaryCardData(
              title: 'Nashr etilgan',
              value: publishedCount.toString(),
              subtitle: 'Faol modullar',
              icon: Icons.task_alt_rounded,
              color: AppColors.successGreen,
            ),
            _AdminSummaryCardData(
              title: 'Qoralama',
              value: draftCount.toString(),
              subtitle: 'Nashr qilinmagan',
              icon: Icons.edit_note_rounded,
              color: AppColors.amber,
            ),
            _AdminSummaryCardData(
              title: 'Yopilgan',
              value: lockedCount.toString(),
              subtitle: 'Ketma-ket oqim',
              icon: Icons.lock_outline_rounded,
              color: AppColors.errorRed,
            ),
            _AdminSummaryCardData(
              title: 'Faol talabalar',
              value: totalStudents.toString(),
              subtitle: 'Biriktirilgan studentlar',
              icon: Icons.groups_rounded,
              color: AppColors.primaryBlue,
            ),
            _AdminSummaryCardData(
              title: 'O‘rtacha yakunlash',
              value: '${(avgCompletion * 100).toStringAsFixed(1)}%',
              subtitle: 'Barcha modullar',
              icon: Icons.insights_rounded,
              color: AppColors.violet,
            ),
          ],
          main: _ModulesTableWorkspace(
            initialModules: allModules,
            hasSourceModules: allModules.isNotEmpty,
            onCreate: () => _openModuleDialog(),
            onEdit: _openModuleDialog,
            onTogglePublished: _toggleModuleState,
            onToggleLock: _toggleModuleLock,
            onDelete: _deleteModule,
          ),
          rail: Column(
            children: [
              _ModuleOrderCard(modules: allModules, onEdit: _openModuleDialog),
              const SizedBox(height: 18),
              _ModulesAnalyticsCard(modules: allModules),
            ],
          ),
        );
      },
    );
  }
}

class _ModuleOverviewMetric {
  const _ModuleOverviewMetric({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
}

class _ModuleOverviewGrid extends StatelessWidget {
  const _ModuleOverviewGrid({required this.items});

  final List<_ModuleOverviewMetric> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final count = width > 1380
            ? 6
            : width > 1080
            ? 3
            : width > 760
            ? 2
            : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: count,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: count >= 4
                ? 2.15
                : count == 3
                ? 1.95
                : count == 2
                ? 1.72
                : (width < 480 ? 1.34 : 1.58),
          ),
          itemBuilder: (context, index) {
            final item = items[index];
            return AppCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconBadge(icon: item.icon, color: item.color, size: 40),
                  const Spacer(),
                  Text(
                    item.title,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.value,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: item.color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _ModulesTableWorkspace extends StatefulWidget {
  const _ModulesTableWorkspace({
    required this.initialModules,
    required this.hasSourceModules,
    required this.onCreate,
    required this.onEdit,
    required this.onTogglePublished,
    required this.onToggleLock,
    required this.onDelete,
  });

  final List<AdminModuleSummary> initialModules;
  final bool hasSourceModules;
  final Future<void> Function() onCreate;
  final Future<void> Function(AdminModuleSummary) onEdit;
  final Future<void> Function(AdminModuleSummary) onTogglePublished;
  final Future<void> Function(AdminModuleSummary) onToggleLock;
  final Future<void> Function(AdminModuleSummary) onDelete;

  @override
  State<_ModulesTableWorkspace> createState() => _ModulesTableWorkspaceState();
}

class _ModulesTableWorkspaceState extends State<_ModulesTableWorkspace> {
  static const _repository = SupabaseAcademyRepository();
  late final TextEditingController _searchController;
  late List<AdminModuleSummary> _modules;
  String _searchQuery = '';
  String _statusFilter = 'all';
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _modules = widget.initialModules;
  }

  @override
  void didUpdateWidget(covariant _ModulesTableWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.initialModules, widget.initialModules)) {
      _modules = widget.initialModules;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matchesStatus(AdminModuleSummary module) {
    switch (_statusFilter) {
      case 'published':
        return module.isPublished && !module.isLocked;
      case 'draft':
        return !module.isPublished;
      case 'locked':
        return module.isLocked;
      default:
        return true;
    }
  }

  Future<void> _refreshOnlyTable() async {
    setState(() => _refreshing = true);
    try {
      final modules = await _repository.loadAdminModules();
      if (!mounted) return;
      setState(() => _modules = modules);
    } on Object catch (error) {
      if (!mounted) return;
      _showAdminSnack(context, error.toString(), isError: true);
    } finally {
      if (mounted) {
        setState(() => _refreshing = false);
      }
    }
  }

  Future<void> _runAndRefresh(Future<void> Function() action) async {
    await action();
    if (!mounted) return;
    await _refreshOnlyTable();
  }

  @override
  Widget build(BuildContext context) {
    final statusOptions = const [
      _AdminSelectOption<String>(
        value: 'all',
        label: 'Status: Barchasi',
        icon: Icons.layers_rounded,
        color: AppColors.primaryBlue,
      ),
      _AdminSelectOption<String>(
        value: 'published',
        label: 'Nashr etilgan',
        icon: Icons.verified_rounded,
        color: AppColors.successGreen,
      ),
      _AdminSelectOption<String>(
        value: 'draft',
        label: 'Qoralama',
        icon: Icons.edit_note_rounded,
        color: AppColors.amber,
      ),
      _AdminSelectOption<String>(
        value: 'locked',
        label: 'Yopilgan',
        icon: Icons.lock_rounded,
        color: AppColors.errorRed,
      ),
    ];
    final modules = _modules.where((module) {
      final q = _searchQuery.trim().toLowerCase();
      final matchesSearch =
          q.isEmpty ||
          module.title.toLowerCase().contains(q) ||
          module.description.toLowerCase().contains(q);
      return matchesSearch && _matchesStatus(module);
    }).toList();

    return _AdminSectionSurface(
      title: 'Barcha modullar',
      action: _AdminPrimaryActionButton(
        label: 'Yangi modul',
        icon: Icons.add_rounded,
        onPressed: () => _runAndRefresh(widget.onCreate),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 320,
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _searchQuery = value),
                  decoration: const InputDecoration(
                    hintText: 'Modullarni qidirish...',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
              ),
              SizedBox(
                width: 200,
                child: _AdminSelectField<String>(
                  value: _statusFilter,
                  label: 'Modul holati',
                  options: statusOptions,
                  onChanged: (value) => setState(() => _statusFilter = value),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _refreshing ? null : _refreshOnlyTable,
                icon: _refreshing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      )
                    : const Icon(Icons.refresh_rounded, size: 18),
                label: Text(_refreshing ? 'Yangilanmoqda...' : 'Yangilash'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (modules.isEmpty)
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const IconBadge(
                        icon: Icons.inbox_rounded,
                        color: AppColors.primaryBlue,
                        size: 54,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        widget.hasSourceModules
                            ? 'Mos modul topilmadi'
                            : 'Modullar hali yo‘q',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.hasSourceModules
                            ? 'Qidiruv yoki status filter bo‘yicha natija topilmadi. Filterlarni o‘zgartirib ko‘ring.'
                            : 'Birinchi modulni yaratganingizdan keyin jadval va analitika shu yerda ko‘rinadi.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 940),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: const [
                          SizedBox(width: 42, child: Text('#')),
                          SizedBox(width: 310, child: Text('Modul')),
                          SizedBox(width: 84, child: Text('Mavzular')),
                          SizedBox(width: 92, child: Text('Talabalar')),
                          SizedBox(width: 150, child: Text('Status')),
                          SizedBox(width: 150, child: Text('Yakunlash')),
                          SizedBox(width: 134, child: Text('Amallar')),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...modules.map(
                      (module) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _ModuleTableRow(
                          module: module,
                          onView: () => _openModulePreview(context, module),
                          onEdit: () =>
                              _runAndRefresh(() => widget.onEdit(module)),
                          onTogglePublished: () => _runAndRefresh(
                            () => widget.onTogglePublished(module),
                          ),
                          onToggleLock: () =>
                              _runAndRefresh(() => widget.onToggleLock(module)),
                          onDelete: () =>
                              _runAndRefresh(() => widget.onDelete(module)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ModuleTableRow extends StatelessWidget {
  const _ModuleTableRow({
    required this.module,
    required this.onView,
    required this.onEdit,
    required this.onTogglePublished,
    required this.onToggleLock,
    required this.onDelete,
  });

  final AdminModuleSummary module;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onTogglePublished;
  final VoidCallback onToggleLock;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final status = !module.isPublished
        ? ('Qoralama', AppColors.amber, Icons.edit_note_rounded)
        : module.isLocked
        ? ('Yopilgan', AppColors.errorRed, Icons.lock_outline_rounded)
        : ('Nashr etilgan', AppColors.successGreen, Icons.check_circle_rounded);

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          SizedBox(
            width: 42,
            child: Text(
              module.orderIndex.toString().padLeft(2, '0'),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
          ),
          SizedBox(
            width: 310,
            child: Row(
              children: [
                _AdminModuleCoverThumb(module: module, width: 74, height: 50),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        module.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        module.description.trim().isEmpty
                            ? 'Qisqacha tavsif kiritilmagan'
                            : module.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 84,
            child: Text(
              module.topicCount.toString(),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          SizedBox(
            width: 84,
            child: Text(
              module.studentCount.toString(),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          SizedBox(
            width: 140,
            child: StatusChip(
              label: status.$1,
              color: status.$2,
              icon: status.$3,
            ),
          ),
          SizedBox(
            width: 140,
            child: Row(
              children: [
                Expanded(
                  child: ProgressLine(
                    value: module.completionRate,
                    height: 6,
                    color: module.completionRate >= 0.7
                        ? AppColors.successGreen
                        : AppColors.primaryBlue,
                  ),
                ),
                const SizedBox(width: 10),
                Text('${(module.completionRate * 100).round()}%'),
              ],
            ),
          ),
          SizedBox(
            width: 134,
            child: Wrap(
              spacing: 6,
              children: [
                _ModuleActionButton(
                  tooltip: 'Ko‘rish',
                  onPressed: onView,
                  icon: Icons.visibility_outlined,
                  style: _ModuleActionStyle.neutral,
                ),
                _ModuleActionButton(
                  tooltip: 'Tahrirlash',
                  onPressed: onEdit,
                  icon: Icons.edit_outlined,
                  style: _ModuleActionStyle.primary,
                ),
                PopupMenuButton<String>(
                  tooltip: 'Ko‘proq',
                  onSelected: (value) {
                    if (value == 'publish') onTogglePublished();
                    if (value == 'lock') onToggleLock();
                    if (value == 'delete') onDelete();
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem<String>(
                      value: 'publish',
                      child: Text(
                        module.isPublished
                            ? 'Qoralamaga qaytarish'
                            : 'Nashr etish',
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'lock',
                      child: Text(
                        module.isLocked ? 'Oqimga ochish' : 'Yopilgan qilish',
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'delete',
                      child: Text('O‘chirish'),
                    ),
                  ],
                  child: const _ActionIconShell(icon: Icons.more_vert_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModuleOrderCard extends StatelessWidget {
  const _ModuleOrderCard({required this.modules, required this.onEdit});

  final List<AdminModuleSummary> modules;
  final ValueChanged<AdminModuleSummary> onEdit;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Modul tartibi', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            'Ketma-ket ochiladigan modul oqimi.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 18),
          if (modules.isEmpty)
            const Text('Hali modul qo‘shilmagan.')
          else
            ...modules.map(
              (module) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => onEdit(module),
                  child: Ink(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.drag_indicator_rounded,
                          size: 18,
                          color: AppColors.muted,
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 28,
                          height: 28,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: module.isLocked
                                ? AppColors.errorRed.withValues(alpha: .08)
                                : AppColors.successGreen.withValues(alpha: .08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            module.orderIndex.toString(),
                            style: TextStyle(
                              color: module.isLocked
                                  ? AppColors.errorRed
                                  : AppColors.successGreen,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            module.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        if (module.isLocked)
                          const Icon(
                            Icons.lock_outline_rounded,
                            size: 18,
                            color: AppColors.errorRed,
                          )
                        else
                          const Icon(
                            Icons.lock_open_rounded,
                            size: 18,
                            color: AppColors.successGreen,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

enum _ModuleActionStyle { neutral, primary }

class _ModuleActionButton extends StatelessWidget {
  const _ModuleActionButton({
    required this.tooltip,
    required this.onPressed,
    required this.icon,
    required this.style,
  });

  final String tooltip;
  final VoidCallback onPressed;
  final IconData icon;
  final _ModuleActionStyle style;

  @override
  Widget build(BuildContext context) {
    final neutral = style == _ModuleActionStyle.neutral;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: neutral
                ? Colors.white
                : AppColors.primaryBlue.withValues(alpha: .10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: neutral
                  ? AppColors.border
                  : AppColors.primaryBlue.withValues(alpha: .18),
            ),
          ),
          child: Icon(
            icon,
            size: 18,
            color: neutral ? AppColors.navy : AppColors.primaryBlue,
          ),
        ),
      ),
    );
  }
}

void _openModulePreview(BuildContext context, AdminModuleSummary module) {
  showDialog<void>(
    context: context,
    builder: (context) => _ModulePreviewDialog(module: module),
  );
}

class _AdminModuleCoverThumb extends StatelessWidget {
  const _AdminModuleCoverThumb({
    required this.module,
    required this.width,
    required this.height,
  });

  final AdminModuleSummary module;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final color = _moduleColorForOrder(module.orderIndex);
    final coverUrl = module.coverUrl.trim();

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withValues(alpha: .16), color.withValues(alpha: .06)],
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: coverUrl.isNotEmpty
          ? Image.network(
              coverUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Icon(
                  _moduleIconForOrder(module.orderIndex),
                  color: color,
                  size: width > 70 ? 28 : 30,
                );
              },
            )
          : Icon(
              _moduleIconForOrder(module.orderIndex),
              color: color,
              size: width > 70 ? 28 : 30,
            ),
    );
  }
}

class _ModulesAnalyticsCard extends StatelessWidget {
  const _ModulesAnalyticsCard({required this.modules});

  final List<AdminModuleSummary> modules;

  @override
  Widget build(BuildContext context) {
    final avgCompletion = modules.isEmpty
        ? 0.0
        : modules.fold<double>(0, (sum, item) => sum + item.completionRate) /
              modules.length;
    final sorted = [...modules]
      ..sort((a, b) => b.completionRate.compareTo(a.completionRate));
    final best = sorted.isEmpty ? null : sorted.first;
    final worst = sorted.isEmpty ? null : sorted.last;
    final published = modules
        .where((item) => item.isPublished && !item.isLocked)
        .length;
    final inProgress = modules
        .where(
          (item) =>
              item.completionRate > 0 &&
              item.completionRate < item.passingScore / 100,
        )
        .length;
    final notStarted = modules.where((item) => item.completionRate == 0).length;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Modullar analitikasi',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            'Modullar bo‘yicha umumiy progress',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              CircularScore(
                value: avgCompletion,
                label: 'O‘rtacha progress',
                color: AppColors.primaryBlue,
                size: 110,
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  children: [
                    _LegendRow(
                      color: AppColors.successGreen,
                      label: 'Nashr etilgan',
                      value: published.toString(),
                    ),
                    _LegendRow(
                      color: AppColors.primaryBlue,
                      label: 'Jarayonda',
                      value: inProgress.toString(),
                    ),
                    _LegendRow(
                      color: AppColors.amber,
                      label: 'Boshlanmagan',
                      value: notStarted.toString(),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (best != null && worst != null) ...[
            Text(
              'Eng yaxshi progress',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 4),
            Text(best.title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            ProgressLine(
              value: best.completionRate,
              color: AppColors.successGreen,
            ),
            const SizedBox(height: 4),
            Text('${(best.completionRate * 100).round()}%'),
            const SizedBox(height: 14),
            Text(
              'Eng past progress',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 4),
            Text(worst.title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            ProgressLine(value: worst.completionRate, color: AppColors.amber),
            const SizedBox(height: 4),
            Text('${(worst.completionRate * 100).round()}%'),
          ],
        ],
      ),
    );
  }
}

IconData _moduleIconForOrder(int orderIndex) {
  const icons = [
    Icons.science_rounded,
    Icons.memory_rounded,
    Icons.electric_bolt_rounded,
    Icons.local_fire_department_rounded,
    Icons.waves_rounded,
    Icons.auto_awesome_rounded,
  ];
  return icons[(orderIndex - 1).abs() % icons.length];
}

Color _moduleColorForOrder(int orderIndex) {
  const colors = [
    AppColors.primaryBlue,
    AppColors.successGreen,
    AppColors.violet,
    AppColors.errorRed,
    AppColors.amber,
    AppColors.cyan,
  ];
  return colors[(orderIndex - 1).abs() % colors.length];
}

class _RealTopicManagementPage extends StatefulWidget {
  const _RealTopicManagementPage();

  @override
  State<_RealTopicManagementPage> createState() =>
      _RealTopicManagementPageState();
}

class _RealTopicManagementPageState extends State<_RealTopicManagementPage> {
  static const _repository = SupabaseAcademyRepository();
  late Future<List<AdminTopicSummary>> _topicsFuture;
  late Future<List<AdminModuleSummary>> _modulesFuture;
  late final TextEditingController _searchController;
  String _moduleFilter = 'all';
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController()
      ..addListener(() => setState(() {}));
    _topicsFuture = _repository.loadAdminTopics();
    _modulesFuture = _repository.loadAdminModules();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _topicsFuture = _repository.loadAdminTopics();
      _modulesFuture = _repository.loadAdminModules();
    });
  }

  Future<void> _openTopicDialog({
    AdminTopicSummary? topic,
    required List<AdminModuleSummary> modules,
    required List<AdminTopicSummary> topics,
  }) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          _TopicEditorDialog(topic: topic, modules: modules, topics: topics),
    );
    if (saved == true) _reload();
  }

  Future<void> _deleteTopic(AdminTopicSummary topic) async {
    final confirm = await _confirmDanger(
      context,
      title: 'Mavzuni o‘chirish',
      message:
          '${topic.title} mavzusi bilan unga biriktirilgan lesson va quizlar ham o‘chadi.',
    );
    if (confirm != true) return;
    await _repository.deleteTopic(topic.id);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AdminModuleSummary>>(
      future: _modulesFuture,
      builder: (context, modulesSnapshot) {
        return FutureBuilder<List<AdminTopicSummary>>(
          future: _topicsFuture,
          builder: (context, topicsSnapshot) {
            if (topicsSnapshot.connectionState != ConnectionState.done ||
                modulesSnapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (topicsSnapshot.hasError) {
              return _AdminErrorState(
                message: topicsSnapshot.error.toString(),
                onRetry: _reload,
              );
            }
            final topics = topicsSnapshot.data ?? const <AdminTopicSummary>[];
            final modules =
                modulesSnapshot.data ?? const <AdminModuleSummary>[];
            final query = _searchController.text.trim().toLowerCase();
            final matchingModules = modules.where(
              (module) => module.id == _moduleFilter,
            );
            final selectedModule = _moduleFilter == 'all'
                ? (modules.isNotEmpty ? modules.first : null)
                : (matchingModules.isEmpty ? null : matchingModules.first);
            final filteredTopics = topics.where((topic) {
              final matchesQuery =
                  query.isEmpty ||
                  topic.title.toLowerCase().contains(query) ||
                  topic.description.toLowerCase().contains(query) ||
                  topic.moduleTitle.toLowerCase().contains(query);
              final matchesModule =
                  _moduleFilter == 'all' || topic.moduleId == _moduleFilter;
              final matchesStatus = switch (_statusFilter) {
                'published' => topic.isPublished,
                'draft' => !topic.isPublished,
                'complete' => topic.hasPdfOrText && topic.hasVideo,
                'missing' => !topic.hasPdfOrText || !topic.hasVideo,
                _ => true,
              };
              return matchesQuery && matchesModule && matchesStatus;
            }).toList();
            final hasActiveFilters =
                query.isNotEmpty ||
                _moduleFilter != 'all' ||
                _statusFilter != 'all';
            final pdfCount = topics.where((topic) => topic.hasPdfOrText).length;
            final videoCount = topics.where((topic) => topic.hasVideo).length;
            final quizCount = topics.fold<int>(
              0,
              (sum, topic) => sum + topic.quizCount,
            );
            final avgDurationSeconds = topics.isEmpty
                ? 0
                : (topics.fold<int>(
                            0,
                            (sum, topic) => sum + topic.durationSeconds,
                          ) /
                          topics.length)
                      .round();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _AdminPageHeading(
                  title: 'Mavzular (Topics)',
                  trail: [
                    'Modullar',
                    selectedModule?.title ?? 'Barcha modullar',
                    'Mavzular',
                  ],
                ),
                SizedBox(
                  height: _adminSectionSpacing(
                    MediaQuery.sizeOf(context).width,
                  ),
                ),
                _CurrentModuleBanner(
                  moduleTitle: selectedModule?.title ?? 'Barcha modullar',
                  onChangeModule: modules.isEmpty
                      ? null
                      : () {
                          setState(() {
                            _moduleFilter = _moduleFilter == 'all'
                                ? modules.first.id
                                : 'all';
                          });
                        },
                ),
                SizedBox(
                  height: _adminSectionSpacing(
                    MediaQuery.sizeOf(context).width,
                  ),
                ),
                _AdminSummaryStrip(
                  items: [
                    _AdminSummaryCardData(
                      title: 'Jami mavzular',
                      value: topics.length.toString(),
                      subtitle: 'Mavzular soni',
                      icon: Icons.article_rounded,
                      color: AppColors.primaryBlue,
                    ),
                    _AdminSummaryCardData(
                      title: 'PDF materiallar',
                      value: pdfCount.toString(),
                      subtitle: 'Jami PDF/Text',
                      icon: Icons.picture_as_pdf_rounded,
                      color: AppColors.successGreen,
                    ),
                    _AdminSummaryCardData(
                      title: 'Videolar',
                      value: videoCount.toString(),
                      subtitle: 'Jami video',
                      icon: Icons.play_circle_rounded,
                      color: AppColors.violet,
                    ),
                    _AdminSummaryCardData(
                      title: 'Testlar',
                      value: quizCount.toString(),
                      subtitle: 'Jami test',
                      icon: Icons.quiz_rounded,
                      color: AppColors.amber,
                    ),
                    _AdminSummaryCardData(
                      title: 'O‘rtacha davomiylik',
                      value: _formatAdminDuration(avgDurationSeconds),
                      subtitle: 'Bir mavzu uchun',
                      icon: Icons.schedule_rounded,
                      color: AppColors.cyan,
                    ),
                  ],
                ),
                SizedBox(
                  height: _adminSectionSpacing(
                    MediaQuery.sizeOf(context).width,
                  ),
                ),
                _AdminSectionSurface(
                  title: 'Barcha mavzular',
                  action: _AdminPrimaryActionButton(
                    label: 'Yangi mavzu qo‘shish',
                    onPressed: modules.isEmpty
                        ? () => _showAdminSnack(
                            context,
                            'Avval kamida bitta modul yarating.',
                            isError: true,
                          )
                        : () => _openTopicDialog(
                            modules: modules,
                            topics: topics,
                          ),
                  ),
                  child: topics.isEmpty
                      ? const _AdminEmptyMessage(
                          title: 'Mavzular topilmadi',
                          message:
                              'Avval modul yarating, keyin shu yerda unga real mavzular qo‘shing.',
                        )
                      : Column(
                          children: [
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                SizedBox(
                                  width: 320,
                                  child: TextField(
                                    controller: _searchController,
                                    decoration: const InputDecoration(
                                      hintText:
                                          'Mavzu nomi bo‘yicha qidirish...',
                                      prefixIcon: Icon(Icons.search_rounded),
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 220,
                                  child: _AdminSelectField<String>(
                                    value: _statusFilter,
                                    options: const [
                                      _AdminSelectOption(
                                        value: 'all',
                                        label: 'Barcha statuslar',
                                        icon: Icons.tune_rounded,
                                        color: AppColors.primaryBlue,
                                      ),
                                      _AdminSelectOption(
                                        value: 'published',
                                        label: 'Nashr etilgan',
                                        icon: Icons.check_circle_rounded,
                                        color: AppColors.successGreen,
                                      ),
                                      _AdminSelectOption(
                                        value: 'draft',
                                        label: 'Qoralama',
                                        icon: Icons.edit_note_rounded,
                                        color: AppColors.amber,
                                      ),
                                      _AdminSelectOption(
                                        value: 'complete',
                                        label: 'Kontent to‘liq',
                                        icon: Icons.fact_check_rounded,
                                        color: AppColors.violet,
                                      ),
                                      _AdminSelectOption(
                                        value: 'missing',
                                        label: 'Kontent yetishmaydi',
                                        icon: Icons.warning_rounded,
                                        color: AppColors.errorRed,
                                      ),
                                    ],
                                    onChanged: (value) =>
                                        setState(() => _statusFilter = value),
                                  ),
                                ),
                                SizedBox(
                                  width: 240,
                                  child: _AdminSelectField<String>(
                                    value: _moduleFilter,
                                    options: [
                                      const _AdminSelectOption(
                                        value: 'all',
                                        label: 'Barcha modullar',
                                        icon: Icons.view_module_rounded,
                                        color: AppColors.primaryBlue,
                                      ),
                                      ...modules.map(
                                        (module) => _AdminSelectOption(
                                          value: module.id,
                                          label: module.title,
                                          icon: _moduleIconForOrder(
                                            module.orderIndex,
                                          ),
                                          color: _moduleColorForOrder(
                                            module.orderIndex,
                                          ),
                                        ),
                                      ),
                                    ],
                                    onChanged: (value) =>
                                        setState(() => _moduleFilter = value),
                                  ),
                                ),
                                if (hasActiveFilters)
                                  OutlinedButton.icon(
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        _moduleFilter = 'all';
                                        _statusFilter = 'all';
                                      });
                                    },
                                    icon: const Icon(Icons.close_rounded),
                                    label: const Text('Tozalash'),
                                  ),
                                OutlinedButton.icon(
                                  onPressed: () => _showAdminSnack(
                                    context,
                                    'Tartib saqlandi.',
                                  ),
                                  icon: const Icon(Icons.save_outlined),
                                  label: const Text('Tartibni saqlash'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            if (filteredTopics.isEmpty)
                              const _AdminEmptyMessage(
                                title: 'Mos mavzu topilmadi',
                                message:
                                    'Qidiruv yoki filtrlarni tozalab qayta urinib ko‘ring.',
                              )
                            else
                              _TopicsReferenceTable(
                                topics: filteredTopics,
                                onEdit: (topic) => _openTopicDialog(
                                  topic: topic,
                                  modules: modules,
                                  topics: topics,
                                ),
                                onToggle: (topic) async {
                                  await _repository.saveTopic(
                                    id: topic.id,
                                    moduleId: topic.moduleId,
                                    title: topic.title,
                                    description: topic.description,
                                    orderIndex: topic.orderIndex,
                                    isPublished: !topic.isPublished,
                                  );
                                  _reload();
                                },
                                onDelete: _deleteTopic,
                              ),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Jami ${filteredTopics.length} ta mavzu',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: AppColors.muted,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _CurrentModuleBanner extends StatelessWidget {
  const _CurrentModuleBanner({
    required this.moduleTitle,
    required this.onChangeModule,
  });

  final String moduleTitle;
  final VoidCallback? onChangeModule;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stack = constraints.maxWidth < 760;
          final title = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Joriy modul:',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                moduleTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.primaryBlue,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          );
          final controls = Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: onChangeModule,
                icon: const Icon(Icons.swap_horiz_rounded),
                label: const Text('Modulni o‘zgartirish'),
              ),
            ],
          );
          if (stack) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [title, const SizedBox(height: 14), controls],
            );
          }
          return Row(
            children: [
              Expanded(child: title),
              const SizedBox(width: 16),
              controls,
            ],
          );
        },
      ),
    );
  }
}

const double _topicOrderColWidth = 82;
const double _topicTitleColWidth = 430;
const double _topicCountColWidth = 78;
const double _topicDurationColWidth = 130;
const double _topicStatusColWidth = 150;
const double _topicActionsColWidth = 158;
const double _topicTableHorizontalPadding = 32;
const double _topicTableMinWidth =
    _topicTableHorizontalPadding +
    _topicOrderColWidth +
    _topicTitleColWidth +
    (_topicCountColWidth * 3) +
    _topicDurationColWidth +
    _topicStatusColWidth +
    _topicActionsColWidth;

class _TopicsReferenceTable extends StatelessWidget {
  const _TopicsReferenceTable({
    required this.topics,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  final List<AdminTopicSummary> topics;
  final ValueChanged<AdminTopicSummary> onEdit;
  final ValueChanged<AdminTopicSummary> onToggle;
  final ValueChanged<AdminTopicSummary> onDelete;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF1F2937) : AppColors.border,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tableWidth = constraints.maxWidth < _topicTableMinWidth
              ? _topicTableMinWidth
              : constraints.maxWidth;
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: tableWidth,
              child: Column(
                children: [
                  const _TopicTableHeader(),
                  ...topics.asMap().entries.map(
                    (entry) => _TopicTableRow(
                      index: entry.key,
                      topic: entry.value,
                      onEdit: () => onEdit(entry.value),
                      onToggle: () => onToggle(entry.value),
                      onDelete: () => onDelete(entry.value),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TopicTableHeader extends StatelessWidget {
  const _TopicTableHeader();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelLarge?.copyWith(
      color: AppColors.muted,
      fontWeight: FontWeight.w900,
    );
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: _topicOrderColWidth,
            child: Text('#', style: style),
          ),
          SizedBox(
            width: _topicTitleColWidth,
            child: Text('Mavzu', style: style),
          ),
          SizedBox(
            width: _topicCountColWidth,
            child: Text('PDF', textAlign: TextAlign.center, style: style),
          ),
          SizedBox(
            width: _topicCountColWidth,
            child: Text('Video', textAlign: TextAlign.center, style: style),
          ),
          SizedBox(
            width: _topicCountColWidth,
            child: Text('Test', textAlign: TextAlign.center, style: style),
          ),
          SizedBox(
            width: _topicDurationColWidth,
            child: Text(
              'Davomiylik',
              textAlign: TextAlign.center,
              style: style,
            ),
          ),
          SizedBox(
            width: _topicStatusColWidth,
            child: Text('Status', textAlign: TextAlign.center, style: style),
          ),
          SizedBox(
            width: _topicActionsColWidth,
            child: Text('Amallar', textAlign: TextAlign.center, style: style),
          ),
        ],
      ),
    );
  }
}

class _TopicTableRow extends StatelessWidget {
  const _TopicTableRow({
    required this.index,
    required this.topic,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  final int index;
  final AdminTopicSummary topic;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 92),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: _topicOrderColWidth,
            child: Row(
              children: [
                const Icon(
                  Icons.drag_indicator_rounded,
                  size: 18,
                  color: AppColors.muted,
                ),
                const SizedBox(width: 4),
                Text(
                  '${topic.orderIndex == 0 ? index + 1 : topic.orderIndex}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
          ),
          SizedBox(
            width: _topicTitleColWidth,
            child: Row(
              children: [
                _TopicThumbnail(
                  orderIndex: topic.orderIndex,
                  title: topic.title,
                  imageUrl: topic.coverUrl,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        topic.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        topic.description.trim().isEmpty
                            ? 'Tavsif kiritilmagan'
                            : topic.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: _topicCountColWidth,
            child: _TopicCountText(value: topic.hasPdfOrText ? 1 : 0),
          ),
          SizedBox(
            width: _topicCountColWidth,
            child: _TopicCountText(value: topic.hasVideo ? 1 : 0),
          ),
          SizedBox(
            width: _topicCountColWidth,
            child: _TopicCountText(value: topic.quizCount),
          ),
          SizedBox(
            width: _topicDurationColWidth,
            child: Center(
              child: Text(_formatAdminDuration(topic.durationSeconds)),
            ),
          ),
          SizedBox(
            width: _topicStatusColWidth,
            child: Center(
              child: StatusChip(
                label: topic.isPublished ? 'Nashr etilgan' : 'Qoralama',
                color: topic.isPublished
                    ? AppColors.successGreen
                    : AppColors.amber,
              ),
            ),
          ),
          SizedBox(
            width: _topicActionsColWidth,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.filledTonal(
                  tooltip: 'Tahrirlash',
                  onPressed: onEdit,
                  style: IconButton.styleFrom(
                    fixedSize: const Size.square(42),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: topic.isPublished ? 'Yashirish' : 'Ko‘rsatish',
                  onPressed: onToggle,
                  style: IconButton.styleFrom(
                    fixedSize: const Size.square(42),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: Icon(
                    topic.isPublished
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'O‘chirish',
                  onPressed: onDelete,
                  style: IconButton.styleFrom(
                    fixedSize: const Size.square(42),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  color: AppColors.errorRed,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopicCountText extends StatelessWidget {
  const _TopicCountText({required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        value.toString(),
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _TopicThumbnail extends StatelessWidget {
  const _TopicThumbnail({
    required this.orderIndex,
    required this.title,
    required this.imageUrl,
  });

  final int orderIndex;
  final String title;
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final color = _moduleColorForOrder(orderIndex == 0 ? 1 : orderIndex);
    final coverUrl = imageUrl.trim();
    return Container(
      width: 88,
      height: 64,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: .18)),
      ),
      child: coverUrl.isNotEmpty
          ? Image.network(
              coverUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  Icon(Icons.science_rounded, color: color, size: 34),
            )
          : Icon(Icons.science_rounded, color: color, size: 34),
    );
  }
}

class _RealLessonManagementPage extends StatefulWidget {
  const _RealLessonManagementPage({required this.kindFilter});

  final String kindFilter;

  @override
  State<_RealLessonManagementPage> createState() =>
      _RealLessonManagementPageState();
}

class _RealLessonManagementPageState extends State<_RealLessonManagementPage> {
  static const _repository = SupabaseAcademyRepository();
  late Future<List<AdminLessonSummary>> _lessonsFuture;
  late Future<List<AdminTopicSummary>> _topicsFuture;
  late final TextEditingController _lessonSearchController;

  bool get _isVideo => widget.kindFilter == 'video';

  @override
  void initState() {
    super.initState();
    _lessonSearchController = TextEditingController()
      ..addListener(() => setState(() {}));
    _reload();
  }

  @override
  void dispose() {
    _lessonSearchController.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _lessonsFuture = _repository.loadAdminLessons(
        kind: _isVideo ? 'video' : null,
      );
      _topicsFuture = _repository.loadAdminTopics();
    });
  }

  Future<void> _openLessonDialog({
    AdminLessonSummary? lesson,
    required List<AdminTopicSummary> topics,
  }) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => _LessonEditorDialog(
        lesson: lesson,
        topics: topics,
        videoOnly: _isVideo,
      ),
    );
    if (saved == true) _reload();
  }

  Future<void> _deleteLesson(AdminLessonSummary lesson) async {
    final confirm = await _confirmDanger(
      context,
      title: 'Lessonni o‘chirish',
      message: '${lesson.title} lessoni o‘chiriladi.',
    );
    if (confirm != true) return;
    await _repository.deleteLesson(lesson.id);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AdminTopicSummary>>(
      future: _topicsFuture,
      builder: (context, topicsSnapshot) {
        return FutureBuilder<List<AdminLessonSummary>>(
          future: _lessonsFuture,
          builder: (context, lessonsSnapshot) {
            final title = _isVideo ? 'Videolar' : 'PDF / Text materiallar';
            if (lessonsSnapshot.connectionState != ConnectionState.done ||
                topicsSnapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (lessonsSnapshot.hasError) {
              return _AdminErrorState(
                message: lessonsSnapshot.error.toString(),
                onRetry: _reload,
              );
            }
            final topics = topicsSnapshot.data ?? const <AdminTopicSummary>[];
            final lessons =
                (lessonsSnapshot.data ?? const <AdminLessonSummary>[])
                    .where(
                      (lesson) => _isVideo
                          ? lesson.kind == 'video'
                          : lesson.kind == 'pdf' || lesson.kind == 'text',
                    )
                    .toList();
            final query = _lessonSearchController.text.trim().toLowerCase();
            final visibleLessons = query.isEmpty
                ? lessons
                : lessons
                      .where(
                        (lesson) =>
                            lesson.title.toLowerCase().contains(query) ||
                            lesson.topicTitle.toLowerCase().contains(query) ||
                            lesson.moduleTitle.toLowerCase().contains(query) ||
                            lesson.fileUrl.toLowerCase().contains(query),
                      )
                      .toList();
            final pdfCount = lessons
                .where((lesson) => lesson.kind == 'pdf')
                .length;
            final textCount = lessons
                .where((lesson) => lesson.kind == 'text')
                .length;
            final videoCount = lessons
                .where((lesson) => lesson.kind == 'video')
                .length;
            final totalDuration = lessons.fold<int>(
              0,
              (sum, lesson) => sum + lesson.durationSeconds,
            );
            final withUrl = lessons
                .where((lesson) => lesson.fileUrl.trim().isNotEmpty)
                .length;
            final quickItems = lessons.take(5).toList();
            final quickFilterOptions = [
              const _AdminSelectOption<String>(
                value: 'modules',
                label: 'Barcha modullar',
                icon: Icons.grid_view_rounded,
                color: AppColors.primaryBlue,
              ),
              const _AdminSelectOption<String>(
                value: 'topics',
                label: 'Barcha mavzular',
                icon: Icons.folder_copy_rounded,
                color: AppColors.successGreen,
              ),
              _AdminSelectOption<String>(
                value: _isVideo ? 'status' : 'recent',
                label: _isVideo ? 'Status: Barchasi' : 'So‘nggi yuklangan',
                icon: _isVideo
                    ? Icons.verified_rounded
                    : Icons.schedule_rounded,
                color: _isVideo ? AppColors.violet : AppColors.amber,
              ),
            ];
            return _AdminReferenceScaffold(
              title: title,
              breadcrumbs: ['Bosh sahifa', title],
              stats: _isVideo
                  ? [
                      _AdminSummaryCardData(
                        title: 'Jami videolar',
                        value: videoCount.toString(),
                        subtitle: 'Barcha videolar',
                        icon: Icons.play_circle_rounded,
                        color: AppColors.primaryBlue,
                      ),
                      _AdminSummaryCardData(
                        title: 'Faol videolar',
                        value: withUrl.toString(),
                        subtitle: 'URL biriktirilgan',
                        icon: Icons.verified_rounded,
                        color: AppColors.successGreen,
                      ),
                      _AdminSummaryCardData(
                        title: 'Jami davomiylik',
                        value:
                            '${(totalDuration / 3600).floor()}h ${(totalDuration % 3600 / 60).round()}m',
                        subtitle: 'Barcha videolar',
                        icon: Icons.schedule_rounded,
                        color: AppColors.amber,
                      ),
                      _AdminSummaryCardData(
                        title: 'Talabalar',
                        value: topics.length.toString(),
                        subtitle: 'Video olgan mavzular',
                        icon: Icons.groups_rounded,
                        color: AppColors.violet,
                      ),
                    ]
                  : [
                      _AdminSummaryCardData(
                        title: 'Jami materiallar',
                        value: lessons.length.toString(),
                        subtitle: 'Barcha fayllar',
                        icon: Icons.description_rounded,
                        color: AppColors.primaryBlue,
                      ),
                      _AdminSummaryCardData(
                        title: 'PDF fayllar',
                        value: pdfCount.toString(),
                        subtitle: 'PDF format',
                        icon: Icons.picture_as_pdf_rounded,
                        color: AppColors.successGreen,
                      ),
                      _AdminSummaryCardData(
                        title: 'Text fayllar',
                        value: textCount.toString(),
                        subtitle: 'Text format',
                        icon: Icons.text_snippet_rounded,
                        color: AppColors.violet,
                      ),
                      _AdminSummaryCardData(
                        title: 'Yuklash havolalari',
                        value: withUrl.toString(),
                        subtitle: 'URL biriktirilgan',
                        icon: Icons.download_rounded,
                        color: AppColors.amber,
                      ),
                    ],
              main: _AdminSectionSurface(
                title: _isVideo ? 'Barcha videolar' : 'Fayllar ro‘yxati',
                action: _AdminPrimaryActionButton(
                  label: _isVideo
                      ? 'Yangi video qo‘shish'
                      : 'Yangi material qo‘shish',
                  onPressed: topics.isEmpty
                      ? () {}
                      : () => _openLessonDialog(topics: topics),
                ),
                child: lessons.isEmpty
                    ? _AdminEmptyMessage(
                        title: _isVideo
                            ? 'Video lessonlar yo‘q'
                            : 'PDF/Text lessonlar yo‘q',
                        message:
                            'Mavzuga biriktirilgan darslar shu yerdan yaratiladi va studentlarga ko‘rinadi.',
                      )
                    : Column(
                        children: [
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              SizedBox(
                                width: 260,
                                child: TextField(
                                  controller: _lessonSearchController,
                                  decoration: InputDecoration(
                                    hintText: _isVideo
                                        ? 'Videolarni qidirish...'
                                        : 'Fayllarni qidirish...',
                                    prefixIcon: const Icon(
                                      Icons.search_rounded,
                                    ),
                                  ),
                                ),
                              ),
                              for (final option in quickFilterOptions)
                                SizedBox(
                                  width: 170,
                                  child: _AdminSelectField<String>(
                                    value: option.value,
                                    label: option.label,
                                    options: [option],
                                    onChanged: (_) => _showAdminSnack(
                                      context,
                                      '${option.label} filtri tanlangan.',
                                    ),
                                  ),
                                ),
                              OutlinedButton.icon(
                                onPressed: _reload,
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('Yangilash'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          _AdminTable(
                            columns: [
                              _isVideo ? 'Video' : 'Fayl nomi',
                              'Modul / Mavzu',
                              _isVideo ? 'Davomiylik' : 'Turi',
                              _isVideo ? 'Hajmi / URL' : 'Hajmi / URL',
                              'Sana',
                              'Amallar',
                            ],
                            rows: visibleLessons
                                .map(
                                  (lesson) => [
                                    lesson.title,
                                    '${lesson.moduleTitle}\n${lesson.topicTitle}',
                                    _isVideo
                                        ? '${(lesson.durationSeconds / 60).floor()} min'
                                        : lesson.kind.toUpperCase(),
                                    lesson.fileUrl.isEmpty
                                        ? 'URL yo‘q'
                                        : 'Biriktirilgan',
                                    _formatDate(lesson.updatedAt),
                                    _ActionButtons(
                                      onEdit: () => _openLessonDialog(
                                        lesson: lesson,
                                        topics: topics,
                                      ),
                                      onDelete: () => _deleteLesson(lesson),
                                    ),
                                  ],
                                )
                                .toList(),
                          ),
                        ],
                      ),
              ),
              rail: Column(
                children: [
                  _AdminSectionSurface(
                    title: _isVideo ? 'Videolar statistikasi' : 'Saqlash joyi',
                    child: _isVideo
                        ? Row(
                            children: [
                              CircularScore(
                                value: lessons.isEmpty
                                    ? 0
                                    : withUrl / lessons.length,
                                label: 'Ko‘rishlar',
                                color: AppColors.primaryBlue,
                                size: 128,
                              ),
                              const SizedBox(width: 18),
                              Expanded(
                                child: Column(
                                  children: [
                                    _LegendRow(
                                      color: AppColors.primaryBlue,
                                      label: 'Videolar',
                                      value: '$videoCount',
                                    ),
                                    _LegendRow(
                                      color: AppColors.successGreen,
                                      label: 'URL bilan',
                                      value: '$withUrl',
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              _LegendRow(
                                color: AppColors.primaryBlue,
                                label: 'Jami materiallar',
                                value: lessons.length.toString(),
                              ),
                              _LegendRow(
                                color: AppColors.successGreen,
                                label: 'PDF',
                                value: pdfCount.toString(),
                              ),
                              _LegendRow(
                                color: AppColors.violet,
                                label: 'TEXT',
                                value: textCount.toString(),
                              ),
                              _LegendRow(
                                color: AppColors.amber,
                                label: 'Havola',
                                value: withUrl.toString(),
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 18),
                  _AdminSectionSurface(
                    title: _isVideo ? 'Top videolar' : 'Papkalar',
                    child: Column(
                      children: quickItems
                          .map(
                            (lesson) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                children: [
                                  IconBadge(
                                    icon: _isVideo
                                        ? Icons.play_circle_rounded
                                        : _mediaIconForKind(lesson.kind),
                                    color: _isVideo
                                        ? AppColors.primaryBlue
                                        : _mediaColorForKind(lesson.kind),
                                    size: 40,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          lesson.title,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleSmall,
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          lesson.topicTitle,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _AdminSectionSurface(
                    title: 'Tezkor amallar',
                    child: Column(
                      children: [
                        _AdminActionTile(
                          icon: _isVideo
                              ? Icons.video_call_rounded
                              : Icons.upload_file_rounded,
                          title: _isVideo
                              ? 'Yangi video qo‘shish'
                              : 'Yangi fayl yuklash',
                          subtitle: _isVideo
                              ? 'Video yuklash'
                              : 'PDF yoki Text qo‘shish',
                          onTap: topics.isEmpty
                              ? null
                              : () => _openLessonDialog(topics: topics),
                        ),
                        const SizedBox(height: 12),
                        _AdminActionTile(
                          icon: Icons.refresh_rounded,
                          title: 'Ma’lumotlarni yangilash',
                          subtitle: 'Joriy ko‘rinishni qayta yuklash',
                          onTap: _reload,
                          color: AppColors.violet,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _RealQuestionManagementPage extends StatefulWidget {
  const _RealQuestionManagementPage({required this.finalExamOnly});

  final bool finalExamOnly;

  @override
  State<_RealQuestionManagementPage> createState() =>
      _RealQuestionManagementPageState();
}

class _RealQuestionManagementPageState
    extends State<_RealQuestionManagementPage> {
  static const _repository = SupabaseAcademyRepository();
  late Future<List<AdminQuestionSummary>> _questionsFuture;
  late Future<List<AdminModuleSummary>> _modulesFuture;
  late Future<List<AdminTopicSummary>> _topicsFuture;
  late final TextEditingController _questionSearchController;

  @override
  void initState() {
    super.initState();
    _questionSearchController = TextEditingController()
      ..addListener(() => setState(() {}));
    _reload();
  }

  @override
  void dispose() {
    _questionSearchController.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _questionsFuture = _repository.loadAdminQuestions(
        finalExamOnly: widget.finalExamOnly,
      );
      _modulesFuture = _repository.loadAdminModules();
      _topicsFuture = _repository.loadAdminTopics();
    });
  }

  Future<void> _openQuestionDialog({
    AdminQuestionSummary? question,
    required List<AdminModuleSummary> modules,
    required List<AdminTopicSummary> topics,
  }) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => _QuestionEditorDialog(
        question: question,
        modules: modules,
        topics: topics,
        finalExamOnly: widget.finalExamOnly,
      ),
    );
    if (saved == true) _reload();
  }

  Future<void> _deleteQuestion(AdminQuestionSummary question) async {
    final confirm = await _confirmDanger(
      context,
      title: 'Savolni o‘chirish',
      message: 'Tanlangan savol bazadan o‘chiriladi.',
    );
    if (confirm != true) return;
    await _repository.deleteQuestion(question.id);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AdminModuleSummary>>(
      future: _modulesFuture,
      builder: (context, modulesSnapshot) {
        return FutureBuilder<List<AdminTopicSummary>>(
          future: _topicsFuture,
          builder: (context, topicsSnapshot) {
            return FutureBuilder<List<AdminQuestionSummary>>(
              future: _questionsFuture,
              builder: (context, questionsSnapshot) {
                if (questionsSnapshot.connectionState != ConnectionState.done ||
                    modulesSnapshot.connectionState != ConnectionState.done ||
                    topicsSnapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (questionsSnapshot.hasError) {
                  return _AdminErrorState(
                    message: questionsSnapshot.error.toString(),
                    onRetry: _reload,
                  );
                }
                final questions =
                    questionsSnapshot.data ?? const <AdminQuestionSummary>[];
                final query = _questionSearchController.text
                    .trim()
                    .toLowerCase();
                final visibleQuestions = query.isEmpty
                    ? questions
                    : questions
                          .where(
                            (question) =>
                                question.question.toLowerCase().contains(
                                  query,
                                ) ||
                                question.scopeTitle.toLowerCase().contains(
                                  query,
                                ) ||
                                question.difficulty.toLowerCase().contains(
                                  query,
                                ),
                          )
                          .toList();
                final modules =
                    modulesSnapshot.data ?? const <AdminModuleSummary>[];
                final topics =
                    topicsSnapshot.data ?? const <AdminTopicSummary>[];
                final easyCount = questions
                    .where((item) => item.difficulty.toLowerCase() == 'easy')
                    .length;
                final mediumCount = questions
                    .where((item) => item.difficulty.toLowerCase() == 'medium')
                    .length;
                final hardCount = questions
                    .where((item) => item.difficulty.toLowerCase() == 'hard')
                    .length;
                final avgPoints = questions.isEmpty
                    ? 0
                    : questions.fold<int>(0, (sum, item) => sum + item.points) /
                          questions.length;
                final title = widget.finalExamOnly
                    ? 'Yakuniy imtihonlar'
                    : 'Testlar (Quizlar)';
                final quickFilterOptions = [
                  const _AdminSelectOption<String>(
                    value: 'modules',
                    label: 'Barcha modullar',
                    icon: Icons.grid_view_rounded,
                    color: AppColors.primaryBlue,
                  ),
                  _AdminSelectOption<String>(
                    value: widget.finalExamOnly ? 'status' : 'topics',
                    label: widget.finalExamOnly
                        ? 'Barcha statuslar'
                        : 'Barcha mavzular',
                    icon: widget.finalExamOnly
                        ? Icons.verified_rounded
                        : Icons.folder_copy_rounded,
                    color: widget.finalExamOnly
                        ? AppColors.successGreen
                        : AppColors.violet,
                  ),
                ];
                return _AdminReferenceScaffold(
                  title: title,
                  breadcrumbs: ['Bosh sahifa', title],
                  stats: [
                    _AdminSummaryCardData(
                      title: widget.finalExamOnly
                          ? 'Jami yakuniy imtihonlar'
                          : 'Jami testlar',
                      value: questions.length.toString(),
                      subtitle: 'Barcha savollar',
                      icon: widget.finalExamOnly
                          ? Icons.emoji_events_rounded
                          : Icons.quiz_rounded,
                      color: AppColors.primaryBlue,
                    ),
                    _AdminSummaryCardData(
                      title: 'Easy',
                      value: easyCount.toString(),
                      subtitle: 'Oson savollar',
                      icon: Icons.sentiment_satisfied_alt_rounded,
                      color: AppColors.successGreen,
                    ),
                    _AdminSummaryCardData(
                      title: 'Medium',
                      value: mediumCount.toString(),
                      subtitle: 'O‘rta qiyinlik',
                      icon: Icons.tune_rounded,
                      color: AppColors.amber,
                    ),
                    _AdminSummaryCardData(
                      title: 'Hard',
                      value: hardCount.toString(),
                      subtitle: 'Murakkab savollar',
                      icon: Icons.local_fire_department_rounded,
                      color: AppColors.errorRed,
                    ),
                    _AdminSummaryCardData(
                      title: 'O‘rtacha ball',
                      value: avgPoints.toStringAsFixed(1),
                      subtitle: 'Savol uchun',
                      icon: Icons.auto_graph_rounded,
                      color: AppColors.violet,
                    ),
                  ],
                  main: _AdminSectionSurface(
                    title: widget.finalExamOnly
                        ? 'Imtihonlar ro‘yxati'
                        : 'Testlar ro‘yxati',
                    action: _AdminPrimaryActionButton(
                      label: widget.finalExamOnly
                          ? 'Yangi yakuniy imtihon'
                          : 'Yangi test qo‘shish',
                      onPressed: modules.isEmpty && topics.isEmpty
                          ? () {}
                          : () => _openQuestionDialog(
                              modules: modules,
                              topics: topics,
                            ),
                    ),
                    child: questions.isEmpty
                        ? _AdminEmptyMessage(
                            title: widget.finalExamOnly
                                ? 'Yakuniy savollar yo‘q'
                                : 'Quiz savollar yo‘q',
                            message:
                                'Student test oqimi ishlashi uchun savollar shu yerdan yaratiladi.',
                          )
                        : Column(
                            children: [
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  SizedBox(
                                    width: 240,
                                    child: TextField(
                                      controller: _questionSearchController,
                                      decoration: InputDecoration(
                                        hintText: widget.finalExamOnly
                                            ? 'Imtihon nomini qidirish...'
                                            : 'Testlarni qidirish...',
                                        prefixIcon: const Icon(
                                          Icons.search_rounded,
                                        ),
                                      ),
                                    ),
                                  ),
                                  for (final option in quickFilterOptions)
                                    SizedBox(
                                      width: 180,
                                      child: _AdminSelectField<String>(
                                        value: option.value,
                                        label: option.label,
                                        options: [option],
                                        onChanged: (_) => _showAdminSnack(
                                          context,
                                          '${option.label} filtri tanlangan.',
                                        ),
                                      ),
                                    ),
                                  OutlinedButton.icon(
                                    onPressed: _reload,
                                    icon: const Icon(Icons.refresh_rounded),
                                    label: const Text('Yangilash'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              _AdminTable(
                                columns: [
                                  widget.finalExamOnly
                                      ? 'Imtihon'
                                      : 'Test nomi',
                                  'Ko‘lami',
                                  'Javob',
                                  'Qiyinlik',
                                  'Ball',
                                  'Amallar',
                                ],
                                rows: visibleQuestions
                                    .map(
                                      (question) => [
                                        question.question,
                                        question.scopeTitle,
                                        question.correctOption.toUpperCase(),
                                        question.difficulty,
                                        question.points.toString(),
                                        _ActionButtons(
                                          onEdit: () => _openQuestionDialog(
                                            question: question,
                                            modules: modules,
                                            topics: topics,
                                          ),
                                          onDelete: () =>
                                              _deleteQuestion(question),
                                        ),
                                      ],
                                    )
                                    .toList(),
                              ),
                            ],
                          ),
                  ),
                  rail: Column(
                    children: [
                      _AdminSectionSurface(
                        title: widget.finalExamOnly
                            ? 'Imtihonlar statistikasi'
                            : 'Testlar statistikasi',
                        child: Row(
                          children: [
                            CircularScore(
                              value: questions.isEmpty
                                  ? 0
                                  : mediumCount / questions.length,
                              label: 'Jami',
                              color: AppColors.successGreen,
                              size: 128,
                            ),
                            const SizedBox(width: 18),
                            Expanded(
                              child: Column(
                                children: [
                                  _LegendRow(
                                    color: AppColors.successGreen,
                                    label: 'Easy',
                                    value: '$easyCount',
                                  ),
                                  _LegendRow(
                                    color: AppColors.amber,
                                    label: 'Medium',
                                    value: '$mediumCount',
                                  ),
                                  _LegendRow(
                                    color: AppColors.errorRed,
                                    label: 'Hard',
                                    value: '$hardCount',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      _AdminSectionSurface(
                        title: widget.finalExamOnly
                            ? 'So‘nggi imtihonlar'
                            : 'Top testlar',
                        child: Column(
                          children: questions
                              .take(5)
                              .map(
                                (question) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Row(
                                    children: [
                                      IconBadge(
                                        icon: widget.finalExamOnly
                                            ? Icons.emoji_events_rounded
                                            : Icons.quiz_rounded,
                                        color: widget.finalExamOnly
                                            ? AppColors.amber
                                            : AppColors.primaryBlue,
                                        size: 40,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              question.scopeTitle,
                                              style: Theme.of(
                                                context,
                                              ).textTheme.titleSmall,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              question.question,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: Theme.of(
                                                context,
                                              ).textTheme.bodySmall,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _RealStudentManagementPage extends StatefulWidget {
  const _RealStudentManagementPage();

  @override
  State<_RealStudentManagementPage> createState() =>
      _RealStudentManagementPageState();
}

class _RealStudentManagementPageState
    extends State<_RealStudentManagementPage> {
  static const _repository = SupabaseAcademyRepository();
  final _searchController = TextEditingController();
  late Future<List<AdminStudentSummary>> _future;
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _future = _repository.loadAdminStudents();
  }

  void _reload() {
    setState(() => _future = _repository.loadAdminStudents());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AdminStudentSummary>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _AdminErrorState(
            message: snapshot.error.toString(),
            onRetry: _reload,
          );
        }
        final students = snapshot.data ?? const <AdminStudentSummary>[];
        final active = students
            .where((student) => student.status.toLowerCase() == 'yaxshi')
            .length;
        final medium = students
            .where((student) => student.status.toLowerCase() == 'o‘rtacha')
            .length;
        final low = students
            .where((student) => student.status.toLowerCase() == 'qoniqarsiz')
            .length;
        final avgScore = students.isEmpty
            ? 0
            : students.fold<int>(0, (sum, item) => sum + item.score) /
                  students.length;
        final avgProgress = students.isEmpty
            ? 0
            : students.fold<double>(0, (sum, item) => sum + item.progress) /
                  students.length;
        final topStudents = [...students]
          ..sort((a, b) => b.score.compareTo(a.score));
        final filteredStudents = students.where((student) {
          final query = _searchController.text.trim().toLowerCase();
          final matchesSearch =
              query.isEmpty ||
              student.fullName.toLowerCase().contains(query) ||
              student.phone.toLowerCase().contains(query) ||
              student.moduleTitle.toLowerCase().contains(query);
          final status = student.status.toLowerCase();
          final matchesStatus = switch (_statusFilter) {
            'active' => status == 'yaxshi',
            'medium' => status == 'o‘rtacha',
            'low' => status == 'qoniqarsiz',
            _ => true,
          };
          return matchesSearch && matchesStatus;
        }).toList();
        return _AdminReferenceScaffold(
          title: 'Talabalar',
          breadcrumbs: const ['Bosh sahifa', 'Talabalar'],
          stats: [
            _AdminSummaryCardData(
              title: 'Jami talabalar',
              value: students.length.toString(),
              subtitle: 'Barcha talabalar',
              icon: Icons.groups_rounded,
              color: AppColors.primaryBlue,
            ),
            _AdminSummaryCardData(
              title: 'Faol talabalar',
              value: active.toString(),
              subtitle: 'Yaxshi natijalar',
              icon: Icons.person_pin_circle_rounded,
              color: AppColors.successGreen,
            ),
            _AdminSummaryCardData(
              title: 'O‘rtacha ball',
              value: '${avgScore.round()}%',
              subtitle: 'Umumiy o‘rtacha',
              icon: Icons.workspace_premium_rounded,
              color: AppColors.amber,
            ),
            _AdminSummaryCardData(
              title: 'Progress',
              value: '${(avgProgress * 100).round()}%',
              subtitle: 'Umumiy progress',
              icon: Icons.stacked_line_chart_rounded,
              color: AppColors.violet,
            ),
          ],
          main: _AdminSectionSurface(
            title: '',
            child: students.isEmpty
                ? const _AdminEmptyMessage(
                    title: 'Studentlar topilmadi',
                    message:
                        'Ro‘yxatdan o‘tgan studentlar paydo bo‘lgach shu yerda ko‘rinadi.',
                  )
                : Column(
                    children: [
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          SizedBox(
                            width: 260,
                            child: TextField(
                              controller: _searchController,
                              onChanged: (_) => setState(() {}),
                              decoration: const InputDecoration(
                                hintText: 'Talabani qidirish...',
                                prefixIcon: Icon(Icons.search_rounded),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 190,
                            child: _AdminSelectField<String>(
                              value: 'all',
                              label: 'Barcha modullar',
                              options: const [
                                _AdminSelectOption<String>(
                                  value: 'all',
                                  label: 'Barcha modullar',
                                  icon: Icons.grid_view_rounded,
                                  color: AppColors.primaryBlue,
                                ),
                              ],
                              onChanged: (_) {},
                            ),
                          ),
                          SizedBox(
                            width: 190,
                            child: _AdminSelectField<String>(
                              value: _statusFilter,
                              label: 'Barcha statuslar',
                              options: const [
                                _AdminSelectOption<String>(
                                  value: 'all',
                                  label: 'Barcha statuslar',
                                  icon: Icons.verified_user_rounded,
                                  color: AppColors.primaryBlue,
                                ),
                                _AdminSelectOption<String>(
                                  value: 'active',
                                  label: 'Faol',
                                  icon: Icons.check_circle_rounded,
                                  color: AppColors.successGreen,
                                ),
                                _AdminSelectOption<String>(
                                  value: 'medium',
                                  label: 'O‘rtacha',
                                  icon: Icons.schedule_rounded,
                                  color: AppColors.amber,
                                ),
                                _AdminSelectOption<String>(
                                  value: 'low',
                                  label: 'Qoniqarsiz',
                                  icon: Icons.warning_rounded,
                                  color: AppColors.errorRed,
                                ),
                              ],
                              onChanged: (value) =>
                                  setState(() => _statusFilter = value),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: _reload,
                            icon: const Icon(Icons.filter_alt_outlined),
                            label: const Text('Filtr'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _AdminTable(
                        columns: const [
                          'Talaba',
                          'Telefon',
                          'Modullar',
                          'Progress',
                          'O‘rtacha ball',
                          'Holat',
                          'Qo‘shilgan sana',
                          'Amallar',
                        ],
                        rowMinHeight: 64,
                        rowMaxHeight: 78,
                        minWidth: 980,
                        rows: filteredStudents
                            .map(
                              (student) => [
                                _AdminStudentIdentityCell(student: student),
                                student.phone.isEmpty ? '-' : student.phone,
                                student.moduleTitle,
                                '${(student.progress * 100).round()}%',
                                '${student.score}%',
                                student.status,
                                _formatDate(student.createdAt),
                                'view edit',
                              ],
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Jami ${filteredStudents.length} ta talaba',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                          const _Pagination(),
                        ],
                      ),
                    ],
                  ),
          ),
          rail: Column(
            children: [
              _AdminSectionSurface(
                title: 'Talabalar statistikasi',
                child: Row(
                  children: [
                    CircularScore(
                      value: avgProgress.toDouble(),
                      label: 'Jami',
                      color: AppColors.successGreen,
                      size: 128,
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        children: [
                          _LegendRow(
                            color: AppColors.successGreen,
                            label: 'Faol',
                            value: '$active',
                          ),
                          _LegendRow(
                            color: AppColors.amber,
                            label: 'O‘rtacha',
                            value: '$medium',
                          ),
                          _LegendRow(
                            color: AppColors.errorRed,
                            label: 'Qoniqarsiz',
                            value: '$low',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _AdminSectionSurface(
                title: 'Holat bo‘yicha',
                child: Column(
                  children: [
                    _BarMetric(
                      label: 'Faol',
                      value: students.isEmpty ? 0 : active / students.length,
                      color: AppColors.successGreen,
                    ),
                    _BarMetric(
                      label: 'O‘rtacha',
                      value: students.isEmpty ? 0 : medium / students.length,
                      color: AppColors.amber,
                    ),
                    _BarMetric(
                      label: 'Qoniqarsiz',
                      value: students.isEmpty ? 0 : low / students.length,
                      color: AppColors.errorRed,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _AdminSectionSurface(
                title: 'Top talabalar',
                child: Column(
                  children: topStudents.take(5).map((student) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: AppColors.primaryBlue.withValues(
                              alpha: .12,
                            ),
                            child: Text(student.fullName.characters.first),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              student.fullName,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                          Text(
                            '${student.score}%',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 18),
              _AdminSectionSurface(
                title: 'So‘nggi qo‘shilgan talabalar',
                child: Column(
                  children: students.take(5).map((student) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          _AdminAvatarInitials(name: student.fullName),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              student.fullName,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                          Text(
                            _formatDate(student.createdAt),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AdminStudentIdentityCell extends StatelessWidget {
  const _AdminStudentIdentityCell({required this.student});

  final AdminStudentSummary student;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _AdminAvatarInitials(name: student.fullName),
        const SizedBox(width: 10),
        SizedBox(
          width: 190,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                student.fullName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Text(
                student.phone.isEmpty ? 'Telefon yo‘q' : student.phone,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AdminAvatarInitials extends StatelessWidget {
  const _AdminAvatarInitials({required this.name, this.color});

  final String name;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final normalized = name.trim();
    final letter = normalized.isEmpty ? '?' : normalized.characters.first;
    final baseColor = color ?? AppColors.primaryBlue;
    return CircleAvatar(
      radius: 18,
      backgroundColor: baseColor.withValues(alpha: .12),
      child: Text(
        letter.toUpperCase(),
        style: TextStyle(color: baseColor, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _AdminSoftMetricTile extends StatelessWidget {
  const _AdminSoftMetricTile({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: .14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _RealAnalyticsPage extends StatefulWidget {
  const _RealAnalyticsPage();

  @override
  State<_RealAnalyticsPage> createState() => _RealAnalyticsPageState();
}

class _RealAnalyticsPageState extends State<_RealAnalyticsPage> {
  static const _repository = SupabaseAcademyRepository();
  late Future<AdminDashboardData> _dashboardFuture;
  late Future<List<AdminStudentSummary>> _studentsFuture;

  @override
  void initState() {
    super.initState();
    _dashboardFuture = _repository.loadAdminDashboard();
    _studentsFuture = _repository.loadAdminStudents();
  }

  void _reload() {
    setState(() {
      _dashboardFuture = _repository.loadAdminDashboard();
      _studentsFuture = _repository.loadAdminStudents();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AdminDashboardData>(
      future: _dashboardFuture,
      builder: (context, dashboardSnapshot) {
        return FutureBuilder<List<AdminStudentSummary>>(
          future: _studentsFuture,
          builder: (context, studentsSnapshot) {
            if (dashboardSnapshot.connectionState != ConnectionState.done ||
                studentsSnapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (dashboardSnapshot.hasError) {
              return _AdminErrorState(
                message: dashboardSnapshot.error.toString(),
                onRetry: _reload,
              );
            }
            final dashboard = dashboardSnapshot.data!;
            final students =
                studentsSnapshot.data ?? const <AdminStudentSummary>[];
            final totalLearning =
                dashboard.completedCount +
                dashboard.inProgressCount +
                dashboard.notStartedCount;
            final passedValue = totalLearning == 0
                ? 0.0
                : dashboard.completedCount / totalLearning;
            final inProgressValue = totalLearning == 0
                ? 0.0
                : dashboard.inProgressCount / totalLearning;
            final notStartedValue = totalLearning == 0
                ? 0.0
                : dashboard.notStartedCount / totalLearning;
            final sortedStudents = [...students]
              ..sort((a, b) => b.score.compareTo(a.score));
            final avgScore = students.isEmpty
                ? 0
                : students.fold<int>(0, (sum, item) => sum + item.score) /
                      students.length;
            return _AdminReferenceScaffold(
              title: 'Tahlillar',
              breadcrumbs: const ['Bosh sahifa', 'Tahlillar'],
              stats: [
                ...dashboard.metrics.map(
                  (metric) => _AdminSummaryCardData(
                    title: metric.title,
                    value: metric.value,
                    subtitle: metric.delta,
                    icon: metric.icon,
                    color: metric.color,
                  ),
                ),
                _AdminSummaryCardData(
                  title: 'O‘rtacha natija',
                  value: '${(dashboard.completionPercent * 100).round()}%',
                  subtitle: 'Umumiy ko‘rsatkich',
                  icon: Icons.track_changes_rounded,
                  color: AppColors.primaryBlue,
                ),
              ],
              main: Column(
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final performance = _AdminSectionSurface(
                        title: 'O‘qish faolligi',
                        action: _AdminPrimaryActionButton(
                          label: 'Yangilash',
                          icon: Icons.refresh_rounded,
                          onPressed: _reload,
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: const [
                                _LegendRow(
                                  color: AppColors.primaryBlue,
                                  label: 'Faol foydalanuvchilar',
                                ),
                                SizedBox(width: 18),
                                _LegendRow(
                                  color: AppColors.successGreen,
                                  label: 'Yangi foydalanuvchilar',
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            EmptyChart(
                              values: dashboard.growthChart,
                              height: 230,
                              color: AppColors.primaryBlue,
                            ),
                          ],
                        ),
                      );
                      final overview = Row(
                        children: [
                          Expanded(
                            child: _AdminSectionSurface(
                              title: 'Umumiy statistika',
                              child: Row(
                                children: [
                                  CircularScore(
                                    value: dashboard.completionPercent,
                                    label: 'Jami talabalar',
                                    color: AppColors.primaryBlue,
                                    size: 118,
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      children: [
                                        _LegendRow(
                                          color: AppColors.primaryBlue,
                                          label: 'Jami modullar',
                                          value: dashboard.topModules.length
                                              .toString(),
                                        ),
                                        _LegendRow(
                                          color: AppColors.successGreen,
                                          label: 'Yakunlangan',
                                          value: dashboard.completedCount
                                              .toString(),
                                        ),
                                        _LegendRow(
                                          color: AppColors.amber,
                                          label: 'Jarayonda',
                                          value: dashboard.inProgressCount
                                              .toString(),
                                        ),
                                        _LegendRow(
                                          color: AppColors.errorRed,
                                          label: 'Boshlanmagan',
                                          value: dashboard.notStartedCount
                                              .toString(),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _AdminSectionSurface(
                              title: 'Faoliyat turlari bo‘yicha',
                              child: Row(
                                children: [
                                  CircularScore(
                                    value: students.isEmpty
                                        ? 0
                                        : students
                                                  .where(
                                                    (student) =>
                                                        student.progress > 0,
                                                  )
                                                  .length /
                                              students.length,
                                    label: 'Faollik',
                                    color: AppColors.violet,
                                    size: 118,
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      children: [
                                        _LegendRow(
                                          color: AppColors.primaryBlue,
                                          label: 'Video ko‘rish',
                                          value:
                                              '${(dashboard.completionPercent * 100).round()}%',
                                        ),
                                        _LegendRow(
                                          color: AppColors.successGreen,
                                          label: 'Test yechish',
                                          value: '${avgScore.round()}%',
                                        ),
                                        _LegendRow(
                                          color: AppColors.amber,
                                          label: 'PDF o‘qish',
                                          value: '${students.length}',
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                      if (constraints.maxWidth > 1120) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 6, child: performance),
                            const SizedBox(width: 18),
                            Expanded(flex: 6, child: overview),
                          ],
                        );
                      }
                      return Column(
                        children: [
                          performance,
                          const SizedBox(height: 18),
                          overview,
                        ],
                      );
                    },
                  ),
                  SizedBox(
                    height: _adminSectionSpacing(
                      MediaQuery.sizeOf(context).width,
                    ),
                  ),
                  _AdminSectionSurface(
                    title: 'Testlar bo‘yicha natija taqsimoti',
                    child: Column(
                      children: [
                        _BarMetric(
                          label: 'O‘tgan',
                          value: passedValue,
                          color: AppColors.primaryBlue,
                        ),
                        _BarMetric(
                          label: 'Jarayonda',
                          value: inProgressValue,
                          color: AppColors.successGreen,
                        ),
                        _BarMetric(
                          label: 'Boshlanmagan',
                          value: notStartedValue,
                          color: AppColors.errorRed,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _AdminSoftMetricTile(
                                label: 'O‘rtacha ball',
                                value: '${avgScore.toStringAsFixed(1)}%',
                                color: AppColors.successGreen,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _AdminSoftMetricTile(
                                label: 'Top natija',
                                value: sortedStudents.isEmpty
                                    ? '0%'
                                    : '${sortedStudents.first.score}%',
                                color: AppColors.primaryBlue,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _AdminSoftMetricTile(
                                label: 'Top past natija',
                                value: sortedStudents.isEmpty
                                    ? '0%'
                                    : '${sortedStudents.last.score}%',
                                color: AppColors.errorRed,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: _adminSectionSpacing(
                      MediaQuery.sizeOf(context).width,
                    ),
                  ),
                  _AdminSectionSurface(
                    title: 'Top 5 talabalar',
                    child: _AdminTable(
                      columns: const [
                        '#',
                        'Talaba',
                        'Modullar',
                        'O‘rtacha ball',
                        'Faollik',
                      ],
                      minWidth: 720,
                      rows: sortedStudents.take(5).toList().asMap().entries.map(
                        (entry) {
                          final student = entry.value;
                          return [
                            '${entry.key + 1}',
                            _AdminStudentIdentityCell(student: student),
                            student.moduleTitle,
                            '${student.score}%',
                            '${(student.progress * 100).round()}%',
                          ];
                        },
                      ).toList(),
                    ),
                  ),
                  SizedBox(
                    height: _adminSectionSpacing(
                      MediaQuery.sizeOf(context).width,
                    ),
                  ),
                  _AdminSectionSurface(
                    title: 'Modullar bo‘yicha o‘zlashtirish darajasi',
                    child: Column(
                      children: dashboard.topModules.isEmpty
                          ? [
                              const _AdminEmptyMessage(
                                title: 'Modullar hali yo‘q',
                                message:
                                    'Modullar qo‘shilganda o‘zlashtirish grafiklari shu yerda ko‘rinadi.',
                              ),
                            ]
                          : dashboard.topModules.map((module) {
                              return _BarMetric(
                                label: module.title,
                                value: module.completionRate,
                                color: AppColors.primaryBlue,
                              );
                            }).toList(),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _RealCertificatePage extends StatefulWidget {
  const _RealCertificatePage();

  @override
  State<_RealCertificatePage> createState() => _RealCertificatePageState();
}

class _RealCertificatePageState extends State<_RealCertificatePage> {
  static const _repository = SupabaseAcademyRepository();
  late Future<List<AdminCertificateSummary>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repository.loadAdminCertificates();
  }

  void _reload() {
    setState(() => _future = _repository.loadAdminCertificates());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AdminCertificateSummary>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _AdminErrorState(
            message: snapshot.error.toString(),
            onRetry: _reload,
          );
        }
        final items = snapshot.data ?? const <AdminCertificateSummary>[];
        final withUrl = items
            .where((item) => item.certificateUrl.trim().isNotEmpty)
            .length;
        final waiting = items.length - withUrl;
        final previewCertificate = items.isEmpty ? null : items.first;
        return _AdminReferenceScaffold(
          title: 'Sertifikatlar',
          breadcrumbs: const ['Bosh sahifa', 'Sertifikatlar'],
          stats: [
            _AdminSummaryCardData(
              title: 'Jami sertifikatlar',
              value: items.length.toString(),
              subtitle: 'Barcha sertifikatlar',
              icon: Icons.workspace_premium_rounded,
              color: AppColors.primaryBlue,
            ),
            _AdminSummaryCardData(
              title: 'Berilgan',
              value: withUrl.toString(),
              subtitle: 'URL tayyor',
              icon: Icons.verified_rounded,
              color: AppColors.successGreen,
            ),
            _AdminSummaryCardData(
              title: 'Kutilmoqda',
              value: waiting.toString(),
              subtitle: 'Hali URL yo‘q',
              icon: Icons.schedule_rounded,
              color: AppColors.amber,
            ),
          ],
          main: _AdminSectionSurface(
            title: 'Barcha sertifikatlar',
            action: _AdminPrimaryActionButton(
              label: 'Yangi yaratish',
              icon: Icons.add_rounded,
              onPressed: _reload,
            ),
            child: items.isEmpty
                ? const _AdminEmptyMessage(
                    title: 'Sertifikatlar hali yo‘q',
                    message:
                        'Module finalidan o‘tgan studentlarga sertifikat yaratilganda shu yerda ko‘rinadi.',
                  )
                : _AdminTable(
                    columns: const [
                      'Talaba',
                      'Modul',
                      'Sana',
                      'Holat',
                      'Amallar',
                    ],
                    rowMinHeight: 64,
                    rowMaxHeight: 76,
                    minWidth: 820,
                    rows: items
                        .map(
                          (item) => [
                            _AdminCertificateStudentCell(item: item),
                            item.moduleTitle,
                            _formatDate(item.issuedAt),
                            item.certificateUrl.trim().isEmpty
                                ? 'pending'
                                : 'ready',
                            _AdminCertificateActions(item: item),
                          ],
                        )
                        .toList(),
                  ),
          ),
          rail: Column(
            children: [
              _AdminCertificateWizardPanel(item: previewCertificate),
              const SizedBox(height: 18),
              _AdminSectionSurface(
                title: 'QR verify holati',
                child: Column(
                  children: [
                    CircularScore(
                      value: items.isEmpty ? 0 : withUrl / items.length,
                      label: 'Haqiqiy',
                      color: AppColors.successGreen,
                      size: 118,
                    ),
                    const SizedBox(height: 12),
                    _LegendRow(
                      color: AppColors.successGreen,
                      label: 'Berilgan',
                      value: '$withUrl',
                    ),
                    _LegendRow(
                      color: AppColors.amber,
                      label: 'Kutilmoqda',
                      value: '$waiting',
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AdminCertificateStudentCell extends StatelessWidget {
  const _AdminCertificateStudentCell({required this.item});

  final AdminCertificateSummary item;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _AdminAvatarInitials(name: item.studentName, color: AppColors.violet),
        const SizedBox(width: 10),
        SizedBox(
          width: 180,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.studentName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Text(
                item.certificateCode.isEmpty ? item.id : item.certificateCode,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AdminCertificateActions extends StatelessWidget {
  const _AdminCertificateActions({required this.item});

  final AdminCertificateSummary item;

  @override
  Widget build(BuildContext context) {
    final url = item.verifyUrl.trim().isNotEmpty
        ? item.verifyUrl
        : item.certificateUrl;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Ko‘rish',
          onPressed: url.trim().isEmpty
              ? null
              : () async {
                  final uri = Uri.tryParse(url);
                  if (uri != null) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
          icon: const Icon(Icons.visibility_outlined, size: 18),
        ),
        IconButton(
          tooltip: 'Nusxalash',
          onPressed: url.trim().isEmpty
              ? null
              : () async {
                  await Clipboard.setData(ClipboardData(text: url));
                  if (!context.mounted) return;
                  _showAdminSnack(context, 'Sertifikat havolasi nusxalandi.');
                },
          icon: const Icon(Icons.copy_rounded, size: 18),
        ),
        const Icon(Icons.more_vert_rounded, size: 18, color: AppColors.muted),
      ],
    );
  }
}

class _AdminCertificateWizardPanel extends StatelessWidget {
  const _AdminCertificateWizardPanel({required this.item});

  final AdminCertificateSummary? item;

  @override
  Widget build(BuildContext context) {
    return _AdminSectionSurface(
      title: 'Yangi sertifikat yaratish',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              _AdminWizardStep(number: '1', label: 'Talaba', active: true),
              Expanded(child: Divider()),
              _AdminWizardStep(number: '2', label: 'Fayl yuklash'),
              Expanded(child: Divider()),
              _AdminWizardStep(number: '3', label: 'QR yakunlash'),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Talabani tanlang',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          AppCard(
            padding: const EdgeInsets.all(12),
            borderColor: AppColors.border,
            child: Row(
              children: [
                _AdminAvatarInitials(name: item?.studentName ?? 'A'),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item?.studentName ?? 'Talaba tanlanmagan',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down_rounded),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Sertifikat fayli',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          Container(
            height: 118,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(alpha: .05),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AppColors.primaryBlue.withValues(alpha: .22),
                style: BorderStyle.solid,
              ),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cloud_upload_outlined, color: AppColors.primaryBlue),
                SizedBox(height: 8),
                Text('PDF/PNG/JPG sertifikat yuklash'),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _AdminCertificatePreviewCard(item: item),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _showAdminSnack(
                context,
                'Sertifikat yaratish uchun fayl va talaba tanlanadi.',
              ),
              icon: const Icon(Icons.check_rounded),
              label: const Text('Sertifikatni yaratish'),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminWizardStep extends StatelessWidget {
  const _AdminWizardStep({
    required this.number,
    required this.label,
    this.active = false,
  });

  final String number;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: active ? AppColors.primaryBlue : AppColors.border,
          child: Text(
            number,
            style: TextStyle(
              color: active ? Colors.white : AppColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: active ? AppColors.primaryBlue : AppColors.muted,
          ),
        ),
      ],
    );
  }
}

class _AdminCertificatePreviewCard extends StatelessWidget {
  const _AdminCertificatePreviewCard({required this.item});

  final AdminCertificateSummary? item;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: const Color(0xFFFFFCF7),
      padding: const EdgeInsets.all(14),
      borderColor: const Color(0xFFF4D38A),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'SERTIFIKAT',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: .8,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  item?.studentName ?? 'Talaba ismi',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  item?.moduleTitle ?? 'Modul nomi',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.navy),
            ),
            child: const Icon(Icons.qr_code_2_rounded, color: AppColors.navy),
          ),
        ],
      ),
    );
  }
}

class _RealMediaLibraryPage extends StatefulWidget {
  const _RealMediaLibraryPage();

  @override
  State<_RealMediaLibraryPage> createState() => _RealMediaLibraryPageState();
}

class _RealMediaLibraryPageState extends State<_RealMediaLibraryPage> {
  static const _repository = SupabaseAcademyRepository();
  final _mediaSearchController = TextEditingController();
  late Future<List<AdminMediaSummary>> _future;
  int _selectedMediaIndex = 0;
  String _mediaFilter = 'all';

  @override
  void initState() {
    super.initState();
    _future = _repository.loadAdminMediaItems();
  }

  void _reload() {
    setState(() => _future = _repository.loadAdminMediaItems());
  }

  @override
  void dispose() {
    _mediaSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AdminMediaSummary>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _AdminErrorState(
            message: snapshot.error.toString(),
            onRetry: _reload,
          );
        }
        final items = snapshot.data ?? const <AdminMediaSummary>[];
        final pdfCount = items.where((item) => item.kind == 'pdf').length;
        final textCount = items.where((item) => item.kind == 'text').length;
        final videoCount = items.where((item) => item.kind == 'video').length;
        final imageCount = items
            .where((item) => item.kind == 'avatar' || item.kind == 'image')
            .length;
        final audioCount = items
            .where((item) => item.kind == 'voice' || item.kind == 'audio')
            .length;
        final documentCount = items
            .where((item) => ['document', 'file', 'text'].contains(item.kind))
            .length;
        final filteredItems = items.where((item) {
          final query = _mediaSearchController.text.trim().toLowerCase();
          final matchesSearch =
              query.isEmpty ||
              item.title.toLowerCase().contains(query) ||
              item.publicId.toLowerCase().contains(query) ||
              item.source.toLowerCase().contains(query);
          final matchesFilter = switch (_mediaFilter) {
            'image' => item.kind == 'image' || item.kind == 'avatar',
            'video' => item.kind == 'video' || item.kind == 'round_video',
            'pdf' => item.kind == 'pdf',
            'audio' => item.kind == 'voice' || item.kind == 'audio',
            'document' => ['document', 'file', 'text'].contains(item.kind),
            _ => true,
          };
          return matchesSearch && matchesFilter;
        }).toList();
        if (_selectedMediaIndex >= filteredItems.length &&
            filteredItems.isNotEmpty) {
          _selectedMediaIndex = 0;
        }
        final selectedItem = filteredItems.isEmpty
            ? null
            : filteredItems[_selectedMediaIndex];
        final totalBytes = items.fold<int>(0, (sum, item) => sum + item.bytes);
        final usedStorage = (totalBytes / (1024 * 1024 * 1024)).clamp(0, 100);
        return _AdminReferenceScaffold(
          title: 'Media kutubxona',
          breadcrumbs: const ['Bosh sahifa', 'Media kutubona'],
          stats: [
            _AdminSummaryCardData(
              title: 'Rasmlar',
              value: imageCount.toString(),
              subtitle: 'Jami fayllar ichida',
              icon: Icons.image_outlined,
              color: AppColors.primaryBlue,
            ),
            _AdminSummaryCardData(
              title: 'Videolar',
              value: videoCount.toString(),
              subtitle: 'Video va round video',
              icon: Icons.video_file_rounded,
              color: AppColors.violet,
            ),
            _AdminSummaryCardData(
              title: 'PDF fayllar',
              value: pdfCount.toString(),
              subtitle: 'PDF hujjatlar',
              icon: Icons.picture_as_pdf_rounded,
              color: AppColors.errorRed,
            ),
            _AdminSummaryCardData(
              title: 'Boshqalar',
              value: (documentCount + audioCount).toString(),
              subtitle: 'Audio va hujjatlar',
              icon: Icons.description_outlined,
              color: AppColors.amber,
            ),
            _AdminSummaryCardData(
              title: 'Xotira ishlatilishi',
              value: '${usedStorage.toStringAsFixed(1)} GB',
              subtitle: '/ 100 GB',
              icon: Icons.storage_rounded,
              color: AppColors.primaryBlue,
            ),
          ],
          main: _AdminSectionSurface(
            title: 'Barcha media fayllar',
            action: _AdminPrimaryActionButton(
              label: 'Yangilash',
              icon: Icons.refresh_rounded,
              onPressed: _reload,
            ),
            child: items.isEmpty
                ? const _AdminEmptyMessage(
                    title: 'Media fayllar topilmadi',
                    message:
                        'Yuklangan Cloudinary fayllar, dars fayllari va sertifikat URLlari shu yerda ko‘rinadi.',
                  )
                : Column(
                    children: [
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          SizedBox(
                            width: 270,
                            child: TextField(
                              controller: _mediaSearchController,
                              onChanged: (_) => setState(() {}),
                              decoration: const InputDecoration(
                                hintText: 'Fayl nomi bo‘yicha qidirish...',
                                prefixIcon: Icon(Icons.search_rounded),
                              ),
                            ),
                          ),
                          _AdminFilterChip(
                            label: 'Barcha fayllar',
                            active: _mediaFilter == 'all',
                            onTap: () => setState(() => _mediaFilter = 'all'),
                          ),
                          _AdminFilterChip(
                            label: 'Rasmlar',
                            active: _mediaFilter == 'image',
                            onTap: () => setState(() => _mediaFilter = 'image'),
                          ),
                          _AdminFilterChip(
                            label: 'Videolar',
                            active: _mediaFilter == 'video',
                            onTap: () => setState(() => _mediaFilter = 'video'),
                          ),
                          _AdminFilterChip(
                            label: 'PDF',
                            active: _mediaFilter == 'pdf',
                            onTap: () => setState(() => _mediaFilter = 'pdf'),
                          ),
                          _AdminFilterChip(
                            label: 'Audio',
                            active: _mediaFilter == 'audio',
                            onTap: () => setState(() => _mediaFilter = 'audio'),
                          ),
                          _AdminFilterChip(
                            label: 'Hujjatlar',
                            active: _mediaFilter == 'document',
                            onTap: () =>
                                setState(() => _mediaFilter = 'document'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _AdminMediaLibraryTable(
                        items: filteredItems,
                        selectedIndex: _selectedMediaIndex,
                        onSelected: (index) =>
                            setState(() => _selectedMediaIndex = index),
                      ),
                    ],
                  ),
          ),
          rail: Column(
            children: [
              if (selectedItem != null) ...[
                _AdminMediaDetailsPanel(item: selectedItem),
                const SizedBox(height: 18),
              ],
              _AdminSectionSurface(
                title: 'Xotira ishlatilishi',
                child: Column(
                  children: [
                    CircularScore(
                      value: items.isEmpty
                          ? 0
                          : (usedStorage / 100).clamp(0, 1),
                      label: '100 GB',
                      color: AppColors.primaryBlue,
                      size: 118,
                    ),
                    const SizedBox(height: 12),
                    _LegendRow(
                      color: AppColors.primaryBlue,
                      label: 'Ishlatilgan',
                      value: '${usedStorage.toStringAsFixed(1)} GB',
                    ),
                    _LegendRow(
                      color: AppColors.successGreen,
                      label: 'Bo‘sh',
                      value:
                          '${(100 - usedStorage).clamp(0, 100).toStringAsFixed(1)} GB',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _AdminSectionSurface(
                title: 'Fayl turlari bo‘yicha',
                child: Column(
                  children: [
                    _LegendRow(
                      color: AppColors.successGreen,
                      label: 'Rasmlar',
                      value: '$imageCount',
                    ),
                    _LegendRow(
                      color: AppColors.violet,
                      label: 'Videolar',
                      value: '$videoCount',
                    ),
                    _LegendRow(
                      color: AppColors.amber,
                      label: 'Audio',
                      value: '$audioCount',
                    ),
                    _LegendRow(
                      color: AppColors.errorRed,
                      label: 'PDF',
                      value: '$pdfCount',
                    ),
                    _LegendRow(
                      color: AppColors.primaryBlue,
                      label: 'TEXT',
                      value: '$textCount',
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AdminMediaPreview extends StatelessWidget {
  const _AdminMediaPreview({required this.item});

  final AdminMediaSummary item;

  @override
  Widget build(BuildContext context) {
    final color = _mediaColorForKind(item.kind);
    final lowerUrl = item.url.toLowerCase();
    final isVisual =
        item.kind == 'image' ||
        item.kind == 'avatar' ||
        lowerUrl.endsWith('.jpg') ||
        lowerUrl.endsWith('.jpeg') ||
        lowerUrl.endsWith('.png') ||
        lowerUrl.endsWith('.webp');

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: isVisual
                ? ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                    child: Image.network(
                      item.url,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Center(
                          child: IconBadge(
                            icon: _mediaIconForKind(item.kind),
                            color: color,
                            size: 64,
                          ),
                        );
                      },
                    ),
                  )
                : Center(
                    child: IconBadge(
                      icon: _mediaIconForKind(item.kind),
                      color: color,
                      size: 64,
                    ),
                  ),
          ),
          Positioned(
            top: 10,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .92),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                item.kind.toUpperCase(),
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminFilterChip extends StatelessWidget {
  const _AdminFilterChip({
    required this.label,
    this.active = false,
    this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: active
              ? AppColors.primaryBlue.withValues(alpha: .1)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active
                ? AppColors.primaryBlue.withValues(alpha: .35)
                : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? AppColors.primaryBlue : AppColors.muted,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _AdminMediaLibraryTable extends StatelessWidget {
  const _AdminMediaLibraryTable({
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<AdminMediaSummary> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF1F2937) : AppColors.border,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 920),
          child: Column(
            children: [
              Container(
                color: isDark
                    ? const Color(0xFF0F172A)
                    : const Color(0xFFF8FAFC),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: const Row(
                  children: [
                    _AdminMediaHeader(width: 300, label: 'Fayl'),
                    _AdminMediaHeader(width: 110, label: 'Turi'),
                    _AdminMediaHeader(width: 110, label: 'Hajmi'),
                    _AdminMediaHeader(width: 150, label: 'Sana'),
                    _AdminMediaHeader(width: 120, label: 'Manba'),
                    _AdminMediaHeader(width: 160, label: 'Foydalanilgan joy'),
                  ],
                ),
              ),
              ...items.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                final color = _mediaColorForKind(item.kind);
                final selected = index == selectedIndex;
                return InkWell(
                  onTap: () => onSelected(index),
                  child: Container(
                    color: selected
                        ? AppColors.primaryBlue.withValues(alpha: .06)
                        : null,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 300,
                          child: Row(
                            children: [
                              IconBadge(
                                icon: _mediaIconForKind(item.kind),
                                color: color,
                                size: 38,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleSmall,
                                    ),
                                    if (item.width != null &&
                                        item.height != null)
                                      Text(
                                        '${item.width} x ${item.height}',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 110,
                          child: _AdminTablePill(
                            label: item.kind.toUpperCase(),
                            color: color,
                          ),
                        ),
                        SizedBox(
                          width: 110,
                          child: Text(
                            _formatAdminBytes(item.bytes),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        SizedBox(
                          width: 150,
                          child: Text(
                            _formatDate(item.updatedAt),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        SizedBox(
                          width: 120,
                          child: Text(
                            item.source,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        SizedBox(
                          width: 160,
                          child: Text(
                            item.usedIn.isEmpty ? '-' : item.usedIn.first,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminMediaHeader extends StatelessWidget {
  const _AdminMediaHeader({required this.width, required this.label});

  final double width;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: AppColors.muted,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _AdminMediaDetailsPanel extends StatelessWidget {
  const _AdminMediaDetailsPanel({required this.item});

  final AdminMediaSummary item;

  @override
  Widget build(BuildContext context) {
    return _AdminSectionSurface(
      title: 'Fayl ma’lumotlari',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 150, child: _AdminMediaPreview(item: item)),
          const SizedBox(height: 14),
          Text(
            item.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          _MediaDetailRow(label: 'Public ID', value: item.publicId),
          _MediaDetailRow(label: 'Resource', value: item.resourceType),
          _MediaDetailRow(label: 'Format', value: item.format),
          _MediaDetailRow(label: 'Hajmi', value: _formatAdminBytes(item.bytes)),
          if (item.durationSeconds != null)
            _MediaDetailRow(
              label: 'Davomiyligi',
              value: _formatAdminDuration(item.durationSeconds!),
            ),
          _MediaDetailRow(label: 'Sana', value: _formatDate(item.updatedAt)),
          const SizedBox(height: 12),
          _AdminAttachmentLink(
            icon: Icons.open_in_new_rounded,
            label: 'Preview ochish',
            onTap: () async {
              final uri = Uri.tryParse(item.url);
              if (uri != null) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
          ),
        ],
      ),
    );
  }
}

class _MediaDetailRow extends StatelessWidget {
  const _MediaDetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final normalized = value.trim().isEmpty ? '-' : value.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              normalized,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
        ],
      ),
    );
  }
}

class _RealRolesPage extends StatefulWidget {
  const _RealRolesPage();

  @override
  State<_RealRolesPage> createState() => _RealRolesPageState();
}

class _RealRolesPageState extends State<_RealRolesPage> {
  static const _repository = SupabaseAcademyRepository();
  late Future<List<AdminRoleSummary>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repository.loadAdminRoles();
  }

  void _reload() {
    setState(() => _future = _repository.loadAdminRoles());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AdminRoleSummary>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _AdminErrorState(
            message: snapshot.error.toString(),
            onRetry: _reload,
          );
        }
        final roles = snapshot.data ?? const <AdminRoleSummary>[];
        final totalUsers = roles.fold<int>(0, (sum, role) => sum + role.count);
        return _AdminReferenceScaffold(
          title: 'Rollar va ruxsatlar',
          breadcrumbs: const ['Bosh sahifa', 'Rollar va ruxsatlar'],
          stats: [
            _AdminSummaryCardData(
              title: 'Jami rollar',
              value: roles.length.toString(),
              subtitle: 'Tizimdagi rollar',
              icon: Icons.group_work_rounded,
              color: AppColors.primaryBlue,
            ),
            _AdminSummaryCardData(
              title: 'Jami ruxsatlar',
              value: (roles.length * 14).toString(),
              subtitle: 'Tizim bo‘ylab huquqlar',
              icon: Icons.shield_outlined,
              color: AppColors.successGreen,
            ),
            _AdminSummaryCardData(
              title: 'Foydalanuvchilar',
              value: totalUsers.toString(),
              subtitle: 'Rollarga biriktirilgan',
              icon: Icons.people_alt_rounded,
              color: AppColors.violet,
            ),
            _AdminSummaryCardData(
              title: 'Faol rollar',
              value: roles.where((role) => role.count > 0).length.toString(),
              subtitle: 'Ishlatilayotgan rollar',
              icon: Icons.key_rounded,
              color: AppColors.amber,
            ),
            _AdminSummaryCardData(
              title: 'Oxirgi yangilanish',
              value: 'Bugun',
              subtitle: '10:30 da',
              icon: Icons.schedule_rounded,
              color: AppColors.primaryBlue,
            ),
          ],
          main: LayoutBuilder(
            builder: (context, constraints) {
              final rolesTable = _AdminSectionSurface(
                title: 'Rollar',
                action: _AdminPrimaryActionButton(
                  label: 'Yangilash',
                  icon: Icons.refresh_rounded,
                  onPressed: _reload,
                ),
                child: roles.isEmpty
                    ? const _AdminEmptyMessage(
                        title: 'Rollar topilmadi',
                        message:
                            'Profiles jadvalidagi role qiymatlari shu yerda ko‘rinadi.',
                      )
                    : _AdminTable(
                        columns: const [
                          '#',
                          'Rol nomi',
                          'Tavsif',
                          'Foydalanuvchilar',
                          'Status',
                          'Amallar',
                        ],
                        rows: roles.asMap().entries.map((entry) {
                          final role = entry.value;
                          final description = switch (role.role) {
                            'admin' => 'To‘liq boshqaruv va kontent huquqlari',
                            'teacher' =>
                              'Kurs, test va talabalar bilan ishlash',
                            'student' =>
                              'O‘quv materiallari va testlarga kirish',
                            _ => 'Cheklangan tizim huquqlari',
                          };
                          return [
                            '${entry.key + 1}',
                            role.role,
                            description,
                            role.count.toString(),
                            role.count > 0 ? 'Faol' : 'NoFaol',
                            'view edit',
                          ];
                        }).toList(),
                      ),
              );
              final matrix = _AdminSectionSurface(
                title: 'Ruxsatlar matritsasi',
                child: const _PermissionMatrixCard(),
              );
              if (constraints.maxWidth > 1220) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 5, child: rolesTable),
                    const SizedBox(width: 18),
                    Expanded(flex: 4, child: matrix),
                  ],
                );
              }
              return Column(
                children: [rolesTable, const SizedBox(height: 18), matrix],
              );
            },
          ),
          rail: Column(
            children: [
              _AdminSectionSurface(
                title: 'Rollar statistikasi',
                child: Column(
                  children: roles
                      .map(
                        (role) => _LegendRow(
                          color: role.role == 'admin'
                              ? AppColors.primaryBlue
                              : role.role == 'teacher'
                              ? AppColors.successGreen
                              : AppColors.violet,
                          label: role.role,
                          value: role.count.toString(),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 18),
              _AdminSectionSurface(
                title: 'Oxirgi faoliyatlar',
                child: Column(
                  children: const [
                    _AdminActionTile(
                      icon: Icons.person_add_alt_1_rounded,
                      title: 'Yangi rol yaratildi',
                      subtitle: 'Mentor roli yaratildi',
                    ),
                    SizedBox(height: 12),
                    _AdminActionTile(
                      icon: Icons.edit_note_rounded,
                      title: 'Rol yangilandi',
                      subtitle: 'O‘qituvchi ruxsatlari yangilandi',
                      color: AppColors.violet,
                    ),
                    SizedBox(height: 12),
                    _AdminActionTile(
                      icon: Icons.lock_open_rounded,
                      title: 'Ruxsat berildi',
                      subtitle: 'Mentor roliga yangi huquq qo‘shildi',
                      color: AppColors.successGreen,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RealSettingsPage extends StatefulWidget {
  const _RealSettingsPage({
    required this.themeMode,
    required this.onThemeChanged,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;

  @override
  State<_RealSettingsPage> createState() => _RealSettingsPageState();
}

class _RealSettingsPageState extends State<_RealSettingsPage> {
  static const _repository = SupabaseAcademyRepository();
  static const _sections = [
    (
      icon: Icons.settings_outlined,
      title: 'Umumiy sozlamalar',
      subtitle: 'Asosiy tizim parametrlari',
    ),
    (
      icon: Icons.info_outline_rounded,
      title: 'Tizim ma’lumotlari',
      subtitle: 'Versiya va server holati',
    ),
    (
      icon: Icons.backup_rounded,
      title: 'Zaxira nusxa',
      subtitle: 'Backup tarixi va tiklash',
    ),
    (
      icon: Icons.security_rounded,
      title: 'Xavfsizlik',
      subtitle: 'Sessiya, 2FA, JWT timeout',
    ),
    (
      icon: Icons.payments_outlined,
      title: 'To‘lov sozlamalari',
      subtitle: 'Click, Payme, Stripe',
    ),
    (
      icon: Icons.extension_rounded,
      title: 'Integratsiyalar',
      subtitle: 'Telegram, Cloudinary, SMTP',
    ),
  ];

  late Future<AdminDashboardData> _future;
  int _selectedSettingsIndex = 0;
  bool _settingsSaving = false;

  @override
  void initState() {
    super.initState();
    _future = _repository.loadAdminDashboard();
  }

  void _reload() {
    setState(() => _future = _repository.loadAdminDashboard());
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.themeMode == ThemeMode.dark;
    return FutureBuilder<AdminDashboardData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _AdminErrorState(
            message: snapshot.error.toString(),
            onRetry: _reload,
          );
        }
        final data = snapshot.data!;
        final activeSection = _sections[_selectedSettingsIndex];
        return _AdminReferenceScaffold(
          title: activeSection.title == 'Umumiy sozlamalar'
              ? 'Sozlamalar'
              : activeSection.title,
          breadcrumbs: [
            'Bosh sahifa',
            'Sozlamalar',
            if (activeSection.title != 'Umumiy sozlamalar') activeSection.title,
          ],
          stats: const [],
          main: LayoutBuilder(
            builder: (context, constraints) {
              final menu = AppCard(
                child: Column(
                  children: _sections.asMap().entries.map((entry) {
                    final index = entry.key;
                    final section = entry.value;
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: index == _sections.length - 1 ? 0 : 10,
                      ),
                      child: _AdminActionTile(
                        icon: section.icon,
                        title: section.title,
                        subtitle: section.subtitle,
                        color: index == _selectedSettingsIndex
                            ? AppColors.primaryBlue
                            : AppColors.muted,
                        onTap: () =>
                            setState(() => _selectedSettingsIndex = index),
                      ),
                    );
                  }).toList(),
                ),
              );
              final sectionContent = _buildSettingsSection(
                context,
                activeSection.title,
                dark,
                data,
              );
              final center = activeSection.title == 'Umumiy sozlamalar'
                  ? _AdminSectionSurface(
                      title: activeSection.title,
                      action: _AdminPrimaryActionButton(
                        label: _settingsSaving ? 'Saqlanmoqda' : 'Saqlash',
                        icon: _settingsSaving
                            ? Icons.hourglass_top_rounded
                            : Icons.save_outlined,
                        onPressed: () => _saveSettingsSection(
                          context,
                          activeSection.title,
                          data,
                        ),
                      ),
                      child: sectionContent,
                    )
                  : sectionContent;
              if (constraints.maxWidth > 1120) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: menu),
                    const SizedBox(width: 18),
                    Expanded(flex: 8, child: center),
                  ],
                );
              }
              return Column(
                children: [menu, const SizedBox(height: 18), center],
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _saveSettingsSection(
    BuildContext context,
    String section,
    AdminDashboardData data,
  ) async {
    if (_settingsSaving) return;
    setState(() => _settingsSaving = true);
    try {
      await _repository.saveAdminSetting(
        section: _settingsKey(section),
        key: 'state',
        value: {
          'title': section,
          'theme': widget.themeMode.name,
          'students': data.recentStudentsCount,
          'active_users': data.activeUsersCount,
          'top_modules': data.topModules.length,
          'certificates': data.certificateCount,
          'notifications': data.notificationCount,
          'completion_percent': data.completionPercent,
          'saved_at': DateTime.now().toIso8601String(),
        },
      );
      if (!context.mounted) return;
      _showAdminSnack(context, '$section Supabase’da saqlandi.');
    } catch (error) {
      if (!context.mounted) return;
      _showAdminSnack(context, 'Saqlashda xatolik: $error');
    } finally {
      if (mounted) setState(() => _settingsSaving = false);
    }
  }

  String _settingsKey(String section) {
    return section
        .toLowerCase()
        .replaceAll('‘', '')
        .replaceAll('’', '')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }

  Widget _buildSettingsSection(
    BuildContext context,
    String section,
    bool dark,
    AdminDashboardData data,
  ) {
    switch (section) {
      case 'Tizim ma’lumotlari':
        return _buildSystemInfoSettings(data);
      case 'Zaxira nusxa':
        return _buildBackupSettings(context);
      case 'Xavfsizlik':
        return _buildSecuritySettings();
      case 'To‘lov sozlamalari':
        return _buildPaymentSettings(data);
      case 'Integratsiyalar':
        return _buildIntegrationSettings(data);
      default:
        return _buildGeneralSettings(context, dark);
    }
  }

  Widget _buildGeneralSettings(BuildContext context, bool dark) {
    return Column(
      children: [
        _SettingsFormRow(
          icon: Icons.settings_outlined,
          title: 'Platforma nomi',
          subtitle: 'Tizim nomi talabalar va o‘qituvchilarga ko‘rinadi',
          child: const _SettingsInputShell(text: 'EduLab'),
        ),
        const _SettingsFormRow(
          icon: Icons.school_rounded,
          title: 'Platforma logotipi',
          subtitle: 'Tizim logotipini yuklang',
          child: _SettingsFileShell(fileName: 'edulab-logo.svg'),
        ),
        const _SettingsFormRow(
          icon: Icons.description_outlined,
          title: 'Platforma tavsifi',
          subtitle: 'Qisqacha tavsif foydalanuvchilar uchun',
          child: _SettingsInputShell(
            text:
                'EduLab - zamonaviy online ta’lim platformasi.\nSifatli ta’lim, oson boshqaruv.',
            minLines: 2,
          ),
        ),
        const _SettingsFormRow(
          icon: Icons.schedule_rounded,
          title: 'Vaqt mintaqasi',
          subtitle: 'Tizim vaqt mintaqasini tanlang',
          child: _SettingsSelectShell(text: '(UTC+05:00) Tashkent'),
        ),
        const _SettingsFormRow(
          icon: Icons.calendar_month_rounded,
          title: 'Sana formati',
          subtitle: 'Sana ko‘rinish formatini tanlang',
          child: _SettingsSelectShell(text: 'DD.MM.YYYY (15.05.2026)'),
        ),
        const _SettingsFormRow(
          icon: Icons.access_time_rounded,
          title: 'Vaqt formati',
          subtitle: 'Vaqt ko‘rinish formatini tanlang',
          child: _SettingsSelectShell(text: '24 soat (14:30)'),
        ),
        const _SettingsFormRow(
          icon: Icons.table_rows_rounded,
          title: 'Elementlar soni sahifada',
          subtitle: 'Jadvallarda har sahifada ko‘rsatiladigan elementlar soni',
          child: _SettingsSelectShell(text: '20'),
        ),
        _SettingsFormRow(
          icon: Icons.folder_open_rounded,
          title: 'Xizmat holati',
          subtitle: 'Platformani vaqtincha yopish',
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Switch(value: false, onChanged: (_) {}),
              const SizedBox(width: 8),
              Text(
                'O‘chirilgan',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
        ),
        _SettingsFormRow(
          icon: Icons.dark_mode_rounded,
          title: 'Qorong‘i rejim',
          subtitle: 'Admin interfeys mavzusi',
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Switch(
                value: dark,
                onChanged: (value) => widget.onThemeChanged(
                  value ? ThemeMode.dark : ThemeMode.light,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSystemInfoSettings(AdminDashboardData data) {
    final stats = [
      const _AdminSummaryCardData(
        title: 'Server holati',
        value: 'Onlayn',
        subtitle: 'Ish vaqti: 23 kun',
        icon: Icons.dns_rounded,
        color: AppColors.primaryBlue,
      ),
      const _AdminSummaryCardData(
        title: 'Supabase holati',
        value: 'Onlayn',
        subtitle: 'Oxirgi tekshiruv: 1 daqiqa',
        icon: Icons.storage_rounded,
        color: AppColors.successGreen,
      ),
      const _AdminSummaryCardData(
        title: 'Saqlash',
        value: '12.4 GB',
        subtitle: '100 GB dan 12%',
        icon: Icons.folder_rounded,
        color: AppColors.amber,
      ),
      const _AdminSummaryCardData(
        title: 'API kechikishi',
        value: '120 ms',
        subtitle: 'O‘rtacha javob vaqti',
        icon: Icons.speed_rounded,
        color: AppColors.violet,
      ),
    ];
    final info = _AdminSectionSurface(
      title: 'Asosiy ma’lumotlar',
      child: Column(
        children: [
          const _SettingsInfoRow(label: 'Platforma nomi', value: 'EduLab'),
          const _SettingsInfoRow(label: 'Joriy versiya', value: 'v2.3.1'),
          const _SettingsInfoRow(label: 'Build raqami', value: '230515.1030'),
          const _SettingsInfoRow(
            label: 'Muhit (Environment)',
            value: 'Production',
          ),
          const _SettingsInfoRow(label: 'Node.js versiyasi', value: 'v20.11.1'),
          const _SettingsInfoRow(
            label: 'Ma’lumotlar bazasi',
            value: 'PostgreSQL 15.2',
          ),
          const _SettingsInfoRow(
            label: 'Oxirgi zaxira nusxa',
            value: '15.05.2026 02:30',
          ),
          const _SettingsInfoRow(
            label: 'Vaqt mintaqasi',
            value: '(UTC+05:00) Tashkent',
          ),
          _SettingsInfoRow(
            label: 'Real dashboard yakunlash',
            value: '${(data.completionPercent * 100).round()}%',
          ),
        ],
      ),
    );
    final resources = _AdminSectionSurface(
      title: 'Tizim resurslari',
      child: Column(
        children: const [
          _SettingsResourceChart(
            label: 'CPU yuklanishi',
            value: '18%',
            color: AppColors.primaryBlue,
            values: [12, 28, 33, 16, 24, 22, 14, 11, 18, 31, 13, 20, 27],
          ),
          _SettingsResourceChart(
            label: 'RAM ishlatilishi',
            value: '42%',
            color: AppColors.successGreen,
            values: [15, 22, 14, 34, 28, 19, 24, 21, 38, 25, 18, 34, 27],
          ),
          _SettingsResourceChart(
            label: 'Disk ishlatilishi',
            value: '12%',
            color: AppColors.violet,
            values: [8, 18, 32, 23, 14, 18, 13, 30, 16, 25, 10, 28, 35],
          ),
        ],
      ),
    );
    return Column(
      children: [
        _AdminSummaryStrip(items: stats),
        const SizedBox(height: 16),
        _settingsResponsivePair(info, resources),
        const SizedBox(height: 16),
        _settingsResponsiveGrid([
          _AdminSectionSurface(
            title: 'Ulangan servislar',
            child: Column(
              children: const [
                _LegendRow(
                  color: AppColors.successGreen,
                  label: 'Supabase Storage',
                  value: 'Ulangan',
                ),
                _LegendRow(
                  color: AppColors.successGreen,
                  label: 'Resend (Email)',
                  value: 'Ulangan',
                ),
                _LegendRow(
                  color: AppColors.successGreen,
                  label: 'Cloudinary (Media)',
                  value: 'Ulangan',
                ),
                _LegendRow(
                  color: AppColors.successGreen,
                  label: 'Sentry (Error Tracking)',
                  value: 'Ulangan',
                ),
              ],
            ),
          ),
          _AdminSectionSurface(
            title: 'Faol sessiyalar',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _SettingsBigNumber(
                  label: 'Hozir tizimda faol foydalanuvchilar',
                  value: '15 ta',
                ),
                _SettingsInfoRow(
                  label: '192.168.1.10',
                  value: 'Chrome / Hozir',
                ),
                _SettingsInfoRow(
                  label: '192.168.1.25',
                  value: 'Firefox / 2 daq oldin',
                ),
                _SettingsInfoRow(
                  label: '192.168.1.30',
                  value: 'Safari / 5 daq oldin',
                ),
              ],
            ),
          ),
          _AdminSectionSurface(
            title: 'Oxirgi loglar',
            child: Column(
              children: const [
                _LegendRow(
                  color: AppColors.successGreen,
                  label: 'Tizimga muvaffaqiyatli kirildi',
                  value: '14:25',
                ),
                _LegendRow(
                  color: AppColors.amber,
                  label: 'Zaxira nusxa yaratildi',
                  value: '02:30',
                ),
                _LegendRow(
                  color: AppColors.primaryBlue,
                  label: 'Fayl yuklandi: dars-1.pdf',
                  value: '23:15',
                ),
                _LegendRow(
                  color: AppColors.violet,
                  label: 'Xavfsizlik tekshiruvi bajarildi',
                  value: '20:10',
                ),
              ],
            ),
          ),
        ]),
      ],
    );
  }

  Widget _buildBackupSettings(BuildContext context) {
    final about = _AdminSectionSurface(
      title: 'Zaxira nusxa haqida',
      child: Column(
        children: const [
          _AdminActionTile(
            icon: Icons.verified_user_rounded,
            title: 'Xavfsiz va shifrlangan',
            subtitle: 'Ma’lumotlaringiz AES-256 bilan shifrlanadi',
          ),
          SizedBox(height: 10),
          _AdminActionTile(
            icon: Icons.update_rounded,
            title: 'Avtomatik zaxira',
            subtitle: 'Rejalashtirilgan zaxira nusxalar avtomatik yaratiladi',
            color: AppColors.primaryBlue,
          ),
          SizedBox(height: 10),
          _AdminActionTile(
            icon: Icons.restore_rounded,
            title: 'Oson tiklash',
            subtitle: 'Bir necha qadamda tizimni tiklashingiz mumkin',
            color: AppColors.successGreen,
          ),
          SizedBox(height: 10),
          _AdminActionTile(
            icon: Icons.info_outline_rounded,
            title: 'Oxirgi zaxira nusxa: 15.05.2026 02:30',
            subtitle: 'Hajmi: 2.45 GB • Turi: To‘liq zaxira',
            color: AppColors.primaryBlue,
          ),
        ],
      ),
    );
    final create = _AdminSectionSurface(
      title: 'Yangi zaxira nusxa yaratish',
      action: _AdminPrimaryActionButton(
        label: 'Zaxira nusxa yaratish',
        icon: Icons.cloud_upload_outlined,
        onPressed: () => _showAdminSnack(context, 'Backup navbatga qo‘yildi.'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text('Zaxira turi', style: TextStyle(fontWeight: FontWeight.w900)),
          SizedBox(height: 10),
          _SettingsChoiceRow(),
          SizedBox(height: 16),
          _SettingsInputShell(
            text: 'Izoh kiriting (masalan: yangilashdan oldin)',
          ),
        ],
      ),
    );
    return Column(
      children: [
        _settingsResponsivePair(about, create),
        const SizedBox(height: 16),
        _AdminSectionSurface(
          title: 'Zaxira nusxalar ro‘yxati',
          child: _AdminTable(
            columns: const [
              'Nomi',
              'Turi',
              'Hajmi',
              'Yaratilgan sana',
              'Izoh',
              'Holat',
              'Amallar',
            ],
            rows: const [
              [
                'backup_2026_05_15_0230',
                'To‘liq',
                '2.45 GB',
                '15.05.2026 02:30',
                '-',
                'Faol',
                'view edit delete',
              ],
              [
                'backup_2026_05_14_0230',
                'To‘liq',
                '2.41 GB',
                '14.05.2026 02:30',
                'Kundalik zaxira',
                'Faol',
                'view edit delete',
              ],
              [
                'backup_2026_05_13_0230',
                'To‘liq',
                '2.38 GB',
                '13.05.2026 02:30',
                'Kundalik zaxira',
                'Faol',
                'view edit delete',
              ],
              [
                'backup_2026_05_12_0230',
                'Ma’lumotlar bazasi',
                '512 MB',
                '12.05.2026 02:30',
                '-',
                'Faol',
                'view edit delete',
              ],
            ],
            compact: true,
            minWidth: 940,
          ),
        ),
      ],
    );
  }

  Widget _buildSecuritySettings() {
    return Column(
      children: [
        _AdminSummaryStrip(
          items: const [
            _AdminSummaryCardData(
              title: 'Xavfsizlik darajasi',
              value: '98%',
              subtitle: 'Yuqori himoya',
              icon: Icons.shield_outlined,
              color: AppColors.primaryBlue,
            ),
            _AdminSummaryCardData(
              title: 'Faol sessiyalar',
              value: '15',
              subtitle: 'Oxirgi 24 soat',
              icon: Icons.groups_rounded,
              color: AppColors.primaryBlue,
            ),
            _AdminSummaryCardData(
              title: 'Ikki faktorli autentifikatsiya',
              value: 'ON',
              subtitle: 'Himoya yoqilgan',
              icon: Icons.lock_rounded,
              color: AppColors.successGreen,
            ),
            _AdminSummaryCardData(
              title: 'Xavfsizlik devori',
              value: 'Himoyalangan',
              subtitle: 'Firewall faol',
              icon: Icons.security_rounded,
              color: AppColors.successGreen,
            ),
            _AdminSummaryCardData(
              title: 'Muvaffaqiyatsiz urinishlar',
              value: '2',
              subtitle: 'Oxirgi 24 soat',
              icon: Icons.lock_outline_rounded,
              color: AppColors.errorRed,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _settingsResponsiveGrid([
          _AdminSectionSurface(
            title: 'Kirish faolligi',
            child: EmptyChart(
              values: const [
                18,
                34,
                50,
                69,
                31,
                43,
                40,
                75,
                28,
                55,
                23,
                63,
                80,
              ],
              height: 155,
            ),
          ),
          _AdminSectionSurface(
            title: 'Xavfli faoliyatlar',
            child: Column(
              children: const [
                _AdminActionTile(
                  icon: Icons.warning_rounded,
                  title: 'Muvaffaqiyatsiz kirish urinishlari',
                  subtitle: '5 marta noto‘g‘ri parol kiritildi',
                  color: AppColors.errorRed,
                ),
                SizedBox(height: 10),
                _AdminActionTile(
                  icon: Icons.warning_amber_rounded,
                  title: 'Shubhali qurilmadan kirish',
                  subtitle: 'Yangi qurilmadan tizimga kirildi',
                  color: AppColors.amber,
                ),
                SizedBox(height: 10),
                _AdminActionTile(
                  icon: Icons.block_rounded,
                  title: 'Bloklangan IP urinish',
                  subtitle: 'Bloklangan IP dan kirishga urinish',
                  color: AppColors.errorRed,
                ),
              ],
            ),
          ),
          _AdminSectionSurface(
            title: 'Kirishlar geografiyasi',
            child: Column(
              children: const [
                _WorldMapPreview(),
                SizedBox(height: 12),
                _LegendRow(
                  color: AppColors.successGreen,
                  label: 'Muvaffaqiyatli',
                  value: '325',
                ),
                _LegendRow(
                  color: AppColors.amber,
                  label: 'Shubhali',
                  value: '7',
                ),
                _LegendRow(
                  color: AppColors.errorRed,
                  label: 'Bloklangan',
                  value: '3',
                ),
              ],
            ),
          ),
        ]),
        const SizedBox(height: 16),
        _settingsResponsiveGrid([
          _AdminSectionSurface(
            title: 'Ishonchli qurilmalar',
            child: _AdminTable(
              columns: const [
                'Qurilma',
                'Brauzer',
                'IP manzil',
                'Joylashuv',
                'Oxirgi faoliyat',
                'Amal',
              ],
              rows: const [
                [
                  'MacBook Pro 16”',
                  'Chrome 124',
                  '192.168.1.10',
                  'Toshkent, UZ',
                  '15.05.2026 14:25',
                  'Chiqish',
                ],
                [
                  'Windows PC',
                  'Edge 124',
                  '192.168.1.25',
                  'Samarqand, UZ',
                  '15.05.2026 12:10',
                  'Chiqish',
                ],
                [
                  'iPhone 15 Pro',
                  'Safari 17',
                  '192.168.1.30',
                  'Toshkent, UZ',
                  '15.05.2026 11:45',
                  'Chiqish',
                ],
              ],
              compact: true,
              minWidth: 760,
            ),
          ),
          _AdminSectionSurface(
            title: 'Parol siyosati',
            child: Column(
              children: const [
                _LegendRow(
                  color: AppColors.successGreen,
                  label: 'Minimal uzunlik: 8 belgi',
                ),
                _LegendRow(
                  color: AppColors.successGreen,
                  label: 'Katta harf: Yoqilgan',
                ),
                _LegendRow(
                  color: AppColors.successGreen,
                  label: 'Raqam: Yoqilgan',
                ),
                _LegendRow(
                  color: AppColors.successGreen,
                  label: 'Parol muddati: 90 kun',
                ),
              ],
            ),
          ),
          _AdminSectionSurface(
            title: 'Sessiya va xavfsizlik',
            child: Column(
              children: const [
                _SettingsInfoRow(label: 'Sessiya muddati', value: '30 daqiqa'),
                _SettingsSwitchRow(
                  icon: Icons.logout_rounded,
                  label: 'Avtomatik chiqish',
                  value: true,
                ),
                _SettingsSwitchRow(
                  icon: Icons.fingerprint_rounded,
                  label: 'Biometrik kirish',
                  value: true,
                ),
                _SettingsSwitchRow(
                  icon: Icons.admin_panel_settings_rounded,
                  label: 'Admin tasdiqlovi',
                  value: true,
                ),
              ],
            ),
          ),
        ]),
      ],
    );
  }

  Widget _buildPaymentSettings(AdminDashboardData data) {
    return Column(
      children: [
        _AdminSummaryStrip(
          items: [
            const _AdminSummaryCardData(
              title: 'Oylik daromad',
              value: '124,560,000 so‘m',
              subtitle: '↑ 18.5%',
              icon: Icons.account_balance_wallet_rounded,
              color: AppColors.primaryBlue,
            ),
            const _AdminSummaryCardData(
              title: 'Muvaffaqiyatli to‘lovlar',
              value: '2,453 ta',
              subtitle: '↑ 15.2%',
              icon: Icons.credit_score_rounded,
              color: AppColors.successGreen,
            ),
            _AdminSummaryCardData(
              title: 'Faol obunalar',
              value: data.activeUsersCount.toString(),
              subtitle: 'Real foydalanuvchilar',
              icon: Icons.groups_rounded,
              color: AppColors.violet,
            ),
            const _AdminSummaryCardData(
              title: 'Muvaffaqiyatsiz to‘lovlar',
              value: '32 ta',
              subtitle: '↓ 8.3%',
              icon: Icons.warning_amber_rounded,
              color: AppColors.errorRed,
            ),
            const _AdminSummaryCardData(
              title: 'Jami tushum',
              value: '856,320,000 so‘m',
              subtitle: '↑ 20.4%',
              icon: Icons.savings_rounded,
              color: AppColors.primaryBlue,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _settingsResponsivePair(
          _AdminSectionSurface(
            title: 'Daromad statistikasi',
            child: EmptyChart(
              values: const [21, 45, 70, 58, 83, 71, 76, 104, 72, 64, 98, 132],
              height: 220,
            ),
          ),
          _AdminSectionSurface(
            title: 'To‘lov usullari',
            child: Column(
              children: const [
                _SettingsPaymentRow(
                  name: 'Click',
                  fee: '1.5%',
                  color: Color(0xFF6D28D9),
                ),
                _SettingsPaymentRow(
                  name: 'Payme',
                  fee: '1.6%',
                  color: Color(0xFF22C6C8),
                ),
                _SettingsPaymentRow(
                  name: 'Uzum Bank',
                  fee: '1.7%',
                  color: Color(0xFF6D28D9),
                ),
                _SettingsPaymentRow(
                  name: 'Stripe',
                  fee: '2.9%',
                  color: Color(0xFF2563EB),
                ),
                _SettingsPaymentRow(
                  name: 'PayPal',
                  fee: '3.4%',
                  color: Color(0xFF0EA5E9),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _settingsResponsiveGrid([
          _AdminSectionSurface(
            title: 'Obuna rejalari',
            child: const _SubscriptionPlansPreview(),
          ),
          _AdminSectionSurface(
            title: 'So‘nggi tranzaksiyalar',
            child: _AdminTable(
              columns: const [
                'Talaba',
                'Summa',
                'To‘lov usuli',
                'Status',
                'Sana',
              ],
              rows: const [
                [
                  'Alisher Usmonov',
                  '99,000 so‘m',
                  'Payme',
                  'Faol',
                  '15.05.2025 14:25',
                ],
                [
                  'Madina Karimova',
                  '49,000 so‘m',
                  'Click',
                  'Faol',
                  '15.05.2025 13:10',
                ],
                [
                  'Bobur Abdullayev',
                  '199,000 so‘m',
                  'Uzum Bank',
                  'Faol',
                  '15.05.2025 12:45',
                ],
                [
                  'Dilshod Sodiqov',
                  '99,000 so‘m',
                  'Payme',
                  'pending',
                  '15.05.2025 11:30',
                ],
              ],
              compact: true,
              minWidth: 700,
            ),
          ),
          _AdminSectionSurface(
            title: 'To‘lov avtomatik sozlamalari',
            child: Column(
              children: const [
                _SettingsSwitchRow(
                  icon: Icons.autorenew_rounded,
                  label: 'Obunani avtomatik yangilash',
                  value: true,
                ),
                _SettingsSwitchRow(
                  icon: Icons.notifications_active_rounded,
                  label: 'To‘lov eslatmalari',
                  value: true,
                ),
                _SettingsInfoRow(label: 'Soliq va QQS', value: '12%'),
              ],
            ),
          ),
        ]),
      ],
    );
  }

  Widget _buildIntegrationSettings(AdminDashboardData data) {
    return Column(
      children: [
        _AdminSummaryStrip(
          items: [
            const _AdminSummaryCardData(
              title: 'Ulangan servislar',
              value: '8',
              subtitle: 'Jami faol integratsiyalar',
              icon: Icons.settings_applications_rounded,
              color: AppColors.violet,
            ),
            const _AdminSummaryCardData(
              title: 'Faol integratsiyalar',
              value: '6',
              subtitle: 'Samarali ishlayapti',
              icon: Icons.check_circle_rounded,
              color: AppColors.successGreen,
            ),
            const _AdminSummaryCardData(
              title: 'Kutilayotgan ulanishlar',
              value: '1',
              subtitle: 'Sozlash talab qiladi',
              icon: Icons.pending_rounded,
              color: AppColors.amber,
            ),
            const _AdminSummaryCardData(
              title: 'Xatoliklar',
              value: '1',
              subtitle: 'Ulanishda muammo bor',
              icon: Icons.cancel_rounded,
              color: AppColors.errorRed,
            ),
            _AdminSummaryCardData(
              title: 'API so‘rovlar',
              value: (data.notificationCount * 12 + 12456).toString(),
              subtitle: 'Oxirgi 30 kun',
              icon: Icons.bar_chart_rounded,
              color: AppColors.primaryBlue,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _settingsResponsiveGrid([
          _AdminSectionSurface(
            title: 'Ulangan servislar',
            child: _AdminTable(
              columns: const [
                'Servis nomi',
                'Tavsif',
                'Holat',
                'So‘nggi sinxron',
                'Amallar',
              ],
              rows: const [
                [
                  'Telegram',
                  'Telegram bot orqali xabarnomalar yuborish',
                  'Faol',
                  '15.05.2025 14:25',
                  'Sozlash',
                ],
                [
                  'Email (SMTP)',
                  'SMTP server orqali email yuborish',
                  'Faol',
                  '15.05.2025 13:40',
                  'Sozlash',
                ],
                [
                  'Google OAuth',
                  'Google orqali avtorizatsiya',
                  'Faol',
                  '15.05.2025 12:10',
                  'Sozlash',
                ],
                [
                  'Click (To‘lov)',
                  'Click to‘lov tizimi integratsiyasi',
                  'Faol',
                  '15.05.2025 11:22',
                  'Sozlash',
                ],
                [
                  'Payme (To‘lov)',
                  'Payme to‘lov tizimi integratsiyasi',
                  'Faol',
                  '15.05.2025 10:05',
                  'Sozlash',
                ],
              ],
              compact: true,
              minWidth: 900,
            ),
          ),
          _AdminSectionSurface(
            title: 'Integratsiya tafsilotlari',
            child: Column(
              children: const [
                _AdminActionTile(
                  icon: Icons.telegram_rounded,
                  title: 'Telegram',
                  subtitle: 'Ulangan',
                  color: AppColors.primaryBlue,
                ),
                SizedBox(height: 10),
                _SettingsInfoRow(
                  label: 'Bot Token',
                  value: '123456••••••••••••',
                ),
                _SettingsInfoRow(label: 'Chat ID', value: '-1001234567890'),
                _SettingsInfoRow(
                  label: 'Webhook URL',
                  value: '/api/integrations/telegram/webhook',
                ),
                _SettingsInfoRow(label: 'Holat', value: 'Aktiv'),
              ],
            ),
          ),
          _AdminSectionSurface(
            title: 'API kalitlar',
            child: Column(
              children: const [
                _SettingsInfoRow(
                  label: 'Public API Key',
                  value: 'pk_live_••••••••••',
                ),
                _SettingsInfoRow(
                  label: 'Secret API Key',
                  value: 'sk_live_••••••••••',
                ),
                _SettingsInfoRow(
                  label: 'Webhook Secret',
                  value: 'whsec_••••••••••',
                ),
                _SettingsInfoRow(
                  label: '/api/webhooks/payment',
                  value: 'Aktiv',
                ),
                _SettingsInfoRow(
                  label: '/api/webhooks/student',
                  value: 'Aktiv',
                ),
                _SettingsInfoRow(
                  label: '/api/webhooks/subscription',
                  value: 'Aktiv',
                ),
              ],
            ),
          ),
          _AdminSectionSurface(
            title: 'Integratsiya loglari',
            child: Column(
              children: const [
                _LegendRow(
                  color: AppColors.successGreen,
                  label: 'Telegram: Xabar muvaffaqiyatli yuborildi',
                  value: '14:25',
                ),
                _LegendRow(
                  color: AppColors.primaryBlue,
                  label: 'Email: Xat yuborildi',
                  value: '14:20',
                ),
                _LegendRow(
                  color: AppColors.amber,
                  label: 'Google Analytics: Ma’lumot yuborildi',
                  value: '14:10',
                ),
                _LegendRow(
                  color: AppColors.errorRed,
                  label: 'CRM: Sinxronizatsiya xatoligi',
                  value: '14:05',
                ),
              ],
            ),
          ),
        ]),
      ],
    );
  }

  Widget _settingsResponsivePair(Widget left, Widget right) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 980) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: left),
              const SizedBox(width: 16),
              Expanded(child: right),
            ],
          );
        }
        return Column(children: [left, const SizedBox(height: 16), right]);
      },
    );
  }

  Widget _settingsResponsiveGrid(List<Widget> children) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 1320
            ? 3
            : constraints.maxWidth > 860
            ? 2
            : 1;
        final itemWidth =
            (constraints.maxWidth - (16 * (columns - 1))) / columns;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: children
              .map((child) => SizedBox(width: itemWidth, child: child))
              .toList(),
        );
      },
    );
  }
}

class _ModuleEditorDialog extends StatefulWidget {
  const _ModuleEditorDialog({this.module});

  final AdminModuleSummary? module;

  @override
  State<_ModuleEditorDialog> createState() => _ModuleEditorDialogState();
}

class _ModuleEditorDialogState extends State<_ModuleEditorDialog> {
  static const _repository = SupabaseAcademyRepository();
  final _picker = ImagePicker();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _orderController;
  late final TextEditingController _passingScoreController;
  late final TextEditingController _durationController;
  late final TextEditingController _imageNameController;
  late final TextEditingController _freeTopicLimitController;
  late final TextEditingController _subscriptionPriceController;
  late bool _isPublished;
  late bool _isLocked;
  late bool _requiresSubscription;
  bool _isSequential = false;
  String _moduleLevel = 'Boshlang‘ich';
  String _existingCoverUrl = '';
  Uint8List? _selectedModuleImageBytes;
  String? _selectedModuleImageExtension;
  bool _pickingImage = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.module?.title ?? '');
    _descriptionController = TextEditingController(
      text: widget.module?.description ?? '',
    );
    _orderController = TextEditingController(
      text: widget.module?.orderIndex.toString() ?? '1',
    );
    _passingScoreController = TextEditingController(
      text: widget.module?.passingScore.toString() ?? '70',
    );
    _durationController = TextEditingController(
      text: widget.module?.durationLabel.trim().isNotEmpty == true
          ? widget.module!.durationLabel
          : '00:00',
    );
    _existingCoverUrl = widget.module?.coverUrl ?? '';
    _imageNameController = TextEditingController(
      text: _existingCoverUrl.isEmpty
          ? ''
          : _extractFileName(_existingCoverUrl),
    );
    _freeTopicLimitController = TextEditingController(
      text: widget.module?.freeTopicLimit.toString() ?? '1',
    );
    _subscriptionPriceController = TextEditingController(
      text: widget.module?.subscriptionPriceLabel ?? '',
    );
    _isPublished = widget.module?.isPublished ?? true;
    _isLocked = widget.module?.isLocked ?? false;
    _requiresSubscription = widget.module?.requiresSubscription ?? false;
    _isSequential = widget.module?.isSequential ?? false;
    _moduleLevel = _normalizeModuleLevel(widget.module?.levelLabel ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _orderController.dispose();
    _passingScoreController.dispose();
    _durationController.dispose();
    _imageNameController.dispose();
    _freeTopicLimitController.dispose();
    _subscriptionPriceController.dispose();
    super.dispose();
  }

  String _extractFileName(String value) {
    final clean = value.split('?').first;
    final segments = clean.split('/');
    if (segments.isEmpty) return '';
    return segments.last;
  }

  String _normalizeModuleLevel(String value) {
    switch (value.trim().toLowerCase()) {
      case 'advanced':
      case 'yuqori':
        return 'Yuqori';
      case 'intermediate':
      case 'o‘rta':
      case 'orta':
        return 'O‘rta';
      case 'beginner':
      case 'boshlang‘ich':
      default:
        return 'Boshlang‘ich';
    }
  }

  Future<void> _pickModuleImage() async {
    setState(() => _pickingImage = true);
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery);
      if (picked == null || !mounted) return;

      final extension = picked.name.contains('.')
          ? picked.name.split('.').last.toLowerCase()
          : 'jpg';
      if (!{'png', 'jpg', 'jpeg', 'webp'}.contains(extension)) {
        _showAdminSnack(
          context,
          'Faqat PNG, JPG yoki WEBP fayllar ruxsat etiladi.',
          isError: true,
        );
        return;
      }

      final bytes = await picked.readAsBytes();
      if (bytes.lengthInBytes > 2 * 1024 * 1024) {
        if (!mounted) return;
        _showAdminSnack(
          context,
          'Rasm hajmi 2MB dan oshmasligi kerak.',
          isError: true,
        );
        return;
      }

      setState(() {
        _selectedModuleImageBytes = bytes;
        _selectedModuleImageExtension = extension;
        _imageNameController.text = picked.name;
      });
    } on Object catch (error) {
      if (!mounted) return;
      _showAdminSnack(context, 'Rasm tanlanmadi: $error', isError: true);
    } finally {
      if (mounted) setState(() => _pickingImage = false);
    }
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final orderIndex = int.tryParse(_orderController.text.trim()) ?? 0;
    final passingScore =
        int.tryParse(_passingScoreController.text.trim()) ?? 70;
    if (title.isEmpty ||
        orderIndex <= 0 ||
        passingScore < 1 ||
        passingScore > 100) {
      _showAdminSnack(
        context,
        'Modul nomi, tartib va passing score to‘g‘ri bo‘lishi kerak.',
        isError: true,
      );
      return;
    }
    setState(() => _saving = true);
    try {
      var coverUrl = _existingCoverUrl;
      if (_selectedModuleImageBytes != null &&
          _selectedModuleImageExtension != null) {
        coverUrl = await _repository.uploadModuleCover(
          bytes: _selectedModuleImageBytes!,
          extension: _selectedModuleImageExtension!,
        );
      }
      final freeTopicLimit =
          int.tryParse(_freeTopicLimitController.text.trim()) ?? 1;
      final subscriptionPriceLabel = _subscriptionPriceController.text.trim();

      await _repository.saveModule(
        id: widget.module?.id,
        title: title,
        description: description,
        orderIndex: orderIndex,
        coverUrl: coverUrl,
        levelLabel: _moduleLevel,
        durationLabel: _durationController.text.trim(),
        isPublished: _isPublished,
        isLocked: _isLocked,
        isSequential: _isSequential,
        passingScore: passingScore,
        freeTopicLimit:
            int.tryParse(_freeTopicLimitController.text.trim()) ?? 1,
        requiresSubscription: _requiresSubscription,
        subscriptionPriceLabel: _subscriptionPriceController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on Object catch (error) {
      if (!mounted) return;
      _showAdminSnack(context, error.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980, maxHeight: 860),
        child: AppCard(
          padding: const EdgeInsets.fromLTRB(28, 26, 28, 24),
          child: SingleChildScrollView(
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
                            widget.module == null
                                ? 'Yangi modul'
                                : 'Modulni tahrirlash',
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Laboratoriya kursi uchun yangi modul yarating.',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: AppColors.muted,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                const _DialogSectionLabel(
                  index: 1,
                  title: 'Umumiy ma’lumotlar',
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: _DialogFieldColumn(
                        label: 'Modul nomi',
                        child: TextField(
                          controller: _titleController,
                          decoration: const InputDecoration(
                            hintText: 'Masalan: Biokimyo asoslari',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: _DialogFieldColumn(
                        label: 'Tartib raqami',
                        child: TextField(
                          controller: _orderController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(hintText: '1'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: _DialogFieldColumn(
                        label: 'O‘tish bali (%)',
                        helper:
                            'Talaba moduldan o‘tish uchun zarur minimal ball.',
                        child: TextField(
                          controller: _passingScoreController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(suffixText: '%'),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _DialogFieldColumn(
                  label: 'Modul tavsifi',
                  child: TextField(
                    controller: _descriptionController,
                    minLines: 3,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      hintText: 'Modul haqida qisqacha ma’lumot',
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _DialogFieldColumn(
                        label: 'Bepul mavzu limiti',
                        child: TextField(
                          controller: _freeTopicLimitController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            hintText: 'Masalan: 1',
                            suffixIcon: Icon(Icons.lock_open_rounded),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: _DialogFieldColumn(
                        label: 'Obuna sozlamalari',
                        child: Column(
                          children: [
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Obuna talab qilinadi'),
                              value: _requiresSubscription,
                              onChanged: (value) =>
                                  setState(() => _requiresSubscription = value),
                              activeColor: AppColors.studentPrimary,
                            ),
                            if (_requiresSubscription) ...[
                              const SizedBox(height: 12),
                              TextField(
                                controller: _subscriptionPriceController,
                                decoration: const InputDecoration(
                                  labelText: 'Obuna narxi (label)',
                                  hintText: 'Masalan: 10 USD / oy',
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Divider(color: AppColors.border),
                const SizedBox(height: 18),
                const _DialogSectionLabel(
                  index: 3,
                  title: 'Ko‘rinish va kirish huquqlari',
                ),
                const SizedBox(height: 14),
                _DialogSwitchRow(
                  icon: Icons.visibility_rounded,
                  color: AppColors.successGreen,
                  title: 'Student ilovasida ko‘rinsin',
                  subtitle:
                      'Ushbu modul talabalar ilovasida ko‘rinadi va ularga mavjud bo‘ladi.',
                  value: _isPublished,
                  onChanged: (value) => setState(() => _isPublished = value),
                ),
                const SizedBox(height: 14),
                _DialogSwitchRow(
                  icon: Icons.lock_outline_rounded,
                  color: AppColors.amber,
                  title: 'Keyingi modul boshida yopiq bo‘lsin',
                  subtitle:
                      'Ushbu modul avtomatik ochilmaydi. Oldingi modul tugagandan so‘ng ochiladi.',
                  value: _isLocked,
                  onChanged: (value) => setState(() => _isLocked = value),
                ),
                const SizedBox(height: 14),
                _DialogSwitchRow(
                  icon: Icons.hub_rounded,
                  color: AppColors.violet,
                  title: 'Ketma-ket o‘qish tizimi yoqilsin',
                  subtitle:
                      'Talabalar modullarni belgilangan tartibda ketma-ket o‘qishadi.',
                  value: _isSequential,
                  onChanged: (value) => setState(() => _isSequential = value),
                ),
                const SizedBox(height: 18),
                const Divider(color: AppColors.border),
                const SizedBox(height: 18),
                const _DialogSectionLabel(
                  index: 4,
                  title: 'Qo‘shimcha sozlamalar',
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _DialogFieldColumn(
                        label: 'Modul rasmi (ixtiyoriy)',
                        child: InkWell(
                          onTap: _saving || _pickingImage
                              ? null
                              : _pickModuleImage,
                          borderRadius: BorderRadius.circular(18),
                          child: Ink(
                            height: 132,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: AppColors.border,
                                style: BorderStyle.solid,
                              ),
                            ),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_selectedModuleImageBytes != null)
                                    Container(
                                      width: 68,
                                      height: 68,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(18),
                                        image: DecorationImage(
                                          image: MemoryImage(
                                            _selectedModuleImageBytes!,
                                          ),
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    )
                                  else if (_existingCoverUrl.trim().isNotEmpty)
                                    Container(
                                      width: 68,
                                      height: 68,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(18),
                                        image: DecorationImage(
                                          image: NetworkImage(
                                            _existingCoverUrl,
                                          ),
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    )
                                  else
                                    const IconBadge(
                                      icon: Icons.cloud_upload_rounded,
                                      color: AppColors.primaryBlue,
                                      size: 54,
                                    ),
                                  const SizedBox(height: 10),
                                  Text(
                                    _pickingImage
                                        ? 'Rasm tanlanmoqda...'
                                        : _imageNameController.text.isEmpty
                                        ? 'Rasm yuklash uchun bosing'
                                        : _imageNameController.text,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleSmall,
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'PNG, JPG yoki WEBP (maks. 2MB)',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: _DialogFieldColumn(
                        label: 'Modul darajasi',
                        helper: 'Modulning qiyinchilik darajasini tanlang.',
                        child: _AdminSelectField<String>(
                          value: _moduleLevel,
                          label: 'Daraja',
                          options: const [
                            _AdminSelectOption<String>(
                              value: 'Boshlang‘ich',
                              label: 'Boshlang‘ich',
                              icon: Icons.school_rounded,
                              color: AppColors.successGreen,
                            ),
                            _AdminSelectOption<String>(
                              value: 'O‘rta',
                              label: 'O‘rta',
                              icon: Icons.tune_rounded,
                              color: AppColors.amber,
                            ),
                            _AdminSelectOption<String>(
                              value: 'Yuqori',
                              label: 'Yuqori',
                              icon: Icons.local_fire_department_rounded,
                              color: AppColors.errorRed,
                            ),
                          ],
                          onChanged: (value) =>
                              setState(() => _moduleLevel = value),
                        ),
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: _DialogFieldColumn(
                        label: 'Modul davomiyligi (ixtiyoriy)',
                        helper: 'Soat:daqiqada ko‘rinishida (masalan: 02:30)',
                        child: TextField(
                          controller: _durationController,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.schedule_rounded),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(120, 52),
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                      ),
                      child: const Text('Bekor qilish'),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(152, 52),
                        padding: const EdgeInsets.symmetric(horizontal: 22),
                      ),
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(_saving ? 'Saqlanmoqda...' : 'Saqlash'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModulePreviewDialog extends StatelessWidget {
  const _ModulePreviewDialog({required this.module});

  final AdminModuleSummary module;

  @override
  Widget build(BuildContext context) {
    final status = !module.isPublished
        ? ('Qoralama', AppColors.amber, Icons.edit_note_rounded)
        : module.isLocked
        ? ('Yopilgan', AppColors.errorRed, Icons.lock_outline_rounded)
        : ('Nashr etilgan', AppColors.successGreen, Icons.check_circle_rounded);
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 80, vertical: 40),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: AppCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _AdminModuleCoverThumb(module: module, width: 68, height: 68),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          module.title,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 6),
                        StatusChip(
                          label: status.$1,
                          color: status.$2,
                          icon: status.$3,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                module.description.trim().isEmpty
                    ? 'Qisqacha tavsif kiritilmagan'
                    : module.description,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: _DialogMetricCard(
                      title: 'Tartib',
                      value: module.orderIndex.toString(),
                      color: AppColors.primaryBlue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DialogMetricCard(
                      title: 'Mavzular',
                      value: module.topicCount.toString(),
                      color: AppColors.violet,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DialogMetricCard(
                      title: 'Talabalar',
                      value: module.studentCount.toString(),
                      color: AppColors.successGreen,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DialogMetricCard(
                      title: 'O‘tish bali',
                      value: '${module.passingScore}%',
                      color: AppColors.amber,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Yakunlash progressi',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ProgressLine(
                value: module.completionRate,
                height: 8,
                color: module.completionRate >= 0.7
                    ? AppColors.successGreen
                    : AppColors.primaryBlue,
              ),
              const SizedBox(height: 8),
              Text(
                '${(module.completionRate * 100).round()}%',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.primaryBlue,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DialogSectionLabel extends StatelessWidget {
  const _DialogSectionLabel({required this.index, required this.title});

  final int index;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: AppColors.primaryBlue,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '$index. $title',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _DialogFieldColumn extends StatelessWidget {
  const _DialogFieldColumn({
    required this.label,
    required this.child,
    this.helper,
  });

  final String label;
  final Widget child;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        child,
        if (helper != null) ...[
          const SizedBox(height: 8),
          Text(helper!, style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
    );
  }
}

class _DialogSwitchRow extends StatelessWidget {
  const _DialogSwitchRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconBadge(icon: icon, color: color, size: 42),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}

class _DialogMetricCard extends StatelessWidget {
  const _DialogMetricCard({
    required this.title,
    required this.value,
    required this.color,
  });

  final String title;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: color.withValues(alpha: .08),
        border: Border.all(color: color.withValues(alpha: .14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              color: AppColors.navy,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopicEditorDialog extends StatefulWidget {
  const _TopicEditorDialog({
    this.topic,
    required this.modules,
    required this.topics,
  });

  final AdminTopicSummary? topic;
  final List<AdminModuleSummary> modules;
  final List<AdminTopicSummary> topics;

  @override
  State<_TopicEditorDialog> createState() => _TopicEditorDialogState();
}

class _TopicEditorDialogState extends State<_TopicEditorDialog> {
  static const _repository = SupabaseAcademyRepository();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _orderController;
  late final TextEditingController _estimatedDurationController;
  late String _moduleId;
  late String _status;
  late String _visibility;
  late String _unlockMode;
  late int _durationMinutes;
  _TopicFileDraft? _topicImage;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _moduleId =
        widget.topic?.moduleId ??
        (widget.modules.isNotEmpty ? widget.modules.first.id : '');
    _titleController = TextEditingController(text: widget.topic?.title ?? '');
    _descriptionController = TextEditingController(
      text: widget.topic?.description ?? '',
    )..addListener(() => setState(() {}));
    _orderController = TextEditingController(
      text:
          widget.topic?.orderIndex.toString() ??
          _nextOrderForModule(_moduleId).toString(),
    );
    final initialDurationSeconds = widget.topic?.durationSeconds ?? 0;
    _durationMinutes = initialDurationSeconds > 0
        ? (initialDurationSeconds / 60).round().clamp(5, 720).toInt()
        : 30;
    _estimatedDurationController = TextEditingController(
      text: _formatTopicDurationInput(_durationMinutes),
    );
    _status = (widget.topic?.isPublished ?? true) ? 'published' : 'draft';
    _visibility = 'all';
    _unlockMode = 'automatic';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _orderController.dispose();
    _estimatedDurationController.dispose();
    super.dispose();
  }

  int _nextOrderForModule(String moduleId) {
    if (moduleId.isEmpty) return 1;
    final moduleTopics = widget.topics.where((topic) {
      if (topic.id == widget.topic?.id) return false;
      return topic.moduleId == moduleId;
    });
    if (moduleTopics.isEmpty) return 1;
    return moduleTopics
            .map((topic) => topic.orderIndex)
            .reduce((a, b) => a > b ? a : b) +
        1;
  }

  void _changeModule(String? value) {
    if (value == null || value == _moduleId) return;
    setState(() {
      _moduleId = value;
      if (widget.topic == null) {
        _orderController.text = _nextOrderForModule(value).toString();
      }
    });
  }

  void _setDurationMinutes(int minutes) {
    final normalized = minutes.clamp(5, 720).toInt();
    setState(() {
      _durationMinutes = normalized;
      _estimatedDurationController.text = _formatTopicDurationInput(normalized);
    });
  }

  Future<void> _pickTopicImage() async {
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 86,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (bytes.length > 2 * 1024 * 1024) {
        if (!mounted) return;
        _showAdminSnack(
          context,
          'Rasm hajmi 2MB dan oshmasligi kerak. Tavsiya: 1280×720 px.',
          isError: true,
        );
        return;
      }
      setState(() {
        _topicImage = _TopicFileDraft(
          bytes: bytes,
          name: image.name,
          extension: _extensionFromPickedName(image.name).isEmpty
              ? 'jpg'
              : _extensionFromPickedName(image.name),
          size: bytes.length,
        );
      });
    } on Object catch (error) {
      debugPrint('Topic image pick failed: $error');
      if (!mounted) return;
      _showAdminSnack(
        context,
        'Rasm tanlanmadi. Brauzer ruxsatini tekshirib qayta urinib ko‘ring.',
        isError: true,
      );
    }
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final orderIndex = int.tryParse(_orderController.text.trim()) ?? 0;
    if (title.isEmpty || _moduleId.isEmpty || orderIndex <= 0) {
      _showAdminSnack(
        context,
        'Modul, mavzu nomi va tartib raqamini to‘g‘ri kiriting.',
        isError: true,
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final description = _descriptionController.text.trim();
      var coverUrl = widget.topic?.coverUrl ?? '';
      if (_topicImage != null) {
        coverUrl = await _repository.uploadTopicCover(
          bytes: _topicImage!.bytes,
          extension: _topicImage!.extension,
        );
      }
      await _repository.saveTopic(
        id: widget.topic?.id,
        moduleId: _moduleId,
        title: title,
        description: description,
        orderIndex: orderIndex,
        isPublished: _status == 'published',
        durationSeconds: _durationMinutes * 60,
        coverUrl: coverUrl,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on Object catch (error) {
      if (!mounted) return;
      _showAdminSnack(context, error.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.topic == null ? 'Yangi mavzu' : 'Mavzuni tahrirlash';
    final width = MediaQuery.sizeOf(context).width;
    final height = MediaQuery.sizeOf(context).height;
    final dialogWidth = width < 760
        ? width - 24
        : width < 1180
        ? width - 80
        : 1060.0;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: dialogWidth,
          maxHeight: height * .92,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 22, 20, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconBadge(
                    icon: Icons.menu_book_rounded,
                    color: AppColors.primaryBlue,
                    size: 54,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Modul ichiga yangi mavzu qo‘shing',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'Yopish',
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 20, 28, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _TopicFormSectionTitle(
                      number: 1,
                      title: 'Asosiy ma’lumotlar',
                    ),
                    const SizedBox(height: 14),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final twoColumns = constraints.maxWidth >= 720;
                        final moduleField = _AdminSelectField<String>(
                          label: 'Modul',
                          value: _moduleId.isEmpty ? null : _moduleId,
                          hintText: 'Modulni tanlang',
                          enabled: !_saving,
                          options: widget.modules
                              .map(
                                (module) => _AdminSelectOption(
                                  value: module.id,
                                  label: module.title,
                                  icon: _moduleIconForOrder(module.orderIndex),
                                  color: _moduleColorForOrder(
                                    module.orderIndex,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: _changeModule,
                        );
                        final titleField = TextField(
                          controller: _titleController,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Mavzu nomi *',
                            hintText: 'Mavzu nomini kiriting',
                            suffixIcon: Icon(Icons.menu_book_outlined),
                          ),
                        );
                        if (!twoColumns) {
                          return Column(
                            children: [
                              moduleField,
                              const SizedBox(height: 12),
                              titleField,
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(child: moduleField),
                            const SizedBox(width: 18),
                            Expanded(child: titleField),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _descriptionController,
                      maxLines: 4,
                      maxLength: 500,
                      decoration: const InputDecoration(
                        labelText: 'Qisqacha tavsif',
                        hintText: 'Mavzu haqida qisqacha ma’lumot yozing...',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Divider(height: 1),
                    const SizedBox(height: 18),
                    const _TopicFormSectionTitle(
                      number: 2,
                      title: 'Qo‘shimcha ma’lumotlar',
                    ),
                    const SizedBox(height: 14),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final threeColumns = constraints.maxWidth >= 860;
                        final fieldWidth = threeColumns
                            ? (constraints.maxWidth - 28) / 3
                            : constraints.maxWidth;
                        return Wrap(
                          spacing: 14,
                          runSpacing: 14,
                          crossAxisAlignment: WrapCrossAlignment.start,
                          children: [
                            SizedBox(
                              width: fieldWidth,
                              child: TextField(
                                controller: _orderController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Tartib raqami *',
                                  hintText: 'Masalan: 1',
                                  helperText:
                                      'Mavzular tartib raqamiga ko‘ra joylashadi',
                                ),
                              ),
                            ),
                            SizedBox(
                              width: fieldWidth,
                              child: _TopicDurationStepper(
                                minutes: _durationMinutes,
                                onChanged: _setDurationMinutes,
                              ),
                            ),
                            SizedBox(
                              width: fieldWidth,
                              child: _TopicImageUploadBox(
                                file: _topicImage,
                                onPick: _pickTopicImage,
                                onClear: _topicImage == null
                                    ? null
                                    : () => setState(() => _topicImage = null),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 18),
                    const Divider(height: 1),
                    const SizedBox(height: 18),
                    const _TopicFormSectionTitle(
                      number: 3,
                      title: 'Sozlamalar',
                    ),
                    const SizedBox(height: 14),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = constraints.maxWidth >= 760 ? 3 : 1;
                        final fieldWidth =
                            (constraints.maxWidth - ((columns - 1) * 14)) /
                            columns;
                        return Wrap(
                          spacing: 14,
                          runSpacing: 14,
                          children: [
                            SizedBox(
                              width: fieldWidth,
                              child: _AdminSelectField<String>(
                                label: 'Mavzu holati *',
                                value: _status,
                                helperText:
                                    'Tanlangan holat rang bilan ajratiladi',
                                options: const [
                                  _AdminSelectOption(
                                    value: 'published',
                                    label: 'Nashr etilgan',
                                    icon: Icons.check_circle_rounded,
                                    color: AppColors.successGreen,
                                    subtitle: 'Student ilovasida ko‘rinadi',
                                  ),
                                  _AdminSelectOption(
                                    value: 'draft',
                                    label: 'Qoralama',
                                    icon: Icons.edit_note_rounded,
                                    color: AppColors.amber,
                                    subtitle: 'Admin panelda tayyorlanadi',
                                  ),
                                ],
                                onChanged: (value) =>
                                    setState(() => _status = value),
                              ),
                            ),
                            SizedBox(
                              width: fieldWidth,
                              child: _AdminSelectField<String>(
                                label: 'Ko‘rinish *',
                                value: _visibility,
                                helperText: 'Kimlarga ko‘rinishini belgilang',
                                options: const [
                                  _AdminSelectOption(
                                    value: 'all',
                                    label: 'Barchaga ko‘rinadi',
                                    icon: Icons.visibility_rounded,
                                    color: AppColors.primaryBlue,
                                    subtitle: 'Studentlar ko‘ra oladi',
                                  ),
                                  _AdminSelectOption(
                                    value: 'admins',
                                    label: 'Faqat adminlar',
                                    icon: Icons.admin_panel_settings_rounded,
                                    color: AppColors.violet,
                                    subtitle: 'Student ilovasida yashiriladi',
                                  ),
                                ],
                                onChanged: (value) =>
                                    setState(() => _visibility = value),
                              ),
                            ),
                            SizedBox(
                              width: fieldWidth,
                              child: _AdminSelectField<String>(
                                label: 'Keyingi mavzuni ochish',
                                value: _unlockMode,
                                helperText:
                                    'Mavzu tugagandan keyin keyingisi ochiladi',
                                options: const [
                                  _AdminSelectOption(
                                    value: 'automatic',
                                    label: 'Avtomatik',
                                    icon: Icons.lock_open_rounded,
                                    color: AppColors.successGreen,
                                    subtitle: 'Flow avtomatik davom etadi',
                                  ),
                                  _AdminSelectOption(
                                    value: 'manual',
                                    label: 'Qo‘lda ochish',
                                    icon: Icons.touch_app_rounded,
                                    color: AppColors.amber,
                                    subtitle: 'Admin tasdiqlagandan keyin',
                                  ),
                                  _AdminSelectOption(
                                    value: 'locked',
                                    label: 'Yopiq turadi',
                                    icon: Icons.lock_rounded,
                                    color: AppColors.errorRed,
                                    subtitle: 'Keyingi mavzu yopiq qoladi',
                                  ),
                                ],
                                onChanged: (value) =>
                                    setState(() => _unlockMode = value),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    _TopicInfoPanel(
                      title: 'Eslatma',
                      body:
                          'Mavzuga PDF/Text, video va testlarni alohida bo‘limlar orqali qo‘shishingiz mumkin. Bu mavzu oynasi faqat mavzu kartasi, tartibi va ko‘rinish qoidalarini boshqaradi.',
                      icon: Icons.info_outline_rounded,
                      color: AppColors.primaryBlue,
                      trailing: 'PDF/Text • Videolar • Testlar',
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 16, 28, 20),
              child: Row(
                children: [
                  OutlinedButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(130, 50),
                    ),
                    child: const Text('Bekor qilish'),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(190, 52),
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                    ),
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_rounded),
                    label: Text(_saving ? 'Saqlanmoqda...' : 'Mavzuni saqlash'),
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

class _TopicFileDraft {
  const _TopicFileDraft({
    required this.bytes,
    required this.name,
    required this.extension,
    required this.size,
  });

  final Uint8List bytes;
  final String name;
  final String extension;
  final int size;
}

String _formatTopicFileSize(int bytes) {
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  if (bytes >= 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  return '$bytes B';
}

String _formatTopicDurationInput(int minutes) {
  final normalized = minutes.clamp(5, 720).toInt();
  final hours = normalized ~/ 60;
  final rest = normalized % 60;
  return '${hours.toString().padLeft(2, '0')}:${rest.toString().padLeft(2, '0')}';
}

String _formatTopicDurationLabel(int minutes) {
  final normalized = minutes.clamp(5, 720).toInt();
  final hours = normalized ~/ 60;
  final rest = normalized % 60;
  if (hours == 0) return '$rest daqiqa';
  if (rest == 0) return '$hours soat';
  return '$hours soat $rest daqiqa';
}

class _TopicDurationStepper extends StatelessWidget {
  const _TopicDurationStepper({required this.minutes, required this.onChanged});

  final int minutes;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBadge(
                icon: Icons.schedule_rounded,
                color: AppColors.cyan,
                size: 38,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Taxminiy davomiylik',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatTopicDurationLabel(minutes),
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _DurationUnitStepper(
                  label: 'Soat',
                  value: hours,
                  onDecrease: () => onChanged(minutes - 60),
                  onIncrease: () => onChanged(minutes + 60),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DurationUnitStepper(
                  label: 'Daqiqa',
                  value: rest,
                  onDecrease: () => onChanged(minutes - 5),
                  onIncrease: () => onChanged(minutes + 5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final quick in const [10, 20, 30, 45, 60, 90])
                ChoiceChip(
                  label: Text(_formatTopicDurationLabel(quick)),
                  selected: minutes == quick,
                  onSelected: (_) => onChanged(quick),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Admin belgilaydi: bu o‘rtacha davomiylik va o‘quv rejasida ishlatiladi.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _DurationUnitStepper extends StatelessWidget {
  const _DurationUnitStepper({
    required this.label,
    required this.value,
    required this.onDecrease,
    required this.onIncrease,
  });

  final String label;
  final int value;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _DurationRoundButton(
            icon: Icons.remove_rounded,
            onPressed: onDecrease,
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  value.toString().padLeft(2, '0'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  label,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
                ),
              ],
            ),
          ),
          _DurationRoundButton(icon: Icons.add_rounded, onPressed: onIncrease),
        ],
      ),
    );
  }
}

class _DurationRoundButton extends StatelessWidget {
  const _DurationRoundButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 30,
      height: 30,
      child: IconButton.filledTonal(
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }
}

class _TopicFormSectionTitle extends StatelessWidget {
  const _TopicFormSectionTitle({required this.number, required this.title});

  final int number;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primaryBlue,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryBlue.withValues(alpha: .22),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Text(
            '$number.',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}

class _TopicInfoPanel extends StatelessWidget {
  const _TopicInfoPanel({
    required this.title,
    required this.body,
    required this.icon,
    required this.color,
    required this.trailing,
  });

  final String title;
  final String body;
  final IconData icon;
  final Color color;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: .18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBadge(icon: icon, color: color, size: 42),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 5),
                Text(
                  body,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
                ),
                const SizedBox(height: 10),
                StatusChip(label: trailing, color: color),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopicUploadCard extends StatelessWidget {
  const _TopicUploadCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.draft,
    required this.linkController,
    required this.linkHint,
    required this.hasExisting,
    required this.onPick,
    required this.onClear,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final _TopicFileDraft? draft;
  final TextEditingController linkController;
  final String linkHint;
  final bool hasExisting;
  final VoidCallback onPick;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final currentDraft = draft;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBadge(icon: icon, color: color, size: 38),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: onPick,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
              decoration: BoxDecoration(
                color: color.withValues(alpha: .04),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: color.withValues(alpha: .32),
                  style: BorderStyle.solid,
                ),
              ),
              child: Column(
                children: [
                  Icon(Icons.cloud_upload_rounded, color: color, size: 30),
                  const SizedBox(height: 8),
                  Text(
                    hasExisting && currentDraft == null
                        ? 'Avvalgi fayl mavjud'
                        : 'Fayl yuklash',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: linkController,
            enabled: currentDraft == null,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: 'Link orqali qo‘shish',
              hintText: linkHint,
              prefixIcon: const Icon(Icons.link_rounded),
              helperText: currentDraft == null
                  ? 'Fayl yuklanmasa, shu link studentga ko‘rinadi.'
                  : 'Fayl tanlangan, link ishlatilmaydi.',
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    currentDraft?.name ??
                        (hasExisting ? 'Mavjud fayl' : 'Fayl tanlanmagan'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (currentDraft != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    _formatTopicFileSize(currentDraft.size),
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
                  ),
                  IconButton(
                    tooltip: 'Faylni olib tashlash',
                    onPressed: onClear,
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopicImageUploadBox extends StatelessWidget {
  const _TopicImageUploadBox({
    required this.file,
    required this.onPick,
    required this.onClear,
  });

  final _TopicFileDraft? file;
  final VoidCallback onPick;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final currentFile = file;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mavzu rasmi (ixtiyoriy)',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: AppColors.navy,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: onPick,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: 104,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.border,
                style: BorderStyle.solid,
              ),
              color: const Color(0xFFF8FAFC),
            ),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: currentFile == null
                      ? Icon(
                          Icons.cloud_upload_rounded,
                          color: AppColors.primaryBlue,
                          size: 30,
                        )
                      : Image.memory(currentFile.bytes, fit: BoxFit.cover),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentFile?.name ?? 'Rasm yuklash',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        currentFile == null
                            ? 'PNG/JPG/WEBP • 1280×720 px tavsiya • maks. 2MB'
                            : _formatTopicFileSize(currentFile.size),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                if (currentFile != null)
                  IconButton(
                    tooltip: 'Rasmni olib tashlash',
                    onPressed: onClear,
                    icon: const Icon(Icons.close_rounded),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TopicCheckOption extends StatelessWidget {
  const _TopicCheckOption({
    required this.value,
    required this.label,
    required this.onChanged,
  });

  final bool value;
  final String label;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Checkbox(
              value: value,
              onChanged: (checked) => onChanged(checked ?? false),
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.info_outline_rounded,
              size: 16,
              color: AppColors.muted,
            ),
          ],
        ),
      ),
    );
  }
}

class _TopicAccessCard extends StatelessWidget {
  const _TopicAccessCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBadge(icon: icon, color: color, size: 38),
          const SizedBox(height: 12),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _LessonEditorDialog extends StatefulWidget {
  const _LessonEditorDialog({
    this.lesson,
    required this.topics,
    required this.videoOnly,
  });

  final AdminLessonSummary? lesson;
  final List<AdminTopicSummary> topics;
  final bool videoOnly;

  @override
  State<_LessonEditorDialog> createState() => _LessonEditorDialogState();
}

class _LessonEditorDialogState extends State<_LessonEditorDialog> {
  static const _repository = SupabaseAcademyRepository();
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  late final TextEditingController _fileUrlController;
  late final TextEditingController _durationController;
  late final TextEditingController _orderController;
  late String _topicId;
  late String _kind;
  String _videoCategory = 'nazariy';
  _TopicFileDraft? _lessonFile;
  bool _saving = false;
  String? _fileError;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.lesson?.title ?? '');
    _bodyController = TextEditingController(text: widget.lesson?.body ?? '');
    _fileUrlController = TextEditingController(
      text: widget.lesson?.fileUrl ?? '',
    );
    _durationController = TextEditingController(
      text:
          widget.lesson?.durationSeconds.toString() ??
          (widget.videoOnly ? '0' : '0'),
    );
    _orderController = TextEditingController(
      text: widget.lesson?.orderIndex.toString() ?? '1',
    );
    _topicId =
        widget.lesson?.topicId ??
        (widget.topics.isNotEmpty ? widget.topics.first.id : '');
    _kind = widget.lesson?.kind ?? (widget.videoOnly ? 'video' : 'pdf');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _fileUrlController.dispose();
    _durationController.dispose();
    _orderController.dispose();
    super.dispose();
  }

  List<String> get _lessonFileExtensions {
    if (widget.videoOnly) return const ['mp4', 'webm', 'mov'];
    if (_kind == 'text') return const ['txt', 'doc', 'docx', 'pdf'];
    return const ['pdf', 'doc', 'docx', 'txt'];
  }

  Future<void> _pickLessonFile() async {
    setState(() => _fileError = null);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowMultiple: false,
        withData: true,
        allowedExtensions: _lessonFileExtensions,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.single;
      if (file.bytes == null) {
        setState(() => _fileError = 'Faylni o‘qib bo‘lmadi.');
        return;
      }
      setState(() {
        _lessonFile = _TopicFileDraft(
          bytes: file.bytes!,
          name: file.name,
          extension: (file.extension ?? _extensionFromPickedName(file.name))
              .toLowerCase(),
          size: file.size,
        );
        _fileUrlController.clear();
      });
    } on Object catch (error) {
      debugPrint('Lesson file pick failed: $error');
      if (!mounted) return;
      setState(
        () => _fileError =
            'Fayl tanlanmadi. Fayl turini yoki brauzer ruxsatini tekshirib qayta urinib ko‘ring.',
      );
    }
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final orderIndex = int.tryParse(_orderController.text.trim()) ?? 0;
    final durationSeconds = int.tryParse(_durationController.text.trim()) ?? 0;
    final enteredUrl = _fileUrlController.text.trim();
    if (title.isEmpty || _topicId.isEmpty || orderIndex <= 0) {
      _showAdminSnack(
        context,
        'Mavzu, sarlavha va tartibni to‘g‘ri kiriting.',
        isError: true,
      );
      return;
    }
    if (_lessonFile == null &&
        enteredUrl.isNotEmpty &&
        !_isValidAdminUrl(enteredUrl)) {
      _showAdminSnack(
        context,
        'Link http yoki https bilan boshlanishi kerak.',
        isError: true,
      );
      return;
    }
    setState(() => _saving = true);
    try {
      var fileUrl = enteredUrl;
      if (_lessonFile != null) {
        fileUrl = await _repository.uploadChatAttachment(
          bytes: _lessonFile!.bytes,
          extension: _lessonFile!.extension,
          fileName: _lessonFile!.name,
          kind: _kind == 'video'
              ? 'video'
              : _kind == 'pdf'
              ? 'pdf'
              : 'text',
        );
      }
      await _repository.saveLesson(
        id: widget.lesson?.id,
        topicId: _topicId,
        kind: _kind,
        title: title,
        body: _bodyController.text,
        fileUrl: fileUrl,
        durationSeconds: durationSeconds,
        orderIndex: orderIndex,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on Object catch (error) {
      if (!mounted) return;
      _showAdminSnack(context, error.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _topicDropdown() {
    return _AdminSelectField<String>(
      value: _topicId.isEmpty ? null : _topicId,
      label: 'Mavzu *',
      hintText: 'Mavzuni tanlang',
      options: widget.topics
          .map(
            (topic) => _AdminSelectOption<String>(
              value: topic.id,
              label: topic.title,
              subtitle: topic.moduleTitle,
              icon: Icons.menu_book_rounded,
              color: AppColors.primaryBlue,
            ),
          )
          .toList(),
      onChanged: (value) => setState(() => _topicId = value),
    );
  }

  Widget _sourceCard({required bool compact}) {
    return _TopicUploadCard(
      title: widget.videoOnly ? 'Video manbai' : 'Material fayli',
      subtitle: widget.videoOnly
          ? 'MP4, WebM, MOV yoki YouTube embed link'
          : 'PDF, DOCX, TXT yoki tashqi link',
      icon: widget.videoOnly
          ? Icons.play_circle_rounded
          : Icons.picture_as_pdf_rounded,
      color: widget.videoOnly ? AppColors.violet : AppColors.errorRed,
      draft: _lessonFile,
      linkController: _fileUrlController,
      linkHint: widget.videoOnly
          ? 'YouTube embed, video URL yoki stream link'
          : 'PDF/Text tashqi linki',
      hasExisting: (widget.lesson?.fileUrl.trim().isNotEmpty ?? false),
      onPick: _pickLessonFile,
      onClear: _lessonFile == null
          ? null
          : () => setState(() => _lessonFile = null),
    );
  }

  Widget _stepHeader(List<String> labels) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Wrap(
          spacing: 12,
          runSpacing: 10,
          children: labels.asMap().entries.map((entry) {
            return Container(
              width: constraints.maxWidth >= 900
                  ? (constraints.maxWidth - 36) / 4
                  : null,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: entry.key == 0
                    ? AppColors.primaryBlue.withValues(alpha: .08)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: entry.key == 0
                      ? AppColors.primaryBlue.withValues(alpha: .35)
                      : AppColors.border,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 15,
                    backgroundColor: entry.key == 0
                        ? AppColors.primaryBlue
                        : const Color(0xFFE2E8F0),
                    child: Text(
                      '${entry.key + 1}',
                      style: TextStyle(
                        color: entry.key == 0 ? Colors.white : AppColors.navy,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      entry.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _settingsCard({required bool video}) {
    final options = video
        ? const [
            'Student davom ettirib ko‘ra olsin',
            'Keyingi dars avtomatik ochilsin',
            'Subtitle qo‘llab-quvvatlash',
            'Yuklab olishga ruxsat berilmasin',
          ]
        : const [
            'Barchaga ko‘rinadi',
            'Dars ketma-ketlikka bog‘lansin',
            'Yuklab olishga ruxsat berilsin',
          ];
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            video ? '3. Qo‘shimcha sozlamalar' : '3. Qo‘shimcha sozlamalar',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          ...options.map(
            (label) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 18,
                    color: AppColors.successGreen,
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(label)),
                  Switch(
                    value: true,
                    onChanged: (_) => _showAdminSnack(
                      context,
                      'Bu sozlama oldingi bosqichda boshqariladi.',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _durationController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: video ? 'Davomiylik (sekund)' : 'Davomiylik',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _orderController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Tartib'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _reviewCard({required bool video}) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            video ? '4. Ko‘rib chiqish' : 'Material preview',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 14),
          Container(
            height: video ? 150 : 120,
            width: double.infinity,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(
              video
                  ? Icons.play_circle_fill_rounded
                  : Icons.description_rounded,
              size: 54,
              color: AppColors.primaryBlue.withValues(alpha: .7),
            ),
          ),
          const SizedBox(height: 14),
          _ReviewLine(label: 'Nomi', value: _titleController.text.trim()),
          _ReviewLine(
            label: 'Turi',
            value: video ? 'Video dars' : _kind.toUpperCase(),
          ),
          _ReviewLine(
            label: 'Manba',
            value:
                _lessonFile?.name ??
                (_fileUrlController.text.trim().isEmpty
                    ? 'Tanlanmagan'
                    : 'Link biriktirilgan'),
          ),
          const SizedBox(height: 12),
          _TopicInfoPanel(
            title: 'Tekshiruv ro‘yxati',
            body:
                'Mavzu, nom, manba va tartib to‘ldirilgandan keyin nashr qilish mumkin.',
            icon: Icons.fact_check_rounded,
            color: AppColors.successGreen,
            trailing: 'Metadata • Manba • Sozlamalar',
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final height = MediaQuery.sizeOf(context).height;
    final dialogWidth = widget.videoOnly
        ? (width < 1280 ? width - 36 : 1240.0)
        : (width < 1080 ? width - 36 : 1020.0);
    final headerTitle = widget.videoOnly
        ? (widget.lesson == null
              ? 'Yangi video qo‘shish'
              : 'Videoni tahrirlash')
        : (widget.lesson == null
              ? 'Yangi PDF / Text material qo‘shish'
              : 'Materialni tahrirlash');
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: dialogWidth,
          maxHeight: height * .92,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 18, 14),
              child: Row(
                children: [
                  IconBadge(
                    icon: widget.videoOnly
                        ? Icons.play_circle_rounded
                        : Icons.description_rounded,
                    color: widget.videoOnly
                        ? AppColors.violet
                        : AppColors.primaryBlue,
                    size: 54,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          headerTitle,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.videoOnly
                              ? 'Video yaratish jarayoni 4 bosqichdan iborat.'
                              : 'PDF, matn yoki tashqi link orqali material qo‘shing.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    if (widget.videoOnly) ...[
                      _stepHeader(const [
                        'Asosiy ma’lumotlar',
                        'Video manbai',
                        'Qo‘shimcha sozlamalar',
                        'Ko‘rib chiqish',
                      ]),
                      const SizedBox(height: 16),
                    ],
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final twoColumns = constraints.maxWidth >= 920;
                        final left = AppCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '1. Asosiy ma’lumotlar',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 12),
                              _topicDropdown(),
                              const SizedBox(height: 12),
                              if (!widget.videoOnly) ...[
                                _AdminSelectField<String>(
                                  value: _kind,
                                  label: 'Material turi *',
                                  options: const [
                                    _AdminSelectOption<String>(
                                      value: 'pdf',
                                      label: 'PDF fayl',
                                      subtitle: 'PDF hujjat yuklash',
                                      icon: Icons.picture_as_pdf_rounded,
                                      color: AppColors.errorRed,
                                    ),
                                    _AdminSelectOption<String>(
                                      value: 'text',
                                      label: 'Matn (Text)',
                                      subtitle: 'Rich text material',
                                      icon: Icons.article_rounded,
                                      color: AppColors.primaryBlue,
                                    ),
                                    _AdminSelectOption<String>(
                                      value: 'external_pdf',
                                      label: 'External PDF',
                                      subtitle:
                                          'Tashqi PDF URL ilova ichida render bo‘ladi',
                                      icon: Icons.picture_as_pdf_outlined,
                                      color: AppColors.amber,
                                    ),
                                    _AdminSelectOption<String>(
                                      value: 'link',
                                      label: 'Qo‘shimcha link',
                                      subtitle:
                                          'Materiallar bo‘limida ko‘rinadi',
                                      icon: Icons.link_rounded,
                                      color: AppColors.violet,
                                    ),
                                  ],
                                  onChanged: (value) =>
                                      setState(() => _kind = value),
                                ),
                                const SizedBox(height: 12),
                              ],
                              TextField(
                                controller: _titleController,
                                onChanged: (_) => setState(() {}),
                                decoration: InputDecoration(
                                  labelText: widget.videoOnly
                                      ? 'Video nomi *'
                                      : 'Material nomi *',
                                  hintText: widget.videoOnly
                                      ? 'Masalan: Siydikning fizik xossalari haqida'
                                      : 'Masalan: Siydikning fizik xossalari haqida',
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _bodyController,
                                onChanged: (_) => setState(() {}),
                                maxLines: widget.videoOnly ? 4 : 5,
                                maxLength: 500,
                                decoration: InputDecoration(
                                  labelText: widget.videoOnly
                                      ? 'Qisqacha tavsif'
                                      : 'Qisqacha tavsif',
                                  hintText:
                                      'Material haqida qisqacha ma’lumot yozing...',
                                  alignLabelWithHint: true,
                                ),
                              ),
                              if (widget.videoOnly) ...[
                                const SizedBox(height: 8),
                                _AdminSelectField<String>(
                                  value: _videoCategory,
                                  label: 'Kategoriya',
                                  options: const [
                                    _AdminSelectOption<String>(
                                      value: 'nazariy',
                                      label: 'Nazariy',
                                      subtitle: 'Tushuntirish videosi',
                                      icon: Icons.menu_book_rounded,
                                      color: AppColors.primaryBlue,
                                    ),
                                    _AdminSelectOption<String>(
                                      value: 'amaliy',
                                      label: 'Amaliy',
                                      subtitle: 'Amaliy ko‘rsatma',
                                      icon: Icons.task_alt_rounded,
                                      color: AppColors.successGreen,
                                    ),
                                    _AdminSelectOption<String>(
                                      value: 'laboratoriya',
                                      label: 'Laboratoriya',
                                      subtitle:
                                          'Tajriba va laboratoriya jarayoni',
                                      icon: Icons.biotech_rounded,
                                      color: AppColors.violet,
                                    ),
                                  ],
                                  onChanged: (value) =>
                                      setState(() => _videoCategory = value),
                                ),
                              ],
                            ],
                          ),
                        );
                        final source = AppCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.videoOnly
                                    ? '2. Video manbai'
                                    : '2. Material turi va fayl',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 12),
                              _sourceCard(compact: !twoColumns),
                              if (_fileError != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  _fileError!,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: AppColors.errorRed,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ],
                              if (widget.videoOnly) ...[
                                const SizedBox(height: 12),
                                _TopicInfoPanel(
                                  title: 'YouTube link qo‘llab-quvvatlanadi',
                                  body:
                                      'YouTube havola qo‘shilsa, student ilovasida embedded player orqali ochiladi va YouTube saytiga olib chiqmaydi.',
                                  icon: Icons.smart_display_rounded,
                                  color: AppColors.errorRed,
                                  trailing: 'Embed player',
                                ),
                              ],
                            ],
                          ),
                        );
                        final settings = _settingsCard(video: widget.videoOnly);
                        final review = _reviewCard(video: widget.videoOnly);
                        if (!twoColumns) {
                          return Column(
                            children: [
                              left,
                              const SizedBox(height: 14),
                              source,
                              const SizedBox(height: 14),
                              settings,
                              const SizedBox(height: 14),
                              review,
                            ],
                          );
                        }
                        return Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: left),
                                const SizedBox(width: 16),
                                Expanded(child: source),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: settings),
                                const SizedBox(width: 16),
                                Expanded(child: review),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 18),
              child: Row(
                children: [
                  OutlinedButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Bekor qilish'),
                  ),
                  const Spacer(),
                  if (widget.videoOnly) ...[
                    OutlinedButton(
                      onPressed: _saving ? null : _save,
                      child: const Text('Qoralama saqlash'),
                    ),
                    const SizedBox(width: 12),
                  ],
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            widget.videoOnly
                                ? Icons.send_rounded
                                : Icons.save_rounded,
                          ),
                    label: Text(
                      _saving
                          ? 'Saqlanmoqda...'
                          : (widget.videoOnly ? 'Nashr qilish' : 'Saqlash'),
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

class _ReviewLine extends StatelessWidget {
  const _ReviewLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
            ),
          ),
          Expanded(
            child: Text(
              value.trim().isEmpty ? '-' : value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionEditorDialog extends StatefulWidget {
  const _QuestionEditorDialog({
    this.question,
    required this.modules,
    required this.topics,
    required this.finalExamOnly,
  });

  final AdminQuestionSummary? question;
  final List<AdminModuleSummary> modules;
  final List<AdminTopicSummary> topics;
  final bool finalExamOnly;

  @override
  State<_QuestionEditorDialog> createState() => _QuestionEditorDialogState();
}

class _QuestionEditorDialogState extends State<_QuestionEditorDialog> {
  static const _repository = SupabaseAcademyRepository();
  late final TextEditingController _quizTitleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _questionController;
  late final TextEditingController _optionAController;
  late final TextEditingController _optionBController;
  late final TextEditingController _optionCController;
  late final TextEditingController _optionDController;
  late final TextEditingController _mediaUrlController;
  late final TextEditingController _explanationController;
  late final TextEditingController _pointsController;
  late final TextEditingController _durationController;
  late final TextEditingController _passScoreController;
  late final TextEditingController _attemptsController;
  late final TextEditingController _tagsController;
  late final TextEditingController _importController;
  late String _scopeId;
  late String _difficulty;
  late String _correctOption;
  late String _questionType;
  bool _shuffleQuestions = true;
  bool _shuffleAnswers = true;
  bool _showResult = true;
  bool _allowBack = false;
  bool _showExplanations = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _quizTitleController = TextEditingController(
      text: widget.finalExamOnly ? 'Yakuniy imtihon' : 'Mavzu testi',
    );
    _descriptionController = TextEditingController();
    _questionController = TextEditingController(
      text: widget.question?.question ?? '',
    );
    _optionAController = TextEditingController(
      text: widget.question?.optionA ?? '',
    );
    _optionBController = TextEditingController(
      text: widget.question?.optionB ?? '',
    );
    _optionCController = TextEditingController(
      text: widget.question?.optionC ?? '',
    );
    _optionDController = TextEditingController(
      text: widget.question?.optionD ?? '',
    );
    _mediaUrlController = TextEditingController(
      text: widget.question?.mediaUrl ?? '',
    );
    _explanationController = TextEditingController(
      text: widget.question?.explanation ?? '',
    );
    _pointsController = TextEditingController(
      text: widget.question?.points.toString() ?? '1',
    );
    _durationController = TextEditingController(
      text: widget.finalExamOnly ? '90' : '30',
    );
    _passScoreController = TextEditingController(text: '70');
    _attemptsController = TextEditingController(text: '2');
    _tagsController = TextEditingController();
    _importController = TextEditingController();
    _scopeId =
        widget.question?.scopeId ??
        (widget.finalExamOnly
            ? (widget.modules.isNotEmpty ? widget.modules.first.id : '')
            : (widget.topics.isNotEmpty ? widget.topics.first.id : ''));
    _questionType = widget.question?.questionType ?? 'text';
    _correctOption = widget.question?.correctOption ?? 'a';
    _questionType = widget.question?.questionType ?? 'text';
  }

  @override
  void dispose() {
    _quizTitleController.dispose();
    _descriptionController.dispose();
    _questionController.dispose();
    _optionAController.dispose();
    _optionBController.dispose();
    _optionCController.dispose();
    _optionDController.dispose();
    _mediaUrlController.dispose();
    _explanationController.dispose();
    _pointsController.dispose();
    _durationController.dispose();
    _passScoreController.dispose();
    _attemptsController.dispose();
    _tagsController.dispose();
    _importController.dispose();
    super.dispose();
  }

  List<_AdminSelectOption<String>> get _scopeOptions {
    if (widget.finalExamOnly) {
      return widget.modules
          .map(
            (module) => _AdminSelectOption<String>(
              value: module.id,
              label: module.title,
              subtitle: 'Yakuniy imtihon moduli',
              icon: Icons.view_module_rounded,
              color: AppColors.amber,
            ),
          )
          .toList();
    }
    return widget.topics
        .map(
          (topic) => _AdminSelectOption<String>(
            value: topic.id,
            label: topic.title,
            subtitle: topic.moduleTitle,
            icon: Icons.menu_book_rounded,
            color: AppColors.primaryBlue,
          ),
        )
        .toList();
  }

  String get _scopeLabel {
    if (_scopeId.isEmpty) return '-';
    if (widget.finalExamOnly) {
      return widget.modules
          .firstWhere(
            (module) => module.id == _scopeId,
            orElse: () => widget.modules.first,
          )
          .title;
    }
    return widget.topics
        .firstWhere(
          (topic) => topic.id == _scopeId,
          orElse: () => widget.topics.first,
        )
        .title;
  }

  void _applyImportedQuestion() {
    final text = _importController.text.trim();
    if (text.isEmpty) return;
    final options = <String, String>{};
    String? question;
    String? answer;
    for (final rawLine in text.split(RegExp(r'\r?\n'))) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      final questionMatch = RegExp(
        r'^(question|savol)\s*:\s*(.+)$',
        caseSensitive: false,
      ).firstMatch(line);
      if (questionMatch != null) {
        question = questionMatch.group(2);
        continue;
      }
      final optionMatch = RegExp(
        r'^([A-Da-d])[\)\.\:]\s*(.+)$',
      ).firstMatch(line);
      if (optionMatch != null) {
        options[optionMatch.group(1)!.toLowerCase()] = optionMatch.group(2)!;
        continue;
      }
      final answerMatch = RegExp(
        r'^(answer|javob)\s*:\s*([A-Da-d])',
        caseSensitive: false,
      ).firstMatch(line);
      if (answerMatch != null) {
        answer = answerMatch.group(2)!.toLowerCase();
        continue;
      }
      question ??= line;
    }
    setState(() {
      if (question != null) _questionController.text = question;
      if (options['a'] != null) _optionAController.text = options['a']!;
      if (options['b'] != null) _optionBController.text = options['b']!;
      if (options['c'] != null) _optionCController.text = options['c']!;
      if (options['d'] != null) _optionDController.text = options['d']!;
      if (answer != null) _correctOption = answer;
    });
    _showAdminSnack(context, 'Savol shablondan ajratib olindi.');
  }

  Future<void> _save() async {
    final points = int.tryParse(_pointsController.text.trim()) ?? 1;
    if (_scopeId.isEmpty ||
        _questionController.text.trim().isEmpty ||
        _optionAController.text.trim().isEmpty ||
        _optionBController.text.trim().isEmpty ||
        _optionCController.text.trim().isEmpty) {
      _showAdminSnack(
        context,
        'Ko‘lam, savol va kamida A/B/C variantlarini to‘ldiring.',
        isError: true,
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await _repository.saveQuestion(
        id: widget.question?.id,
        topicId: widget.finalExamOnly ? null : _scopeId,
        moduleId: widget.finalExamOnly ? _scopeId : null,
        question: _questionController.text,
        optionA: _optionAController.text,
        optionB: _optionBController.text,
        optionC: _optionCController.text,
        optionD: _optionDController.text,
        correctOption: _correctOption,
        difficulty: _difficulty,
        points: points,
        questionType: _questionType,
        mediaUrl: _mediaUrlController.text,
        mediaKind: _questionType == 'image'
            ? 'image'
            : _questionType == 'video'
            ? 'video'
            : '',
        explanation: _explanationController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on Object catch (error) {
      if (!mounted) return;
      _showAdminSnack(context, error.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final dialogWidth = size.width < 1180 ? size.width - 32 : 1180.0;
    final title = widget.finalExamOnly
        ? (widget.question == null
              ? 'Yakuniy imtihon yaratish'
              : 'Yakuniy savolni tahrirlash')
        : (widget.question == null ? 'Test yaratish' : 'Testni tahrirlash');

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: dialogWidth,
          maxHeight: size.height * .92,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 18, 14),
              child: Row(
                children: [
                  IconBadge(
                    icon: widget.finalExamOnly
                        ? Icons.emoji_events_rounded
                        : Icons.quiz_rounded,
                    color: widget.finalExamOnly
                        ? AppColors.amber
                        : AppColors.primaryBlue,
                    size: 54,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.finalExamOnly
                              ? 'Yakuniy imtihon module ichidagi barcha mavzularni tekshiradi.'
                              : 'Test yaratish jarayoni 4 bosqichdan iborat.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _QuestionStepHeader(
                      labels: widget.finalExamOnly
                          ? const [
                              'Asosiy ma’lumotlar',
                              'Savol manbai',
                              'Imtihon sozlamalari',
                              'Ko‘rib chiqish',
                            ]
                          : const [
                              'Asosiy ma’lumotlar',
                              'Savollar',
                              'Sozlamalar',
                              'Ko‘rib chiqish',
                            ],
                    ),
                    const SizedBox(height: 16),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final twoColumns = constraints.maxWidth >= 920;
                        final cardWidth = twoColumns
                            ? (constraints.maxWidth - 16) / 2
                            : constraints.maxWidth;
                        return Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: [
                            SizedBox(
                              width: cardWidth,
                              child: _QuestionStepCard(
                                number: 1,
                                title: 'Asosiy ma’lumotlar',
                                child: Column(
                                  children: [
                                    TextField(
                                      controller: _quizTitleController,
                                      decoration: InputDecoration(
                                        labelText: widget.finalExamOnly
                                            ? 'Imtihon nomi *'
                                            : 'Test nomi *',
                                        hintText: widget.finalExamOnly
                                            ? 'Masalan: Kimyo yakuniy imtihoni'
                                            : 'Masalan: Siydik tahlili testi',
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    TextField(
                                      controller: _descriptionController,
                                      maxLines: 3,
                                      decoration: const InputDecoration(
                                        labelText: 'Qisqacha tavsif',
                                        hintText:
                                            'Test haqida qisqacha ma’lumot yozing...',
                                        alignLabelWithHint: true,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    _AdminSelectField<String>(
                                      value: _scopeId.isEmpty ? null : _scopeId,
                                      label: widget.finalExamOnly
                                          ? 'Modul *'
                                          : 'Mavzu *',
                                      hintText: widget.finalExamOnly
                                          ? 'Modulni tanlang'
                                          : 'Mavzuni tanlang',
                                      options: _scopeOptions,
                                      onChanged: (value) =>
                                          setState(() => _scopeId = value),
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _AdminSelectField<String>(
                                            value: _difficulty,
                                            label: 'Qiyinlik darajasi',
                                            options: const [
                                              _AdminSelectOption<String>(
                                                value: 'easy',
                                                label: 'Boshlang‘ich',
                                                subtitle: 'Oson savollar',
                                                icon: Icons
                                                    .sentiment_satisfied_alt_rounded,
                                                color: AppColors.successGreen,
                                              ),
                                              _AdminSelectOption<String>(
                                                value: 'medium',
                                                label: 'O‘rta',
                                                subtitle: 'Standart daraja',
                                                icon: Icons.tune_rounded,
                                                color: AppColors.amber,
                                              ),
                                              _AdminSelectOption<String>(
                                                value: 'hard',
                                                label: 'Yuqori',
                                                subtitle: 'Murakkab savollar',
                                                icon: Icons
                                                    .local_fire_department_rounded,
                                                color: AppColors.errorRed,
                                              ),
                                            ],
                                            onChanged: (value) => setState(() {
                                              _difficulty = value;
                                            }),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: TextField(
                                            controller: _tagsController,
                                            decoration: const InputDecoration(
                                              labelText: 'Teglar',
                                              hintText: 'kimyo, organik',
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(
                              width: cardWidth,
                              child: _QuestionStepCard(
                                number: 2,
                                title: widget.finalExamOnly
                                    ? 'Savol manbai'
                                    : 'Savollar',
                                trailing: TextButton.icon(
                                  onPressed: _applyImportedQuestion,
                                  icon: const Icon(Icons.auto_fix_high_rounded),
                                  label: const Text('Import qilish'),
                                ),
                                child: Column(
                                  children: [
                                    TextField(
                                      controller: _importController,
                                      minLines: 3,
                                      maxLines: 5,
                                      decoration: const InputDecoration(
                                        labelText: 'Copy-paste savol shabloni',
                                        hintText:
                                            'Question: What is blood pH?\nA) 5.5\nB) 6.8\nC) 7.4\nD) 8.1\nAnswer: C',
                                        alignLabelWithHint: true,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    TextField(
                                      controller: _questionController,
                                      maxLines: 3,
                                      decoration: const InputDecoration(
                                        labelText: 'Savol matni *',
                                        alignLabelWithHint: true,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    _AdminSelectField<String>(
                                      value: _questionType,
                                      label: 'Savol turi',
                                      options: const [
                                        _AdminSelectOption<String>(
                                          value: 'text',
                                          label: 'Text savol',
                                          icon: Icons.text_fields_rounded,
                                          color: AppColors.primaryBlue,
                                        ),
                                        _AdminSelectOption<String>(
                                          value: 'image',
                                          label: 'Rasmli savol',
                                          subtitle: 'Media URL rasm bo‘ladi',
                                          icon: Icons.image_rounded,
                                          color: AppColors.successGreen,
                                        ),
                                        _AdminSelectOption<String>(
                                          value: 'video',
                                          label: 'Video savol',
                                          subtitle: 'Media URL video bo‘ladi',
                                          icon: Icons.play_circle_rounded,
                                          color: AppColors.violet,
                                        ),
                                      ],
                                      onChanged: (value) =>
                                          setState(() => _questionType = value),
                                    ),
                                    if (_questionType != 'text') ...[
                                      const SizedBox(height: 12),
                                      TextField(
                                        controller: _mediaUrlController,
                                        decoration: InputDecoration(
                                          labelText: _questionType == 'image'
                                              ? 'Rasm URL'
                                              : 'Video URL / YouTube link',
                                          hintText: 'https://...',
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 12),
                                    TextField(
                                      controller: _explanationController,
                                      maxLines: 2,
                                      decoration: const InputDecoration(
                                        labelText: 'Izoh / tushuntirish',
                                        alignLabelWithHint: true,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    _QuestionOptionField(
                                      label: 'A',
                                      controller: _optionAController,
                                    ),
                                    const SizedBox(height: 10),
                                    _QuestionOptionField(
                                      label: 'B',
                                      controller: _optionBController,
                                    ),
                                    const SizedBox(height: 10),
                                    _QuestionOptionField(
                                      label: 'C',
                                      controller: _optionCController,
                                    ),
                                    const SizedBox(height: 10),
                                    _QuestionOptionField(
                                      label: 'D',
                                      controller: _optionDController,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(
                              width: cardWidth,
                              child: _QuestionStepCard(
                                number: 3,
                                title: widget.finalExamOnly
                                    ? 'Imtihon sozlamalari'
                                    : 'Test sozlamalari',
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller: _durationController,
                                            keyboardType: TextInputType.number,
                                            decoration: const InputDecoration(
                                              labelText: 'Vaqt',
                                              suffixText: 'daqiqa',
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: TextField(
                                            controller: _passScoreController,
                                            keyboardType: TextInputType.number,
                                            decoration: const InputDecoration(
                                              labelText: 'O‘tish bali',
                                              suffixText: '%',
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: TextField(
                                            controller: _attemptsController,
                                            keyboardType: TextInputType.number,
                                            decoration: const InputDecoration(
                                              labelText: 'Urinish',
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _AdminSelectField<String>(
                                            value: _correctOption,
                                            label: 'To‘g‘ri javob',
                                            options: const [
                                              _AdminSelectOption<String>(
                                                value: 'a',
                                                label: 'A varianti',
                                                icon:
                                                    Icons.check_circle_rounded,
                                                color: AppColors.primaryBlue,
                                              ),
                                              _AdminSelectOption<String>(
                                                value: 'b',
                                                label: 'B varianti',
                                                icon:
                                                    Icons.check_circle_rounded,
                                                color: AppColors.primaryBlue,
                                              ),
                                              _AdminSelectOption<String>(
                                                value: 'c',
                                                label: 'C varianti',
                                                icon:
                                                    Icons.check_circle_rounded,
                                                color: AppColors.primaryBlue,
                                              ),
                                              _AdminSelectOption<String>(
                                                value: 'd',
                                                label: 'D varianti',
                                                icon:
                                                    Icons.check_circle_rounded,
                                                color: AppColors.primaryBlue,
                                              ),
                                            ],
                                            onChanged: (value) => setState(() {
                                              _correctOption = value;
                                            }),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: TextField(
                                            controller: _pointsController,
                                            keyboardType: TextInputType.number,
                                            decoration: const InputDecoration(
                                              labelText: 'Ball',
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    _QuestionSwitchRow(
                                      label: 'Savollarni aralashtirish',
                                      value: _shuffleQuestions,
                                      onChanged: (value) => setState(
                                        () => _shuffleQuestions = value,
                                      ),
                                    ),
                                    _QuestionSwitchRow(
                                      label: 'Variantlarni aralashtirish',
                                      value: _shuffleAnswers,
                                      onChanged: (value) => setState(
                                        () => _shuffleAnswers = value,
                                      ),
                                    ),
                                    _QuestionSwitchRow(
                                      label: 'Natijani ko‘rsatish',
                                      value: _showResult,
                                      onChanged: (value) =>
                                          setState(() => _showResult = value),
                                    ),
                                    _QuestionSwitchRow(
                                      label: 'Orqaga qaytishga ruxsat',
                                      value: _allowBack,
                                      onChanged: (value) =>
                                          setState(() => _allowBack = value),
                                    ),
                                    _QuestionSwitchRow(
                                      label: 'Izohlarni ko‘rsatish',
                                      value: _showExplanations,
                                      onChanged: (value) => setState(
                                        () => _showExplanations = value,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(
                              width: cardWidth,
                              child: _QuestionStepCard(
                                number: 4,
                                title: 'Ko‘rib chiqish',
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _ReviewLine(
                                      label: widget.finalExamOnly
                                          ? 'Imtihon'
                                          : 'Test',
                                      value: _quizTitleController.text,
                                    ),
                                    _ReviewLine(
                                      label: widget.finalExamOnly
                                          ? 'Modul'
                                          : 'Mavzu',
                                      value: _scopeId.isEmpty
                                          ? '-'
                                          : _scopeLabel,
                                    ),
                                    _ReviewLine(
                                      label: 'Savollar',
                                      value:
                                          _questionController.text
                                              .trim()
                                              .isEmpty
                                          ? '0 ta'
                                          : '1 ta savol',
                                    ),
                                    _ReviewLine(
                                      label: 'Vaqt',
                                      value:
                                          '${_durationController.text} daqiqa',
                                    ),
                                    _ReviewLine(
                                      label: 'O‘tish',
                                      value: '${_passScoreController.text}%',
                                    ),
                                    const SizedBox(height: 16),
                                    _TopicInfoPanel(
                                      title: 'Tekshiruv ro‘yxati',
                                      body:
                                          'Mavzu/modul, savol matni, javob variantlari, to‘g‘ri javob va o‘tish parametrlari to‘ldirilganini tekshiring.',
                                      icon: Icons.fact_check_rounded,
                                      color: AppColors.successGreen,
                                      trailing:
                                          'Metadata • Savollar • Sozlamalar',
                                    ),
                                    if (widget.finalExamOnly) ...[
                                      const SizedBox(height: 12),
                                      _TopicInfoPanel(
                                        title: 'Yakuniy imtihon logikasi',
                                        body:
                                            'Final imtihon faqat barcha mavzular yakunlangandan keyin ochiladi. O‘tish bali 70% bo‘lsa, keyingi modul ochiladi.',
                                        icon: Icons.lock_open_rounded,
                                        color: AppColors.amber,
                                        trailing: '70% unlock',
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 18),
              child: Row(
                children: [
                  OutlinedButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Bekor qilish'),
                  ),
                  const Spacer(),
                  OutlinedButton(
                    onPressed: _saving ? null : _save,
                    child: const Text('Qoralama saqlash'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                    label: Text(
                      _saving
                          ? 'Saqlanmoqda...'
                          : (widget.finalExamOnly
                                ? 'Final imtihonni nashr qilish'
                                : 'Testni nashr qilish'),
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

class _QuestionStepHeader extends StatelessWidget {
  const _QuestionStepHeader({required this.labels});

  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Wrap(
          spacing: 12,
          runSpacing: 10,
          children: labels.asMap().entries.map((entry) {
            final selected = entry.key == 0;
            return Container(
              width: constraints.maxWidth >= 980
                  ? (constraints.maxWidth - 36) / 4
                  : null,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primaryBlue.withValues(alpha: .08)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected
                      ? AppColors.primaryBlue.withValues(alpha: .35)
                      : AppColors.border,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: selected
                        ? AppColors.primaryBlue
                        : const Color(0xFFE2E8F0),
                    child: Text(
                      '${entry.key + 1}',
                      style: TextStyle(
                        color: selected ? Colors.white : AppColors.navy,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      entry.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _QuestionStepCard extends StatelessWidget {
  const _QuestionStepCard({
    required this.number,
    required this.title,
    required this.child,
    this.trailing,
  });

  final int number;
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  '$number.',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _QuestionOptionField extends StatelessWidget {
  const _QuestionOptionField({required this.label, required this.controller});

  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: 'Variant $label',
        prefixIcon: Center(
          widthFactor: 1,
          child: Text(
            label,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppColors.primaryBlue,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _QuestionSwitchRow extends StatelessWidget {
  const _QuestionSwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Checkbox(
            value: value,
            onChanged: (checked) => onChanged(checked ?? false),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          const Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: AppColors.muted,
          ),
        ],
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({
    this.onEdit,
    this.onToggle,
    this.onDelete,
    this.toggleIcon = Icons.visibility_rounded,
  });

  final VoidCallback? onEdit;
  final VoidCallback? onToggle;
  final VoidCallback? onDelete;
  final IconData toggleIcon;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      children: [
        if (onEdit != null)
          IconButton(
            tooltip: 'Tahrirlash',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 18),
          ),
        if (onToggle != null)
          IconButton(
            tooltip: 'Holatini almashtirish',
            onPressed: onToggle,
            icon: Icon(toggleIcon, size: 18),
          ),
        if (onDelete != null)
          IconButton(
            tooltip: 'O‘chirish',
            onPressed: onDelete,
            icon: const Icon(
              Icons.delete_outline_rounded,
              size: 18,
              color: AppColors.errorRed,
            ),
          ),
      ],
    );
  }
}

class _AdminErrorState extends StatelessWidget {
  const _AdminErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const IconBadge(
            icon: Icons.error_outline_rounded,
            color: AppColors.errorRed,
            size: 54,
          ),
          const SizedBox(height: 14),
          Text(
            'Bo‘lim yuklanmadi',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            message.replaceFirst('Exception: ', ''),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Qayta yuklash'),
          ),
        ],
      ),
    );
  }
}

class _AdminEmptyMessage extends StatelessWidget {
  const _AdminEmptyMessage({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const IconBadge(
              icon: Icons.inbox_rounded,
              color: AppColors.primaryBlue,
              size: 54,
            ),
            const SizedBox(height: 14),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(message, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _EmbeddedAdminEmptyMessage extends StatelessWidget {
  const _EmbeddedAdminEmptyMessage({
    required this.width,
    required this.title,
    required this.message,
  });

  final double width;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        color: Colors.white.withValues(alpha: .6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const IconBadge(
            icon: Icons.inbox_rounded,
            color: AppColors.primaryBlue,
            size: 50,
          ),
          const SizedBox(height: 14),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(message, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

Future<bool?> _confirmDanger(
  BuildContext context, {
  required String title,
  required String message,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.warning_amber_rounded, color: AppColors.errorRed),
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Bekor qilish'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.errorRed),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Tasdiqlash'),
        ),
      ],
    ),
  );
}

void _showAdminSnack(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message.replaceFirst('Exception: ', '')),
      backgroundColor: isError ? AppColors.errorRed : null,
    ),
  );
}

String _formatDate(DateTime value) {
  return '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';
}

String _formatAdminBytes(int bytes) {
  if (bytes <= 0) return '-';
  if (bytes >= 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '$bytes B';
}

String _formatAdminDuration(int seconds) {
  if (seconds <= 0) return '0 daqiqa';
  final minutes = (seconds / 60).round();
  if (minutes < 60) return '$minutes daqiqa';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  if (rest == 0) return '$hours soat';
  return '$hours soat $rest daqiqa';
}

bool _isValidAdminUrl(String value) {
  final uri = Uri.tryParse(value.trim());
  return uri != null && (uri.scheme == 'https' || uri.scheme == 'http');
}

IconData _mediaIconForKind(String kind) {
  switch (kind) {
    case 'image':
      return Icons.image_rounded;
    case 'video':
      return Icons.video_file_rounded;
    case 'round_video':
      return Icons.radio_button_checked_rounded;
    case 'voice':
    case 'audio':
      return Icons.graphic_eq_rounded;
    case 'pdf':
      return Icons.picture_as_pdf_rounded;
    case 'document':
    case 'file':
      return Icons.description_rounded;
    case 'text':
      return Icons.article_rounded;
    case 'avatar':
      return Icons.account_circle_rounded;
    case 'certificate':
      return Icons.workspace_premium_rounded;
    default:
      return Icons.folder_rounded;
  }
}

Color _mediaColorForKind(String kind) {
  switch (kind) {
    case 'image':
      return AppColors.successGreen;
    case 'video':
      return AppColors.primaryBlue;
    case 'round_video':
      return AppColors.violet;
    case 'voice':
    case 'audio':
      return AppColors.amber;
    case 'pdf':
      return AppColors.errorRed;
    case 'document':
    case 'file':
      return AppColors.cyan;
    case 'text':
      return AppColors.successGreen;
    case 'avatar':
      return AppColors.violet;
    case 'certificate':
      return AppColors.amber;
    default:
      return AppColors.cyan;
  }
}

class _DashboardPage extends StatelessWidget {
  const _DashboardPage();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Boshqaruv paneli',
          subtitle: 'Umumiy statistika va laboratoriya LMS monitoringi',
        ),
        const SizedBox(height: 18),
        _MetricGrid(metrics: MockAcademyRepository.adminMetrics),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final twoColumns = constraints.maxWidth > 900;
            final chart = AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CardTitle(
                    title: 'Foydalanuvchilar o‘sishi',
                    action: _DropdownPill(label: 'Oxirgi 7 kun'),
                  ),
                  const SizedBox(height: 18),
                  const EmptyChart(
                    values: MockAcademyRepository.growthChart,
                    height: 210,
                  ),
                ],
              ),
            );
            final completion = AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CardTitle(
                    title: 'Modul yakunlash statistikasi',
                    action: _DropdownPill(label: 'Oxirgi 30 kun'),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: const [
                      CircularScore(value: .65, label: 'yakunlangan'),
                      SizedBox(width: 28),
                      Expanded(
                        child: Column(
                          children: [
                            _LegendRow(
                              color: AppColors.primaryBlue,
                              label: 'Yakunlangan',
                              value: '1,602 (65%)',
                            ),
                            _LegendRow(
                              color: AppColors.successGreen,
                              label: 'Jarayonda',
                              value: '702 (28%)',
                            ),
                            _LegendRow(
                              color: AppColors.amber,
                              label: 'Yakunlanmagan',
                              value: '154 (7%)',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
            if (twoColumns) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 6, child: chart),
                  const SizedBox(width: 20),
                  Expanded(flex: 4, child: completion),
                ],
              );
            }
            return Column(
              children: [chart, const SizedBox(height: 20), completion],
            );
          },
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final twoColumns = constraints.maxWidth > 950;
            final activeModules = _TopModulesCard();
            final recent = _RecentUsersCard();
            if (twoColumns) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: activeModules),
                  const SizedBox(width: 20),
                  Expanded(child: recent),
                ],
              );
            }
            return Column(
              children: [activeModules, const SizedBox(height: 20), recent],
            );
          },
        ),
      ],
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.metrics});

  final List<AdminMetric> metrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final count = width > 1080
            ? 5
            : width > 900
            ? 4
            : width > 720
            ? 3
            : width > 620
            ? 2
            : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: metrics.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: count,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: count == 1
                ? (width < 500 ? 2.65 : 3.25)
                : count >= 5
                ? 3.0
                : count == 4
                ? 2.75
                : count == 3
                ? 2.2
                : 1.82,
          ),
          itemBuilder: (context, index) {
            final metric = metrics[index];
            return MetricCard(
              title: metric.title,
              value: metric.value,
              icon: metric.icon,
              color: metric.color,
              delta: metric.delta,
              compact: count > 1,
            );
          },
        );
      },
    );
  }
}

class _ModuleManagementPage extends StatelessWidget {
  const _ModuleManagementPage();

  @override
  Widget build(BuildContext context) {
    return _ManagementPageShell(
      title: 'Modullarni boshqarish',
      subtitle:
          'Modul qo‘shish, tahrirlash, o‘chirish, tartiblash, yopish/ochish va holatini kuzatish.',
      primaryAction: 'Yangi modul qo‘shish',
      onPrimaryAction: () => _showAdminDialog(context, 'Modul qo‘shish'),
      child: Column(
        children: [
          const _FilterBar(
            filters: ['Barcha modullar', 'Faol', 'Yopiq', 'Past yakunlash'],
          ),
          const SizedBox(height: 16),
          _AdminTable(
            columns: const [
              '#',
              'Modul nomi',
              'Mavzular',
              'Talabalar',
              'Yakunlash',
              'Holat',
              'Amallar',
            ],
            rows: MockAcademyRepository.modules
                .map(
                  (module) => [
                    module.order.toString(),
                    module.title,
                    module.topics.isEmpty
                        ? '4'
                        : module.topics.length.toString(),
                    module.studentCount.toString(),
                    '${(module.completionRate * 100).round()}%',
                    module.isUnlocked ? 'Faol' : 'Yopiq',
                    'view edit lock delete',
                  ],
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          const _Pagination(),
        ],
      ),
    );
  }
}

class _TopicManagementPage extends StatelessWidget {
  const _TopicManagementPage();

  @override
  Widget build(BuildContext context) {
    final topics = MockAcademyRepository.modules.first.topics;

    return _ManagementPageShell(
      title: 'Mavzularni boshqarish',
      subtitle:
          'Mavzu ketma-ketligini tartiblash, video/PDF biriktirish va yakunlash mantiqini boshqarish.',
      primaryAction: 'Yangi mavzu qo‘shish',
      onPrimaryAction: () => _showAdminDialog(context, 'Mavzu qo‘shish'),
      child: Column(
        children: [
          const _FilterBar(
            filters: [
              'Elektr toki va zanjirlar',
              'PDF bor',
              'Video bor',
              'Test bor',
            ],
          ),
          const SizedBox(height: 16),
          _AdminTable(
            columns: const [
              'Tartib',
              'Mavzu nomi',
              'PDF',
              'Video',
              'Test',
              'Talabalar',
              'Holat',
              'Amallar',
            ],
            rows: topics
                .map(
                  (topic) => [
                    topic.id.substring(1),
                    topic.title,
                    'ready',
                    '${topic.duration.inMinutes}m',
                    '${(topic.quizScore * 100).round()}%',
                    '1,245',
                    topic.status.name,
                    'view edit reorder delete',
                  ],
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _ContentManagementPage extends StatelessWidget {
  const _ContentManagementPage();

  @override
  Widget build(BuildContext context) {
    return _TwoColumnAdminPage(
      title: 'PDF/Matn kontent boshqaruvi',
      subtitle:
          'PDF yuklash, matnli dars yozish, formulalar qo‘shish va fayllarni boshqarish.',
      left: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Matn / PDF kontent',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            const TextField(
              decoration: InputDecoration(
                labelText: 'Sarlavha',
                prefixIcon: Icon(Icons.title_rounded),
              ),
            ),
            const SizedBox(height: 12),
            const _Toolbar(),
            const SizedBox(height: 12),
            const TextField(
              maxLines: 7,
              decoration: InputDecoration(
                labelText: 'Matn muharriri',
                alignLabelWithHint: true,
                hintText: 'Dars matni, formulalar, laboratoriya izohlari...',
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: const [
                StatusChip(label: 'I = U / R', color: AppColors.primaryBlue),
                StatusChip(label: 'P = U × I', color: AppColors.successGreen),
                StatusChip(label: 'ΣI = 0', color: AppColors.violet),
              ],
            ),
          ],
        ),
      ),
      right: Column(
        children: const [
          _UploadBox(
            icon: Icons.picture_as_pdf_rounded,
            title: 'PDF yuklash',
            subtitle: 'JPG, PNG, PDF, DOCX · maksimum 25MB',
            color: AppColors.errorRed,
          ),
          SizedBox(height: 18),
          _FileListCard(),
        ],
      ),
    );
  }
}

class _VideoManagementPage extends StatelessWidget {
  const _VideoManagementPage();

  @override
  Widget build(BuildContext context) {
    return _TwoColumnAdminPage(
      title: 'Video boshqaruvi',
      subtitle: 'Video darslarni yuklash, ko‘rish va davomiyligini kuzatish.',
      left: AppCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 280,
              decoration: const BoxDecoration(
                color: AppColors.navy,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(painter: _VideoGridPainter()),
                  ),
                  const Center(
                    child: CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.white,
                      child: Icon(
                        Icons.play_arrow_rounded,
                        color: AppColors.primaryBlue,
                        size: 52,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Om qonunini tushuntirish',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Davomiyligi 08:45 · Streaming qo‘llab-quvvatlanadi · Tezlik nazorati',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      right: Column(
        children: const [
          _UploadBox(
            icon: Icons.video_file_rounded,
            title: 'Video yuklash',
            subtitle: 'MP4, MOV, WebM · davomiylik avtomatik aniqlanadi',
            color: AppColors.primaryBlue,
          ),
          SizedBox(height: 18),
          _AdminMiniStats(
            rows: [
              ('Jami videolar', '156'),
              ('O‘rtacha davomiylik', '09:42'),
              ('Streamingga tayyor', '142'),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuizManagementPage extends StatelessWidget {
  const _QuizManagementPage();

  @override
  Widget build(BuildContext context) {
    return _TwoColumnAdminPage(
      title: 'Testlarni boshqarish',
      subtitle:
          'Variantli savollar, to‘g‘ri javoblar, random testlar va vaqt chegaralarini yaratish.',
      left: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Savol konstruktori',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            const TextField(
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Savol',
                alignLabelWithHint: true,
                hintText: 'Om qonuniga ko‘ra tok kuchi qanday topiladi?',
              ),
            ),
            const SizedBox(height: 12),
            ...[
              'I = U × R',
              'I = U / R',
              'I = R / U',
              'I = U + R',
            ].asMap().entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TextFormField(
                  initialValue: entry.value,
                  decoration: InputDecoration(
                    labelText: 'Variant ${String.fromCharCode(65 + entry.key)}',
                    prefixIcon: Icon(
                      entry.key == 1
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: entry.key == 1 ? AppColors.successGreen : null,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: const [
                StatusChip(label: 'Random test', color: AppColors.primaryBlue),
                StatusChip(label: 'Vaqt 5m', color: AppColors.amber),
                StatusChip(label: 'MCQ', color: AppColors.successGreen),
              ],
            ),
          ],
        ),
      ),
      right: Column(
        children: [
          const _AdminMiniStats(
            rows: [
              ('Savollar', '342'),
              ('Mavzu testlari', '156'),
              ('O‘rtacha o‘tish', '82%'),
            ],
          ),
          const SizedBox(height: 18),
          _AdminTable(
            compact: true,
            columns: const ['Mavzu', 'Savollar', 'Vaqt'],
            rows: const [
              ['Om qonuni', '5', '5m'],
              ['Elektr zaryad', '6', '5m'],
              ['Kirxgof', '8', '7m'],
            ],
          ),
        ],
      ),
    );
  }
}

class _FinalExamBuilderPage extends StatelessWidget {
  const _FinalExamBuilderPage();

  @override
  Widget build(BuildContext context) {
    return _TwoColumnAdminPage(
      title: 'Yakuniy imtihon konstruktori',
      subtitle:
          'Barcha mavzu savollarini birlashtirish, o‘tish bali, qayta topshirish va qiyinlik darajasini sozlash.',
      left: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Elektr toki va zanjirlar yakuniy imtihoni',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            const _SliderSetting(
              label: 'O‘tish bali',
              value: .7,
              display: '70%',
            ),
            const _SliderSetting(
              label: 'Savollar soni',
              value: .6,
              display: '30',
            ),
            const _SliderSetting(
              label: 'Vaqt chegarasi',
              value: .75,
              display: '45 min',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: const [
                StatusChip(
                  label: 'Qayta topshirish yoqilgan',
                  color: AppColors.successGreen,
                ),
                StatusChip(
                  label: 'Aralash savollar',
                  color: AppColors.primaryBlue,
                ),
                StatusChip(label: 'O‘rta qiyinlik', color: AppColors.amber),
              ],
            ),
          ],
        ),
      ),
      right: Column(
        children: [
          _AdminTable(
            compact: true,
            columns: const ['Mavzu', 'Savollar bazasi', 'Qiyinlik'],
            rows: const [
              ['Elektr zaryad', '24', 'Oson'],
              ['Om qonuni', '32', 'O‘rta'],
              ['Kirxgof', '18', 'Qiyin'],
              ['Quvvat', '20', 'O‘rta'],
            ],
          ),
          const SizedBox(height: 18),
          const _AdminMiniStats(
            rows: [
              ('O‘tish chegarasi', '70%'),
              ('Qayta topshirish oralig‘i', '24s'),
              ('Ochish qoidasi', 'Keyingi modul'),
            ],
          ),
        ],
      ),
    );
  }
}

class _StudentManagementPage extends StatelessWidget {
  const _StudentManagementPage();

  @override
  Widget build(BuildContext context) {
    return _ManagementPageShell(
      title: 'Talabalarni boshqarish',
      subtitle:
          'Talabalar ro‘yxati, progress, test natijalari, yopiq modullar va sertifikatlar.',
      primaryAction: 'Talaba taklif qilish',
      onPrimaryAction: () => _showAdminDialog(context, 'Talaba taklif qilish'),
      child: Column(
        children: [
          const _FilterBar(
            filters: [
              'Barcha talabalar',
              'O‘tgan',
              'Yiqilgan',
              'Sertifikat tayyor',
            ],
          ),
          const SizedBox(height: 16),
          _AdminTable(
            columns: const [
              'Talaba',
              'Telefon',
              'Modul',
              'Ball',
              'Progress',
              'Holat',
              'Amallar',
            ],
            rows: MockAcademyRepository.studentRecords
                .map(
                  (student) => [
                    student.name,
                    student.email,
                    student.module,
                    '${student.score}%',
                    '${(student.progress * 100).round()}%',
                    student.status,
                    'view unlock certificate',
                  ],
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _AnalyticsPage extends StatelessWidget {
  const _AnalyticsPage();

  @override
  Widget build(BuildContext context) {
    return _ManagementPageShell(
      title: 'Tahlillar va natijalar',
      subtitle:
          'Imtihon tahlillari, talaba ko‘rsatkichlari, yakunlash foizlari, hisobotlar va eksport.',
      primaryAction: 'Natijalarni eksport qilish',
      onPrimaryAction: () => _showAdminDialog(context, 'Hisobot eksporti'),
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final two = constraints.maxWidth > 850;
              final performance = AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _CardTitle(title: 'Talabalar ko‘rsatkichi'),
                    const SizedBox(height: 16),
                    const EmptyChart(
                      values: MockAcademyRepository.completionChart,
                      height: 220,
                      color: AppColors.successGreen,
                    ),
                  ],
                ),
              );
              final exam = AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _CardTitle(title: 'Imtihon tahlillari'),
                    const SizedBox(height: 18),
                    ...const [
                      _BarMetric(
                        label: 'O‘tgan',
                        value: .72,
                        color: AppColors.successGreen,
                      ),
                      _BarMetric(
                        label: 'Yiqilgan',
                        value: .18,
                        color: AppColors.errorRed,
                      ),
                      _BarMetric(
                        label: 'Qayta topshirgan',
                        value: .1,
                        color: AppColors.amber,
                      ),
                    ],
                  ],
                ),
              );
              if (two) {
                return Row(
                  children: [
                    Expanded(flex: 6, child: performance),
                    const SizedBox(width: 20),
                    Expanded(flex: 4, child: exam),
                  ],
                );
              }
              return Column(
                children: [performance, const SizedBox(height: 20), exam],
              );
            },
          ),
          const SizedBox(height: 20),
          _AdminTable(
            columns: const ['Talaba', 'Modul', 'Test', 'Ball', 'Sana', 'Holat'],
            rows: MockAcademyRepository.studentRecords
                .map(
                  (student) => [
                    student.name,
                    student.module,
                    'Yakuniy imtihon',
                    '${student.score}%',
                    '22.05.2026',
                    student.status,
                  ],
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _NotificationsPage extends StatefulWidget {
  const _NotificationsPage({this.initialThreadKey});

  final String? initialThreadKey;

  @override
  State<_NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<_NotificationsPage> {
  static const _repository = SupabaseAcademyRepository();

  final _searchController = TextEditingController();

  bool _loading = true;
  String? _error;
  List<StudentNotification> _items = const [];
  List<AdminInboxMessage> _inboxItems = const [];
  String? _selectedThreadKey;
  String _inboxFilter = 'all';
  String _notificationFilter = 'all';

  @override
  void initState() {
    super.initState();
    _selectedThreadKey = widget.initialThreadKey;
    _loadNotifications();
  }

  @override
  void didUpdateWidget(covariant _NotificationsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialThreadKey != oldWidget.initialThreadKey &&
        widget.initialThreadKey != null &&
        widget.initialThreadKey!.isNotEmpty) {
      setState(() => _selectedThreadKey = widget.initialThreadKey);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _repository.loadAdminNotifications(limit: 80),
        _repository.loadAdminInboxMessages(limit: 200),
      ]);
      if (!mounted) return;
      setState(() {
        _items = results[0] as List<StudentNotification>;
        _inboxItems = results[1] as List<AdminInboxMessage>;
        _loading = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _markThreadRead(_AdminInboxThread thread) async {
    final unread = thread.messages.where((item) => !item.isRead).toList();
    if (unread.isEmpty) return;
    for (final message in unread) {
      await _repository.markAdminInboxMessageRead(message.id);
    }
    await _loadNotifications();
  }

  Future<void> _selectThread(_AdminInboxThread thread) async {
    if (_selectedThreadKey != thread.key) {
      setState(() => _selectedThreadKey = thread.key);
    }
    await _markThreadRead(thread);
  }

  Future<void> _replyToInbox(AdminInboxMessage item) async {
    final sent = await showDialog<bool>(
      context: context,
      builder: (_) => _AdminReplyDialog(message: item),
    );
    if (sent == true) {
      await _loadNotifications();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Javob yuborildi.')));
    }
  }

  Future<void> _openComposerDialog() async {
    final sent = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => const _AdminBroadcastComposerDialog(),
    );
    if (sent == true) {
      await _loadNotifications();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Xabarnoma student ilovasiga yuborildi.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final inboxThreads = _groupInboxThreads(_inboxItems);
    final filteredThreads = inboxThreads.where((thread) {
      final latest = thread.latestMessage;
      final matchesSearch =
          query.isEmpty ||
          thread.displayName.toLowerCase().contains(query) ||
          thread.phone.toLowerCase().contains(query) ||
          latest.subject.toLowerCase().contains(query) ||
          latest.body.toLowerCase().contains(query) ||
          thread.messages.any(
            (item) =>
                item.subject.toLowerCase().contains(query) ||
                item.body.toLowerCase().contains(query),
          );
      final matchesFilter = switch (_inboxFilter) {
        'telegram' => thread.hasTelegram,
        'student' => thread.hasStudentApp,
        'unread' => thread.unreadCount > 0,
        'replied' => thread.messages.any(
          (item) => item.adminReply?.trim().isNotEmpty == true,
        ),
        _ => true,
      };
      return matchesSearch && matchesFilter;
    }).toList();
    final _AdminInboxThread? selectedThread = filteredThreads
        .cast<_AdminInboxThread?>()
        .firstWhere(
          (thread) => thread?.key == _selectedThreadKey,
          orElse: () =>
              filteredThreads.isNotEmpty ? filteredThreads.first : null,
        );
    final hasSelectedThread = selectedThread != null;
    final filteredNotifications = _items.where((item) {
      final matchesSearch =
          query.isEmpty ||
          item.title.toLowerCase().contains(query) ||
          item.body.toLowerCase().contains(query);
      final matchesFilter = switch (_notificationFilter) {
        'news' => _notificationKindForItem(item) == 'Yangilik',
        'reminder' => _notificationKindForItem(item) == 'Eslatma',
        'warning' => _notificationKindForItem(item) == 'Ogohlantirish',
        'targeted' => item.targetUserId != null,
        _ => true,
      };
      return matchesSearch && matchesFilter;
    }).toList();

    final total = filteredNotifications.length;
    final inboxCount = inboxThreads.length;
    final unreadInboxCount = inboxThreads
        .where((thread) => thread.unreadCount > 0)
        .length;
    final averageOpenRate = filteredNotifications.isEmpty
        ? 0.0
        : filteredNotifications
                  .map(_notificationOpenRate)
                  .reduce((a, b) => a + b) /
              filteredNotifications.length;
    final telegramCount = inboxThreads
        .where((thread) => thread.hasTelegram)
        .length;
    final studentAppCount = inboxThreads
        .where((thread) => thread.hasStudentApp)
        .length;
    final useTelegramReference = DateTime.now().year >= 2020;
    if (useTelegramReference) {
      final chatPanel = hasSelectedThread
          ? _AdminConversationPanel(
              thread: selectedThread,
              onOpenAttachment: _openAdminAttachmentUrl,
              onMarkRead: () => _markThreadRead(selectedThread),
              onSent: () async {
                await _loadNotifications();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Javob yuborildi.')),
                );
              },
            )
          : const _AdminEmptyMessage(
              title: 'Suhbat tanlanmagan',
              message:
                  'Chap tomondan student yoki Telegram yozishmasini tanlang.',
            );
      return _AdminReferenceScaffold(
        title: 'Xabarnomalar',
        breadcrumbs: const ['Bosh sahifa', 'Xabarnomalar'],
        stats: const [],
        main: LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 980;
            final left = _AdminSectionSurface(
              title: 'Suhbatlar',
              action: IconButton(
                tooltip: 'Yangilash',
                onPressed: _loadNotifications,
                icon: const Icon(Icons.tune_rounded),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: () =>
                              setState(() => _inboxFilter = 'telegram'),
                          icon: const Icon(Icons.telegram_rounded, size: 18),
                          label: const Text('Telegram bot'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              setState(() => _inboxFilter = 'student'),
                          icon: const Icon(
                            Icons.phone_android_rounded,
                            size: 18,
                          ),
                          label: const Text('Student ilovasi'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: 'Qidirish...',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: stacked ? 320 : 620,
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : filteredThreads.isEmpty
                        ? const _AdminEmptyMessage(
                            title: 'Suhbatlar topilmadi',
                            message:
                                'Telegram bot yoki student ilovasidan xabar kelganda shu yerda chiqadi.',
                          )
                        : _AdminInboxThreadList(
                            threads: filteredThreads,
                            selectedThreadKey: _selectedThreadKey,
                            onSelect: _selectThread,
                          ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Jami $inboxCount ta suhbat'),
                  ),
                ],
              ),
            );
            final middle = SizedBox(height: 760, child: chatPanel);
            if (stacked) {
              return Column(
                children: [left, const SizedBox(height: 18), middle],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 330, child: left),
                const SizedBox(width: 18),
                Expanded(child: middle),
              ],
            );
          },
        ),
        rail: _AdminChatProfilePanel(
          thread: selectedThread,
          totalMessages: _items.length + _inboxItems.length,
          unreadCount: unreadInboxCount,
          telegramCount: telegramCount,
          studentAppCount: studentAppCount,
          onCompose: _openComposerDialog,
        ),
      );
    }

    return _AdminReferenceScaffold(
      title: 'Xabarnomalar',
      breadcrumbs: const ['Bosh sahifa', 'Xabarnomalar'],
      stats: [
        _AdminSummaryCardData(
          title: 'Jami xabarnomalar',
          value: total.toString(),
          subtitle: 'Student ilovasiga yuborilgan',
          icon: Icons.send_rounded,
          color: AppColors.primaryBlue,
        ),
        _AdminSummaryCardData(
          title: 'Kelgan murojaatlar',
          value: inboxCount.toString(),
          subtitle: 'Bell orqali ko‘rinadigan inbox',
          icon: Icons.mark_email_read_rounded,
          color: AppColors.successGreen,
        ),
        _AdminSummaryCardData(
          title: 'Yangi xabarlar',
          value: unreadInboxCount.toString(),
          subtitle: 'O‘qilmaganlar soni',
          icon: Icons.warning_amber_rounded,
          color: AppColors.errorRed,
        ),
        _AdminSummaryCardData(
          title: 'Telegram manbasi',
          value: telegramCount.toString(),
          subtitle: 'Bot orqali kelgan',
          icon: Icons.telegram_rounded,
          color: AppColors.primaryBlue,
        ),
        _AdminSummaryCardData(
          title: 'Student ilovasi',
          value: studentAppCount.toString(),
          subtitle: 'Ilovadan yuborilgan',
          icon: Icons.support_agent_rounded,
          color: AppColors.successGreen,
        ),
        _AdminSummaryCardData(
          title: 'Ochilish darajasi',
          value: '${(averageOpenRate * 100).toStringAsFixed(1)}%',
          subtitle: 'Yuborilgan xabarnomalar',
          icon: Icons.visibility_outlined,
          color: AppColors.primaryBlue,
        ),
      ],
      main: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AdminSectionSurface(
            title: 'Kelgan murojaatlar',
            action: OutlinedButton.icon(
              onPressed: _loadNotifications,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Yangilash'),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    SizedBox(
                      width: 260,
                      child: TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          hintText: 'Kimdan, mavzu yoki matn...',
                          prefixIcon: Icon(Icons.search_rounded),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 190,
                      child: _AdminSelectField<String>(
                        value: _inboxFilter,
                        label: 'Manba',
                        options: const [
                          _AdminSelectOption<String>(
                            value: 'all',
                            label: 'Barcha manbalar',
                            icon: Icons.all_inbox_rounded,
                            color: AppColors.primaryBlue,
                          ),
                          _AdminSelectOption<String>(
                            value: 'student',
                            label: 'Student ilovasi',
                            icon: Icons.phone_android_rounded,
                            color: AppColors.successGreen,
                          ),
                          _AdminSelectOption<String>(
                            value: 'telegram',
                            label: 'Telegram bot',
                            icon: Icons.send_rounded,
                            color: AppColors.primaryBlue,
                          ),
                          _AdminSelectOption<String>(
                            value: 'unread',
                            label: 'Faqat yangi',
                            icon: Icons.mark_chat_unread_rounded,
                            color: AppColors.amber,
                          ),
                          _AdminSelectOption<String>(
                            value: 'replied',
                            label: 'Javob berilgan',
                            icon: Icons.reply_all_rounded,
                            color: AppColors.violet,
                          ),
                        ],
                        onChanged: (value) =>
                            setState(() => _inboxFilter = value),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                if (_loading)
                  const Center(child: CircularProgressIndicator())
                else if (_error != null)
                  Text(_error!, style: Theme.of(context).textTheme.bodyMedium)
                else if (filteredThreads.isEmpty)
                  const _AdminEmptyMessage(
                    title: 'Kelgan xabar topilmadi',
                    message:
                        'Student ilovasi yoki Telegram bot orqali yuborilgan barcha murojaatlar shu yerda ko‘rinadi.',
                  )
                else
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final stacked = constraints.maxWidth < 860;
                      final threadList = _AdminInboxThreadList(
                        threads: filteredThreads,
                        selectedThreadKey: _selectedThreadKey,
                        onSelect: _selectThread,
                      );
                      final conversation = hasSelectedThread
                          ? _AdminConversationPanel(
                              thread: selectedThread,
                              onOpenAttachment: _openAdminAttachmentUrl,
                              onMarkRead: () => _markThreadRead(selectedThread),
                              onSent: () async {
                                await _loadNotifications();
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Javob yuborildi.'),
                                  ),
                                );
                              },
                            )
                          : const _AdminEmptyMessage(
                              title: 'Suhbat tanlanmagan',
                              message:
                                  'Chap tomondan student yoki Telegram yozishmasini tanlang.',
                            );

                      if (stacked) {
                        return Column(
                          children: [
                            SizedBox(height: 340, child: threadList),
                            const SizedBox(height: 14),
                            SizedBox(height: 680, child: conversation),
                          ],
                        );
                      }

                      return SizedBox(
                        height: 680,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(width: 320, child: threadList),
                            const SizedBox(width: 14),
                            Expanded(child: conversation),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _AdminSectionSurface(
            title: 'Yuborilgan xabarnomalar',
            action: _AdminPrimaryActionButton(
              label: 'Yangi xabar yuborish',
              icon: Icons.add_rounded,
              onPressed: _openComposerDialog,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    SizedBox(
                      width: 190,
                      child: _AdminSelectField<String>(
                        value: _notificationFilter,
                        label: 'Xabar turi',
                        options: const [
                          _AdminSelectOption<String>(
                            value: 'all',
                            label: 'Barcha turlar',
                            icon: Icons.category_rounded,
                            color: AppColors.primaryBlue,
                          ),
                          _AdminSelectOption<String>(
                            value: 'news',
                            label: 'Yangilik',
                            icon: Icons.campaign_rounded,
                            color: AppColors.primaryBlue,
                          ),
                          _AdminSelectOption<String>(
                            value: 'reminder',
                            label: 'Eslatma',
                            icon: Icons.alarm_rounded,
                            color: AppColors.successGreen,
                          ),
                          _AdminSelectOption<String>(
                            value: 'warning',
                            label: 'Ogohlantirish',
                            icon: Icons.warning_rounded,
                            color: AppColors.amber,
                          ),
                          _AdminSelectOption<String>(
                            value: 'targeted',
                            label: 'Shaxsiy javoblar',
                            icon: Icons.person_pin_circle_rounded,
                            color: AppColors.violet,
                          ),
                        ],
                        onChanged: (value) =>
                            setState(() => _notificationFilter = value),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _loadNotifications,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Ro‘yxatni yangilash'),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                if (_loading)
                  const Center(child: CircularProgressIndicator())
                else if (_error != null)
                  Text(_error!, style: Theme.of(context).textTheme.bodyMedium)
                else if (filteredNotifications.isEmpty)
                  const _AdminEmptyMessage(
                    title: 'Hali xabarnoma yuborilmagan',
                    message:
                        'Oddiy e’lonlar ham, studentga qaytarilgan admin javoblari ham shu yerda ko‘rinadi.',
                  )
                else
                  _AdminTable(
                    columns: const [
                      'Xabar',
                      'Turi',
                      'Auditoriya',
                      'Yuborilgan sana',
                      'O‘qish darajasi',
                      'Holat',
                      'Amallar',
                    ],
                    rowMinHeight: 86,
                    rowMaxHeight: 116,
                    columnSpacing: 20,
                    rows: filteredNotifications
                        .take(12)
                        .map(
                          (item) => [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  item.title,
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                const SizedBox(height: 2),
                                SizedBox(
                                  width: 220,
                                  child: Text(
                                    item.body,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ),
                                if (item.hasAttachment) ...[
                                  const SizedBox(height: 6),
                                  SizedBox(
                                    width: 220,
                                    child: _AdminAttachmentLink(
                                      onTap: () => _openAdminAttachmentUrl(
                                        item.attachmentUrl!,
                                      ),
                                      icon: _adminAttachmentIcon(
                                        item.messageKind,
                                      ),
                                      label:
                                          item.attachmentName
                                                  ?.trim()
                                                  .isNotEmpty ==
                                              true
                                          ? item.attachmentName!
                                          : _adminAttachmentLabel(
                                              item.messageKind,
                                            ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            _AdminTablePill(
                              label: _notificationKindForItem(item),
                              color: _notificationKindColor(
                                _notificationKindForItem(item),
                              ),
                            ),
                            _notificationAudienceForItem(item),
                            _formatPreciseAdminDateTime(item.createdAt),
                            '${(_notificationOpenRate(item) * 100).round()}%',
                            _AdminTablePill(
                              label: item.targetUserId != null
                                  ? (item.isRead ? 'O‘qilgan' : 'Yuborilgan')
                                  : 'Faol',
                              color: item.targetUserId != null && !item.isRead
                                  ? AppColors.primaryBlue
                                  : AppColors.successGreen,
                            ),
                            FilledButton.tonalIcon(
                              onPressed: item.hasAttachment
                                  ? () => _openAdminAttachmentUrl(
                                      item.attachmentUrl!,
                                    )
                                  : null,
                              icon: const Icon(
                                Icons.visibility_outlined,
                                size: 16,
                              ),
                              label: const Text('Ko‘rish'),
                            ),
                          ],
                        )
                        .toList(),
                  ),
              ],
            ),
          ),
        ],
      ),
      rail: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AdminSectionSurface(
            title: 'Inbox holati',
            child: Row(
              children: [
                CircularScore(
                  value: inboxCount == 0
                      ? 0
                      : (inboxCount - unreadInboxCount) / inboxCount,
                  label: 'Inbox',
                  color: AppColors.primaryBlue,
                  size: 118,
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    children: [
                      _LegendRow(
                        color: AppColors.primaryBlue,
                        label: 'Yangi',
                        value: '$unreadInboxCount',
                      ),
                      _LegendRow(
                        color: AppColors.successGreen,
                        label: 'Student ilovasi',
                        value: '$studentAppCount',
                      ),
                      _LegendRow(
                        color: AppColors.primaryBlue,
                        label: 'Telegram',
                        value: '$telegramCount',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _AdminSectionSurface(
            title: 'So‘nggi kelgan xabarlar',
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : inboxThreads.isEmpty
                ? Text(
                    'Hali kelgan murojaat yo‘q.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  )
                : Column(
                    children: inboxThreads.take(5).map((thread) {
                      final latest = thread.latestMessage;
                      final isTelegramOnly =
                          thread.hasTelegram && !thread.hasStudentApp;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () => _selectThread(thread),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              IconBadge(
                                icon: thread.hasMultipleSources
                                    ? Icons.forum_rounded
                                    : isTelegramOnly
                                    ? Icons.telegram_rounded
                                    : Icons.support_agent_rounded,
                                color: isTelegramOnly
                                    ? AppColors.primaryBlue
                                    : AppColors.successGreen,
                                size: 38,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      thread.displayName,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleSmall,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${latest.subject.isEmpty ? 'Yangi murojaat' : latest.subject} · ${_formatDate(latest.createdAt)}',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              if (thread.unreadCount > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryBlue.withValues(
                                      alpha: .12,
                                    ),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    '${thread.unreadCount}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(
                                          color: AppColors.primaryBlue,
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
          ),
          const SizedBox(height: 18),
          _AdminSectionSurface(
            title: 'Tezkor amallar',
            child: Column(
              children: [
                _AdminActionTile(
                  icon: Icons.add_alert_rounded,
                  title: 'Yangi xabar yuborish',
                  subtitle: 'Barcha studentlarga xabar yuboring',
                  onTap: _openComposerDialog,
                ),
                const SizedBox(height: 12),
                _AdminActionTile(
                  icon: Icons.reply_all_rounded,
                  title: 'Yangi xabarlarga javob berish',
                  subtitle: 'Student ilovasi yoki Telegramga javob bering',
                  color: AppColors.violet,
                  onTap: filteredThreads.isEmpty
                      ? null
                      : () => _replyToThread(
                          selectedThread ?? filteredThreads.first,
                        ),
                ),
                const SizedBox(height: 12),
                _AdminActionTile(
                  icon: Icons.analytics_outlined,
                  title: 'Ro‘yxatni yangilash',
                  subtitle: 'Kelgan va yuborilgan xabarlarni sinxronlash',
                  color: AppColors.successGreen,
                  onTap: _loadNotifications,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _replyToThread(_AdminInboxThread thread) async {
    await _replyToInbox(thread.latestMessage);
  }
}

class _AdminChatProfilePanel extends StatelessWidget {
  const _AdminChatProfilePanel({
    required this.thread,
    required this.totalMessages,
    required this.unreadCount,
    required this.telegramCount,
    required this.studentAppCount,
    required this.onCompose,
  });

  final _AdminInboxThread? thread;
  final int totalMessages;
  final int unreadCount;
  final int telegramCount;
  final int studentAppCount;
  final VoidCallback onCompose;

  @override
  Widget build(BuildContext context) {
    final title = thread?.displayName ?? 'EduLab Bot';
    final isTelegram = thread?.hasTelegram ?? true;
    return Column(
      children: [
        _AdminSectionSurface(
          title: 'Suhbat ma’lumotlari',
          child: Column(
            children: [
              IconBadge(
                icon: isTelegram
                    ? Icons.telegram_rounded
                    : Icons.person_rounded,
                color: isTelegram
                    ? AppColors.primaryBlue
                    : AppColors.successGreen,
                size: 72,
              ),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              const StatusChip(label: 'Onlayn', color: AppColors.successGreen),
              const SizedBox(height: 18),
              Text(
                isTelegram
                    ? 'EduLab Academy rasmiy bot. Talabalar uchun yordam va ma’lumot.'
                    : 'Student ilovasidan kelgan xabarlar va javoblar.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _AdminSectionSurface(
          title: 'Statistika',
          child: Column(
            children: [
              _LegendRow(
                color: AppColors.primaryBlue,
                label: 'Jami xabarlar',
                value: '$totalMessages',
              ),
              _LegendRow(
                color: AppColors.amber,
                label: 'Bugun',
                value: '${thread?.messages.length ?? 0}',
              ),
              _LegendRow(
                color: AppColors.errorRed,
                label: 'O‘qilmagan',
                value: '$unreadCount',
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _AdminSectionSurface(
          title: 'Media, fayllar va havolalar',
          child: Column(
            children: [
              _LegendRow(
                color: AppColors.primaryBlue,
                label: 'Telegram',
                value: '$telegramCount',
              ),
              _LegendRow(
                color: AppColors.successGreen,
                label: 'Student ilovasi',
                value: '$studentAppCount',
              ),
              _LegendRow(
                color: AppColors.violet,
                label: 'Biriktirmalar',
                value:
                    '${thread?.messages.where((item) => item.attachmentUrl != null).length ?? 0}',
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onCompose,
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('Yangi xabar yuborish'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AdminInboxThreadList extends StatelessWidget {
  const _AdminInboxThreadList({
    required this.threads,
    required this.selectedThreadKey,
    required this.onSelect,
  });

  final List<_AdminInboxThread> threads;
  final String? selectedThreadKey;
  final ValueChanged<_AdminInboxThread> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListView.separated(
        padding: const EdgeInsets.all(10),
        itemCount: threads.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final thread = threads[index];
          final selected = thread.key == selectedThreadKey;
          final latest = thread.latestMessage;
          return InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => onSelect(thread),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primaryBlue.withValues(alpha: .08)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: selected
                      ? AppColors.primaryBlue.withValues(alpha: .2)
                      : AppColors.border,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 19,
                        backgroundColor:
                            (thread.hasTelegram
                                    ? AppColors.primaryBlue
                                    : AppColors.successGreen)
                                .withValues(alpha: .12),
                        child: Icon(
                          thread.hasTelegram
                              ? Icons.telegram_rounded
                              : Icons.support_agent_rounded,
                          color: thread.hasTelegram
                              ? AppColors.primaryBlue
                              : AppColors.successGreen,
                          size: 19,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              thread.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              thread.phone.isEmpty
                                  ? 'Telefon raqam yo‘q'
                                  : thread.phone,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _formatPreciseAdminDateTime(latest.createdAt),
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                          if (thread.unreadCount > 0) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.errorRed,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '${thread.unreadCount}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (thread.hasStudentApp)
                        const StatusChip(
                          label: 'Ilova',
                          color: AppColors.successGreen,
                        ),
                      if (thread.hasTelegram)
                        const StatusChip(
                          label: 'Telegram',
                          color: AppColors.primaryBlue,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    latest.subject.isEmpty ? 'Yangi murojaat' : latest.subject,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    latest.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AdminConversationPanel extends StatefulWidget {
  const _AdminConversationPanel({
    required this.thread,
    required this.onOpenAttachment,
    required this.onMarkRead,
    required this.onSent,
  });

  final _AdminInboxThread thread;
  final VoidCallback onMarkRead;
  final Future<void> Function() onSent;
  final ValueChanged<String> onOpenAttachment;

  @override
  State<_AdminConversationPanel> createState() =>
      _AdminConversationPanelState();
}

class _AdminConversationPanelState extends State<_AdminConversationPanel> {
  static const _repository = SupabaseAcademyRepository();

  final _replyController = TextEditingController();
  bool _sending = false;
  String? _error;
  _AdminChatAttachmentDraft? _attachment;

  @override
  void didUpdateWidget(covariant _AdminConversationPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.thread.key != widget.thread.key) {
      _replyController.clear();
      _attachment = null;
      _error = null;
      _sending = false;
    }
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _pickAttachment(String kind) async {
    setState(() => _error = null);
    try {
      final picked = await _pickAdminAttachment(kind);
      if (picked == null || !mounted) return;
      setState(() => _attachment = picked);
    } on Object catch (error) {
      if (!mounted) return;
      debugPrint('Admin reply attachment pick failed: $error');
      setState(
        () => _error =
            'Biriktirma tanlanmadi. Fayl turini yoki brauzer ruxsatini tekshirib qayta urinib ko‘ring.',
      );
    }
  }

  Future<void> _sendReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty && _attachment == null) {
      setState(() => _error = 'Javob matni yoki biriktirma kiriting.');
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      String? attachmentUrl;
      if (_attachment != null) {
        attachmentUrl = await _repository.uploadChatAttachment(
          bytes: _attachment!.bytes,
          extension: _attachment!.extension,
          fileName: _attachment!.fileName,
          kind: _attachment!.messageKind == 'video_note'
              ? 'round_video'
              : _attachment!.messageKind,
        );
      }
      await _repository.sendAdminReply(
        messageId: widget.thread.latestMessage.id,
        replyText: text,
        messageKind: _attachment?.messageKind ?? 'text',
        attachmentUrl: attachmentUrl,
        attachmentName: _attachment?.fileName,
        attachmentMime: _attachment?.mimeType,
        attachmentSize: _attachment?.size,
      );
      if (!mounted) return;
      _replyController.clear();
      setState(() {
        _attachment = null;
        _sending = false;
      });
      await widget.onSent();
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _sending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final thread = widget.thread;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primaryBlue.withValues(alpha: .12),
                  child: const Icon(
                    Icons.person_rounded,
                    color: AppColors.primaryBlue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        thread.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (thread.phone.isNotEmpty)
                            StatusChip(
                              label: thread.phone,
                              color: AppColors.navy,
                            ),
                          if (thread.hasStudentApp)
                            const StatusChip(
                              label: 'Ilovadan',
                              color: AppColors.successGreen,
                            ),
                          if (thread.hasTelegram)
                            const StatusChip(
                              label: 'Telegramdan',
                              color: AppColors.primaryBlue,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (thread.unreadCount > 0)
                  OutlinedButton.icon(
                    onPressed: widget.onMarkRead,
                    icon: const Icon(Icons.done_all_rounded, size: 18),
                    label: const Text('O‘qildi'),
                  ),
              ],
            ),
          ),
          Expanded(
            child: ColoredBox(
              color: AppColors.background.withValues(alpha: .6),
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: thread.messages.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = thread.messages[index];
                  return _AdminConversationMessageTile(
                    message: item,
                    onOpenAttachment: widget.onOpenAttachment,
                  );
                },
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: const Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_error != null) ...[
                  Text(
                    _error!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.errorRed,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                if (_attachment != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withValues(alpha: .07),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.primaryBlue.withValues(alpha: .16),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _adminAttachmentIcon(_attachment!.messageKind),
                          color: AppColors.primaryBlue,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _attachment!.fileName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: _sending
                              ? null
                              : () => setState(() => _attachment = null),
                          icon: const Icon(Icons.close_rounded, size: 18),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final kind in const [
                      ('image', Icons.image_outlined),
                      ('video', Icons.videocam_outlined),
                      ('video_note', Icons.radio_button_checked_rounded),
                      ('voice', Icons.mic_none_rounded),
                      ('document', Icons.attach_file_rounded),
                    ])
                      OutlinedButton.icon(
                        onPressed: _sending
                            ? null
                            : () => _pickAttachment(kind.$1),
                        icon: Icon(kind.$2, size: 17),
                        label: Text(_adminAttachmentLabel(kind.$1)),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _replyController,
                        enabled: !_sending,
                        minLines: 1,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          hintText: 'Javob yozing...',
                          prefixIcon: Icon(Icons.reply_rounded),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: _sending ? null : _sendReply,
                      icon: _sending
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded),
                      label: const Text('Yuborish'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminConversationMessageTile extends StatelessWidget {
  const _AdminConversationMessageTile({
    required this.message,
    required this.onOpenAttachment,
  });

  final AdminInboxMessage message;
  final ValueChanged<String> onOpenAttachment;

  @override
  Widget build(BuildContext context) {
    final isTelegram = message.source == 'telegram';
    final replied = message.adminReply?.trim().isNotEmpty == true;
    return LayoutBuilder(
      builder: (context, constraints) {
        final bubbleWidth = constraints.maxWidth < 720
            ? constraints.maxWidth
            : constraints.maxWidth * .72;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: bubbleWidth),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: message.isRead
                        ? Theme.of(context).colorScheme.surface
                        : AppColors.primaryBlue.withValues(alpha: .06),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(18),
                      topRight: Radius.circular(18),
                      bottomRight: Radius.circular(18),
                      bottomLeft: Radius.circular(6),
                    ),
                    border: Border.all(
                      color: message.isRead
                          ? AppColors.border
                          : AppColors.primaryBlue.withValues(alpha: .18),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          IconBadge(
                            icon: isTelegram
                                ? Icons.telegram_rounded
                                : Icons.support_agent_rounded,
                            color: isTelegram
                                ? AppColors.primaryBlue
                                : AppColors.successGreen,
                            size: 36,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  message.subject.isEmpty
                                      ? 'Yangi murojaat'
                                      : message.subject,
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    StatusChip(
                                      label: isTelegram
                                          ? 'Telegram bot'
                                          : 'Student ilovasi',
                                      color: isTelegram
                                          ? AppColors.primaryBlue
                                          : AppColors.successGreen,
                                    ),
                                    StatusChip(
                                      label: message.isRead
                                          ? 'Ko‘rildi'
                                          : 'Yangi',
                                      color: message.isRead
                                          ? AppColors.successGreen
                                          : AppColors.primaryBlue,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        message.body,
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(height: 1.45),
                      ),
                      if (message.hasAttachment) ...[
                        const SizedBox(height: 10),
                        if (message.isImage)
                          InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () =>
                                onOpenAttachment(message.attachmentUrl!),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.network(
                                message.attachmentUrl!,
                                height: 180,
                                width: 220,
                                fit: BoxFit.cover,
                              ),
                            ),
                          )
                        else
                          _AdminAttachmentLink(
                            onTap: () =>
                                onOpenAttachment(message.attachmentUrl!),
                            icon: _adminAttachmentIcon(message.messageKind),
                            label:
                                message.attachmentName?.trim().isNotEmpty ==
                                    true
                                ? message.attachmentName!
                                : _adminAttachmentLabel(message.messageKind),
                          ),
                      ],
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          StatusChip(
                            label: _formatPreciseAdminDateTime(
                              message.createdAt,
                            ),
                            color: AppColors.navy,
                          ),
                          if (message.adminReadAt != null)
                            StatusChip(
                              label:
                                  'Admin ko‘rdi: ${_formatPreciseAdminDateTime(message.adminReadAt!)}',
                              color: AppColors.successGreen,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (replied) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: bubbleWidth),
                  child: Container(
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
                          color: AppColors.primaryBlue.withValues(alpha: .18),
                          blurRadius: 14,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Admin javobi',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          message.adminReply!,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Colors.white, height: 1.45),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            if (message.repliedAt != null)
                              StatusChip(
                                label:
                                    'Yuborildi: ${_formatPreciseAdminDateTime(message.repliedAt!)}',
                                color: Colors.white,
                              ),
                            if (message.recipientReadAt != null)
                              StatusChip(
                                label:
                                    'Talaba o‘qidi: ${_formatPreciseAdminDateTime(message.recipientReadAt!)}',
                                color: AppColors.successGreen,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

String _notificationKindForItem(StudentNotification item) {
  final source = '${item.title} ${item.body}'.toLowerCase();
  if (source.contains('imtihon') || source.contains('eslatma')) {
    return 'Eslatma';
  }
  if (source.contains('texnik') ||
      source.contains('xavfsizlik') ||
      source.contains('parol')) {
    return 'Ogohlantirish';
  }
  if (source.contains('sertifikat') || source.contains('taklif')) {
    return 'Taklif';
  }
  return 'Yangilik';
}

String _notificationAudienceForItem(StudentNotification item) {
  if (item.targetUserId != null) return 'Shaxsiy javob';
  if ((item.deepLink ?? '').isNotEmpty) return 'Maqsadli guruh';
  return 'Barcha talabalar';
}

double _notificationOpenRate(StudentNotification item) {
  final hash = item.id.codeUnits.fold<int>(0, (sum, unit) => sum + unit);
  final base = 0.62 + (hash % 32) / 100;
  return base.clamp(0.0, 0.98);
}

Color _notificationKindColor(String kind) {
  switch (kind) {
    case 'Eslatma':
      return AppColors.violet;
    case 'Ogohlantirish':
      return AppColors.errorRed;
    case 'Taklif':
      return AppColors.amber;
    default:
      return AppColors.primaryBlue;
  }
}

IconData _notificationIconForKind(String kind) {
  switch (kind) {
    case 'Eslatma':
      return Icons.schedule_send_rounded;
    case 'Ogohlantirish':
      return Icons.warning_amber_rounded;
    case 'Taklif':
      return Icons.card_giftcard_rounded;
    default:
      return Icons.notifications_active_rounded;
  }
}

class _CertificatePage extends StatelessWidget {
  const _CertificatePage();

  @override
  Widget build(BuildContext context) {
    return _TwoColumnAdminPage(
      title: 'Sertifikatlarni boshqarish',
      subtitle:
          'Sertifikat yaratish, yuklab olish, yutuqlar va yakunlash dalillarini boshqarish.',
      left: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const IconBadge(
                  icon: Icons.workspace_premium_rounded,
                  color: AppColors.amber,
                  size: 60,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'LabProof Academy sertifikati',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const _ResultStat(label: 'Talaba', value: 'Azizbek Tursunov'),
            const _ResultStat(
              label: 'Modul',
              value: 'Elektr toki va zanjirlar',
            ),
            const _ResultStat(label: 'Yakuniy ball', value: '80%'),
            const _ResultStat(label: 'Sertifikat ID', value: 'LPA-2026-0012'),
          ],
        ),
      ),
      right: Column(
        children: [
          const _AdminMiniStats(
            rows: [
              ('Yaratilgan', '842'),
              ('Yuklab olingan', '696'),
              ('Ko‘rib chiqilmoqda', '23'),
            ],
          ),
          const SizedBox(height: 18),
          _AdminTable(
            compact: true,
            columns: const ['Talaba', 'Modul', 'Holat'],
            rows: const [
              ['Azizbek', 'Elektr toki', 'Tayyor'],
              ['Malika', 'Optika', 'Tayyor'],
              ['Jasur', 'Magnit maydon', 'Kutilmoqda'],
            ],
          ),
        ],
      ),
    );
  }
}

class _MediaLibraryPage extends StatelessWidget {
  const _MediaLibraryPage();

  @override
  Widget build(BuildContext context) {
    final media = const [
      ('Zanjir sxemasi', Icons.image_rounded, AppColors.primaryBlue),
      ('om_qonuni.pdf', Icons.picture_as_pdf_rounded, AppColors.errorRed),
      (
        'Laboratoriya videosi 08:45',
        Icons.video_file_rounded,
        AppColors.violet,
      ),
      ('Formulalar jadvali', Icons.functions_rounded, AppColors.successGreen),
      (
        'Xavfsizlik yo‘riqnomasi',
        Icons.health_and_safety_rounded,
        AppColors.amber,
      ),
      ('Resurslar to‘plami', Icons.folder_zip_rounded, AppColors.cyan),
    ];

    return _ManagementPageShell(
      title: 'Media kutubxona',
      subtitle: 'Rasmlar, PDFlar, videolar va laboratoriya resurslari.',
      primaryAction: 'Media yuklash',
      onPrimaryAction: () => _showAdminDialog(context, 'Media yuklash'),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final count = constraints.maxWidth > 1100
              ? 4
              : constraints.maxWidth > 760
              ? 3
              : 2;
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: media.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: count,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.3,
            ),
            itemBuilder: (context, index) {
              final item = media[index];
              return AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconBadge(icon: item.$2, color: item.$3, size: 52),
                    const Spacer(),
                    Text(
                      item.$1,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      'Yangilangan: 22.05.2026',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _RolesPage extends StatelessWidget {
  const _RolesPage();

  @override
  Widget build(BuildContext context) {
    return _ManagementPageShell(
      title: 'Rollar va ruxsatlar',
      subtitle:
          'Admin, o‘qituvchi va student huquqlarini RBAC-ready API uchun boshqarish.',
      primaryAction: 'Rol yaratish',
      onPrimaryAction: () => _showAdminDialog(context, 'Rol yaratish'),
      child: Column(
        children: const [
          _PermissionCard(
            role: 'Admin',
            color: AppColors.primaryBlue,
            permissions: [
              'To‘liq platforma boshqaruvi',
              'Foydalanuvchilarni boshqarish',
              'Tizim sozlamalari',
            ],
          ),
          SizedBox(height: 14),
          _PermissionCard(
            role: 'Teacher',
            color: AppColors.successGreen,
            permissions: [
              'Modul yaratish',
              'Test tuzish',
              'Natijalarni ko‘rish',
            ],
          ),
          SizedBox(height: 14),
          _PermissionCard(
            role: 'Student',
            color: AppColors.violet,
            permissions: [
              'Darslarni o‘qish',
              'Test topshirish',
              'Sertifikat yuklab olish',
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingsPage extends StatelessWidget {
  const _SettingsPage({required this.themeMode, required this.onThemeChanged});

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;

  @override
  Widget build(BuildContext context) {
    final dark = themeMode == ThemeMode.dark;

    return _ManagementPageShell(
      title: 'Sozlamalar',
      subtitle:
          'Qorong‘i rejim, til, xavfsizlik va platforma ko‘rinishini sozlash.',
      primaryAction: 'O‘zgarishlarni saqlash',
      onPrimaryAction: () => _showAdminDialog(context, 'Sozlamalar saqlandi'),
      child: Column(
        children: [
          AppCard(
            child: Column(
              children: [
                _SettingsSwitchRow(
                  icon: Icons.dark_mode_rounded,
                  label: 'Qorong‘i rejim',
                  value: dark,
                  onChanged: (value) =>
                      onThemeChanged(value ? ThemeMode.dark : ThemeMode.light),
                ),
                const _SettingsSwitchRow(
                  icon: Icons.security_rounded,
                  label: 'JWT sessiya himoyasi',
                  value: true,
                ),
                const _SettingsSwitchRow(
                  icon: Icons.lock_rounded,
                  label: 'Rolga asoslangan ruxsatlar',
                  value: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const _AdminMiniStats(
            rows: [
              ('Til', 'O‘zbek'),
              ('API rejimi', 'REST-ready'),
              ('Autentifikatsiya', 'JWT'),
              ('Arxitektura', 'Clean Architecture'),
            ],
          ),
        ],
      ),
    );
  }
}

class _ManagementPageShell extends StatelessWidget {
  const _ManagementPageShell({
    required this.title,
    required this.subtitle,
    required this.primaryAction,
    required this.onPrimaryAction,
    required this.child,
  });

  final String title;
  final String subtitle;
  final String primaryAction;
  final VoidCallback onPrimaryAction;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 980;
          final spacing = _adminSectionSpacing(constraints.maxWidth);
          final titleBlock = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
            ],
          );
          final actionButton = FilledButton.icon(
            onPressed: onPrimaryAction,
            icon: const Icon(Icons.add_rounded),
            label: Text(primaryAction),
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (stacked) ...[
                titleBlock,
                SizedBox(height: spacing * .7),
                Align(
                  alignment: Alignment.centerLeft,
                  child: constraints.maxWidth < 560
                      ? SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: onPrimaryAction,
                            icon: const Icon(Icons.add_rounded),
                            label: Text(primaryAction),
                          ),
                        )
                      : actionButton,
                ),
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: titleBlock),
                    SizedBox(width: spacing),
                    actionButton,
                  ],
                ),
              SizedBox(height: spacing),
              child,
            ],
          );
        },
      ),
    );
  }
}

class _TwoColumnAdminPage extends StatelessWidget {
  const _TwoColumnAdminPage({
    required this.title,
    required this.subtitle,
    required this.left,
    required this.right,
  });

  final String title;
  final String subtitle;
  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(title: title, subtitle: subtitle),
          SizedBox(
            height: _adminSectionSpacing(MediaQuery.sizeOf(context).width),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 1120) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 6, child: left),
                    SizedBox(width: _adminSectionSpacing(constraints.maxWidth)),
                    Expanded(flex: 4, child: right),
                  ],
                );
              }
              return Column(
                children: [
                  left,
                  SizedBox(height: _adminSectionSpacing(constraints.maxWidth)),
                  right,
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AdminTable extends StatelessWidget {
  const _AdminTable({
    required this.columns,
    required this.rows,
    this.compact = false,
    this.rowMinHeight,
    this.rowMaxHeight,
    this.columnSpacing,
    this.minWidth,
  });

  final List<String> columns;
  final List<List<Object>> rows;
  final bool compact;
  final double? rowMinHeight;
  final double? rowMaxHeight;
  final double? columnSpacing;
  final double? minWidth;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF1F2937) : AppColors.border,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final estimatedWidth = columns.fold<double>(
            80,
            (width, _) => width + (compact ? 128 : 152),
          );
          final tableWidth = math.max(
            constraints.maxWidth,
            minWidth ?? estimatedWidth,
          );

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: tableWidth),
              child: Theme(
                data: Theme.of(context).copyWith(
                  dividerColor: isDark
                      ? const Color(0xFF1F2937)
                      : AppColors.border,
                ),
                child: DataTable(
                  horizontalMargin: 18,
                  columnSpacing: columnSpacing ?? (compact ? 22 : 28),
                  headingRowColor: WidgetStatePropertyAll(
                    isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  ),
                  headingRowHeight: compact ? 42 : 54,
                  dataRowMinHeight: rowMinHeight ?? (compact ? 48 : 58),
                  dataRowMaxHeight: rowMaxHeight ?? (compact ? 54 : 66),
                  headingTextStyle: TextStyle(
                    color: isDark ? Colors.white : AppColors.navy,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                  dataTextStyle: TextStyle(
                    color: isDark ? const Color(0xFFE5E7EB) : AppColors.navy,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  columns: columns
                      .map(
                        (column) => DataColumn(
                          label: Text(
                            column,
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  rows: rows
                      .map(
                        (row) => DataRow(
                          cells: row
                              .map((cell) => DataCell(_TableCell(value: cell)))
                              .toList(),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TableCell extends StatelessWidget {
  const _TableCell({required this.value});

  final Object value;

  @override
  Widget build(BuildContext context) {
    if (value is Widget) return value as Widget;
    final stringValue = value.toString();
    final lower = stringValue.toLowerCase();
    if (lower.contains('view') ||
        lower.contains('edit') ||
        lower.contains('delete')) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.visibility_outlined, size: 17, color: AppColors.muted),
          SizedBox(width: 9),
          Icon(Icons.edit_outlined, size: 17, color: AppColors.primaryBlue),
          SizedBox(width: 9),
          Icon(
            Icons.delete_outline_rounded,
            size: 17,
            color: AppColors.errorRed,
          ),
        ],
      );
    }

    if (['faol', 'ready', 'yaxshi'].contains(lower)) {
      return const StatusChip(label: 'Faol', color: AppColors.successGreen);
    }

    if (['locked', 'pending'].contains(lower)) {
      return const StatusChip(label: 'Yopiq', color: AppColors.amber);
    }

    if (lower.contains('qoniqarsiz')) {
      return const StatusChip(label: 'Qoniqarsiz', color: AppColors.errorRed);
    }

    if (lower.contains('o‘rtacha')) {
      return const StatusChip(label: 'O‘rtacha', color: AppColors.amber);
    }

    if (stringValue.endsWith('%')) {
      final parsed = int.tryParse(stringValue.replaceAll('%', '')) ?? 0;
      return SizedBox(
        width: 94,
        child: Row(
          children: [
            Expanded(
              child: ProgressLine(
                value: parsed / 100,
                height: 5,
                color: parsed >= 70
                    ? AppColors.successGreen
                    : AppColors.primaryBlue,
              ),
            ),
            const SizedBox(width: 8),
            Text(stringValue, maxLines: 1, softWrap: false),
          ],
        ),
      );
    }

    return Text(
      stringValue,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.filters});

  final List<String> filters;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          const Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Yozuvlarni qidirish...',
                prefixIcon: Icon(Icons.search_rounded),
                contentPadding: EdgeInsets.symmetric(vertical: 11),
              ),
            ),
          ),
          const SizedBox(width: 12),
          ...filters
              .take(3)
              .map(
                (filter) => Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: _DropdownPill(label: filter),
                ),
              ),
        ],
      ),
    );
  }
}

class _Pagination extends StatelessWidget {
  const _Pagination();

  void _notify(BuildContext context, String message) {
    _showAdminSnack(context, message);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        OutlinedButton(
          onPressed: () => _notify(context, 'Oldingi sahifa mavjud emas.'),
          child: const Text('Oldingi'),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: () => _notify(context, '1-sahifa tanlangan.'),
          child: const Text('1'),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: () =>
              _notify(context, '2-sahifa uchun real ma’lumot kerak.'),
          child: const Text('2'),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: () =>
              _notify(context, 'Keyingi sahifa hozircha mavjud emas.'),
          child: const Text('Keyingi'),
        ),
      ],
    );
  }
}

class _DropdownPill extends StatelessWidget {
  const _DropdownPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF334155)
              : AppColors.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(width: 6),
          const Icon(Icons.keyboard_arrow_down_rounded, size: 16),
        ],
      ),
    );
  }
}

class _TopModulesCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle(title: 'Eng faol modullar'),
          const SizedBox(height: 14),
          ...MockAcademyRepository.modules
              .take(4)
              .map(
                (module) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Text(
                        '${module.order}',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(width: 14),
                      const IconBadge(
                        icon: Icons.science_rounded,
                        color: AppColors.primaryBlue,
                        size: 34,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          module.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      Text(
                        '${module.studentCount} talaba',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _RecentUsersCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle(title: 'So‘nggi foydalanuvchilar'),
          const SizedBox(height: 14),
          ...MockAcademyRepository.studentRecords.map(
            (student) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.primaryBlue.withValues(
                      alpha: .12,
                    ),
                    child: Text(student.name.characters.first),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          student.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          student.email,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  StatusChip(
                    label: student.status,
                    color: student.score >= 70
                        ? AppColors.successGreen
                        : AppColors.errorRed,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle({required this.title, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        ?action,
      ],
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.color, required this.label, this.value = ''});

  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final hasValue = value.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontSize: 13),
            ),
          ),
          if (hasValue)
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
        ],
      ),
    );
  }
}

class _DashboardInlinePill extends StatelessWidget {
  const _DashboardInlinePill({
    required this.label,
    required this.value,
    this.color = AppColors.primaryBlue,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: .12)),
      ),
      child: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.muted,
            fontWeight: FontWeight.w600,
          ),
          children: [
            TextSpan(text: '$label: '),
            TextSpan(
              text: value,
              style: TextStyle(color: color, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: const [
          Icon(Icons.format_bold_rounded, size: 18),
          SizedBox(width: 14),
          Icon(Icons.format_italic_rounded, size: 18),
          SizedBox(width: 14),
          Icon(Icons.format_list_bulleted_rounded, size: 18),
          SizedBox(width: 14),
          Icon(Icons.functions_rounded, size: 18),
          SizedBox(width: 14),
          Icon(Icons.table_chart_rounded, size: 18),
        ],
      ),
    );
  }
}

class _UploadBox extends StatelessWidget {
  const _UploadBox({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      borderColor: color.withValues(alpha: .28),
      child: Column(
        children: [
          IconBadge(icon: icon, color: color, size: 64),
          const SizedBox(height: 18),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                final result = await FilePicker.platform.pickFiles(
                  allowMultiple: false,
                  withData: false,
                );
                if (!context.mounted) return;
                if (result == null || result.files.isEmpty) {
                  _showAdminSnack(context, 'Fayl tanlanmadi.');
                  return;
                }
                final fileName = result.files.first.name;
                _showAdminSnack(context, '$fileName tanlandi.');
              },
              icon: const Icon(Icons.cloud_upload_rounded),
              label: const Text('Fayl tanlash'),
            ),
          ),
        ],
      ),
    );
  }
}

class _FileListCard extends StatelessWidget {
  const _FileListCard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Fayllarni boshqarish',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 14),
          ...const [
            _FileRow(
              name: 'om_qonuni.pdf',
              size: '2.4 MB',
              icon: Icons.picture_as_pdf_rounded,
              color: AppColors.errorRed,
            ),
            _FileRow(
              name: 'formulalar.docx',
              size: '820 KB',
              icon: Icons.description_rounded,
              color: AppColors.primaryBlue,
            ),
            _FileRow(
              name: 'laboratoriya_note.txt',
              size: '14 KB',
              icon: Icons.notes_rounded,
              color: AppColors.successGreen,
            ),
          ],
        ],
      ),
    );
  }
}

class _FileRow extends StatelessWidget {
  const _FileRow({
    required this.name,
    required this.size,
    required this.icon,
    required this.color,
  });

  final String name;
  final String size;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          IconBadge(icon: icon, color: color, size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: Theme.of(context).textTheme.titleMedium),
                Text(size, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Fayl amallari',
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              showDragHandle: true,
              builder: (sheetContext) => SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.visibility_outlined),
                      title: const Text('Ko‘rish'),
                      subtitle: Text(name),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        _showAdminSnack(
                          context,
                          '$name ko‘rish oynasi ochildi.',
                        );
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.download_rounded),
                      title: const Text('Yuklab olish'),
                      subtitle: Text(size),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        _showAdminSnack(
                          context,
                          '$name yuklab olishga tayyor.',
                        );
                      },
                    ),
                    ListTile(
                      leading: const Icon(
                        Icons.delete_outline_rounded,
                        color: AppColors.errorRed,
                      ),
                      title: const Text('O‘chirish'),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        _showAdminSnack(
                          context,
                          '$name o‘chirish uchun tanlandi.',
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            icon: const Icon(Icons.more_vert_rounded),
          ),
        ],
      ),
    );
  }
}

class _AdminMiniStats extends StatelessWidget {
  const _AdminMiniStats({required this.rows});

  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: rows
            .map(
              (row) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 9),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        row.$1,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    Text(row.$2, style: Theme.of(context).textTheme.titleLarge),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _SliderSetting extends StatelessWidget {
  const _SliderSetting({
    required this.label,
    required this.value,
    required this.display,
  });

  final String label;
  final double value;
  final String display;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(display, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          Slider(
            value: value,
            onChanged: (_) => _showAdminSnack(
              context,
              '$label ko‘rsatkichi hisobot ma’lumotlaridan avtomatik keladi.',
            ),
          ),
        ],
      ),
    );
  }
}

class _BarMetric extends StatelessWidget {
  const _BarMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                '${(value * 100).round()}%',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 8),
          ProgressLine(value: value, color: color),
        ],
      ),
    );
  }
}

class _TimelineCard extends StatelessWidget {
  const _TimelineCard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent campaigns',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 14),
          ...MockAcademyRepository.activities.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  IconBadge(icon: item.icon, color: item.color, size: 36),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          item.subtitle,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({
    required this.role,
    required this.color,
    required this.permissions,
  });

  final String role;
  final Color color;
  final List<String> permissions;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBadge(icon: Icons.verified_user_rounded, color: color, size: 52),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(role, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: permissions
                      .map((item) => StatusChip(label: item, color: color))
                      .toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionMatrixCard extends StatelessWidget {
  const _PermissionMatrixCard();

  @override
  Widget build(BuildContext context) {
    const columns = ['Modul', 'Super', 'Admin', 'O‘qituvchi', 'Talaba'];
    const rows = [
      ('Dashboard', [true, true, true, true]),
      ('Modullar', [true, true, true, false]),
      ('Mavzular', [true, true, true, false]),
      ('PDF / Text', [true, true, true, false]),
      ('Videolar', [true, true, true, false]),
      ('Testlar', [true, true, true, true]),
      ('Yakuniy imtihonlar', [true, true, true, false]),
      ('Talabalar', [true, true, true, false]),
      ('Tahlillar', [true, true, true, false]),
      ('Xabarnomalar', [true, true, true, false]),
      ('Media kutubona', [true, true, true, false]),
      ('Sozlamalar', [true, true, false, false]),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        horizontalMargin: 0,
        columnSpacing: 18,
        headingTextStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w800,
          color: AppColors.navy,
        ),
        columns: columns
            .map((column) => DataColumn(label: Text(column)))
            .toList(),
        rows: rows
            .map(
              (row) => DataRow(
                cells: [
                  DataCell(Text(row.$1)),
                  ...row.$2.map(
                    (allowed) => DataCell(
                      Icon(
                        allowed ? Icons.check_rounded : Icons.remove_rounded,
                        size: 18,
                        color: allowed
                            ? AppColors.successGreen
                            : AppColors.muted,
                      ),
                    ),
                  ),
                ],
              ),
            )
            .toList(),
      ),
    );
  }
}

class _SettingsSwitchRow extends StatelessWidget {
  const _SettingsSwitchRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          IconBadge(icon: icon, color: AppColors.primaryBlue, size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.titleMedium),
          ),
          Switch(value: value, onChanged: onChanged ?? (_) {}),
        ],
      ),
    );
  }
}

class _SettingsFormRow extends StatelessWidget {
  const _SettingsFormRow({
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
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stack = constraints.maxWidth < 720;
          final label = Row(
            children: [
              IconBadge(icon: icon, color: AppColors.primaryBlue, size: 38),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          );
          if (stack) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [label, const SizedBox(height: 12), child],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(flex: 4, child: label),
              const SizedBox(width: 18),
              Expanded(flex: 6, child: child),
            ],
          );
        },
      ),
    );
  }
}

class _SettingsInputShell extends StatelessWidget {
  const _SettingsInputShell({required this.text, this.minLines = 1});

  final String text;
  final int minLines;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        text,
        maxLines: math.max(minLines, 1),
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleSmall,
      ),
    );
  }
}

class _SettingsSelectShell extends StatelessWidget {
  const _SettingsSelectShell({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return _SettingsInputShell(text: '$text     ⌄');
  }
}

class _SettingsFileShell extends StatelessWidget {
  const _SettingsFileShell({required this.fileName});

  final String fileName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const IconBadge(
            icon: Icons.school_rounded,
            color: AppColors.primaryBlue,
            size: 38,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              fileName,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          OutlinedButton(onPressed: () {}, child: const Text('O‘zgartirish')),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'O‘chirish',
            onPressed: () {},
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: AppColors.errorRed,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsResourceChart extends StatelessWidget {
  const _SettingsResourceChart({
    required this.label,
    required this.value,
    required this.color,
    required this.values,
  });

  final String label;
  final String value;
  final Color color;
  final List<double> values;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          SizedBox(
            width: 126,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: EmptyChart(values: values, color: color, height: 72),
          ),
        ],
      ),
    );
  }
}

class _SettingsBigNumber extends StatelessWidget {
  const _SettingsBigNumber({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 3),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _SettingsChoiceRow extends StatelessWidget {
  const _SettingsChoiceRow();

  @override
  Widget build(BuildContext context) {
    Widget choice({
      required IconData icon,
      required String title,
      required String subtitle,
      required bool selected,
    }) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primaryBlue.withValues(alpha: .06)
                : null,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.primaryBlue : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              IconBadge(icon: icon, color: AppColors.primaryBlue, size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleSmall),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        choice(
          icon: Icons.backup_rounded,
          title: 'To‘liq zaxira',
          subtitle: 'Barcha ma’lumotlar',
          selected: true,
        ),
        const SizedBox(width: 10),
        choice(
          icon: Icons.dataset_rounded,
          title: 'Faqat ma’lumotlar bazasi',
          subtitle: 'Faqat DB zaxirasi',
          selected: false,
        ),
      ],
    );
  }
}

class _WorldMapPreview extends StatelessWidget {
  const _WorldMapPreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Stack(
        children: [
          Center(
            child: Icon(
              Icons.public_rounded,
              color: AppColors.border.withValues(alpha: .9),
              size: 112,
            ),
          ),
          const Positioned(
            left: 64,
            top: 64,
            child: Icon(Icons.circle, size: 12, color: AppColors.primaryBlue),
          ),
          const Positioned(
            right: 92,
            top: 72,
            child: Icon(Icons.circle, size: 12, color: AppColors.successGreen),
          ),
          const Positioned(
            right: 44,
            bottom: 42,
            child: Icon(Icons.circle, size: 12, color: AppColors.errorRed),
          ),
        ],
      ),
    );
  }
}

class _SettingsPaymentRow extends StatelessWidget {
  const _SettingsPaymentRow({
    required this.name,
    required this.fee,
    required this.color,
  });

  final String name;
  final String fee;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          IconBadge(icon: Icons.payment_rounded, color: color, size: 34),
          const SizedBox(width: 10),
          Expanded(
            child: Text(name, style: Theme.of(context).textTheme.titleSmall),
          ),
          const StatusChip(label: 'Ulangan', color: AppColors.successGreen),
          const SizedBox(width: 12),
          Text(
            fee,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _SubscriptionPlansPreview extends StatelessWidget {
  const _SubscriptionPlansPreview();

  @override
  Widget build(BuildContext context) {
    const plans = [
      ('Basic', '49,000', '10'),
      ('Premium', '99,000', 'Cheksiz'),
      ('VIP', '199,000', 'Cheksiz'),
    ];
    return Row(
      children: plans.map((plan) {
        final selected = plan.$1 == 'Premium';
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? AppColors.primaryBlue : AppColors.border,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(plan.$1, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 10),
                Text(
                  '${plan.$2} so‘m',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Kurslar: ${plan.$3}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 14),
                const StatusChip(label: 'Faol', color: AppColors.successGreen),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _SettingsInfoRow extends StatelessWidget {
  const _SettingsInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
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
      padding: const EdgeInsets.symmetric(vertical: 8),
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

class _VideoGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: .08)
      ..strokeWidth = 1;

    for (var x = 0.0; x < size.width; x += 38) {
      canvas.drawLine(Offset(x, 0), Offset(x + 90, size.height), paint);
    }

    for (var y = 0.0; y < size.height; y += 34) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y + 26), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

void _showAdminDialog(BuildContext context, String title) {
  showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(title),
        content: const SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: InputDecoration(
                  labelText: 'Nomi',
                  prefixIcon: Icon(Icons.edit_rounded),
                ),
              ),
              SizedBox(height: 12),
              TextField(
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Tavsif',
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Bekor qilish'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Saqlash'),
          ),
        ],
      );
    },
  );
}
