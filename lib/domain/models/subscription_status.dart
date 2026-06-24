enum SubscriptionState { unknown, loading, active, inactive, error }

class SubscriptionStatus {
  const SubscriptionStatus({
    required this.state,
    this.planId,
    this.provider,
    this.currentPeriodEnd,
    this.checkedAt,
    this.errorCode,
  });

  const SubscriptionStatus.unknown() : this(state: SubscriptionState.unknown);

  const SubscriptionStatus.loading() : this(state: SubscriptionState.loading);

  const SubscriptionStatus.inactive() : this(state: SubscriptionState.inactive);

  const SubscriptionStatus.error(String code)
    : this(state: SubscriptionState.error, errorCode: code);

  final SubscriptionState state;
  final String? planId;
  final String? provider;
  final DateTime? currentPeriodEnd;
  final DateTime? checkedAt;
  final String? errorCode;

  bool get isActive => state == SubscriptionState.active;
}

class SubscriptionRedeemResult {
  const SubscriptionRedeemResult({
    required this.ok,
    required this.code,
    this.planId,
    this.currentPeriodEnd,
  });

  final bool ok;
  final String code;
  final String? planId;
  final DateTime? currentPeriodEnd;

  factory SubscriptionRedeemResult.fromMap(Map<String, dynamic> map) {
    return SubscriptionRedeemResult(
      ok: map['ok'] == true,
      code: map['code']?.toString() ?? 'redeem_failed',
      planId: map['plan_id']?.toString(),
      currentPeriodEnd: DateTime.tryParse(
        map['current_period_end']?.toString() ?? '',
      ),
    );
  }
}
