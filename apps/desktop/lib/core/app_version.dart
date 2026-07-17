import 'package:package_info_plus/package_info_plus.dart';

/// The running client's version string, e.g. "1.1.2".
///
/// Loaded once from the platform package metadata at startup
/// ([loadClientVersion], called in main before runApp). Until then it reads
/// "0.0.0", which the server treats as "unknown" and never enforces against —
/// so nothing is ever blocked before we actually know the version.
String _clientVersion = '0.0.0';
bool _loaded = false;

String get clientVersion => _clientVersion;

/// Load + cache the client version from package metadata. Idempotent, and
/// never throws — if the lookup fails the safe "0.0.0" default stands, so a
/// metadata hiccup can never break startup.
Future<void> loadClientVersion() async {
  if (_loaded) return;
  try {
    final info = await PackageInfo.fromPlatform();
    final v = info.version.trim();
    if (v.isNotEmpty) _clientVersion = v;
  } catch (_) {
    // Keep the "0.0.0" default; version metadata must never gate startup.
  }
  _loaded = true;
}

/// Compare two dotted numeric versions ("1.2.10" vs "1.3.0").
///
/// Returns -1 if [a] < [b], 1 if [a] > [b], 0 if equal. **Fail-open:** if
/// either string is malformed/unparseable it returns 0 (treated as "not
/// outdated"), so a bad version string can never trigger a forced update.
/// Build metadata ("+0") and pre-release suffixes ("-beta") are ignored.
int compareVersions(String a, String b) {
  final pa = _parse(a);
  final pb = _parse(b);
  if (pa == null || pb == null) return 0;
  final n = pa.length > pb.length ? pa.length : pb.length;
  for (var i = 0; i < n; i++) {
    final x = i < pa.length ? pa[i] : 0;
    final y = i < pb.length ? pb[i] : 0;
    if (x != y) return x < y ? -1 : 1;
  }
  return 0;
}

List<int>? _parse(String v) {
  final core = v.split('+').first.split('-').first.trim();
  if (core.isEmpty) return null;
  final out = <int>[];
  for (final part in core.split('.')) {
    final n = int.tryParse(part);
    if (n == null) return null;
    out.add(n);
  }
  return out.isEmpty ? null : out;
}
