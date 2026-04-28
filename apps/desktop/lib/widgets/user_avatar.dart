import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

import '../data/services/auth_service.dart';

/// Decoded user profile from the JWT access token.
class _UserProfile {
  const _UserProfile({this.name, this.email, this.pictureUrl});
  final String? name;
  final String? email;
  final String? pictureUrl;

  String get initials {
    if (name != null && name!.trim().isNotEmpty) {
      final parts = name!.trim().split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
      }
      return parts.first[0].toUpperCase();
    }
    if (email != null && email!.isNotEmpty) {
      return email![0].toUpperCase();
    }
    return '?';
  }
}

/// Provider that decodes the ID token and caches the profile.
/// The ID token (not the access token) contains user profile claims
/// like name, email, and picture from the Google OAuth provider.
///
/// Re-resolves on user-identity change. The provider has no formal
/// dependency on the JWT itself (which lives in secure storage) and
/// no .family key, so without an explicit Riverpod dependency it
/// would return user A's cached profile after user B logs in. The
/// `ref.watch(currentUserIdProvider)` below establishes that
/// dependency: when AuthStateNotifier flips userId on logout/login,
/// this provider's body re-runs and the JWT is re-decoded with the
/// new user's claims. Mirrors the pattern used by the 8 user-scoped
/// preference notifiers in preferences_service.dart.
final _userProfileProvider = FutureProvider.autoDispose<_UserProfile>((ref) async {
  // The watched value isn't used directly -- the JWT is the source
  // of truth for the profile claims, and it's read from secure
  // storage on every invocation below. The watch exists ONLY to
  // tell Riverpod to invalidate the cached _UserProfile when the
  // current user changes. Do not delete this line as "dead code";
  // see the doc comment above for the full rationale.
  ref.watch(currentUserIdProvider);

  final authService = ref.read(authServiceProvider);

  // Prefer ID token — it contains profile claims (name, email, picture).
  // Fall back to access token if ID token is not available.
  final idToken = await authService.getIdToken();
  final token = idToken ?? await authService.getAccessToken();
  if (token == null) return const _UserProfile();

  try {
    final claims = JwtDecoder.decode(token);
    return _UserProfile(
      name: (claims['name'] as String?) ??
          (claims['https://psitta.app/name'] as String?) ??
          (claims['given_name'] as String?),
      email: (claims['email'] as String?) ??
          (claims['https://psitta.app/email'] as String?),
      pictureUrl: (claims['picture'] as String?) ??
          (claims['https://psitta.app/picture'] as String?),
    );
  } catch (_) {
    return const _UserProfile();
  }
});

/// Reusable avatar widget that shows the user's Google profile photo
/// or their initials as a fallback.
class UserAvatarWidget extends ConsumerWidget {
  const UserAvatarWidget({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(_userProfileProvider);
    final theme = Theme.of(context);

    return profileAsync.when(
      loading: () => CircleAvatar(
        radius: size / 2,
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
      ),
      error: (_, __) => CircleAvatar(
        radius: size / 2,
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        child: Icon(Icons.person, size: size * 0.5),
      ),
      data: (profile) {
        if (profile.pictureUrl != null && profile.pictureUrl!.isNotEmpty) {
          return CircleAvatar(
            radius: size / 2,
            backgroundImage: NetworkImage(profile.pictureUrl!),
            onBackgroundImageError: (_, __) {},
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
          );
        }
        return CircleAvatar(
          radius: size / 2,
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Text(
            profile.initials,
            style: TextStyle(
              fontSize: size * 0.38,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
        );
      },
    );
  }

  /// Access the decoded profile for displaying name/email elsewhere.
  static AsyncValue<({String? name, String? email, String? pictureUrl})>
      watchProfile(WidgetRef ref) {
    return ref.watch(_userProfileProvider).whenData(
          (p) => (name: p.name, email: p.email, pictureUrl: p.pictureUrl),
        );
  }
}
