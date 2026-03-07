import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers/providers.dart';
import '../../data/services/preferences_service.dart';

class VoiceSelectorScreen extends ConsumerWidget {
  const VoiceSelectorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voicesAsync = ref.watch(voicesProvider);
    final selectedId = ref.watch(selectedVoiceIdProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.arrow_back, size: 16),
                  label: const Text('Settings'),
                  onPressed: () => context.go('/settings'),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Default Voice',
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Select the voice used for new documents.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: voicesAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (voices) => voices.isEmpty
                    ? const Center(child: Text('No voices available'))
                    : ListView.separated(
                        itemCount: voices.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final v = voices[i];
                          final isSelected = v.id == selectedId;
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isSelected
                                  ? Theme.of(context)
                                      .colorScheme
                                      .primary
                                  : Theme.of(context)
                                      .colorScheme
                                      .surfaceVariant,
                              child: Text(
                                v.displayName.substring(0, 1).toUpperCase(),
                                style: TextStyle(
                                  color: isSelected
                                      ? Theme.of(context)
                                          .colorScheme
                                          .onPrimary
                                      : null,
                                ),
                              ),
                            ),
                            title: Text(v.displayName),
                            subtitle: Text(v.language),
                            trailing: isSelected
                                ? Icon(Icons.check_circle,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary)
                                : const Icon(
                                    Icons.radio_button_unchecked),
                            onTap: () {
                              ref
                                  .read(selectedVoiceIdProvider
                                      .notifier)
                                  .select(v.id);
                              context.go('/settings');
                            },
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
