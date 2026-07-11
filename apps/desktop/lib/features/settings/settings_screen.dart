import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/plan_gate.dart';
import '../../core/quota_gate.dart';
import '../../data/providers/providers.dart';
import '../../data/providers/blueprint_providers.dart'
    show blueprintsListProvider, blueprintDetailProvider;
import '../../data/services/audio_service.dart' show audioServiceProvider;
import '../shell/widgets/player_bar.dart' show activeDocumentIdProvider;
import '../../core/i18n/working_language.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/preferences_service.dart';
import '../../shared/widgets/psitta_logo.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/voice_avatar.dart';
import '../../l10n/app_localizations.dart';

String _autoDeleteLabel(AppLocalizations loc, int? days) =>
    days == null ? loc.setAutoDeleteNever : loc.setAutoDeleteAfter(days);

String _cacheSizeLabel(int mb) => mb >= 1024 ? '${mb ~/ 1024} GB' : '$mb MB';

/// Backend plan id → user-facing label. Falls through to the raw id
/// for any plan not yet shipped (forward-compat).
const Map<String, String> _kPlanDisplayNames = {
  'free': 'Free',
  'reading_nook_pro': 'Reading Nook Pro',
  'writing_nook_pro': 'Writing Nook Pro',
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
      _appVersion = info.version;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            loc.navSettings,
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
    final loc = AppLocalizations.of(context);
    final selectedTheme = ref.watch(selectedThemeNameProvider);
    final swhMode = ref.watch(selectedSwhModeProvider);
    final isPro = ref.watch(isProUserProvider);
    // Writing-Nook-only settings (Story-Coach, Writing Nook guide) are gated on
    // this so they never appear in the Reading/Free experience (1.0.9.0 parity).
    final isWritingNook =
        ref.watch(planStatusProvider).plan == 'writing_nook_pro';
    final maxSpeed = isPro ? kProMaxSpeed : kFreeMaxSpeed;
    final availableSpeeds =
        SpeedPreferenceNotifier.speeds.where((s) => s <= maxSpeed).toList();
    final currentSpeed = ref.watch(selectedSpeedProvider);
    final displaySpeed = availableSpeeds.contains(currentSpeed)
        ? currentSpeed
        : availableSpeeds.last;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 640),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          _SettingsCard(
            icon: Icons.person_outline,
            title: loc.setSecAccount,
            children: [
              _AccountTile(),
              _SubscriptionTile(),
              _ManageSubscriptionTile(),
              _ChangePlanTile(),
              _StaySignedInTile(),
            ],
          ),
          _SettingsCard(
            icon: Icons.logout,
            title: loc.setSecSession,
            children: [_LogoutTile()],
          ),
          _SettingsCard(
            icon: Icons.graphic_eq_outlined,
            title: loc.setSecUsage,
            children: [_PremiumVoicesUsageTile()],
          ),
          _SettingsCard(
            icon: Icons.translate_outlined,
            title: loc.setSecLanguage,
            children: [
              Builder(builder: (context) {
                final currentWl =
                    WorkingLanguage.fromLocale(ref.watch(selectedLocaleProvider));
                final currentLabel =
                    currentWl?.label ?? WorkingLanguage.englishUS.label;
                final device =
                    WidgetsBinding.instance.platformDispatcher.locale;
                final deviceLabel = WorkingLanguage.fromLocale(device)?.label ??
                    WorkingLanguage.englishUS.label;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.language_outlined),
                      title: Text(loc.setWorkingLanguage),
                      subtitle: Text(
                        loc.setWorkingLanguageSub,
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: Text(
                        currentLabel,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.restart_alt),
                      title: Text(loc.setResetToDeviceLanguage),
                      subtitle: Text(
                        loc.setResetToDeviceLanguageSub(deviceLabel),
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: OutlinedButton(
                        onPressed: () async {
                          // 1. Snap the UI locale back to the device language.
                          await ref
                              .read(selectedLocaleProvider.notifier)
                              .resetToDeviceDefault();
                          // 2. Reset the narrator voice to that language's
                          //    default, so a stale voice never reads the next
                          //    document with the wrong accent.
                          final resolved = WorkingLanguage.fromLocale(device) ??
                              WorkingLanguage.englishUS;
                          ref
                              .read(selectedVoiceIdProvider.notifier)
                              .select(resolved.defaultVoiceId);
                          ref.invalidate(blueprintsListProvider);
                          ref.invalidate(blueprintDetailProvider);
                          // 3. Clear the open document + stop audio so the
                          //    Writing Desk / player bar don't keep a
                          //    now-mismatched document loaded.
                          await ref.read(audioServiceProvider).stop();
                          ref
                              .read(activeDocumentIdProvider.notifier)
                              .state = null;
                          if (!context.mounted) return;
                          // 4. Land the writer in the Library — a clean,
                          //    language-neutral starting point after the reset.
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  loc.setLanguageResetSnack(deviceLabel)),
                            ),
                          );
                          context.go('/library');
                        },
                        child: Text(loc.setResetButton),
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
          _SettingsCard(
            icon: Icons.palette_outlined,
            title: loc.setSecAppearance,
            children: [
              ListTile(
                title: Text(loc.setTheme),
                subtitle: Text(selectedTheme),
                trailing: SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String>(
                    value: selectedTheme,
                    items: ThemeNames.all
                        .map((th) => DropdownMenuItem(value: th, child: Text(th)))
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
            ],
          ),
          _SettingsCard(
            icon: Icons.headphones_outlined,
            title: loc.setSecPlayback,
            children: [
              Builder(builder: (context) {
                final voicesAsync = ref.watch(voicesProvider);
                final selectedId = ref.watch(selectedVoiceIdProvider);
                final displayName = voicesAsync.whenOrNull(
                  data: (voices) {
                    for (final v in voices) {
                      if (v.id == selectedId) return v.displayName;
                    }
                    return null;
                  },
                );
                return ListTile(
                  leading: displayName == null
                      ? const SizedBox(width: 32, height: 32)
                      : VoiceAvatar(
                          voiceName: displayName,
                          size: 32,
                          variant: VoiceAvatarVariant.small,
                        ),
                  title: Text(loc.setDefaultVoice),
                  subtitle: Text(displayName ?? loc.setSelectAVoice),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go('/voices'),
                );
              }),
              ListTile(
                title: Text(loc.setPlaybackSpeed),
                subtitle: isPro
                    ? null
                    : Text(
                        loc.setSpeedFreeLimit,
                        style: const TextStyle(fontSize: 11),
                      ),
                trailing: DropdownButton<double>(
                  value: displaySpeed,
                  underline: const SizedBox(),
                  items: availableSpeeds
                      .map((s) => DropdownMenuItem<double>(
                            value: s,
                            child: Text('${s}x'),
                          ))
                      .toList(),
                  onChanged: (val) {
                    if (val == null) return;
                    ref.read(selectedSpeedProvider.notifier).select(val);
                  },
                ),
              ),
            ],
          ),
          _SettingsCard(
            icon: Icons.subtitles_outlined,
            title: loc.setSecSwh,
            children: [
              if (!isPro)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                  child: Row(
                    children: [
                      Icon(Icons.lock_outline,
                          size: 14, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          loc.setSwhProGate,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.go('/plan'),
                        child: Text(loc.navUpgrade),
                      ),
                    ],
                  ),
                ),
              RadioListTile<String>(
                title: Text(loc.setSwhReadWith),
                subtitle: Text(
                  loc.setSwhReadWithSub,
                  style: const TextStyle(fontSize: 11),
                ),
                value: SwhMode.always,
                groupValue: swhMode,
                onChanged: isPro
                    ? (v) =>
                        ref.read(selectedSwhModeProvider.notifier).select(v!)
                    : null,
              ),
              RadioListTile<String>(
                title: Text(loc.setSwhReadWithout),
                value: SwhMode.never,
                groupValue: swhMode,
                onChanged: isPro
                    ? (v) =>
                        ref.read(selectedSwhModeProvider.notifier).select(v!)
                    : null,
              ),
            ],
          ),
          // Writing-Nook-only — hidden entirely for Reading/Free (1.0.9.0 parity).
          if (isWritingNook) ...[
            _SettingsCard(
              icon: Icons.auto_stories_outlined,
              title: loc.setSecStoryCoach,
              children: [
                SwitchListTile(
                  title: Text(loc.setStoryCoachToggle),
                  subtitle: Text(
                    loc.setStoryCoachSub,
                    style: const TextStyle(fontSize: 11),
                  ),
                  value: ref.watch(storyCoachEnabledProvider),
                  onChanged: (v) => ref
                      .read(storyCoachEnabledProvider.notifier)
                      .setEnabled(v),
                ),
              ],
            ),
            _SettingsCard(
              icon: Icons.support_agent,
              title: loc.setSecHelpGuide,
              children: [
                SwitchListTile(
                  title: Text(loc.setHelpGuideToggle),
                  subtitle: Text(
                    loc.setHelpGuideSub,
                    style: const TextStyle(fontSize: 11),
                  ),
                  value: ref.watch(guideChatEnabledProvider),
                  onChanged: (v) =>
                      ref.read(guideChatEnabledProvider.notifier).setEnabled(v),
                ),
              ],
            ),
          ],
          _SettingsCard(
            icon: Icons.sd_storage_outlined,
            title: loc.setSecStorage,
            children: [
              ListTile(
                title: Text(loc.setAutoDelete),
                trailing: DropdownButton<int?>(
                  value: ref.watch(selectedAutoDeleteProvider),
                  underline: const SizedBox(),
                  items: AutoDeletePreferenceNotifier.options
                      .map((d) => DropdownMenuItem<int?>(
                            value: d,
                            child: Text(_autoDeleteLabel(loc, d)),
                          ))
                      .toList(),
                  onChanged: (val) {
                    ref.read(selectedAutoDeleteProvider.notifier).select(val);
                  },
                ),
              ),
              ListTile(
                title: Text(loc.setCacheSize),
                trailing: DropdownButton<int>(
                  value: ref.watch(selectedCacheSizeProvider),
                  underline: const SizedBox(),
                  items: CacheSizePreferenceNotifier.options
                      .map((s) => DropdownMenuItem<int>(
                            value: s,
                            child: Text(_cacheSizeLabel(s)),
                          ))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      ref.read(selectedCacheSizeProvider.notifier).select(val);
                    }
                  },
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 16),
            child: Center(
              child: Text(
                // Tier-aware label: Writing shows the real build version;
                // Free/Reading pin to v1.1.0 (kept on the Reading line).
                isWritingNook
                    ? (_appVersion.isEmpty ? 'Psitta' : 'Psitta v$_appVersion')
                    : 'Psitta v1.1.0',
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


/// A polished settings section: rounded card with an icon + title header and a
/// list of control rows. Big-tech grouped-settings look.
class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.icon,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.18)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                Icon(icon, size: 18, color: scheme.primary),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: scheme.outline.withValues(alpha: 0.14)),
          ...children,
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
    final loc = AppLocalizations.of(context);

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
                loc.brandListen,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0,
                  color: primaryText,
                ),
              ),
              Text(
                loc.brandImprove,
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
    final loc = AppLocalizations.of(context);
    final profileAsync = UserAvatarWidget.watchProfile(ref);

    return profileAsync.when(
      loading: () => ListTile(
        leading: const UserAvatarWidget(size: 40),
        title: Text(loc.setLoading),
      ),
      error: (_, __) => ListTile(
        leading: const UserAvatarWidget(size: 40),
        title: Text(loc.setSecAccount),
        subtitle: Text(loc.accountLoadError),
      ),
      data: (profile) {
        final name = profile.name ?? loc.accountFallbackName;
        final email = profile.email ?? loc.accountFallbackEmail;
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
    final loc = AppLocalizations.of(context);
    final sub = ref.watch(billingStatusProvider);
    return sub.when(
      loading: () => ListTile(
        leading: const Icon(Icons.card_membership_outlined),
        title: Text(loc.subTitle),
        subtitle: Text(loc.setLoading),
      ),
      // The error branch is explicit about "temporarily unavailable"
      // (not "you're Free") and exposes a tap target to retry, so a
      // transient 401/network blip doesn't mislead a paying Pro user.
      error: (_, __) => ListTile(
        leading: const Icon(Icons.error_outline, color: Colors.orange),
        title: Text(loc.subStatusUnavailable),
        subtitle: Text(loc.subTapRetry),
        onTap: () => ref.invalidate(billingStatusProvider),
      ),
      data: (data) {
        final planStatus = PlanStatus.fromMap(data);
        final planLabel = _kPlanDisplayNames[planStatus.plan] ?? planStatus.plan;

        // Tester-allowlist users get a distinct title + sunset-date
        // subtitle and a tooltip explaining the alpha access. The
        // tile itself stays the same shape so the Settings list
        // layout doesn't shift between sources.
        if (planStatus.isTesterAllowlist) {
          final periodEnd = planStatus.currentPeriodEnd;
          final dateText = periodEnd != null
              ? formatResetDate(periodEnd)
              : loc.subUnknownDate;
          return Tooltip(
            message: loc.subAlphaTooltip(dateText),
            child: ListTile(
              leading: const Icon(Icons.card_membership_outlined),
              title: Text(loc.subPlanAlphaTester(planLabel)),
              subtitle: Text(loc.subActiveUntil(dateText)),
            ),
          );
        }

        final subtitle = planStatus.plan == 'free'
            ? loc.subNoActive
            : (planStatus.status == 'active'
                ? loc.subActive
                : planStatus.status);
        return ListTile(
          leading: const Icon(Icons.card_membership_outlined),
          title: Text(loc.subPlanLabel(planLabel)),
          subtitle: Text(subtitle),
        );
      },
    );
  }
}

/// Premium-voices (ElevenLabs) char usage for the current billing
/// period. Sourced from [quotaUsageProvider] which calls
/// `GET /users/me/subscription`. Free users see a Pro-gate row instead
/// of the progress bar — the EL counters are zero for them anyway.
class _PremiumVoicesUsageTile extends ConsumerWidget {
  const _PremiumVoicesUsageTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final quotaAsync = ref.watch(quotaUsageProvider);
    return quotaAsync.when(
      loading: () => ListTile(
        leading: const Icon(Icons.graphic_eq_outlined),
        title: Text(loc.featPremiumVoices),
        subtitle: Text(loc.setLoading),
      ),
      error: (_, __) => ListTile(
        leading: const Icon(Icons.error_outline, color: Colors.orange),
        title: Text(loc.featPremiumVoices),
        subtitle: Text(loc.usageUnavailable),
        onTap: () => ref.invalidate(quotaUsageProvider),
      ),
      data: (info) {
        if (!info.hasElQuota) {
          return ListTile(
            leading: const Icon(Icons.graphic_eq_outlined),
            title: Text(loc.featPremiumVoices),
            subtitle: Text(loc.usageStandardFree),
            trailing: TextButton(
              onPressed: () => context.go('/plan'),
              child: Text(loc.navUpgrade),
            ),
          );
        }
        final theme = Theme.of(context);
        final progressColor = elProgressColor(context, info);
        final resetText = info.elCharsResetAt != null
            ? loc.usageResets(formatResetDate(info.elCharsResetAt!))
            : '';
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.graphic_eq_outlined, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      loc.featPremiumVoices,
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
                  if (resetText.isNotEmpty)
                    Text(
                      resetText,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: info.elFraction,
                  minHeight: 6,
                  color: progressColor,
                  backgroundColor:
                      theme.colorScheme.surfaceContainerHighest,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                elQuotaSubtitle(info),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
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
    final loc = AppLocalizations.of(context);
    return ListTile(
      leading: const Icon(Icons.swap_horiz_outlined),
      title: Text(loc.setChangePlan),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.go('/plan'),
    );
  }
}

/// Launches the Stripe Customer Portal in the user's default browser.
///
/// Visible only to users with an active Stripe subscription. The gate
/// uses [PlanStatus.isStripeSubscribed] (true ONLY when billing is
/// loaded AND plan != free AND status == active AND source == stripe),
/// so Free, loading, unavailable, dev_override, and tester_allowlist
/// states all hide the tile — preventing a paying user from being
/// told "you have no subscription" during a transient billing fetch,
/// AND preventing comp/grandfathered/allowlist Pro users from tapping
/// into a 502 (KL 2026-05-22b). Conversion path for non-Stripe Pro
/// users stays open via _ChangePlanTile.
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
        _showSnack(AppLocalizations.of(context).manageNoUrl);
        return;
      }

      final launched = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        _showSnack(AppLocalizations.of(context).planCouldNotOpenBrowser);
        return;
      }

      ref.invalidate(billingStatusProvider);

      _showSnack(
        AppLocalizations.of(context).manageBrowserMsg,
        durationSeconds: 5,
      );
    } on DioException catch (e) {
      _handlePortalError(e);
    } catch (_) {
      _showSnack(AppLocalizations.of(context).planConnectionError);
    } finally {
      if (mounted) setState(() => _isLaunching = false);
    }
  }

  void _handlePortalError(DioException e) {
    final status = e.response?.statusCode;
    switch (status) {
      case 404:
        _showSnack(AppLocalizations.of(context).manageNoSubscription);
      case 502:
        _showSnack(AppLocalizations.of(context).managePortalUnavailable);
      default:
        if (e.type == DioExceptionType.connectionError ||
            e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout) {
          _showSnack(AppLocalizations.of(context).planConnectionError);
        } else {
          _showSnack(AppLocalizations.of(context).managePortalError);
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
    // KL 2026-05-22b — only show Manage Subscription for users with
    // an active Stripe subscription. dev_override / tester_allowlist /
    // comp / grandfathered Pro users have no Stripe customer record
    // and the portal-session call would 502 (api/v1/billing.py:359).
    // Conversion path for non-Stripe Pro users stays open via
    // _ChangePlanTile.
    final planStatus = ref.watch(planStatusProvider);
    if (!planStatus.isStripeSubscribed) return const SizedBox.shrink();
    final loc = AppLocalizations.of(context);

    return ListTile(
      leading: const Icon(Icons.credit_card_outlined),
      title: Text(loc.manageTitle),
      subtitle: Text(
        loc.manageSubtitle,
        style: const TextStyle(fontSize: 11),
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
    final loc = AppLocalizations.of(context);
    return SwitchListTile(
      secondary: const Icon(Icons.lock_open_outlined),
      title: Text(loc.staySignedIn),
      subtitle: Text(
        loc.staySignedInSub,
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
    final loc = AppLocalizations.of(context);
    return ListTile(
      leading: const Icon(Icons.logout, color: Colors.red),
      title: Text(loc.setLogout, style: const TextStyle(color: Colors.red)),
      onTap: () async {
        await ref.read(authStateProvider.notifier).logout();
      },
    );
  }
}
