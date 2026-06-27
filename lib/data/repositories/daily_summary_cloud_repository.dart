import 'dart:convert';

import 'package:supabase/supabase.dart' as supabase;

import '../../domain/models/cloud_runtime_context.dart';
import '../../domain/models/daily_summary.dart';
import 'active_device_repository.dart';
import 'phase2_repository_exception.dart';

abstract class DailySummaryCloudRepository {
  const DailySummaryCloudRepository();

  Future<DailySummary?> fetchSummary({
    required String accountId,
    required String date,
  });

  Future<void> upsertSummary({
    required String accountId,
    required DailySummary summary,
  });
}

class NoopDailySummaryCloudRepository extends DailySummaryCloudRepository {
  const NoopDailySummaryCloudRepository();

  @override
  Future<DailySummary?> fetchSummary({
    required String accountId,
    required String date,
  }) async {
    return null;
  }

  @override
  Future<void> upsertSummary({
    required String accountId,
    required DailySummary summary,
  }) async {}
}

class SupabaseDailySummaryCloudRepository extends DailySummaryCloudRepository {
  const SupabaseDailySummaryCloudRepository({
    required this.client,
    required this.runtimeContext,
    required this.activeDeviceRepository,
  });

  final supabase.SupabaseClient client;
  final CloudRuntimeContext runtimeContext;
  final ActiveDeviceRepository activeDeviceRepository;

  @override
  Future<DailySummary?> fetchSummary({
    required String accountId,
    required String date,
  }) async {
    if (accountId.isEmpty) {
      return null;
    }

    try {
      await activeDeviceRepository.assertActive();
      final rows = await client
          .from('daily_summaries')
          .select()
          .eq('account_id', accountId)
          .eq('date', date)
          .filter('deleted_at', 'is', null)
          .limit(1);
      if (rows.isEmpty) {
        return null;
      }
      return _summaryFromCloudRow(Map<String, dynamic>.from(rows.first));
    } on Phase2RepositoryException {
      rethrow;
    } catch (error) {
      throw _cloudRecordExceptionFor('daily_summary_fetch_failed', error);
    }
  }

  @override
  Future<void> upsertSummary({
    required String accountId,
    required DailySummary summary,
  }) async {
    if (accountId.isEmpty) {
      return;
    }

    try {
      await activeDeviceRepository.assertActive();
      final now = DateTime.now().toUtc().toIso8601String();
      final rows = await client
          .from('daily_summaries')
          .upsert(<String, dynamic>{
            'account_id': accountId,
            'date': summary.date,
            'summary_json': summary.toCacheMap(),
            'source_updated_at': now,
            'profile_version': 1,
            'algorithm_version': 'daily_summary_v1',
            'built_at': now,
            'deleted_at': null,
          }, onConflict: 'account_id,date')
          .select()
          .limit(1);
      if (rows.isEmpty) {
        throw const Phase2RepositoryException('daily_summary_save_no_row');
      }
    } on Phase2RepositoryException {
      rethrow;
    } catch (error) {
      throw _cloudRecordExceptionFor('daily_summary_save_failed', error);
    }
  }

  DailySummary _summaryFromCloudRow(Map<String, dynamic> row) {
    final raw = row['summary_json'];
    if (raw is Map) {
      return DailySummary.fromCacheMap(Map<String, dynamic>.from(raw));
    }
    if (raw is String && raw.isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return DailySummary.fromCacheMap(Map<String, dynamic>.from(decoded));
      }
    }
    throw const Phase2RepositoryException('record_schema_mismatch');
  }

  Phase2RepositoryException _cloudRecordExceptionFor(
    String fallbackCode,
    Object error,
  ) {
    if (error is Phase2RepositoryException) {
      return error;
    }
    final raw = error.toString();
    final normalized = raw.toLowerCase();
    if (normalized.contains('device_replaced') ||
        normalized.contains('not_active_device')) {
      runtimeContext.markDeviceReplaced();
      return Phase2RepositoryException('device_replaced', raw);
    }
    if (normalized.contains('row-level security') ||
        normalized.contains('permission denied') ||
        normalized.contains('401') ||
        normalized.contains('403')) {
      return Phase2RepositoryException('record_rls_denied', raw);
    }
    if (normalized.contains('socket') ||
        normalized.contains('failed host lookup') ||
        normalized.contains('connection') ||
        normalized.contains('timeout') ||
        normalized.contains('network')) {
      return Phase2RepositoryException('record_network_error', raw);
    }
    if (normalized.contains('schema cache') ||
        normalized.contains('column') ||
        normalized.contains('does not exist')) {
      return Phase2RepositoryException('record_schema_mismatch', raw);
    }
    return Phase2RepositoryException(fallbackCode, raw);
  }
}
