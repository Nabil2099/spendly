import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Lightweight 3-slide onboarding flow shown on first launch.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onComplete});

  final VoidCallback onComplete;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  static const _slides = [
    _OnboardingSlideData(
      icon: Icons.account_balance_wallet_rounded,
      accentColor: AppColors.primaryGreen,
      surfaceColor: AppColors.primaryGreenLight,
      title: 'Track Daily Expenses',
      description: 'Record every EGP expense in seconds with clear categories and optional notes.',
    ),
    _OnboardingSlideData(
      icon: Icons.donut_large_rounded,
      accentColor: AppColors.sandyAccent,
      surfaceColor: AppColors.warmSurface,
      title: 'Stay Within Budget',
      description: 'Set a monthly spending limit and watch your remaining balance update live.',
    ),
    _OnboardingSlideData(
      icon: Icons.insights_rounded,
      accentColor: AppColors.darkPlum,
      surfaceColor: AppColors.primaryGreenLight,
      title: 'Clear Spending Insights',
      description: 'See where your money goes by category and search your full history anytime.',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    } else {
      widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _currentPage == _slides.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: widget.onComplete,
                      child: const Text(
                        'Skip',
                        style: TextStyle(
                          color: AppColors.secondaryText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: _slides.length,
                      onPageChanged: (index) {
                        setState(() => _currentPage = index);
                      },
                      itemBuilder: (context, index) {
                        return _SlideView(
                          data: _slides[index],
                          isActive: index == _currentPage,
                        );
                      },
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_slides.length, (index) {
                      final active = index == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        height: 8,
                        width: active ? 26 : 8,
                        decoration: BoxDecoration(
                          color: active
                              ? AppColors.primaryGreen
                              : AppColors.subtleBorder,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _next,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Text(
                          isLast ? 'Get Started' : 'Continue',
                          key: ValueKey(isLast),
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
    );
  }
}

class _OnboardingSlideData {
  const _OnboardingSlideData({
    required this.icon,
    required this.accentColor,
    required this.surfaceColor,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final Color accentColor;
  final Color surfaceColor;
  final String title;
  final String description;
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.data, required this.isActive});

  final _OnboardingSlideData data;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: isActive ? 1 : 0.4,
      duration: const Duration(milliseconds: 300),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedScale(
            scale: isActive ? 1.0 : 0.9,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutBack,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: data.surfaceColor,
                borderRadius: BorderRadius.circular(42),
                border: Border.all(
                  color: data.accentColor.withValues(alpha: 0.2),
                  width: 1.5,
                ),
              ),
              child: Icon(data.icon, size: 72, color: data.accentColor),
            ),
          ),
          const SizedBox(height: 36),
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.primaryText,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            data.description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.secondaryText,
              fontSize: 15,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
