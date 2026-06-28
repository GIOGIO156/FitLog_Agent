enum AiAvailabilityStatus {
  signedOut,
  offline,
  subscriptionInactive,
  profileMissing,
  gatewayPending,
}

class AiAvailability {
  const AiAvailability({
    required this.status,
    required this.canEditComposer,
    required this.canSend,
    required this.reason,
  });

  final AiAvailabilityStatus status;
  final bool canEditComposer;
  final bool canSend;
  final String reason;

  bool get isReadyVisual => status == AiAvailabilityStatus.gatewayPending;
}
