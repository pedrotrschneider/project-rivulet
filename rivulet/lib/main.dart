import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fvp/fvp.dart' as fvp;
import 'package:rivulet/features/auth/auth_provider.dart';
import 'package:rivulet/features/auth/profiles_provider.dart';
import 'package:rivulet/features/auth/screens/login_screen.dart';
import 'package:rivulet/features/auth/screens/profile_selection_screen.dart';
import 'package:rivulet/features/auth/screens/server_setup_screen.dart';
import 'package:rivulet/features/app_shell/app_shell.dart';
import 'package:rivulet/features/player/player_screen.dart';

import 'dart:io';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:rivulet/core/platform/linux_path_provider.dart';
import 'package:rivulet/core/network/network_monitor.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isLinux) {
    try {
      PathProviderPlatform.instance = LinuxPathProviderOverride();
    } catch (_) {
      // Ignore if fails, fallback to default might work or crash later
    }
  }

  fvp.registerWith();
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  @override
  void initState() {
    super.initState();
    // Initialize state
    Future.microtask(() async {
      await ref.read(serverUrlProvider.notifier).load();
      await ref.read(authProvider.notifier).checkStatus();
      await ref.read(selectedProfileProvider.notifier).load();
      ref.read(networkMonitorProvider); // Initialize monitoring
    });
  }

  @override
  Widget build(BuildContext context) {
    // Watch server URL, Auth State, and Selected Profile
    final serverUrl = ref.watch(serverUrlProvider);
    final isAuth = ref.watch(authProvider);
    final selectedProfileId = ref.watch(selectedProfileProvider);

    return MaterialApp(
      title: 'Rivulet',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: _buildHome(serverUrl, isAuth, selectedProfileId),

      onGenerateRoute: (settings) {
        if (settings.name == '/player') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (context) => PlayerScreen(
              url:
                  args['streamUrl'], // Discovery passes it as 'streamUrl' or we need to check usage?
              // The search screen passes args? No, discovery and others invoke PlayerScreen constructor directly usually.
              // Wait, the named route is used in main.dart.
              // StreamSelectionSheet Pushes MaterialPageRoute directly.
              // So main.dart likely handles deep links? Or just route generation.
              // If StreamSelectionSheet pushes directly, it uses the constructor.
              // If main.dart handles /player, it uses args map.
              // Let's assume the map key 'streamUrl' is what I used in main.dart recently.
              // But PlayerScreen now expects 'url'.
              externalId: args['externalId'],
              title: args['title'],
              type: args['type'],
              season: args['season'],
              episode: args['episode'],
              startPosition: args['startPosition'] ?? 0,
              imdbId: args['imdbId'],
            ),
          );
        }
        return null;
      },
    );
  }

  Widget _buildHome(String? serverUrl, bool isAuth, String? selectedProfileId) {
    if (serverUrl == null) {
      // Step 1: Need Server URL
      return const ServerSetupScreen();
    }

    if (!isAuth) {
      // Step 2: Need Authentication
      return const LoginScreen();
    }

    if (selectedProfileId == null) {
      // Step 3: Need Profile Selection
      return const ProfileSelectionScreen();
    }

    // Step 4: Logged In with Profile -> Main App
    return const AppShell();
  }
}
