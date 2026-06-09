import 'package:flutter/material.dart';
import 'package:habo/auth/auth_service.dart';
import 'package:habo/constants.dart';
import 'package:habo/services/service_locator.dart';
import 'package:habo/sync/sync_service.dart';
import 'package:provider/provider.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  String _formatTime(DateTime? dt) {
    if (dt == null) return 'Not yet synced';
    final local = dt.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}  $h:$m';
  }

  // Pops back to Settings immediately — a single synchronous pop, with
  // nothing async gating it — then runs the push-to-cloud-and-sign-out
  // chain in the background. Earlier versions awaited that chain before
  // popping, which raced against the reactive auth-state rebuilds it
  // triggers (AuthService.notifyListeners fires mid-flight) and left users
  // bouncing between Account and Settings or stuck on a permanent spinner.
  // The snackbar gives the "syncing to the cloud" confirmation the pop
  // itself no longer waits on.
  void _signOut(BuildContext context) {
    final sync = context.read<SyncService>();
    final feedback = ServiceLocator.instance.uiFeedbackService;

    feedback.showSuccess('Syncing your data to the cloud and signing out…');
    Navigator.of(context).pop();

    sync.signOut().timeout(const Duration(seconds: 60)).then((_) {
      feedback.showSuccess('Signed out');
    }).catchError((e) {
      feedback.showError('Sign out failed: $e');
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final sync = context.watch<SyncService>();
    final email = auth.currentUser?.email ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Account'),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: ListView(
          children: [
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.account_circle_outlined, size: 40),
              title: Text(email),
              subtitle: const Text('Signed in'),
            ),
            const Divider(),
            ListTile(
              leading: sync.isSyncing
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: HaboColors.primary,
                      ),
                    )
                  : const Icon(Icons.cloud_done_outlined,
                      color: HaboColors.primary),
              title: Text(sync.isSyncing ? 'Syncing…' : 'Cloud sync active'),
              subtitle: Text(
                sync.isSyncing
                    ? 'Uploading your habits'
                    : 'Last synced: ${_formatTime(sync.lastSyncTime)}',
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Sign out'),
              onTap: () => _signOut(context),
            ),
          ],
        ),
      ),
    );
  }
}
