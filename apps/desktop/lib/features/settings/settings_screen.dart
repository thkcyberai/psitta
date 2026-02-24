import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/colors.dart';
import '../../data/services/preferences_service.dart';

/// Settings Screen — user preferences and app configuration.
///
/// Desktop layout: single-column settings list with sections.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final selectedTheme = ref.watch(selectedThemeNameProvider);

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
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: ListView(
                children: [
                  _SectionHeader(title: 'Appearance'),
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
                          ref
                              .read(selectedThemeNameProvider.notifier)
                              .select(value);
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
                  _SectionHeader(title: 'Playback'),
                  const ListTile(
                    title: Text('Default Voice'),
                    subtitle: Text('Rachel'),
                    trailing: Icon(Icons.chevron_right),
                  ),
                  const ListTile(
                    title: Text('Playback Speed'),
                    subtitle: Text('1.0x'),
                    trailing: Icon(Icons.chevron_right),
                  ),

                  const SizedBox(height: 16),
                  _SectionHeader(title: 'Storage'),
                  const ListTile(
                    title: Text('Auto-Delete Documents'),
                    subtitle: Text('After 60 days'),
                    trailing: Icon(Icons.chevron_right),
                  ),
                  const ListTile(
                    title: Text('Cache Size'),
                    subtitle: Text('256 MB'),
                    trailing: Icon(Icons.chevron_right),
                  ),

                  const SizedBox(height: 16),
                  _SectionHeader(title: 'Account'),
                  const ListTile(
                    title: Text('Subscription'),
                    subtitle: Text('Free tier — 3 documents/month'),
                    trailing: Icon(Icons.chevron_right),
                  ),
                  const ListTile(
                    title: Text('API Server'),
                    subtitle: Text('http://localhost:8000'),
                    trailing: Icon(Icons.chevron_right),
                  ),

                  const SizedBox(height: 32),
                  Center(
                    child: Text(
                      'Psitta v0.1.0',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

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
