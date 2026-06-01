import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../../core/constants/app_colors.dart';
import '../../data/models/academy_models.dart';
import '../../data/repositories/supabase_academy_repository.dart';
import 'shared_widgets.dart';

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
      }
    }
  }

  void _showCreateTweetDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CreateTweetDialog(
        onTweetCreated: (content, attachments) async {
          try {
            await _repository.createTwitterPost(
              content: content,
              attachments: attachments,
            );
            if (mounted) {
              Navigator.pop(context);
              _loadPosts();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Post yuborildi!')),
              );
            }
          } catch (error) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Xatolik: ${error.toString()}')),
              );
            }
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: isDark ? Colors.black : Colors.white,
            title: const Text('Community'),
            elevation: 0,
            actions: [
              IconButton(
                onPressed: widget.onNotifications,
                icon: Badge.count(
                  count: widget.notificationCount,
                  child: const Icon(Icons.notifications_none),
                ),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: _TweetComposer(
              onTweet: _showCreateTweetDialog,
            ),
          ),
          if (_isLoading)
            const SliverToBoxAdapter(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_posts.isEmpty)
            SliverToBoxAdapter(
              child: _EmptyState(
                icon: Icons.forum_outlined,
                title: 'Hali post yo\'q',
                message: 'Birinchi postni siz yozing!',
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index == _posts.length) {
                    return _isLoadingMore
                        ? const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        : const SizedBox(height: 100);
                  }
                  final post = _posts[index];
                  return _TweetCard(
                    post: post,
                    onLike: () => _handleLike(post.id),
                    onRepost: () => _handleRepost(post.id),
                    onReply: () => _showReplyDialog(post),
                    onBookmark: () => _handleBookmark(post.id),
                  );
                },
                childCount: _posts.length + 1,
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateTweetDialog,
        backgroundColor: AppColors.studentPrimary,
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _handleLike(String postId) async {
    await _repository.toggleTwitterLike(postId);
    _loadPosts();
  }

  Future<void> _handleRepost(String postId) async {
    await _repository.repostTweet(postId);
    _loadPosts();
  }

  Future<void> _handleBookmark(String postId) async {
    await _repository.toggleBookmark(postId);
    _loadPosts();
  }

  void _showReplyDialog(CommunityPost post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ReplyThreadDialog(post: post),
    );
  }
}

class _TweetComposer extends StatelessWidget {
  const _TweetComposer({required this.onTweet});

