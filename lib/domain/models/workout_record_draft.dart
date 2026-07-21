import 'dart:convert';

class WorkoutRecordDraft {
  const WorkoutRecordDraft({
    required this.id,
    required this.kind,
    this.sourcePlanId,
    this.sourceSessionId,
    required this.date,
    required this.recordName,
    required this.notes,
    required this.payloadJson,
    this.saveState = saveStateEditing,
    this.saveMutationId,
    this.targetPlanId,
    this.savePayloadHash,
    this.saveStartedAt,
    this.saveBodyWeightKg,
    required this.createdAt,
    required this.updatedAt,
  });

  static const String activeDraftId = 'active_workout_draft';
  static const String kindNewRecord = 'new_record';
  static const String kindEditRecord = 'edit_record';
  static const String saveStateEditing = 'editing';
  static const String saveStateCommitting = 'committing';
  static const String saveStateCommitUnknown = 'commit_unknown';

  final String id;
  final String kind;
  final String? sourcePlanId;
  final int? sourceSessionId;
  final String date;
  final String recordName;
  final String notes;
  final String payloadJson;
  final String saveState;
  final String? saveMutationId;
  final String? targetPlanId;
  final String? savePayloadHash;
  final String? saveStartedAt;
  final double? saveBodyWeightKg;
  final String createdAt;
  final String updatedAt;

  bool get isNewRecordDraft => kind == kindNewRecord;
  bool get canAutosave => saveState == saveStateEditing;
  bool get hasPendingCommit =>
      saveState == saveStateCommitting || saveState == saveStateCommitUnknown;

  WorkoutRecordDraft copyWith({
    String? date,
    String? recordName,
    String? notes,
    String? payloadJson,
    String? saveState,
    String? saveMutationId,
    String? targetPlanId,
    String? savePayloadHash,
    String? saveStartedAt,
    double? saveBodyWeightKg,
    bool clearCommitMetadata = false,
    String? updatedAt,
  }) {
    return WorkoutRecordDraft(
      id: id,
      kind: kind,
      sourcePlanId: sourcePlanId,
      sourceSessionId: sourceSessionId,
      date: date ?? this.date,
      recordName: recordName ?? this.recordName,
      notes: notes ?? this.notes,
      payloadJson: payloadJson ?? this.payloadJson,
      saveState: saveState ?? this.saveState,
      saveMutationId: clearCommitMetadata
          ? null
          : saveMutationId ?? this.saveMutationId,
      targetPlanId: clearCommitMetadata
          ? null
          : targetPlanId ?? this.targetPlanId,
      savePayloadHash: clearCommitMetadata
          ? null
          : savePayloadHash ?? this.savePayloadHash,
      saveStartedAt: clearCommitMetadata
          ? null
          : saveStartedAt ?? this.saveStartedAt,
      saveBodyWeightKg: clearCommitMetadata
          ? null
          : saveBodyWeightKg ?? this.saveBodyWeightKg,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> get payload {
    final decoded = jsonDecode(payloadJson);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return decoded.cast<String, dynamic>();
    }
    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> get exercisePayloads {
    final raw = payload['exercises'];
    if (raw is! List) {
      return const <Map<String, dynamic>>[];
    }
    return raw
        .whereType<Map>()
        .map((entry) => entry.cast<String, dynamic>())
        .toList();
  }

  int get exerciseCount => exercisePayloads.length;

  String? get firstExerciseName {
    if (exercisePayloads.isEmpty) {
      return null;
    }
    final name =
        exercisePayloads.first['exercise_name']?.toString().trim() ?? '';
    return name.isEmpty ? null : name;
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'kind': kind,
      'source_plan_id': sourcePlanId,
      'source_session_id': sourceSessionId,
      'date': date,
      'record_name': recordName,
      'notes': notes,
      'payload_json': payloadJson,
      'save_state': saveState,
      'save_mutation_id': saveMutationId,
      'target_plan_id': targetPlanId,
      'save_payload_hash': savePayloadHash,
      'save_started_at': saveStartedAt,
      'save_body_weight_kg': saveBodyWeightKg,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory WorkoutRecordDraft.fromMap(Map<String, dynamic> map) {
    final rawSessionId = map['source_session_id'];
    final sessionId = rawSessionId is num
        ? rawSessionId.toInt()
        : int.tryParse(rawSessionId?.toString() ?? '');
    return WorkoutRecordDraft(
      id: (map['id'] ?? activeDraftId).toString(),
      kind: (map['kind'] ?? kindNewRecord).toString(),
      sourcePlanId: map['source_plan_id']?.toString(),
      sourceSessionId: sessionId,
      date: (map['date'] ?? '').toString(),
      recordName: (map['record_name'] ?? '').toString(),
      notes: (map['notes'] ?? '').toString(),
      payloadJson: (map['payload_json'] ?? '{}').toString(),
      saveState: _normalizedSaveState(map['save_state']),
      saveMutationId: _nullableText(map['save_mutation_id']),
      targetPlanId: _nullableText(map['target_plan_id']),
      savePayloadHash: _nullableText(map['save_payload_hash']),
      saveStartedAt: _nullableText(map['save_started_at']),
      saveBodyWeightKg: _nullableDouble(map['save_body_weight_kg']),
      createdAt: (map['created_at'] ?? '').toString(),
      updatedAt: (map['updated_at'] ?? '').toString(),
    );
  }

  static String _normalizedSaveState(Object? value) {
    final state = value?.toString();
    return state == saveStateCommitting || state == saveStateCommitUnknown
        ? state!
        : saveStateEditing;
  }

  static String? _nullableText(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  static double? _nullableDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '');
  }
}
