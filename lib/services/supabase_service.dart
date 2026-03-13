import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static const String supabaseUrl = 'https://xxspocdyxwoezelsngli.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh4c3BvY2R5eHdvZXplbHNuZ2xpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzIxODI4MzEsImV4cCI6MjA4Nzc1ODgzMX0.4owe6Bj8lxgazmk2s4hLeVcN95-wMAuRdG6ymVb6rJk';

  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }
}
