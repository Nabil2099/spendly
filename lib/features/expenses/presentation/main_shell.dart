import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';

/// Main shell (Dashboard, Transactions & AI) with a floating bottom nav bar.
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final selectedIndex = navigationShell.currentIndex;
    final hideNavBar = selectedIndex == 2;

    return Scaffold(
      extendBody: !hideNavBar,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: navigationShell,
          ),
        ),
      ),
      bottomNavigationBar: AnimatedSwitcher(
        duration: const Duration(milliseconds: 240),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          return SizeTransition(
            sizeFactor: animation,
            alignment: Alignment.bottomCenter,
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        child: hideNavBar
            ? const SizedBox.shrink(key: ValueKey('hidden_nav'))
            : SafeArea(
                key: const ValueKey('visible_nav'),
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  child: Center(
                    heightFactor: 1,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: context.cardBg,
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(color: context.borderColor),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(
                                      alpha: context.isDarkMode ? 0.35 : 0.08,
                                    ),
                                    blurRadius: 24,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _FloatingNavItem(
                                      icon: Icons.home_outlined,
                                      activeIcon: Icons.home_rounded,
                                      label: 'Home',
                                      selected: selectedIndex == 0,
                                      onTap: () => navigationShell.goBranch(0),
                                    ),
                                  ),
                                  Expanded(
                                    child: _FloatingNavItem(
                                      icon: Icons.receipt_long_outlined,
                                      activeIcon: Icons.receipt_long_rounded,
                                      label: 'History',
                                      selected: selectedIndex == 1,
                                      onTap: () => navigationShell.goBranch(1),
                                    ),
                                  ),
                                  Expanded(
                                    child: _FloatingNavItem(
                                      icon: Icons.auto_awesome_outlined,
                                      activeIcon: Icons.auto_awesome_rounded,
                                      label: 'AI',
                                      selected: selectedIndex == 2,
                                      onTap: () => navigationShell.goBranch(2),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Material(
                            color: AppColors.primaryGreen,
                            shape: const CircleBorder(),
                            elevation: 4,
                            shadowColor: AppColors.primaryGreen.withValues(
                              alpha: 0.4,
                            ),
                            child: InkWell(
                              onTap: () => context.push(AppRoutes.expenseNew),
                              customBorder: const CircleBorder(),
                              child: const SizedBox(
                                width: 54,
                                height: 54,
                                child: Icon(
                                  Icons.add_rounded,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _FloatingNavItem extends StatelessWidget {
  const _FloatingNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? context.greenTint : Colors.transparent,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? activeIcon : icon,
              size: 20,
              color: selected ? AppColors.primaryGreen : context.textSecondary,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected
                      ? AppColors.primaryGreen
                      : context.textSecondary,
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
