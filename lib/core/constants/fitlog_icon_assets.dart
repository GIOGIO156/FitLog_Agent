class FitLogIconAssets {
  FitLogIconAssets._();

  static const String macroProtein = 'assets/icons/macros/protein.png';
  static const String macroCarbs = 'assets/icons/macros/carbs.png';
  static const String macroFat = 'assets/icons/macros/fat.png';

  static const String strategy = 'assets/icons/common/strategy.png';
  static const String food = 'assets/icons/common/food.png';
  static const String workout = 'assets/icons/common/workout.png';
  static const String flame = 'assets/icons/common/flame.svg';

  static const String exerciseBenchPress =
      'assets/icons/exercises/bench_press.png';
  static const String exerciseCableFly = 'assets/icons/exercises/cable_fly.png';
  static const String exerciseDeadlift = 'assets/icons/exercises/deadlift.png';
  static const String exerciseDumbbellBicepsCurl =
      'assets/icons/exercises/dumbbell_biceps_curl.png';
  static const String exerciseDumbbellFly =
      'assets/icons/exercises/dumbbell_fly.png';
  static const String exerciseBarbellBicepsCurl =
      'assets/icons/exercises/barbell_biceps_curl.png';
  static const String exerciseBentOverBarbellRow =
      'assets/icons/exercises/bent_over_barbell_row.png';
  static const String exerciseLateralRaise =
      'assets/icons/exercises/lateral_raise.png';
  static const String exerciseLatPulldown =
      'assets/icons/exercises/lat_pulldown.png';
  static const String exerciseOverheadPress =
      'assets/icons/exercises/overhead_press.png';
  static const String exercisePullUp = 'assets/icons/exercises/pull_up.png';
  static const String exerciseRunning = 'assets/icons/exercises/running.png';
  static const String exerciseSeatedRow =
      'assets/icons/exercises/seated_row.png';
  static const String exerciseSquat = 'assets/icons/exercises/squat.png';

  static const String workoutChest = 'assets/icons/workouts/chest.png';
  static const String workoutBack = 'assets/icons/workouts/back.png';
  static const String workoutLegs = 'assets/icons/workouts/legs.png';
  static const String workoutShoulders = 'assets/icons/workouts/shoulders.png';
  static const String workoutArms = 'assets/icons/workouts/arms.png';
  static const String workoutCore = 'assets/icons/workouts/core.png';
  static const String workoutCardio = 'assets/icons/workouts/cardio.png';
  static const String workoutFullBody = 'assets/icons/workouts/full_body.png';

  static String workoutAssetForBodyPart(String bodyPart) {
    switch (bodyPart) {
      case 'Chest':
        return workoutChest;
      case 'Back':
        return workoutBack;
      case 'Legs':
      case 'Glutes':
        return workoutLegs;
      case 'Shoulders':
        return workoutShoulders;
      case 'Arms':
        return workoutArms;
      case 'Core':
        return workoutCore;
      case 'Cardio':
        return workoutCardio;
      case 'Full Body':
      default:
        return workoutFullBody;
    }
  }

  static String? exerciseAssetForExerciseKey(String? exerciseKey) {
    switch ((exerciseKey ?? '').trim()) {
      case 'barbell_flat_bench_press':
      case 'bench_press':
      case 'close_grip_bench_press':
        return exerciseBenchPress;
      case 'cable_fly':
        return exerciseCableFly;
      case 'deadlift':
        return exerciseDeadlift;
      case 'dumbbell_biceps_curl':
        return exerciseDumbbellBicepsCurl;
      case 'dumbbell_fly':
        return exerciseDumbbellFly;
      case 'barbell_biceps_curl':
        return exerciseBarbellBicepsCurl;
      case 'bent_over_barbell_row':
        return exerciseBentOverBarbellRow;
      case 'lateral_raise':
        return exerciseLateralRaise;
      case 'lat_pulldown':
        return exerciseLatPulldown;
      case 'barbell_overhead_press':
      case 'overhead_press':
        return exerciseOverheadPress;
      case 'pull_up':
        return exercisePullUp;
      case 'running':
        return exerciseRunning;
      case 'seated_row':
      case 'seated_cable_row':
        return exerciseSeatedRow;
      case 'squat':
        return exerciseSquat;
      default:
        return null;
    }
  }

  static String? exerciseAssetForExercise(String exerciseName) {
    switch (exerciseName.trim()) {
      case 'Barbell Flat Bench Press':
      case 'Bench Press':
      case 'Close-grip Bench Press':
      case '卧推':
      case '杠铃卧推':
      case '平板卧推':
      case '杠铃平板卧推':
      case '杠铃窄距平板卧推':
        return exerciseBenchPress;
      case 'Cable Fly':
        return exerciseCableFly;
      case 'Deadlift':
        return exerciseDeadlift;
      case 'Dumbbell Biceps Curl':
        return exerciseDumbbellBicepsCurl;
      case 'Dumbbell Fly':
        return exerciseDumbbellFly;
      case 'Barbell Biceps Curl':
        return exerciseBarbellBicepsCurl;
      case 'Bent-over Barbell Row':
        return exerciseBentOverBarbellRow;
      case 'Lateral Raise':
        return exerciseLateralRaise;
      case 'Lat Pulldown':
        return exerciseLatPulldown;
      case 'Barbell Overhead Press':
      case 'Overhead Press':
        return exerciseOverheadPress;
      case 'Pull-up':
        return exercisePullUp;
      case 'Running':
        return exerciseRunning;
      case 'Seated Cable Row':
      case 'Seated Row':
        return exerciseSeatedRow;
      case 'Squat':
        return exerciseSquat;
      default:
        return null;
    }
  }
}
