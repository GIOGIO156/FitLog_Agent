import '../data/repositories/custom_exercise_repository.dart';
import '../data/repositories/food_repository.dart';
import '../data/repositories/profile_repository.dart';
import '../data/repositories/workout_repository.dart';
import '../domain/models/diet_adjustment_review.dart';
import '../domain/models/user_profile.dart';
import '../domain/services/daily_summary_service.dart';

class ExportTableBuilder {
  ExportTableBuilder({
    required FoodRepository foodRepository,
    required CustomExerciseRepository customExerciseRepository,
    required WorkoutRepository workoutRepository,
    required ProfileRepository profileRepository,
    required DailySummaryService dailySummaryService,
  }) : _foodRepository = foodRepository,
       _customExerciseRepository = customExerciseRepository,
       _workoutRepository = workoutRepository,
       _profileRepository = profileRepository,
       _dailySummaryService = dailySummaryService;

  final FoodRepository _foodRepository;
  final CustomExerciseRepository _customExerciseRepository;
  final WorkoutRepository _workoutRepository;
  final ProfileRepository _profileRepository;
  final DailySummaryService _dailySummaryService;

  Future<List<ExportTable>> build() async {
    final foodRecords = await _foodRepository.getAllFoodRecords();
    final workoutSessions = await _workoutRepository.getAllWorkoutSessions();
    final customExercises = await _customExerciseRepository.getAllDefinitions();
    final profile =
        await _profileRepository.getProfile() ?? UserProfile.defaults;
    final dietAdjustmentReviews = await _profileRepository
        .getAllDietAdjustmentReviews();

    final tables = <ExportTable>[
      ExportTable(
        sheetName: 'Food Records',
        fileName: 'food_records.csv',
        rows: <List<dynamic>>[
          <dynamic>[
            'date',
            'meal_name',
            'total_weight_g',
            'calories_kcal',
            'protein_g',
            'carbs_g',
            'fat_g',
            'confidence',
            'source',
            'estimation_notes',
          ],
          ...foodRecords.map(
            (record) => <dynamic>[
              record.date,
              record.mealName,
              record.totalWeightG,
              record.caloriesKcal,
              record.proteinG,
              record.carbsG,
              record.fatG,
              record.confidence,
              record.source,
              record.estimationNotes,
            ],
          ),
        ],
      ),
      ExportTable(
        sheetName: 'Food Items',
        fileName: 'food_items.csv',
        rows: <List<dynamic>>[
          <dynamic>[
            'food_record_id',
            'name',
            'estimated_weight_g',
            'calories_kcal',
            'protein_g',
            'carbs_g',
            'fat_g',
            'notes',
          ],
          for (final record in foodRecords)
            for (final item in record.items)
              <dynamic>[
                record.id,
                item.name,
                item.estimatedWeightG,
                item.caloriesKcal,
                item.proteinG,
                item.carbsG,
                item.fatG,
                item.notes,
              ],
        ],
      ),
      ExportTable(
        sheetName: 'Workout Records',
        fileName: 'workout_records.csv',
        rows: <List<dynamic>>[
          <dynamic>[
            'date',
            'record_name',
            'body_part',
            'secondary_body_part',
            'exercise_key',
            'exercise_source',
            'exercise_name',
            'exercise_type',
            'duration_minutes',
            'intensity',
            'strength_profile',
            'load_input_mode',
            'reps_input_mode',
            'set_metric_type',
            'cardio_met',
            'cardio_intensity_basis',
            'cardio_active_minutes',
            'body_weight_kg_at_calculation',
            'estimated_calories',
            'notes',
            'exercise_snapshot_json',
          ],
          ...workoutSessions.map(
            (session) => <dynamic>[
              session.date,
              session.recordName ?? '',
              session.bodyPart,
              session.secondaryBodyPart ?? '',
              session.exerciseKey ?? '',
              session.exerciseSource ?? '',
              session.exerciseName,
              session.exerciseType,
              session.durationMinutes,
              session.intensity,
              session.strengthProfile ?? '',
              session.loadInputMode ?? '',
              session.repsInputMode ?? '',
              session.setMetricType ?? '',
              session.cardioMet ?? '',
              session.cardioIntensityBasis ?? '',
              session.cardioActiveMinutes ?? '',
              session.bodyWeightKgAtCalculation ?? '',
              session.estimatedCalories,
              session.notes,
              session.exerciseSnapshotJson ?? '',
            ],
          ),
        ],
      ),
      ExportTable(
        sheetName: 'Workout Sets',
        fileName: 'workout_sets.csv',
        rows: <List<dynamic>>[
          <dynamic>[
            'workout_session_id',
            'set_number',
            'weight_kg',
            'reps',
            'input_weight_kg',
            'input_reps',
            'input_duration_seconds',
            'calculation_load_kg',
            'calculation_reps',
            'load_input_mode',
            'reps_input_mode',
            'set_metric_type',
            'is_completed',
            'completed_at',
          ],
          for (final session in workoutSessions)
            for (final set in session.sets)
              <dynamic>[
                session.id,
                set.setNumber,
                set.weightKg,
                set.reps,
                set.inputWeightKg ?? '',
                set.inputReps ?? '',
                set.inputDurationSeconds ?? '',
                set.calculationLoadKg ?? '',
                set.calculationReps ?? '',
                set.loadInputMode ?? '',
                set.repsInputMode ?? '',
                set.setMetricType ?? '',
                set.isCompleted ? 1 : 0,
                set.completedAt ?? '',
              ],
        ],
      ),
      ExportTable(
        sheetName: 'Custom Exercises',
        fileName: 'custom_exercises.csv',
        rows: <List<dynamic>>[
          <dynamic>[
            'exercise_key',
            'name',
            'exercise_type',
            'body_part',
            'secondary_body_part',
            'strength_structure',
            'strength_profile',
            'load_input_mode',
            'reps_input_mode',
            'set_metric_type',
            'default_cardio_intensity',
            'is_hidden',
          ],
          ...customExercises.map(
            (exercise) => <dynamic>[
              exercise.key,
              exercise.name,
              exercise.exerciseType,
              exercise.bodyPart,
              exercise.secondaryBodyPart ?? '',
              exercise.strengthStructure,
              exercise.strengthProfile,
              exercise.loadInputMode,
              exercise.repsInputMode,
              exercise.setMetricType,
              exercise.defaultCardioIntensity,
              exercise.isHidden ? 1 : 0,
            ],
          ),
        ],
      ),
      ExportTable(
        sheetName: 'Daily Summary',
        fileName: 'daily_summary.csv',
        rows: await _buildSummaryRows(),
      ),
      ExportTable(
        sheetName: 'User Profile',
        fileName: 'user_profile.csv',
        rows: <List<dynamic>>[
          <dynamic>[
            'nickname',
            'age',
            'height_cm',
            'weight_kg',
            'sex_for_formula',
            'activity_level',
            'daily_energy_goal_type',
            'daily_energy_goal_kcal',
            'protein_ratio_percent',
            'carbs_ratio_percent',
            'fat_ratio_percent',
            'diet_goal_phase',
            'diet_calculation_mode',
            'diet_plan_strategy',
            'carb_cycle_pattern_json',
            'carb_cycle_high_multiplier',
            'carb_cycle_medium_multiplier',
            'carb_cycle_low_multiplier',
            'carb_taper_review_period_days',
            'carb_taper_target_loss_pct_per_week',
            'carb_taper_step_g',
            'carb_taper_current_delta_g',
            'last_carb_taper_review_at',
            'training_frequency_per_week',
            'macro_self_check_period_days',
            'macro_self_check_enabled',
            'last_macro_self_check_at',
          ],
          <dynamic>[
            profile.nickname ?? '',
            profile.age,
            profile.heightCm,
            profile.weightKg,
            profile.sexForFormula,
            profile.activityLevel,
            profile.dailyEnergyGoalType,
            profile.dailyEnergyGoalKcal,
            profile.proteinRatioPercent,
            profile.carbsRatioPercent,
            profile.fatRatioPercent,
            profile.dietGoalPhase,
            profile.dietCalculationMode,
            profile.dietPlanStrategy,
            profile.carbCyclePatternJson ?? '',
            profile.carbCycleHighMultiplier,
            profile.carbCycleMediumMultiplier,
            profile.carbCycleLowMultiplier,
            profile.carbTaperReviewPeriodDays,
            profile.carbTaperTargetLossPctPerWeek,
            profile.carbTaperStepG,
            profile.carbTaperCurrentDeltaG,
            profile.lastCarbTaperReviewAt ?? '',
            profile.trainingFrequencyPerWeek,
            profile.macroSelfCheckPeriodDays,
            profile.macroSelfCheckEnabled ? 1 : 0,
            profile.lastMacroSelfCheckAt ?? '',
          ],
        ],
      ),
      ExportTable(
        sheetName: 'Diet Adjustment Reviews',
        fileName: 'diet_adjustment_reviews.csv',
        rows: _buildDietAdjustmentReviewRows(dietAdjustmentReviews),
      ),
    ];

    return tables;
  }

