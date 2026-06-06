import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/app_colors.dart';
import '../../data/models/academy_models.dart';
import '../../data/repositories/supabase_academy_repository.dart';

class TwitterStyleCommunity extends StatefulWidget {
  const TwitterStyleCommunity({
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
  State<TwitterStyleCommunity> createState() => _TwitterStyleCommunityState();
}

class _TwitterStyleCommunityState extends State<TwitterStyleCommunity> {
  final _repository = const SupabaseAcademyRepository();
  List<CommunityPost> _posts = [];
  final Map<String, List<CommunityReply>> _localRepliesByPostId = {};
  bool _isLoading = true;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    setState(() => _isLoading = true);
    try {
      final posts = await _repository.loadTwitterPosts();
      if (mounted) {
        setState(() {
          _posts = posts;
          _isLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showMessage('Community postlari yuklanmadi.');
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _showCreateTweetDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _CreateTweetDialog(
        onTweetCreated: (content, attachments) async {
          final localPost = _createLocalPost(content, attachments);
          if (mounted) {
            setState(() {
              _posts = [localPost, ..._posts];
              _isLoading = false;
            });
            Navigator.pop(sheetContext);
            _showMessage('Post qo‘shildi!');
          }

          unawaited(
            _repository
                .createTwitterPost(content: content, attachments: attachments)
                .then((_) {
                  if (mounted) _loadPosts();
                })
                .catchError((_) {
                  if (mounted) {
                    _showMessage('Post hozircha lokal ko‘rinishda saqlandi.');
                  }
                }),
          );
        },
      ),
    );
  }

  CommunityPost _createLocalPost(String content, List<String> attachments) {
    final profile = widget.data.profile;
    return CommunityPost(
      id: 'local-${DateTime.now().microsecondsSinceEpoch}',
      authorId: profile.id,
      authorName: profile.fullName.trim().isEmpty
          ? 'Student'
          : profile.fullName.trim(),
      authorAvatar: profile.avatarUrl,
      authorBadge: 'Student',
      content: content,
      likes: 0,
      dislikes: 0,
      reposts: 0,
      replies: 0,
      isLiked: false,
      isDisliked: false,
      isReposted: false,
      isBookmarked: false,
      createdAt: DateTime.now(),
      attachments: attachments,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Community',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Savol, fikr va tajribalarni guruh bilan ulashing',
                    style: TextStyle(
                      color: isDark ? Colors.white60 : const Color(0xFF64748B),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            _CircleIconButton(
              tooltip: 'Yangilash',
              onPressed: _loadPosts,
              icon: const Icon(Icons.refresh_rounded),
            ),
            const SizedBox(width: 16),
            Badge.count(
              isLabelVisible: widget.notificationCount > 0,
              count: widget.notificationCount,
              child: _CircleIconButton(
                tooltip: 'Bildirishnomalar',
                onPressed: widget.onNotifications,
                icon: const Icon(Icons.notifications_none_rounded),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _TweetComposer(onTweet: _showCreateTweetDialog),
        const SizedBox(height: 12),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 36),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_posts.isEmpty)
          _EmptyState(
            icon: Icons.forum_outlined,
            title: 'Hali post yo‘q',
            message: 'Birinchi postni siz yozing!',
          )
        else ...[
          for (final post in _posts)
            _TweetCard(
              post: post,
              onLike: () => _handleReaction(post.id, 'like'),
              onDislike: () => _handleReaction(post.id, 'dislike'),
              onRepost: () => _handleRepost(post.id),
              onReply: () => _showReplyDialog(post),
              onShare: () => _handleShare(post),
              onBookmark: () => _handleBookmark(post.id),
              onMore: () => _showPostOptions(post),
            ),
          if (_isLoadingMore)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            const SizedBox(height: 100),
        ],
      ],
    );
  }

  Future<void> _handleReaction(String postId, String reactionType) async {
    final index = _posts.indexWhere((item) => item.id == postId);
    if (index == -1) return;
    final original = _posts[index];
    final isLike = reactionType == 'like';
    final removeReaction = isLike ? original.isLiked : original.isDisliked;
    final next = _copyPost(
      original,
      likes: isLike
          ? original.likes + (removeReaction ? -1 : 1)
          : original.likes + (original.isLiked ? -1 : 0),
      dislikes: !isLike
          ? original.dislikes + (removeReaction ? -1 : 1)
          : original.dislikes + (original.isDisliked ? -1 : 0),
      isLiked: isLike && !removeReaction,
      isDisliked: !isLike && !removeReaction,
    );
    setState(() => _posts[index] = next);

    if (postId.startsWith('local-')) return;

    try {
      if (isLike) {
        await _repository.toggleTwitterLike(postId);
      } else {
        await _repository.toggleTwitterDislike(postId);
      }
      await _loadPosts();
    } catch (error) {
      if (!mounted) return;
      setState(() => _posts[index] = original);
      _showMessage('Reaksiya saqlanmadi.');
    }
  }

  Future<void> _handleRepost(String postId) async {
    final index = _posts.indexWhere((item) => item.id == postId);
    if (index == -1) return;
    final original = _posts[index];
    final nextIsReposted = !original.isReposted;
    setState(() {
      _posts[index] = _copyPost(
        original,
        reposts: original.reposts + (nextIsReposted ? 1 : -1),
        isReposted: nextIsReposted,
      );
    });

    if (postId.startsWith('local-')) return;

    try {
      await _repository.repostTweet(postId);
      await _loadPosts();
    } catch (_) {
      if (!mounted) return;
      setState(() => _posts[index] = original);
      _showMessage('Repost saqlanmadi.');
    }
  }

  Future<void> _handleBookmark(String postId) async {
    final index = _posts.indexWhere((item) => item.id == postId);
    if (index == -1) return;
    final original = _posts[index];
    setState(() {
      _posts[index] = _copyPost(original, isBookmarked: !original.isBookmarked);
    });

    if (postId.startsWith('local-')) return;

    try {
      await _repository.toggleBookmark(postId);
      await _loadPosts();
    } catch (_) {
      if (!mounted) return;
      setState(() => _posts[index] = original);
      _showMessage('Xatcho‘p saqlanmadi.');
    }
  }

  Future<void> _handleDeletePost(CommunityPost post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Post o‘chirilsinmi?'),
        content: const Text('Bu amalni qaytarib bo‘lmaydi.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Bekor qilish'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.errorRed),
            child: const Text('O‘chirish'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final originalPosts = _posts;
    setState(
      () => _posts = _posts.where((item) => item.id != post.id).toList(),
    );
    _localRepliesByPostId.remove(post.id);

    if (post.id.startsWith('local-')) {
      _showMessage('Post o‘chirildi.');
      return;
    }

    try {
      await _repository.deleteTwitterPost(post.id);
      _showMessage('Post o‘chirildi.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _posts = originalPosts);
      _showMessage('Post o‘chirilmadi.');
    }
  }

  Future<void> _handleEditPost(CommunityPost post) async {
    final controller = TextEditingController(text: post.content);
    final updated = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF020617) : Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      _CircleIconButton(
                        tooltip: 'Yopish',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Postni tahrirlash',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () =>
                            Navigator.pop(context, controller.text.trim()),
                        child: const Text('Saqlash'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    minLines: 4,
                    maxLines: 8,
                    maxLength: 280,
                    decoration: InputDecoration(
                      hintText: 'Post matni...',
                      filled: true,
                      fillColor: isDark
                          ? Colors.white.withValues(alpha: .06)
                          : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide(
                          color: AppColors.studentPrimary.withValues(
                            alpha: .22,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    controller.dispose();
    if (updated == null || updated.isEmpty || updated == post.content) return;

    final index = _posts.indexWhere((item) => item.id == post.id);
    if (index == -1) return;
    final original = _posts[index];
    final edited = _copyPost(original, content: updated);
    setState(() => _posts[index] = edited);

    if (post.id.startsWith('local-')) {
      _showMessage('Post tahrirlandi.');
      return;
    }

    try {
      await _repository.updateTwitterPost(post.id, content: updated);
      _showMessage('Post tahrirlandi.');
      await _loadPosts();
    } catch (_) {
      if (!mounted) return;
      setState(() => _posts[index] = original);
      _showMessage('Post tahrirlanmadi.');
    }
  }

  Future<void> _handleShare(CommunityPost post) async {
    final shared = await _shareCommunityPost(context: context, post: post);
    if (shared == _CommunityShareResult.copied) {
      _showMessage('Ulashish bu qurilmada mavjud emas, post matni nusxalandi.');
    }
  }

  void _showPostOptions(CommunityPost post) {
    final isOwnPost =
        post.authorId == widget.data.profile.id || post.id.startsWith('local-');
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _PostOptionsSheet(
        post: post,
        canEdit: isOwnPost,
        canDelete: isOwnPost,
        onEdit: () => unawaited(_handleEditPost(post)),
        onDelete: () => unawaited(_handleDeletePost(post)),
        onShare: () => unawaited(_handleShare(post)),
        onBookmark: () => _handleBookmark(post.id),
      ),
    );
  }

  void _showReplyDialog(CommunityPost post) {
    final isLocalPost = post.id.startsWith('local-');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ReplyThreadDialog(
        post: post,
        initialReplies: _localRepliesByPostId[post.id] ?? const [],
        onLocalReplyCreated: (reply) {
          final replies = _localRepliesByPostId[post.id] ?? const [];
          _localRepliesByPostId[post.id] = [...replies, reply];
        },
        onPostChanged: (updatedPost) {
          final index = _posts.indexWhere((item) => item.id == post.id);
          if (index == -1 || !mounted) return;
          setState(() => _posts[index] = updatedPost);
        },
        onChanged: isLocalPost ? null : _loadPosts,
      ),
    ).whenComplete(() {
      if (!isLocalPost) _loadPosts();
    });
  }

  CommunityPost _copyPost(
    CommunityPost post, {
    String? content,
    int? likes,
    int? dislikes,
    int? reposts,
    int? replies,
    bool? isLiked,
    bool? isDisliked,
    bool? isReposted,
    bool? isBookmarked,
  }) {
    return CommunityPost(
      id: post.id,
      authorId: post.authorId,
      authorName: post.authorName,
      authorAvatar: post.authorAvatar,
      authorBadge: post.authorBadge,
      content: content ?? post.content,
      likes: math.max(0, likes ?? post.likes),
      dislikes: math.max(0, dislikes ?? post.dislikes),
      reposts: math.max(0, reposts ?? post.reposts),
      replies: math.max(0, replies ?? post.replies),
      isLiked: isLiked ?? post.isLiked,
      isDisliked: isDisliked ?? post.isDisliked,
      isReposted: isReposted ?? post.isReposted,
      isBookmarked: isBookmarked ?? post.isBookmarked,
      createdAt: post.createdAt,
      attachments: post.attachments,
      isPinned: post.isPinned,
      replyToPostId: post.replyToPostId,
      replyToPostAuthor: post.replyToPostAuthor,
    );
  }
}

enum _CommunityShareResult { opened, copied, dismissed }

String _communityShareText(CommunityPost post) {
  final author = post.authorName.trim().isEmpty ? 'Student' : post.authorName;
  return '$author LabProof Community’da yozdi:\n\n${post.content}';
}

Future<_CommunityShareResult> _shareCommunityPost({
  required BuildContext context,
  required CommunityPost post,
}) async {
  final shareText = _communityShareText(post);
  final box = context.findRenderObject() as RenderBox?;

  try {
    final result = await SharePlus.instance.share(
      ShareParams(
        text: shareText,
        title: 'LabProof Community',
        subject: 'LabProof Community posti',
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
        downloadFallbackEnabled: false,
      ),
    );

    if (result.status == ShareResultStatus.dismissed) {
      return _CommunityShareResult.dismissed;
    }
    if (result.status != ShareResultStatus.unavailable) {
      return _CommunityShareResult.opened;
    }
  } catch (_) {
    // Fall back below when the platform/browser cannot open a share sheet.
  }

  await Clipboard.setData(ClipboardData(text: shareText));
  return _CommunityShareResult.copied;
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.size = 48,
    this.iconSize = 26,
    this.backgroundColor,
    this.iconColor,
  });

  final Widget icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;
  final double iconSize;
  final Color? backgroundColor;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveBackground =
        backgroundColor ??
        (isDark
            ? Colors.white.withValues(alpha: .08)
            : const Color(0xFFF1F5F9));
    final effectiveIconColor =
        iconColor ?? (isDark ? Colors.white : const Color(0xFF0F172A));

    Widget child = SizedBox.square(
      dimension: size,
      child: Material(
        color: effectiveBackground,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: DefaultTextStyle(
            style: TextStyle(color: effectiveIconColor),
            child: IconTheme(
              data: IconThemeData(color: effectiveIconColor, size: iconSize),
              child: Center(child: icon),
            ),
          ),
        ),
      ),
    );

    if (tooltip != null) {
      child = Tooltip(message: tooltip!, child: child);
    }
    return child;
  }
}

class _MiniComposerIcon extends StatelessWidget {
  const _MiniComposerIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 28,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: .10),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }
}

class _TweetComposer extends StatelessWidget {
  const _TweetComposer({required this.onTweet});

  final VoidCallback onTweet;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTweet,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: .08)
                  : const Color(0xFFE2E8F0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? .18 : .04),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.studentPrimary,
                child: const Icon(Icons.person, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: .05)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Mavzu yuzasidan post yozing...',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade500,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _MiniComposerIcon(
                        icon: Icons.edit_note_rounded,
                        color: AppColors.studentPrimary,
                      ),
                      const SizedBox(width: 8),
                      _MiniComposerIcon(
                        icon: Icons.image_outlined,
                        color: AppColors.studentPink,
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
}

class _TweetCard extends StatelessWidget {
  const _TweetCard({
    required this.post,
    required this.onLike,
    required this.onDislike,
    required this.onRepost,
    required this.onReply,
    required this.onShare,
    required this.onBookmark,
    required this.onMore,
  });

