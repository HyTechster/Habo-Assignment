import 'package:flutter/material.dart';
import 'package:habo/constants.dart';
import 'package:habo/friends/friends_manager.dart';
import 'package:provider/provider.dart';

/// "Send Nudge" action shown next to a friend's shared habit. Sending is
/// delegated to [FriendsManager.sendNudge], which enforces the
/// once-per-friend-per-habit-per-day rate limit server-side; this widget
/// only surfaces the resulting feedback (sent / already nudged / error).
class NudgeButton extends StatefulWidget {
  const NudgeButton({
    super.key,
    required this.friendId,
    required this.habitId,
    required this.habitTitle,
  });

  final String friendId;
  final String habitId;
  final String habitTitle;

  @override
  State<NudgeButton> createState() => _NudgeButtonState();
}

class _NudgeButtonState extends State<NudgeButton> {
  bool _sending = false;

  Future<void> _send() async {
    setState(() => _sending = true);
    final manager = Provider.of<FriendsManager>(context, listen: false);
    await manager.sendNudge(
      receiverId: widget.friendId,
      habitId: widget.habitId,
      habitTitle: widget.habitTitle,
    );
    if (!mounted) return;
    setState(() => _sending = false);

    final feedback = manager.nudgeFeedback;
    if (feedback != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(feedback)),
      );
      manager.clearNudgeFeedback();
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: _sending ? null : _send,
      icon: _sending
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.notifications_active_outlined, size: 18),
      label: const Text('Send Nudge'),
      style: TextButton.styleFrom(foregroundColor: HaboColors.primary),
    );
  }
}
