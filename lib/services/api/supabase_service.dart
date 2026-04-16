import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:moimoi_pos/core/utils/env_config.dart';

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
      await client.from('fcm_tokens').upsert({
        'token': token,
        'user_id': user.id,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch(e) {
      // ignore
    }
  }
}
