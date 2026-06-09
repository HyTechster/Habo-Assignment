import 'dart:io' show Platform;

import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:habo/auth/auth_service.dart';
import 'package:habo/auth/screens/account_screen.dart';
import 'package:habo/auth/screens/sign_in_screen.dart';
import 'package:habo/constants.dart';
import 'package:habo/debug/dummy_data_seeder.dart';
import 'package:habo/settings/manage_categories_screen.dart';
import 'package:habo/sync/sync_service.dart';
import 'package:habo/extensions.dart';
import 'package:habo/friends/my_profile_screen.dart';
import 'package:habo/generated/l10n.dart';
import 'package:habo/habits/habits_manager.dart';
import 'package:habo/navigation/app_state_manager.dart';
import 'package:habo/services/service_locator.dart';
import 'package:habo/navigation/routes.dart';
import 'package:habo/notifications.dart';
import 'package:habo/settings/color_icon.dart';
import 'package:habo/settings/settings_manager.dart';
import 'package:habo/services/biometric_auth_service.dart';
import 'package:intl/intl.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends StatefulWidget {
  static MaterialPage page() {
    return MaterialPage(
      name: Routes.settingsPath,
      key: ValueKey(Routes.settingsPath),
      child: const SettingsScreen(),
    );
  }

  const SettingsScreen({
    super.key,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  PackageInfo _packageInfo = PackageInfo(
    appName: 'Unknown',
    packageName: 'Unknown',
    version: 'Unknown',
    buildNumber: 'Unknown',
    buildSignature: 'Unknown',
  );

  final BiometricAuthService _biometricService = BiometricAuthService();
  bool _biometricAvailable = false;
  String _authDescription = '';

  Future<void> testTime(BuildContext context) async {
    TimeOfDay? selectedTime;
    TimeOfDay initialTime =
        Provider.of<SettingsManager>(context, listen: false).getDailyNot;
    selectedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (selectedTime != null) {
      Provider.of<SettingsManager>(context, listen: false).setDailyNot =
          selectedTime;
    }
  }

  @override
  void initState() {
    super.initState();
    _initPackageInfo();
    _checkBiometricAvailability();
  }

  Future<void> _initPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _packageInfo = info;
    });
  }

  Future<void> _checkBiometricAvailability() async {
    final available = await _biometricService.hasDeviceAuthentication();
    if (!mounted) return;
    final description =
        await _biometricService.getAuthenticationDescription(context);
    if (!mounted) return;
    setState(() {
      _biometricAvailable = available;
      _authDescription = description;
    });
  }

  void showRestoreDialog(BuildContext context) {
    AwesomeDialog(
      context: context,
      dialogBackgroundColor: Theme.of(context).colorScheme.primaryContainer,
      dialogType: DialogType.warning,
      headerAnimationLoop: false,
      animType: AnimType.bottomSlide,
      title: S.of(context).warning,
      desc: S.of(context).allHabitsWillBeReplaced,
      btnOkText: S.of(context).restore,
      btnCancelText: S.of(context).cancel,
      btnCancelColor: Colors.grey,
      btnOkColor: HaboColors.primary,
      btnCancelOnPress: () {},
      btnOkOnPress: () async {
        await Provider.of<HabitsManager>(context, listen: false).loadBackup();
      },
    ).show();
  }

  void _showClearCloudDataDialog(BuildContext context) {
    AwesomeDialog(
      context: context,
      dialogBackgroundColor: Theme.of(context).colorScheme.primaryContainer,
      dialogType: DialogType.warning,
      headerAnimationLoop: false,
      animType: AnimType.bottomSlide,
      title: 'Clear all data?',
      desc: 'This permanently deletes all your habits, entries and categories '
          'from both the cloud and this device. This cannot be undone.',
      btnCancelText: S.of(context).cancel,
      btnOkText: 'Clear',
      btnCancelColor: Colors.grey,
      btnOkColor: Colors.red,
      btnCancelOnPress: () {},
      btnOkOnPress: () async {
        final sync = context.read<SyncService>();
        final feedback = ServiceLocator.instance.uiFeedbackService;
        try {
          await sync.clearAllData();
          feedback.showSuccess('All data cleared.');
        } catch (e) {
          feedback.showError('Failed to clear data: $e');
        }
      },
    ).show();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppStateManager>(
      builder: (
        context,
        appStateManager,
        child,
      ) {
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            Provider.of<AppStateManager>(context, listen: false)
                .goSettings(false);
          },
          child: LoaderOverlay(
            overlayWidgetBuilder: (_) {
              return const Center(
                child: CircularProgressIndicator(
                  color: HaboColors.primary,
                ),
              );
            },
            child: Scaffold(
              appBar: AppBar(
                title: Text(
                  S.of(context).settings,
                ),
                backgroundColor: Colors.transparent,
                iconTheme: Theme.of(context).iconTheme,
              ),
              body: SingleChildScrollView(
                child: Center(
                  child: Column(
                    children: <Widget>[
                      // Signed-out users haven't backed up their data yet —
                      // surface the prompt to sign in/create an account right
                      // at the top, ahead of every other setting.
                      if (!Provider.of<AuthService>(context).isSignedIn)
                        ListTile(
                          leading: const Icon(Icons.account_circle_outlined),
                          title: const Text('Sign in / Create account'),
                          subtitle: const Text('Tap to back up your data'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SignInScreen(),
                            ),
                          ),
                        ),
                      // Username/profile and the account entry only make
                      // sense once signed in — social features are entirely
                      // opt-in (see E4). Account sits directly below Profile.
                      if (Provider.of<AuthService>(context).isSignedIn) ...[
                        ListTile(
                          leading: const Icon(Icons.badge_outlined),
                          title: const Text('Profile'),
                          subtitle: const Text(
                              'Set the username your friends see'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const MyProfileScreen(),
                            ),
                          ),
                        ),
                        Consumer<AuthService>(
                          builder: (context, auth, _) => ListTile(
                            leading:
                                const Icon(Icons.account_circle_outlined),
                            title: Text(auth.currentUser?.email ?? 'Account'),
                            subtitle: const Text('Cloud sync enabled'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AccountScreen(),
                              ),
                            ),
                          ),
                        ),
                      ],
                      ListTile(
                        title: Text(S.of(context).theme),
                        trailing: DropdownButton<Themes>(
                          items: (Platform.isIOS
                                  ? Themes.values
                                      .where((t) => t != Themes.materialYou)
                                  : Themes.values)
                              .map((Themes value) {
                            return DropdownMenuItem<Themes>(
                              value: value,
                              child: Text(
                                S.of(context).themeSelect(value.name),
                                textAlign: TextAlign.center,
                              ),
                            );
                          }).toList(),
                          value: (Platform.isIOS &&
                                  Provider.of<SettingsManager>(context)
                                          .getThemeString ==
                                      Themes.materialYou)
                              ? Themes.device
                              : Provider.of<SettingsManager>(context)
                                  .getThemeString,
                          onChanged: (value) {
                            Provider.of<SettingsManager>(context, listen: false)
                                .setTheme = value!;
                          },
                        ),
                      ),
                      ListTile(
                        title: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(S.of(context).firstDayOfWeek),
                            const SizedBox(width: 5),
                          ],
                        ),
                        trailing: DropdownButton<dynamic>(
                          alignment: Alignment.center,
                          items: StartingDayOfWeek.values.map((dynamic value) {
                            return DropdownMenuItem<dynamic>(
                              alignment: Alignment.center,
                              value: value,
                              child: Text(
                                DateFormat('E', Intl.getCurrentLocale())
                                    .dateSymbols
                                    .WEEKDAYS[(value.index + 1) % 7]
                                    .substring(0, 2)
                                    .capitalize(),
                                textAlign: TextAlign.center,
                              ),
                            );
                          }).toList(),
                          value: Provider.of<SettingsManager>(context)
                              .getWeekStartEnum,
                          onChanged: (value) {
                            Provider.of<SettingsManager>(context, listen: false)
                                .setWeekStart = value;
                          },
                        ),
                      ),
                      if (platformSupportsNotifications())
                        ListTile(
                          title: Text(S.of(context).notifications),
                          trailing: Switch(
                            value: Provider.of<SettingsManager>(context)
                                .getShowDailyNot,
                            onChanged: (value) async {
                              Provider.of<SettingsManager>(context,
                                      listen: false)
                                  .setShowDailyNot = value;
                            },
                          ),
                        ),
                      if (platformSupportsNotifications())
                        ListTile(
                          enabled: Provider.of<SettingsManager>(context)
                              .getShowDailyNot,
                          title: Text(S.of(context).notificationTime),
                          trailing: InkWell(
                            onTap: () {
                              if (Provider.of<SettingsManager>(context,
                                      listen: false)
                                  .getShowDailyNot) {
                                testTime(context);
                              }
                            },
                            child: Text(
                              MaterialLocalizations.of(context).formatTimeOfDay(
                                  Provider.of<SettingsManager>(context)
                                      .getDailyNot),
                              style: TextStyle(
                                  color: (Provider.of<SettingsManager>(context)
                                          .getShowDailyNot)
                                      ? null
                                      : Theme.of(context).disabledColor),
                            ),
                          ),
                        ),
                      ListTile(
                        title: Text(S.of(context).soundEffects),
                        trailing: Consumer<SettingsManager>(
                          builder: (context, settings, child) {
                            final volume = settings.getSoundVolume;
                            return SizedBox(
                              width: 200,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    volume == 0
                                        ? Icons.volume_off
                                        : Icons.volume_up,
                                    size: 16,
                                    color: volume == 0
                                        ? Theme.of(context).disabledColor
                                        : null,
                                  ),
                                  Expanded(
                                    child: Slider(
                                      value: volume,
                                      min: 0,
                                      max: 5,
                                      divisions: 5,
                                      label: '${volume.round()}',
                                      onChanged: (value) {
                                        Provider.of<SettingsManager>(context,
                                                listen: false)
                                            .setSoundVolume = value;
                                        // Play test sound when adjusting volume
                                        if (value > 0) {
                                          Provider.of<SettingsManager>(context,
                                                  listen: false)
                                              .playClickSound();
                                        }
                                      },
                                    ),
                                  ),
                                  Text(
                                    volume == 0 ? '0' : '${volume.round()}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: volume == 0
                                              ? Theme.of(context).disabledColor
                                              : null,
                                        ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      ListTile(
                        title: Text(S.of(context).biometricLock),
                        enabled: _biometricAvailable,
                        subtitle: Text(S
                            .of(context)
                            .biometricLockDescription(_authDescription)),
                        trailing: Switch(
                          value: Provider.of<SettingsManager>(context)
                              .getBiometricLock,
                          onChanged: (value) async {
                            if (value) {
                              try {
                                // Test authentication before enabling
                                final authenticated =
                                    await _biometricService.authenticate(
                                  context: context,
                                  localizedReason:
                                      S.of(context).authenticateToEnable,
                                );
                                if (!mounted) return;
                                if (authenticated) {
                                  Provider.of<SettingsManager>(context,
                                          listen: false)
                                      .setBiometricLock = true;
                                  if (mounted) {
                                    ServiceLocator.instance.uiFeedbackService
                                        .showSuccess(
                                            S.of(context).biometricLockEnabled);
                                  }
                                } else {
                                  if (mounted) {
                                    ServiceLocator.instance.uiFeedbackService
                                        .showError(S
                                            .of(context)
                                            .authenticationRequired);
                                  }
                                }
                              } catch (e) {
                                if (mounted) {
                                  ServiceLocator.instance.uiFeedbackService
                                      .showError(
                                          '${S.of(context).authenticationError}: $e');
                                }
                              }
                            } else {
                              Provider.of<SettingsManager>(context,
                                      listen: false)
                                  .setBiometricLock = false;
                              if (mounted) {
                                ServiceLocator.instance.uiFeedbackService
                                    .showSuccess(
                                        S.of(context).biometricLockDisabled);
                              }
                            }
                          },
                        ),
                      ),
                      ListTile(
                        title: Text(S.of(context).oneTapCheck),
                        subtitle:
                            Text(S.of(context).tapCheckLongPressMenu),
                        trailing: Switch(
                          value: Provider.of<SettingsManager>(context)
                              .getOneTapCheck,
                          onChanged: (value) async {
                            Provider.of<SettingsManager>(context, listen: false)
                                .setOneTapCheck = value;
                          },
                        ),
                      ),
                      ListTile(
                        title: Text(S.of(context).showMonthName),
                        trailing: Switch(
                          value: Provider.of<SettingsManager>(context)
                              .getShowMonthName,
                          onChanged: (value) {
                            Provider.of<SettingsManager>(context, listen: false)
                                .setShowMonthName = value;
                          },
                        ),
                      ),
                      ListTile(
                        title: Text(S.of(context).showCategories),
                        trailing: Switch(
                          value: Provider.of<SettingsManager>(context)
                              .getShowCategories,
                          onChanged: (value) {
                            Provider.of<SettingsManager>(context, listen: false)
                                .setShowCategories = value;
                          },
                        ),
                      ),
                      ListTile(
                        title: Text(S.of(context).setColors),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ColorIcon(
                              color: Provider.of<SettingsManager>(context,
                                      listen: false)
                                  .checkColor,
                              icon: Icons.check,
                              defaultColor: HaboColors.primary,
                              onPicked: (value) {
                                Provider.of<SettingsManager>(context,
                                        listen: false)
                                    .checkColor = value;
                              },
                            ),
                            ColorIcon(
                              color: Provider.of<SettingsManager>(context,
                                      listen: false)
                                  .progressColor,
                              icon: Icons.trending_up,
                              defaultColor: HaboColors.progress,
                              onPicked: (value) {
                                Provider.of<SettingsManager>(context,
                                        listen: false)
                                    .progressColor = value;
                              },
                            ),
                            ColorIcon(
                              color: Provider.of<SettingsManager>(context,
                                      listen: false)
                                  .failColor,
                              icon: Icons.close,
                              defaultColor: HaboColors.red,
                              onPicked: (value) {
                                Provider.of<SettingsManager>(context,
                                        listen: false)
                                    .failColor = value;
                              },
                            ),
                            ColorIcon(
                              color: Provider.of<SettingsManager>(context,
                                      listen: false)
                                  .skipColor,
                              icon: Icons.last_page,
                              defaultColor: HaboColors.skip,
                              onPicked: (value) {
                                Provider.of<SettingsManager>(context,
                                        listen: false)
                                    .skipColor = value;
                              },
                            ),
                          ],
                        ),
                      ),
                      ListTile(
                        leading: const Icon(Icons.category_outlined),
                        title: const Text('Manage categories'),
                        subtitle: const Text('Remove categories and see their habits'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ManageCategoriesScreen(),
                          ),
                        ),
                      ),
                      ListTile(
                        title: Text(S.of(context).backup),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            MaterialButton(
                              onPressed: () async {
                                await ServiceLocator.instance.backupService
                                    .createDatabaseBackup();
                              },
                              child: Text(
                                S.of(context).create,
                                style: const TextStyle(
                                    decoration: TextDecoration.underline),
                              ),
                            ),
                            const VerticalDivider(
                              thickness: 1,
                              indent: 20,
                              endIndent: 20,
                              color: Colors.grey,
                            ),
                            MaterialButton(
                              onPressed: () async {
                                showRestoreDialog(context);
                              },
                              child: Text(
                                S.of(context).restore,
                                style: const TextStyle(
                                    decoration: TextDecoration.underline),
                              ),
                            ),
                          ],
                        ),
                      ),
                      ListTile(
                        title: Text(S.of(context).onboarding),
                        onTap: () {
                          Provider.of<AppStateManager>(context, listen: false)
                              .goOnboarding(true);
                        },
                      ),
                      ListTile(
                        title: Text(S.of(context).whatsNewTitle),
                        onTap: () {
                          Provider.of<AppStateManager>(context, listen: false)
                              .goWhatsNew(true);
                        },
                      ),
                      ListTile(
                        title: Text(S.of(context).about),
                        onTap: () {
                          showAboutDialog(
                            context: context,
                            applicationIcon: Image.asset(
                              'assets/images/icon.png',
                              width: 55,
                              height: 55,
                            ),
                            applicationName: 'Habo',
                            applicationVersion: _packageInfo.version,
                            applicationLegalese: '©2025 Habo',
                            children: <Widget>[
                              Padding(
                                padding: const EdgeInsets.only(top: 15),
                                child: RichText(
                                  text: TextSpan(
                                    style:
                                        Theme.of(context).textTheme.bodyMedium,
                                    children: [
                                      TextSpan(
                                        style: const TextStyle(
                                            color: Colors.blue,
                                            decoration:
                                                TextDecoration.underline),
                                        text: S.of(context).termsAndConditions,
                                        recognizer: TapGestureRecognizer()
                                          ..onTap = () async {
                                            final Uri url = Uri.parse(
                                                'https://habo.space/terms.html#terms');
                                            if (await canLaunchUrl(url)) {
                                              await launchUrl(
                                                url,
                                                mode: LaunchMode
                                                    .externalApplication,
                                              );
                                            }
                                          },
                                      ),
                                      const TextSpan(text: '\n'),
                                      TextSpan(
                                        style: const TextStyle(
                                            color: Colors.blue,
                                            decoration:
                                                TextDecoration.underline),
                                        text: S.of(context).privacyPolicy,
                                        recognizer: TapGestureRecognizer()
                                          ..onTap = () async {
                                            final Uri url = Uri.parse(
                                                'https://habo.space/terms.html#privacy');
                                            if (await canLaunchUrl(url)) {
                                              await launchUrl(
                                                url,
                                                mode: LaunchMode
                                                    .externalApplication,
                                              );
                                            }
                                          },
                                      ),
                                      const TextSpan(text: '\n'),
                                      TextSpan(
                                        style: const TextStyle(
                                            color: Colors.blue,
                                            decoration:
                                                TextDecoration.underline),
                                        text: S.of(context).disclaimer,
                                        recognizer: TapGestureRecognizer()
                                          ..onTap = () async {
                                            final Uri url = Uri.parse(
                                                'https://habo.space/terms.html#disclaimer');
                                            if (await canLaunchUrl(url)) {
                                              await launchUrl(
                                                url,
                                                mode: LaunchMode
                                                    .externalApplication,
                                              );
                                            }
                                          },
                                      ),
                                      const TextSpan(text: '\n'),
                                      TextSpan(
                                        style: const TextStyle(
                                            color: Colors.blue,
                                            decoration:
                                                TextDecoration.underline),
                                        text: S.of(context).sourceCode,
                                        recognizer: TapGestureRecognizer()
                                          ..onTap = () async {
                                            final Uri url = Uri.parse(
                                                'https://github.com/xpavle00/Habo');
                                            if (await canLaunchUrl(url)) {
                                              await launchUrl(
                                                url,
                                                mode: LaunchMode
                                                    .externalApplication,
                                              );
                                            }
                                          },
                                      ),
                                      const TextSpan(text: '\n\n'),
                                      TextSpan(
                                        text: S.of(context).ifYouWantToSupport,
                                      ),
                                      const TextSpan(text: '\n'),
                                      TextSpan(
                                        style: const TextStyle(
                                            color: Colors.blue,
                                            decoration:
                                                TextDecoration.underline),
                                        text: S.of(context).buyMeACoffee,
                                        recognizer: TapGestureRecognizer()
                                          ..onTap = () async {
                                            final Uri url = Uri.parse(
                                                'https://www.buymeacoffee.com/peterpavlenko');
                                            if (await canLaunchUrl(url)) {
                                              await launchUrl(
                                                url,
                                                mode: LaunchMode
                                                    .externalApplication,
                                              );
                                            }
                                          },
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            ],
                          );
                        },
                      ),
                      // Debug-only tile — hidden in release builds.
                      if (kDebugMode) ...[
                        const Divider(),
                        ListTile(
                          leading: const Icon(Icons.science_outlined,
                              color: Colors.orange),
                          title: const Text(
                            'Seed test data (debug)',
                            style: TextStyle(color: Colors.orange),
                          ),
                          subtitle: const Text(
                            'Creates 10 habits (checkable & progressive) + fills the year with events',
                          ),
                          onTap: () async {
                            final manager = Provider.of<HabitsManager>(
                                context,
                                listen: false);
                            await DummyDataSeeder.seed(manager);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Test data seeded!'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                        ),
                      ],
                      if (Provider.of<AuthService>(context).isSignedIn) ...[
                        const Divider(),
                        ListTile(
                          leading: const Icon(
                              Icons.cloud_off_outlined,
                              color: Colors.red),
                          title: const Text(
                            'Clear all data',
                            style: TextStyle(color: Colors.red),
                          ),
                          subtitle: const Text(
                              'Permanently delete all habits and entries'),
                          onTap: () => _showClearCloudDataDialog(context),
                        ),
                      ],
                      SizedBox(height: 56),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
