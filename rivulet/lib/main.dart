import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fvp/fvp.dart' as fvp;
import 'package:rivulet/features/auth/auth_provider.dart';
import 'package:rivulet/features/auth/screens/login_screen.dart';
import 'package:rivulet/features/auth/screens/server_setup_screen.dart';
import 'package:rivulet/features/search/search_screen.dart';
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
    Future.microtask(() {
      ref
          .read(serverUrlProvider.notifier)
          .load()
          .then((_) => ref.read(authProvider.notifier).checkStatus());
    });
  }

  @override
  Widget build(BuildContext context) {
    // Watch server URL and Auth State
    // Rename variable to reflect it's just a String, not an AsyncValue
    final serverUrl = ref.watch(serverUrlProvider);
    final isAuth = ref.watch(authProvider);

    return MaterialApp(
      title: 'Rivulet',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      // Remove .when() and pass the variable directly
      home: _buildHome(serverUrl, isAuth),

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

  Widget _buildHome(String? serverUrl, bool isAuth) {
    if (serverUrl == null) {
      // Step 1: Need Server URL
      return const ServerSetupScreen();
    }

    if (!isAuth) {
      // Step 2: Need Authentication
      return const LoginScreen();
    }

    // Step 3: Logged In -> Main App
    return const DiscoveryScreen();
  }
}
