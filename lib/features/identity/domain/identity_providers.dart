/// Identity providers — expose the current local user to the whole app.
///
/// `currentUserProvider` is an AsyncNotifier so any screen can `ref.watch` it
/// and rebuild when the display name changes. Halaqa, Al-Minbar and the share
/// composer all read the current user's id + name from here.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/user_profile.dart';
import '../data/identity_repository.dart';

final identityRepositoryProvider = Provider<IdentityRepository>((ref) {
  return IdentityRepository();
});

final currentUserProvider =
    AsyncNotifierProvider<CurrentUserNotifier, UserProfile>(
  CurrentUserNotifier.new,
);

class CurrentUserNotifier extends AsyncNotifier<UserProfile> {
  @override
  Future<UserProfile> build() async {
    final repo = ref.watch(identityRepositoryProvider);
    return repo.ensureProfile();
  }

  /// Rename the current user (used from the Halaqa create/join flow).
  Future<void> updateName(String name) async {
    if (name.trim().isEmpty) return;
    final repo = ref.read(identityRepositoryProvider);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => repo.updateDisplayName(name));
  }
}
