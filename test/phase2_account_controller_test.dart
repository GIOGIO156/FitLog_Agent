import 'dart:async';

import 'package:fitlog_local/data/db/app_database.dart';
import 'package:fitlog_local/data/repositories/ai_local_context_permission_repository.dart';
import 'package:fitlog_local/data/repositories/active_device_repository.dart';
import 'package:fitlog_local/data/repositories/auth_repository.dart';
import 'package:fitlog_local/data/repositories/cloud_profile_repository.dart';
import 'package:fitlog_local/data/repositories/custom_exercise_repository.dart';
import 'package:fitlog_local/data/repositories/daily_summary_cache_repository.dart';
import 'package:fitlog_local/data/repositories/food_repository.dart';
import 'package:fitlog_local/data/repositories/phase2_repository_exception.dart';
import 'package:fitlog_local/data/repositories/profile_repository.dart';
import 'package:fitlog_local/data/repositories/subscription_repository.dart';
import 'package:fitlog_local/data/repositories/workout_draft_repository.dart';
import 'package:fitlog_local/data/repositories/workout_repository.dart';
import 'package:fitlog_local/core/constants/app_constants.dart';
import 'package:fitlog_local/core/utils/date_utils.dart';
import 'package:fitlog_local/domain/models/calorie_calibration_state.dart';
import 'package:fitlog_local/domain/models/auth_session.dart';
import 'package:fitlog_local/domain/models/cloud_profile.dart';
import 'package:fitlog_local/domain/models/diet_adjustment_review.dart';
import 'package:fitlog_local/domain/models/subscription_status.dart';
import 'package:fitlog_local/domain/models/user_profile.dart';
import 'package:fitlog_local/domain/models/weight_log.dart';
import 'package:fitlog_local/domain/models/workout_session.dart';
import 'package:fitlog_local/core/widgets/fitlog_bottom_nav_bar.dart';
import 'package:fitlog_local/core/widgets/fitlog_guide_sheet.dart';
import 'package:fitlog_local/domain/services/cache_maintenance_service.dart';
import 'package:fitlog_local/domain/services/carb_taper_review_service.dart';
import 'package:fitlog_local/domain/services/cloud_profile_mapper.dart';
import 'package:fitlog_local/domain/services/daily_summary_service.dart';
import 'package:fitlog_local/domain/services/diet_plan_strategy_service.dart';
import 'package:fitlog_local/domain/services/training_frequency_self_check_service.dart';
import 'package:fitlog_local/domain/services/warm_cache_coordinator.dart';
import 'package:fitlog_local/export/csv_export_service.dart';
import 'package:fitlog_local/export/xlsx_export_service.dart';
import 'package:fitlog_local/features/account/account_controller.dart';
import 'package:fitlog_local/features/ai/ai_page.dart';
import 'package:fitlog_local/features/profile/profile_page.dart';
import 'package:fitlog_local/core/localization/language_controller.dart';
import 'package:fitlog_local/core/theme/fitlog_theme.dart';
import 'package:fitlog_local/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('AccountController loads signed-in Phase 2 account state', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final cloudProfile = const CloudProfileMapper().defaultForAccount('acct_1');
    final controller = _buildController(cloudProfile: cloudProfile);

    await _initializeController(controller);

    expect(controller.authSession.isSignedIn, isTrue);
    expect(controller.subscriptionStatus.isActive, isTrue);
    expect(controller.cloudProfileState.isReady, isTrue);
    expect(controller.localContextPermission?.allowed, isFalse);
  });

  test(
    'AccountController cold start does not wait for active device claim',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final claimCompleter = Completer<void>();
      final cloudProfile = const CloudProfileMapper().defaultForAccount(
        'acct_1',
      );
      final controller = AccountController(
        authRepository: _FakeAuthRepository(),
        subscriptionRepository: _FakeSubscriptionRepository(),
        cloudProfileRepository: _FakeCloudProfileRepository(cloudProfile),
        profileRepository: _FakeProfileRepository(AppDatabase.instance),
        contextPermissionRepository: const AiLocalContextPermissionRepository(),
        activeDeviceRepository: _BlockingActiveDeviceRepository(
          claimCompleter.future,
        ),
        backendConfigured: true,
      );

      await controller.initialize().timeout(const Duration(seconds: 1));

      expect(controller.initialized, isTrue);
      expect(controller.authSession.isSignedIn, isTrue);
      expect(controller.cloudProfileState.isReady, isFalse);

      claimCompleter.complete();
      await controller.waitForBackgroundAccountState();

      expect(controller.subscriptionStatus.isActive, isTrue);
      expect(controller.cloudProfileState.isReady, isTrue);
    },
  );

  test(
    'AccountController creates a default Cloud Profile for new accounts',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final profileRepository = _FakeProfileRepository(AppDatabase.instance);
      final cloudProfileRepository = _FakeCloudProfileRepository(null);
      final controller = AccountController(
        authRepository: _FakeAuthRepository(),
        subscriptionRepository: _FakeSubscriptionRepository(),
        cloudProfileRepository: cloudProfileRepository,
        profileRepository: profileRepository,
        contextPermissionRepository: const AiLocalContextPermissionRepository(),
        backendConfigured: true,
      );

      await _initializeController(controller);

      expect(controller.authSession.isSignedIn, isTrue);
      expect(controller.cloudProfileState.isReady, isTrue);
      expect(controller.cloudProfileState.cloudProfile?.accountId, 'acct_1');
      expect(controller.cloudProfileState.cloudProfile?.profile.age, 25);
      expect(cloudProfileRepository.cloudProfile?.accountId, 'acct_1');
      expect(profileRepository.savedProfile?.age, 25);
    },
  );

  test(
    'AccountController keeps Cloud Profile ready when subscription loading fails',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final cloudProfile = const CloudProfileMapper().defaultForAccount(
        'acct_1',
      );
      final controller = AccountController(
        authRepository: _FakeAuthRepository(),
        subscriptionRepository: _FailingSubscriptionRepository(),
        cloudProfileRepository: _FakeCloudProfileRepository(cloudProfile),
        profileRepository: _FakeProfileRepository(AppDatabase.instance),
        contextPermissionRepository: const AiLocalContextPermissionRepository(),
        backendConfigured: true,
      );

      await _initializeController(controller);

      expect(controller.authSession.isSignedIn, isTrue);
      expect(controller.subscriptionStatus.state, SubscriptionState.error);
      expect(
        controller.subscriptionStatus.errorCode,
        'subscription_load_failed',
      );
      expect(controller.cloudProfileState.isReady, isTrue);
      expect(controller.aiAvailability.reason, 'subscription_inactive');
    },
  );

  test(
    'AccountController keeps Cloud Profile ready when local cache fails',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final cloudProfile = const CloudProfileMapper().defaultForAccount(
        'acct_1',
      );
      final controller = AccountController(
        authRepository: _FakeAuthRepository(),
        subscriptionRepository: _FakeSubscriptionRepository(),
        cloudProfileRepository: _FakeCloudProfileRepository(cloudProfile),
        profileRepository: _FailingCacheProfileRepository(AppDatabase.instance),
        contextPermissionRepository: const AiLocalContextPermissionRepository(),
        backendConfigured: true,
      );

      await _initializeController(controller);

      expect(controller.cloudProfileState.isReady, isTrue);
      expect(controller.cloudProfileState.cloudProfile?.accountId, 'acct_1');
    },
  );

  test('AccountController surfaces Cloud Profile failure codes', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final controller = AccountController(
      authRepository: _FakeAuthRepository(),
      subscriptionRepository: _FakeSubscriptionRepository(),
      cloudProfileRepository: const _FailingCloudProfileRepository(
        'profile_schema_mismatch',
      ),
      profileRepository: _FakeProfileRepository(AppDatabase.instance),
      contextPermissionRepository: const AiLocalContextPermissionRepository(),
      backendConfigured: true,
    );

    await _initializeController(controller);

    expect(controller.cloudProfileState.status, CloudProfileStatus.error);
    expect(controller.cloudProfileState.errorCode, 'profile_schema_mismatch');
  });

  test(
    'AccountController keeps loaded profile visible after save failure',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final cloudProfile = const CloudProfileMapper().defaultForAccount(
        'acct_1',
      );
      final cloudProfileRepository = _SaveFailingCloudProfileRepository(
        cloudProfile,
        'profile_schema_mismatch',
      );
      final controller = AccountController(
        authRepository: _FakeAuthRepository(),
        subscriptionRepository: _FakeSubscriptionRepository(),
        cloudProfileRepository: cloudProfileRepository,
        profileRepository: _FakeProfileRepository(AppDatabase.instance),
        contextPermissionRepository: const AiLocalContextPermissionRepository(),
        backendConfigured: true,
      );

      await _initializeController(controller);
      expect(controller.cloudProfileState.isReady, isTrue);

      await expectLater(
        controller.saveCloudProfile(
          cloudProfile.profile.copyWith(weightKg: 80),
        ),
        throwsA(isA<Phase2RepositoryException>()),
      );

      expect(controller.cloudProfileState.isReady, isTrue);
      expect(controller.cloudProfileState.cloudProfile?.accountId, 'acct_1');
      expect(controller.cloudProfileState.errorCode, isNull);
    },
  );

  testWidgets('AI composer clears when the account signs out', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final cloudProfile = const CloudProfileMapper().defaultForAccount('acct_1');
    final controller = _buildController(cloudProfile: cloudProfile);
    await _initializeController(controller);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AccountController>.value(value: controller),
          ChangeNotifierProvider<LanguageController>(
            create: (_) => LanguageController(),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: AiPage())),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey<String>('ai_composer_field')),
      'Keep this while I move around.',
    );
    await tester.pump();
    expect(find.text('Keep this while I move around.'), findsOneWidget);

    await controller.signOut();
    await tester.pump();

    expect(find.text('Keep this while I move around.'), findsNothing);
  });

  testWidgets('AI center status uses the Cloud Profile nickname', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final cloudProfile = CloudProfile(
      accountId: 'acct_1',
      profile: UserProfile.defaults.copyWith(nickname: 'Cloud Nick'),
      profileVersion: 1,
    );
    final controller = _buildController(cloudProfile: cloudProfile);
    await _initializeController(controller);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AccountController>.value(value: controller),
          ChangeNotifierProvider<LanguageController>(
            create: (_) => LanguageController(),
          ),
        ],
        child: MaterialApp(
          theme: buildFitLogTheme(Brightness.light),
          home: const MediaQuery(
            data: MediaQueryData(size: Size(800, 600), disableAnimations: true),
            child: Scaffold(body: AiPage()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text("I'm listening, Cloud Nick", findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('AI account sheet toggles local context permission', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final cloudProfile = const CloudProfileMapper().defaultForAccount('acct_1');
    final controller = _buildController(cloudProfile: cloudProfile);
    await _initializeController(controller);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AccountController>.value(value: controller),
          ChangeNotifierProvider<LanguageController>(
            create: (_) => LanguageController(),
          ),
        ],
        child: MaterialApp(
          theme: buildFitLogTheme(Brightness.light),
          home: const MediaQuery(
            data: MediaQueryData(size: Size(800, 600), disableAnimations: true),
            child: Scaffold(body: AiPage()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.manage_accounts_outlined));
    await tester.pumpAndSettle();

    final switchFinder = find.byKey(
      const ValueKey<String>('ai_local_context_permission_switch'),
    );
    expect(switchFinder, findsOneWidget);
    expect(controller.localContextPermission?.allowed, isFalse);

    await tester.tap(switchFinder);
    await tester.pumpAndSettle();

    expect(controller.localContextPermission?.allowed, isTrue);
    expect(tester.widget<SwitchListTile>(switchFinder).value, isTrue);
  });

  testWidgets(
    'Profile signed-out gate shows email password login and register modes',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final database = AppDatabase.instance;
      final profileRepository = _FakeProfileRepository(database);
      final controller = AccountController(
        authRepository: _SignedOutAuthRepository(),
        subscriptionRepository: _FakeSubscriptionRepository(),
        cloudProfileRepository: _FakeCloudProfileRepository(
          const CloudProfileMapper().defaultForAccount('acct_1'),
        ),
        profileRepository: profileRepository,
        contextPermissionRepository: const AiLocalContextPermissionRepository(),
        backendConfigured: true,
      );
      await _initializeController(controller);

      await tester.pumpWidget(
        _buildProfileTestApp(
          database: database,
          accountController: controller,
          profileRepository: profileRepository,
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey<String>('phase2_sign_in_entry_button')),
        findsOne,
      );
      expect(
        find.byKey(const ValueKey<String>('phase2_register_link')),
        findsOne,
      );
      expect(
        find.byKey(const ValueKey<String>('phase2_login_email_field')),
        findsNothing,
      );

      final logoTopBeforeDrag = tester.getTopLeft(find.byType(Image).first).dy;
      await tester.drag(
        find.byKey(const ValueKey<String>('phase2_sign_in_entry_button')),
        const Offset(0, -160),
      );
      await tester.pump();
      expect(tester.getTopLeft(find.byType(Image).first).dy, logoTopBeforeDrag);

      await tester.tap(
        find.byKey(const ValueKey<String>('phase2_sign_in_entry_button')),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey<String>('phase2_login_email_field')),
        findsOne,
      );
      expect(
        find.byKey(const ValueKey<String>('phase2_login_password_field')),
        findsOne,
      );
      expect(
        find.byKey(const ValueKey<String>('phase2_login_button')),
        findsOne,
      );
      final emailField = tester.widget<TextField>(
        find.byKey(const ValueKey<String>('phase2_login_email_field')),
      );
      expect(emailField.style?.fontFamily, fitLogFontFamily);
      expect(emailField.style?.fontWeight, FontWeight.w500);
      expect(emailField.decoration?.labelStyle?.fontFamily, fitLogFontFamily);
      expect(emailField.decoration?.labelStyle?.fontWeight, FontWeight.w500);

      final passwordField = tester.widget<TextField>(
        find.byKey(const ValueKey<String>('phase2_login_password_field')),
      );
      expect(passwordField.obscureText, isTrue);

      final loginButton = tester.widget<FilledButton>(
        find.descendant(
          of: find.byKey(const ValueKey<String>('phase2_login_button')),
          matching: find.byType(FilledButton),
        ),
      );
      final loginButtonTextStyle = loginButton.style?.textStyle?.resolve(
        <WidgetState>{},
      );
      expect(loginButtonTextStyle?.fontFamily, fitLogFontFamily);
      expect(loginButtonTextStyle?.fontWeight, FontWeight.w600);

      await tester.tap(
        find.byKey(const ValueKey<String>('phase2_register_link')),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey<String>('phase2_register_email_field')),
        findsOne,
      );
      expect(
        find.byKey(const ValueKey<String>('phase2_register_code_field')),
        findsOne,
      );
      expect(
        find.byKey(const ValueKey<String>('phase2_register_send_code_button')),
        findsOne,
      );
      expect(
        find.byKey(const ValueKey<String>('phase2_register_password_field')),
        findsOne,
      );
      expect(
        find.byKey(
          const ValueKey<String>('phase2_register_confirm_password_field'),
        ),
        findsOne,
      );
      expect(
        find.byKey(const ValueKey<String>('phase2_create_account_button')),
        findsOne,
      );
      expect(
        find.byKey(const ValueKey<String>('phase2_sign_in_link')),
        findsOne,
      );

      final sendCodeButton = tester.widget<TextButton>(
        find.byKey(const ValueKey<String>('phase2_register_send_code_button')),
      );
      final sendCodeTextStyle = sendCodeButton.style?.textStyle?.resolve(
        <WidgetState>{},
      );
      expect(sendCodeTextStyle?.fontFamily, fitLogFontFamily);
      expect(sendCodeTextStyle?.fontWeight, FontWeight.w600);
      expect(find.text('Profile & Settings'), findsNothing);
    },
  );

  testWidgets('Profile auth fields keep focus when keyboard inset appears', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final database = AppDatabase.instance;
    final profileRepository = _FakeProfileRepository(database);
    final controller = AccountController(
      authRepository: _SignedOutAuthRepository(),
      subscriptionRepository: _FakeSubscriptionRepository(),
      cloudProfileRepository: _FakeCloudProfileRepository(
        const CloudProfileMapper().defaultForAccount('acct_1'),
      ),
      profileRepository: profileRepository,
      contextPermissionRepository: const AiLocalContextPermissionRepository(),
      backendConfigured: true,
    );
    await _initializeController(controller);

    await tester.pumpWidget(
      _buildProfileTestApp(
        database: database,
        accountController: controller,
        profileRepository: profileRepository,
      ),
    );
    await tester.pump();

    await tester.tap(
      find.byKey(const ValueKey<String>('phase2_sign_in_entry_button')),
    );
    await tester.pump();

    final emailFinder = find.byKey(
      const ValueKey<String>('phase2_login_email_field'),
    );
    await tester.tap(emailFinder);
    await tester.pump();
    expect(tester.testTextInput.isVisible, isTrue);

    tester.view.viewInsets = const FakeViewPadding(bottom: 336);
    await tester.pump();
    expect(tester.testTextInput.isVisible, isTrue);

    await tester.enterText(emailFinder, 'gioruno156@outlook.com');
    await tester.pump();

    expect(find.text('gioruno156@outlook.com'), findsOneWidget);
    expect(emailFinder, findsOneWidget);
  });

  testWidgets('Profile login failure shows a readable notification in place', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final database = AppDatabase.instance;
    final profileRepository = _FakeProfileRepository(database);
    final controller = AccountController(
      authRepository: _FailingSignInAuthRepository(),
      subscriptionRepository: _FakeSubscriptionRepository(),
      cloudProfileRepository: _FakeCloudProfileRepository(
        const CloudProfileMapper().defaultForAccount('acct_1'),
      ),
      profileRepository: profileRepository,
      contextPermissionRepository: const AiLocalContextPermissionRepository(),
      backendConfigured: true,
    );
    await _initializeController(controller);

    await tester.pumpWidget(
      _buildProfileTestApp(
        database: database,
        accountController: controller,
        profileRepository: profileRepository,
      ),
    );
    await tester.pump();

    await tester.tap(
      find.byKey(const ValueKey<String>('phase2_sign_in_entry_button')),
    );
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey<String>('phase2_login_email_field')),
      'missing@example.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('phase2_login_password_field')),
      'wrong-password',
    );
    await tester.tap(find.byKey(const ValueKey<String>('phase2_login_button')));
    await tester.pump();

    expect(find.text('Email or password is incorrect.'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('phase2_login_email_field')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('phase2_login_password_field')),
      findsOneWidget,
    );
    expect(controller.authSession.isSignedIn, isFalse);
  });

  testWidgets('Profile cloud failure shows readable message and error code', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final database = AppDatabase.instance;
    final profileRepository = _FakeProfileRepository(database);
    final controller = AccountController(
      authRepository: _FakeAuthRepository(),
      subscriptionRepository: _FakeSubscriptionRepository(),
      cloudProfileRepository: const _FailingCloudProfileRepository(
        'profile_schema_mismatch',
      ),
      profileRepository: profileRepository,
      contextPermissionRepository: const AiLocalContextPermissionRepository(),
      backendConfigured: true,
    );
    await _initializeController(controller);

    await tester.pumpWidget(
      _buildProfileTestApp(
        database: database,
        accountController: controller,
        profileRepository: profileRepository,
      ),
    );
    await tester.pump();

    expect(
      find.text(
        'Cloud Profile fields are incomplete. Run the schema compatibility SQL.',
      ),
      findsOneWidget,
    );
    expect(find.text('Error code: profile_schema_mismatch'), findsOneWidget);
  });

  testWidgets('Profile shows current account cache while Cloud Profile loads', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final database = AppDatabase.instance;
    final profileRepository = _FakeProfileRepository(
      database,
      initialProfile: UserProfile.defaults.copyWith(nickname: 'Cached'),
    );
    final controller =
        AccountController(
            authRepository: _FakeAuthRepository(),
            subscriptionRepository: _FakeSubscriptionRepository(),
            cloudProfileRepository: _FakeCloudProfileRepository(null),
            profileRepository: profileRepository,
            contextPermissionRepository:
                const AiLocalContextPermissionRepository(),
            backendConfigured: true,
          )
          ..initialized = true
          ..authSession = const AuthSession(
            status: AuthSessionStatus.signedIn,
            accountId: 'acct_1',
            email: 'phase2@example.com',
          )
          ..cloudProfileState = const CloudProfileState.loading()
          ..cachedCloudProfileAccountId = 'acct_1'
          ..cachedCloudProfileVersion = 1;

    await tester.pumpWidget(
      _buildProfileTestApp(
        database: database,
        accountController: controller,
        profileRepository: profileRepository,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Loading cloud profile...'), findsNothing);
    expect(find.text('Cached'), findsOneWidget);
  });

  testWidgets(
    'Profile registration code failure shows registered email guidance',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final database = AppDatabase.instance;
      final profileRepository = _FakeProfileRepository(database);
      final controller = AccountController(
        authRepository: _RegisteredEmailAuthRepository(),
        subscriptionRepository: _FakeSubscriptionRepository(),
        cloudProfileRepository: _FakeCloudProfileRepository(
          const CloudProfileMapper().defaultForAccount('acct_1'),
        ),
        profileRepository: profileRepository,
        contextPermissionRepository: const AiLocalContextPermissionRepository(),
        backendConfigured: true,
      );
      await _initializeController(controller);

      await tester.pumpWidget(
        _buildProfileTestApp(
          database: database,
          accountController: controller,
          profileRepository: profileRepository,
        ),
      );
      await tester.pump();

      await tester.tap(
        find.byKey(const ValueKey<String>('phase2_register_link')),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey<String>('phase2_register_email_field')),
        'phase2@example.com',
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('phase2_register_send_code_button')),
      );
      await tester.pump();

      expect(
        find.text('This email is already registered. Sign in instead.'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('phase2_register_email_field')),
        findsOneWidget,
      );
    },
  );

  testWidgets('Profile subscription overlay can redeem an inactive account', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final database = AppDatabase.instance;
    final profileRepository = _FakeProfileRepository(database);
    final subscriptionRepository = _FakeSubscriptionRepository(
      initialState: SubscriptionState.inactive,
    );
    final controller = AccountController(
      authRepository: _FakeAuthRepository(),
      subscriptionRepository: subscriptionRepository,
      cloudProfileRepository: _FakeCloudProfileRepository(
        const CloudProfileMapper().defaultForAccount('acct_1'),
      ),
      profileRepository: profileRepository,
      contextPermissionRepository: const AiLocalContextPermissionRepository(),
      backendConfigured: true,
    );
    await _initializeController(controller);

    await tester.pumpWidget(
      _buildProfileTestApp(
        database: database,
        accountController: controller,
        profileRepository: profileRepository,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('subscription_entry_button')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('subscription_entry_button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Subscription'), findsOneWidget);
    expect(find.text('Inactive'), findsOneWidget);
    expect(
      tester
          .getSize(
            find.byKey(
              const ValueKey<String>('subscription_compact_dialog_card'),
            ),
          )
          .height,
      lessThan(420),
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('subscription_redeem_button')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('subscription_redeem_code_field')),
      'FITLOG-DEV-2026',
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('subscription_redeem_submit_button')),
    );
    await tester.pumpAndSettle();

    expect(subscriptionRepository.redeemedCode, 'FITLOG-DEV-2026');
    expect(controller.subscriptionStatus.isActive, isTrue);
    expect(find.text('Redeemed.'), findsOneWidget);
  });

  testWidgets('Profile subscription overlay shows invalid code feedback', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final database = AppDatabase.instance;
    final profileRepository = _FakeProfileRepository(database);
    final subscriptionRepository = _FakeSubscriptionRepository(
      initialState: SubscriptionState.inactive,
      redeemFailureCode: 'invalid_or_expired_code',
    );
    final controller = AccountController(
      authRepository: _FakeAuthRepository(),
      subscriptionRepository: subscriptionRepository,
      cloudProfileRepository: _FakeCloudProfileRepository(
        const CloudProfileMapper().defaultForAccount('acct_1'),
      ),
      profileRepository: profileRepository,
      contextPermissionRepository: const AiLocalContextPermissionRepository(),
      backendConfigured: true,
    );
    await _initializeController(controller);

    await tester.pumpWidget(
      _buildProfileTestApp(
        database: database,
        accountController: controller,
        profileRepository: profileRepository,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('subscription_entry_button')),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('subscription_redeem_button')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('subscription_redeem_code_field')),
      'BAD-CODE',
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('subscription_redeem_submit_button')),
    );
    await tester.pump();

    expect(find.text('Invalid or expired code.'), findsOneWidget);
    expect(controller.subscriptionStatus.state, SubscriptionState.inactive);
  });

  testWidgets('Profile subscription overlay shows redeemed code feedback', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final database = AppDatabase.instance;
    final profileRepository = _FakeProfileRepository(database);
    final subscriptionRepository = _FakeSubscriptionRepository(
      initialState: SubscriptionState.inactive,
      redeemFailureCode: 'code_already_redeemed',
    );
    final controller = AccountController(
      authRepository: _FakeAuthRepository(),
      subscriptionRepository: subscriptionRepository,
      cloudProfileRepository: _FakeCloudProfileRepository(
        const CloudProfileMapper().defaultForAccount('acct_1'),
      ),
      profileRepository: profileRepository,
      contextPermissionRepository: const AiLocalContextPermissionRepository(),
      backendConfigured: true,
    );
    await _initializeController(controller);

    await tester.pumpWidget(
      _buildProfileTestApp(
        database: database,
        accountController: controller,
        profileRepository: profileRepository,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('subscription_entry_button')),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('subscription_redeem_button')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('subscription_redeem_code_field')),
      'USED-CODE',
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('subscription_redeem_submit_button')),
    );
    await tester.pump();

    expect(find.text('Code already redeemed.'), findsOneWidget);
    expect(controller.subscriptionStatus.state, SubscriptionState.inactive);
  });

  testWidgets('Profile method guide opens above the root bottom navigation', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final database = AppDatabase.instance;
    final profileRepository = _FakeProfileRepository(database);
    final controller = AccountController(
      authRepository: _FakeAuthRepository(),
      subscriptionRepository: _FakeSubscriptionRepository(),
      cloudProfileRepository: _FakeCloudProfileRepository(
        const CloudProfileMapper().defaultForAccount('acct_1'),
      ),
      profileRepository: profileRepository,
      contextPermissionRepository: const AiLocalContextPermissionRepository(),
      backendConfigured: true,
    );
    await _initializeController(controller);
    final rootTabController = RootTabController()
      ..setIndex(RootTabIndex.profile);

    await tester.pumpWidget(
      _buildProfileTestApp(
        database: database,
        accountController: controller,
        profileRepository: profileRepository,
        withRootNavOverlay: true,
        rootTabController: rootTabController,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.info_outline_rounded).first);
    await tester.pump(const Duration(milliseconds: 80));
    await tester.pumpAndSettle();

    expect(find.text('Method Guide'), findsOneWidget);
    expect(find.byType(ModalBarrier), findsWidgets);

    final sheetRect = tester.getRect(
      find.byKey(const ValueKey<String>('fitlog_guide_sheet_panel')),
    );
    final navRect = tester.getRect(
      find.byKey(const ValueKey<String>('fitlog_bottom_nav_bar')),
    );
    expect(
      sheetRect.bottom,
      moreOrLessEquals(
        navRect.top - FitLogGuideSheetGeometry.sheetToNavGap,
        epsilon: 1,
      ),
    );
    expect(
      sheetRect.top,
      greaterThanOrEqualTo(FitLogGuideSheetGeometry.topFocusGap),
    );

    await tester.tapAt(tester.getCenter(find.text('Home')));
    await tester.pump();

    expect(rootTabController.index, RootTabIndex.profile);
    await tester.pump(const Duration(milliseconds: 600));
  });

  testWidgets('Profile sign out card clears the local profile cache', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final database = AppDatabase.instance;
    final profileRepository = _FakeProfileRepository(database);
    final controller = AccountController(
      authRepository: _FakeAuthRepository(),
      subscriptionRepository: _FakeSubscriptionRepository(),
      cloudProfileRepository: _FakeCloudProfileRepository(
        const CloudProfileMapper().defaultForAccount('acct_1'),
      ),
      profileRepository: profileRepository,
      contextPermissionRepository: const AiLocalContextPermissionRepository(),
      backendConfigured: true,
    );
    await _initializeController(controller);

    await tester.pumpWidget(
      _buildProfileTestApp(
        database: database,
        accountController: controller,
        profileRepository: profileRepository,
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey<String>('profile_sign_out_button')),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('profile_sign_out_button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(controller.authSession.isSignedIn, isFalse);
    expect(profileRepository.clearedProfile, isTrue);
    expect(
      find.byKey(const ValueKey<String>('phase2_sign_in_entry_button')),
      findsOneWidget,
    );
  });

  testWidgets('Profile changes save to cloud only from the draft bar', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final database = AppDatabase.instance;
    final profileRepository = _FakeProfileRepository(database);
    final cloudProfileRepository = _FakeCloudProfileRepository(
      const CloudProfileMapper().defaultForAccount('acct_1'),
    );
    final controller = AccountController(
      authRepository: _FakeAuthRepository(),
      subscriptionRepository: _FakeSubscriptionRepository(),
      cloudProfileRepository: cloudProfileRepository,
      profileRepository: profileRepository,
      contextPermissionRepository: const AiLocalContextPermissionRepository(),
      backendConfigured: true,
    );
    await _initializeController(controller);

    await tester.pumpWidget(
      _buildProfileTestApp(
        database: database,
        accountController: controller,
        profileRepository: profileRepository,
      ),
    );
    await tester.pumpAndSettle();

    expect(cloudProfileRepository.saveCount, 0);
    expect(
      find.byKey(const ValueKey<String>('profile_draft_save_bar')),
      findsNothing,
    );

    final bulkingPill = find
        .byKey(const ValueKey<String>('profile_phase_bulking'))
        .first;
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(bulkingPill);
    await tester.pump();

    expect(cloudProfileRepository.saveCount, 0);
    expect(
      find.byKey(const ValueKey<String>('profile_draft_save_bar')),
      findsOneWidget,
    );
    expect(find.text('1 unsaved'), findsOneWidget);

    final saveButton = tester.widget<FilledButton>(
      find.byKey(const ValueKey<String>('profile_draft_save_button')),
    );
    expect(saveButton.onPressed, isNotNull);
    saveButton.onPressed!();
    await tester.pumpAndSettle();

    expect(cloudProfileRepository.saveCount, 1);
    expect(
      cloudProfileRepository.cloudProfile?.profile.dietGoalPhase,
      AppConstants.dietGoalPhaseBulking,
    );
    expect(
      find.byKey(const ValueKey<String>('profile_draft_save_bar')),
      findsNothing,
    );
  });

  testWidgets('Past body metric edit saves only a body metric log', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final database = AppDatabase.instance;
    final profileRepository = _FakeProfileRepository(
      database,
      initialProfile: UserProfile.defaults.copyWith(
        weightKg: 65,
        bodyFatPercent: 18,
        waistCm: 75,
      ),
    );
    final cloudProfileRepository = _FakeCloudProfileRepository(
      const CloudProfileMapper().defaultForAccount('acct_1'),
    );
    final controller = AccountController(
      authRepository: _FakeAuthRepository(),
      subscriptionRepository: _FakeSubscriptionRepository(),
      cloudProfileRepository: cloudProfileRepository,
      profileRepository: profileRepository,
      contextPermissionRepository: const AiLocalContextPermissionRepository(),
      backendConfigured: true,
    );
    await _initializeController(controller);
    final rootTabController = RootTabController()
      ..setIndex(RootTabIndex.profile);

    await tester.pumpWidget(
      _buildProfileTestApp(
        database: database,
        accountController: controller,
        profileRepository: profileRepository,
        withRootNavOverlay: true,
        rootTabController: rootTabController,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('profile_body_metric_calendar_button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK').last);
    await tester.pumpAndSettle();

    final expectedDate = DateUtilsX.formatDate(
      DateUtilsX.parseDay(
        DateUtilsX.todayKey(),
      ).subtract(const Duration(days: 1)),
    );
    expect(
      find.byKey(const ValueKey<String>('profile_body_metric_date_label')),
      findsOneWidget,
    );
    expect(find.text(DateUtilsX.formatReadable(expectedDate)), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('profile_body_metric_weight_field')),
      findsOneWidget,
    );
    for (final fieldKey in <String>[
      'profile_body_metric_weight_field',
      'profile_body_metric_body_fat_field',
      'profile_body_metric_waist_field',
    ]) {
      final field = tester.widget<TextField>(
        find.byKey(ValueKey<String>(fieldKey)),
      );
      expect(field.decoration?.filled, isFalse);
      expect(field.decoration?.isCollapsed, isTrue);
    }

    await tester.tapAt(tester.getCenter(find.text('Home')));
    await tester.pump(const Duration(milliseconds: 250));
    expect(rootTabController.index, RootTabIndex.profile);

    await tester.enterText(
      find.byKey(const ValueKey<String>('profile_body_metric_weight_field')),
      '66.4',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('profile_body_metric_body_fat_field')),
      '17.2',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('profile_body_metric_waist_field')),
      '74.8',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('profile_body_metric_save_button')),
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('profile_body_metric_save_button')),
    );
    await tester.pumpAndSettle();

    expect(cloudProfileRepository.saveCount, 0);
    expect(profileRepository.weightLogSaveCount, 1);
    expect(profileRepository.savedWeightLog?.accountId, 'acct_1');
    expect(profileRepository.savedWeightLog?.date, expectedDate);
    expect(profileRepository.savedWeightLog?.weightKg, 66.4);
    expect(profileRepository.savedWeightLog?.bodyFatPercent, 17.2);
    expect(profileRepository.savedWeightLog?.waistCm, 74.8);
    expect(
      find.byKey(const ValueKey<String>('profile_body_metric_date_label')),
      findsNothing,
    );
  });

  testWidgets('Past body metric edit is blocked while Profile draft exists', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final database = AppDatabase.instance;
    final profileRepository = _FakeProfileRepository(database);
    final controller = AccountController(
      authRepository: _FakeAuthRepository(),
      subscriptionRepository: _FakeSubscriptionRepository(),
      cloudProfileRepository: _FakeCloudProfileRepository(
        const CloudProfileMapper().defaultForAccount('acct_1'),
      ),
      profileRepository: profileRepository,
      contextPermissionRepository: const AiLocalContextPermissionRepository(),
      backendConfigured: true,
    );
    await _initializeController(controller);

    await tester.pumpWidget(
      _buildProfileTestApp(
        database: database,
        accountController: controller,
        profileRepository: profileRepository,
      ),
    );
    await tester.pumpAndSettle();

    final bulkingPill = find
        .byKey(const ValueKey<String>('profile_phase_bulking'))
        .first;
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(bulkingPill);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 500));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('profile_body_metric_calendar_button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Select date'), findsNothing);
    expect(
      find.text(
        'Save or discard current Profile changes before editing past body records.',
      ),
      findsOneWidget,
    );
    expect(profileRepository.weightLogSaveCount, 0);
  });
}

