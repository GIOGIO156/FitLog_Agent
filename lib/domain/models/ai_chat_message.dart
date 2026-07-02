import 'dart:convert';

import '../../core/utils/number_utils.dart';
import 'ai_food_photo_analysis.dart';
import 'ai_workout_draft.dart';

enum AiChatMessageRole { user, assistant }

extension AiChatMessageRoleValue on AiChatMessageRole {
  String get value {
    switch (this) {
      case AiChatMessageRole.user:
        return 'user';
      case AiChatMessageRole.assistant:
        return 'assistant';
    }
  }
}

AiChatMessageRole aiChatMessageRoleFromValue(String value) {
  switch (value) {
    case 'user':
      return AiChatMessageRole.user;
    case 'assistant':
      return AiChatMessageRole.assistant;
    default:
      throw FormatException('Unsupported AI chat message role: $value');
  }
}

class AiChatMessage {
  const AiChatMessage({
    required this.id,
    required this.sessionId,
    required this.accountId,
    required this.messageSequence,
    required this.role,
    required this.contentText,
    this.messageType = 'text',
    this.workflowType = 'auto',
    this.modelChoice,
    this.modelProvider,
    this.requestId,
    this.finalAnswerJson,
    this.attachmentsMetadata = const <Map<String, dynamic>>[],
    required this.createdAt,
    this.deletedAt,
  });

  final String id;
  final String sessionId;
  final String accountId;
  final int messageSequence;
  final AiChatMessageRole role;
  final String contentText;
  final String messageType;
  final String workflowType;
  final String? modelChoice;
  final String? modelProvider;
  final String? requestId;
  final Map<String, dynamic>? finalAnswerJson;
  final List<Map<String, dynamic>> attachmentsMetadata;
  final DateTime createdAt;
  final DateTime? deletedAt;

  bool get isUser => role == AiChatMessageRole.user;
  bool get isAssistant => role == AiChatMessageRole.assistant;
  bool get isDeleted => deletedAt != null;
  AiFoodDraft? get foodDraftArtifact => foodDraftArtifactSnapshot?.draft;
  AiFoodDraftArtifact? get foodDraftArtifactSnapshot =>
      _foodArtifactFromFinalAnswer(finalAnswerJson);
  AiWorkoutDraft? get workoutDraftArtifact =>
      workoutDraftArtifactSnapshot?.draft;
  AiWorkoutDraftArtifact? get workoutDraftArtifactSnapshot =>
      _workoutArtifactFromFinalAnswer(finalAnswerJson);

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'session_id': sessionId,
      'account_id': accountId,
      'message_sequence': messageSequence,
      'role': role.value,
      'content_text': contentText,
      'message_type': messageType,
      'workflow_type': workflowType,
      'model_choice': modelChoice,
      'model_provider': modelProvider,
      'request_id': requestId,
      'final_answer_json': finalAnswerJson,
      'attachments_metadata': attachmentsMetadata,
      'created_at': createdAt.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
    };
  }

  factory AiChatMessage.fromMap(Map<String, dynamic> map) {
    final messageType = (map['message_type'] ?? 'text').toString();
    if (messageType != 'text') {
      throw FormatException('Unsupported AI chat message type: $messageType');
    }

    return AiChatMessage(
      id: (map['id'] ?? '').toString(),
      sessionId: (map['session_id'] ?? '').toString(),
      accountId: (map['account_id'] ?? '').toString(),
      messageSequence: NumberUtils.toInt(map['message_sequence']),
      role: aiChatMessageRoleFromValue((map['role'] ?? '').toString()),
      contentText: (map['content_text'] ?? '').toString(),
      messageType: messageType,
      workflowType: (map['workflow_type'] ?? 'auto').toString(),
      modelChoice: map['model_choice']?.toString(),
      modelProvider: map['model_provider']?.toString(),
      requestId: map['request_id']?.toString(),
      finalAnswerJson: _mapOrNull(map['final_answer_json']),
      attachmentsMetadata: _mapList(map['attachments_metadata']),
      createdAt: _parseDateTime(map['created_at']),
      deletedAt: _parseNullableDateTime(map['deleted_at']),
    );
  }

  static int compareByStableOrder(AiChatMessage a, AiChatMessage b) {
    final sequence = a.messageSequence.compareTo(b.messageSequence);
    if (sequence != 0) {
      return sequence;
    }

    final created = a.createdAt.compareTo(b.createdAt);
    if (created != 0) {
      return created;
    }

    return a.id.compareTo(b.id);
  }
}

class AiFoodDraftArtifact {
  const AiFoodDraftArtifact({
    required this.mealName,
    required this.caloriesKcal,
    required this.draft,
  });