  final CommunityPost post;
  final VoidCallback onLike;
  final VoidCallback onDislike;
  final VoidCallback onRepost;
  final VoidCallback onReply;
  final VoidCallback onShare;
  final VoidCallback onBookmark;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cardColor = isDark ? const Color(0xFF0F172A) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: .08)
        : const Color(0xFFE2E8F0);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? .18 : .04),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (post.isPinned)
            Row(
              children: [
                const Icon(
                  Icons.push_pin,
                  size: 16,
                  color: AppColors.studentPrimary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Pinned',
                  style: TextStyle(
                    color: AppColors.studentPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          if (post.replyToPostId != null)
            Row(
              children: [
                Text(
                  'Replying to',
                  style: TextStyle(
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  post.replyToPostAuthor ?? 'Unknown',
                  style: TextStyle(
                    color: AppColors.studentPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: post.authorAvatar.isNotEmpty
                    ? null
                    : AppColors.studentPrimary,
                backgroundImage: post.authorAvatar.isNotEmpty
                    ? NetworkImage(post.authorAvatar)
                    : null,
                child: post.authorAvatar.isEmpty
                    ? Text(
                        post.authorName.characters.first.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          post.authorName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF0F172A),
                            fontWeight: FontWeight.w900,
                            fontSize: 14.5,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '@${post.authorName.toLowerCase().replaceAll(' ', '')}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isDark
                                  ? Colors.grey.shade500
                                  : Colors.grey.shade500,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _getBadgeColor(
                              post.authorBadge,
                            ).withValues(alpha: .1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            post.authorBadge,
                            style: TextStyle(
                              color: _getBadgeColor(post.authorBadge),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '· ${post.timeAgo}',
                          style: TextStyle(
                            color: isDark
                                ? Colors.grey.shade500
                                : Colors.grey.shade500,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: onMore,
                          child: const Icon(Icons.more_horiz, size: 18),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            post.content,
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              fontSize: 15,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (post.attachments.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: post.attachments.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: EdgeInsets.only(
                      right: index < post.attachments.length - 1 ? 8 : 0,
                    ),
                    child: Container(
                      width: 100,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.grey.shade800
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.image,
                              color: AppColors.studentPrimary,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              post.attachments.length > 1
                                  ? '+${post.attachments.length}'
                                  : '',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 12),
          Divider(color: borderColor, height: 1),
          const SizedBox(height: 8),
          Row(
            children: [
              _ActionButton(
                icon: post.isLiked ? Icons.favorite : Icons.favorite_border,
                color: post.isLiked ? AppColors.errorRed : null,
                count: post.likes,
                label: 'Yoqdi',
                onTap: onLike,
              ),
              _ActionButton(
                icon: post.isDisliked
                    ? Icons.thumb_down_alt
                    : Icons.thumb_down_alt_outlined,
                color: post.isDisliked ? const Color(0xFF64748B) : null,
                count: post.dislikes,
                label: 'Yoqmadi',
                onTap: onDislike,
              ),
              _ActionButton(
                icon: Icons.mode_comment_outlined,
                count: post.replies,
                label: 'Izoh',
                onTap: onReply,
              ),
              _ActionButton(
                icon: post.isReposted ? Icons.repeat : Icons.repeat_outlined,
                color: post.isReposted ? AppColors.studentPrimary : null,
                count: post.reposts,
                label: 'Repost',
                onTap: onRepost,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getBadgeColor(String badge) {
    switch (badge.toLowerCase()) {
      case 'admin':
        return AppColors.errorRed;
      case 'mentor':
        return AppColors.studentPrimary;
      default:
        return Colors.grey;
    }
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.count,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final int count;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final effectiveColor =
        color ?? (isDark ? Colors.white70 : const Color(0xFF64748B));
    final backgroundColor = color != null
        ? effectiveColor.withValues(alpha: .12)
        : (isDark
              ? Colors.white.withValues(alpha: .04)
              : const Color(0xFFF8FAFC));

    return Tooltip(
      message: label,
      child: Padding(
        padding: const EdgeInsets.only(right: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: 34,
              child: Material(
                color: backgroundColor,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onTap,
                  child: Icon(icon, size: 18, color: effectiveColor),
                ),
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 5),
              Text(
                count.toString(),
                style: TextStyle(
                  color: effectiveColor,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PostOptionsSheet extends StatelessWidget {
  const _PostOptionsSheet({
    required this.post,
    required this.canEdit,
    required this.canDelete,
    required this.onEdit,
    required this.onDelete,
    required this.onShare,
    required this.onBookmark,
  });

  final CommunityPost post;
  final bool canEdit;
  final bool canDelete;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onShare;
  final VoidCallback onBookmark;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    void runAndClose(VoidCallback action) {
      Navigator.pop(context);
      Future.microtask(action);
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF020617) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 5,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: .18)
                    : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.studentPrimary,
                  child: Text(
                    post.authorName.characters.first.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    post.content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (canEdit)
              _PostOptionTile(
                icon: Icons.edit_rounded,
                label: 'Tahrirlash',
                color: AppColors.studentPrimary,
                onTap: () => runAndClose(onEdit),
              ),
            if (canDelete)
              _PostOptionTile(
                icon: Icons.delete_outline_rounded,
                label: 'O‘chirish',
                color: AppColors.errorRed,
                onTap: () => runAndClose(onDelete),
              ),
            _PostOptionTile(
              icon: Icons.ios_share_rounded,
              label: 'Ulashish',
              color: const Color(0xFF0EA5E9),
              onTap: () => runAndClose(onShare),
            ),
            _PostOptionTile(
              icon: post.isBookmarked
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
              label: post.isBookmarked ? 'Xatcho‘pdan olish' : 'Xatcho‘p',
              color: const Color(0xFFF59E0B),
              onTap: () => runAndClose(onBookmark),
            ),
          ],
        ),
      ),
    );
  }
}

class _PostOptionTile extends StatelessWidget {
  const _PostOptionTile({
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isDark
            ? Colors.white.withValues(alpha: .05)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: color == AppColors.errorRed ? color : null,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: isDark ? Colors.white54 : const Color(0xFF94A3B8),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CreateTweetDialog extends StatefulWidget {
  const _CreateTweetDialog({required this.onTweetCreated});

  final Function(String content, List<String> attachments) onTweetCreated;

  @override
  State<_CreateTweetDialog> createState() => _CreateTweetDialogState();
}

class _CreateTweetDialogState extends State<_CreateTweetDialog> {
  static const _stickers = [
    '🧪',
    '🔬',
    '🧫',
    '🧬',
    '💉',
    '✅',
    '⭐',
    '🔥',
    '💡',
    '👏',
    '🎯',
    '🏆',
  ];

  final _controller = TextEditingController();
  final List<TextEditingController> _pollControllers = [
    TextEditingController(),
    TextEditingController(),
  ];
  List<String> _attachments = [];
  bool _isPollEnabled = false;
  bool _isSubmitting = false;
  String _draftText = '';

  @override
  void dispose() {
    _controller.dispose();
    for (final controller in _pollControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImages() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
      );
      if (result != null) {
        setState(() {
          _attachments.addAll(
            result.files.map((file) => file.path ?? file.name),
          );
        });
      }
    } catch (e) {
      // Handle error
    }
  }

  void _insertSticker(String sticker) {
    final selection = _controller.selection;
    final source = _controller.text;
    final start = selection.start < 0 ? source.length : selection.start;
    final end = selection.end < 0 ? source.length : selection.end;
    final separator = source.isEmpty || source.substring(0, start).endsWith(' ')
        ? ''
        : ' ';
    final value = source.replaceRange(start, end, '$separator$sticker ');
    final offset = (start + separator.length + sticker.length + 1).clamp(
      0,
      value.length,
    );

    setState(() {
      _controller.value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: offset),
      );
      _draftText = value;
    });
  }

  void _showStickerPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF020617) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Sticker tanlang',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    _CircleIconButton(
                      tooltip: 'Yopish',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                      size: 42,
                      iconSize: 22,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final sticker in _stickers)
                      Material(
                        color: isDark
                            ? Colors.white.withValues(alpha: .06)
                            : const Color(0xFFF1F5F9),
                        shape: const CircleBorder(),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () {
                            Navigator.pop(context);
                            _insertSticker(sticker);
                          },
                          child: SizedBox.square(
                            dimension: 56,
                            child: Center(
                              child: Text(
                                sticker,
                                style: const TextStyle(fontSize: 27),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _togglePoll() {
    setState(() => _isPollEnabled = !_isPollEnabled);
  }

  void _addPollOption() {
    if (_pollControllers.length >= 4) return;
    setState(() => _pollControllers.add(TextEditingController()));
  }

  void _removePollOption(int index) {
    if (_pollControllers.length <= 2) return;
    final controller = _pollControllers.removeAt(index);
    controller.dispose();
    setState(() {});
  }

  List<String> get _pollOptions {
    if (!_isPollEnabled) return const [];
    return _pollControllers
        .map((controller) => controller.text.trim())
        .where((option) => option.isNotEmpty)
        .toList(growable: false);
  }

  String _composedContent() {
    final text = _draftText.trim().isNotEmpty
        ? _draftText.trim()
        : _controller.text.trim();
    final options = _pollOptions;
    if (options.isEmpty) return text;

    final pollText = [
      "So'rovnoma:",
      for (var i = 0; i < options.length; i++) '${i + 1}. ${options[i]}',
    ].join('\n');
    return text.isEmpty ? pollText : '$text\n\n$pollText';
  }

  Future<void> _submit() async {
    final content = _composedContent();
    if (_isSubmitting || content.isEmpty) return;

    setState(() => _isSubmitting = true);
    try {
      await widget.onTweetCreated(content, _attachments);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: isDark ? Colors.black : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              backgroundColor: isDark ? Colors.black : Colors.white,
              elevation: 0,
              leadingWidth: 64,
              leading: Center(
                child: _CircleIconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                  size: 48,
                  iconSize: 28,
                ),
              ),
              title: const Text('Yangi post'),
              actions: [
                TextButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Yuborish'),
                ),
              ],
            ),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: math.max(
                  260,
                  MediaQuery.sizeOf(context).height - keyboardInset - 96,
                ),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: TextField(
                        controller: _controller,
                        minLines: 3,
                        maxLines: 5,
                        maxLength: 280,
                        textInputAction: TextInputAction.send,
                        onChanged: (value) =>
                            setState(() => _draftText = value),
                        onSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          hintText: 'Mavzu, savol yoki tajribangizni yozing...',
                          filled: true,
                          fillColor: isDark
                              ? Colors.white.withValues(alpha: .06)
                              : const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.all(14),
                        ),
                        autofocus: true,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          _CircleIconButton(
                            tooltip: 'Rasm',
                            onPressed: _pickImages,
                            icon: const Icon(Icons.image_outlined),
                            size: 52,
                            iconSize: 26,
                            backgroundColor: AppColors.studentPrimary
                                .withValues(alpha: .10),
                            iconColor: AppColors.studentPrimary,
                          ),
                          const SizedBox(width: 10),
                          _CircleIconButton(
                            tooltip: 'Sticker',
                            onPressed: _showStickerPicker,
                            icon: const Icon(Icons.emoji_emotions_outlined),
                            size: 52,
                            iconSize: 26,
                            backgroundColor: AppColors.studentPink.withValues(
                              alpha: .10,
                            ),
                            iconColor: AppColors.studentPink,
                          ),
                          const SizedBox(width: 10),
                          _CircleIconButton(
                            tooltip: 'So‘rov',
                            onPressed: _togglePoll,
                            icon: const Icon(Icons.poll_outlined),
                            size: 52,
                            iconSize: 26,
                            backgroundColor:
                                (_isPollEnabled
                                        ? AppColors.amber
                                        : AppColors.amber)
                                    .withValues(
                                      alpha: _isPollEnabled ? .24 : .12,
                                    ),
                            iconColor: AppColors.amber,
                          ),
                        ],
                      ),
                    ),
                    if (_isPollEnabled) ...[
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: .05)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.amber.withValues(alpha: .28),
                            ),
                          ),
                          child: Column(
                            children: [
                              for (
                                var i = 0;
                                i < _pollControllers.length;
                                i++
                              ) ...[
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _pollControllers[i],
                                        onChanged: (_) => setState(() {}),
                                        decoration: InputDecoration(
                                          hintText: '${i + 1}-variant',
                                          isDense: true,
                                          filled: true,
                                          fillColor: isDark
                                              ? Colors.black.withValues(
                                                  alpha: .18,
                                                )
                                              : Colors.white,
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            borderSide: BorderSide(
                                              color: AppColors.amber.withValues(
                                                alpha: .18,
                                              ),
                                            ),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            borderSide: BorderSide(
                                              color: AppColors.amber.withValues(
                                                alpha: .18,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (_pollControllers.length > 2) ...[
                                      const SizedBox(width: 8),
                                      _CircleIconButton(
                                        tooltip: 'Olib tashlash',
                                        onPressed: () => _removePollOption(i),
                                        icon: const Icon(Icons.close_rounded),
                                        size: 36,
                                        iconSize: 18,
                                      ),
                                    ],
                                  ],
                                ),
                                if (i < _pollControllers.length - 1)
                                  const SizedBox(height: 8),
                              ],
                              if (_pollControllers.length < 4) ...[
                                const SizedBox(height: 10),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton.icon(
                                    onPressed: _addPollOption,
                                    icon: const Icon(Icons.add_rounded),
                                    label: const Text('Variant qo‘shish'),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (_attachments.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        height: 80,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _attachments.length,
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: EdgeInsets.only(right: 8),
                              child: Stack(
                                children: [
                                  Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.grey.shade300,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _attachments.removeAt(index);
                                        });
                                      },
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.black54,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.close,
                                          size: 16,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        child: SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: Material(
                            color: !_isSubmitting
                                ? AppColors.studentPrimary
                                : AppColors.studentPrimary.withValues(
                                    alpha: .34,
                                  ),
                            borderRadius: BorderRadius.circular(16),
                            child: InkWell(
                              onTap: _isSubmitting ? null : _submit,
                              borderRadius: BorderRadius.circular(16),
                              child: Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (_isSubmitting)
                                      const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    else
                                      const Icon(
                                        Icons.send_rounded,
                                        color: Colors.white,
                                      ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Post yuborish',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
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

class _ReplyThreadDialog extends StatefulWidget {
  const _ReplyThreadDialog({
    required this.post,
    this.initialReplies = const [],
    this.onLocalReplyCreated,
    this.onPostChanged,
    this.onChanged,
  });

  final CommunityPost post;
  final List<CommunityReply> initialReplies;
  final ValueChanged<CommunityReply>? onLocalReplyCreated;
  final ValueChanged<CommunityPost>? onPostChanged;
  final VoidCallback? onChanged;

  @override
  State<_ReplyThreadDialog> createState() => _ReplyThreadDialogState();
}

class _ReplyThreadDialogState extends State<_ReplyThreadDialog> {
  final _repository = const SupabaseAcademyRepository();
  final _controller = TextEditingController();
  late CommunityPost _threadPost;
  List<CommunityReply> _replies = [];
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _threadPost = widget.post;
    _replies = widget.initialReplies;
    _loadReplies();
  }

  Future<void> _loadReplies() async {
    if (widget.post.id.startsWith('local-')) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final replies = await _repository.loadReplies(widget.post.id);
      if (mounted) {
        setState(() {
          _replies = replies;
          _isLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _submitReply() async {
    final content = _controller.text.trim();
    if (content.isEmpty) return;
    setState(() => _isSubmitting = true);

    if (widget.post.id.startsWith('local-')) {
      final reply = CommunityReply(
        id: 'local-reply-${DateTime.now().microsecondsSinceEpoch}',
        postId: widget.post.id,
        authorId: widget.post.authorId,
        authorName: widget.post.authorName,
        authorAvatar: widget.post.authorAvatar,
        authorBadge: widget.post.authorBadge,
        content: content,
        likes: 0,
        isLiked: false,
        createdAt: DateTime.now(),
      );
      _controller.clear();
      setState(() {
        _replies = [..._replies, reply];
        _threadPost = CommunityPost(
          id: _threadPost.id,
          authorId: _threadPost.authorId,
          authorName: _threadPost.authorName,
          authorAvatar: _threadPost.authorAvatar,
          authorBadge: _threadPost.authorBadge,
          content: _threadPost.content,
          likes: _threadPost.likes,
          dislikes: _threadPost.dislikes,
          reposts: _threadPost.reposts,
          replies: _threadPost.replies + 1,
          isLiked: _threadPost.isLiked,
          isDisliked: _threadPost.isDisliked,
          isReposted: _threadPost.isReposted,
          isBookmarked: _threadPost.isBookmarked,
          createdAt: _threadPost.createdAt,
          attachments: _threadPost.attachments,
          isPinned: _threadPost.isPinned,
          replyToPostId: _threadPost.replyToPostId,
          replyToPostAuthor: _threadPost.replyToPostAuthor,
        );
        _isLoading = false;
        _isSubmitting = false;
      });
      widget.onLocalReplyCreated?.call(reply);
      widget.onPostChanged?.call(_threadPost);
      widget.onChanged?.call();
      return;
    }

    try {
      await _repository.createReply(postId: widget.post.id, content: content);
      _controller.clear();
      await _loadReplies();
      widget.onChanged?.call();
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  CommunityPost _copyThreadPost({
    int? likes,
    int? dislikes,
    int? reposts,
    int? replies,
    bool? isLiked,
    bool? isDisliked,
    bool? isReposted,
    bool? isBookmarked,
  }) {
    return CommunityPost(
      id: _threadPost.id,
      authorId: _threadPost.authorId,
      authorName: _threadPost.authorName,
      authorAvatar: _threadPost.authorAvatar,
      authorBadge: _threadPost.authorBadge,
      content: _threadPost.content,
      likes: math.max(0, likes ?? _threadPost.likes),
      dislikes: math.max(0, dislikes ?? _threadPost.dislikes),
      reposts: math.max(0, reposts ?? _threadPost.reposts),
      replies: math.max(0, replies ?? _threadPost.replies),
      isLiked: isLiked ?? _threadPost.isLiked,
      isDisliked: isDisliked ?? _threadPost.isDisliked,
      isReposted: isReposted ?? _threadPost.isReposted,
      isBookmarked: isBookmarked ?? _threadPost.isBookmarked,
      createdAt: _threadPost.createdAt,
      attachments: _threadPost.attachments,
      isPinned: _threadPost.isPinned,
      replyToPostId: _threadPost.replyToPostId,
      replyToPostAuthor: _threadPost.replyToPostAuthor,
    );
  }

  Future<void> _toggleThreadReaction(String reactionType) async {
    final original = _threadPost;
    final isLike = reactionType == 'like';
    final removeReaction = isLike ? original.isLiked : original.isDisliked;
    setState(() {
      _threadPost = _copyThreadPost(
        likes: isLike
            ? original.likes + (removeReaction ? -1 : 1)
            : original.likes + (original.isLiked ? -1 : 0),
        dislikes: !isLike
            ? original.dislikes + (removeReaction ? -1 : 1)
            : original.dislikes + (original.isDisliked ? -1 : 0),
        isLiked: isLike && !removeReaction,
        isDisliked: !isLike && !removeReaction,
      );
    });

    if (widget.post.id.startsWith('local-')) {
      widget.onPostChanged?.call(_threadPost);
      return;
    }

    try {
      if (isLike) {
        await _repository.toggleTwitterLike(widget.post.id);
      } else {
        await _repository.toggleTwitterDislike(widget.post.id);
      }
      widget.onPostChanged?.call(_threadPost);
      widget.onChanged?.call();
    } catch (_) {
      if (mounted) setState(() => _threadPost = original);
    }
  }

  Future<void> _toggleThreadRepost() async {
    final original = _threadPost;
    final nextIsReposted = !original.isReposted;
    setState(() {
      _threadPost = _copyThreadPost(
        reposts: original.reposts + (nextIsReposted ? 1 : -1),
        isReposted: nextIsReposted,
      );
    });

    if (widget.post.id.startsWith('local-')) {
      widget.onPostChanged?.call(_threadPost);
      return;
    }

    try {
      await _repository.repostTweet(widget.post.id);
      widget.onPostChanged?.call(_threadPost);
      widget.onChanged?.call();
    } catch (_) {
      if (mounted) setState(() => _threadPost = original);
    }
  }

  Future<void> _toggleThreadBookmark() async {
    final original = _threadPost;
    setState(() {
      _threadPost = _copyThreadPost(isBookmarked: !original.isBookmarked);
    });

    if (widget.post.id.startsWith('local-')) {
      widget.onPostChanged?.call(_threadPost);
      return;
    }

    try {
      await _repository.toggleBookmark(widget.post.id);
      widget.onPostChanged?.call(_threadPost);
      widget.onChanged?.call();
    } catch (_) {
      if (mounted) setState(() => _threadPost = original);
    }
  }

  Future<void> _shareThreadPost() async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final shared = await _shareCommunityPost(
      context: context,
      post: _threadPost,
    );
    if (shared == _CommunityShareResult.copied) {
      messenger
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Ulashish bu qurilmada mavjud emas, post matni nusxalandi.',
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: .88,
      minChildSize: .55,
      maxChildSize: .96,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF020617) : const Color(0xFFF8FAFC),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ListView(
          controller: scrollController,
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
          ),
          children: [
            AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leadingWidth: 64,
              leading: Center(
                child: _CircleIconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                  size: 48,
                  iconSize: 28,
                ),
              ),
              title: const Text('Izohlar'),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _TweetCard(
                post: _threadPost,
                onLike: () => _toggleThreadReaction('like'),
                onDislike: () => _toggleThreadReaction('dislike'),
                onRepost: _toggleThreadRepost,
                onReply: () {},
                onShare: _shareThreadPost,
                onBookmark: _toggleThreadBookmark,
                onMore: () {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    builder: (context) => _PostOptionsSheet(
                      post: _threadPost,
                      canEdit: false,
                      canDelete: false,
                      onEdit: () {},
                      onDelete: () {},
                      onShare: _shareThreadPost,
                      onBookmark: _toggleThreadBookmark,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_replies.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text('Hali izoh yo‘q. Birinchi izohni yozing.'),
              )
            else
              for (final reply in _replies) _ReplyItem(reply: reply),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.studentPrimary,
                    child: const Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: 'Izoh yozing...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      onSubmitted: (_) => _submitReply(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _CircleIconButton(
                    onPressed: _isSubmitting ? null : _submitReply,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                    size: 56,
                    iconSize: 28,
                    backgroundColor: AppColors.studentPrimary,
                    iconColor: Colors.white,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ReplyItem({required CommunityReply reply}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: reply.authorAvatar.isNotEmpty
                ? null
                : AppColors.studentPrimary,
            backgroundImage: reply.authorAvatar.isNotEmpty
                ? NetworkImage(reply.authorAvatar)
                : null,
            child: reply.authorAvatar.isEmpty
                ? Text(
                    reply.authorName.characters.first.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      reply.authorName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      reply.timeAgo,
                      style: TextStyle(
                        color: isDark
                            ? Colors.grey.shade500
                            : Colors.grey.shade500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  reply.content,
                  style: const TextStyle(fontSize: 14, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(
            icon,
            size: 48,
            color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
