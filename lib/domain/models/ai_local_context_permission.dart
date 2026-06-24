class AiLocalContextPermission {
  const AiLocalContextPermission({
    required this.accountId,
    required this.allowed,
    required this.updatedAt,
  });

  final String accountId;
  final bool allowed;
  final DateTime updatedAt;
}
