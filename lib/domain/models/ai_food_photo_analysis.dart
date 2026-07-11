import '../../core/constants/app_constants.dart';
import 'ai_gateway_error.dart';
import 'ai_gateway_request.dart';
import 'food_item.dart';
import 'food_record.dart';

const String aiFoodDraftSchemaVersion = 'food_draft.v2';
const String aiLegacyFoodDraftSchemaVersion = 'food_draft.v1';

class AiFoodPhotoImagePayload {
  const AiFoodPhotoImagePayload({
    required this.mimeType,
    required this.base64Data,
    required this.byteLength,
  });

  final String mimeType;
  final String base64Data;
  final int byteLength;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'mime_type': mimeType,
      'base64_data': base64Data,
      'byte_length': byteLength,
    };
  }
}

class AiFoodPhotoAnalysisRequest {
  const AiFoodPhotoAnalysisRequest({
    required this.images,
    required this.language,
    this.modelChoice = AiGatewayModelChoice.qwen,
    required this.deviceId,
    required this.selectedDate,
    this.userNote,
    this.client = const <String, dynamic>{},
  });

  final List<AiFoodPhotoImagePayload> images;
  final String language;
  final AiGatewayModelChoice modelChoice;
  final String deviceId;
  final String selectedDate;
  final String? userNote;
  final Map<String, dynamic> client;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'images': images.map((image) => image.toJson()).toList(growable: false),
      'language': language,
      'model_choice': modelChoice.value,
      'device_id': deviceId,
      'selected_date': selectedDate,
      'schema_version': aiFoodDraftSchemaVersion,
      if ((userNote ?? '').trim().isNotEmpty) 'user_note': userNote!.trim(),
      if (client.isNotEmpty) 'client': Map<String, dynamic>.from(client),
    };
  }
}

class AiFoodPhotoAnalysisResponse {
  const AiFoodPhotoAnalysisResponse({
    this.modelChoice,
    this.modelProvider,
    this.draft,
    this.needsClarification = false,
    this.clarificationQuestions = const <String>[],
    this.debugSummaryId,
    this.error,
  });

  final AiGatewayModelChoice? modelChoice;
  final String? modelProvider;
  final AiFoodDraft? draft;
  final bool needsClarification;
  final List<String> clarificationQuestions;
  final String? debugSummaryId;
  final AiGatewayError? error;

  bool get isSuccess => error == null;

  factory AiFoodPhotoAnalysisResponse.fromJson(
    Map<String, dynamic> json, {
    String? legacyDate,
  }) {
    final rawModelChoice = json['model_choice']?.toString();
    final rawDraft = json['draft'];
    return AiFoodPhotoAnalysisResponse(
      modelChoice: rawModelChoice == null
          ? null
          : aiGatewayModelChoiceFromValue(rawModelChoice),
      modelProvider: json['model_provider']?.toString(),
      draft: rawDraft is Map
          ? AiFoodDraft.fromJson(
              Map<String, dynamic>.from(rawDraft),
              legacyDate: legacyDate,
            )
          : null,
      needsClarification: json['needs_clarification'] == true,
      clarificationQuestions: _stringList(json['clarification_questions']),
      debugSummaryId: json['debug_summary_id']?.toString(),
      error: AiGatewayError.fromJsonOrNull(json['error']),
    );
  }
}

class AiFoodDraft {
  const AiFoodDraft({
    required this.date,
    required this.mealName,
    required this.totalWeightG,
    required this.caloriesKcal,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    this.confidence,
    required this.estimationNotes,
    this.items = const <AiFoodDraftItem>[],
  });

  final String date;
  final String mealName;
  final double totalWeightG;
  final double caloriesKcal;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double? confidence;
  final String estimationNotes;
  final List<AiFoodDraftItem> items;

  factory AiFoodDraft.fromJson(
    Map<String, dynamic> json, {
    String? legacyDate,
  }) {
    final schemaVersion = json['schema_version']?.toString();
    if (schemaVersion != null &&
        schemaVersion != aiFoodDraftSchemaVersion &&
        schemaVersion != aiLegacyFoodDraftSchemaVersion) {
      throw const FormatException('food_draft_unsupported_schema_version');
    }
    final date = _validDateOrNull(json['date']) ?? _validDateOrNull(legacyDate);
    if (date == null) {
      throw const FormatException('food_draft_missing_date');
    }
    final mealName = (json['meal_name'] ?? '').toString().trim();
    if (mealName.isEmpty) {
      throw const FormatException('food_draft_missing_meal_name');
    }
    final draft = AiFoodDraft(
      date: date,
      mealName: mealName,
      totalWeightG: _nonNegativeFiniteNumber(json['total_weight_g']),
      caloriesKcal: _nonNegativeFiniteNumber(json['calories_kcal']),
      proteinG: _nonNegativeFiniteNumber(json['protein_g']),
      carbsG: _nonNegativeFiniteNumber(json['carbs_g']),
      fatG: _nonNegativeFiniteNumber(json['fat_g']),
      confidence: _confidenceOrNull(json['confidence']),
      estimationNotes: (json['estimation_notes'] ?? '').toString().trim(),
      items: _draftItems(json['items']),
    );
    return draft.withItemTotalsIfPresent();
  }

  _FoodDraftTotals get _effectiveTotals {
    if (items.isEmpty) {
      return _FoodDraftTotals(
        totalWeightG: totalWeightG,
        caloriesKcal: caloriesKcal,
        proteinG: proteinG,
        carbsG: carbsG,
        fatG: fatG,
      );
    }
    return _FoodDraftTotals.fromItems(items);
  }

