import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'app.dart';
import 'core/app_version.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load the running client version once so every API request can stamp it
  // (X-Client-Version) and the /config version floor can be evaluated. Never
  // throws — falls back to a safe default that is never enforced against.
  await loadClientVersion();

  await windowManager.ensureInitialized();
  const WindowOptions windowOptions = WindowOptions(
    minimumSize: Size(900, 600),
    title: 'Psitta',
  );
  // Fire-and-forget by design: the window shows itself once ready while
  // runApp proceeds. Marked unawaited to make that intent explicit.
  unawaited(
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    }),
  );

  runApp(const ProviderScope(child: PsittaApp()));
}
