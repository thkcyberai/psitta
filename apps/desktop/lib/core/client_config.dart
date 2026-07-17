import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers/providers.dart';
import 'app_version.dart';

/// The server-owned client control plane, read from `GET /config`.
///
/// Mirrors the backend payload `{ minimum_supported_version,
/// recommended_version, flags }`. This is how the client learns — without a
/// release — the version floor it must meet and which remotely-controlled
/// features are on. Consumers treat it fail-open (see [updateStatusProvider]).
class ClientConfig {
  const ClientConfig({
    required this.minimumSupportedVersion,
    required this.recommendedVersion,
    required this.flags,
  });

  factory ClientConfig.fromMap(Map<String, dynamic> m) {
    final rawFlags = m['flags'];
    return ClientConfig(
      minimumSupportedVersion:
          (m['minimum_supported_version'] as String?) ?? '0.0.0',
      recommendedVersion: (m['recommended_version'] as String?) ?? '0.0.0',
      flags: rawFlags is Map
          ? rawFlags.map((k, v) => MapEntry(k.toString(), v))
          : <String, dynamic>{},
    );
  }

  final String minimumSupportedVersion;
  final String recommendedVersion;
  final Map<String, dynamic> flags;

  /// Permissive fallback used while `/config` is loading or errored: no version
  /// floor, no flags — so a config fault never blocks or degrades the app.
  static const permissive = ClientConfig(
    minimumSupportedVersion: '0.0.0',
    recommendedVersion: '0.0.0',
    flags: {},
  );

  /// Read a boolean feature flag / kill switch; [orElse] when absent or
  /// non-boolean.
  bool flag(String key, {bool orElse = false}) {
    final v = flags[key];
    return v is bool ? v : orElse;
  }
}

/// `GET /config` — the remote control plane. autoDispose; unauthenticated on the
/// server so it resolves even with a stale token.
final clientConfigProvider =
    FutureProvider.autoDispose<ClientConfig>((ref) async {
  final api = ref.watch(apiClientProvider);
  final res = await api.dio.get('/config');
  return ClientConfig.fromMap(res.data as Map<String, dynamic>);
});

/// Whether the running client is current, should update, or must update.
enum UpdateStatus { upToDate, updateRecommended, updateRequired }

/// Resolve [UpdateStatus] by comparing the running [clientVersion] to the
/// server floor. **Fail-open:** while `/config` is loading or errored the
/// status is [UpdateStatus.upToDate], so a network/config hiccup can never
/// wall the user out of the app.
final updateStatusProvider = Provider.autoDispose<UpdateStatus>((ref) {
  return ref.watch(clientConfigProvider).when(
        data: (cfg) {
          final v = clientVersion;
          if (compareVersions(v, cfg.minimumSupportedVersion) < 0) {
            return UpdateStatus.updateRequired;
          }
          if (compareVersions(v, cfg.recommendedVersion) < 0) {
            return UpdateStatus.updateRecommended;
          }
          return UpdateStatus.upToDate;
        },
        loading: () => UpdateStatus.upToDate,
        error: (_, __) => UpdateStatus.upToDate,
      );
});
