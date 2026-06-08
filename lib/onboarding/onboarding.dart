import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:habo/constants.dart';
import 'package:habo/generated/l10n.dart';
import 'package:habo/settings/settings_manager.dart';
import 'package:provider/provider.dart';

class Onboarding extends StatefulWidget {
  const Onboarding({super.key});

  @override
  State<Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends State<Onboarding> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  static const int _totalPages = 3;

  void _onDone() {
    final settings = Provider.of<SettingsManager>(context, listen: false);
    if (settings.getSeenOnboarding) {
      Navigator.pop(context);
    } else {
      settings.setSeenOnboarding = true;
    }
  }

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _onDone();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            onPageChanged: (index) => setState(() => _currentPage = index),
            children: [
              _buildPage1(context),
              _buildPage2(context),
              _buildPage3(context),
            ],
          ),
          _buildBottomNav(context),
        ],
      ),
    );
  }

  // ── Page 1: Define Your Habits (green gradient) ──────────────────────────

  Widget _buildPage1(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF14D640), Color(0xFF047A1F)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _stepBadge(
              '01 / 03',
              Colors.white.withValues(alpha: 0.18),
              Colors.white.withValues(alpha: 0.9),
            ),
            Expanded(
              flex: 5,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  child: SvgPicture.asset(
                    'assets/images/onboard/1.svg',
                    semanticsLabel: 'Habits illustration',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 6,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 0, 28, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      S.of(context).defineYourHabits,
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.1,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      S.of(context).defineYourHabitsDescription,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withValues(alpha: 0.80),
                        height: 1.55,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        _loopChip(S.of(context).cueNumbered),
                        _loopArrow(),
                        _loopChip(S.of(context).routineNumbered),
                        _loopArrow(),
                        _loopChip(S.of(context).rewardNumbered),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 90),
          ],
        ),
      ),
    );
  }

  Widget _loopChip(String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.28),
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _loopArrow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Icon(
        Icons.arrow_forward_ios_rounded,
        color: Colors.white.withValues(alpha: 0.50),
        size: 13,
      ),
    );
  }

  // ── Page 2: Log Your Days (dark navy) ────────────────────────────────────

  Widget _buildPage2(BuildContext context) {
    return Container(
      color: const Color(0xFF1C1C2E),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _stepBadge(
              '02 / 03',
              HaboColors.primary.withValues(alpha: 0.18),
              HaboColors.primary,
            ),
            Expanded(
              flex: 4,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 56),
                  child: SvgPicture.asset(
                    'assets/images/onboard/2.svg',
                    semanticsLabel: S.of(context).emptyList,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 7,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 0, 28, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      S.of(context).logYourDays,
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.1,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _dayTypeRow(
                      Icons.check_circle_rounded,
                      S.of(context).successful,
                      HaboColors.primary,
                    ),
                    const SizedBox(height: 10),
                    _dayTypeRow(
                      Icons.add_circle_rounded,
                      S.of(context).numericHabit,
                      HaboColors.progress,
                    ),
                    const SizedBox(height: 10),
                    _dayTypeRow(
                      Icons.cancel_rounded,
                      S.of(context).notSoSuccessful,
                      HaboColors.red,
                    ),
                    const SizedBox(height: 10),
                    _dayTypeRow(
                      Icons.skip_next_rounded,
                      S.of(context).skipDoesNotAffectStreaks,
                      HaboColors.skip,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 90),
          ],
        ),
      ),
    );
  }

  Widget _dayTypeRow(IconData icon, String label, Color color) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }

  // ── Page 3: Observe Your Progress (clean light) ──────────────────────────

  Widget _buildPage3(BuildContext context) {
    return Container(
      color: const Color(0xFFFAFAFA),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _stepBadge(
              '03 / 03',
              const Color(0x11000000),
              const Color(0x77000000),
            ),
            Expanded(
              flex: 5,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  child: SvgPicture.asset(
                    'assets/images/onboard/3.svg',
                    semanticsLabel: S.of(context).emptyList,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 6,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 0, 28, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      S.of(context).observeYourProgress,
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111111),
                        height: 1.1,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      S.of(context).trackYourProgress,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Color(0xFF555555),
                        height: 1.55,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        _statCard(
                          Icons.local_fire_department_rounded,
                          'Streak',
                          HaboColors.orange,
                        ),
                        const SizedBox(width: 12),
                        _statCard(
                          Icons.check_circle_rounded,
                          'Success',
                          HaboColors.primary,
                        ),
                        const SizedBox(width: 12),
                        _statCard(
                          Icons.bar_chart_rounded,
                          'Statistics',
                          HaboColors.progress,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 90),
          ],
        ),
      ),
    );
  }

  Widget _statCard(IconData icon, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF555555),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Shared widgets ────────────────────────────────────────────────────────

  Widget _stepBadge(String text, Color bgColor, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, right: 24),
      child: Align(
        alignment: Alignment.topRight,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w600,
              fontSize: 12,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    final bool isLastPage = _currentPage == _totalPages - 1;
    final bool isColoredBg = _currentPage <= 1; // green or dark page
    final Color onBg =
        isColoredBg ? Colors.white : const Color(0xFF111111);

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 16,
          bottom: MediaQuery.of(context).padding.bottom + 16,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Skip / placeholder
            SizedBox(
              width: 72,
              child: isLastPage
                  ? null
                  : TextButton(
                      onPressed: _onDone,
                      style: TextButton.styleFrom(
                        foregroundColor: onBg.withValues(alpha: 0.55),
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 40),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        S.of(context).skip,
                        style: TextStyle(
                          color: onBg.withValues(alpha: 0.55),
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
            ),

            // Animated dot indicators
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(_totalPages, (i) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: _currentPage == i ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: _currentPage == i
                        ? HaboColors.primary
                        : onBg.withValues(alpha: 0.22),
                  ),
                );
              }),
            ),

            // Next / Done pill button
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              width: isLastPage ? 110 : 52,
              height: 52,
              decoration: BoxDecoration(
                color: HaboColors.primary,
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: HaboColors.primary.withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(26),
                  onTap: _nextPage,
                  child: Center(
                    child: isLastPage
                        ? Text(
                            S.of(context).done,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          )
                        : const Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
