import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';

class ProfilService {
  static final supabase = Supabase.instance.client;

  /// Lädt das Profil des aktuell eingeloggten Users
  static Future<Map<String, dynamic>?> ladeProfil() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return null;

      final res = await supabase
          .from('profiles')
          .select('id, display_name, rolle')
          .eq('id', userId)
          .maybeSingle();

      return res;
    } catch (e) {
      debugPrint("❌ Fehler beim Laden des Profils: $e");
      return null;
    }
  }

  /// Legt ein neues Profil an – wird nach Registrierung aufgerufen
  static Future<void> erstelleProfil({
    required String userId,
    required String displayName,
    String rolle = 'fahrer',
  }) async {
    try {
      await supabase.from('profiles').upsert({
        'id': userId,
        'display_name': displayName,
        'rolle': rolle,
      });
    } catch (e) {
      debugPrint("❌ Fehler beim Erstellen des Profils: $e");
    }
  }

  /// Aktualisiert den Anzeigenamen
  static Future<void> aktualisiereDisplayName(String neuerName) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      await supabase
          .from('profiles')
          .update({'display_name': neuerName})
          .eq('id', userId);
    } catch (e) {
      debugPrint("❌ Fehler beim Aktualisieren des Namens: $e");
    }
  }

  /// Gibt die Rolle des aktuellen Users zurück
  static Future<String> ladeRolle() async {
    final profil = await ladeProfil();
    return profil?['rolle'] ?? 'fahrer';
  }
}