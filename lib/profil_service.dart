import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';

class ProfilService {
  static final supabase = Supabase.instance.client;

  /// Das Standard-Passwort für die Erst-Anmeldung (muss im Supabase Dashboard so vergeben werden)
  static const String defaultInitialPassword = 'Start_123';

  /// Lädt das Profil des aktuell eingeloggten Users
  static Future<Map<String, dynamic>?> ladeProfil() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return null;

      final res = await supabase
          .from('profiles')
          .select('id, display_name, rolle, muss_passwort_aendern')
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
        'muss_passwort_aendern': true, // Standardmäßig bei Neuanlage erzwingen
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

  /// Ermöglicht es dem Admin, das Passwort-Flag für einen Nutzer zurückzusetzen (erzwingt Änderung beim nächsten Login)
  static Future<void> erzwingePasswortAenderung(String targetUserId) async {
    try {
      await supabase
          .from('profiles')
          .update({'muss_passwort_aendern': true})
          .eq('id', targetUserId);
    } catch (e) {
      debugPrint("❌ Fehler beim Zurücksetzen des Passwort-Flags: $e");
    }
  }

  /// Ändert das Passwort des aktuell angemeldeten Benutzers
  static Future<bool> passwortAendern(String neuesPasswort) async {
    try {
      // 1. Passwort in Supabase Auth aktualisieren
      await supabase.auth.updateUser(UserAttributes(password: neuesPasswort));

      // 2. Flag in der Datenbank zurücksetzen
      final userId = supabase.auth.currentUser?.id;
      if (userId != null) {
        await supabase
            .from('profiles')
            .update({'muss_passwort_aendern': false})
            .eq('id', userId);
      }
      return true;
    } catch (e) {
      debugPrint("❌ Fehler beim Ändern des Passworts: $e");
      return false;
    }
  }

  /// Gibt die Rolle des aktuellen Users zurück
  static Future<String> ladeRolle() async {
    final profil = await ladeProfil();
    return profil?['rolle'] ?? 'fahrer';
  }
}