  AiFoodDraft withItemTotalsIfPresent() {
    if (items.isEmpty) {
      return this;
    }
    final totals = _FoodDraftTotals.fromItems(items);
    return AiFoodDraft(
      date: date,
      mealName: mealName,
      totalWeightG: totals.totalWeightG,
      caloriesKcal: totals.caloriesKcal,
      proteinG: totals.proteinG,
      carbsG: totals.carbsG,
      fatG: totals.fatG,
      confidence: confidence,
      estimationNotes: estimationNotes,
      items: items,
    );
  }

  Map<String, dynamic> toJson() {
    final totals = _effectiveTotals;
    return <String, dynamic>{
      'schema_version': aiFoodDraftSchemaVersion,
      'date': date,
      'meal_name': mealName,
      'total_weight_g': totals.totalWeightG,
      'calories_kcal': totals.caloriesKcal,
      'protein_g': totals.proteinG,
      'carbs_g': totals.carbsG,
      'fat_g': totals.fatG,
      'confidence': confidence,
      'estimation_notes': estimationNotes,
      'items': items.map((item) => item.toJson()).toList(growable: false),
    };
  }

  FoodRecord toFoodRecord({
    String? date,
    String? modelProvider,
    String? userNote,
  }) {
    final noteParts = <String>[
      if (estimationNotes.trim().isNotEmpty) estimationNotes.trim(),
      if ((modelProvider ?? '').trim().isNotEmpty)
        'AI food estimate via ${modelProvider!.trim()}',
      if ((userNote ?? '').trim().isNotEmpty) 'User note: ${userNote!.trim()}',
    ];
    final totals = _effectiveTotals;
    return FoodRecord(
      date: date ?? this.date,
      mealName: mealName,
      totalWeightG: totals.totalWeightG,
      caloriesKcal: totals.caloriesKcal,
      proteinG: totals.proteinG,
      carbsG: totals.carbsG,
      fatG: totals.fatG,
      confidence: confidence,
      estimationNotes: noteParts.join('\n'),
      source: AppConstants.sourceAiPhoto,
      items: items.map((item) => item.toFoodItem()).toList(growable: false),
    );
  }
}

class AiFoodDraftItem {
  const AiFoodDraftItem({
    required this.name,
    required this.weightG,
    required this.caloriesKcal,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
  });

  final String name;
  final double weightG;
  final double caloriesKcal;
  final double proteinG;
  final double carbsG;
  final double fatG;

  factory AiFoodDraftItem.fromJson(Map<String, dynamic> json) {
    final name = (json['name'] ?? '').toString().trim();
    if (name.isEmpty) {
      throw const FormatException('food_draft_item_missing_name');
    }
    return AiFoodDraftItem(
      name: name,
      weightG: _nonNegativeFiniteNumber(json['weight_g']),
      caloriesKcal: _nonNegativeFiniteNumber(json['calories_kcal']),
      proteinG: _nonNegativeFiniteNumber(json['protein_g']),
      carbsG: _nonNegativeFiniteNumber(json['carbs_g']),
      fatG: _nonNegativeFiniteNumber(json['fat_g']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name,
      'weight_g': weightG,
      'calories_kcal': caloriesKcal,
      'protein_g': proteinG,
      'carbs_g': carbsG,
      'fat_g': fatG,
    };
  }

  FoodItem toFoodItem() {
    return FoodItem(
      name: name,
      estimatedWeightG: weightG,
      caloriesKcal: caloriesKcal,
      proteinG: proteinG,
      carbsG: carbsG,
      fatG: fatG,
      notes: '',
    );
  }
}

class _FoodDraftTotals {
  const _FoodDraftTotals({
    required this.totalWeightG,
    required this.caloriesKcal,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
  });

  factory _FoodDraftTotals.fromItems(List<AiFoodDraftItem> items) {
    var totalWeightG = 0.0;
    var caloriesKcal = 0.0;
    var proteinG = 0.0;
    var carbsG = 0.0;
    var fatG = 0.0;
    for (final item in items) {
      totalWeightG += item.weightG;
      caloriesKcal += item.caloriesKcal;
      proteinG += item.proteinG;
      carbsG += item.carbsG;
      fatG += item.fatG;
    }
    return _FoodDraftTotals(
      totalWeightG: totalWeightG,
      caloriesKcal: caloriesKcal,
      proteinG: proteinG,
      carbsG: carbsG,
      fatG: fatG,
    );
  }

  final double totalWeightG;
  final double caloriesKcal;
  final double proteinG;
  final double carbsG;
  final double fatG;
}

double _nonNegativeFiniteNumber(Object? value) {
  final number = value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '');
  if (number == null || !number.isFinite || number < 0) {
    throw const FormatException('food_draft_invalid_number');
  }
  return number;
}

double? _confidenceOrNull(Object? value) {
  if (value == null) {
    return null;
  }
  final confidence = _nonNegativeFiniteNumber(value);
  if (confidence > 1) {
    throw const FormatException('food_draft_invalid_confidence');
  }
  return confidence;
}

List<AiFoodDraftItem> _draftItems(Object? value) {
  if (value is! List) {
    return const <AiFoodDraftItem>[];
  }
  return value
      .map((item) {
        if (item is! Map) {
          throw const FormatException('food_draft_invalid_item');
        }
        return AiFoodDraftItem.fromJson(Map<String, dynamic>.from(item));
      })
      .toList(growable: false);
}

List<String> _stringList(Object? value) {
  if (value is! List) {
    return const <String>[];
  }
  return value.map((item) => item.toString()).toList(growable: false);
}

String? _validDateOrNull(Object? value) {
  final text = value?.toString().trim() ?? '';
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(text);
  if (match == null) return null;
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final parsed = DateTime.utc(year, month, day);
  return parsed.year == year && parsed.month == month && parsed.day == day
      ? text
      : null;
}
