import 'package:flutter/material.dart';
import 'package:habo/constants.dart';
import 'package:habo/friends/friends_manager.dart';
import 'package:provider/provider.dart';

/// Eye icon shown beside a habit row when the user is in "choose
/// individually" visibility mode (FriendsManager.shareAllHabits == false).
/// Tapping it toggles whether *that* habit is summarized for friends —
/// the same action as the switch in EditHabitScreen, just reachable directly
/// from the habit list. Hidden entirely for habits that haven't synced to
/// the cloud yet, since sharing isn't possible until they have a cloud id.
class HabitVisibilityEyeButton extends StatefulWidget {
  const HabitVisibilityEyeButton({super.key, required this.localHabitId});

  final int localHabitId;

  @override
  State<HabitVisibilityEyeButton> createState() => _HabitVisibilityEyeButtonState();
}

class _HabitVisibilityEyeButtonState extends State<HabitVisibilityEyeButton> {
  bool _loading = true;
  bool _isShared = false;
  String? _cloudHabitId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final manager = context.read<FriendsManager>();
    try {
      final cloudId = await manager.cloudHabitIdForLocalId(widget.localHabitId);
      if (!mounted) return;
      if (cloudId != null) {
        final shared = await manager.isHabitShared(cloudId);
        if (!mounted) return;
        setState(() {
          _cloudHabitId = cloudId;
          _isShared = shared;
          _loading = false;
        });
        return;
      }
    } catch (_) {
      // Offline or not yet synced — leave the icon hidden; this is a
      // best-effort enhancement, not core functionality.
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _toggle() async {
    final cloudId = _cloudHabitId;
    if (cloudId == null) return;
    final manager = context.read<FriendsManager>();
    final next = !_isShared;
    setState(() {
      _isShared = next;
      _loading = true;
    });
    try {
      await manager.setHabitShared(cloudId, next);
    } catch (_) {
      if (mounted) setState(() => _isShared = !next);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cloudHabitId == null) {
      // Either still resolving, or this habit has no cloud counterpart yet —
      // either way there's nothing actionable to show.
      return const SizedBox.shrink();
    }
    return IconButton(
      padding: const EdgeInsets.fromLTRB(3, 0, 0, 0),
      constraints: const BoxConstraints(minHeight: 36, minWidth: 36, maxHeight: 48),
      icon: _loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(_isShared ? Icons.visibility_outlined : Icons.visibility_off_outlined),
      color: _isShared ? HaboColors.primary : Colors.grey,
      tooltip: _isShared
          ? 'Visible to friends — tap to hide'
          : 'Hidden from friends — tap to show',
      onPressed: _loading ? null : _toggle,
    );
  }
}
