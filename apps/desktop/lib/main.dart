import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'app.dart';

/// Psitta Desktop — Application Entry Point.
///
/// Initializes the Flutter engine, configures the desktop window
/// (minimum size, title, center position), then launches the app.
/// Window management is desktop-only — mobile builds skip this.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Desktop Window Configuration ──────────────────────────────
  await windowManager.ensureInitialized();

  const windowOptions = WindowOptions(
    size: Size(1280, 800),
    minimumSize: Size(900, 600),
    center: true,
    title: 'Psitta',
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  // ── Launch App ────────────────────────────────────────────────
  runApp(const ProviderScope(child: PsittaApp()));
}
