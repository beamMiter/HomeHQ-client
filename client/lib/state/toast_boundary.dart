import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/toast.dart';
import 'auth_state.dart';

/// A toast belongs to one session.
///
/// The messenger is app-wide, so without this a toast raised on Home survives
/// the redirect and pops up on top of the login screen after logout (and the
/// reverse on login). Clear it whenever the signed-in state flips.
///
/// Watch it once from the app root.
final toastAuthBoundaryProvider = Provider<void>((ref) {
  ref.listen<bool>(authProvider.select((s) => s.isAuthenticated), (prev, next) {
    if (prev != next) AppToast.clear();
  });
});
