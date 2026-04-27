import 'package:supabase/supabase.dart';
import 'dart:io';

void main() async {
  final supabase = SupabaseClient(
    'https://nma2k5rinrin-dev.supabase.co',
    '<ANON_KEY>', // wait, I can extract it from .env
  );
}
