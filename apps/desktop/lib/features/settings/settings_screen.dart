import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/plan_gate.dart';
import '../../core/theme/colors.dart';
import '../../data/providers/providers.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/preferences_service.dart';
import '../../shared/widgets/psitta_logo.dart';
import '../../widgets/user_avatar.dart';

String _autoDeleteLabel(int? days) =>
    days == null ? 'Never' : 'After $days days';

String _cacheSizeLabel(int mb) => mb >= 1024 ? '${mb ~/ 1024} GB' : '$mb MB';

/// Backend plan id → user-facing label. Falls through to the raw id
/// for any plan not yet shipped (forward-compat).
const Map<String, String> _kPlanDisplayNames = {
  'free': 'Free',
  'reading_nook_pro': 'Reading Nook Pro',
  'creative_nook_pro': 'Creative Nook Pro',
};

/// Settings Screen — user preferences and app configuration.
///
/// Desktop layout: single-column settings list with sections.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() {
      _appVersion = '${info.version}+${info.buildNumber}';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Settings',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final settings = _buildSettingsList(context);
                if (constraints.maxWidth < 900) return settings;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(width: 600, child: settings),
                    const Expanded(child: _SettingsBrandingPanel()),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsList(BuildContext context) {
    final theme = Theme.of(context);
    final selectedTheme = ref.watch(selectedThemeNameProvider);
    final swhMode = ref.watch(selectedSwhModeProvider);
    final isPro = ref.watch(isProUserProvider);
    final maxSpeed = isPro ? kProMaxSpeed : kFreeMaxSpeed;
    final availableSpeeds =
        SpeedPreferenceNotifier.speeds.where((s) => s <= maxSpeed).toList();
    final currentSpeed = ref.watch(selectedSpeedProvider);
    final displaySpeed = availableSpeeds.contains(currentSpeed)
        ? currentSpeed
        : availableSpeeds.last;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 600),
      child: ListView(
        children: [
          const _SectionHeader(title: 'Account'),
          const _AccountTile(),
          const _SubscriptionTile(),
          const _ManageSubscriptionTile(),
          const _ChangePlanTile(),
          const _StaySignedInTile(),
          _LogoutTile(),
          const SizedBox(height: 16),
          const _SectionHeader(title: 'Appearance'),
          ListTile(
            title: const Text('Theme'),
            subtitle: Text(selectedTheme),
            trailing: SizedBox(
              width: 260,
              child: DropdownButtonFormField<String>(
                value: selectedTheme,
                items: ThemeNames.all
                    .map(
                      (t) => DropdownMenuItem(
                        value: t,
                        child: Text(t),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  ref.read(selectedThemeNameProvider.notifier).select(value);
                },
                decoration: const InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const _SectionHeader(title: 'Playback'),
          ListTile(
            title: const Text('Default Voice'),
            subtitle: Text(
              ref.watch(voicesProvider).whenOrNull(
                    data: (voices) {
                      final id = ref.watch(selectedVoiceIdProvider);
                      for (final v in voices) {
                        if (v.id == id) return v.displayName;
                      }
                      return null;
                    },
                  ) ??
                  'Select a voice',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/voices'),
          ),
          ListTile(
            title: const Text('Playback Speed'),
            subtitle: isPro
                ? null
                : const Text(
                    'Free plan limited to 2.0x. '
                    'Upgrade for up to 4.0x.',
                    style: TextStyle(fontSize: 11),
                  ),
            trailing: DropdownButton<double>(
              value: displaySpeed,
              underline: const SizedBox(),
              items: availableSpeeds
                  .map(
                    (s) => DropdownMenuItem<double>(
                      value: s,
                      child: Text('${s}x'),
                    ),
                  )
                  .toList(),
              onChanged: (val) {
                if (val == null) return;
                ref.read(selectedSpeedProvider.notifier).select(val);
              },
            ),
          ),
          const SizedBox(height: 16),
          const _SectionHeader(title: 'Sync Word Highlight'),
          if (!isPro)
            Padding(
              padding:
                  const EdgeInsets.only(left: 16, right: 16, bottom: 4, top: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Available with Reading Nook Pro',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.go('/plan'),
                    child: const Text('Upgrade'),
                  ),
                ],
              ),
            ),
          RadioListTile<String>(
            title: const Text('Read with S.W.H'),
            subtitle: const Text(
              'Uses ElevenLabs TTS credits for word-level sync',
              style: TextStyle(fontSize: 11),
            ),
            value: SwhMode.always,
            groupValue: swhMode,
            onChanged: isPro
                ? (v) => ref.read(selectedSwhModeProvider.notifier).select(v!)
                : null,
          ),
          RadioListTile<String>(
            title: const Text('Read without S.W.H'),
            value: SwhMode.never,
            groupValue: swhMode,
            onChanged: isPro
                ? (v) => ref.read(selectedSwhModeProvider.notifier).select(v!)
                : null,
          ),
          const SizedBox(height: 16),
          const _SectionHeader(title: 'Storage'),
          ListTile(
            title: const Text('Auto-Delete Documents'),
            trailing: DropdownButton<int?>(
              value: ref.watch(selectedAutoDeleteProvider),
              underline: const SizedBox(),
              items: AutoDeletePreferenceNotifier.options
                  .map(
                    (d) => DropdownMenuItem<int?>(
                      value: d,
                      child: Text(_autoDeleteLabel(d)),
                    ),
                  )
                  .toList(),
              onChanged: (val) {
                ref.read(selectedAutoDeleteProvider.notifier).select(val);
              },
            ),
          ),
          ListTile(
            title: const Text('Cache Size'),
            trailing: DropdownButton<int>(
              value: ref.watch(selectedCacheSizeProvider),
              underline: const SizedBox(),
              items: CacheSizePreferenceNotifier.options
                  .map(
                    (s) => DropdownMenuItem<int>(
                      value: s,
                      child: Text(_cacheSizeLabel(s)),
                    ),
                  )
                  .toList(),
              onChanged: (val) {
                if (val != null) {
                  ref.read(selectedCacheSizeProvider.notifier).select(val);
                }
              },
            ),
          ),
          const SizedBox(height: 16),
          const ListTile(
            title: Text('API Server'),
            subtitle: Text('http://localhost:8000'),
            trailing: Icon(Icons.chevron_right),
          ),
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.only(bottom: 24, top: 16),
            child: Center(
              child: Text(
                _appVersion.isEmpty ? 'Psitta' : 'Psitta v$_appVersion',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsBrandingPanel extends StatelessWidget {
  const _SettingsBrandingPanel();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryText = theme.colorScheme.onSurface;
    final mutedText = theme.colorScheme.onSurfaceVariant;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 16),
              Opacity(
                opacity: isDark ? 0.30 : 1.0,
                child: const PsittaLogo(
                  width: 280,
                  height: 100,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Listen to your documents.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0,
                  color: primaryText,
                ),
              ),
              Text(
                'Improve your writing.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0,
                  color: primaryText,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Facti AI LLC',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: mutedText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shows the user's avatar, name, and email from the JWT access token.
class _AccountTile extends ConsumerWidget {
  const _AccountTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = UserAvatarWidget.watchProfile(ref);

    return profileAsync.when(
      loading: () => const ListTile(
        leading: UserAvatarWidget(size: 40),
        title: Text('Loading...'),
      ),
      error: (_, __) => const ListTile(
        leading: UserAvatarWidget(size: 40),
        title: Text('Account'),
        subtitle: Text('Could not load profile'),
      ),
      data: (profile) {
        final name = profile.name ?? 'User';
        final email = profile.email ?? 'Unknown';
        return ListTile(
          leading: const UserAvatarWidget(size: 40),
          title: Text(name),
          subtitle: Text(email),
        );
      },
    );
  }
}

/// Shows the user's current plan, sourced from the Stripe-backed
/// /billing/status endpoint via [billingStatusProvider]. Monthly doc
/// usage was previously surfaced from the legacy /users/me/subscription
/// endpoint — that field isn't on /billing/status yet, so the subtitle
/// shows subscription state instead until the backend exposes usage.
class _SubscriptionTile extends ConsumerWidget {
  const _SubscriptionTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sub = ref.watch(billingStatusProvider);
    return sub.when(
      loading: () => const ListTile(
        leading: Icon(Icons.card_membership_outlined),
        title: Text('Subscription'),
        subtitle: Text('Loading...'),
      ),
      // The error branch is explicit about "temporarily unavailable"
      // (not "you're Free") and exposes a tap target to retry, so a
      // transient 401/network blip doesn't mislead a paying Pro user.
      error: (_, __) => ListTile(
        leading: const Icon(Icons.error_outline, color: Colors.orange),
        title: const Text('Plan status temporarily unavailable'),
        subtitle: const Text('Tap to retry'),
        onTap: () => ref.invalidate(billingStatusProvider),
      ),
      data: (data) {
        final plan = (data['plan'] as String?) ?? 'free';
        final status = (data['status'] as String?) ?? 'none';
        final planLabel = _kPlanDisplayNames[plan] ?? plan;
        final subtitle = plan == 'free'
            ? 'No active subscription'
            : (status == 'active' ? 'Active' : status);
        return ListTile(
          leading: const Icon(Icons.card_membership_outlined),
          title: Text('Plan: $planLabel'),
          subtitle: Text(subtitle),
        );
      },
    );
  }
}

/// Navigate to plan selection screen.
class _ChangePlanTile extends StatelessWidget {
  const _ChangePlanTile();

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.swap_horiz_outlined),
      title: const Text('Change Plan'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.go('/plan'),
    );
  }
}

/// Launches the Stripe Customer Portal in the user's default browser.
///
/// Visible only to confirmed Pro users. The gate uses [isProUserProvider]
/// (true ONLY when billing is loaded AND plan != free AND status ==
/// active), so Free, loading, and unavailable states all hide the tile —
/// preventing a paying user from being told "you have no subscription"
/// during a transient billing fetch.
///
/// On success the portal URL opens in the system browser via
/// url_launcher and [billingStatusProvider] is invalidated so any plan
/// change made in the portal (cancel, swap tier, swap period) is
/// reflected in the UI when the user returns to the app. Per the
/// 2026-04-23 Key Learning, FutureProvider.autoDispose does not auto-
/// dispose while persistent shell widgets keep listeners alive — explicit
/// invalidate is the only reliable cache bust.
class _ManageSubscriptionTile extends ConsumerStatefulWidget {
  const _ManageSubscriptionTile();

  @override
  ConsumerState<_ManageSubscriptionTile> createState() =>
      _ManageSubscriptionTileState();
}

class _ManageSubscriptionTileState
    extends ConsumerState<_ManageSubscriptionTile> {
  bool _isLaunching = false;

  Future<void> _openPortal() async {
    setState(() => _isLaunching = true);
    final api = ref.read(apiClientProvider);
    try {
      final response = await api.dio.post('/billing/portal-session');
      final data = response.data as Map<String, dynamic>;
      final url = data['url'] as String?;
      if (url == null) {
        _showSnack('Subscription portal returned no URL. Please try again.');
        return;
      }

      final launched = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        _showSnack('Could not open browser. Please try again.');
        return;
      }

      ref.invalidate(billingStatusProvider);

      _showSnack(
        'Manage your subscription in the browser. '
        'This page will refresh when you return.',
        durationSeconds: 5,
      );
    } on DioException catch (e) {
      _handlePortalError(e);
    } catch (_) {
      _showSnack('Connection error. Please check your internet.');
    } finally {
      if (mounted) setState(() => _isLaunching = false);
    }
  }

  void _handlePortalError(DioException e) {
    final status = e.response?.statusCode;
    switch (status) {
      case 404:
        _showSnack('No active subscription. Subscribe first to manage.');
      case 502:
        _showSnack(
          'Subscription portal temporarily unavailable. Please try again.',
        );
      default:
        if (e.type == DioExceptionType.connectionError ||
            e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout) {
          _showSnack('Connection error. Please check your internet.');
        } else {
          _showSnack('Could not open subscription portal. Please try again.');
        }
    }
  }

  void _showSnack(String message, {int durationSeconds = 4}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: Duration(seconds: durationSeconds),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPro = ref.watch(isProUserProvider);
    if (!isPro) return const SizedBox.shrink();

    return ListTile(
      leading: const Icon(Icons.credit_card_outlined),
      title: const Text('Manage Subscription'),
      subtitle: const Text(
        'Update payment, swap plan, or cancel — opens in your browser',
        style: TextStyle(fontSize: 11),
      ),
      trailing: _isLaunching
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.open_in_new),
      enabled: !_isLaunching,
      onTap: _isLaunching ? null : _openPortal,
    );
  }
}

/// Logout button that signs out and redirects to /login.
class _StaySignedInTile extends ConsumerWidget {
  const _StaySignedInTile();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staySignedIn = ref.watch(staySignedInProvider);
    return SwitchListTile(
      secondary: const Icon(Icons.lock_open_outlined),
      title: const Text('Stay signed in'),
      subtitle: const Text(
        'Skip the login screen after signing out',
      ),
      value: staySignedIn,
      onChanged: (value) =>
          ref.read(staySignedInProvider.notifier).toggle(value),
    );
  }
}

class _LogoutTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: const Icon(Icons.logout, color: Colors.red),
      title: const Text('Logout', style: TextStyle(color: Colors.red)),
      onTap: () async {
        await ref.read(authStateProvider.notifier).logout();
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
      ),
    );
  }
}
