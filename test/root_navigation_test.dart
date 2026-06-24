import 'package:fitlog_local/app.dart';
import 'package:fitlog_local/core/widgets/fitlog_bottom_nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('RootTabIndex keeps AI centered between Food and Workout', () {
    expect(RootTabIndex.home, 0);
    expect(RootTabIndex.food, 1);
    expect(RootTabIndex.ai, 2);
    expect(RootTabIndex.workout, 3);
    expect(RootTabIndex.profile, 4);
  });

  testWidgets('FitLogBottomNavBar renders five tabs and taps Workout index', (
    tester,
  ) async {
    int? tappedIndex;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: FitLogBottomNavBar(
            currentIndex: RootTabIndex.ai,
            onTap: (index) => tappedIndex = index,
            items: const <FitLogNavItem>[
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
            ],
          ),
        ),
      ),
    );

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Food'), findsOneWidget);
    expect(find.text('AI'), findsOneWidget);
    expect(find.text('Workout'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);

    await tester.tap(find.text('Workout'));
    await tester.pump();

    expect(tappedIndex, RootTabIndex.workout);
  });

  testWidgets('FitLogBottomNavBar layout helpers separate screen and SafeArea', (
    tester,
  ) async {
    Future<Map<String, double>> capture(double safeBottom) async {
      final values = <String, double>{};

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: const Size(390, 844),
              viewPadding: EdgeInsets.only(bottom: safeBottom),
            ),
            child: Builder(
              builder: (context) {
                values['fullFootprint'] =
                    FitLogBottomNavBar.fullScreenFootprintFor(context);
                values['safeAreaOverlap'] =
                    FitLogBottomNavBar.safeAreaContentOverlapFor(context);
                values['homeReserve'] =
                    FitLogBottomNavBar.homeFirstScreenBottomReserveFor(context);
                values['scrollPadding'] =
                    FitLogBottomNavBar.scrollBottomPaddingFor(context);
                values['controlScreenPadding'] =
                    FitLogBottomNavBar.floatingControlScreenBottomPaddingFor(
                      context,
                    );
                values['controlNavGap'] =
                    values['controlScreenPadding']! - values['fullFootprint']!;
                values['controlSafeAreaPadding'] =
                    FitLogBottomNavBar.floatingControlSafeAreaBottomPaddingFor(
                      context,
                    );
                values['controlScrollPadding'] =
                    FitLogBottomNavBar.floatingControlScrollBottomPaddingFor(
                      context,
                    );
                values['controlScreenScrollPadding'] =
                    FitLogBottomNavBar.floatingControlScreenScrollBottomPaddingFor(
                      context,
                    );
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      return values;
    }

    var values = await capture(0);
    expect(values['fullFootprint'], 84);
    expect(values['safeAreaOverlap'], 84);
    expect(values['homeReserve'], 84);
    expect(values['scrollPadding'], 116);
    expect(values['controlScreenPadding'], 92);
    expect(values['controlNavGap'], 8);
    expect(values['controlSafeAreaPadding'], 92);
    expect(values['controlScrollPadding'], 184);
    expect(values['controlScreenScrollPadding'], 184);

    values = await capture(24);
    expect(values['fullFootprint'], 96);
    expect(values['safeAreaOverlap'], 72);
    expect(values['homeReserve'], 72);
    expect(values['scrollPadding'], 104);
    expect(values['controlScreenPadding'], 104);
    expect(values['controlNavGap'], 8);
    expect(values['controlSafeAreaPadding'], 80);
    expect(values['controlScrollPadding'], 172);
    expect(values['controlScreenScrollPadding'], 196);

    values = await capture(34);
    expect(values['fullFootprint'], 106);
    expect(values['safeAreaOverlap'], 72);
    expect(values['homeReserve'], 72);
    expect(values['scrollPadding'], 104);
    expect(values['controlScreenPadding'], 114);
    expect(values['controlNavGap'], 8);
    expect(values['controlSafeAreaPadding'], 80);
    expect(values['controlScrollPadding'], 172);
    expect(values['controlScreenScrollPadding'], 206);
  });
}
