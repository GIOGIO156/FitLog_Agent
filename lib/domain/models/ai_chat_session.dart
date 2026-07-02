class AiChatSession {
  const AiChatSession({
    required this.id,
    required this.accountId,
    required this.title,
    required this.language,
    this.lastMessageAt,
    this.archivedAt,
    this.deletedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String accountId;
  final String title;
  final String language;
  final DateTime? lastMessageAt;
  final DateTime? archivedAt;
  final DateTime? deletedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isArchived => archivedAt != null;
  bool get isDeleted => deletedAt != null;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'account_id': accountId,
      'title': title,
      'language': language,
      'last_message_at': lastMessageAt?.toIso8601String(),
      'archived_at': archivedAt?.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory AiChatSession.fromMap(Map<String, dynamic> map) {
    return AiChatSession(
      id: (map['id'] ?? '').toString(),
      accountId: (map['account_id'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      language: (map['language'] ?? 'zh').toString(),
      lastMessageAt: _parseNullableDateTime(map['last_message_at']),
      archivedAt: _parseNullableDateTime(map['archived_at']),
      deletedAt: _parseNullableDateTime(map['deleted_at']),
      createdAt: _parseDateTime(map['created_at']),
      updatedAt: _parseDateTime(map['updated_at']),
    );
  }
}

DateTime _parseDateTime(Object? value) {
  return DateTime.tryParse(value?.toString() ?? '') ??
      DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
}

DateTime? _parseNullableDateTime(Object? value) {
  if (value == null) {
    return null;
  }
  return DateTime.tryParse(value.toString());
}
