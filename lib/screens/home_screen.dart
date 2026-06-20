import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'people_screen.dart';
import 'purchases_screen.dart';
import 'settlement_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  static const _tabs = [
    PurchasesScreen(),
    SettlementScreen(),
    PeopleScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final loading = context.select<AppState, bool>((s) => s.loading);

    return Scaffold(
      body: loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            )
          : IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          border: Border(top: BorderSide(color: AppTheme.outline)),
        ),
        child: SafeArea(
          top: false,
          child: NavigationBarTheme(
            data: NavigationBarThemeData(
              backgroundColor: Colors.transparent,
              indicatorColor: AppTheme.primary.withValues(alpha: 0.16),
              labelTextStyle: WidgetStateProperty.resolveWith(
                (states) => TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: states.contains(WidgetState.selected)
                      ? AppTheme.primary
                      : AppTheme.textSecondary,
                ),
              ),
              iconTheme: WidgetStateProperty.resolveWith(
                (states) => IconThemeData(
                  color: states.contains(WidgetState.selected)
                      ? AppTheme.primary
                      : AppTheme.textSecondary,
                ),
              ),
            ),
            child: NavigationBar(
              height: 64,
              elevation: 0,
              backgroundColor: Colors.transparent,
              labelBehavior:
                  NavigationDestinationLabelBehavior.alwaysShow,
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.receipt_long_outlined),
                  selectedIcon: Icon(Icons.receipt_long),
                  label: 'Purchases',
                ),
                NavigationDestination(
                  icon: Icon(Icons.handshake_outlined),
                  selectedIcon: Icon(Icons.handshake),
                  label: 'Settle',
                ),
                NavigationDestination(
                  icon: Icon(Icons.group_outlined),
                  selectedIcon: Icon(Icons.group),
                  label: 'People',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