Future<void> _initializeController(AccountController controller) async {
  await controller.initialize();
  await controller.waitForBackgroundAccountState();
}

AccountController _buildController({required CloudProfile cloudProfile}) {
  return AccountController(
    authRepository: _FakeAuthRepository(),
    subscriptionRepository: _FakeSubscriptionRepository(),
    cloudProfileRepository: _FakeCloudProfileRepository(cloudProfile),
    profileRepository: _FakeProfileRepository(AppDatabase.instance),
    contextPermissionRepository: const AiLocalContextPermissionRepository(),
    backendConfigured: true,
  );
}

class _BlockingActiveDeviceRepository implements ActiveDeviceRepository {
  const _BlockingActiveDeviceRepository(this.claimFuture);

  final Future<void> claimFuture;

  @override
  Future<void> claim(AuthSession session) => claimFuture;

  @override
  Future<void> assertActive() async {}

  @override
  Future<void> release() async {}
}

class _FakeAuthRepository implements AuthRepository {
  AuthSession session = const AuthSession(
    status: AuthSessionStatus.signedIn,
    accountId: 'acct_1',
    email: 'phase2@example.com',
  );

  @override
  Future<AuthSession> loadSession() async => session;

  @override
  Future<AuthSession> signInWithPassword({
    required String email,
    required String password,
  }) async => session;

