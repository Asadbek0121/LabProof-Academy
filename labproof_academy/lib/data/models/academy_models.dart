import 'package:flutter/material.dart';

DateTime? _parseLocalDateTime(Object? value) {
  if (value == null) return null;
  final parsed = DateTime.tryParse(value.toString());
  if (parsed == null) return null;
  return parsed.toLocal();
}

enum UserRole { student, admin }

enum TopicStatus { completed, current, locked }

class StudentProfile {
  const StudentProfile({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.role,
    this.avatarUrl = '',
    this.gender = '',
    this.age,
    this.region = '',
    this.district = '',
    this.mahalla = '',
    this.street = '',
  });

  final String id;
  final String fullName;
  final String phone;
  final UserRole role;
  final String avatarUrl;
  final String gender;
  final int? age;
  final String region;
  final String district;
  final String mahalla;
  final String street;

  String get displayPhone => phone.isEmpty ? 'Telefon raqam yo‘q' : phone;
  bool get hasAvatar => avatarUrl.trim().isNotEmpty;

  String get firstName {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    return parts.isEmpty || parts.first.isEmpty ? 'Student' : parts.first;
  }

  String get lastName {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.length < 2) return '';
    return parts.sublist(1).join(' ');
  }

  String get initials {
    final safeParts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (safeParts.isEmpty) return 'ST';
    if (safeParts.length == 1) {
      return safeParts.first.characters.take(2).toString().toUpperCase();
    }
    return '${safeParts.first.characters.first}${safeParts.last.characters.first}'
        .toUpperCase();
  }

  String get locationSummary {
    final parts = [
      region,
      district,
      mahalla,
      street,
    ].where((item) => item.trim().isNotEmpty).toList();
    if (parts.isEmpty) return 'Manzil kiritilmagan';
    return parts.join(', ');
  }

  int get profileCompletionPercent {
    final fields = [
      fullName.trim().isNotEmpty,
      phone.trim().isNotEmpty,
      gender.trim().isNotEmpty,
      age != null && age! > 0,
      region.trim().isNotEmpty,
      district.trim().isNotEmpty,
      mahalla.trim().isNotEmpty,
      street.trim().isNotEmpty,
      hasAvatar,
    ];
    final completed = fields.where((item) => item).length;
    return ((completed / fields.length) * 100).round();
  }

  StudentProfile copyWith({
    String? fullName,
    String? phone,
    UserRole? role,
    String? avatarUrl,
    String? gender,
    int? age,
    bool clearAge = false,
    String? region,
    String? district,
    String? mahalla,
    String? street,
  }) {
    return StudentProfile(
      id: id,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      gender: gender ?? this.gender,
      age: clearAge ? null : (age ?? this.age),
      region: region ?? this.region,
      district: district ?? this.district,
      mahalla: mahalla ?? this.mahalla,
      street: street ?? this.street,
    );
  }
}

class StudentProfileUpdate {
  const StudentProfileUpdate({
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.gender,
    this.age,
    required this.region,
    required this.district,
    required this.mahalla,
    required this.street,
    this.avatarUrl,
  });

  final String firstName;
  final String lastName;
  final String phone;
  final String gender;
  final int? age;
  final String region;
  final String district;
  final String mahalla;
  final String street;
  final String? avatarUrl;

  String get fullName => '$firstName $lastName'.trim();
}

class StudentDashboardData {
  const StudentDashboardData({
    required this.profile,
    required this.modules,
    required this.completedModules,
    required this.averageScore,
    required this.certificateCount,
  });

  final StudentProfile profile;
  final List<AcademyModule> modules;
  final int completedModules;
  final int averageScore;
  final int certificateCount;

  int get activeModuleCount {
    return modules.where((module) => module.isUnlocked).length;
  }

  double get overallProgress {
    if (modules.isEmpty) return 0;
    final total = modules.fold<double>(0, (sum, item) => sum + item.progress);
    return total / modules.length;
  }

  AcademyModule? get continueModule {
    for (final module in modules) {
      if (module.isUnlocked && !module.isPassed) return module;
    }
    for (final module in modules) {
      if (module.isUnlocked) return module;
    }
    return null;
  }
}

