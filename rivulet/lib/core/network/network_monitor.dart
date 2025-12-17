import 'dart:async';
import 'dart:io';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'network_monitor.g.dart';

@Riverpod(keepAlive: true)
class NetworkMonitor extends _$NetworkMonitor {
  Timer? _timer;

  @override
  bool build() {
    // Start with a safe default (true) or pessimistic (false)?
    // User wants immediate feedback, but false might block UI unnecessarily on startup.
    // Let's default to true and correct it quickly.
    _startMonitoring();

    ref.onDispose(() {
      _timer?.cancel();
    });

    return true;
  }

  void _startMonitoring() {
    // Check immediately
    _checkConnection();

    // Check every 5 seconds
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      _checkConnection();
    });
  }

  Future<void> _checkConnection() async {
    bool hasConnection = false;
    try {
      final result = await InternetAddress.lookup('google.com');
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        hasConnection = true;
      }
    } on SocketException catch (_) {
      hasConnection = false;
    }

    if (state != hasConnection) {
      state = hasConnection;
    }
  }
}
