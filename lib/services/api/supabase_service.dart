import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:moimoi_pos/core/utils/env_config.dart';

class SupabaseService {
  static const String supabaseUrl = EnvConfig.supabaseUrl;
  static const String supabaseAnonKey = EnvConfig.supabaseAnonKey;

  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }
}