class AcademyModule {
  const AcademyModule({
    required this.id,
    required this.title,
    required this.description,
    required this.order,
    this.coverUrl = '',
    required this.progress,
    required this.isUnlocked,
    required this.isPassed,
    required this.topics,
    required this.studentCount,
    required this.completionRate,
    this.category = 'Barchasi',
    this.finalQuestions = const [],
    this.freeTopicLimit = 1,
    this.requiresSubscription = false,
    this.subscriptionPriceLabel = '',
  });

  final String id;
  final String title;
  final String description;
  final int order;
  final String coverUrl;
  final double progress;
  final bool isUnlocked;
  final bool isPassed;
  final List<TopicLesson> topics;
  final int studentCount;
  final double completionRate;
  final String category;
  final List<QuizQuestion> finalQuestions;
  final int freeTopicLimit;
  final bool requiresSubscription;
  final String subscriptionPriceLabel;

  bool isTopicFree(int index) => index < freeTopicLimit;
}

class VideoLessonChapter {
  const VideoLessonChapter({required this.time, required this.title});

  final Duration time;
  final String title;
}

class LessonMaterial {
  const LessonMaterial({
    required this.kind,
    required this.title,
    this.body = '',
    this.url = '',
    this.duration = Duration.zero,
    this.sourceType = '',
    this.chapters = const [],
  });

  final String kind;
  final String title;
  final String body;
  final String url;
  final Duration duration;
  final String sourceType;
  final List<VideoLessonChapter> chapters;

  bool get isVideo => kind == 'video';
  bool get isPdf => kind == 'pdf' || kind == 'external_pdf';
  bool get isExternalPdf => kind == 'external_pdf';
  bool get isText => kind == 'text' || kind == 'rich_text';
  bool get isRichText => kind == 'rich_text';
  bool get isLink => kind == 'link';
  bool get hasUrl => url.trim().isNotEmpty;
  bool get hasBody => body.trim().isNotEmpty;
}

class TopicLesson {
  const TopicLesson({
    required this.id,
    required this.moduleId,
    required this.title,
    required this.summary,
    required this.pdfTitle,
    required this.videoTitle,
    required this.duration,
    required this.status,
    required this.quizScore,
    required this.formula,
    this.coverUrl = '',
    this.pdfUrl = '',
    this.videoUrl = '',
    this.videoChapters = const [],
    this.quizQuestions = const [],
    this.materials = const [],
    this.isFreePreview = true,
    this.requiresSubscription = false,
  });

  final String id;
  final String moduleId;
  final String title;
  final String summary;
  final String pdfTitle;
  final String videoTitle;
  final Duration duration;
  final TopicStatus status;
  final double quizScore;
  final String formula;
  final String coverUrl;
  final String pdfUrl;
  final String videoUrl;
  final List<VideoLessonChapter> videoChapters;
  final List<QuizQuestion> quizQuestions;
  final List<LessonMaterial> materials;
  final bool isFreePreview;
  final bool requiresSubscription;

  List<LessonMaterial> get readingMaterials => materials
      .where((item) => item.isPdf || item.isText || item.isLink)
      .toList(growable: false);

  List<LessonMaterial> get videoMaterials =>
      materials.where((item) => item.isVideo).toList(growable: false);

  bool get hasReadingMaterial => readingMaterials.isNotEmpty;
  bool get hasVideoMaterial => videoMaterials.isNotEmpty;
  bool get hasQuiz => quizQuestions.isNotEmpty;
}

class QuizQuestion {
  const QuizQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.topic,
    this.assetLabel,
    this.questionType = 'text',
    this.mediaUrl = '',
    this.mediaKind = '',
    this.explanation = '',
  });

  final String question;
  final List<String> options;
  final int correctIndex;
  final String topic;
  final String? assetLabel;
  final String questionType;
  final String mediaUrl;
  final String mediaKind;
  final String explanation;

  bool get hasMedia => mediaUrl.trim().isNotEmpty;
  bool get isImageQuestion => questionType == 'image' || mediaKind == 'image';
  bool get isVideoQuestion => questionType == 'video' || mediaKind == 'video';
}

