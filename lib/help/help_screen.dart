import 'package:flutter/material.dart';
import 'package:habo/constants.dart';
import 'package:habo/generated/l10n.dart';
import 'package:habo/navigation/app_state_manager.dart';
import 'package:habo/navigation/routes.dart';
import 'package:provider/provider.dart';

class HelpScreen extends StatelessWidget {
  static MaterialPage page() {
    return MaterialPage(
      name: Routes.helpPath,
      key: ValueKey(Routes.helpPath),
      child: const HelpScreen(),
    );
  }

  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Provider.of<AppStateManager>(context, listen: false).goHelp(false);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Help'),
          backgroundColor: Colors.transparent,
          iconTheme: Theme.of(context).iconTheme,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HelpSection(
                icon: Icons.add_circle_outline_rounded,
                title: 'Creating Habits',
                children: [
                  const _HelpParagraph(
                    'Tap the + button to create a new habit. Every habit is '
                    'structured around three core elements:',
                  ),
                  const SizedBox(height: 10),
                  _HabitLoopRow(context),
                  const SizedBox(height: 10),
                  const _HelpParagraph(
                    'You can also set a title, optional cue, routine, reward, '
                    'and sanction. For numeric habits, set a daily target and '
                    'partial-credit value.',
                  ),
                ],
              ),
              _HelpSection(
                icon: Icons.calendar_today_rounded,
                title: 'Logging Days',
                children: [
                  const _HelpParagraph(
                    'Tap a day cell to open the action menu and log your '
                    'progress for that day:',
                  ),
                  const SizedBox(height: 12),
                  _DayTypeLegend(context),
                  const SizedBox(height: 10),
                  const _HelpParagraph(
                    'Enable "One-tap check" in Settings to log a check with a '
                    'single tap, and long-press to open the full menu.',
                  ),
                ],
              ),
              _HelpSection(
                icon: Icons.bar_chart_rounded,
                title: 'Statistics',
                children: const [
                  _HelpParagraph(
                    'Tap the bar chart icon in the top bar to open the '
                    'Statistics screen. You\'ll find your current streak, '
                    'overall success rate, and a monthly calendar view for '
                    'each habit.',
                  ),
                ],
              ),
              _HelpSection(
                icon: Icons.tune_rounded,
                title: 'Features',
                children: const [
                  _FeatureRow(
                    icon: Icons.palette_outlined,
                    label:
                        'Themes — Choose Light, Dark, OLED, or Material You from Settings.',
                  ),
                  _FeatureRow(
                    icon: Icons.fingerprint_rounded,
                    label:
                        'Biometric Lock — Protect your habits with fingerprint or face unlock.',
                  ),
                  _FeatureRow(
                    icon: Icons.notifications_outlined,
                    label:
                        'Notifications — Set a daily reminder time to log your habits.',
                  ),
                  _FeatureRow(
                    icon: Icons.save_alt_rounded,
                    label:
                        'Backup & Restore — Export or import your full habit database.',
                  ),
                  _FeatureRow(
                    icon: Icons.label_outline_rounded,
                    label:
                        'Categories — Assign categories to group and filter related habits.',
                  ),
                ],
              ),
              const _HelpSection(
                icon: Icons.lightbulb_outline_rounded,
                title: 'Tips',
                children: [
                  _TipRow(
                    'Two-day rule: missing one day is forgivable — the streak '
                    'stays alive if you didn\'t miss two days in a row.',
                  ),
                  SizedBox(height: 6),
                  _TipRow(
                    'Streaks reset on a Fail, but a Skip has no effect on your '
                    'streak counter.',
                  ),
                  SizedBox(height: 6),
                  _TipRow(
                    'Long-press any habit title to reorder habits by dragging.',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Section card ─────────────────────────────────────────────────────────────

class _HelpSection extends StatelessWidget {
  const _HelpSection({
    required this.icon,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
        border: const Border(
          left: BorderSide(color: HaboColors.primary, width: 4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: HaboColors.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1, thickness: 1),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

// ── Paragraph ─────────────────────────────────────────────────────────────────

class _HelpParagraph extends StatelessWidget {
  const _HelpParagraph(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        height: 1.55,
        color: Theme.of(context).colorScheme.onPrimaryContainer,
      ),
    );
  }
}

// ── Habit loop row ────────────────────────────────────────────────────────────

class _HabitLoopRow extends StatelessWidget {
  const _HabitLoopRow(this.context);
  final BuildContext context;

  @override
  Widget build(BuildContext ctx) {
    return Row(
      children: [
        _chip(ctx, S.of(context).cueNumbered),
        _arrow(),
        _chip(ctx, S.of(context).routineNumbered),
        _arrow(),
        _chip(ctx, S.of(context).rewardNumbered),
      ],
    );
  }

  Widget _chip(BuildContext ctx, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: HaboColors.primary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: HaboColors.primary.withValues(alpha: 0.25)),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: HaboColors.primary,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _arrow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Icon(
        Icons.arrow_forward_ios_rounded,
        size: 12,
        color: HaboColors.primary.withValues(alpha: 0.5),
      ),
    );
  }
}

// ── Day type legend ───────────────────────────────────────────────────────────

class _DayTypeLegend extends StatelessWidget {
  const _DayTypeLegend(this.context);
  final BuildContext context;

  @override
  Widget build(BuildContext ctx) {
    return Column(
      children: [
        _row(ctx, Icons.check_circle_rounded, S.of(context).successful, HaboColors.primary),
        const SizedBox(height: 7),
        _row(ctx, Icons.add_circle_rounded, S.of(context).numericHabit, HaboColors.progress),
        const SizedBox(height: 7),
        _row(ctx, Icons.cancel_rounded, S.of(context).notSoSuccessful, HaboColors.red),
        const SizedBox(height: 7),
        _row(ctx, Icons.skip_next_rounded, S.of(context).skipDoesNotAffectStreaks, HaboColors.skip),
        const SizedBox(height: 7),
        _row(ctx, Icons.chat_bubble_outline_rounded, S.of(context).note, HaboColors.orange),
      ],
    );
  }

  Widget _row(BuildContext ctx, IconData icon, String label, Color color) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              height: 1.3,
              color: Theme.of(ctx).colorScheme.onPrimaryContainer,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Feature row ───────────────────────────────────────────────────────────────

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: HaboColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tip row ───────────────────────────────────────────────────────────────────

class _TipRow extends StatelessWidget {
  const _TipRow(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 5),
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: HaboColors.primary,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
        ),
      ],
    );
  }
}
