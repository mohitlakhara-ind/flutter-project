import 'package:flutter/material.dart';
import '../main.dart'; // To access HomeScreen currently
import 'todo_screen.dart';
import 'time_management_screen.dart';

class MainDashboard extends StatefulWidget {
  final String userId;
  const MainDashboard({super.key, required this.userId});

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  int _currentIndex = 0;

  late final List<Widget> _screens = [
    HomeScreen(userId: widget.userId), // The original notes home screen from main.dart
    TodoScreen(userId: widget.userId),
    TimeManagementScreen(userId: widget.userId),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            IndexedStack(
              index: _currentIndex,
              children: _screens,
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
              width: 1,
            )
          )
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          elevation: 0,
          indicatorColor: const Color(0xFF0EA5E9).withOpacity(0.2),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.sticky_note_2_outlined),
              selectedIcon: Icon(Icons.sticky_note_2, color: Color(0xFF0EA5E9)),
              label: 'Notes',
            ),
            NavigationDestination(
              icon: Icon(Icons.check_circle_outline),
              selectedIcon: Icon(Icons.check_circle, color: Color(0xFF0EA5E9)),
              label: 'Todos',
            ),
            NavigationDestination(
              icon: Icon(Icons.timer_outlined),
              selectedIcon: Icon(Icons.timer, color: Color(0xFF0EA5E9)),
              label: 'Focus',
            ),
          ],
        ),
      ),
    );
  }
}
