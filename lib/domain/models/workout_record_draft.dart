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
    required this.createdAt,
    required this.updatedAt,
  });

  static const String activeDraftId = 'active_workout_draft';
  static const String kindNewRecord = 'new_record';
  static const String kindEditRecord = 'edit_record';

  final String id;
  final String kind;
  final String? sourcePlanId;
  final int? sourceSessionId;
  final String date;
  final String recordName;
  final String notes;
  final String payloadJson;
  final String createdAt;
  final String updatedAt;

  bool get isNewRecordDraft => kind == kindNewRecord;

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
      createdAt: (map['created_at'] ?? '').toString(),
      updatedAt: (map['updated_at'] ?? '').toString(),
    );
  }
}
