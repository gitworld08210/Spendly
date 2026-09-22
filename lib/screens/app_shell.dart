import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../widgets/bottom_nav.dart';
import 'add_transaction_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'statistics_screen.dart';
import 'transactions_screen.dart';

/// Root scaffold hosting the four tabs and the center "+" add action.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  late final List<Widget> _tabs = [
    HomeScreen(userName: AuthService.instance.displayName),
    const StatisticsScreen(),
    const TransactionsScreen(),
    const ProfileScreen(),
  ];

  void _openAdd() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AddTransactionScreen(),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: PaisaBottomNav(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        onAdd: _openAdd,
      ),
    );
  }
}
