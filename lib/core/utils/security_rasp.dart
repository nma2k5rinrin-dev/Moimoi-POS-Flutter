import 'package:flutter/foundation.dart';
import 'package:freerasp/freerasp.dart';
import 'package:flutter/services.dart';

/// Chuyên xử lý chống Root / Fake Emulator cho môi trường TiyPOS
class SecurityRasp {
  static Future<void> init() async {
    // Chỉ kích hoạt trên Mobile/Desktop build, không chạy trên Web (WASM/CanvasKit)
    if (kIsWeb) return;

    try {
      final config = TalsecConfig(
        /// For Android
        androidConfig: AndroidConfig(
          packageName: 'com.moimoi.moimoi_pos',
          signingCertHashes: [
            // Cần điền Hash thật của bản Release sau (tạm thời để empty key cho debug)
            'dummy_hash_for_debug',
          ],
        ),
        watcherMail: 'security@moimoi.vn',
        isProd: !kDebugMode,
      );

      // Thiết lập callback xử lý khi phát hiện hack/root
      final callback = ThreatCallback(
        onAppIntegrity: () => _killApp('App is modified!'),
        onObfuscationIssues: () => _killApp('Obfuscation broken!'),
        onDebug: () => kDebugMode ? null : _killApp('Debugger attached!'),
        onDeviceBinding: () => _killApp('Device binding failed!'),
        onDeviceID: () => _killApp('Device ID extraction failed!'),
        onHooks: () => _killApp('Substrate/Frida hook detected!'),
        onPrivilegedAccess: () => _killApp('Root/Jailbreak detected!'),
        onSecureHardwareNotAvailable: () => debugPrint('Secure HW missing'),
        onSimulator: () => kDebugMode ? null : _killApp('Emulator detected!'),
        onUnofficialStore: () => debugPrint('Unofficial store used!'),
      );

      Talsec.instance.attachListener(callback);
      await Talsec.instance.start(config);
      debugPrint('[Security] FreeRASP initialized successfully');
    } catch (e) {
      debugPrint('[Security] FreeRASP init failed: $e');
    }
  }

  /// Thoát app khẩn cấp khi phát hiện đe dọa bảo mật
  static void _killApp(String reason) {
    debugPrint('🚨 [SECURITY THREAT DETECTED]: $reason');
    SystemNavigator.pop();
  }
}
