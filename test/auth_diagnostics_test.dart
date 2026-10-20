import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fitlog_local/core/diagnostics/auth_diagnostic_http_client.dart';
import 'package:fitlog_local/core/diagnostics/auth_diagnostics.dart';
import 'package:fitlog_local/core/localization/app_language.dart';
import 'package:fitlog_local/core/localization/app_strings.dart';
import 'package:fitlog_local/core/localization/language_controller.dart';
import 'package:fitlog_local/core/widgets/auth_diagnostics_export_button.dart';
import 'package:fitlog_local/data/repositories/auth_repository.dart';
import 'package:fitlog_local/data/repositories/phase2_repository_exception.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fitlog_local/export/file_share_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase/supabase.dart' as supabase;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AuthDiagnostics.channel, (call) async {
          if (call.method == 'snapshot') {
            return {'network': 'wifi', 'model': 'test-phone'};
          }
          return false;
        });
  });

  AuthDiagnostics journal({int recent = 8, int incidents = 2}) =>
      AuthDiagnostics(
        maxRecent: recent,
        maxIncidents: incidents,
        snapshot: () async => {
          'network': 'wifi',
          'vpn_active': true,
          'password': 'snapshot-secret',
        },
      );

  test(
    'failure context survives successes, restart and bounded rotation',
    () async {
      var log = journal();
      await log.record('before');
      await log.record(
        'failed',
        failure: true,
        error: const SocketException('private secret'),
      );
      for (var i = 0; i < 20; i++) {
        await log.record('success_$i');
      }
      log = journal();
      var saved = jsonDecode(await log.exportJson()) as Map;
      expect((saved['recent'] as List).length, 8);
      final incident = (saved['incidents'] as List).single as Map;
      expect((incident['failure'] as Map)['event'], 'failed');
      expect((incident['before'] as List).single['event'], 'before');
      expect((incident['after'] as List).length, 5);
      expect((incident['after'] as List).first['event'], 'success_0');
      await log.record('failed_2', failure: true);
      await log.record('failed_3', failure: true);
      saved = jsonDecode(await log.exportJson()) as Map;
      expect((saved['incidents'] as List).map((e) => e['failure']['event']), [
        'failed_2',
        'failed_3',
      ]);
    },
  );

  test('exceptions and unexpected fields never persist credentials', () async {
    final log = journal();
    await log.record(
      'failed',
      failure: true,
      error: const supabase.AuthException(
        'password=secret-password&access_token=secret-token',
        code: 'secret-token',
      ),
      data: {
        'password': 'secret-password',
        'access_token': 'secret-token',
        'request_body': 'secret-body',
      },
    );
    final exported = await log.exportJson();
    for (final secret in [
      'secret-password',
      'secret-token',
      'secret-body',
      'snapshot-secret',
    ]) {
      expect(exported, isNot(contains(secret)));
      expect(
        (await SharedPreferences.getInstance()).getString(
          AuthDiagnostics.storageKey,
        ),
        isNot(contains(secret)),
      );
    }
    expect(exported, contains('unrecognized'));
    expect(exported, contains('AuthException'));
  });

  test(
    'snapshot failure and malformed journal do not escape to authentication',
    () async {
      SharedPreferences.setMockInitialValues({
        AuthDiagnostics.storageKey: 'malformed',
      });
      final log = AuthDiagnostics(
        snapshot: () => throw StateError('unavailable'),
      );
      await log.record('still_recorded');
      final saved = jsonDecode(await log.exportJson()) as Map;
      expect(saved['recent'].first['phone']['snapshot_status'], 'unavailable');
      expect(saved['journal_write_failures_this_run'], greaterThan(0));
    },
  );

  test(
    'error categories distinguish transport, server, credentials and OTP',
    () {
      final cases = <Object, String>{
        http.ClientException(
          'Failed host lookup',
          Uri.parse('https://example.invalid/auth/v1/token'),
        ): 'auth_dns_error',
        http.ClientException(
          'Connection reset',
          Uri.parse('https://example.invalid/auth/v1/token'),
        ): 'auth_network_error',
        const HandshakeException('TLS failed'): 'auth_tls_error',
        TimeoutException('timeout'): 'auth_timeout',
        supabase.AuthRetryableFetchException(statusCode: '503'):
            'auth_server_error',
        const supabase.AuthException('limited', statusCode: '429'):
            'auth_rate_limited',
        const supabase.AuthException(
          'bad password',
          code: 'invalid_credentials',
        ): 'invalid_credentials',
        const supabase.AuthException('expired', code: 'otp_expired'):
            'otp_invalid_or_expired',
        const supabase.AuthException(
          'expired',
          code: 'refresh_token_not_found',
        ): 'auth_session_invalid',
      };
      for (final entry in cases.entries) {
        expect(authFailureCode(entry.key), entry.value);
      }
      expect(
        AppStrings(AppLanguage.chinese).phase2ErrorMessage('auth_dns_error'),
        contains('解析'),
      );
      expect(
        AppStrings(AppLanguage.english).phase2ErrorMessage('auth_dns_error'),
        contains('resolved'),
      );
    },
  );

  test(
    'HTTP diagnostics preserve responses, capture clocks and redact bodies',
    () async {
      final log = journal();
      final client = AuthDiagnosticHttpClient(
        MockClient((request) async {
          expect(request.body, contains('secret-password'));
          return http.Response(
            jsonEncode({
              'code': 'invalid_credentials',
              'message': 'secret-password',
              'access_token': 'secret-token',
            }),
            400,
            headers: {
              'date': HttpDate.format(
                DateTime.now().toUtc().add(const Duration(minutes: 5)),
              ),
            },
          );
        }),
        diagnostics: log,
      );
      final response = await client.post(
        Uri.parse('https://example.invalid/auth/v1/token?grant_type=password'),
        body: 'secret-password',
      );
      expect(response.statusCode, 400);
      expect(response.body, contains('secret-token'));
      final exported = await log.exportJson();
      expect(exported, isNot(contains('secret-password')));
      expect(exported, isNot(contains('secret-token')));
      final events = (jsonDecode(exported)['recent'] as List).cast<Map>();
      final result = events.singleWhere(
        (e) => e['event'] == 'auth_http_result',
      );
      expect(result['auth_error_code'], 'invalid_credentials');
      expect(result['server_clock_offset_ms'], greaterThan(290000));
      client.close();
    },
  );

  test(
    'password connection failure is no longer shown as OTP failure',
    () async {
      final client = supabase.SupabaseClient(
        'https://example.invalid',
        'test-key',
        httpClient: MockClient((request) async {
          throw http.ClientException('Failed host lookup', request.url);
        }),
      );
      final subscription = client.auth.onAuthStateChange.listen(
        (_) {},
        onError: (Object _) {},
      );
      try {
        await expectLater(
          SupabaseAuthRepository(client).signInWithPassword(
            email: 'test@example.invalid',
            password: 'secret-password',
          ),
          throwsA(
            isA<Phase2RepositoryException>().having(
              (e) => e.code,
              'code',
              'auth_dns_error',
            ),
          ),
        );
      } finally {
        await subscription.cancel();
        await client.dispose();
        await AuthDiagnostics.instance.exportJson();
      }
    },
  );

  test(
    'expired offline recovery still clears credentials in this diagnostic release',
    () async {
      String part(Object value) =>
          base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
      final token =
          '${part({'alg': 'HS256'})}.${part({'exp': 1, 'sub': 'test-user'})}.signature';
      SharedPreferences.setMockInitialValues({
        'fitlog.supabase.auth.session': jsonEncode({
          'access_token': token,
          'refresh_token': 'secret-refresh',
          'token_type': 'bearer',
          'user': {
            'id': 'test-user',
            'app_metadata': {},
            'user_metadata': {},
            'aud': 'authenticated',
            'created_at': '2026-01-01T00:00:00Z',
          },
        }),
      });
      final client = supabase.SupabaseClient(
        'https://example.invalid',
        'test-key',
        httpClient: MockClient((request) async {
          throw http.ClientException('Failed host lookup', request.url);
        }),
      );
      final subscription = client.auth.onAuthStateChange.listen(
        (_) {},
        onError: (Object _) {},
      );
      try {
        await expectLater(
          SupabaseAuthRepository(client).loadSession(),
          throwsA(
            isA<Phase2RepositoryException>().having(
              (e) => e.code,
              'code',
              'auth_dns_error',
            ),
          ),
        );
        expect(
          (await SharedPreferences.getInstance()).getString(
            'fitlog.supabase.auth.session',
          ),
          isNull,
        );
        final exported = await AuthDiagnostics.instance.exportJson();
        expect(exported, contains('restore_exception'));
        expect(exported, isNot(contains('secret-refresh')));
        expect(exported, isNot(contains(token)));
      } finally {
        await subscription.cancel();
        await client.dispose();
      }
    },
  );

  for (final previouslyIgnored in [true, false]) {
    test(
      'sign-out retains its previous network downgrade: $previouslyIgnored',
      () async {
        String part(Object value) => base64Url
            .encode(utf8.encode(jsonEncode(value)))
            .replaceAll('=', '');
        final exp = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
        final token =
            '${part({'alg': 'HS256'})}.${part({'exp': exp, 'sub': 'test-user'})}.signature';
        final client = supabase.SupabaseClient(
          'https://example.invalid',
          'test-key',
          httpClient: MockClient((request) async {
            throw http.ClientException(
              previouslyIgnored
                  ? 'SocketException: Failed host lookup'
                  : 'SocketException: token connection failure',
              request.url,
            );
          }),
        );
        final subscription = client.auth.onAuthStateChange.listen(
          (_) {},
          onError: (Object _) {},
        );
        try {
          await client.auth.recoverSession(
            jsonEncode({
              'access_token': token,
              'refresh_token': 'secret-refresh',
              'token_type': 'bearer',
              'user': {
                'id': 'test-user',
                'app_metadata': {},
                'user_metadata': {},
                'aud': 'authenticated',
                'created_at': '2026-01-01T00:00:00Z',
              },
            }),
          );
          final action = SupabaseAuthRepository(client).signOut();
          if (previouslyIgnored) {
            await action;
          } else {
            await expectLater(
              action,
              throwsA(isA<Phase2RepositoryException>()),
            );
          }
          expect(client.auth.currentSession, isNull);
          expect(
            (await SharedPreferences.getInstance()).getString(
              'fitlog.supabase.auth.session',
            ),
            isNull,
          );
        } finally {
          await subscription.cancel();
          await client.dispose();
          await AuthDiagnostics.instance.exportJson();
        }
      },
    );
  }

  testWidgets(
    'export shares retained JSON without an account and cancellation is normal',
    (tester) async {
      final directory = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('fitlog_share_'),
      ))!;
      Map? shared;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => directory.path,
      );
      messenger.setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/share'),
        (call) async {
          shared = call.arguments as Map;
          return ''; // User dismisses the native share sheet.
        },
      );
      try {
        await tester.pumpWidget(
          ChangeNotifierProvider(
            create: (_) => LanguageController(),
            child: const MaterialApp(
              home: Scaffold(body: AuthDiagnosticsExportButton()),
            ),
          ),
        );
        await tester.runAsync(() async {
          await tester.tap(
            find.byKey(const ValueKey('export_auth_diagnostics')),
          );
          // Await the native invocation, not just the diagnostic queue.
          for (var i = 0; i < 100 && shared == null; i++) {
            await Future<void>.delayed(const Duration(milliseconds: 10));
          }
        });
        await tester.pumpAndSettle();
        expect(shared, isNotNull);
        expect(shared!['mimeTypes'], ['application/json']);
        expect(shared!['originWidth'], greaterThan(0));
        expect(shared!['originHeight'], greaterThan(0));
        final file = File((shared!['paths'] as List).single as String);
        expect(
          await tester.runAsync(file.readAsString),
          contains('export_requested'),
        );
        expect(find.textContaining('could not open'), findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        messenger.setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
        messenger.setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/share'),
          null,
        );
        await tester.runAsync(() async {
          for (final file in directory.listSync().whereType<File>()) {
            await file.delete();
          }
          await directory.delete();
        });
      }
    },
  );

  test('all export formats share a file and preserve it on failure', () async {
    final directory = await Directory.systemTemp.createTemp('fitlog_share_');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const channel = MethodChannel('dev.fluttercommunity.plus/share');
    const origin = Rect.fromLTWH(10, 10, 100, 40);
    try {
      for (final entry in {
        'json': 'application/json',
        'xlsx':
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        'zip': 'application/zip',
      }.entries) {
        final file = File('${directory.path}/export.${entry.key}');
        await file.writeAsString('retained export');
        messenger.setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'share');
          final args = call.arguments as Map;
          expect(args['paths'], [file.path]);
          expect(args['mimeTypes'], [entry.value]);
          expect(args['originX'], 10);
          return 'target.app';
        });
        expect(
          await FileShareService.shareFile(file.path, origin: origin),
          isTrue,
        );
        messenger.setMockMethodCallHandler(channel, (call) async {
          throw PlatformException(code: 'share_failed');
        });
        expect(
          await FileShareService.shareFile(file.path, origin: origin),
          isFalse,
        );
        expect(await file.readAsString(), 'retained export');
      }
    } finally {
      messenger.setMockMethodCallHandler(channel, null);
      for (final file in directory.listSync().whereType<File>()) {
        await file.delete();
      }
      await directory.delete();
    }
  });
}
