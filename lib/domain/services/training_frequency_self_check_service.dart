import '../../core/constants/app_constants.dart';
import '../../core/utils/date_utils.dart';
import '../../data/repositories/workout_repository.dart';
import '../models/training_frequency_self_check_result.dart';
import '../models/user_profile.dart';
import '../models/workout_session.dart';

class TrainingFrequencySelfCheckService {
  const TrainingFrequencySelfCheckService({
    required WorkoutRepository workoutRepository,
  }) : _workoutRepository = workoutRepository;

  final WorkoutRepository _workoutRepository;

  Future<TrainingFrequencySelfCheckResult> evaluate({
    required UserProfile profile,
    required String referenceDay,
    bool respectReminderCooldown = true,
  }) async {
    final currentFrequency = _resolveTrainingFrequency(
      profile.trainingFrequencyPerWeek,
    );
    final periodDays = _resolvePeriodDays(profile.macroSelfCheckPeriodDays);
    final isEnabled = profile.macroSelfCheckEnabled;

    final end = DateUtilsX.parseDay(referenceDay);
    final start = end.subtract(Duration(days: periodDays - 1));
    final sessions = await _workoutRepository.getWorkoutSessionsBetween(
      startDate: DateUtilsX.formatDate(start),
      endDate: DateUtilsX.formatDate(end),
    );

    final sessionsByDate = <String, List<WorkoutSession>>{};
    for (final session in sessions) {
      sessionsByDate.putIfAbsent(session.date, () => <WorkoutSession>[]);
      sessionsByDate[session.date]!.add(session);
    }

    var activeTrainingDays = 0;
    for (final daySessions in sessionsByDate.values) {
      if (_isValidWorkoutDay(daySessions)) {
        activeTrainingDays += 1;
      }
    }

    final hasValidTrainingData = activeTrainingDays > 0;
    final averageWeeklyTrainingFrequency =
        activeTrainingDays / periodDays * 7.0;
    final belowRecommendedRange = averageWeeklyTrainingFrequency < 2;
    final recommendedFrequency = _clampFrequency(
      averageWeeklyTrainingFrequency.round(),
    );

    final cooldownPassed =
        !respectReminderCooldown ||
        _isReminderCooldownPassed(
          lastReminderAt: profile.lastMacroSelfCheckAt,
          referenceDay: referenceDay,
        );

    final shouldSuggestAdjustment =
        isEnabled &&
        hasValidTrainingData &&
        cooldownPassed &&
        recommendedFrequency != currentFrequency;

    return TrainingFrequencySelfCheckResult(
      isApplicable: true,
      isEnabled: isEnabled,
      periodDays: periodDays,
      activeTrainingDays: activeTrainingDays,
      averageWeeklyTrainingFrequency: averageWeeklyTrainingFrequency,
      currentTrainingFrequency: currentFrequency,
      recommendedTrainingFrequency: recommendedFrequency,
      hasValidTrainingData: hasValidTrainingData,
      shouldSuggestAdjustment: shouldSuggestAdjustment,
      belowRecommendedRange: belowRecommendedRange,
    );
  }

  bool _isValidWorkoutDay(List<WorkoutSession> sessions) {
    if (sessions.isEmpty) {
      return false;
    }

    final hasStrength = sessions.any(
      (session) => session.exerciseType == 'strength',
    );
    if (hasStrength) {
      return true;
    }

    final cardioMinutes = sessions
        .where((session) => session.exerciseType == 'cardio')
        .fold<int>(0, (sum, session) => sum + session.durationMinutes);
    if (cardioMinutes >= AppConstants.validWorkoutCardioMinutesThreshold) {
      return true;
    }

    final totalCalories = sessions.fold<double>(
      0,
      (sum, session) => sum + session.estimatedCalories,
    );
    return totalCalories >= AppConstants.validWorkoutCaloriesThreshold;
  }

  bool _isReminderCooldownPassed({
    required String? lastReminderAt,
    required String referenceDay,
  }) {
    if (lastReminderAt == null || lastReminderAt.trim().isEmpty) {
      return true;
    }
    final parsed = DateTime.tryParse(lastReminderAt);
    if (parsed == null) {
      return true;
    }
    final lastDay = DateUtilsX.formatDate(parsed);
    final diff = DateUtilsX.parseDay(
      referenceDay,
    ).difference(DateUtilsX.parseDay(lastDay)).inDays;
    return diff >= AppConstants.macroSelfCheckReminderCooldownDays;
  }

  int _resolveTrainingFrequency(int value) {
    return AppConstants.resolveTrainingFrequencyPerWeek(value);
  }

  int _resolvePeriodDays(int value) {
    return AppConstants.resolveMacroSelfCheckPeriodDays(value);
  }

  int _clampFrequency(int value) {
    if (value < 2) {
      return 2;
    }
    if (value > 5) {
      return 5;
    }
    return value;
  }
}
