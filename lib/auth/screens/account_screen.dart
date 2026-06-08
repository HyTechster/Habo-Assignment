import 'package:flutter/material.dart';
import 'package:habo/auth/auth_service.dart';
import 'package:habo/constants.dart';
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

  Future<void> _signOut(BuildContext context) async {
    // Push local data to cloud BEFORE signing out so nothing is lost.
    await context.read<SyncService>().signOut();
    if (context.mounted) Navigator.of(context).pop();
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