  @override
  Future<void> sendRegistrationOtp(String email) async {}

  @override
  Future<AuthSession> completeRegistration({
    required String email,
    required String token,
    required String password,
  }) async => session;

  @override
  Future<void> signOut() async {
    session = const AuthSession.signedOut();
  }
}

class _SignedOutAuthRepository implements AuthRepository {
  @override
  Future<AuthSession> loadSession() async => const AuthSession.signedOut();

  @override
  Future<AuthSession> signInWithPassword({
    required String email,
    required String password,
  }) async {
    return const AuthSession.signedOut();
  }

  @override
  Future<void> sendRegistrationOtp(String email) async {}

  @override
  Future<AuthSession> completeRegistration({
    required String email,
    required String token,
    required String password,
  }) async {
    return const AuthSession.signedOut();
  }

  @override
  Future<void> signOut() async {}
}

class _FailingSignInAuthRepository extends _SignedOutAuthRepository {
  @override
  Future<AuthSession> signInWithPassword({
    required String email,
    required String password,
  }) async {
    throw const Phase2RepositoryException('invalid_credentials');
  }
}

class _RegisteredEmailAuthRepository extends _SignedOutAuthRepository {
  @override
  Future<void> sendRegistrationOtp(String email) async {
    throw const Phase2RepositoryException('email_already_registered');
  }
}

