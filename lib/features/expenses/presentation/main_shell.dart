import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/l10n/l10n.dart';

/// Main shell (Home, History, Stats & AI) with a centered `+` floating nav bar.
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final selectedIndex = navigationShell.currentIndex;
    final hideNavBar = selectedIndex == 3;
    final l10n = context.l10n;

    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: navigationShell,
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              ignoring: hideNavBar,
              child: AnimatedSlide(
                offset: hideNavBar ? const Offset(0, 1.4) : Offset.zero,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                child: AnimatedOpacity(
                  opacity: hideNavBar ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                      child: Center(
                        heightFactor: 1,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 480),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: context.cardBg,
                              borderRadius: BorderRadius.circular(32),
                              border: Border.all(color: context.borderColor),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(
                                    alpha: context.isDarkMode ? 0.35 : 0.09,
                                  ),
                                  blurRadius: 24,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _FloatingNavItem(
                                  icon: Icons.home_outlined,
                                  activeIcon: Icons.home_rounded,
                                  label: l10n.navHome,
                                  selected: selectedIndex == 0,
                                  onTap: () => navigationShell.goBranch(0),
                                ),
                                _FloatingNavItem(
                                  icon: Icons.receipt_long_outlined,
                                  activeIcon: Icons.receipt_long_rounded,
                                  label: l10n.navHistory,
                                  selected: selectedIndex == 1,
                                  onTap: () => navigationShell.goBranch(1),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  child: Material(
                                    color: AppColors.primaryGreen,
                                    shape: const CircleBorder(),
                                    elevation: 3,
                                    shadowColor: AppColors.primaryGreen
                                        .withValues(alpha: 0.45),
                                    child: InkWell(
                                      onTap: () =>
                                          context.push(AppRoutes.expenseNew),
                                      customBorder: const CircleBorder(),
                                      child: const SizedBox(
                                        width: 48,
                                        height: 48,
                                        child: Icon(
                                          Icons.add_rounded,
                                          color: Colors.white,
                                          size: 26,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                _FloatingNavItem(
                                  icon: Icons.insights_outlined,
                                  activeIcon: Icons.insights_rounded,
                                  label: l10n.navStats,
                                  selected: selectedIndex == 2,
                                  onTap: () => navigationShell.goBranch(2),
                                ),
                                _FloatingNavItem(
                                  icon: Icons.auto_awesome_outlined,
                                  activeIcon: Icons.auto_awesome_rounded,
                                  label: l10n.navAi,
                                  selected: selectedIndex == 3,
                                  onTap: () => navigationShell.goBranch(3),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
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
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(
            horizontal: selected ? 14 : 12,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: selected ? context.greenTint : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                scale: selected ? 1.08 : 1.0,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutBack,
                child: Icon(
                  selected ? activeIcon : icon,
                  size: 21,
                  color: selected
                      ? AppColors.primaryGreen
                      : context.textSecondary,
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                child: selected
                    ? Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          style: const TextStyle(
                            color: AppColors.primaryGreen,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