class StudentRecord {
  const StudentRecord({
    required this.name,
    required this.email,
    required this.module,
    required this.score,
    required this.status,
    required this.progress,
  });

  final String name;
  final String email;
  final String module;
  final int score;
  final String status;
  final double progress;
}

class ActivityItem {
  const ActivityItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
}

class AdminMetric {
  const AdminMetric({
    required this.title,
    required this.value,
    required this.delta,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final String delta;
  final IconData icon;
  final Color color;
}

class StudentNotification {
  const StudentNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.isRead,
    this.deepLink,
    this.targetUserId,
    this.messageKind = 'text',
    this.attachmentUrl,
    this.attachmentName,
    this.attachmentMime,
    this.replyToInboxMessageId,
  });

  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRead;
  final String? deepLink;
  final String? targetUserId;
  final String messageKind;
  final String? attachmentUrl;
  final String? attachmentName;
  final String? attachmentMime;
  final String? replyToInboxMessageId;

  bool get hasAttachment => (attachmentUrl ?? '').trim().isNotEmpty;
  bool get isImage => messageKind == 'image';
  bool get isVideo => messageKind == 'video' || messageKind == 'video_note';
  bool get isAudio => messageKind == 'audio' || messageKind == 'voice';
}

class AdminInboxMessage {
  const AdminInboxMessage({
    required this.id,
    required this.source,
    required this.senderUserId,
    required this.senderName,
    required this.senderPhone,
    required this.telegramChatId,
    required this.subject,
    required this.body,
    required this.isRead,
    required this.adminReply,
    required this.repliedAt,
    required this.createdAt,
    required this.messageKind,
    this.attachmentUrl,
    this.attachmentName,
    this.attachmentMime,
    this.attachmentSize,
    this.adminReadAt,
    this.recipientReadAt,
  });

  final String id;
  final String source;
  final String? senderUserId;
  final String senderName;
  final String senderPhone;
  final String? telegramChatId;
  final String subject;
  final String body;
  final bool isRead;
  final String? adminReply;
  final DateTime? repliedAt;
  final DateTime createdAt;
  final String messageKind;
  final String? attachmentUrl;
  final String? attachmentName;
  final String? attachmentMime;
  final int? attachmentSize;
  final DateTime? adminReadAt;
  final DateTime? recipientReadAt;

  bool get hasAttachment => (attachmentUrl ?? '').trim().isNotEmpty;
  bool get isImage => messageKind == 'image' || messageKind == 'sticker';
  bool get isVideo => messageKind == 'video' || messageKind == 'video_note';
  bool get isAudio => messageKind == 'audio' || messageKind == 'voice';

  factory AdminInboxMessage.fromMap(Map<String, dynamic> row) {
    return AdminInboxMessage(
      id: row['id'].toString(),
      source: (row['source'] ?? 'student_app').toString(),
      senderUserId: row['sender_user_id']?.toString(),
      senderName: (row['sender_name'] ?? '').toString(),
      senderPhone: (row['sender_phone'] ?? '').toString(),
      telegramChatId: row['telegram_chat_id']?.toString(),
      subject: (row['subject'] ?? '').toString(),
      body: (row['body'] ?? '').toString(),
      isRead: row['is_read'] == true,
      adminReply: row['admin_reply']?.toString(),
      repliedAt: _parseLocalDateTime(row['replied_at']),
      createdAt: _parseLocalDateTime(row['created_at']) ?? DateTime.now(),
      messageKind: (row['message_kind'] ?? 'text').toString(),
      attachmentUrl: row['attachment_url']?.toString(),
      attachmentName: row['attachment_name']?.toString(),
      attachmentMime: row['attachment_mime']?.toString(),
      attachmentSize: (row['attachment_size'] as num?)?.round(),
      adminReadAt: _parseLocalDateTime(row['admin_read_at']),
      recipientReadAt: _parseLocalDateTime(row['recipient_read_at']),
    );
  }
}

