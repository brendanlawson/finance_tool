import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core_providers.dart';

/// Whether a PIN has ever been set — app lock is opt-in (via Settings),
/// not forced on every install, so most personal-use setups just open
/// straight to the app.
final isPinSetProvider = FutureProvider<bool>((ref) {
  return ref.watch(appLockServiceProvider).isPinSet();
});

/// In-memory "has this session already passed the PIN check" flag. Reset
/// to false every cold start by construction (it's a plain in-memory
/// provider default) — the PIN gates app *launch*, not every screen.
/// A plain Notifier rather than the legacy StateProvider (moved to a
/// separate import path in Riverpod 3.0, and not worth depending on for
/// one boolean flag).
class UnlockedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void unlock() => state = true;
}

final unlockedProvider = NotifierProvider<UnlockedNotifier, bool>(UnlockedNotifier.new);
