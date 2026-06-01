import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  const SupabaseService._();

  static SupabaseClient get client => Supabase.instance.client;
}