class AdminModuleSummary {
  const AdminModuleSummary({
    required this.id,
    required this.title,
    required this.description,
    required this.orderIndex,
    required this.coverUrl,
    required this.levelLabel,
    required this.durationLabel,
    required this.isPublished,
    required this.isLocked,
    required this.isSequential,
    required this.passingScore,
    required this.topicCount,
    required this.studentCount,
    required this.completionRate,
    required this.createdAt,
    required this.updatedAt,
    this.freeTopicLimit = 1,
    this.requiresSubscription = false,
    this.subscriptionPriceLabel = '',
  });

  final String id;
  final String title;
  final String description;
  final int orderIndex;
  final String coverUrl;
  final String levelLabel;
  final String durationLabel;
  final bool isPublished;
  final bool isLocked;
  final bool isSequential;
  final int passingScore;
  final int topicCount;
  final int studentCount;
  final double completionRate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int freeTopicLimit;
  final bool requiresSubscription;
  final String subscriptionPriceLabel;
}

class AdminTopicSummary {
  const AdminTopicSummary({
    required this.id,
    required this.moduleId,
    required this.moduleTitle,
    required this.title,
    required this.description,
    required this.orderIndex,
    required this.coverUrl,
    required this.isPublished,
    required this.lessonCount,
    required this.hasPdfOrText,
    required this.hasVideo,
    required this.quizCount,
    required this.completedStudentCount,
    required this.durationSeconds,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String moduleId;
  final String moduleTitle;
  final String title;
  final String description;
  final int orderIndex;
  final String coverUrl;
  final bool isPublished;
  final int lessonCount;
  final bool hasPdfOrText;
  final bool hasVideo;
  final int quizCount;
  final int completedStudentCount;
  final int durationSeconds;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class AdminLessonSummary {
  const AdminLessonSummary({
    required this.id,
    required this.topicId,
    required this.topicTitle,
    required this.moduleId,
    required this.moduleTitle,
    required this.kind,
    required this.title,
    required this.body,
    required this.fileUrl,
    required this.durationSeconds,
    required this.orderIndex,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String topicId;
  final String topicTitle;
  final String moduleId;
  final String moduleTitle;
  final String kind;
  final String title;
  final String body;
  final String fileUrl;
  final int durationSeconds;
  final int orderIndex;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isVideo => kind == 'video';
  bool get isPdfOrText => kind == 'pdf' || kind == 'text';
}

class AdminQuestionSummary {
  const AdminQuestionSummary({
    required this.id,
    required this.scopeType,
    required this.scopeId,
    required this.scopeTitle,
    required this.question,
    required this.optionA,
    required this.optionB,
    required this.optionC,
    required this.optionD,
    required this.correctOption,
    required this.difficulty,
    required this.points,
    required this.createdAt,
    this.questionType = 'text',
    this.mediaUrl = '',
    this.mediaKind = '',
    this.explanation = '',
  });

  final String id;
  final String scopeType;
  final String scopeId;
  final String scopeTitle;
  final String question;
  final String optionA;
  final String optionB;
  final String optionC;
  final String optionD;
  final String correctOption;
  final String difficulty;
  final int points;
  final DateTime createdAt;
  final String questionType;
  final String mediaUrl;
  final String mediaKind;
  final String explanation;

  bool get isFinalExamQuestion => scopeType == 'module';
  bool get hasMedia => mediaUrl.trim().isNotEmpty;
  bool get isImageQuestion => questionType == 'image' || mediaKind == 'image';
  bool get isVideoQuestion => questionType == 'video' || mediaKind == 'video';
}

class AdminStudentSummary {
  const AdminStudentSummary({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.moduleTitle,
    required this.score,
    required this.progress,
    required this.status,
    required this.certificateCount,
    required this.createdAt,
  });

  final String id;
  final String fullName;
  final String phone;
  final String moduleTitle;
  final int score;
  final double progress;
  final String status;
  final int certificateCount;
  final DateTime createdAt;
}

class AdminCertificateSummary {
  const AdminCertificateSummary({
    required this.id,
    required this.studentName,
    required this.moduleTitle,
    required this.certificateUrl,
    required this.issuedAt,
    this.certificateCode = '',
    this.verifyUrl = '',
    this.qrCodeUrl = '',
    this.status = 'issued',
  });

  final String id;
  final String studentName;
  final String moduleTitle;
  final String certificateUrl;
  final DateTime issuedAt;
  final String certificateCode;
  final String verifyUrl;
  final String qrCodeUrl;
  final String status;
}

class AdminMediaSummary {
  const AdminMediaSummary({
    required this.title,
    required this.kind,
    required this.url,
    required this.updatedAt,
    this.publicId = '',
    this.resourceType = '',
    this.format = '',
    this.bytes = 0,
    this.durationSeconds,
    this.width,
    this.height,
    this.source = 'content',
    this.usedIn = const [],
  });

  final String title;
  final String kind;
  final String url;
  final DateTime updatedAt;
  final String publicId;
  final String resourceType;
  final String format;
  final int bytes;
  final int? durationSeconds;
  final int? width;
  final int? height;
  final String source;
  final List<String> usedIn;
}

class AdminRoleSummary {
  const AdminRoleSummary({required this.role, required this.count});

  final String role;
  final int count;
}

class AdminDashboardData {
  const AdminDashboardData({
    required this.metrics,
    required this.growthChart,
    required this.completionChart,
    required this.activities,
    required this.topModules,
    required this.recentStudents,
    required this.completionPercent,
    required this.completedCount,
    required this.inProgressCount,
    required this.notStartedCount,
    required this.notificationCount,
    required this.recentStudentsCount,
    required this.activeUsersCount,
    required this.certificateCount,
  });

  final List<AdminMetric> metrics;
  final List<double> growthChart;
  final List<double> completionChart;
  final List<ActivityItem> activities;
  final List<AdminModuleSummary> topModules;
  final List<AdminStudentSummary> recentStudents;
  final double completionPercent;
  final int completedCount;
  final int inProgressCount;
  final int notStartedCount;
  final int notificationCount;
  final int recentStudentsCount;
  final int activeUsersCount;
  final int certificateCount;
}

class CommunityPost {
  const CommunityPost({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.authorAvatar,
    required this.authorBadge,
    required this.content,
    required this.likes,
    this.dislikes = 0,
    required this.reposts,
    required this.replies,
    required this.isLiked,
    this.isDisliked = false,
    required this.isReposted,
    required this.isBookmarked,
    required this.createdAt,
    this.attachments = const [],
    this.isPinned = false,
    this.replyToPostId,
    this.replyToPostAuthor,
  });

  final String id;
  final String authorId;
  final String authorName;
  final String authorAvatar;
  final String authorBadge;
  final String content;
  final int likes;
  final int dislikes;
  final int reposts;
  final int replies;
  final bool isLiked;
  final bool isDisliked;
  final bool isReposted;
  final bool isBookmarked;
  final DateTime createdAt;
  final List<String> attachments;
  final bool isPinned;
  final String? replyToPostId;
  final String? replyToPostAuthor;

  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inMinutes < 1) return 'hozirgina';
    if (difference.inMinutes < 60) return '${difference.inMinutes}d';
    if (difference.inHours < 24) return '${difference.inHours}soat';
    if (difference.inDays < 7) return '${difference.inDays}kun';
    return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
  }
}

class CommunityReply {
  const CommunityReply({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.authorName,
    required this.authorAvatar,
    required this.authorBadge,
    required this.content,
    required this.likes,
    required this.isLiked,
    required this.createdAt,
    this.parentReplyId,
    this.attachments = const [],
  });

  final String id;
  final String postId;
  final String authorId;
  final String authorName;
  final String authorAvatar;
  final String authorBadge;
  final String content;
  final int likes;
  final bool isLiked;
  final DateTime createdAt;
  final String? parentReplyId;
  final List<String> attachments;

  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inMinutes < 1) return 'hozirgina';
    if (difference.inMinutes < 60) return '${difference.inMinutes}d';
    if (difference.inHours < 24) return '${difference.inHours}soat';
    if (difference.inDays < 7) return '${difference.inDays}kun';
    return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
  }
}
