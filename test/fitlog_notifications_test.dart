import 'package:fitlog_local/app.dart';
import 'package:fitlog_local/core/widgets/fitlog_bottom_nav_bar.dart';
import 'package:fitlog_local/core/widgets/fitlog_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _navItems = <FitLogNavItem>[
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

void main() {
  tearDown(FitLogNotifications.dismiss);

  testWidgets('success notification is a top lightweight notice', (
    tester,
  ) async {
    await tester.pumpWidget(
      _NotificationTestApp(
        child: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () {
                FitLogNotifications.success(context, 'Saved');
              },
              child: const Text('Show success'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Show success'));
    await tester.pump(const Duration(milliseconds: 220));

    expect(find.byKey(FitLogNotifications.successKey), findsOneWidget);
    expect(find.text('Saved'), findsOneWidget);

    final bannerTop = tester
        .getTopLeft(find.byKey(FitLogNotifications.bannerKey))
        .dy;
    final bannerBottom = tester
        .getBottomLeft(find.byKey(FitLogNotifications.bannerKey))
        .dy;
    final navTop = tester
        .getTopLeft(const ValueKey<String>('fitlog_bottom_nav_bar').finder)
        .dy;

    expect(bannerTop, lessThan(80));
    expect(bannerBottom, lessThan(navTop));

    await tester.pump(const Duration(milliseconds: 2600));
    expect(find.text('Saved'), findsNothing);
  });

  testWidgets('error notification floats above bottom navigation', (
    tester,
  ) async {
    await tester.pumpWidget(
      _NotificationTestApp(
        child: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () {
                FitLogNotifications.error(context, 'Save failed: network');
              },
              child: const Text('Show error'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Show error'));
    await tester.pump(const Duration(milliseconds: 220));

    expect(find.byKey(FitLogNotifications.errorKey), findsOneWidget);
    expect(find.text('Save failed: network'), findsOneWidget);

    final bannerBottom = tester
        .getBottomLeft(find.byKey(FitLogNotifications.bannerKey))
        .dy;
    final navTop = tester
        .getTopLeft(const ValueKey<String>('fitlog_bottom_nav_bar').finder)
        .dy;

    expect(bannerBottom, lessThan(navTop));

    FitLogNotifications.dismiss();
    await tester.pump();
  });

  testWidgets('action notification preserves the action callback', (
    tester,
  ) async {
    var retried = false;
    await tester.pumpWidget(
      _NotificationTestApp(
        child: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () {
                FitLogNotifications.action(
                  context,
                  'Upload failed',
                  actionLabel: 'Retry',
                  onPressed: () => retried = true,
                );
              },
              child: const Text('Show action'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Show action'));
    await tester.pump(const Duration(milliseconds: 220));

    expect(find.byKey(FitLogNotifications.actionKey), findsOneWidget);
    expect(find.text('Upload failed'), findsOneWidget);
    expect(find.byKey(FitLogNotifications.actionButtonKey), findsOneWidget);

    final bannerBottom = tester
        .getBottomLeft(find.byKey(FitLogNotifications.bannerKey))
        .dy;
    final navTop = tester
        .getTopLeft(const ValueKey<String>('fitlog_bottom_nav_bar').finder)
        .dy;
    expect(bannerBottom, lessThan(navTop));

    await tester.tap(find.byKey(FitLogNotifications.actionButtonKey));
    await tester.pump();

    expect(retried, isTrue);
    expect(find.byKey(FitLogNotifications.actionKey), findsNothing);
  });

  testWidgets('notification stays compact and auto-dismisses', (tester) async {
    await tester.pumpWidget(
      _NotificationTestApp(
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () => FitLogNotifications.error(context, 'Temporary'),
            child: const Text('Show temporary'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show temporary'));
    await tester.pump(const Duration(milliseconds: 220));
    expect(find.text('Temporary'), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsNothing);
    final bannerHeight = tester
        .getSize(find.byKey(FitLogNotifications.bannerKey))
        .height;
    expect(bannerHeight, lessThan(60));
    await tester.pump(const Duration(milliseconds: 5000));
    await tester.pump();
    expect(find.text('Temporary'), findsNothing);
  });

  testWidgets('leaving the foreground removes a notification', (tester) async {
    await tester.pumpWidget(
      _NotificationTestApp(
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () => FitLogNotifications.success(context, 'Saved'),
            child: const Text('Show lifecycle notice'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show lifecycle notice'));
    await tester.pump();
    expect(find.text('Saved'), findsOneWidget);

    FitLogNotifications.handleAppLifecycleState(AppLifecycleState.paused);
    await tester.pump();
    expect(find.text('Saved'), findsNothing);
  });

  testWidgets('route changes dismiss the originating notification', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: <NavigatorObserver>[
          FitLogNotifications.navigatorObserver,
        ],
        home: Scaffold(
          body: Builder(
            builder: (context) => Column(
              children: <Widget>[
                TextButton(
                  onPressed: () =>
                      FitLogNotifications.error(context, 'Route error'),
                  child: const Text('Show route error'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const Scaffold(body: Text('Next')),
                    ),
                  ),
                  child: const Text('Open next'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show route error'));
    await tester.pump();
    expect(find.text('Route error'), findsOneWidget);

    await tester.tap(find.text('Open next'));
    await tester.pumpAndSettle();
    expect(find.text('Next'), findsOneWidget);
    expect(find.text('Route error'), findsNothing);
  });

  testWidgets('same-frame route pop cannot orphan a pending notification', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: <NavigatorObserver>[
          FitLogNotifications.navigatorObserver,
        ],
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => Scaffold(
                    body: Builder(
                      builder: (pageContext) => TextButton(
                        onPressed: () {
                          FitLogNotifications.success(pageContext, 'Saved');
                          Navigator.of(pageContext).pop();
                        },
                        child: const Text('Save and close'),
                      ),
                    ),
                  ),
                ),
              ),
              child: const Text('Open editor'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open editor'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save and close'));
    await tester.pump();

    expect(find.text('Open editor'), findsOneWidget);
    expect(find.text('Saved'), findsNothing);
    await tester.pump(const Duration(milliseconds: 3000));
    expect(find.text('Saved'), findsNothing);
  });

  testWidgets('save notice shown after route pop remains time-bounded', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildFitLogTheme(Brightness.light),
        navigatorObservers: <NavigatorObserver>[
          FitLogNotifications.navigatorObserver,
        ],
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => Scaffold(
                    body: Builder(
                      builder: (pageContext) => TextButton(
                        onPressed: () {
                          final navigator = Navigator.of(pageContext);
                          FitLogNotifications.successAfterNavigation(
                            pageContext,
                            'Record saved',
                          );
                          navigator.pop();
                        },
                        child: const Text('Save record'),
                      ),
                    ),
                  ),
                ),
              ),
              child: const Text('Open record'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open record'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save record'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));

    expect(find.text('Open record'), findsOneWidget);
    expect(find.byKey(FitLogNotifications.successKey), findsOneWidget);
    expect(find.text('Record saved'), findsWidgets);
    await tester.pump(const Duration(milliseconds: 2600));
    expect(find.text('Record saved'), findsNothing);
  });
}

class _NotificationTestApp extends StatelessWidget {
  const _NotificationTestApp({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: buildFitLogTheme(Brightness.light),
      builder: (context, child) {
        return MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 844),
            viewPadding: EdgeInsets.only(bottom: 24),
          ),
          child: child!,
        );
      },
      home: Scaffold(
        body: Center(child: child),
        bottomNavigationBar: FitLogBottomNavBar(
          items: _navItems,
          currentIndex: RootTabIndex.home,
          onTap: (_) {},
        ),
      ),
    );
  }
}

extension on Key {
  Finder get finder => find.byKey(this);
}
