import 'package:flutter/material.dart';

import 'lock_gate.dart';
import 'router.dart';
import 'theme.dart';

class FinanceApp extends StatelessWidget {
  const FinanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Finance Tool',
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      routerConfig: appRouter,
      builder: (context, child) => LockGate(child: child ?? const SizedBox.shrink()),
    );
  }
}