  Future<List<List<dynamic>>> _buildSummaryRows() async {
    final uniqueDates = <String>{
      ...await _foodRepository.getDistinctDates(),
      ...await _workoutRepository.getDistinctDates(),
    }.toList()..sort();

    final rows = <List<dynamic>>[
      <dynamic>[
        'date',
        'diet_goal_phase',
        'diet_calculation_mode',
        'diet_plan_strategy',
        'carb_day_type',
        'is_energy_target_mode',
        'calories_in',
        'protein_g',
        'carbs_g',
        'fat_g',
        'exercise_calories',
        'bmr',
        'tdee_reference',
        'lifestyle_factor_used',
        'no_exercise_target_intake',
        'target_intake',
        'remaining_calories',
        'base_target_calories',
        'base_protein_target_g',
        'base_carbs_target_g',
        'base_fat_target_g',
        'final_target_calories',
        'final_protein_target_g',
        'final_carbs_target_g',
        'final_fat_target_g',
        'carb_adjustment_g',
        'carb_taper_current_delta_g',
        'calibration_confidence',
        'calibration_window_days',
        'calibration_valid_days',
        'target_protein_g',
        'target_carbs_g',
        'target_fat_g',
        'remaining_protein_g',
        'remaining_carbs_g',
        'remaining_fat_g',
        'base_macro_energy_equivalent_kcal',
        'final_macro_energy_equivalent_kcal',
        'macro_energy_equivalent_kcal',
        'diet_strategy_reason_codes',
        'macro_self_check_current_frequency',
        'macro_self_check_recommended_frequency',
        'macro_self_check_active_training_days',
        'macro_self_check_period_days',
        'macro_self_check_average_weekly_frequency',
        'macro_self_check_should_suggest',
        'macro_self_check_has_valid_training_data',
        'macro_self_check_below_recommended_range',
      ],
    ];

    for (final date in uniqueDates) {
      final daily = await _dailySummaryService.getSummaryForDate(date);
      rows.add(<dynamic>[
        date,
        daily.dietGoalPhase,
        daily.dietCalculationMode,
        daily.dietPlanStrategy,
        daily.carbDayType ?? '',
        daily.isEnergyTargetMode ? 1 : 0,
        daily.caloriesIn,
        daily.proteinG,
        daily.carbsG,
        daily.fatG,
        daily.exerciseCalories,
        daily.bmr,
        daily.tdeeReference,
        daily.lifestyleFactorUsed,
        daily.noExerciseTargetIntake,
        daily.targetIntake,
        daily.remainingCalories,
        daily.baseTargetCalories,
        daily.baseProteinTargetG,
        daily.baseCarbsTargetG,
        daily.baseFatTargetG,
        daily.finalTargetCalories,
        daily.finalProteinTargetG,
        daily.finalCarbsTargetG,
        daily.finalFatTargetG,
        daily.carbAdjustmentG,
        daily.carbTaperCurrentDeltaG,
        daily.calibrationConfidence,
        daily.calibrationWindowDays,
        daily.calibrationValidDays,
        daily.targetProteinG,
        daily.targetCarbsG,
        daily.targetFatG,
        daily.remainingProteinG,
        daily.remainingCarbsG,
        daily.remainingFatG,
        daily.baseMacroEnergyEquivalentKcal,
        daily.finalMacroEnergyEquivalentKcal,
        daily.macroEnergyEquivalentKcal,
        daily.dietStrategyReasonCodes.join('|'),
        daily.macroSelfCheckCurrentFrequency,
        daily.macroSelfCheckRecommendedFrequency,
        daily.macroSelfCheckActiveTrainingDays,
        daily.macroSelfCheckPeriodDays,
        daily.macroSelfCheckAverageWeeklyFrequency,
        daily.macroSelfCheckShouldSuggest ? 1 : 0,
        daily.macroSelfCheckHasValidTrainingData ? 1 : 0,
        daily.macroSelfCheckBelowRecommendedRange ? 1 : 0,
      ]);
    }

    return rows;
  }