  final VoidCallback onTweet;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.black : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
            width: 1,
          ),
        ),
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
            child: GestureDetector(
              onTap: onTweet,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    Text(
                      'Nima nima deyishiz?',
                      style: TextStyle(
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.image_outlined, color: AppColors.studentPrimary),
                    const SizedBox(width: 8),
                    Icon(Icons.gif_outlined, color: AppColors.studentPink),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TweetCard extends StatelessWidget {
  const _TweetCard({
    required this.post,
    required this.onLike,
    required this.onRepost,
    required this.onReply,
    required this.onBookmark,
  });

  final CommunityPost post;
  final VoidCallback onLike;
  final VoidCallback onRepost;
  final VoidCallback onReply;
  final VoidCallback onBookmark;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.black : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (post.isPinned)
            Row(
              children: [
                const Icon(Icons.push_pin, size: 16, color: AppColors.studentPrimary),
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
            children: [
              CircleAvatar(
                radius: 20,
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
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '@${post.authorName.toLowerCase().replaceAll(' ', '')}',
                          style: TextStyle(
                            color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                          fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getBadgeColor(post.authorBadge).withValues(alpha: .1),
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
                        const Spacer(),
                        Text(
                          '· ${post.timeAgo}',
                          style: TextStyle(
                            color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _showMoreOptions(),
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
            style: const TextStyle(fontSize: 15, height: 1.4),
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
                    padding: EdgeInsets.only(right: index < post.attachments.length - 1 ? 8 : 0),
                    child: Container(
                      width: 100,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.image, color: AppColors.studentPrimary),
                            const SizedBox(height: 4),
                            Text(
                              post.attachments.length > 1 ? '+${post.attachments.length}' : '',
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
          Row(
            children: [
              _ActionButton(
                icon: post.isLiked ? Icons.favorite : Icons.favorite_border,
                color: post.isLiked ? AppColors.errorRed : null,
                count: post.likes,
                onTap: onLike,
              ),
              _ActionButton(
                icon: post.isReposted ? Icons.repeat : Icons.repeat_outlined,
                color: post.isReposted ? AppColors.studentPrimary : null,
                count: post.reposts,
                onTap: onRepost,
              ),
              _ActionButton(
                icon: Icons.mode_comment_outlined,
                count: post.replies,
                onTap: onReply,
              ),
              const Spacer(),
              _ActionButton(
                icon: post.isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                color: post.isBookmarked ? AppColors.studentPrimary : null,
                onTap: onBookmark,
              ),
              _ActionButton(
                icon: Icons.share_outlined,
                onTap: () {
                  // Share functionality
                },
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

  void _showMoreOptions() {
    // Show more options menu
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.count,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final int count;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: color ?? (isDark ? Colors.white70 : Colors.black54),
            ),
            const SizedBox(width: 4),
            Text(
              count.toString(),
              style: TextStyle(
                color: color ?? (isDark ? Colors.white70 : Colors.black54),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateTweetDialog extends StatefulWidget {
  const _CreateTweetDialog({
    required this.onTweetCreated,
  });

  final Function(String content, List<String> attachments) onTweetCreated;

  @override
  State<_CreateTweetDialog> createState() => _CreateTweetDialogState();
}

class _CreateTweetDialogState extends State<_CreateTweetDialog> {
  final _controller = TextEditingController();
  List<String> _attachments = [];
  bool _isSubmitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickAttachment() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
      );
      if (result != null) {
        setState(() {
          _attachments.addAll(result.files.map((file) => file.path!));
        });
      }
    } catch (e) {
      // Handle error
    }
  }

  void _submit() {
    if (_controller.text.trim().isEmpty) return;
    
    setState(() => _isSubmitting = true);
    
    widget.onTweetCreated(_controller.text.trim(), _attachments).then((_) {
      setState(() => _isSubmitting = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.black : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppBar(
            backgroundColor: isDark ? Colors.black : Colors.white,
            elevation: 0,
            leading: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
            title: const Text('New post'),
            actions: [
              TextButton(
                onPressed: _submit,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Post'),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _controller,
              maxLines: 6,
              maxLength: 280,
              decoration: const InputDecoration(
                hintText: 'Nima nima deyishiz?',
                border: InputBorder.none,
              ),
              autofocus: true,
            ),
          ),
          Row(
            children: [
              IconButton(
                onPressed: _pickAttachment,
                icon: const Icon(Icons.image_outlined),
                color: AppColors.studentPrimary,
              ),
              IconButton(
                onPressed: () => _pickAttachment(),
                icon: const Icon(Icons.gif_outlined),
                color: AppColors.studentPink,
              ),
              IconButton(
                onPressed: () => _pickAttachment(),
                icon: const Icon(Icons.poll_outlined),
                color: AppColors.amber,
              ),
            ],
          ),
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
                            border: Border.all(color: Colors.grey.shade300),
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
        ],
      ),
    );
  }
}

class _ReplyThreadDialog extends StatefulWidget {
  const _ReplyThreadDialog({
    required this.post,
  });

  final CommunityPost post;

  @override
  State<_ReplyThreadDialog> createState() => _ReplyThreadDialogState();
}

class _ReplyThreadDialogState extends State<_ReplyThreadDialog> {
  final _repository = const SupabaseAcademyRepository();
  final _controller = TextEditingController();
  List<CommunityReply> _replies = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReplies();
  }

  Future<void> _loadReplies() async {
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

  void _submitReply() {
    if (_controller.text.trim().isEmpty) return;
    
    _repository.createReply(
      postId: widget.post.id,
      content: _controller.text.trim(),
    ).then((_) {
      _controller.clear();
      _loadReplies();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.black : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppBar(
            backgroundColor: isDark ? Colors.black : Colors.white,
            elevation: 0,
            leading: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
            title: Text('Thread'),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: _TweetCard(
              post: widget.post,
              onLike: () {},
              onRepost: () {},
              onReply: () {},
              onBookmark: () {},
            ),
          ),
          Divider(height: 1),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_replies.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Hali reply yo\'q'),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _replies.length,
              itemBuilder: (context, index) {
                final reply = _replies[index];
                return _ReplyItem(reply: reply);
              },
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.studentPrimary,
                  child: const Icon(Icons.person, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _controller,
                  decoration: InputDecoration(
                    hintText: 'Post your reply',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  onSubmitted: (_) => _submitReply(),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _submitReply,
                  icon: const Icon(Icons.send),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.studentPrimary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
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
                        color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
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
          Icon(icon, size: 48, color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
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
