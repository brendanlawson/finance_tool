import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/app_lock_providers.dart';
import 'pin_entry_screen.dart';

/// Wraps the app's real content, deciding whether to show it or a PIN
/// entry screen. If checking whether a PIN exists fails for some reason,
/// this fails *open* (shows the app) rather than locking the user out
/// permanently with no recovery path — the PIN is a convenience gate on
/// top of an already-encrypted database, not the thing standing between
/// an attacker and the data, so failing open here does not weaken actual
/// security (see AppLockService's doc comment).
class LockGate extends ConsumerWidget {
  const LockGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pinSet = ref.watch(isPinSetProvider);
    return pinSet.when(
      data: (isSet) {
        if (!isSet) return child;
        final unlocked = ref.watch(unlockedProvider);
        return unlocked ? child : const PinEntryScreen();
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stackTrace) => child,
    );
  }
}
