import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:moimoi_pos/services/api/supabase_service.dart';
/// Standalone AudioStore — manages notification and payment sounds.
/// Replaces the old AudioStore mixin on ChangeNotifier.
class AudioStore extends ChangeNotifier {
  final AudioPlayer _orderSoundPlayer = AudioPlayer();
  final AudioPlayer _paymentSoundPlayer = AudioPlayer();

  String _notificationSound = 'sounds/bell.wav';
  String _paymentSound = 'sounds/buy_1.mp3';

  String get notificationSound => _notificationSound;
  String get paymentSound => _paymentSound;

  void initAudio() {
    if (!kIsWeb) {
      try {
        final notificationContext = AudioContext(
          android: AudioContextAndroid(
            usageType: AndroidUsageType.notification,
            contentType: AndroidContentType.sonification,
            audioFocus: AndroidAudioFocus.gainTransientMayDuck,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.ambient,
            options: {AVAudioSessionOptions.mixWithOthers},
          ),
        );
        // Both players use notification stream (not media stream)
        _orderSoundPlayer.setAudioContext(notificationContext);
        _paymentSoundPlayer.setAudioContext(notificationContext);
      } catch (e) {
        debugPrint('[AudioStore] initAudio error: $e');
      }
    }
  }

  Future<void> loadAudioPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _notificationSound =
          prefs.getString('notification_sound') ?? 'sounds/bell.wav';
      _paymentSound = prefs.getString('payment_sound') ?? 'sounds/buy_1.mp3';
    } catch (e) {
      debugPrint('[AudioStore] loadAudioPreferences error: $e');
    }
  }

  Future<void> setNotificationSound(String soundPath) async {
    _notificationSound = soundPath;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('notification_sound', soundPath);
      notifyListeners();
      
      // Sync to Supabase so the server knows which Android Channel / iOS Sound to hit
      try {
        final fcmToken = await FirebaseMessaging.instance.getToken();
        if (fcmToken != null) {
          await SupabaseService.registerFcmToken(fcmToken);
        }
      } catch (fcmErr) {
        debugPrint('[AudioStore] sync sound to FCM error: $fcmErr');
      }
    } catch (e) {
      debugPrint('[AudioStore] setNotificationSound error: $e');
    }
  }

  Future<void> setPaymentSound(String soundPath) async {
    _paymentSound = soundPath;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('payment_sound', soundPath);
      notifyListeners();
    } catch (e) {
      debugPrint('[AudioStore] setPaymentSound error: $e');
    }
  }

  /// Resolves the correct Source for a sound path.
  /// Paths starting with 'device:' are device files, otherwise assets.
  Source _resolveSource(String soundPath) {
    if (soundPath.startsWith('device:')) {
      return DeviceFileSource(soundPath.substring(7)); // strip 'device:' prefix
    }
    return AssetSource(soundPath);
  }

  void previewNotificationSound(String soundPath) async {
    try {
      if (_orderSoundPlayer.state == PlayerState.playing) {
        await _orderSoundPlayer.stop();
      }
      if (soundPath == 'mute') return;
      await _orderSoundPlayer.play(_resolveSource(soundPath));
    } catch (e) {
      debugPrint('[AudioStore] previewNotificationSound error: $e');
    }
  }

  void playNewOrderSound() async {
    try {
      if (_orderSoundPlayer.state == PlayerState.playing) {
        await _orderSoundPlayer.stop();
      }
      if (_notificationSound == 'mute') return;
      await _orderSoundPlayer.play(_resolveSource(_notificationSound));
    } catch (e) {
      debugPrint('[AudioStore] playNewOrderSound error: $e');
    }
  }

  void playPaymentSound() async {
    try {
      if (_paymentSoundPlayer.state == PlayerState.playing) {
        await _paymentSoundPlayer.stop();
      }
      if (_paymentSound == 'mute') return;
      await _paymentSoundPlayer.play(_resolveSource(_paymentSound));
    } catch (e) {
      debugPrint('[AudioStore] playPaymentSound error: $e');
    }
  }

  void disposeAudio() {
    _orderSoundPlayer.dispose();
    _paymentSoundPlayer.dispose();
  }

  @override
  void dispose() {
    disposeAudio();
    super.dispose();
  }
}
