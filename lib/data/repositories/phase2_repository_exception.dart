class Phase2RepositoryException implements Exception {
  const Phase2RepositoryException(this.code, [this.message]);

  final String code;
  final String? message;

  @override
  String toString() => message == null ? code : '$code: $message';
}