class _FakeSubscriptionRepository implements SubscriptionRepository {
  _FakeSubscriptionRepository({
    this.initialState = SubscriptionState.active,
    this.redeemFailureCode,
  }) : _state = initialState;

  final SubscriptionState initialState;
  final String? redeemFailureCode;
  SubscriptionState _state;
  String? redeemedCode;

  @override
  Future<SubscriptionStatus> getStatus(String accountId) async {
    return SubscriptionStatus(
      state: _state,
      planId: 'fitlog_ai_dev',
      provider: 'internal_dev_entitlement',
      currentPeriodEnd: _state == SubscriptionState.active
          ? DateTime.utc(2026, 7, 23)
          : null,
      checkedAt: DateTime.now().toUtc(),
    );
  }

  @override
  Future<SubscriptionRedeemResult> redeemCode(String code) async {
    final failureCode = redeemFailureCode;
    if (failureCode != null) {
      throw Phase2RepositoryException(failureCode);
    }
    redeemedCode = code.trim();
    _state = SubscriptionState.active;
    return const SubscriptionRedeemResult(ok: true, code: 'redeemed');
  }
}

class _FailingSubscriptionRepository implements SubscriptionRepository {
  @override
  Future<SubscriptionStatus> getStatus(String accountId) async {
    throw const Phase2RepositoryException('subscription_load_failed');
  }

