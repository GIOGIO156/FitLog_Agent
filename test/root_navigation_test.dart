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
}
