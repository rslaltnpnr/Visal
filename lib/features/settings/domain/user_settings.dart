/// users/{uid}.settings
class PrivacySettings {
  const PrivacySettings({
    this.showOnline = true,
    this.showLastSeen = true,
    this.readReceipts = true,
    this.notificationPreview = true,
    this.moodVisible = true,
  });

  final bool showOnline;
  final bool showLastSeen;
  final bool readReceipts;

  /// false => bildirimde yalnızca "VISAL — Yeni mesaj" görünür.
  final bool notificationPreview;
  final bool moodVisible;

  factory PrivacySettings.fromMap(Map<String, dynamic>? m) => PrivacySettings(
        showOnline: m?['showOnline'] as bool? ?? true,
        showLastSeen: m?['showLastSeen'] as bool? ?? true,
        readReceipts: m?['readReceipts'] as bool? ?? true,
        notificationPreview: m?['notificationPreview'] as bool? ?? true,
        moodVisible: m?['moodVisible'] as bool? ?? true,
      );

  Map<String, dynamic> toMap() => {
        'showOnline': showOnline,
        'showLastSeen': showLastSeen,
        'readReceipts': readReceipts,
        'notificationPreview': notificationPreview,
        'moodVisible': moodVisible,
      };

  PrivacySettings copyWith({
    bool? showOnline,
    bool? showLastSeen,
    bool? readReceipts,
    bool? notificationPreview,
    bool? moodVisible,
  }) =>
      PrivacySettings(
        showOnline: showOnline ?? this.showOnline,
        showLastSeen: showLastSeen ?? this.showLastSeen,
        readReceipts: readReceipts ?? this.readReceipts,
        notificationPreview: notificationPreview ?? this.notificationPreview,
        moodVisible: moodVisible ?? this.moodVisible,
      );
}

class NotificationSettings {
  const NotificationSettings({
    this.messages = true,
    this.love = true,
    this.memories = true,
    this.capsules = true,
    this.events = true,
    this.dailyQuestion = true,
  });

  final bool messages;
  final bool love;
  final bool memories;
  final bool capsules;
  final bool events;
  final bool dailyQuestion;

  factory NotificationSettings.fromMap(Map<String, dynamic>? m) =>
      NotificationSettings(
        messages: m?['messages'] as bool? ?? true,
        love: m?['love'] as bool? ?? true,
        memories: m?['memories'] as bool? ?? true,
        capsules: m?['capsules'] as bool? ?? true,
        events: m?['events'] as bool? ?? true,
        dailyQuestion: m?['dailyQuestion'] as bool? ?? true,
      );

  Map<String, dynamic> toMap() => {
        'messages': messages,
        'love': love,
        'memories': memories,
        'capsules': capsules,
        'events': events,
        'dailyQuestion': dailyQuestion,
      };

  NotificationSettings copyWith({
    bool? messages,
    bool? love,
    bool? memories,
    bool? capsules,
    bool? events,
    bool? dailyQuestion,
  }) =>
      NotificationSettings(
        messages: messages ?? this.messages,
        love: love ?? this.love,
        memories: memories ?? this.memories,
        capsules: capsules ?? this.capsules,
        events: events ?? this.events,
        dailyQuestion: dailyQuestion ?? this.dailyQuestion,
      );
}

class UserSettings {
  const UserSettings({
    this.privacy = const PrivacySettings(),
    this.notifications = const NotificationSettings(),
  });

  final PrivacySettings privacy;
  final NotificationSettings notifications;

  factory UserSettings.fromMap(Map<String, dynamic>? m) => UserSettings(
        privacy: PrivacySettings.fromMap(
          (m?['privacy'] as Map?)?.cast<String, dynamic>(),
        ),
        notifications: NotificationSettings.fromMap(
          (m?['notifications'] as Map?)?.cast<String, dynamic>(),
        ),
      );

  Map<String, dynamic> toMap() => {
        'privacy': privacy.toMap(),
        'notifications': notifications.toMap(),
      };
}