  final String mealName;
  final double? caloriesKcal;
  final AiFoodDraft? draft;

  bool get canOpen => draft != null;
}

class AiWorkoutDraftArtifact {
  const AiWorkoutDraftArtifact({
    required this.recordName,
    required this.exerciseCount,
    required this.draft,
  });

  final String recordName;
  final int exerciseCount;
  final AiWorkoutDraft? draft;

  bool get canOpen => draft != null;
}

AiFoodDraftArtifact? _foodArtifactFromFinalAnswer(Map<String, dynamic>? value) {
  if (value == null) {
    return null;
  }
  final artifacts = value['artifacts'];
  if (artifacts is List) {
    for (final item in artifacts) {
      if (item is! Map) {
        continue;
      }
      final artifact = Map<String, dynamic>.from(item);
      if (artifact['type'] != 'food_draft') {
        continue;
      }
      final draft = artifact['draft'];
      if (draft is Map) {
        final draftMap = Map<String, dynamic>.from(draft);
        try {
          final foodDraft = AiFoodDraft.fromJson(draftMap);
          return AiFoodDraftArtifact(
            mealName: foodDraft.mealName,
            caloriesKcal: foodDraft.caloriesKcal,
            draft: foodDraft,
          );
        } on FormatException {
          return AiFoodDraftArtifact(
            mealName: _textField(draftMap, 'meal_name') ?? 'Food draft',
            caloriesKcal: _numberField(draftMap, 'calories_kcal'),
            draft: null,
          );
        }
      }
    }
  }

  final draft = value['draft'];
  if (draft is Map) {
    final draftMap = Map<String, dynamic>.from(draft);
    try {
      final foodDraft = AiFoodDraft.fromJson(draftMap);
      return AiFoodDraftArtifact(
        mealName: foodDraft.mealName,
        caloriesKcal: foodDraft.caloriesKcal,
        draft: foodDraft,
      );
    } on FormatException {
      return AiFoodDraftArtifact(
        mealName: _textField(draftMap, 'meal_name') ?? 'Food draft',
        caloriesKcal: _numberField(draftMap, 'calories_kcal'),
        draft: null,
      );
    }
  }
  return null;
}

AiWorkoutDraftArtifact? _workoutArtifactFromFinalAnswer(
  Map<String, dynamic>? value,
) {
  if (value == null) {
    return null;
  }
  final artifacts = value['artifacts'];
  if (artifacts is! List) {
    return null;
  }
  for (final item in artifacts) {
    if (item is! Map) {
      continue;
    }
    final artifact = Map<String, dynamic>.from(item);
    if (artifact['type'] != 'workout_draft') {
      continue;
    }
    final draft = artifact['draft'];
    if (draft is! Map) {
      return AiWorkoutDraftArtifact(
        recordName:
            _textField(artifact, 'record_name') ?? 'Workout record draft',
        exerciseCount: NumberUtils.toInt(artifact['exercise_count']),
        draft: null,
      );
    }
    final draftMap = Map<String, dynamic>.from(draft);
    try {
      final workoutDraft = AiWorkoutDraft.fromJson(draftMap);
      return AiWorkoutDraftArtifact(
        recordName: workoutDraft.recordName,
        exerciseCount: workoutDraft.exercises.length,
        draft: workoutDraft,
      );
    } on FormatException {
      return AiWorkoutDraftArtifact(
        recordName: _textField(draftMap, 'record_name') ?? 'Workout record',
        exerciseCount: _exerciseCountFromDraft(draftMap),
        draft: null,
      );
    }
  }
  return null;
}

String? _textField(Map<String, dynamic> value, String key) {
  final text = value[key]?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

double? _numberField(Map<String, dynamic> value, String key) {
  if (value[key] == null) {
    return null;
  }
  final parsed = NumberUtils.toDouble(value[key], fallback: double.nan);
  return parsed.isFinite ? parsed : null;
}

int _exerciseCountFromDraft(Map<String, dynamic> value) {
  final raw = value['exercises'];
  return raw is List ? raw.length : 0;
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

Map<String, dynamic>? _mapOrNull(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  if (value is String && value.isNotEmpty) {
    final decoded = jsonDecode(value);
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
  }
  throw const FormatException('Expected JSON object');
}

List<Map<String, dynamic>> _mapList(Object? value) {
  if (value == null) {
    return const <Map<String, dynamic>>[];
  }

  final rawList = value is String ? jsonDecode(value) : value;
  if (rawList is! List) {
    throw const FormatException('Expected JSON array');
  }

  return rawList
      .map((item) => Map<String, dynamic>.from(item as Map))
      .toList(growable: false);
}
