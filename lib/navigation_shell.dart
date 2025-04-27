import 'package:flutter/material.dart';

import 'package:responsive_framework/responsive_framework.dart';

import 'analysis_page.dart';
import 'dashboard_page.dart';
import 'ingredient_page.dart';
import 'inventory_page.dart';
import 'sales_page.dart';

/// A responsive navigation shell that adapts to screen size,
/// provides consistent UI/UX, clear IA, and accessibility support.
class NavigationShell extends StatefulWidget {
  const NavigationShell({super.key});

  @override
  State<NavigationShell> createState() => _NavigationShellState();
}

class _NavigationShellState extends State<NavigationShell> {
  int _currentIndex = 0;

  final List<_NavItem> _items = [
    _NavItem(label: 'Dashboard', icon: Icons.dashboard, page: DashboardPage()),
    _NavItem(label: 'Inventory', icon: Icons.inventory, page: InventoryPage()),
    _NavItem(label: 'Sales', icon: Icons.sell, page: SalesPage()),
    _NavItem(label: 'Analysis', icon: Icons.analytics, page: AnalysisPage()),
    _NavItem(
      label: 'Ingredients',
      icon: Icons.food_bank,
      page: IngredientPage(),
    ),
  ];

  void _onSelect(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = !ResponsiveBreakpoints.of(context).smallerThan(TABLET);

    return FocusTraversalGroup(
      policy: WidgetOrderTraversalPolicy(),
      child: Scaffold(
        body: Row(
          children: [
            if (isDesktop)
              NavigationRail(
                selectedIndex: _currentIndex,
                onDestinationSelected: _onSelect,
                labelType: NavigationRailLabelType.selected,
                leading: Semantics(
                  label: 'Main menu',
                  child: IconButton(icon: Icon(Icons.menu), onPressed: () {}),
                ),
                destinations:
                    _items
                        .map(
                          (item) => NavigationRailDestination(
                            icon: Semantics(
                              label: item.label,
                              child: Icon(item.icon),
                            ),
                            selectedIcon: Icon(item.icon, size: 28),
                            label: Text(item.label),
                          ),
                        )
                        .toList(),
              ),
            Expanded(child: _items[_currentIndex].page),
          ],
        ),
        bottomNavigationBar:
            !isDesktop
                ? Semantics(
                  container: true,
                  label: 'Bottom navigation',
                  child: BottomNavigationBar(
                    currentIndex: _currentIndex,
                    onTap: _onSelect,
                    items:
                        _items
                            .map(
                              (item) => BottomNavigationBarItem(
                                icon: Semantics(
                                  label: item.label,
                                  child: Icon(item.icon),
                                ),
                                label: item.label,
                              ),
                            )
                            .toList(),
                    type: BottomNavigationBarType.fixed,
                    selectedFontSize: 12,
                    unselectedFontSize: 12,
                    showUnselectedLabels: true,
                    // Accessibility: ensure touch target
                    selectedItemColor: Theme.of(context).colorScheme.primary,
                  ),
                )
                : null,
      ),
    );
  }
}

/// Internal model for navigation items
class _NavItem {
  final String label;
  final IconData icon;
  final Widget page;
  const _NavItem({required this.label, required this.icon, required this.page});
}
