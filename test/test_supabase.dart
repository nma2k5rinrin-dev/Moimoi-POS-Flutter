import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets('Test query store_tables', (tester) async {
    // Read from dart define
    final url = const String.fromEnvironment('SUPABASE_URL');
    final key = const String.fromEnvironment('SUPABASE_ANON_KEY');
    
    print('URL: $url');
    print('Key length: ${key.length}');
    
    final client = SupabaseClient(url, key);
    
    try {
      final res = await client
          .from('store_tables')
          .select()
          .eq('store_id', 'moimoi')
          .isFilter('deleted_at', null);
      print('SUCCESS: fetched ${res.length} rows');
    } catch (e) {
      print('ERROR IN isFilter: $e');
    }
  });
}
