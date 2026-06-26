import 'package:supabase/supabase.dart' as supabase;

import '../../domain/models/cloud_profile.dart';
import '../../domain/services/cloud_profile_mapper.dart';
import 'active_device_repository.dart';
import 'phase2_repository_exception.dart';

abstract class CloudProfileRepository {
  Future<CloudProfile?> fetch(String accountId);

  Future<CloudProfile> save(CloudProfile cloudProfile);
}

class UnconfiguredCloudProfileRepository implements CloudProfileRepository {
  const UnconfiguredCloudProfileRepository();

  @override
  Future<CloudProfile?> fetch(String accountId) async => null;

  @override
  Future<CloudProfile> save(CloudProfile cloudProfile) async {
    throw const Phase2RepositoryException('backend_not_configured');
  }
}

class SupabaseCloudProfileRepository implements CloudProfileRepository {
  const SupabaseCloudProfileRepository({
    required this.client,
    this.mapper = const CloudProfileMapper(),
    this.activeDeviceRepository = const NoopActiveDeviceRepository(),
  });

  final supabase.SupabaseClient client;
  final CloudProfileMapper mapper;
  final ActiveDeviceRepository activeDeviceRepository;

  @override
  Future<CloudProfile?> fetch(String accountId) async {
    try {
      final rows = await client
          .from('cloud_profiles')
          .select()
          .eq('account_id', accountId)
          .limit(1);
      if (rows.isEmpty) {
        return null;
      }
      return mapper.fromRow(Map<String, dynamic>.from(rows.first));
    } catch (error) {
      throw _profileExceptionFor('profile_fetch_failed', error);
    }
  }

  @override
  Future<CloudProfile> save(CloudProfile cloudProfile) async {
    try {
      await activeDeviceRepository.assertActive();
      final rows = await client
          .from('cloud_profiles')
          .upsert(mapper.toRow(cloudProfile))
          .select()
          .limit(1);
      if (rows.isEmpty) {
        throw const Phase2RepositoryException('profile_save_no_row');
      }
      return mapper.fromRow(Map<String, dynamic>.from(rows.first));
    } on Phase2RepositoryException {
      rethrow;
    } catch (error) {
      throw _profileExceptionFor('profile_save_failed', error);
    }
  }

  Phase2RepositoryException _profileExceptionFor(
    String fallbackCode,
    Object error,
  ) {
    final raw = error.toString();
    final normalized = raw.toLowerCase();
    String code = fallbackCode;

    if (normalized.contains('socketexception') ||
        normalized.contains('failed host lookup') ||
        normalized.contains('connection refused') ||
        normalized.contains('connection timed out') ||
        normalized.contains('network is unreachable')) {
      code = 'profile_network_error';
    } else if ((normalized.contains('jwt') || normalized.contains('session')) &&
        (normalized.contains('expired') || normalized.contains('invalid'))) {
      code = 'profile_auth_expired';
    } else if (normalized.contains('42p01') ||
        normalized.contains('cloud_profiles" does not exist') ||
        normalized.contains('cloud_profiles does not exist') ||
        normalized.contains('could not find the table')) {
      code = 'profile_table_missing';
    } else if (normalized.contains('pgrst204') ||
        (normalized.contains('could not find') &&
            normalized.contains('column')) ||
        normalized.contains('schema cache') ||
        (normalized.contains('column') &&
            normalized.contains('does not exist'))) {
      code = 'profile_schema_mismatch';
    } else if (normalized.contains('22p02') ||
        normalized.contains('invalid input syntax') ||
        normalized.contains('cannot cast') ||
        normalized.contains('invalid input value') ||
        (normalized.contains('integer') && normalized.contains('double'))) {
      code = 'profile_schema_type_mismatch';
    } else if (normalized.contains('23514') ||
        normalized.contains('check constraint') ||
        normalized.contains('violates check')) {
      code = 'profile_constraint_failed';
    } else if (normalized.contains('row-level security') ||
        normalized.contains('permission denied') ||
        normalized.contains('42501') ||
        normalized.contains('401') ||
        normalized.contains('403')) {
      code = 'profile_rls_denied';
    }

    return Phase2RepositoryException(code, raw);
  }
}