  @override
  Future<SubscriptionRedeemResult> redeemCode(String code) async {
    throw const Phase2RepositoryException('redeem_failed');
  }
}

class _FailingCloudProfileRepository implements CloudProfileRepository {
  const _FailingCloudProfileRepository(this.code);

  final String code;

  @override
  Future<CloudProfile?> fetch(String accountId) async {
    throw Phase2RepositoryException(code);
  }

  @override
  Future<CloudProfile> save(CloudProfile cloudProfile) async {
    throw Phase2RepositoryException(code);
  }
}

class _SaveFailingCloudProfileRepository implements CloudProfileRepository {
  _SaveFailingCloudProfileRepository(this.cloudProfile, this.code);

  final CloudProfile? cloudProfile;
  final String code;

  @override
  Future<CloudProfile?> fetch(String accountId) async => cloudProfile;

  @override
  Future<CloudProfile> save(CloudProfile cloudProfile) async {
    throw Phase2RepositoryException(code);
  }
}

class _FakeCloudProfileRepository implements CloudProfileRepository {
  _FakeCloudProfileRepository(this.cloudProfile);

  CloudProfile? cloudProfile;
  int saveCount = 0;

  @override
  Future<CloudProfile?> fetch(String accountId) async => cloudProfile;

  @override
  Future<CloudProfile> save(CloudProfile cloudProfile) async {
    saveCount += 1;
    this.cloudProfile = cloudProfile;
    return cloudProfile;
  }
}