  List<List<dynamic>> _buildDietAdjustmentReviewRows(
    List<DietAdjustmentReview> reviews,
  ) {
    return <List<dynamic>>[
      <dynamic>[
        'review_date',
        'window_days',
        'diet_goal_phase',
        'diet_calculation_mode',
        'diet_plan_strategy',
        'start_avg_weight_kg',
        'end_avg_weight_kg',
        'weight_change_kg',
        'loss_rate_pct_per_week',
        'target_loss_pct_per_week',
        'food_log_coverage',
        'active_training_days',
        'suggested_action',
        'suggested_carb_delta_g',
        'applied_delta_after_g',
        'confidence',
        'reason_codes_json',
        'user_decision',
      ],
      ...reviews.map(
        (review) => <dynamic>[
          review.reviewDate,
          review.windowDays,
          review.dietGoalPhase,
          review.dietCalculationMode,
          review.dietPlanStrategy,
          review.startAvgWeightKg,
          review.endAvgWeightKg,
          review.weightChangeKg,
          review.lossRatePctPerWeek,
          review.targetLossPctPerWeek,
          review.foodLogCoverage,
          review.activeTrainingDays,
          review.suggestedAction,
          review.suggestedCarbDeltaG,
          review.appliedDeltaAfterG,
          review.confidence,
          review.reasonCodesJson,
          review.userDecision,
        ],
      ),
    ];
  }
}

class ExportTable {
  const ExportTable({
    required this.sheetName,
    required this.fileName,
    required this.rows,
  });

  final String sheetName;
  final String fileName;
  final List<List<dynamic>> rows;
}
