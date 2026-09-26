import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'routes/app_router.dart';
import 'services/local_storage_service.dart';
import 'widgets/global_alert_banner.dart';

void main() async {
  // Ensure native bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive storage boxes
  await Hive.initFlutter();
  final localStorageService = LocalStorageService();
  await localStorageService.init();

  runApp(
    ProviderScope(
      overrides: [
        // Provide the fully initialized Hive local storage service instance
        localStorageProvider.overrideWithValue(localStorageService),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Read route navigation manager and theme configuration state
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeProvider);

    return MaterialApp.router(
      title: 'Saathi Shield',
      debugShowCheckedModeBanner: false,
      
      // Theme settings
      themeMode: themeMode,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      
      // GoRouter configurations
      routerConfig: router,

      builder: (context, child) {
        return Stack(
          children: [
            if (child != null) child,
            const GlobalAlertBanner(),
          ],
        );
      },
    );
  }
}
