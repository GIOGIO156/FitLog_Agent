class WorkoutDraftMutationQueue {
  Future<void> _tail = Future<void>.value();

  Future<void> run(Future<void> Function() mutation) {
    final previous = _tail;
    final next = () async {
      try {
        await previous;
      } catch (_) {
        // A final delete barrier must still run after an older failed write.
      }
      await mutation();
    }();
    _tail = next;
    return next;
  }
}
