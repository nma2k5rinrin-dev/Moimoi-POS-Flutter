import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:moimoi_pos/core/utils/env_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SupabaseService {
  static const String supabaseUrl = EnvConfig.supabaseUrl;
  static const String supabaseAnonKey = EnvConfig.supabaseAnonKey;

  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  }

  static Future<void> registerFcmToken(String token) async {
    final user = client.auth.currentUser;
    if (user == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      String soundPath = prefs.getString('notification_sound') ?? 'sounds/bell.wav';
      // Mute will just send 'mute'
      String soundName = 'bell';
      if (soundPath != 'mute') {
        // e.g. "sounds/buy_1.mp3" -> "buy_1"
        try {
          soundName = soundPath.split('/').last.split('.').first;
        } catch (_) {}
      } else {
        soundName = 'mute';
      }

      await client.from('fcm_tokens').upsert({
        'token': token,
        'user_id': user.id,
        'sound': sound,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch(e) {
      // ignore
    }
  }
}
