import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/exercise_definition.dart';
import '../../core/constants/exercise_visuals.dart';
import '../../core/localization/localization_extensions.dart';
import '../../core/utils/date_utils.dart';
import '../../core/widgets/exercise_thumbnail.dart';
import '../../core/widgets/glass_panel.dart';
import '../../domain/models/workout_session.dart';

class WorkoutSessionPage extends StatefulWidget {
  const WorkoutSessionPage({super.key, required this.sessionId});

  final int sessionId;

  @override
  State<WorkoutSessionPage> createState() => _WorkoutSessionPageState();
}

class _WorkoutSessionPageState extends State<WorkoutSessionPage> {
  WorkoutSession? _session;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await context
        .read<AppServices>()
        .workoutRepository
        .getWorkoutSessionById(widget.sessionId);

    if (!mounted) {
      return;
    }

    setState(() {
      _session = data;
      _loading = false;
    });
  }

  String _weightValueText({
    required WorkoutSession session,
    required double weightKg,
  }) {
    final strings = context.strings;
    final isBodyweightExercise = AppConstants.isBodyweightExercise(
      session.exerciseName,
    );
    final isAssistedBodyweightExercise =
        AppConstants.isAssistedBodyweightExercise(session.exerciseName);

    final loadMode = session.loadInputMode;
    if (loadMode == ExerciseLoadInputMode.assistanceLoad ||
        isAssistedBodyweightExercise) {
      return '${weightKg.toStringAsFixed(1)} kg';
    }
    if ((loadMode == ExerciseLoadInputMode.bodyweightAdded ||
            isBodyweightExercise) &&
        weightKg <= 0) {
      return strings.isChinese ? '自重' : 'Bodyweight';
    }
    return '${weightKg.toStringAsFixed(1)} kg';
  }

  String _metricValueText(WorkoutSession session, int reps, int? seconds) {
    if (session.setMetricType == ExerciseSetMetricType.durationSeconds) {
      final value = seconds ?? 0;
      if (value <= 0) {
        return '--';
      }
      final minutes = value ~/ 60;
      final remainingSeconds = value % 60;
      return minutes <= 0
          ? '${value}s'
          : '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
    }
    return '× $reps';
  }

  String _weightHeader(WorkoutSession session) {
    final strings = context.strings;
    switch (session.loadInputMode) {
      case ExerciseLoadInputMode.perSideLoad:
        return strings.perSideWeightKgShortLabel;
      case ExerciseLoadInputMode.assistanceLoad:
        return strings.assistWeightKgShortLabel;
      case ExerciseLoadInputMode.bodyweightAdded:
        return strings.addedWeightKgShortLabel;
      default:
        final isBodyweightExercise = AppConstants.isBodyweightExercise(
          session.exerciseName,
        );
        final isAssistedBodyweightExercise =
            AppConstants.isAssistedBodyweightExercise(session.exerciseName);
        return isAssistedBodyweightExercise
            ? strings.assistWeightKgShortLabel
            : isBodyweightExercise
            ? strings.addedWeightKgShortLabel
            : strings.weightKgShortLabel;
    }
  }

  String _metricHeader(WorkoutSession session) {
    final strings = context.strings;
    if (session.setMetricType == ExerciseSetMetricType.durationSeconds) {
      return strings.setDurationLabel;
    }
    if (session.repsInputMode == ExerciseRepsInputMode.perSide) {
      return strings.perSideRepsLabel;
    }
    return strings.repsLabel;
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final session = _session;
    if (session == null) {
      return Scaffold(
        appBar: AppBar(title: Text(strings.workoutLogTitle)),
        body: const Center(child: Text('Workout session not found.')),
      );
    }

    final color = ExerciseVisuals.colorForBodyPart(session.bodyPart, context);
    return Scaffold(
      appBar: AppBar(title: Text(strings.workoutLogTitle)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: <Widget>[
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    ExerciseThumbnail(
                      bodyPart: session.bodyPart,
                      exerciseName: session.exerciseName,
                      color: color,
                      size: 58,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        strings.exerciseDisplayName(session.exerciseName),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(DateUtilsX.formatReadable(session.date)),
                const SizedBox(height: 4),
                Text(strings.bodyPartLabel(session.bodyPart)),
                Text(
                  '${strings.durationMinutesLabel}: ${session.durationMinutes}',
                ),
                Text(
                  '${strings.estimatedCaloriesLabel}: ${session.estimatedCalories.toStringAsFixed(0)} kcal',
                ),
                if (session.exerciseType == ExerciseType.cardio &&
                    (session.cardioIntensityBasis ?? '').isNotEmpty)
                  Text(
                    '${strings.cardioIntensityFieldLabel}: ${strings.cardioIntensityOptionLabel(session.cardioIntensityBasis!)}',
                  ),
                if (session.notes.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('${strings.notesLabel}: ${session.notes}'),
                  ),
              ],
            ),
          ),
          if (session.exerciseType == 'strength')
            GlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '${strings.totalSetsLabel}: ${session.sets.length}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    child: Row(
                      children: <Widget>[
                        SizedBox(
                          width: 44,
                          child: Text(
                            '#',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Expanded(
                          flex: 6,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 18),
                            child: Text(
                              _weightHeader(session),
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 4,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 18),
                            child: Text(
                              _metricHeader(session),
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...session.sets.asMap().entries.map((entry) {
                    final index = entry.key;
                    final set = entry.value;
                    final isStriped = index.isOdd;
                    return Container(
                      color: isStriped
                          ? Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest
                                .withValues(alpha: 0.32)
                          : Colors.transparent,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 14,
                      ),
                      child: Row(
                        children: <Widget>[
                          SizedBox(
                            width: 44,
                            child: Text(
                              '${set.setNumber}',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 6,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 18),
                              child: Text(
                                _weightValueText(
                                  session: session,
                                  weightKg: set.displayWeightKg,
                                ),
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 4,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 18),
                              child: Text(
                                _metricValueText(
                                  session,
                                  set.displayReps,
                                  set.inputDurationSeconds,
                                ),
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            )
          else
            GlassPanel(child: Text(strings.cardioNoSetPlan)),
        ],
      ),
    );
  }
}
