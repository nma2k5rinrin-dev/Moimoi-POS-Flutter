import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://xxspocdyxwoezelsngli.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFub24iLCJpYXQiOjE3NzIxODI4MzEsImV4cCI6MjA4Nzc1ODgzMX0.4owe6Bj8lxgazmk2s4hLeVcN95-wMAuRdG6ymVb6rJk',
  );

  try {
    // Check if admin_update_user exists by trying to call it with dummy payload
    final res = await client.rpc('admin_update_user', params: {
      'p_username': 'bi',
      'p_fullname': 'Bi',
      'p_phone': '',
      'p_role': 'staff',
      'p_password': ''
    });
    print('RPC Result: $res');
  } catch (e) {
    print('Error calling RPC: $e');
  }
}