class _FakeProfileRepository extends ProfileRepository {
  _FakeProfileRepository(super.database, {UserProfile? initialProfile})
    : _profile = initialProfile ?? UserProfile.defaults;

  UserProfile _profile;
  UserProfile? savedProfile;
  _SavedWeightLog? savedWeightLog;
  int weightLogSaveCount = 0;
  bool clearedProfile = false;

  @override
  Future<UserProfile?> getProfile() async => _profile;

  @override
  Future<CalorieCalibrationState?> getCalorieCalibrationState() async => null;

  @override
  Future<List<WeightLog>> getWeightLogsBetween({
    String? accountId,
    required String startDate,
    required String endDate,
  }) async {
    return const <WeightLog>[];
  }

  @override
  Future<DietAdjustmentReview?> getLatestDietAdjustmentReview({
    String? userDecision,
  }) async {
    return null;
  }

  @override
  Future<void> saveProfile(UserProfile profile, {String? accountId}) async {
    _profile = profile;
    savedProfile = profile;
  }

  @override
  Future<void> upsertWeightLog({
    String? accountId,
    required String date,
    required double weightKg,
    double? bodyFatPercent,
    double? waistCm,
    String source = 'manual',
  }) async {
    weightLogSaveCount += 1;
    savedWeightLog = _SavedWeightLog(
      accountId: accountId,
      date: date,
      weightKg: weightKg,
      bodyFatPercent: bodyFatPercent,
      waistCm: waistCm,
      source: source,
    );
  }

