import 'package:supabase/supabase.dart' as supabase;

import '../../domain/models/subscription_status.dart';
import 'phase2_repository_exception.dart';

abstract class SubscriptionRepository {
  Future<SubscriptionStatus> getStatus(String accountId);

  Future<SubscriptionRedeemResult> redeemCode(String code);
}

class UnconfiguredSubscriptionRepository implements SubscriptionRepository {
  const UnconfiguredSubscriptionRepository();

  @override
  Future<SubscriptionStatus> getStatus(String accountId) async {
    return const SubscriptionStatus.inactive();
  }

  @override
  Future<SubscriptionRedeemResult> redeemCode(String code) async {
    throw const Phase2RepositoryException('backend_not_configured');
  }
}

class SupabaseSubscriptionRepository implements SubscriptionRepository {
  const SupabaseSubscriptionRepository(this.client);

  final supabase.SupabaseClient client;

  @override
  Future<SubscriptionStatus> getStatus(String accountId) async {
    try {
      final row = await client
          .from('subscriptions')
          .select()
          .eq('account_id', accountId)
          .maybeSingle();
      if (row == null) {
        return const SubscriptionStatus.inactive();
      }
      final status = row['status']?.toString() ?? 'inactive';
      return SubscriptionStatus(
        state: status == 'active'
            ? SubscriptionState.active
            : SubscriptionState.inactive,
        planId: row['plan_id']?.toString(),
        provider: row['provider']?.toString(),
        currentPeriodEnd: _parseDate(row['current_period_end']),
        checkedAt: DateTime.now().toUtc(),
      );
    } catch (error) {
      throw Phase2RepositoryException(
        'subscription_load_failed',
        error.toString(),
      );
    }
  }

  @override
  Future<SubscriptionRedeemResult> redeemCode(String code) async {
    try {
      final result = await client.rpc(
        'redeem_internal_subscription_code',
        params: <String, dynamic>{'input_code': code.trim()},
      );
      final map = Map<String, dynamic>.from(result as Map);
      final redeemResult = SubscriptionRedeemResult.fromMap(map);
      if (!redeemResult.ok) {
        throw Phase2RepositoryException(redeemResult.code);
      }
      return redeemResult;
    } on Phase2RepositoryException {
      rethrow;
    } catch (error) {
      throw Phase2RepositoryException('redeem_failed', error.toString());
    }
  }

  DateTime? _parseDate(Object? value) {
    if (value == null) {
      return null;
    }
    return DateTime.tryParse(value.toString());
  }
}
