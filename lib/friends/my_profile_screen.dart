import 'package:flutter/material.dart';
import 'package:habo/constants.dart';
import 'package:habo/friends/friends_manager.dart';
import 'package:habo/services/service_locator.dart';
import 'package:provider/provider.dart';

/// Lets the signed-in user view and change the username their friends see
/// (e.g. when searching for them or sending a friend request).
class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({super.key});

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  final _controller = TextEditingController();
  bool _editing = false;
  bool _saving = false;
  bool _savingVisibility = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final manager = context.read<FriendsManager>();
      await manager.loadMyProfile();
      if (mounted) _controller.text = manager.myProfile?.username ?? '';
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save(FriendsManager manager) async {
    final newUsername = _controller.text.trim();
    final current = manager.myProfile?.username;
    if (newUsername.isEmpty || newUsername == current) {
      setState(() => _editing = false);
      return;
    }

    setState(() => _saving = true);
    final success = await manager.updateUsername(newUsername);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _editing = !success;
    });
    if (success) {
      ServiceLocator.instance.uiFeedbackService.showSuccess('Username updated');
    } else {
      ServiceLocator.instance.uiFeedbackService.showError(
        manager.usernameError ?? 'Could not update username. Please try again.',
      );
    }
  }

  void _cancel(FriendsManager manager) {
    _controller.text = manager.myProfile?.username ?? '';
    setState(() => _editing = false);
  }

  Future<void> _setVisibilityMode(FriendsManager manager, bool shareAll) async {
    if (manager.shareAllHabits == shareAll || _savingVisibility) return;
    setState(() => _savingVisibility = true);
    final success = await manager.setShareAllHabits(shareAll);
    if (!mounted) return;
    setState(() => _savingVisibility = false);
    if (!success) {
      ServiceLocator.instance.uiFeedbackService
          .showError('Could not update visibility. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FriendsManager>(
      builder: (context, manager, _) {
        final profile = manager.myProfile;
        // Keep the field in sync with freshly-loaded data while not editing.
        if (!_editing && profile != null && _controller.text != profile.username) {
          _controller.text = profile.username;
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Profile'),
            backgroundColor: Colors.transparent,
          ),
          body: SafeArea(
            child: manager.myProfileStatus == LoadStatus.loading && profile == null
                ? const Center(
                    child: CircularProgressIndicator(color: HaboColors.primary),
                  )
                : ListView(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    children: [
                      const Center(
                        child: Icon(
                          Icons.account_circle,
                          size: 72,
                          color: HaboColors.primary,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _editing
                            ? TextField(
                                controller: _controller,
                                autofocus: true,
                                enabled: !_saving,
                                maxLength: 32,
                                decoration: const InputDecoration(
                                  labelText: 'Username',
                                  helperText:
                                      "This is the name friends use to find and recognize you.",
                                ),
                                onSubmitted: (_) => _save(manager),
                              )
                            : ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Username'),
                                subtitle: Text(profile?.username ?? '—'),
                                trailing: IconButton(
                                  tooltip: 'Edit username',
                                  icon: const Icon(Icons.edit_outlined),
                                  onPressed: () => setState(() => _editing = true),
                                ),
                              ),
                      ),
                      if (_editing)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: _saving ? null : () => _cancel(manager),
                                child: const Text('Cancel'),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: _saving ? null : () => _save(manager),
                                child: _saving
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Text('Save'),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 24),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'Habit visibility to friends',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 4, 16, 0),
                        child: Text(
                          'Choose which of your habits are summarized on your '
                          'profile for friends to see.',
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                      ),
                      RadioListTile<bool>(
                        title: const Text('All habits'),
                        subtitle: const Text(
                          'Every habit you have is summarized for friends.',
                        ),
                        value: true,
                        groupValue: profile?.shareAllHabits,
                        onChanged: _savingVisibility || profile == null
                            ? null
                            : (value) => _setVisibilityMode(manager, value!),
                      ),
                      RadioListTile<bool>(
                        title: const Text('Chosen habits'),
                        subtitle: const Text(
                          'Pick individual habits to share using the eye icon '
                          'in your habit list. Habits are shown by default.',
                        ),
                        value: false,
                        groupValue: profile?.shareAllHabits,
                        onChanged: _savingVisibility || profile == null
                            ? null
                            : (value) => _setVisibilityMode(manager, value!),
                      ),
                      if (_savingVisibility)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}