  @override
  Future<void> clearProfile() async {
    clearedProfile = true;
  }
}

class _SavedWeightLog {
  const _SavedWeightLog({
    required this.accountId,
    required this.date,
    required this.weightKg,
    required this.bodyFatPercent,
    required this.waistCm,
    required this.source,
  });

  final String? accountId;
  final String date;
  final double weightKg;
  final double? bodyFatPercent;
  final double? waistCm;
  final String source;
}

class _FailingCacheProfileRepository extends _FakeProfileRepository {
  _FailingCacheProfileRepository(super.database);

  @override
  Future<void> saveProfile(UserProfile profile, {String? accountId}) async {
    throw StateError('local cache failed');
  }
}

class _FakeFoodRepository extends FoodRepository {
  _FakeFoodRepository(super.database);

  @override
  Future<double> getCaloriesInByDate(String day) async => 0;
}

class _FakeWorkoutRepository extends WorkoutRepository {
  _FakeWorkoutRepository(super.database);

  @override
  Future<double> getExerciseCaloriesByDate(String day) async => 0;

  @override
  Future<List<WorkoutSession>> getWorkoutSessionsBetween({
    required String startDate,
    required String endDate,
  }) async {
    return const <WorkoutSession>[];
  }
}

Widget _buildProfileTestApp({
  required AppDatabase database,
  required AccountController accountController,
  required _FakeProfileRepository profileRepository,
  bool withRootNavOverlay = false,
  RootTabController? rootTabController,
}) {
  final effectiveRootTabController = rootTabController ?? RootTabController();
  final rootInteractionLockController = RootInteractionLockController();
  final foodRepository = _FakeFoodRepository(database);
  final workoutRepository = _FakeWorkoutRepository(database);
  final trainingFrequencySelfCheckService = TrainingFrequencySelfCheckService(
    workoutRepository: workoutRepository,
  );
  final carbTaperReviewService = CarbTaperReviewService(
    foodRepository: foodRepository,
    workoutRepository: workoutRepository,
    profileRepository: profileRepository,
  );
  final dietPlanStrategyService = DietPlanStrategyService(
    carbTaperReviewService: carbTaperReviewService,
  );
  final dailySummaryService = DailySummaryService(
    foodRepository: foodRepository,
    workoutRepository: workoutRepository,
    profileRepository: profileRepository,
    trainingFrequencySelfCheckService: trainingFrequencySelfCheckService,
    dietPlanStrategyService: dietPlanStrategyService,
  );
  final dailySummaryCacheRepository = DailySummaryCacheRepository(database);

  return MultiProvider(
    providers: [
      Provider<AppServices>.value(
        value: AppServices(
          foodRepository: foodRepository,
          customExerciseRepository: CustomExerciseRepository(database),
          workoutRepository: workoutRepository,
          workoutDraftRepository: WorkoutDraftRepository(database),
          profileRepository: profileRepository,
          dailySummaryService: dailySummaryService,
          xlsxExportService: XlsxExportService(
            foodRepository: foodRepository,
            customExerciseRepository: CustomExerciseRepository(database),
            workoutRepository: workoutRepository,
            profileRepository: profileRepository,
            dailySummaryService: dailySummaryService,
          ),
          csvExportService: CsvExportService(
            foodRepository: foodRepository,
            customExerciseRepository: CustomExerciseRepository(database),
            workoutRepository: workoutRepository,
            profileRepository: profileRepository,
            dailySummaryService: dailySummaryService,
          ),
          carbTaperReviewService: carbTaperReviewService,
          dietPlanStrategyService: dietPlanStrategyService,
          trainingFrequencySelfCheckService: trainingFrequencySelfCheckService,
          warmCacheCoordinator: WarmCacheCoordinator(
            dailySummaryService: dailySummaryService,
          ),
          cacheMaintenanceService: CacheMaintenanceService(
            database: database,
            dailySummaryCacheRepository: dailySummaryCacheRepository,
          ),
          database: database,
        ),
      ),
      ChangeNotifierProvider<AccountController>.value(value: accountController),
      ChangeNotifierProvider<RootTabController>.value(
        value: effectiveRootTabController,
      ),
      ChangeNotifierProvider<RootInteractionLockController>.value(
        value: rootInteractionLockController,
      ),
      ChangeNotifierProvider<RefreshNotifier>(create: (_) => RefreshNotifier()),
      ChangeNotifierProvider<LanguageController>(
        create: (_) => LanguageController(),
      ),
      ChangeNotifierProvider<FitLogThemeController>(
        create: (_) => FitLogThemeController(),
      ),
    ],
    child: MaterialApp(
      theme: buildFitLogTheme(Brightness.light),
      home: Scaffold(
        extendBody: withRootNavOverlay,
        body: withRootNavOverlay
            ? Stack(
                children: <Widget>[
                  const Positioned.fill(child: ProfilePage()),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: AnimatedBuilder(
                      animation: Listenable.merge(<Listenable>[
                        effectiveRootTabController,
                        rootInteractionLockController,
                      ]),
                      builder: (context, _) {
                        return IgnorePointer(
                          ignoring:
                              rootInteractionLockController.navigationLocked,
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 180),
                            opacity:
                                rootInteractionLockController.navigationLocked
                                ? 0.42
                                : 1,
                            child: FitLogBottomNavBar(
                              items: _profileGuideTestNavItems,
                              currentIndex: effectiveRootTabController.index,
                              onTap: effectiveRootTabController.setIndex,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              )
            : const ProfilePage(),
      ),
    ),
  );
}

const _profileGuideTestNavItems = <FitLogNavItem>[
  FitLogNavItem(
    label: 'Home',
    icon: Icons.home_outlined,
    activeIcon: Icons.home_rounded,
  ),
  FitLogNavItem(
    label: 'Food',
    icon: Icons.restaurant_menu_outlined,
    activeIcon: Icons.restaurant_menu_rounded,
  ),
  FitLogNavItem(
    label: 'AI',
    icon: Icons.auto_awesome_outlined,
    activeIcon: Icons.auto_awesome_rounded,
  ),
  FitLogNavItem(
    label: 'Workout',
    icon: Icons.fitness_center_outlined,
    activeIcon: Icons.fitness_center_rounded,
  ),
  FitLogNavItem(
    label: 'Profile',
    icon: Icons.person_outline_rounded,
    activeIcon: Icons.person_rounded,
  ),
];
