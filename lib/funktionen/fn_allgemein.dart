import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class GiesAppLogik {
  static final supabase = Supabase.instance.client;

  /// Hilfsfunktion: Berechnet den Start einer KW (exakt wie im Web-Code)
  static DateTime _getStartOfKW(int kw) {
    // Wir nehmen 2026 als Basisjahr, wie in deinem Web-Code
    return DateTime(2026, 1, 1).add(Duration(days: (kw - 1) * 7 - 3));
  }

  /// Holt Daten über den Zeitraum (gte/lte), genau wie die Web-App
static Future<List<dynamic>> ladeAusfuehrungenProKW(int kw) async {
    try {
      final start = _getStartOfKW(kw);
      final end = start.add(const Duration(days: 6, hours: 23, minutes: 59));

      debugPrint("🔍 Suche Zeitraum: ${start.toIso8601String()} bis ${end.toIso8601String()}");

      final res = await supabase.from('ausfuehrung').select('''
        id, erledigt, geplant_am, kennzeichen, massnahme_id,
        orte (
          id, beschreibung_genau, hausnummer, latitude, longitude, 
          strassen:strasse_id (name, stadtteil)
        ), 
        massnahmen (
          id,
          taetigkeiten:taetigkeit_id (beschreibung_kurz, intervall_tage)
        )
      ''') // Hier wurde 'intervall_tage' korrigiert
      .gte('geplant_am', start.toIso8601String())
      .lte('geplant_am', end.toIso8601String())
      .order('geplant_am');
      
      final liste = res as List<dynamic>;
      debugPrint("🚀 Erfolg: ${liste.length} Einträge gefunden.");
      return liste;
    } catch (e) {
      debugPrint("❌ DB-Fehler bei ladeAusfuehrungen: $e");
      return [];
    }
  }

  /// Bleibt gleich: Fahrzeuge laden
  static Future<List<String>> ladeAlleKFZ() async {
    try {
      final res = await supabase.from('fahrzeuge').select('kennzeichen').order('kennzeichen');
      return (res as List).map((e) => e['kennzeichen'].toString()).toList();
    } catch (e) { return []; }
  }

  /// Bleibt gleich: Erledigen und neu planen
static Future<void> erledigenUndPlanen(dynamic ausfuehrung, {String? kfz, String? quelle}) async {
    try {
      final nun = DateTime.now();
      final massnahmeId = ausfuehrung['massnahme_id'];
      final int jahr = nun.year;
      final DateTime saisonEnde = DateTime(jahr, 11, 3, 23, 59); // 03.11. des aktuellen Jahres

      // 1. Aktuellen Termin als erledigt markieren
      await supabase.from('ausfuehrung').update({
        'erledigt': true,
        'ausgefuehrt_am': nun.toIso8601String(),
        'kennzeichen': kfz ?? ausfuehrung['kennzeichen'],
      }).eq('id', ausfuehrung['id']);

      // 2. ALLE zukünftigen offenen Termine dieser Maßnahme im aktuellen Jahr löschen
      // (Wir säubern das Feld für die Neukalibrierung)
      await supabase
          .from('ausfuehrung')
          .delete()
          .eq('massnahme_id', massnahmeId)
          .eq('erledigt', false)
          .gt('geplant_am', nun.toIso8601String())
          .lte('geplant_am', DateTime(jahr, 12, 31).toIso8601String());

      // 3. Neuberennung der Saison bis 03.11.
      final int intervall = ausfuehrung['massnahmen']?['taetigkeiten']?['intervall_tage'] ?? 7;
      List<Map<String, dynamic>> neueTermine = [];
      
      DateTime naechsterCheck = nun.add(Duration(days: intervall));

      // Schleife füllt die Saison auf
      while (naechsterCheck.isBefore(saisonEnde) || naechsterCheck.isAtSameMomentAs(saisonEnde)) {
        neueTermine.add({
          'massnahme_id': massnahmeId,
          'geplant_am': naechsterCheck.toIso8601String(),
          'erledigt': false,
          'kennzeichen': kfz ?? ausfuehrung['kennzeichen'],
        });
        // Zum nächsten Termin springen
        naechsterCheck = naechsterCheck.add(Duration(days: intervall));
      }

      // 4. Batch-Insert der neuen Saison-Termine
      if (neueTermine.isNotEmpty) {
        await supabase.from('ausfuehrung').insert(neueTermine);
      }
      
      debugPrint("🧹 Saison bereinigt und ${neueTermine.length} neue Termine bis 03.11. generiert.");
    } catch (e) {
      debugPrint("❌ Fehler in Saison-Logik: $e");
      throw "Fehler beim Re-Kalibrieren der Saison: $e";
    }
  }

  static Future<void> setzeAufOffen(dynamic ausfuehrung) async {
    await supabase.from('ausfuehrung').update({
      'erledigt': false,
      'ausgefuehrt_am': null,
    }).eq('id', ausfuehrung['id']);
  }
  /// Berechnet die aktuelle Kalenderwoche nach ISO-Standard
  static int getISOWeek(DateTime date) {
    // Erstellt ein Datum für den Donnerstag der aktuellen Woche
    // (ISO-Wochen sind über den Donnerstag definiert)
    final int dayOfYear = int.parse(DateFormat("D").format(date));
    final int woy = ((dayOfYear - date.weekday + 10) / 7).floor();
    
    // Kleiner Check für Jahresübergänge (52/53 oder 1)
    if (woy < 1) return 52;
    if (woy > 52) return 1;
    return woy;
  }
  static Future<void> resetToLastStatus(dynamic ausfuehrung) async {
    try {
      final massnahmeId = ausfuehrung['massnahme_id'];
      final int jahr = DateTime.now().year;
      final DateTime saisonEnde = DateTime(jahr, 11, 3, 23, 59);

      // 1. Die "falsche" Zukunft löschen (alles was durch den Fehl-Scan entstand)
      await supabase
          .from('ausfuehrung')
          .delete()
          .eq('massnahme_id', massnahmeId)
          .eq('erledigt', false)
          .gt('geplant_am', DateTime.now().toIso8601String());

      // 2. Den aktuellen Termin wieder auf "OFFEN" setzen
      await supabase.from('ausfuehrung').update({
        'erledigt': false,
        'ausgefuehrt_am': null,
      }).eq('id', ausfuehrung['id']);

      // 3. Den zeitlich LETZTEN ERLEDIGTEN Termin vor diesem suchen
      // Um zu wissen, von wo aus wir die ursprüngliche Kette berechnen müssen
      final letzteErledigtRes = await supabase
          .from('ausfuehrung')
          .select('ausgefuehrt_am')
          .eq('massnahme_id', massnahmeId)
          .eq('erledigt', true)
          .lt('ausgefuehrt_am', DateTime.now().toIso8601String())
          .order('ausgefuehrt_am', ascending: false)
          .limit(1)
          .maybeSingle();

      // Startpunkt für die Wiederherstellung finden
      DateTime basisDatum;
      if (letzteErledigtRes != null && letzteErledigtRes['ausgefuehrt_am'] != null) {
        // Wir nehmen den echten letzten Gießzeitpunkt
        basisDatum = DateTime.parse(letzteErledigtRes['ausgefuehrt_am']);
      } else {
        // Falls es gar keine Historie gibt, nehmen wir das geplante Datum des aktuellen Eintrags
        basisDatum = DateTime.parse(ausfuehrung['geplant_am']);
      }

      // 4. Die Kette basierend auf dem alten Intervall wiederherstellen
      final int intervall = ausfuehrung['massnahmen']?['taetigkeiten']?['intervall_tage'] ?? 7;
      List<Map<String, dynamic>> wiederhergestellteTermine = [];
      
      // Wir fangen beim ersten Termin NACH dem aktuellen an
      DateTime naechsterCheck = basisDatum.add(Duration(days: intervall));
      
      // Wenn der nächste Check auf das aktuelle (gerade geöffnete) Datum fällt, 
      // springen wir einen Schritt weiter, um Dubletten zu vermeiden
      if (naechsterCheck.isBefore(DateTime.now())) {
        naechsterCheck = naechsterCheck.add(Duration(days: intervall));
      }

      while (naechsterCheck.isBefore(saisonEnde)) {
        wiederhergestellteTermine.add({
          'massnahme_id': massnahmeId,
          'geplant_am': naechsterCheck.toIso8601String(),
          'erledigt': false,
          'kennzeichen': ausfuehrung['kennzeichen'],
        });
        naechsterCheck = naechsterCheck.add(Duration(days: intervall));
      }

      // 5. In die Datenbank schreiben
      if (wiederhergestellteTermine.isNotEmpty) {
        await supabase.from('ausfuehrung').insert(wiederhergestellteTermine);
      }

      debugPrint("🔄 Rollback erfolgreich: Kette ab $basisDatum wiederhergestellt.");
    } catch (e) {
      debugPrint("❌ Fehler beim Reset: $e");
      throw "Reset fehlgeschlagen: $e";
    }
  }
}