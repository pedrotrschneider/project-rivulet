import 'dart:async';

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

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
          final url = settings.arguments as String;
          return MaterialPageRoute(
            builder: (context) => PlayerScreen(url: url),
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
