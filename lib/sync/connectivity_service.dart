import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Wrapper dịch vụ kiểm tra trạng thái mạng.
/// Cung cấp stream và method kiểm tra online/offline.
class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  final _controller = StreamController<bool>.broadcast();

  /// Stream emitting true khi online, false khi offline.
  Stream<bool> get onConnectivityChanged => _controller.stream;

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  void init() {
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (online != _isOnline) {
        _isOnline = online;
        _controller.add(online);
        debugPrint('[ConnectivityService] Status: ${online ? "ONLINE" : "OFFLINE"}');
      }
    });
    // Initial check
    _connectivity.checkConnectivity().then((results) {
      _isOnline = results.any((r) => r != ConnectivityResult.none);
      _controller.add(_isOnline);
    });
  }

  /// One-shot check
  Future<bool> checkNow() async {
    final results = await _connectivity.checkConnectivity();
    _isOnline = results.any((r) => r != ConnectivityResult.none);
    return _isOnline;
  }

  void dispose() {
    _subscription?.cancel();
    _controller.close();
  }
}
