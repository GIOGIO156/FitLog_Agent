class ExerciseDefinition {
  const ExerciseDefinition({
    required this.key,
    required this.name,
    required this.bodyPart,
    required this.exerciseType,
    this.secondaryBodyPart,
    this.strengthStructure = ExerciseStructure.compound,
    this.strengthProfile = ExerciseStrengthProfile.upperBodyCompound,
    this.loadInputMode = ExerciseLoadInputMode.totalLoad,
    this.repsInputMode = ExerciseRepsInputMode.totalReps,
    this.setMetricType = ExerciseSetMetricType.reps,
    this.defaultCardioIntensity = CardioIntensityBasis.moderate30To60,
    this.cardioMetByIntensity = const <String, double>{},
    this.isBuiltin = true,
    this.isHidden = false,
    this.legacyNames = const <String>[],
  });

  final String key;
  final String name;
  final String bodyPart;
  final String exerciseType;
  final String? secondaryBodyPart;
  final String strengthStructure;
  final String strengthProfile;
  final String loadInputMode;
  final String repsInputMode;
  final String setMetricType;
  final String defaultCardioIntensity;
  final Map<String, double> cardioMetByIntensity;
  final bool isBuiltin;
  final bool isHidden;
  final List<String> legacyNames;

  bool get isStrength => exerciseType == ExerciseType.strength;
  bool get isCardio => exerciseType == ExerciseType.cardio;
  bool get usesBodyweight =>
      loadInputMode == ExerciseLoadInputMode.bodyweightAdded;
  bool get usesAssistance =>
      loadInputMode == ExerciseLoadInputMode.assistanceLoad;
  bool get usesPerSideLoad =>
      loadInputMode == ExerciseLoadInputMode.perSideLoad;
  bool get usesPerSideReps => repsInputMode == ExerciseRepsInputMode.perSide;
  bool get usesDurationSets =>
      setMetricType == ExerciseSetMetricType.durationSeconds;

  ExerciseDefinition copyWith({
    String? key,
    String? name,
    String? bodyPart,
    String? exerciseType,
    String? secondaryBodyPart,
    String? strengthStructure,
    String? strengthProfile,
    String? loadInputMode,
    String? repsInputMode,
    String? setMetricType,
    String? defaultCardioIntensity,
    Map<String, double>? cardioMetByIntensity,
    bool? isBuiltin,
    bool? isHidden,
    List<String>? legacyNames,
  }) {
    return ExerciseDefinition(
      key: key ?? this.key,
      name: name ?? this.name,
      bodyPart: bodyPart ?? this.bodyPart,
      exerciseType: exerciseType ?? this.exerciseType,
      secondaryBodyPart: secondaryBodyPart ?? this.secondaryBodyPart,
      strengthStructure: strengthStructure ?? this.strengthStructure,
      strengthProfile: strengthProfile ?? this.strengthProfile,
      loadInputMode: loadInputMode ?? this.loadInputMode,
      repsInputMode: repsInputMode ?? this.repsInputMode,
      setMetricType: setMetricType ?? this.setMetricType,
      defaultCardioIntensity:
          defaultCardioIntensity ?? this.defaultCardioIntensity,
      cardioMetByIntensity: cardioMetByIntensity ?? this.cardioMetByIntensity,
      isBuiltin: isBuiltin ?? this.isBuiltin,
      isHidden: isHidden ?? this.isHidden,
      legacyNames: legacyNames ?? this.legacyNames,
    );
  }
}

class ExerciseType {
  ExerciseType._();

  static const String strength = 'strength';
  static const String cardio = 'cardio';
}

class ExerciseSource {
  ExerciseSource._();

  static const String builtin = 'builtin';
  static const String custom = 'custom';
  static const String adHoc = 'ad_hoc';
}

class ExerciseStructure {
  ExerciseStructure._();

  static const String compound = 'compound';
  static const String isolation = 'isolation';
  static const String fullBodyAuto = 'full_body_auto';
}

class ExerciseStrengthProfile {
  ExerciseStrengthProfile._();

  static const String upperBodyCompound = 'upper_body_compound';
  static const String lowerBodyCompound = 'lower_body_compound';
  static const String isolation = 'isolation';
  static const String fullBodyPowerOrHighDensity =
      'full_body_power_or_high_density';
}

class ExerciseLoadInputMode {
  ExerciseLoadInputMode._();

  static const String totalLoad = 'total_load';
  static const String perSideLoad = 'per_side_load';
  static const String bodyweightAdded = 'bodyweight_added';
  static const String assistanceLoad = 'assistance_load';
}

class ExerciseRepsInputMode {
  ExerciseRepsInputMode._();

  static const String totalReps = 'total_reps';
  static const String perSide = 'per_side_reps';
}

class ExerciseSetMetricType {
  ExerciseSetMetricType._();

  static const String reps = 'reps';
  static const String durationSeconds = 'duration_seconds';
}

class CardioIntensityBasis {
  CardioIntensityBasis._();

  static const String low60Plus = 'low_60_plus';
  static const String moderate30To60 = 'moderate_30_to_60';
  static const String vigorous10To30 = 'vigorous_10_to_30';
  static const String high3To10 = 'high_3_to_10';
  static const String intervalUnder3 = 'interval_under_3';

  static const List<String> values = <String>[
    low60Plus,
    moderate30To60,
    vigorous10To30,
    high3To10,
    intervalUnder3,
  ];
}
