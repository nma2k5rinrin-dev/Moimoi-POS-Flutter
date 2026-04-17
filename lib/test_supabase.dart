import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  await dotenv.load(fileName: ".env");
  final client = SupabaseClient(
    dotenv.env['SUPABASE_URL']!,
    dotenv.env['SUPABASE_ANON_KEY']!,
  );
  try {
    final serverData = await client
        .from('transactions')
        .select()
        .limit(5);
    for (var row in serverData) {
      print("${row['id']} - ${row['time']}");
    }
  } catch (e) {
    print("Error: $e");
  }
}
